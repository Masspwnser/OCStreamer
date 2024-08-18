package com.evan;

import java.awt.Dimension;
import java.io.FileInputStream;
import java.util.Properties;
import java.util.Timer;
import java.util.TimerTask;
import java.util.concurrent.TimeUnit;

public class Configuration {
    private static final String FILE_NAME = "properties.cfg";

    private static final Properties prop = new Properties();
    private static Configuration instance = null;
    
    private static int width;
    private static int height;
    private static boolean dither;
    private static boolean headless;
    private static String browserBinary;
    private static String url;

    static {
        // Every delay seconds, reload the configuration file
        long delay = TimeUnit.SECONDS.toMillis(30);
        Timer timer = new Timer("configuration-reloader", true);
        TimerTask task = new TimerTask() {
            @Override
            public void run() {
                System.out.println("Re-loading configuration");
                loadConfiguration();
            }
        };
        timer.scheduleAtFixedRate(task, delay, delay);
    }

    private Configuration() {
        System.out.println("Loading configuration");
        loadConfiguration();
    }

    public static synchronized Configuration instance() {
        if (instance == null) {
            instance = new Configuration();
        }
        return instance;
    }

    private static synchronized void loadConfiguration() {
        try (FileInputStream fis = new FileInputStream(FILE_NAME)) {
            prop.load(fis);
        } catch (Exception e) {
            System.out.println("Error loading configuration");
        }

        width = Integer.parseInt(prop.getProperty("width", "160"));
        height = Integer.parseInt(prop.getProperty("height", "50"));
        dither = Boolean.parseBoolean(prop.getProperty("dither", "false"));
        headless = Boolean.parseBoolean(prop.getProperty("headless", "true"));
        browserBinary = prop.getProperty("browser.binary", "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe");
        url = prop.getProperty("url", "https://www.twitch.tv/cerbervt");
    }

    public String getUrl() {
        return url;
    }

    // Raw OpenComputers screen dimensions
    public Dimension getOCScreenDimensions() {
        return new Dimension(width, height);
    }

    // Computed screen dimensions, using braille to increase pixel dimensions.
    public Dimension getComputedScreenDimensions() {
        return new Dimension(width*2, height*4);
    }

    public String getBrowserBinaryPath() {
        return browserBinary;
    }

    public boolean shouldDither() {
        return dither;
    }

    public boolean isHeadless() {
        return headless;
    }
}
