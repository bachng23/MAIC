// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AppleNativeKit",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
    ],
    products: [
        .library(
            name: "AppleNativeKit",
            targets: ["AppleNativeKit"]
        ),
    ],
    targets: [
        .target(
            name: "AppleNativeKit",
            path: "Sources/AppleNativeKit"
        ),
    ]
)
