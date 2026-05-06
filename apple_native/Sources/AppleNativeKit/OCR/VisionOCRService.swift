import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(ImageIO)
import ImageIO
#endif
#if canImport(Vision)
import Vision
#endif

@available(macOS 13.0, iOS 17.0, *)
public final class VisionOCRService {
    public init() {}

    public func recognizeText(fromImageAt imagePath: String) async throws -> OCRResult {
        #if canImport(Vision) && canImport(ImageIO) && canImport(CoreGraphics)
        let imageURL = URL(fileURLWithPath: imagePath)
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw VisionOCRError.fileNotFound
        }

        let cgImage = try loadCGImage(from: imageURL)
        let observations = try performRecognition(on: cgImage)

        let lines = observations
            .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return OCRResult(
            rawText: lines.joined(separator: "\n"),
            lines: lines
        )
        #else
        _ = imagePath
        throw VisionOCRError.visionUnavailable
        #endif
    }

    #if canImport(Vision) && canImport(ImageIO) && canImport(CoreGraphics)
    private func loadCGImage(from imageURL: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
            throw VisionOCRError.invalidImage
        }

        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw VisionOCRError.invalidImage
        }

        return image
    }

    private func performRecognition(on image: CGImage) throws -> [VNRecognizedTextObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.02
        request.automaticallyDetectsLanguage = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results else {
            return []
        }

        return observations.sorted { lhs, rhs in
            let yDifference = abs(lhs.boundingBox.minY - rhs.boundingBox.minY)
            if yDifference > 0.03 {
                return lhs.boundingBox.minY > rhs.boundingBox.minY
            }

            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }
    }
    #endif
}

public enum VisionOCRError: Error {
    case fileNotFound
    case invalidImage
    case visionUnavailable
}
