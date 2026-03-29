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
    let backgroundStyle: StreamDeckButtonBackgroundStyle
    let isPressed: Bool
    let style: Style

    var body: some View {
        let normalizedLabel = normalizedLabel
        let normalizedSecondaryLabel = normalizedSecondaryLabel
        let background = backgroundColor
        let foreground = Color.white
        let border = borderColor

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
                    .padding(8)
                    .scaleEffect(isPressed ? 0.75 : 1)
                    .foregroundStyle(foreground)
            }
        }
    }

    @ViewBuilder
    private func content(label: String?, secondaryLabel: String?) -> some View {
        if let appIcon = appIconImage, let label {
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
