// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwfitMCPBLETransport",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "MCPBLETransport",
            targets: ["MCPBLETransport"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", exact: "0.10.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.4")
    ],
    targets: [
        .target(
            name: "MCPBLETransport",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "MCPBLETransportTests",
            dependencies: ["MCPBLETransport"]
        )
    ]
)
