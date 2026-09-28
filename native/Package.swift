// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "iphonectl-native",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "iphonectl-native",
            path: "Sources/iphonectl-native"
        )
    ]
)
