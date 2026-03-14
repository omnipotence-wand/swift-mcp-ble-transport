import MCP
import SwiftMCPBLETransport

func runExample() async throws {
    let client = Client(name: "BLEClient", version: "1.0.0")
    let transport = BLEMCPTransport(
        options: BLETransportOptions(
            namePrefix: "MCP",
            scanTimeout: .seconds(10),
            connectTimeout: .seconds(10)
        )
    )

    _ = try await client.connect(transport: transport)
    let (tools, _) = try await client.listTools()
    print(tools.map(\.name))
}
