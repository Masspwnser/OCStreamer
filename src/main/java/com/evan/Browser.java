package com.evan;

import com.evan.encoding.Image;

import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.Dimension;
import java.awt.image.BufferedImage;
import java.io.*;
import java.time.Duration;
import java.util.logging.Logger;

import org.openqa.selenium.*;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.chrome.ChromeOptions;
import org.openqa.selenium.interactions.Actions;
import org.openqa.selenium.support.ui.WebDriverWait;

public class Browser  {
    private static final Logger logger = Logger.getLogger(Browser.class.getName());
    
    private final WebDriver driver;

    public Browser() {
        // TODO Support other browsers
        driver = startChromeDriver();

        // Make absolutely sure the browser dies
        Runtime.getRuntime().addShutdownHook(new Thread() {
            @Override
            public void run() {
                if (driver != null) {
                    driver.quit();
                }
            }
        });
    }

    public Image getScreenshot() throws IOException {
        // TODO These conversions are odious, fix it
        byte[] screenshot = ((TakesScreenshot) driver).getScreenshotAs(OutputType.BYTES);
        BufferedImage image = ImageIO.read(new ByteArrayInputStream(screenshot));
        Dimension computedScreenDim = Configuration.instance().getComputedScreenDimensions();

        BufferedImage resized = new BufferedImage(computedScreenDim.width, computedScreenDim.height, BufferedImage.TYPE_4BYTE_ABGR);
        Graphics2D graphics = resized.createGraphics();
        graphics.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_NEAREST_NEIGHBOR);
        graphics.drawImage(image, 0, 0, computedScreenDim.width, computedScreenDim.height, 0, 0, image.getWidth(), image.getHeight(), null);
        graphics.dispose();

        return new Image(resized);
    }
    
    private WebDriver startChromeDriver() {
        ChromeOptions chromeOptions = new ChromeOptions();
        chromeOptions.setBinary(Configuration.instance().getBrowserBinaryPath());
        if (Configuration.instance().isHeadless()) {
            chromeOptions.addArguments("--headless");
        }
        if (Configuration.instance().isMute()) {
            chromeOptions.addArguments("--mute-audio");
        }
        WebDriver chromeDriver = new ChromeDriver(chromeOptions);
        chromeDriver.get(Configuration.instance().getUrl());

        new WebDriverWait(chromeDriver, Duration.ofSeconds(10));
        if (Configuration.instance().isFullscreen()) {
            new Actions(chromeDriver).sendKeys("f").perform(); // Attempt fullscreen
        }

        return chromeDriver;
    }
}
