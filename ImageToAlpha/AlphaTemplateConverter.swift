// This file defines AlphaTemplateConverter, which encapsulates all image processing logic formerly in ImageToAlpha.run().
import Foundation
import AppKit

struct AlphaTemplateConverter {
    private init() {}

    /// Converts a PNG image by setting the RGB to black and the alpha to the inverse brightness, writing result to the given output path.
    static func convert(inputPath: String, outputPath: String) throws {
        // Load the image.
        guard let inputImage = NSImage(contentsOfFile: inputPath) else {
            throw NSError(domain: "AlphaTemplateConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image at \(inputPath). Ensure it is a valid PNG file."])
        }

        // Determine pixel dimensions from the best representation.
        guard let bestRep = inputImage.representations.max(by: { $0.pixelsWide * $0.pixelsHigh < $1.pixelsWide * $1.pixelsHigh }) else {
            throw NSError(domain: "AlphaTemplateConverter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to determine image pixel dimensions."])
        }
        let width = bestRep.pixelsWide
        let height = bestRep.pixelsHigh

        // Create a new bitmap with alpha channel.
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0) else {
            throw NSError(domain: "AlphaTemplateConverter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create bitmap representation."])
        }

        // Draw the input image into the bitmap context to get a bitmap with alpha.
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw NSError(domain: "AlphaTemplateConverter", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create graphics context."])
        }
        NSGraphicsContext.current = context
        context.cgContext.clear(CGRect(x: 0, y: 0, width: width, height: height))
        inputImage.draw(in: CGRect(x: 0, y: 0, width: width, height: height),
                        from: .zero,
                        operation: .copy,
                        fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        guard let data = bitmap.bitmapData else {
            throw NSError(domain: "AlphaTemplateConverter", code: 5, userInfo: [NSLocalizedDescriptionKey: "Cannot access bitmap data."])
        }
        let bytesPerPixel = bitmap.bitsPerPixel / 8

        // For each pixel, calculate brightness and set alpha; make RGB black.
        DispatchQueue.concurrentPerform(iterations: height) { y in
            for x in 0..<width {
                let offset = y * bitmap.bytesPerRow + x * bytesPerPixel
                let r = Float(data[offset])
                let g = Float(data[offset+1])
                let b = Float(data[offset+2])
                let brightness = 0.299 * r + 0.587 * g + 0.114 * b
                let invertedAlpha = UInt8(255 - UInt8(brightness))
                data[offset] = 0   // R
                data[offset+1] = 0 // G
                data[offset+2] = 0 // B
                if bytesPerPixel >= 4 {
                    data[offset+3] = invertedAlpha // A
                }
            }
        }

        // Write the new PNG out.
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "AlphaTemplateConverter", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG data for output."])
        }
        do {
            try pngData.write(to: URL(fileURLWithPath: outputPath))
        } catch {
            throw NSError(domain: "AlphaTemplateConverter", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to write output image to \(outputPath): \(error)"])
        }
    }
}
