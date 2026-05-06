import Foundation
#if canImport(AppleNativeKit)
import AppleNativeKit
#endif

#if canImport(AppleNativeKit)
@available(iOS 17.0, *)
final class AppleNativeRuntime {
    static let shared = AppleNativeRuntime()

    let baselineStore: BaselineStore
    let healthMonitoringService: HealthMonitoringService
    let anomalyPredictor: AnomalyPredictor
    let visionOCRService: VisionOCRService

    private init() {
        let baselineStore = BaselineStore()
        self.baselineStore = baselineStore
        self.healthMonitoringService = HealthMonitoringService(baselineStore: baselineStore)
        self.anomalyPredictor = AnomalyPredictor(baselineStore: baselineStore)
        self.visionOCRService = VisionOCRService()
    }
}
#endif
