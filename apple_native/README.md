# Apple Native Workspace

This directory contains the Apple-platform-specific implementation for MediGuard.

It is intentionally separated from `backend` and `frontend` so the iOS-native work can progress independently.

## Goals

- Apple Vision OCR
- HealthKit integration
- Core ML anomaly detection
- WatchConnectivity support
- Flutter bridge contracts for iOS

## Structure

```text
apple_native/
  Package.swift
  docs/
  Sources/
    AppleNativeKit/
      OCR/
      Health/
      ML/
      Watch/
      Bridge/
      Shared/
```

## Recommended Workflow

1. Build reusable native logic inside `AppleNativeKit`.
2. Keep Flutter channel names and payload contracts stable.
3. Later integrate these source files into the iOS runner in `frontend/ios`.

## Next Steps

1. Implement Apple Vision OCR in `Sources/AppleNativeKit/OCR`.
2. Implement HealthKit permissions and reads in `Sources/AppleNativeKit/Health`.
3. Implement Core ML prediction in `Sources/AppleNativeKit/ML`.
4. Wire the bridge layer to Flutter method channels in `Sources/AppleNativeKit/Bridge`.
