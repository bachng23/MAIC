import Foundation
#if canImport(Flutter)
import Flutter
#endif
#if canImport(AppleNativeKit)
import AppleNativeKit
#endif

#if canImport(Flutter) && canImport(AppleNativeKit)
@available(iOS 17.0, *)
final class HealthMonitoringChannelHandler: NSObject {
    private let messenger: FlutterBinaryMessenger
    private let runtime = AppleNativeRuntime.shared

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
    }

    func register() {
        let channel = FlutterMethodChannel(
            name: ChannelNames.healthMonitor,
            binaryMessenger: messenger
        )

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
    }

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case FlutterBridgeContracts.requestHealthPermissionsMethod:
            Task {
                do {
                    try await runtime.healthMonitoringService.requestPermissions()
                    result(
                        try FlutterBridgeContracts.encode(
                            HealthPermissionResponse(granted: true)
                        )
                    )
                } catch {
                    result(bridgeError(
                        code: "health_permissions_error",
                        message: "HealthKit permission request failed",
                        details: String(describing: error)
                    ))
                }
            }
        case FlutterBridgeContracts.startMonitoringMethod:
            Task {
                do {
                    let request = try FlutterBridgeContracts.decode(StartMonitoringRequest.self, from: call.arguments)
                    try await runtime.healthMonitoringService.startMonitoring(window: request.monitoringWindow())
                    let session = await runtime.healthMonitoringService.currentSession()
                    result(
                        try FlutterBridgeContracts.encode(
                            MonitoringSessionResponse(session: session)
                        )
                    )
                } catch {
                    result(bridgeError(
                        code: "start_monitoring_error",
                        message: "Failed to start health monitoring",
                        details: String(describing: error)
                    ))
                }
            }
        case FlutterBridgeContracts.stopMonitoringMethod:
            Task {
                await runtime.healthMonitoringService.stopMonitoring()
                do {
                    result(
                        try FlutterBridgeContracts.encode(
                            StopMonitoringResponse(stopped: true)
                        )
                    )
                } catch {
                    result(bridgeError(
                        code: "stop_monitoring_error",
                        message: "Failed to stop health monitoring",
                        details: String(describing: error)
                    ))
                }
            }
        case FlutterBridgeContracts.latestSnapshotMethod:
            Task {
                let snapshot = await runtime.healthMonitoringService.latestSnapshot()
                do {
                    result(
                        try FlutterBridgeContracts.encode(
                            SnapshotResponse(snapshot: snapshot)
                        )
                    )
                } catch {
                    result(bridgeError(
                        code: "latest_snapshot_error",
                        message: "Failed to fetch latest health snapshot",
                        details: String(describing: error)
                    ))
                }
            }
        case FlutterBridgeContracts.currentMonitoringSessionMethod:
            Task {
                let session = await runtime.healthMonitoringService.currentSession()
                do {
                    result(
                        try FlutterBridgeContracts.encode(
                            MonitoringSessionResponse(session: session)
                        )
                    )
                } catch {
                    result(bridgeError(
                        code: "monitoring_session_error",
                        message: "Failed to fetch monitoring session",
                        details: String(describing: error)
                    ))
                }
            }
        case FlutterBridgeContracts.currentBaselineMethod:
            Task {
                let baseline = await runtime.healthMonitoringService.currentBaseline()
                do {
                    result(
                        try FlutterBridgeContracts.encode(
                            BaselineResponse(baseline: baseline)
                        )
                    )
                } catch {
                    result(bridgeError(
                        code: "baseline_error",
                        message: "Failed to fetch personalized baseline",
                        details: String(describing: error)
                    ))
                }
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
