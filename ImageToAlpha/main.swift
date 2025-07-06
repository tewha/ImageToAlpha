import ArgumentParser
import Foundation
import AppKit

struct ImageToAlpha: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "image-to-alpha",
        abstract: "Converts a PNG to a template by placing the inverse brightness in the alpha channel and making the image black.",
        discussion: """
        Reads a PNG file, calculates the brightness for each pixel, then sets the RGB channels to black and the alpha channel to the inverse brightness. The result is a template image suitable for masking or highlighting.
        """
    )
    
    @Flag(name: .shortAndLong, help: "Process file in-place; use the same path for input and output.")
    var inPlace: Bool = false

    @Argument(help: "Path to the input image.")
    var inputPath: String
    
    @Argument(help: "Path to the output image.",
              completion: .file(),
              transform: { $0 })
    var outputPath: String?

    func run() throws {
        // Validate parameters.
        let actualOutput: String
        if inPlace {
            guard outputPath == nil else {
                throw ValidationError("When using -i/--in-place, provide only one path.")
            }
            actualOutput = inputPath
        } else {
            guard let outputPath else {
                throw ValidationError("You must provide an output path unless using -i/--in-place.")
            }
            actualOutput = outputPath
        }

        // Load the image.
        guard let inputImage = NSImage(contentsOfFile: inputPath) else {
            throw ValidationError("Failed to load image at \(inputPath). Ensure it is a valid PNG file.")
        }

        // Determine pixel dimensions from the best representation.
        guard let bestRep = inputImage.representations.max(by: { $0.pixelsWide * $0.pixelsHigh < $1.pixelsWide * $1.pixelsHigh }) else {
            throw ValidationError("Failed to determine image pixel dimensions.")
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
            throw ValidationError("Failed to create bitmap representation.")
        }

        // Draw the input image into the bitmap context to get a bitmap with alpha.
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw ValidationError("Failed to create graphics context.")
        }
        NSGraphicsContext.current = context
        context.cgContext.clear(CGRect(x: 0, y: 0, width: width, height: height))
        inputImage.draw(in: CGRect(x: 0, y: 0, width: width, height: height),
                        from: .zero,
                        operation: .copy,
                        fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        guard let data = bitmap.bitmapData else {
            throw ValidationError("Cannot access bitmap data.")
        }
        let bytesPerPixel = bitmap.bitsPerPixel / 8

        // For each pixel, calculate the brightness of the image and make the alpha channel the inverse (so that black pixels are opaque and white pixels transparent). Replace the original image data with black.
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bitmap.bytesPerRow + x * bytesPerPixel
                let r = Float(data[offset])
                let g = Float(data[offset+1])
                let b = Float(data[offset+2])
                // Compute brightness using Rec. 601 luma formula, range 0...255
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
            throw ValidationError("Failed to encode PNG data for output.")
        }
        do {
            try pngData.write(to: URL(fileURLWithPath: actualOutput))
        } catch {
            throw ValidationError("Failed to write output image to \(actualOutput): \(error)")
        }
    }
}

ImageToAlpha.main()
