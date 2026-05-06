import Foundation
#if canImport(Flutter)
import Flutter
#endif
#if canImport(AppleNativeKit)
import AppleNativeKit
#endif

#if canImport(Flutter) && canImport(AppleNativeKit)
@available(iOS 17.0, *)
final class CoreMLChannelHandler: NSObject {
    private let messenger: FlutterBinaryMessenger
    private let runtime = AppleNativeRuntime.shared

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
    }

    func register() {
        let channel = FlutterMethodChannel(
            name: ChannelNames.coreML,
            binaryMessenger: messenger
        )

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
    }

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case FlutterBridgeContracts.predictAnomalyMethod:
            Task {
                do {
                    let request = try FlutterBridgeContracts.decode(PredictAnomalyRequest.self, from: call.arguments)
                    let prediction = try await runtime.anomalyPredictor.predict(
                        from: request.snapshot,
                        medicationLogID: request.medicationLogId
                    )
                    result(
                        try FlutterBridgeContracts.encode(
                            PredictAnomalyResponse(prediction: prediction)
                        )
                    )
                } catch {
                    result(bridgeError(
                        code: "predict_anomaly_error",
                        message: "Failed to run anomaly prediction",
                        details: String(describing: error)
                    ))
                }
            }
        case FlutterBridgeContracts.loadModelStatusMethod:
            do {
                result(
                    try FlutterBridgeContracts.encode(
                        ModelStatusResponse(
                            loaded: true,
                            modelName: "RuleBasedAnomalyPredictor",
                            modelVersion: "mvp-1",
                            mode: "rule_based"
                        )
                    )
                )
            } catch {
                result(bridgeError(
                    code: "load_model_status_error",
                    message: "Failed to load model status",
                    details: String(describing: error)
                ))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
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
#endif
