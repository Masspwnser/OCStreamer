package com.mass.ocstreamer.server;

public class Main {
    public static void main(String[] args) {
        Configuration.instance();
        var browser = new Browser();
        new WebServer(browser);
    }
}
