package com.evan;

import java.awt.Dimension;
import java.io.File;
import java.io.FileInputStream;
import java.util.Properties;
import java.util.logging.Logger;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.filefilter.FileFilterUtils;
import org.apache.commons.io.monitor.FileAlterationListenerAdaptor;
import org.apache.commons.io.monitor.FileAlterationMonitor;
import org.apache.commons.io.monitor.FileAlterationObserver;

public class Configuration {
    private static final Logger logger = Logger.getLogger(Configuration.class.getName());

    private static final File CONFIG_FILE = new File("properties.cfg");

    private static final Properties prop = new Properties();
    private static Configuration instance = null;
    
    private static int width;
    private static int height;
    private static boolean dither;
    private static boolean headless;
    private static boolean fullscreen;
    private static boolean mute;
    private static String browserBinary;
    private static String userData;
    private static String url;

    private Configuration() {
        loadConfiguration();

        // Reload configuration on change
        FileAlterationObserver observer = new FileAlterationObserver(FileUtils.current(), FileFilterUtils.suffixFileFilter(".cfg"));
        observer.addListener(new FileAlterationListenerAdaptor() {
            @Override
            public void onFileCreate(File file) {
                loadConfiguration();
            }

            @Override
            public void onFileChange(File file) {
                loadConfiguration();
            }
        });
        FileAlterationMonitor monitor = new FileAlterationMonitor(500, observer);
        try {
            monitor.start();
        } catch (Exception e) {
            logger.severe(e.getMessage());
        }
    }

    public static synchronized Configuration instance() {
        if (instance == null) {
            instance = new Configuration();
        }
        return instance;
    }

    private static synchronized void loadConfiguration() {
        logger.info("Loading configuration");
        try (FileInputStream fis = new FileInputStream(CONFIG_FILE)) {
            prop.load(fis);
        } catch (Exception e) {
            logger.severe("Error loading configuration");
        }

        width = Integer.parseInt(prop.getProperty("width", "160"));
        height = Integer.parseInt(prop.getProperty("height", "50"));
        dither = Boolean.parseBoolean(prop.getProperty("dither", "false"));
        headless = Boolean.parseBoolean(prop.getProperty("headless", "true"));
        fullscreen = Boolean.parseBoolean(prop.getProperty("fullscreen", "true"));
        mute = Boolean.parseBoolean(prop.getProperty("mute", "true"));
        browserBinary = prop.getProperty("browser.binary", "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe");
        userData = prop.getProperty("browser.userdata", "");
        String oldUrl = url;
        url = prop.getProperty("url", "https://www.twitch.tv/cerbervt");
        if (oldUrl != null && !url.equals(oldUrl)) {
            Browser.instance().navigate(url);
        }
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

    public String getUserDataPath() {
        return userData;
    }

    public boolean shouldDither() {
        return dither;
    }

    public boolean isHeadless() {
        return headless;
    }

    public boolean isFullscreen() {
        return fullscreen;
    }

    public boolean isMute() {
        return mute;
    }
}
