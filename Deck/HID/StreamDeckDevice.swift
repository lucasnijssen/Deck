import Foundation
@preconcurrency import IOKit.hid

struct ButtonEvent: Sendable {
    let index: Int
    let pressed: Bool
}

struct ButtonGrid: Sendable {
    let rows: Int
    let columns: Int
}

struct ButtonImageResolution: Sendable {
    let width: Int
    let height: Int
}

enum ButtonImageEncoding: Sendable {
    case jpeg(quality: CGFloat)
    case bmp
}

enum ButtonImageRotation: Sendable {
    case degrees90Clockwise
    case degrees180
}

struct ButtonImageFormat: Sendable {
    let encoding: ButtonImageEncoding
    let rotation: ButtonImageRotation
}

enum StreamDeckModel: UInt32, CaseIterable, Identifiable, Sendable {
    static let vendorID: Int = 0x0FD9

    case mini = 0x0063
    case xl = 0x006C
    case mk2 = 0x0080

    var id: UInt32 { rawValue }

    var displayName: String {
        switch self {
        case .mini:
            "Stream Deck Mini"
        case .xl:
            "Stream Deck XL"
        case .mk2:
            "Stream Deck MK.2"
        }
    }

    var grid: ButtonGrid {
        switch self {
        case .mini:
            ButtonGrid(rows: 2, columns: 3)
        case .xl:
            ButtonGrid(rows: 4, columns: 8)
        case .mk2:
            ButtonGrid(rows: 3, columns: 5)
        }
    }

    var buttonImageResolution: ButtonImageResolution {
        switch self {
        case .mini:
            ButtonImageResolution(width: 80, height: 80)
        case .xl:
            ButtonImageResolution(width: 96, height: 96)
        case .mk2:
            ButtonImageResolution(width: 72, height: 72)
        }
    }

    var buttonImageFormat: ButtonImageFormat {
        switch self {
        case .mini:
            ButtonImageFormat(encoding: .bmp, rotation: .degrees90Clockwise)
        case .xl, .mk2:
            ButtonImageFormat(encoding: .jpeg(quality: 0.92), rotation: .degrees180)
        }
    }

    var buttonCount: Int {
        grid.rows * grid.columns
    }

    var supportsBrightness: Bool {
        switch self {
        case .mini:
            false
        case .xl, .mk2:
            true
        }
    }

    init?(vendorID: Int, productID: Int) {
        guard vendorID == Self.vendorID else {
            return nil
        }

        self.init(rawValue: UInt32(productID))
    }
}

struct StreamDeckDeviceSnapshot: Identifiable, Sendable {
    let id: String
    let name: String
    let model: StreamDeckModel
    let grid: ButtonGrid
    let buttonImageResolution: ButtonImageResolution
}

extension StreamDeckDeviceSnapshot {
    static let previewMK2 = StreamDeckDeviceSnapshot(
        id: "preview-mk2",
        name: "Preview Stream Deck MK.2",
        model: .mk2,
        grid: StreamDeckModel.mk2.grid,
        buttonImageResolution: StreamDeckModel.mk2.buttonImageResolution
    )
}

enum StreamDeckDeviceError: Error {
    case unsupportedDevice
    case unsupportedButtonIndex
    case unsupportedBrightness
    case failedToSendFeatureReport(IOReturn)
}

final class StreamDeckDevice: Identifiable, @unchecked Sendable {
    let id: String
    let name: String
    let model: StreamDeckModel
    let grid: ButtonGrid
    let buttonImageResolution: ButtonImageResolution

    var snapshot: StreamDeckDeviceSnapshot {
        StreamDeckDeviceSnapshot(
            id: id,
            name: name,
            model: model,
            grid: grid,
            buttonImageResolution: buttonImageResolution
        )
    }

    var onButtonEvent: (@Sendable (ButtonEvent) -> Void)?

    private let device: IOHIDDevice
    private let imageSender: ButtonImageSender
    private var inputHandler: ButtonInputHandler
    private let maxFeatureReportLength: Int

    init(device: IOHIDDevice) throws {
        guard
            let vendorID = Self.intProperty(for: kIOHIDVendorIDKey as CFString, on: device),
            let productID = Self.intProperty(for: kIOHIDProductIDKey as CFString, on: device),
            let model = StreamDeckModel(vendorID: vendorID, productID: productID)
        else {
            throw StreamDeckDeviceError.unsupportedDevice
        }
        self.device = device
        self.model = model
        self.grid = model.grid
        self.buttonImageResolution = model.buttonImageResolution
        self.inputHandler = ButtonInputHandler(model: model)
        self.name = Self.stringProperty(for: kIOHIDProductKey as CFString, on: device) ?? model.displayName
        self.id = Self.makeIdentifier(for: device, model: model)
        self.imageSender = ButtonImageSender(device: device, model: model)
        self.maxFeatureReportLength = Self.intProperty(for: kIOHIDMaxFeatureReportSizeKey as CFString, on: device) ?? 32
    }

    func handleInputReport(_ report: UnsafeBufferPointer<UInt8>) {
        for event in inputHandler.parse(report: report) {
            onButtonEvent?(event)
        }
    }

    func sendButtonImageData(_ data: Data, at index: Int) throws {
        guard (0..<model.buttonCount).contains(index) else {
            throw StreamDeckDeviceError.unsupportedButtonIndex
        }

        try imageSender.sendImageData(data, to: index)
    }

    func setBrightness(_ brightness: Int) throws {
        guard model.supportsBrightness else {
            throw StreamDeckDeviceError.unsupportedBrightness
        }

        let clampedBrightness = UInt8(max(0, min(100, brightness)))
        var report = [UInt8](repeating: 0, count: max(32, maxFeatureReportLength))
        report[0] = 0x03
        report[1] = 0x08
        report[2] = clampedBrightness

        let status = report.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return kIOReturnBadArgument
            }

            return IOHIDDeviceSetReport(
                device,
                kIOHIDReportTypeFeature,
                CFIndex(report[0]),
                baseAddress,
                buffer.count
            )
        }

        guard status == kIOReturnSuccess else {
            throw StreamDeckDeviceError.failedToSendFeatureReport(status)
        }
    }

    static func makeIdentifier(for device: IOHIDDevice, model: StreamDeckModel) -> String {
        if let serialNumber = stringProperty(for: kIOHIDSerialNumberKey as CFString, on: device), !serialNumber.isEmpty {
            return serialNumber
        }

        if let locationID = intProperty(for: kIOHIDLocationIDKey as CFString, on: device) {
            return "\(model.rawValue)-\(locationID)"
        }

        return "\(model.rawValue)-\(Int(bitPattern: Unmanaged.passUnretained(device).toOpaque()))"
    }

    static func intProperty(for key: CFString, on device: IOHIDDevice) -> Int? {
        guard let value = IOHIDDeviceGetProperty(device, key) else {
            return nil
        }

        if let number = value as? NSNumber {
            return number.intValue
        }

        return nil
    }

    static func stringProperty(for key: CFString, on device: IOHIDDevice) -> String? {
        guard let value = IOHIDDeviceGetProperty(device, key) else {
            return nil
        }

        return value as? String
    }
}
