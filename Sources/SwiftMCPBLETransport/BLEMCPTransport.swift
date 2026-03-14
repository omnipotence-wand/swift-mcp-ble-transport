import Foundation
import Logging
import MCP

#if canImport(CoreBluetooth)
import CoreBluetooth

public actor BLEMCPTransport: Transport {
    public nonisolated let logger: Logger

    private nonisolated let options: BLETransportOptions
    private let framer = BLEPacketFramer()
    private var assembler = BLEPacketAssembler()
    private nonisolated let adapter: any BLEAdapter
    private var connected = false
    private var stream: AsyncThrowingStream<Data, Error>
    private var continuation: AsyncThrowingStream<Data, Error>.Continuation
    private var receiverTask: Task<Void, Never>?

    public init(
        options: BLETransportOptions = .init(),
        logger: Logger? = nil
    ) {
        self.options = options
        self.logger = logger ?? Logger(label: "mcp.transport.ble")
        let adapter = CoreBluetoothAdapter(logger: self.logger)
        self.adapter = adapter
        var continuation: AsyncThrowingStream<Data, Error>.Continuation!
        self.stream = AsyncThrowingStream<Data, Error> { continuation = $0 }
        self.continuation = continuation
    }

    init(
        options: BLETransportOptions = .init(),
        logger: Logger? = nil,
        adapter: any BLEAdapter
    ) {
        self.options = options
        self.logger = logger ?? Logger(label: "mcp.transport.ble")
        self.adapter = adapter
        var continuation: AsyncThrowingStream<Data, Error>.Continuation!
        self.stream = AsyncThrowingStream<Data, Error> { continuation = $0 }
        self.continuation = continuation
    }

    public func connect() async throws {
        guard !connected else { return }
        try await adapter.connect(options: options)
        connected = true
        receiverTask = Task {
            let incoming = adapter.incomingMessages()
            do {
                for try await packet in incoming {
                    do {
                        if let message = try assembler.feed(packet: packet) {
                            continuation.yield(message)
                        }
                    } catch {
                        continuation.finish(throwing: error)
                        await disconnect()
                        return
                    }
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    public func disconnect() async {
        guard connected else { return }
        receiverTask?.cancel()
        receiverTask = nil
        await adapter.disconnect()
        connected = false
        assembler.reset()
        continuation.finish()
    }

    public func send(_ data: Data) async throws {
        guard connected else {
            throw MCPError.connectionClosed
        }
        let mtu = adapter.currentMTU()
        let maxPayload = framer.computeMaxPayload(mtu: mtu)
        let packets = try framer.packetize(message: data, maxPayload: maxPayload)
        for packet in packets {
            try await adapter.write(packet, withResponse: options.writeWithResponse)
        }
    }

    public func receive() -> AsyncThrowingStream<Data, Error> {
        stream
    }
}

#else

public actor BLEMCPTransport: Transport {
    public nonisolated let logger: Logger

    public init(options: BLETransportOptions = .init(), logger: Logger? = nil) {
        self.logger = logger ?? Logger(label: "mcp.transport.ble")
    }

    public func connect() async throws {
        throw BLETransportError.bluetoothUnavailable
    }

    public func disconnect() async {}

    public func send(_ data: Data) async throws {
        throw BLETransportError.bluetoothUnavailable
    }

    public func receive() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: BLETransportError.bluetoothUnavailable)
        }
    }
}

#endif
