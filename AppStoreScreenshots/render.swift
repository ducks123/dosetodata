#!/usr/bin/env swift

import AppKit
import ImageIO
import UniformTypeIdentifiers

private let designSize = NSSize(width: 1320, height: 2868)
private let outputSize = NSSize(width: 1242, height: 2688)
private let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppStoreScreenshots/final")
private let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

private struct Frame {
    let filename: String
    let source: String
    let headline: String
    let subhead: String
    let colors: [NSColor]
    let highlight: Highlight
}

private enum Highlight {
    case medicationChange
    case hideCheckInCTA
    case medicationReminder
    case none
}

private let frames: [Frame] = [
    Frame(
        filename: "01-clear-trends.png",
        source: "AppStoreScreenshots/raw/02-insights.png",
        headline: "Turn daily check-ins\ninto clear trends",
        subhead: "See your scores and medication changes together",
        colors: [hex("C9E5FF"), hex("D8F5E6"), hex("FFE0E8")],
        highlight: .medicationChange
    ),
    Frame(
        filename: "02-fast-check-in.png",
        source: "AppStoreScreenshots/raw/05-checkin-edit.png",
        headline: "Make check-ins\nyour own",
        subhead: "Choose what to track and add your own questions",
        colors: [hex("F1D8FF"), hex("CEE6FF"), hex("D9F5E7")],
        highlight: .hideCheckInCTA
    ),
    Frame(
        filename: "03-medication-context.png",
        source: "AppStoreScreenshots/raw/01-today.png",
        headline: "Your week at\na glance",
        subhead: "See today's score and every day you took your medication",
        colors: [hex("FFE2CF"), hex("F5DDF0"), hex("D7E8FF")],
        highlight: .none
    ),
    Frame(
        filename: "04-medication-schedule.png",
        source: "AppStoreScreenshots/raw/03-schedule.png",
        headline: "Never miss\na dose",
        subhead: "Get reminders when it's time to take your medication",
        colors: [hex("D5F3E5"), hex("FFF0C8"), hex("DDE4FF")],
        highlight: .medicationReminder
    ),
    Frame(
        filename: "05-appointment-picture.png",
        source: "AppStoreScreenshots/raw/04-checkin-detail.png",
        headline: "Your metrics.\nOne daily score.",
        subhead: "See how you're doing based on the questions you choose",
        colors: [hex("DCE6FF"), hex("EADDF8"), hex("FBE2E1")],
        highlight: .none
    ),
]

private func hex(_ value: String) -> NSColor {
    let scanner = Scanner(string: value)
    var number: UInt64 = 0
    scanner.scanHexInt64(&number)
    return NSColor(
        red: CGFloat((number >> 16) & 0xff) / 255,
        green: CGFloat((number >> 8) & 0xff) / 255,
        blue: CGFloat(number & 0xff) / 255,
        alpha: 1
    )
}

private func topRect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
    NSRect(x: x, y: designSize.height - y - height, width: width, height: height)
}

private func topPoint(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
    NSPoint(x: x, y: designSize.height - y)
}

private func drawText(
    _ text: String,
    in rect: NSRect,
    font: NSFont,
    color: NSColor,
    alignment: NSTextAlignment = .center,
    lineSpacing: CGFloat = 0
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineSpacing = lineSpacing
    paragraph.lineBreakMode = .byWordWrapping
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
    ]
    NSAttributedString(string: text, attributes: attributes).draw(in: rect)
}

private func drawRoundedImage(_ image: NSImage, in rect: NSRect, radius: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

private func fillRoundedRect(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

private func drawMedicationChangeCallout() {
    let calloutRect = topRect(590, 1460, 500, 92)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 22
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    shadow.set()
    fillRoundedRect(calloutRect, radius: 46, color: NSColor.white.withAlphaComponent(0.97))
    NSShadow().set()

    let accent = hex("27358B")
    fillRoundedRect(topRect(620, 1488, 34, 34), radius: 17, color: accent)
    drawText(
        "Medication changed here",
        in: topRect(675, 1480, 380, 48),
        font: .systemFont(ofSize: 27, weight: .semibold),
        color: hex("111827"),
        alignment: .left
    )

    let pointer = NSBezierPath()
    pointer.move(to: topPoint(635, 1552))
    pointer.line(to: topPoint(538, 1662))
    accent.setStroke()
    pointer.lineWidth = 6
    pointer.lineCapStyle = .round
    pointer.stroke()
    fillRoundedRect(topRect(526, 1650, 24, 24), radius: 12, color: accent)
}

private func drawMedicationReminder(icon: NSImage?) {
    let notificationRect = topRect(152, 800, 1016, 224)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
    shadow.shadowBlurRadius = 34
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    fillRoundedRect(notificationRect, radius: 52, color: NSColor.white.withAlphaComponent(0.97))
    NSShadow().set()

    if let icon {
        drawRoundedImage(icon, in: topRect(190, 838, 82, 82), radius: 20)
    }
    drawText(
        "DOSE TO DATA  |  NOW",
        in: topRect(300, 831, 760, 34),
        font: .systemFont(ofSize: 24, weight: .semibold),
        color: hex("667085"),
        alignment: .left
    )
    drawText(
        "Medication reminder",
        in: topRect(300, 874, 760, 44),
        font: .systemFont(ofSize: 33, weight: .semibold),
        color: hex("111827"),
        alignment: .left
    )
    drawText(
        "Time to take Wellbutrin XL 150mg",
        in: topRect(300, 925, 790, 42),
        font: .systemFont(ofSize: 28, weight: .regular),
        color: hex("344054"),
        alignment: .left
    )
}

private func render(_ frame: Frame) throws {
    guard let source = NSImage(contentsOf: projectRoot.appendingPathComponent(frame.source)) else {
        throw NSError(domain: "AppStoreScreenshots", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Could not open \(frame.source)"
        ])
    }

    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let cgContext = CGContext(
            data: nil,
            width: Int(designSize.width),
            height: Int(designSize.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(designSize.width) * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
          ) else {
        throw NSError(domain: "AppStoreScreenshots", code: 2)
    }
    let graphics = NSGraphicsContext(cgContext: cgContext, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    defer { NSGraphicsContext.restoreGraphicsState() }

    let canvas = NSRect(origin: .zero, size: designSize)
    NSGradient(colors: frame.colors)?.draw(in: canvas, angle: -38)

    let ink = hex("111827")
    let secondaryInk = hex("344054")
    let icon = NSImage(contentsOf: projectRoot.appendingPathComponent(
        "DoseToData/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
    ))

    if let icon {
        let iconRect = topRect(84, 70, 92, 92)
        drawRoundedImage(icon, in: iconRect, radius: 22)
    }
    drawText(
        "Dose to Data",
        in: topRect(196, 91, 500, 48),
        font: .systemFont(ofSize: 36, weight: .semibold),
        color: ink,
        alignment: .left
    )

    drawText(
        frame.headline,
        in: topRect(80, 215, 1160, 255),
        font: .systemFont(ofSize: 96, weight: .bold),
        color: ink,
        lineSpacing: 4
    )
    drawText(
        frame.subhead,
        in: topRect(110, 510, 1100, 70),
        font: .systemFont(ofSize: 40, weight: .medium),
        color: secondaryInk
    )

    let frameRect = topRect(92, 660, 1136, 2370)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
    shadow.shadowBlurRadius = 44
    shadow.shadowOffset = NSSize(width: 0, height: -18)
    shadow.set()
    hex("101828").setFill()
    NSBezierPath(roundedRect: frameRect, xRadius: 112, yRadius: 112).fill()
    NSShadow().set()

    let screenRect = topRect(118, 686, 1084, 2354)
    drawRoundedImage(source, in: screenRect, radius: 88)

    switch frame.highlight {
    case .medicationChange:
        drawMedicationChangeCallout()
    case .hideCheckInCTA:
        hex("F7F8FC").setFill()
        topRect(118, 2742, 1084, 298).fill()
    case .medicationReminder:
        drawMedicationReminder(icon: icon)
    case .none:
        break
    }

    guard let designImage = cgContext.makeImage(),
          let outputContext = CGContext(
            data: nil,
            width: Int(outputSize.width),
            height: Int(outputSize.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(outputSize.width) * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
          ) else {
        throw NSError(domain: "AppStoreScreenshots", code: 3)
    }

    let scale = max(outputSize.width / designSize.width, outputSize.height / designSize.height)
    let scaledSize = NSSize(width: designSize.width * scale, height: designSize.height * scale)
    let outputRect = NSRect(
        x: (outputSize.width - scaledSize.width) / 2,
        y: (outputSize.height - scaledSize.height) / 2,
        width: scaledSize.width,
        height: scaledSize.height
    )
    outputContext.interpolationQuality = .high
    outputContext.draw(designImage, in: outputRect)
    guard let outputImage = outputContext.makeImage() else {
        throw NSError(domain: "AppStoreScreenshots", code: 3)
    }

    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    let outputURL = outputDirectory.appendingPathComponent(frame.filename)
    guard let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw NSError(domain: "AppStoreScreenshots", code: 4)
    }
    CGImageDestinationAddImage(destination, outputImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "AppStoreScreenshots", code: 5)
    }
}

for frame in frames {
    try render(frame)
    print("Rendered \(frame.filename)")
}
