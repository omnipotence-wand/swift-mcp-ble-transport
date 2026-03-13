import Foundation

public struct BLEPacketAssembler: Sendable {
    private var buffer = Data()
    private var totalLength = 0
    private var inProgress = false
    private var expectedSequence: UInt8 = 0

    public init() {}

    public mutating func feed(packet: Data) throws -> Data? {
        guard let header = packet.first else { return nil }

        let packetType = header & BLEFramingConstants.headerTypeMask
        let sequence = header & BLEFramingConstants.headerSeqMask
        let payload = packet.dropFirst()

        if packetType == BLEFramingConstants.typeSingle {
            return Data(payload)
        }

        if packetType == BLEFramingConstants.typeStart {
            guard payload.count >= 4 else {
                reset()
                throw BLETransportError.invalidPacket
            }
            totalLength = Int(payload.prefix(4).toUInt32BigEndian())
            buffer = Data(payload.dropFirst(4))
            inProgress = true
            expectedSequence = (sequence + 1) & BLEFramingConstants.headerSeqMask
            return nil
        }

        guard inProgress else { return nil }
        guard sequence == expectedSequence else {
            reset()
            throw BLETransportError.packetSequenceMismatch
        }

        expectedSequence = (expectedSequence + 1) & BLEFramingConstants.headerSeqMask

        if packetType == BLEFramingConstants.typeCont {
            buffer.append(payload)
            return nil
        }

        if packetType == BLEFramingConstants.typeEnd {
            buffer.append(payload)
            guard buffer.count == totalLength else {
                reset()
                throw BLETransportError.packetLengthMismatch
            }
            let message = buffer
            reset()
            return message
        }

        return nil
    }

    public mutating func reset() {
        buffer = Data()
        totalLength = 0
        inProgress = false
        expectedSequence = 0
    }
}

private extension Data {
    func toUInt32BigEndian() -> UInt32 {
        precondition(self.count == 4)
        return self.reduce(UInt32(0)) { partial, byte in
            (partial << 8) | UInt32(byte)
        }
    }
}
