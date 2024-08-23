package com.evan.encoding;

import com.evan.Configuration;

import java.awt.image.BufferedImage;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.logging.Logger;

import org.apache.commons.io.output.ByteArrayOutputStream;

public class Image {
    private static final Logger logger = Logger.getLogger(Image.class.getName());

    public final int width;
    public final int height;

    private final Color[][] pixels;

    public Image(BufferedImage image) {
        this.width = image.getWidth();
        this.height = image.getHeight();
        this.pixels = new Color[this.height][this.width];
        for (int y = 0; y < this.height; y++) {
            for (int x = 0; x < this.width; x++) {
                this.pixels[y][x] = new Color(image.getRGB(x, y));
            }
        }
        if (Configuration.instance().shouldDither()) {
            dither();
        }
    }

    public byte[] getByteArray() {
        ByteArrayOutputStream stream = new ByteArrayOutputStream();
        Pixel pixel;
        // 16-bit width and height
        stream.write((byte) Configuration.instance().getOCScreenDimensions().width);
        stream.write((byte) (Configuration.instance().getOCScreenDimensions().width >> 8));
        stream.write((byte) Configuration.instance().getOCScreenDimensions().height);
        stream.write((byte) (Configuration.instance().getOCScreenDimensions().height >> 8));
        for (int y = 0; y < this.height; y+=4) {
            for (int x = 0; x < this.width; x+=2) {
                pixel = getBraillePixel(x, y);
                stream.write((byte) Palette.getClosestIndex(pixel.background));
                stream.write((byte) Palette.getClosestIndex(pixel.foreground));
                // Bitpack the braille to reduce throughput
                byte[] utf8Bytes = pixel.symbol.getBytes(StandardCharsets.UTF_8);
                stream.write((byte) (((utf8Bytes[1] & 0x03) << 6) | (utf8Bytes[2] & 0x3F)));
            }
        }
        return stream.toByteArray();
    }

    private static String getBrailleChar(int[][] brailleMatrix) {
        return Character.toString((char) (10240 + 
        128 * brailleMatrix[3][1]
        + 64 * brailleMatrix[3][0]
        + 32 * brailleMatrix[2][1]
        + 16 * brailleMatrix[1][1]
        + 8 * brailleMatrix[0][1]
        + 4 * brailleMatrix[2][0]
        + 2 * brailleMatrix[1][0]
        + brailleMatrix[0][0]));
    }

    private Color[][] getBraiileArray(int fromX, int fromY) {
        Color[][] brailleArray = new Color[4][2];
        int imageX;
        int imageY;

        for (int y = 0; y < 4; y++) {
            for (int x = 0; x < 2; x++) {
                imageX = fromX + x;
                imageY = fromY + y;

                if (imageX < this.width && imageY < this.height) {
                    brailleArray[y][x] = this.pixels[imageY][imageX];
                } else {
                    brailleArray[y][x] = new Color(0x00000000);
                }
            }
        }

        return brailleArray;
    }

    private static double getColorDistance(Color myColor) {
        return Math.pow(myColor.red, 2) + Math.pow(myColor.green, 2) + Math.pow(myColor.blue, 2);
    }

    private static double getChannelsDelta(Color color1, Color color2) {
        return Math.pow(color1.red - color2.red, 2) + Math.pow(color1.green - color2.green, 2) + Math.pow(color1.blue - color2.blue, 2);
    }

    private static Color getBestMatch(Color color1, Color color2, Color targetColor) {
        return getChannelsDelta(color1, targetColor) < getChannelsDelta(color2, targetColor) ? color1 : color2;
    }

    private Pixel getBraillePixel(int fromX, int fromY) {
        Color[][] brailleArray = getBraiileArray(fromX, fromY);

        double distance, minDistance = 999999.0d, maxDistance = 0.0d;
        Color minColor = brailleArray[0][0], maxColor = brailleArray[0][0];

        for (int y = 0; y < 4; y++) {
            for (int x = 0; x < 2; x++) {
                distance = getColorDistance(brailleArray[y][x]);
                if (distance < minDistance) {
                    minDistance = distance;
                    minColor = brailleArray[y][x];
                }

                if (distance > maxDistance) {
                    maxDistance = distance;
                    maxColor = brailleArray[y][x];
                }
            }
        }

        int[][] brailleMatrix = new int[4][2];

        for (int y = 0; y < 4; y++) {
            for (int x = 0; x < 2; x++) {
                brailleMatrix[y][x] = getBestMatch(minColor, maxColor, brailleArray[y][x]) == minColor ? 0 : 1;
            }
        }

        String brailleChar = getBrailleChar(brailleMatrix);


        return new Pixel(minColor, maxColor, 0x00, brailleChar);
    }

    private static final double Xp1Yp0 = 7.0d / 16.0d;
    private static final double Xp1Yp1 = 1.0d / 16.0d;
    private static final double Xp0Yp1 = 5.0d / 16.0d;
    private static final double Xm1Y1 = 3.0d / 16.0d;

    private void dither() {
        double intensity = 1;
        for (int y = 0; y < this.height; y++) {
            for (int x = 0; x < this.width; x++) {

                Color paletteColor = Palette.getClosestColor(this.pixels[y][x]);
                Color colorDifference = Color.difference(this.pixels[y][x], paletteColor);

                this.pixels[y][x] = paletteColor;

                if (x < this.width - 1) {
                    this.pixels[y][x + 1] = Color.sum(
                            this.pixels[y][x + 1],
                            Color.multiply(colorDifference, Xp1Yp0 * intensity)
                    );

                    if (y < this.height - 1) {
                        this.pixels[y + 1][x + 1] = Color.sum(
                                this.pixels[y + 1][x + 1],
                                Color.multiply(colorDifference, Xp1Yp1 * intensity)
                        );
                    }
                }

                if (y < this.height - 1) {
                    this.pixels[y + 1][x] = Color.sum(
                            this.pixels[y + 1][x],
                            Color.multiply(colorDifference, Xp0Yp1 * intensity)
                    );

                    if (x > 0) {
                        this.pixels[y + 1][x - 1] = Color.sum(
                                this.pixels[y + 1][x - 1],
                                Color.multiply(colorDifference, Xm1Y1 * intensity)
                        );
                    }
                }
            }
        }
    }
}