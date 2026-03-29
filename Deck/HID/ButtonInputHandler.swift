import Foundation

struct ButtonInputHandler {
    private let model: StreamDeckModel
    private var previousStates: [Bool]

    init(model: StreamDeckModel) {
        self.model = model
        self.previousStates = Array(repeating: false, count: model.buttonCount)
    }

    mutating func parse(report: UnsafeBufferPointer<UInt8>) -> [ButtonEvent] {
        guard let currentStates = decodeButtonStates(from: report) else {
            return []
        }

        var events: [ButtonEvent] = []
        events.reserveCapacity(model.buttonCount)

        for index in 0..<min(previousStates.count, currentStates.count) {
            guard previousStates[index] != currentStates[index] else {
                continue
            }

            events.append(ButtonEvent(index: index, pressed: currentStates[index]))
        }

        previousStates = currentStates
        return events
    }

    private func decodeButtonStates(from report: UnsafeBufferPointer<UInt8>) -> [Bool]? {
        switch model {
        case .mini:
            return decodeMiniReport(report)
        case .mk2, .xl:
            return decodeStandardReport(report)
        }
    }

    private func decodeMiniReport(_ report: UnsafeBufferPointer<UInt8>) -> [Bool]? {
        guard report.count >= 1 + model.buttonCount, report[0] == 0x01 else {
            return nil
        }

        return Array(report[1..<(1 + model.buttonCount)].map { $0 != 0 })
    }

    private func decodeStandardReport(_ report: UnsafeBufferPointer<UInt8>) -> [Bool]? {
        guard report.count >= 4, report[0] == 0x01 else {
            return nil
        }

        let declaredLength = Int(report[2]) | (Int(report[3]) << 8)
        let availablePayloadCount = max(0, report.count - 4)
        let payloadCount = min(model.buttonCount, declaredLength, availablePayloadCount)

        guard payloadCount == model.buttonCount else {
            return nil
        }

        return Array(report[4..<(4 + payloadCount)].map { $0 != 0 })
    }
}
