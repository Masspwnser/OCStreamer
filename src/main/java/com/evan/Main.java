package com.evan;

import org.openqa.selenium.*;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.chrome.ChromeOptions;
import org.openqa.selenium.interactions.Actions;
import org.openqa.selenium.support.ui.WebDriverWait;

import com.evan.encoding.OCIFConverter;

import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.Dimension;
import java.awt.image.BufferedImage;
import java.io.*;
import java.net.ServerSocket;
import java.net.Socket;
import java.time.Duration;
import java.util.logging.Logger;

public class Main {
    private static final Logger logger = Logger.getLogger(Main.class.getName());

    public static void main(String[] args) throws IOException {
        WebDriver driver = initializeBrowser();
         beginConnectionLoop(driver);
    }

    private static WebDriver initializeBrowser() {
        ChromeOptions chromeOptions = new ChromeOptions();
        chromeOptions.setBinary(Configuration.instance().getBrowserBinaryPath());
        if (Configuration.instance().isHeadless()) {
            chromeOptions.addArguments("--headless");
        }
        WebDriver driver = new ChromeDriver(chromeOptions);
        driver.get(Configuration.instance().getUrl());

        new WebDriverWait(driver, Duration.ofSeconds(10));
        if (Configuration.instance().isFullscreen()) {
            new Actions(driver).sendKeys("f").perform(); // Attempt fullscreen
        }

        // Prevent computer-breaking memory leak vulnerability
        Runtime.getRuntime().addShutdownHook(new Thread() {
            @Override
            public void run() {
                if (driver != null) {
                    driver.quit();
                }
            }
         });
         return driver;
    }

    private static void beginConnectionLoop(WebDriver driver) throws IOException {
        while (true) {
            try (ServerSocket serverSocket = new ServerSocket(54321, 1)) {
                logger.info("Waiting for connection!");
                Socket clientSocket = serverSocket.accept(); // This is blocking
                DataOutputStream dataOutputStream = new DataOutputStream(clientSocket.getOutputStream());
                logger.info("Connection received! Begin streaming...");

                while (clientSocket.isConnected()) {
                    byte[] screenshot = ((TakesScreenshot) driver).getScreenshotAs(OutputType.BYTES);
                    BufferedImage image = ImageIO.read(new ByteArrayInputStream(screenshot));
                    Dimension computedScreenDim = Configuration.instance().getComputedScreenDimensions();

                    //scaling
                    BufferedImage resized = new BufferedImage(computedScreenDim.width, computedScreenDim.height, BufferedImage.TYPE_4BYTE_ABGR);
                    Graphics2D graphics = resized.createGraphics();
                    graphics.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_NEAREST_NEIGHBOR);
                    graphics.drawImage(image, 0, 0, computedScreenDim.width, computedScreenDim.height, 0, 0, image.getWidth(), image.getHeight(), null);
                    graphics.dispose();
                    //end scaling

                    OCIFConverter.sendToSocket(dataOutputStream, resized);
                }
            }
            logger.warning("Disconnected from client.");
        }
    }
}
