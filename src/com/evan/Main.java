package com.evan;

import org.openqa.selenium.*;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.chrome.ChromeOptions;
import org.openqa.selenium.interactions.Actions;
import org.openqa.selenium.support.ui.WebDriverWait;

import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.*;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.SocketException;
import java.time.Duration;
import java.util.Properties;

//todo open in specified resolution aspect ratio
//todo RLE pixels

public class Main {
    public static void main(String[] args) throws InterruptedException {
        Properties prop = new Properties();
        String fileName = "properties.cfg";
        try (FileInputStream fis = new FileInputStream(fileName)) {
            prop.load(fis);
        } catch (Exception e) {}
        String pageURL = prop.getProperty("url", "https://www.twitch.tv/cerbervt");
        int width = Integer.parseInt(prop.getProperty("width", "160"));
        int height = Integer.parseInt(prop.getProperty("height", "50"));
        String browserBinaryPath = prop.getProperty("browser.binary", "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe");
        boolean dither = Boolean.parseBoolean(prop.getProperty("dither", "false"));

        ChromeOptions chromeOptions = new ChromeOptions();
        chromeOptions.setBinary(browserBinaryPath);
        chromeOptions.addArguments("--headless");
        WebDriver driver = new ChromeDriver(chromeOptions);
        driver.get(pageURL);

        new WebDriverWait(driver, Duration.ofSeconds(10));
        new Actions(driver).sendKeys("f").perform(); // Attempt fullscreen

        // Prevent computer-breaking memory leak vulnerability
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
                        InputStream inputStream = clientSocket.getInputStream();

                        while (clientSocket.isConnected()) {
                            byte[] screenshot = ((TakesScreenshot) driver).getScreenshotAs(OutputType.BYTES);
                            BufferedImage image = ImageIO.read(new ByteArrayInputStream(screenshot));

                            //scaling
                            BufferedImage resized = new BufferedImage(width*2, height*4, BufferedImage.TYPE_4BYTE_ABGR);
                            Graphics2D graphics = resized.createGraphics();
                            graphics.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_NEAREST_NEIGHBOR);
                            graphics.drawImage(image, 0, 0, width*2, height*4, 0, 0, image.getWidth(), image.getHeight(), null);
                            graphics.dispose();
                            //end scaling

                            while (inputStream.available() <= 0 && clientSocket.isConnected()) {
                                System.out.println("WAITED, AVOID AT ALL COST");
                                Thread.sleep(100);
                            }
                            System.out.println("Client requested new frame, sending it");

                            OCIF.sendToSocket(dataOutputStream, resized, width, height, true, dither);
                        }
                    }
                    System.out.println("Connection lost! Ending stream.");
                } catch (SocketException e){
                    if(serverSocket != null) serverSocket.close();
                    System.out.println("Disconnected from client.");
                }
            }
        } catch (IOException e) {
            System.out.println("Unexpected IO exception");
            e.printStackTrace();
        } finally {
            driver.quit();
            System.exit(0);
        }
    }
}
