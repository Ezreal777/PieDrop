// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PieDrop",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "PieDrop", path: "Sources/PieDrop")
    ]
)
