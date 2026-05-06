# iOS Native Integration Checklist

This folder currently contains Swift bridge scaffolding only. The Flutter iOS Runner project still needs to be created or restored in Xcode before these files can be compiled into the app target.

## 1. Add AppleNativeKit to the Runner target

Use one of these options:

- add `/Users/bachng/Coding/MAIC/apple_native` as a local Swift Package in Xcode
- or copy/link the source files from `apple_native/Sources/AppleNativeKit` into the Runner project

Recommended option: local Swift Package.

## 2. Add channel bridge files to Runner

Add these files to the iOS Runner target membership:

- `Runner/Channels/AppleNativeChannelRegistrar.swift`
- `Runner/Channels/VisionOCRChannelHandler.swift`
- `Runner/Channels/HealthMonitoringChannelHandler.swift`
- `Runner/Channels/CoreMLChannelHandler.swift`

## 3. Register channels in AppDelegate

Inside `AppDelegate.swift`, after `GeneratedPluginRegistrant.register(with: self)`, register the native channels:

```swift
if #available(iOS 17.0, *) {
    AppleNativeChannelRegistrar.register(with: window?.rootViewController as! FlutterBinaryMessenger)
}
```

If your app uses the default Flutter template, prefer registering with the root `FlutterViewController`:

```swift
if
    #available(iOS 17.0, *),
    let controller = window?.rootViewController as? FlutterViewController
{
    AppleNativeChannelRegistrar.register(with: controller.binaryMessenger)
}
```

## 4. Enable HealthKit capability

In Xcode:

1. Select the `Runner` target.
2. Open `Signing & Capabilities`.
3. Add `HealthKit`.

## 5. Update Info.plist

Add:

- `NSHealthShareUsageDescription`
- `NSCameraUsageDescription` if OCR images can come from camera capture
- `NSPhotoLibraryUsageDescription` if OCR images can come from photo library selection

If the app later writes HealthKit data, also add:

- `NSHealthUpdateUsageDescription`

## 6. Suggested smoke tests

- Call OCR channel with an existing image file path and verify returned text.
- Call `requestHealthPermissions` and confirm the iOS permission prompt appears.
- Call `startMonitoring` with a short window and confirm `getCurrentMonitoringSession` returns a live session.
- Call `predictAnomaly` with a mocked `HealthSnapshot` payload and confirm a structured prediction is returned.
