// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacStatusLand",
    defaultLocalization: "zh",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MacStatusLand",
            path: "MacStatusLand",
            exclude: ["Info.plist", "Entitlements.entitlements"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
