import Foundation
@preconcurrency import IOKit.hid

final class StreamDeckManager: @unchecked Sendable {
    var onDeviceConnected: @Sendable (StreamDeckDeviceSnapshot) -> Void = { _ in }
    var onDeviceDisconnected: @Sendable (String) -> Void = { _ in }
    var onButtonEvent: @Sendable (String, ButtonEvent) -> Void = { _, _ in }

    private let queue = DispatchQueue(label: "io.deckapp.deck.hid", qos: .userInitiated)
    private let manager: IOHIDManager
    private var devicesByID: [String: StreamDeckDevice] = [:]
    private var hasStarted = false
    private let lifecycleLock = NSLock()

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        let matchingDictionaries = StreamDeckModel.allCases.map { model in
            [
                kIOHIDVendorIDKey as String: StreamDeckModel.vendorID,
                kIOHIDProductIDKey as String: Int(model.rawValue),
            ] as NSDictionary
        }

        IOHIDManagerSetDeviceMatchingMultiple(manager, matchingDictionaries as CFArray)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, Self.handleDeviceMatching, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerRegisterDeviceRemovalCallback(manager, Self.handleDeviceRemoval, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerRegisterInputReportCallback(manager, Self.handleInputReport, Unmanaged.passUnretained(self).toOpaque())
    }

    deinit {
        IOHIDManagerCancel(manager)
    }

    func start() {
        lifecycleLock.lock()
        let shouldStart = !hasStarted
        if shouldStart {
            hasStarted = true
        }
        lifecycleLock.unlock()

        guard shouldStart else {
            return
        }

        IOHIDManagerSetDispatchQueue(manager, queue)
        queue.async { [manager] in
            IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerActivate(manager)
        }
    }

    func sendButtonImage(_ data: Data, to buttonIndex: Int, on deviceID: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self, let device = self.devicesByID[deviceID] else {
                    continuation.resume()
                    return
                }

                do {
                    try device.sendButtonImageData(data, at: buttonIndex)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func setBrightness(_ brightness: Int, on deviceID: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self, let device = self.devicesByID[deviceID] else {
                    continuation.resume()
                    return
                }

                do {
                    try device.setBrightness(brightness)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func connect(device: IOHIDDevice) {
        do {
            let streamDeckDevice = try StreamDeckDevice(device: device)
            streamDeckDevice.onButtonEvent = { [weak self, deviceID = streamDeckDevice.id] event in
                self?.onButtonEvent(deviceID, event)
            }

            devicesByID[streamDeckDevice.id] = streamDeckDevice
            onDeviceConnected(streamDeckDevice.snapshot)
        } catch {
            print("[HID] Failed to open Stream Deck device: \(error)")
        }
    }

    private func disconnect(device: IOHIDDevice) {
        let deviceID = StreamDeckDevice.makeIdentifier(for: device, model: inferredModel(for: device))

        guard devicesByID.removeValue(forKey: deviceID) != nil else {
            return
        }
        onDeviceDisconnected(deviceID)
    }

    private func inferredModel(for device: IOHIDDevice) -> StreamDeckModel {
        let vendorID = StreamDeckDevice.intProperty(for: kIOHIDVendorIDKey as CFString, on: device) ?? 0
        let productID = StreamDeckDevice.intProperty(for: kIOHIDProductIDKey as CFString, on: device) ?? 0
        return StreamDeckModel(vendorID: vendorID, productID: productID) ?? .mk2
    }

    private static let handleDeviceMatching: IOHIDDeviceCallback = { context, _, _, device in
        guard let context else {
            return
        }

        let manager = Unmanaged<StreamDeckManager>.fromOpaque(context).takeUnretainedValue()
        manager.queue.async {
            manager.connect(device: device)
        }
    }

    private static let handleDeviceRemoval: IOHIDDeviceCallback = { context, _, _, device in
        guard let context else {
            return
        }

        let manager = Unmanaged<StreamDeckManager>.fromOpaque(context).takeUnretainedValue()
        manager.queue.async {
            manager.disconnect(device: device)
        }
    }

    private static let handleInputReport: IOHIDReportCallback = { context, _, sender, _, _, report, reportLength in
        guard let context else {
            return
        }

        let manager = Unmanaged<StreamDeckManager>.fromOpaque(context).takeUnretainedValue()
        let device = unsafeBitCast(sender, to: IOHIDDevice.self)
        let deviceID = StreamDeckDevice.makeIdentifier(for: device, model: manager.inferredModel(for: device))

        guard let streamDeckDevice = manager.devicesByID[deviceID] else {
            return
        }

        let buffer = UnsafeBufferPointer(start: report, count: reportLength)
        streamDeckDevice.handleInputReport(buffer)
    }
}
