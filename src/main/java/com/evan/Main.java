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
import java.net.SocketException;
import java.time.Duration;

public class Main {
    public static void main(String[] args) throws InterruptedException {

        ChromeOptions chromeOptions = new ChromeOptions();
        chromeOptions.setBinary(Configuration.instance().getBrowserBinaryPath());
        if (Configuration.instance().isHeadless()) {
            chromeOptions.addArguments("--headless");
        }
        WebDriver driver = new ChromeDriver(chromeOptions);
        driver.get(Configuration.instance().getUrl());

        new WebDriverWait(driver, Duration.ofSeconds(10));
        new Actions(driver).sendKeys("f").perform(); // Attempt fullscreen

        // (help) Prevent computer-breaking memory leak vulnerability
        Runtime.getRuntime().addShutdownHook(new Thread() {
            public void run() {
                if (driver != null) {
                    driver.quit();
                }
            }
         });

        try {
            while (true) {
                ServerSocket serverSocket = null;
                try {
                    serverSocket = new ServerSocket(54321, 1);

                    System.out.println("Waiting for connection!");
                    Socket clientSocket = serverSocket.accept();
                    System.out.println("Connection received! Begin streaming...");
                    if (clientSocket.isConnected()) {
                        DataOutputStream dataOutputStream = new DataOutputStream(clientSocket.getOutputStream());

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
                } catch (SocketException e){
                    if(serverSocket != null) serverSocket.close();
                } finally {
                    System.out.println("Disconnected from client.");
                }
            }
        } catch (IOException e) {
            System.out.println("Unexpected IO exception");
            e.printStackTrace();
        } finally {
            System.out.println("Cleaning up and exiting...");
            driver.quit();
            System.exit(0);
        }
    }
}
