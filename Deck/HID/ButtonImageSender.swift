import Foundation
@preconcurrency import IOKit.hid

enum ButtonImageSenderError: Error {
    case failedToSendReport(IOReturn)
}

struct ButtonImageSender: @unchecked Sendable {
    private let device: IOHIDDevice
    private let model: StreamDeckModel

    init(device: IOHIDDevice, model: StreamDeckModel) {
        self.device = device
        self.model = model
    }

    func sendImageData(_ data: Data, to buttonIndex: Int) throws {
        switch model {
        case .mini:
            try sendMiniImageData(data, to: buttonIndex)
        case .mk2, .xl:
            try sendStandardImageData(data, to: buttonIndex)
        }
    }

    private func sendStandardImageData(_ data: Data, to buttonIndex: Int) throws {
        let reportID: UInt8 = 0x02
        let command: UInt8 = 0x07
        let reportLength = 1024
        let chunkPayloadLength = reportLength - 8
        let chunks = max(1, Int(ceil(Double(data.count) / Double(chunkPayloadLength))))

        for chunkIndex in 0..<chunks {
            let start = chunkIndex * chunkPayloadLength
            let end = min(start + chunkPayloadLength, data.count)
            let chunk = data[start..<end]

            var report = [UInt8](repeating: 0, count: reportLength)
            report[0] = reportID
            report[1] = command
            report[2] = UInt8(buttonIndex)
            report[3] = chunkIndex == (chunks - 1) ? 0x01 : 0x00
            report[4] = UInt8(chunk.count & 0xFF)
            report[5] = UInt8((chunk.count >> 8) & 0xFF)
            report[6] = UInt8(chunkIndex & 0xFF)
            report[7] = UInt8((chunkIndex >> 8) & 0xFF)
            report.replaceSubrange(8..<(8 + chunk.count), with: chunk)

            try sendReport(type: kIOHIDReportTypeOutput, reportID: reportID, bytes: report)
        }
    }

    private func sendMiniImageData(_ data: Data, to buttonIndex: Int) throws {
        let reportID: UInt8 = 0x02
        let command: UInt8 = 0x01
        let reportLength = 1024
        let chunkPayloadLength = reportLength - 16
        let chunks = max(1, Int(ceil(Double(data.count) / Double(chunkPayloadLength))))

        for chunkIndex in 0..<chunks {
            let start = chunkIndex * chunkPayloadLength
            let end = min(start + chunkPayloadLength, data.count)
            let chunk = data[start..<end]

            var report = [UInt8](repeating: 0, count: reportLength)
            report[0] = reportID
            report[1] = command
            report[2] = UInt8(chunkIndex)
            report[4] = chunkIndex == (chunks - 1) ? 0x01 : 0x00
            report[5] = UInt8(buttonIndex)
            report.replaceSubrange(16..<(16 + chunk.count), with: chunk)

            try sendReport(type: kIOHIDReportTypeOutput, reportID: reportID, bytes: report)
        }
    }

    private func sendReport(type: IOHIDReportType, reportID: UInt8, bytes: [UInt8]) throws {
        let status = bytes.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return kIOReturnBadArgument
            }

            return IOHIDDeviceSetReport(
                device,
                type,
                CFIndex(reportID),
                baseAddress,
                buffer.count
            )
        }

        guard status == kIOReturnSuccess else {
            throw ButtonImageSenderError.failedToSendReport(status)
        }
    }
}
