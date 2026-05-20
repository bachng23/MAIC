import Foundation
import MessageUI
import UIKit
#if canImport(Flutter)
import Flutter
#endif
#if canImport(AppleNativeKit)
import AppleNativeKit
#endif

#if canImport(Flutter) && canImport(AppleNativeKit)
/// Handles the `com.mediguard/emergency` method channel.
///
/// Flutter (via a silent APNs push) calls:
///   - `sendIMessage`  → opens Messages app pre-filled with contacts + message
///   - `emergencyCall` → dials 119 via `tel:` URL
@available(iOS 17.0, *)
final class EmergencyChannelHandler: NSObject {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
    }

    func register() {
        let channel = FlutterMethodChannel(
            name: ChannelNames.emergency,
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
    }

    // MARK: - Dispatch

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case FlutterBridgeContracts.sendIMessageMethod:
            handleSendIMessage(arguments: call.arguments, result: result)
        case FlutterBridgeContracts.emergencyCallMethod:
            handleEmergencyCall(arguments: call.arguments, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - sendIMessage

    private struct IMessagePayload: Decodable {
        let contacts: [Contact]
        let message: String

        struct Contact: Decodable {
            let phone: String
        }
    }

    /// Opens the Messages app for the first contact. iOS does not allow
    /// sending iMessages silently, so we use MFMessageComposeViewController
    /// pre-filled with all recipient numbers.
    private func handleSendIMessage(arguments: Any?, result: @escaping FlutterResult) {
        guard MFMessageComposeViewController.canSendText() else {
            result(FlutterError(
                code: "MESSAGES_UNAVAILABLE",
                message: "This device cannot send Messages.",
                details: nil
            ))
            return
        }

        let payload: IMessagePayload
        do {
            payload = try FlutterBridgeContracts.decode(IMessagePayload.self, from: arguments)
        } catch {
            result(FlutterError(code: "INVALID_ARGS", message: "\(error)", details: nil))
            return
        }

        let recipients = payload.contacts.map(\.phone)
        guard !recipients.isEmpty else {
            result(FlutterError(code: "NO_CONTACTS", message: "No emergency contacts provided.", details: nil))
            return
        }

        DispatchQueue.main.async {
            let vc = MFMessageComposeViewController()
            vc.recipients = recipients
            vc.body = payload.message
            vc.messageComposeDelegate = MessageDelegateProxy.shared

            guard let root = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                .first else {
                result(FlutterError(code: "NO_ROOT_VC", message: "Could not find root view controller.", details: nil))
                return
            }
            root.present(vc, animated: true)
            result(true)
        }
    }

    // MARK: - emergencyCall

    private struct EmergencyCallPayload: Decodable {
        let number: String
    }

    private func handleEmergencyCall(arguments: Any?, result: @escaping FlutterResult) {
        let number: String
        if let payload = try? FlutterBridgeContracts.decode(EmergencyCallPayload.self, from: arguments) {
            number = payload.number
        } else {
            number = "119"
        }

        guard let url = URL(string: "tel://\(number)") else {
            result(FlutterError(code: "INVALID_NUMBER", message: "Cannot form tel URL for \(number)", details: nil))
            return
        }

        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:]) { opened in
                result(opened)
            }
        }
    }
}

// MARK: - Message delegate proxy

/// A lightweight singleton that dismisses the compose sheet silently
/// so the caller doesn't need to worry about cleanup.
private final class MessageDelegateProxy: NSObject, MFMessageComposeViewControllerDelegate {
    static let shared = MessageDelegateProxy()

    func messageComposeViewController(
        _ controller: MFMessageComposeViewController,
        didFinishWith result: MessageComposeResult
    ) {
        controller.dismiss(animated: true)
    }
}
#endif
