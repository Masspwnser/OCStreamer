package com.evan;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.util.logging.Logger;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;

public class WebServer {
    private static final Logger logger = Logger.getLogger(WebServer.class.getName());

    private final Browser browser = new Browser();

    private byte[] byteImage;

    public WebServer() {
        try {
            HttpServer server = HttpServer.create(new InetSocketAddress(8008), 0);
            server.createContext("/stream", new ImageHandler());
            server.createContext("/test", new TestHandler());
            server.setExecutor(null); // creates a default executor
            server.start();
            logger.info("Started web server");
        } catch (IOException e) {
            logger.severe(e.getMessage());
        }
    }

    class ImageHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange t) throws IOException {
            if (byteImage == null) {
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

    class TestHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange t) throws IOException {
            String response = "READY";
            t.sendResponseHeaders(200, response.length());
            OutputStream os = t.getResponseBody();
            os.write(response.getBytes());
            os.close();
            byteImage = browser.getScreenshot().getByteArray();
            logger.fine("Sent READY to client, beginning stream");
        }
    }
}