import Foundation
import Testing
@testable import MCPBLETransport

#if canImport(CoreBluetooth)
import CoreBluetooth

private final class MockBLEAdapter: BLEAdapter, @unchecked Sendable {
    let mtu: Int
    private(set) var connected = false
    private(set) var writes: [Data] = []
    private var stream: AsyncThrowingStream<Data, Error>
    private var continuation: AsyncThrowingStream<Data, Error>.Continuation

    init(mtu: Int = 23) {
        self.mtu = mtu
        var continuation: AsyncThrowingStream<Data, Error>.Continuation!
        self.stream = AsyncThrowingStream { continuation = $0 }
        self.continuation = continuation
    }

    func connect(options: BLETransportOptions) async throws {
        connected = true
    }

    func disconnect() async {
        connected = false
        continuation.finish()
    }

    func write(_ data: Data, withResponse: Bool) async throws {
        writes.append(data)
    }

    func incomingMessages() -> AsyncThrowingStream<Data, Error> {
        stream
    }

    func currentMTU() -> Int {
        mtu
    }

    func push(_ packet: Data) {
        continuation.yield(packet)
    }
}

@Test
func transport_sendAndReceive() async throws {
    let mock = MockBLEAdapter(mtu: 23)
    let transport = BLEMCPTransport(
        options: BLETransportOptions(mtu: 23),
        adapter: mock
    )

    try await transport.connect()
    try await transport.send(Data("client-message".utf8))
    #expect(mock.connected == true)
    #expect(mock.writes.isEmpty == false)

    let framer = BLEPacketFramer()
    let serverPayload = Data("server-message".utf8)
    let packets = try framer.packetize(message: serverPayload, maxPayload: 20)
    for packet in packets {
        mock.push(packet)
    }

    var iterator = await transport.receive().makeAsyncIterator()
    let received = try await iterator.next()
    #expect(received == serverPayload)

    await transport.disconnect()
}

#endif
