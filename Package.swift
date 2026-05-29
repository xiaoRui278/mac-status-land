// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacStatusLand",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "MacStatusLand",
            path: "MacStatusLand",
            exclude: ["Info.plist", "Entitlements.entitlements"]
        )
    ]
)
