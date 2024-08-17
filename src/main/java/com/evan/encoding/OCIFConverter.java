package com.evan.encoding;

import java.awt.Dimension;
import java.awt.image.BufferedImage;
import java.io.DataOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;

import com.evan.Configuration;

public class OCIFConverter {
    private OCIFConverter() {}

    private static void writePixelToFileAsOCIF5(DataOutputStream out, Pixel pixel) throws IOException {
        out.write((byte) Palette.getClosestIndex(pixel.background));
        out.write((byte) Palette.getClosestIndex(pixel.foreground));
        // Bitpack the braille to reduce throughput
        byte[] utf8Bytes = pixel.symbol.getBytes(StandardCharsets.UTF_8);
        out.write(((utf8Bytes[1] & 0x03) << 6) | (utf8Bytes[2] & 0x3F));
    }

    private static byte[] integerToByteArray(int number, int arraySize) {
        byte[] array = new byte[arraySize];

        int position = arraySize - 1;
        do {
            array[position] = (byte) (number & 0xFF);
            number = number >> 8;
            position--;
        } while (number > 0);

        while (position >= 0) {
            array[position] = 0x0;
            position--;
        }

        return array;
    }

    private static Image loadImage(BufferedImage buffImage) {
        Image image = new Image(buffImage);

        if (Configuration.instance().shouldDither()) {
            image = Image.dither(image);
        }

        return image;
    }

    public static void sendToSocket(DataOutputStream out, BufferedImage bufImage) throws IOException {
        Image image = loadImage(bufImage);
        Dimension ocScreenDimensions = Configuration.instance().getOCScreenDimensions();

        out.write(integerToByteArray(ocScreenDimensions.width, 2));
        out.write(integerToByteArray(ocScreenDimensions.height, 2));

        for (int y = 0; y < image.height; y += 4) {
            for (int x = 0; x < image.width; x += 2) {
                writePixelToFileAsOCIF5(out, Image.getBraillePixel(image, x, y));
            }
        }
    }
}
