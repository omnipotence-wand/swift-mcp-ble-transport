// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-mcp-ble-transport",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SwiftMCPBLETransport",
            targets: ["SwiftMCPBLETransport"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", exact: "0.10.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.4")
    ],
    targets: [
        .target(
            name: "SwiftMCPBLETransport",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "SwiftMCPBLETransportTests",
            dependencies: ["SwiftMCPBLETransport"]
        )
    ]
)
