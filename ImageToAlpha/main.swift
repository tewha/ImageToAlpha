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

        do {
            try AlphaTemplateConverter.convert(inputPath: inputPath, outputPath: actualOutput)
        } catch let error as NSError {
            throw ValidationError(error.localizedDescription)
        }
    }
}

ImageToAlpha.main()
