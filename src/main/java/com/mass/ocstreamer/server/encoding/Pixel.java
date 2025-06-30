package com.mass.ocstreamer.server.encoding;


public class Pixel {
    public final Color background;
    public final Color foreground;
    public final int alpha;
    public final String symbol;

    public Pixel(Color background, Color foreground, int alpha, String symbol) {
        this.background = background;
        this.foreground = foreground;
        this.alpha = alpha;
        this.symbol = symbol;
    }
}