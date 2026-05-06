import Foundation
#if canImport(Flutter)
import Flutter
#endif
#if canImport(AppleNativeKit)
import AppleNativeKit
#endif

#if canImport(Flutter) && canImport(AppleNativeKit)
@available(iOS 17.0, *)
enum AppleNativeChannelRegistrar {
    private static var retainedHandlers: [AnyObject] = []

    static func register(with messenger: FlutterBinaryMessenger) {
        let visionHandler = VisionOCRChannelHandler(messenger: messenger)
        let healthHandler = HealthMonitoringChannelHandler(messenger: messenger)
        let coreMLHandler = CoreMLChannelHandler(messenger: messenger)

        visionHandler.register()
        healthHandler.register()
        coreMLHandler.register()

        retainedHandlers = [
            visionHandler,
            healthHandler,
            coreMLHandler,
        ]
    }
}
#endif
