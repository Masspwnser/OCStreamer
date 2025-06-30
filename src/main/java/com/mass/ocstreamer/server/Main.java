package com.mass.ocstreamer.server;

public class Main {
    public static void main(String[] args) {
        Configuration.instance();
        Browser.instance();
        new WebServer();
    }
}
