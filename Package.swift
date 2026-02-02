// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MonitorControl",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MonitorControlV3",
            targets: ["MonitorControl"]),
    ],
    targets: [
        .target(
            name: "PrivateDDC",
            dependencies: [],
            path: "Sources/PrivateDDC",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreDisplay", .when(platforms: [.macOS]))
            ]
        ),
        .executableTarget(
            name: "MonitorControl",
            dependencies: [
                "PrivateDDC"
            ]
        ),
    ]
)
