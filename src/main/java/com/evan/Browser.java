package com.evan;

import com.evan.encoding.Image;

import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.*;
import java.time.Duration;
import java.util.logging.Logger;

import org.openqa.selenium.OutputType;
import org.openqa.selenium.TakesScreenshot;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.chrome.ChromeOptions;
import org.openqa.selenium.firefox.FirefoxDriver;
import org.openqa.selenium.firefox.FirefoxOptions;
import org.openqa.selenium.interactions.Actions;
import org.openqa.selenium.support.ui.WebDriverWait;

public class Browser  {
    private static final Logger logger = Logger.getLogger(Browser.class.getName());

    private static Browser instance = null;
    
    private final WebDriver driver;

    private Browser() {
        // TODO Support other browsers
        driver = getDriver();
        
        if (Configuration.instance().isFullscreen()) {
            new WebDriverWait(driver, Duration.ofSeconds(10));
            new Actions(driver).sendKeys("f").perform(); // Attempt fullscreen
        }

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

    public static synchronized Browser instance() {
        if (instance == null) {
            instance = new Browser();
        }
        return instance;
    }

    public void navigate(String newUrl) {
        driver.get(newUrl);
        if (Configuration.instance().isFullscreen()) {
            new WebDriverWait(driver, Duration.ofSeconds(5));
            new Actions(driver).sendKeys("f").perform(); // Attempt fullscreen
        }
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

    // This sucks, but not sure there's a better way to get multi-browser support
    private WebDriver getDriver() {
        WebDriver webDriver = null;
        if (Configuration.instance().getBrowserBinaryPath().toLowerCase().contains("firefox")) {
            FirefoxOptions options = new FirefoxOptions();
            options.setBinary(Configuration.instance().getBrowserBinaryPath());
            if (Configuration.instance().isHeadless()) {
                options.addArguments("--headless");
            }
            // TODO figure out mute for firefox
            // TODO this can be automated with commandline arguments
            if (!Configuration.instance().getUserDataPath().equals("")) {
                options.addArguments("--profile");
                options.addArguments(Configuration.instance().getUserDataPath());
            }
            webDriver = new FirefoxDriver(options);
            webDriver.get(Configuration.instance().getUrl());
        } else if (Configuration.instance().getBrowserBinaryPath().toLowerCase().contains("chrome")) {
            ChromeOptions options = new ChromeOptions();
            options.setBinary(Configuration.instance().getBrowserBinaryPath());
            if (Configuration.instance().isHeadless()) {
                options.addArguments("--headless");
            }
            if (Configuration.instance().isMute()) {
                options.addArguments("--mute-audio");
            }
            if (!Configuration.instance().getUserDataPath().equals("")) {
                options.addArguments("--profile");
                options.addArguments(Configuration.instance().getUserDataPath());
            }
            webDriver = new ChromeDriver(options);
            webDriver.get(Configuration.instance().getUrl());
        }
        return webDriver;
    }
}
