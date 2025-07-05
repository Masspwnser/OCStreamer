package com.mass.ocstreamer.server;

import java.awt.Dimension;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Path;
import java.util.Properties;
import java.util.logging.Logger;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.filefilter.FileFilterUtils;
import org.apache.commons.io.monitor.FileAlterationListenerAdaptor;
import org.apache.commons.io.monitor.FileAlterationMonitor;
import org.apache.commons.io.monitor.FileAlterationObserver;

public class Configuration {
    private static final Logger logger = Logger.getLogger(Configuration.class.getName());

    private static final String PROPERTIES_FILE = "properties.cfg";

    private static final Properties prop = new Properties();
    private static Configuration instance = null;
    
    private static int width;
    private static int height;
    private static boolean dither;
    private static boolean headless;
    private static boolean fullscreen;
    private static boolean mute;
    private static Path browserBinary;
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
        try (InputStream is = Configuration.class.getClassLoader().getResourceAsStream(PROPERTIES_FILE)) {
            prop.load(is);
        } catch (IOException e) {
            logger.severe("Error loading configuration {}" + e.getMessage());
        }

        width = Integer.parseInt(prop.getProperty("width", "160"));
        height = Integer.parseInt(prop.getProperty("height", "50"));
        dither = Boolean.parseBoolean(prop.getProperty("dither", "false"));
        headless = Boolean.parseBoolean(prop.getProperty("headless", "true"));
        fullscreen = Boolean.parseBoolean(prop.getProperty("fullscreen", "true"));
        mute = Boolean.parseBoolean(prop.getProperty("mute", "true"));
        browserBinary = Path.of(prop.getProperty("browser.binary", "/usr/bin/firefox"));
        userData = prop.getProperty("browser.userdata", "");
        url = prop.getProperty("url", "https://pngimg.com/uploads/smiley/smiley_PNG27.png");
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

    public Path getBrowserBinaryPath() {
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
