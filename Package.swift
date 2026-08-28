// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "musicloud",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Musicloud", targets: ["Musicloud"])],
    targets: [
        .target(name: "MusicloudCore"),
        .executableTarget(name: "Musicloud", dependencies: ["MusicloudCore"]),
        .testTarget(name: "MusicloudCoreTests", dependencies: ["MusicloudCore"])
    ]
)
