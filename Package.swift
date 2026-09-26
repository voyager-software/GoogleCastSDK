// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GoogleCast",
    platforms: [
        .iOS(.v16),
        .macCatalyst(.v16),
    ],
    products: [
        .library(
            name: "GoogleCast",
            targets: ["GoogleCast"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "GoogleCast",
            // EXPERIMENTAL: Google's 4.8.6 xcframework plus an unofficial Mac Catalyst slice,
            // built by Scripts/make-catalyst-xcframework.sh
            url: "https://github.com/voyager-software/GoogleCastSDK/releases/download/4.8.6-catalyst-beta.2/GoogleCastSDK-ios-4.8.6_dynamic_catalyst.zip",
            checksum: "ceeac77092b3c574dbd6fd211dcb26d6e22116eadf6956e94ae6498c29317936"
        ),
    ]
)

// swift package compute-checksum ~/Downloads/GoogleCastSDK-ios-4.8.3_dynamic.zip
// bc2c3c2434ef2895a0388ac3f16932242d3d3ac11805f810dbe7d7bce3bb27f6

// swift package compute-checksum ~/Downloads/GoogleCastSDK-ios-4.8.4_dynamic.zip
// c9c3a794e8585198b59c6bb7da5418a3194ffa1ffa6f9a1cbdf4dc0ea26dc6cf

// swift package compute-checksum ~/Downloads/GoogleCastSDK-ios-4.8.6_dynamic.zip
// 55f6c21291a1315c68063f07e7d76225564bff70f2fd38caad135c71d66eb310
