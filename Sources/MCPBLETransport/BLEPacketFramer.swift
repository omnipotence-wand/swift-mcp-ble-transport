import Foundation

public struct BLEPacketFramer: Sendable {
    public init() {}

    public func computeMaxPayload(mtu: Int) -> Int {
        var maxPayload = mtu - BLEFramingConstants.attOverhead
        if maxPayload < BLEFramingConstants.minPayload {
            maxPayload = BLEFramingConstants.minPayload
        }
        if maxPayload > BLEFramingConstants.maxGattValueLength {
            maxPayload = BLEFramingConstants.maxGattValueLength
        }
        return maxPayload
    }

    public func packetize(message: Data, maxPayload: Int) throws -> [Data] {
        if message.count + 1 <= maxPayload {
            var packet = Data(capacity: 1 + message.count)
            packet.append(BLEFramingConstants.typeSingle)
            packet.append(message)
            return [packet]
        }

        if maxPayload <= 5 {
            throw BLETransportError.mtuTooSmall
        }

        var packets: [Data] = []
        var offset = 0
        var sequence: UInt8 = 0
        let totalLength = UInt32(message.count)

        let startChunkSize = maxPayload - 5
        let startEnd = min(message.count, startChunkSize)
        let startChunk = message[offset..<startEnd]
        var startPacket = Data(capacity: 1 + 4 + startChunk.count)
        startPacket.append(BLEFramingConstants.typeStart | (sequence & BLEFramingConstants.headerSeqMask))
        startPacket.append(contentsOf: totalLength.bigEndianBytes)
        startPacket.append(startChunk)
        packets.append(startPacket)
        offset += startChunk.count
        sequence = (sequence + 1) & BLEFramingConstants.headerSeqMask

        let contChunkSize = maxPayload - 1
        while offset < message.count {
            let remaining = message.count - offset
            let chunkSize = min(remaining, contChunkSize)
            let chunk = message[offset..<(offset + chunkSize)]
            var packet = Data(capacity: 1 + chunkSize)
            let packetType: UInt8 = remaining > contChunkSize ? BLEFramingConstants.typeCont : BLEFramingConstants.typeEnd
            packet.append(packetType | (sequence & BLEFramingConstants.headerSeqMask))
            packet.append(chunk)
            packets.append(packet)
            offset += chunkSize
            sequence = (sequence + 1) & BLEFramingConstants.headerSeqMask
        }

        return packets
    }
}

private extension UInt32 {
    var bigEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.bigEndian) { Array($0) }
    }
}
