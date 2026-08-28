// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "musicloud",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Musicloud", targets: ["Musicloud"])],
    targets: [
        .target(name: "MusicloudCore"),
        .target(name: "MusicloudAudio", dependencies: ["MusicloudCore"]),
        .executableTarget(name: "Musicloud", dependencies: ["MusicloudCore", "MusicloudAudio"]),
        .testTarget(name: "MusicloudCoreTests", dependencies: ["MusicloudCore"]),
        .testTarget(name: "MusicloudAudioTests", dependencies: ["MusicloudAudio"], resources: [.copy("Fixtures")])
    ]
)
