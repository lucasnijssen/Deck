import AppKit
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

enum ButtonImageRendererError: Error {
    case failedToRenderView
    case failedToProcessImage
    case failedToEncodeImage
}

enum StreamDeckButtonBackgroundStyle: Sendable {
    case empty
    case standard
    case black
}

enum StreamDeckButtonAppIconStyle: Sendable {
    case inline
    case fullKey
}

struct StreamDeckButtonFaceView: View {
    enum Style {
        case editor
        case device
    }

    static let cornerRadius: CGFloat = 18
    static let borderWidth: CGFloat = 1.5

    let systemName: String?
    let appIconBundleIdentifier: String?
    let appIconStyle: StreamDeckButtonAppIconStyle
    let label: String?
    let secondaryLabel: String?
    let timeStyle: TimeAction.Style?
    let timeDate: Date?
    let backgroundStyle: StreamDeckButtonBackgroundStyle
    let isPressed: Bool
    let style: Style

    init(
        systemName: String?,
        appIconBundleIdentifier: String?,
        appIconStyle: StreamDeckButtonAppIconStyle,
        label: String?,
        secondaryLabel: String?,
        timeStyle: TimeAction.Style? = nil,
        timeDate: Date? = nil,
        backgroundStyle: StreamDeckButtonBackgroundStyle,
        isPressed: Bool,
        style: Style
    ) {
        self.systemName = systemName
        self.appIconBundleIdentifier = appIconBundleIdentifier
        self.appIconStyle = appIconStyle
        self.label = label
        self.secondaryLabel = secondaryLabel
        self.timeStyle = timeStyle
        self.timeDate = timeDate
        self.backgroundStyle = backgroundStyle
        self.isPressed = isPressed
        self.style = style
    }

    var body: some View {
        let normalizedLabel = normalizedLabel
        let normalizedSecondaryLabel = normalizedSecondaryLabel
        let background = backgroundColor
        let foreground = Color.white
        let border = borderColor
        let contentPadding = contentPadding

        if let appIcon = appIconImage, isFullKeyAppIcon {
            ZStack {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .fill(Color.black)

                Image(nsImage: appIcon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
            }
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
            .scaleEffect(isPressed ? 0.75 : 1)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .fill(background)
                    .overlay {
                        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                            .strokeBorder(border, lineWidth: Self.borderWidth)
                    }

                content(label: normalizedLabel, secondaryLabel: normalizedSecondaryLabel)
                    .padding(contentPadding)
                    .scaleEffect(isPressed ? 0.75 : 1)
                    .foregroundStyle(foreground)
            }
        }
    }

    @ViewBuilder
    private func content(label: String?, secondaryLabel: String?) -> some View {
        if let timeStyle, let timeDate {
            timeContent(style: timeStyle, date: timeDate, caption: secondaryLabel)
        } else if let appIcon = appIconImage, let label {
            VStack(spacing: 6) {
                Spacer(minLength: 0)
                Image(nsImage: appIcon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                labeledText(label: label, secondaryLabel: secondaryLabel)
                Spacer(minLength: 0)
            }
        } else if let systemName, let label {
            VStack(spacing: 6) {
                Spacer(minLength: 0)
                Image(systemName: systemName)
                    .font(.system(size: 26, weight: .semibold))
                labeledText(label: label, secondaryLabel: secondaryLabel)
                Spacer(minLength: 0)
            }
        } else if let appIcon = appIconImage {
            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else if let systemName {
            Image(systemName: systemName)
                .font(.system(size: 28, weight: .semibold))
        } else if let label {
            if let secondaryLabel {
                VStack(spacing: 2) {
                    Spacer(minLength: 0)
                    Text(label)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(secondaryLabel)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(Color.white.opacity(0.82))
                    Spacer(minLength: 0)
                }
            } else {
                Text(label)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }

    @ViewBuilder
    private func timeContent(style: TimeAction.Style, date: Date, caption: String?) -> some View {
        switch style {
        case .digital:
            digitalTimeContent(date: date, caption: caption)
        case .analog:
            analogTimeContent(date: date, caption: caption)
        }
    }

    @ViewBuilder
    private func digitalTimeContent(date: Date, caption: String?) -> some View {
        let timeString = digitalTimeString(for: date)

        if let caption {
            VStack(spacing: 3) {
                Spacer(minLength: 0)
                Text(timeString)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                Text(caption)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(Color.white.opacity(0.82))
                Spacer(minLength: 0)
            }
        } else {
            Text(timeString)
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
        }
    }

    @ViewBuilder
    private func analogTimeContent(date: Date, caption: String?) -> some View {
        let _ = caption

        AnalogClockFace(date: date)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func labeledText(label: String, secondaryLabel: String?) -> some View {
        Text(label)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .lineLimit(2)
            .minimumScaleFactor(0.55)
            .multilineTextAlignment(.center)

        if let secondaryLabel {
            Text(secondaryLabel)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Color.white.opacity(0.82))
        }
    }

    private var normalizedLabel: String? {
        normalize(label)
    }

    private var normalizedSecondaryLabel: String? {
        normalize(secondaryLabel)
    }

    private func normalize(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var backgroundColor: Color {
        switch backgroundStyle {
        case .empty:
            switch style {
            case .editor:
                return Color(nsColor: .quaternaryLabelColor).opacity(0.22)
            case .device:
                return .black
            }
        case .standard:
            return Color(red: 0.12, green: 0.16, blue: 0.22)
        case .black:
            return .black
        }
    }

    private var borderColor: Color {
        switch backgroundStyle {
        case .empty:
            switch style {
            case .editor:
                return Color.black.opacity(0.08)
            case .device:
                return .clear
            }
        case .standard, .black:
            return Color.white.opacity(0.08)
        }
    }

    private var appIconImage: NSImage? {
        guard
            let appIconBundleIdentifier,
            let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appIconBundleIdentifier)
        else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 64, height: 64)
        return icon
    }

    private var isFullKeyAppIcon: Bool {
        appIconStyle == .fullKey
    }

    private var contentPadding: CGFloat {
        if timeStyle == .analog {
            return 0
        }

        return 8
    }

    private func digitalTimeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

private struct AnalogClockFace: View {
    let date: Date

    var body: some View {
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
        let hour = Double(components.hour ?? 0).truncatingRemainder(dividingBy: 12)
        let minute = Double(components.minute ?? 0)
        let hourAngle = Angle.degrees((hour + (minute / 60)) * 30)
        let minuteAngle = Angle.degrees(minute * 6)

        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let dialInset = size * 0.035
            let handHubSize = size * 0.065
            let handColor = Color.white

            ZStack {
                Canvas { context, canvasSize in
                    let rect = CGRect(origin: .zero, size: canvasSize).insetBy(dx: dialInset, dy: dialInset)
                    let cornerRadius = min(StreamDeckButtonFaceView.cornerRadius - 1, rect.width / 4, rect.height / 4)
                    let tickCount = 56

                    for index in 0..<tickCount {
                        let isMajorTick = index.isMultiple(of: 7)
                        let tickLength = isMajorTick ? size * 0.115 : size * 0.07
                        let angle = (Double(index) / Double(tickCount)) * 360
                        let outerPoint = perimeterPoint(in: rect, cornerRadius: cornerRadius, angleDegrees: angle)
                        let innerPoint = pointTowardCenter(from: outerPoint, in: rect, distance: tickLength)

                        var tickPath = Path()
                        tickPath.move(to: outerPoint)
                        tickPath.addLine(to: innerPoint)

                        context.stroke(
                            tickPath,
                            with: .color(.white),
                            style: StrokeStyle(
                                lineWidth: isMajorTick ? size * 0.023 : size * 0.014,
                                lineCap: .round
                            )
                        )
                    }
                }

                watchHand(length: size * 0.25, width: size * 0.04, color: handColor, angle: hourAngle)
                watchHand(length: size * 0.37, width: size * 0.028, color: handColor, angle: minuteAngle)

                Circle()
                    .fill(handColor)
                    .frame(width: handHubSize, height: handHubSize)
            }
        }
    }

    private func watchHand(length: CGFloat, width: CGFloat, color: Color, angle: Angle) -> some View {
        RoundedRectangle(cornerRadius: width, style: .continuous)
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -length / 2)
            .rotationEffect(angle)
    }

    private func pointTowardCenter(from point: CGPoint, in rect: CGRect, distance: CGFloat) -> CGPoint {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let dx = center.x - point.x
        let dy = center.y - point.y
        let length = max(sqrt((dx * dx) + (dy * dy)), 0.001)

        return CGPoint(
            x: point.x + ((dx / length) * distance),
            y: point.y + ((dy / length) * distance)
        )
    }

    private func perimeterPoint(in rect: CGRect, cornerRadius: CGFloat, angleDegrees: Double) -> CGPoint {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radians = (angleDegrees - 90) * .pi / 180
        let direction = CGPoint(x: cos(radians), y: sin(radians))
        let cornerCenters = [
            CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
            CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
            CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
            CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius)
        ]

        var bestT = CGFloat.greatestFiniteMagnitude
        var bestPoint = CGPoint(x: center.x + (direction.x * rect.width), y: center.y + (direction.y * rect.height))

        func consider(_ t: CGFloat) {
            guard t > 0, t < bestT else {
                return
            }

            bestT = t
            bestPoint = CGPoint(x: center.x + (direction.x * t), y: center.y + (direction.y * t))
        }

        if abs(direction.x) > 0.0001 {
            for x in [rect.minX, rect.maxX] {
                let t = (x - center.x) / direction.x
                let y = center.y + (direction.y * t)
                if y >= rect.minY + cornerRadius && y <= rect.maxY - cornerRadius {
                    consider(t)
                }
            }
        }

        if abs(direction.y) > 0.0001 {
            for y in [rect.minY, rect.maxY] {
                let t = (y - center.y) / direction.y
                let x = center.x + (direction.x * t)
                if x >= rect.minX + cornerRadius && x <= rect.maxX - cornerRadius {
                    consider(t)
                }
            }
        }

        for cornerCenter in cornerCenters {
            let dx = center.x - cornerCenter.x
            let dy = center.y - cornerCenter.y
            let b = 2 * ((direction.x * dx) + (direction.y * dy))
            let c = (dx * dx) + (dy * dy) - (cornerRadius * cornerRadius)
            let discriminant = (b * b) - (4 * c)

            guard discriminant >= 0 else {
                continue
            }

            let sqrtDiscriminant = sqrt(discriminant)
            let solutions = [(-b - sqrtDiscriminant) / 2, (-b + sqrtDiscriminant) / 2]

            for t in solutions where t > 0 {
                let point = CGPoint(x: center.x + (direction.x * t), y: center.y + (direction.y * t))
                let inMatchingCorner =
                    (point.x <= rect.minX + cornerRadius || point.x >= rect.maxX - cornerRadius) &&
                    (point.y <= rect.minY + cornerRadius || point.y >= rect.maxY - cornerRadius)

                if inMatchingCorner {
                    consider(t)
                }
            }
        }

        return bestPoint
    }
}

@MainActor
final class ButtonImageRenderer {
    func render<Content: View>(_ content: Content, for model: StreamDeckModel) throws -> Data {
        let resolution = model.buttonImageResolution
        let targetSize = CGSize(width: resolution.width, height: resolution.height)

        let renderer = ImageRenderer(
            content: content
                .frame(width: targetSize.width, height: targetSize.height)
                .background(Color.black)
        )
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(targetSize)

        guard let renderedImage = renderer.cgImage else {
            throw ButtonImageRendererError.failedToRenderView
        }

        guard let processedImage = processedImage(from: renderedImage, format: model.buttonImageFormat, targetSize: targetSize) else {
            throw ButtonImageRendererError.failedToProcessImage
        }

        return try encode(processedImage, using: model.buttonImageFormat.encoding)
    }

    func renderSolidColor(_ color: Color, for model: StreamDeckModel) throws -> Data {
        try render(
            Rectangle()
                .fill(color),
            for: model
        )
    }

    func renderSymbol(_ systemName: String, label: String, for model: StreamDeckModel, isPressed: Bool = false) throws -> Data {
        try render(
            StreamDeckButtonFaceView(
                systemName: systemName,
                appIconBundleIdentifier: nil,
                appIconStyle: .inline,
                label: label,
                secondaryLabel: nil,
                backgroundStyle: .standard,
                isPressed: isPressed,
                style: .device
            ),
            for: model
        )
    }

    func renderEmptyButton(for model: StreamDeckModel, isPressed: Bool = false) throws -> Data {
        try render(
            StreamDeckButtonFaceView(
                systemName: nil,
                appIconBundleIdentifier: nil,
                appIconStyle: .inline,
                label: nil,
                secondaryLabel: nil,
                backgroundStyle: .empty,
                isPressed: isPressed,
                style: .device
            ),
            for: model
        )
    }

    func renderButton(
        systemName: String?,
        appIconBundleIdentifier: String?,
        appIconStyle: StreamDeckButtonAppIconStyle = .inline,
        label: String?,
        secondaryLabel: String? = nil,
        timeStyle: TimeAction.Style? = nil,
        timeDate: Date? = nil,
        backgroundStyle: StreamDeckButtonBackgroundStyle,
        for model: StreamDeckModel,
        isPressed: Bool = false
    ) throws -> Data {
        try render(
            StreamDeckButtonFaceView(
                systemName: systemName,
                appIconBundleIdentifier: appIconBundleIdentifier,
                appIconStyle: appIconStyle,
                label: label,
                secondaryLabel: secondaryLabel,
                timeStyle: timeStyle,
                timeDate: timeDate,
                backgroundStyle: backgroundStyle,
                isPressed: isPressed,
                style: .device
            ),
            for: model
        )
    }

    private func processedImage(from image: CGImage, format: ButtonImageFormat, targetSize: CGSize) -> CGImage? {
        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: Int(targetSize.width),
                height: Int(targetSize.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return nil
        }

        context.interpolationQuality = .high

        switch format.rotation {
        case .degrees180:
            context.translateBy(x: targetSize.width, y: targetSize.height)
            context.rotate(by: .pi)
        case .degrees90Clockwise:
            context.translateBy(x: targetSize.width, y: 0)
            context.rotate(by: .pi / 2)
        }

        context.draw(image, in: CGRect(origin: .zero, size: targetSize))
        return context.makeImage()
    }

    private func encode(_ image: CGImage, using encoding: ButtonImageEncoding) throws -> Data {
        switch encoding {
        case .jpeg(let quality):
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
                throw ButtonImageRendererError.failedToEncodeImage
            }

            CGImageDestinationAddImage(
                destination,
                image,
                [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
            )

            guard CGImageDestinationFinalize(destination) else {
                throw ButtonImageRendererError.failedToEncodeImage
            }

            return data as Data

        case .bmp:
            guard let data = NSBitmapImageRep(cgImage: image).representation(using: .bmp, properties: [:]) else {
                throw ButtonImageRendererError.failedToEncodeImage
            }

            return data
        }
    }
}
