// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

enum PackageMetadata {
    static let version: String = "4.8.3"
    static let checksum: String = "bc2c3c2434ef2895a0388ac3f16932242d3d3ac11805f810dbe7d7bce3bb27f6"
}

let package = Package(
    name: "GoogleCastSDK",
    platforms: [
        .iOS(.v14),
    ],
    products: [
        .library(
            name: "GoogleCastSDK",
            targets: ["GoogleCastSDK"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "GoogleCastSDK",
            url: "https://dl.google.com/dl/chromecast/sdk/ios/GoogleCastSDK-ios-\(PackageMetadata.version)_dynamic.zip",
            checksum: PackageMetadata.checksum
        ),
    ]
)

// swift package compute-checksum ~/Downloads/GoogleCastSDK-ios-4.8.3_dynamic.zip
// bc2c3c2434ef2895a0388ac3f16932242d3d3ac11805f810dbe7d7bce3bb27f6
