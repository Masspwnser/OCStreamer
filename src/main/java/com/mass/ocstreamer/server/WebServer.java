package com.mass.ocstreamer.server;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.util.logging.Logger;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;

public class WebServer {
    private static final Logger logger = Logger.getLogger(WebServer.class.getName());

    private final Browser browser;
    private byte[] byteImage;

    public WebServer(Browser browser) {
        this.browser = browser;
        HttpServer server;
        try {
            server = HttpServer.create(new InetSocketAddress(56795), 0);
        } catch (IOException e) {
            logger.severe(e.getMessage());
            System.exit(1);
            return;
        }
        server.createContext("/stream", new ImageHandler());
        server.createContext("/status", new StatusHandler());
        server.setExecutor(null); // creates a default executor
        server.start();
        logger.info("Started web server");

        Runtime.getRuntime().addShutdownHook(new Thread(() -> server.stop(0)));
    }

    class ImageHandler implements HttpHandler {
        @Override
        public synchronized void handle(HttpExchange t) throws IOException {
            if (byteImage == null) {
                logger.warning("Image bytes were NOT ready at time of request.");
                byteImage = browser.getScreenshot().getByteArray();
            }
            t.sendResponseHeaders(200, byteImage.length);
            OutputStream os = t.getResponseBody();
            os.write(byteImage);
            os.close();
            byteImage = browser.getScreenshot().getByteArray();
            logger.fine("Sent frame to client");
        }
    }

    class StatusHandler implements HttpHandler {
        @Override
        public synchronized void handle(HttpExchange t) throws IOException {
            byteImage = browser.getScreenshot().getByteArray();
            String response = "READY";
            t.sendResponseHeaders(200, response.length());
            OutputStream os = t.getResponseBody();
            os.write(response.getBytes());
            os.close();
            logger.info("Started broadcast to client");
        }
    }
}