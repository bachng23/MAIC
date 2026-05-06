import Foundation
#if canImport(Flutter)
import Flutter
#endif
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppleNativeKit)
import AppleNativeKit
#endif

#if canImport(Flutter) && canImport(AppleNativeKit)
@available(iOS 17.0, *)
final class VisionOCRChannelHandler: NSObject, PHPickerViewControllerDelegate {
    private let messenger: FlutterBinaryMessenger
    private let runtime = AppleNativeRuntime.shared
    private var pendingImagePickResult: FlutterResult?

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
    }

    func register() {
        let channel = FlutterMethodChannel(
            name: ChannelNames.visionOCR,
            binaryMessenger: messenger
        )

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
    }

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case FlutterBridgeContracts.recognizeTextMethod, FlutterBridgeContracts.recognizeTextFromFileMethod:
            Task {
                do {
                    let request = try FlutterBridgeContracts.decode(OCRFileRequest.self, from: call.arguments)
                    let ocrResult = try await runtime.visionOCRService.recognizeText(fromImageAt: request.imagePath)
                    result(try FlutterBridgeContracts.encode(ocrResult))
                } catch {
                    result(bridgeError(
                        code: "vision_ocr_error",
                        message: "Vision OCR request failed",
                        details: String(describing: error)
                    ))
                }
            }
        case FlutterBridgeContracts.pickImageFromLibraryMethod:
            pickImageFromLibrary(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func pickImageFromLibrary(result: @escaping FlutterResult) {
        guard pendingImagePickResult == nil else {
            result(bridgeError(
                code: "vision_picker_busy",
                message: "Another image picker request is already in progress",
                details: "Only one library picker can be active at a time."
            ))
            return
        }

        guard let presenter = topViewController() else {
            result(bridgeError(
                code: "vision_picker_unavailable",
                message: "Unable to present image picker",
                details: "No active view controller was found."
            ))
            return
        }

        pendingImagePickResult = result

        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        presenter.present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let resultHandler = pendingImagePickResult else { return }
        pendingImagePickResult = nil

        guard let provider = results.first?.itemProvider else {
            resultHandler(bridgeError(
                code: "vision_picker_cancelled",
                message: "Image selection was cancelled",
                details: "No image was selected."
            ))
            return
        }

        if provider.hasItemConformingToTypeIdentifier("public.image") {
            provider.loadFileRepresentation(forTypeIdentifier: "public.image") { [weak self] url, error in
                guard let self else { return }

                if let error {
                    resultHandler(self.bridgeError(
                        code: "vision_picker_load_error",
                        message: "Failed to load selected image",
                        details: String(describing: error)
                    ))
                    return
                }

                guard let url else {
                    resultHandler(self.bridgeError(
                        code: "vision_picker_load_error",
                        message: "Failed to load selected image",
                        details: "Provider returned no file URL."
                    ))
                    return
                }

                do {
                    let targetURL = try self.copyPickedImageToTemporaryLocation(from: url)
                    let response = PickedImageResponse(imagePath: targetURL.path)
                    resultHandler(try FlutterBridgeContracts.encode(response))
                } catch {
                    resultHandler(self.bridgeError(
                        code: "vision_picker_copy_error",
                        message: "Failed to prepare selected image for OCR",
                        details: String(describing: error)
                    ))
                }
            }
            return
        }

        resultHandler(bridgeError(
            code: "vision_picker_invalid_type",
            message: "Selected item is not an image",
            details: "Please choose an image from the photo library."
        ))
    }

    private func copyPickedImageToTemporaryLocation(from url: URL) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileExtension = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
        let targetURL = tempDirectory.appendingPathComponent(
            "ocr_pick_\(UUID().uuidString).\(fileExtension)"
        )

        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.removeItem(at: targetURL)
        }

        try FileManager.default.copyItem(at: url, to: targetURL)
        return targetURL
    }

    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)

        var viewController = keyWindow?.rootViewController
        while let presented = viewController?.presentedViewController {
            viewController = presented
        }
        return viewController
    }

    private func bridgeError(
        code: String,
        message: String,
        details: String
    ) -> FlutterError {
        let payload = FlutterBridgeErrorPayload(
            code: code,
            message: message,
            details: details
        )
        return FlutterError(
            code: code,
            message: message,
            details: try? FlutterBridgeContracts.encode(payload)
        )
    }
}

private struct OCRFileRequest: Codable {
    let imagePath: String
}
#endif
