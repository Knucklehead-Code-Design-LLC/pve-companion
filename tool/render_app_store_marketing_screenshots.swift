#!/usr/bin/env swift

import AppKit
import Foundation

enum PlatformFamily {
  case iPhone
  case iPad
  case mac
}

struct ScreenshotSpecification {
  let platform: PlatformFamily
  let filename: String
  let headline: String
  let accent: NSColor

  var directory: String {
    switch platform {
    case .iPhone:
      return "iphone-6.9"
    case .iPad:
      return "ipad-13"
    case .mac:
      return "mac"
    }
  }
}

let screenshots: [ScreenshotSpecification] = [
  ScreenshotSpecification(
    platform: .iPhone,
    filename: "01-datacenter-overview.jpg",
    headline: "Health,\nat a glance.",
    accent: NSColor(srgbRed: 0.04, green: 0.52, blue: 1, alpha: 1)
  ),
  ScreenshotSpecification(
    platform: .iPhone,
    filename: "02-guest-inventory.jpg",
    headline: "Every guest,\nin clear view.",
    accent: NSColor(srgbRed: 0.13, green: 0.72, blue: 0.74, alpha: 1)
  ),
  ScreenshotSpecification(
    platform: .iPhone,
    filename: "03-node-health.jpg",
    headline: "Know which nodes\nneed attention.",
    accent: NSColor(srgbRed: 0.19, green: 0.82, blue: 0.40, alpha: 1)
  ),
  ScreenshotSpecification(
    platform: .iPhone,
    filename: "04-storage-inventory.jpg",
    headline: "Capacity,\nmade clear.",
    accent: NSColor(srgbRed: 0.42, green: 0.36, blue: 0.92, alpha: 1)
  ),
  ScreenshotSpecification(
    platform: .iPhone,
    filename: "05-recent-tasks.jpg",
    headline: "Every task,\nin one place.",
    accent: NSColor(srgbRed: 1, green: 0.62, blue: 0.12, alpha: 1)
  ),
  ScreenshotSpecification(
    platform: .iPad,
    filename: "01-datacenter-overview.jpg",
    headline: "Health,\nat a glance.",
    accent: NSColor(srgbRed: 0.04, green: 0.52, blue: 1, alpha: 1)
  ),
  ScreenshotSpecification(
    platform: .iPad,
    filename: "02-guest-inventory.jpg",
    headline: "Every guest,\nin clear view.",
    accent: NSColor(srgbRed: 0.13, green: 0.72, blue: 0.74, alpha: 1)
  ),
  ScreenshotSpecification(
    platform: .iPad,
    filename: "03-node-health.jpg",
    headline: "Know which nodes\nneed attention.",
    accent: NSColor(srgbRed: 0.19, green: 0.82, blue: 0.40, alpha: 1)
  ),
  ScreenshotSpecification(
    platform: .iPad,
    filename: "04-storage-inventory.jpg",
    headline: "Capacity,\nmade clear.",
    accent: NSColor(srgbRed: 0.42, green: 0.36, blue: 0.92, alpha: 1)
  ),
  ScreenshotSpecification(
    platform: .iPad,
    filename: "05-recent-tasks.jpg",
    headline: "Every task,\nin one place.",
    accent: NSColor(srgbRed: 1, green: 0.62, blue: 0.12, alpha: 1)
  ),
  ScreenshotSpecification(
    platform: .mac,
    filename: "01-datacenter-overview.jpg",
    headline: "Health at a glance.",
    accent: NSColor(srgbRed: 0.04, green: 0.52, blue: 1, alpha: 1)
  ),
  ScreenshotSpecification(
    platform: .mac,
    filename: "02-guest-inventory.jpg",
    headline: "Every guest, in clear view.",
    accent: NSColor(srgbRed: 0.13, green: 0.72, blue: 0.74, alpha: 1)
  ),
  ScreenshotSpecification(
    platform: .mac,
    filename: "03-node-health.jpg",
    headline: "Know which nodes need attention.",
    accent: NSColor(srgbRed: 0.19, green: 0.82, blue: 0.40, alpha: 1)
  ),
  ScreenshotSpecification(
    platform: .mac,
    filename: "04-storage-inventory.jpg",
    headline: "Capacity, made clear.",
    accent: NSColor(srgbRed: 0.42, green: 0.36, blue: 0.92, alpha: 1)
  ),
  ScreenshotSpecification(
    platform: .mac,
    filename: "05-recent-tasks.jpg",
    headline: "Every task, in one place.",
    accent: NSColor(srgbRed: 1, green: 0.62, blue: 0.12, alpha: 1)
  ),
]

enum RenderError: LocalizedError {
  case missingImage(URL)
  case imageEncodingFailed(URL)
  case unsupportedArguments

  var errorDescription: String? {
    switch self {
    case let .missingImage(url):
      return "Could not load required image at \(url.path)."
    case let .imageEncodingFailed(url):
      return "Could not encode JPEG output at \(url.path)."
    case .unsupportedArguments:
      return "usage: swift tool/render_app_store_marketing_screenshots.swift"
    }
  }
}

func rect(
  fromTop top: CGFloat,
  x: CGFloat,
  width: CGFloat,
  height: CGFloat,
  canvas: NSSize
) -> NSRect {
  NSRect(x: x, y: canvas.height - top - height, width: width, height: height)
}

func drawText(
  _ string: String,
  in rect: NSRect,
  font: NSFont,
  color: NSColor,
  lineSpacing: CGFloat = 0,
  letterSpacing: CGFloat = 0
) {
  let paragraphStyle = NSMutableParagraphStyle()
  paragraphStyle.lineBreakMode = .byWordWrapping
  paragraphStyle.lineSpacing = lineSpacing

  let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: color,
    .paragraphStyle: paragraphStyle,
    .kern: letterSpacing,
  ]
  NSAttributedString(string: string, attributes: attributes).draw(
    with: rect,
    options: [.usesLineFragmentOrigin, .usesFontLeading]
  )
}

func drawRoundedImage(_ image: NSImage, in rect: NSRect, radius: CGFloat) {
  let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

  NSGraphicsContext.saveGraphicsState()
  let shadow = NSShadow()
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.42)
  shadow.shadowBlurRadius = 28
  shadow.shadowOffset = NSSize(width: 0, height: -12)
  shadow.set()
  NSColor.black.withAlphaComponent(0.9).setFill()
  path.fill()
  NSGraphicsContext.restoreGraphicsState()

  NSGraphicsContext.saveGraphicsState()
  path.addClip()
  NSGraphicsContext.current?.imageInterpolation = .high
  image.draw(in: rect)
  NSGraphicsContext.restoreGraphicsState()

  NSColor.white.withAlphaComponent(0.28).setStroke()
  path.lineWidth = 1
  path.stroke()
}

func drawBrandMark(_ mark: NSImage, in rect: NSRect) {
  let path = NSBezierPath(
    roundedRect: rect,
    xRadius: rect.width * 0.22,
    yRadius: rect.width * 0.22
  )
  NSGraphicsContext.saveGraphicsState()
  path.addClip()
  mark.draw(in: rect)
  NSGraphicsContext.restoreGraphicsState()
}

func drawBackground(
  in context: CGContext,
  canvas: NSSize,
  accent: NSColor
) {
  let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
  let start = NSColor(srgbRed: 0.004, green: 0.055, blue: 0.22, alpha: 1)
  let end = NSColor(srgbRed: 0.01, green: 0.13, blue: 0.35, alpha: 1)
  let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [
      start.cgColor,
      end.cgColor,
      accent.withAlphaComponent(0.74).cgColor,
    ] as CFArray,
    locations: [0, 0.58, 1]
  )!
  context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: 0),
    end: CGPoint(x: canvas.width, y: canvas.height),
    options: []
  )

  context.saveGState()
  context.setFillColor(accent.withAlphaComponent(0.18).cgColor)
  context.fillEllipse(
    in: NSRect(
      x: canvas.width * 0.55,
      y: canvas.height * 0.57,
      width: canvas.width * 0.75,
      height: canvas.height * 0.55
    )
  )
  context.setFillColor(
    NSColor(srgbRed: 0.04, green: 0.68, blue: 0.88, alpha: 0.16).cgColor
  )
  context.fillEllipse(
    in: NSRect(
      x: -canvas.width * 0.28,
      y: -canvas.height * 0.09,
      width: canvas.width * 0.74,
      height: canvas.height * 0.44
    )
  )

  context.setStrokeColor(NSColor.white.withAlphaComponent(0.12).cgColor)
  context.setLineWidth(max(1, canvas.width / 900))
  let nodes = [
    CGPoint(x: canvas.width * 0.08, y: canvas.height * 0.82),
    CGPoint(x: canvas.width * 0.26, y: canvas.height * 0.92),
    CGPoint(x: canvas.width * 0.43, y: canvas.height * 0.78),
    CGPoint(x: canvas.width * 0.68, y: canvas.height * 0.93),
    CGPoint(x: canvas.width * 0.91, y: canvas.height * 0.78),
  ]
  context.move(to: nodes[0])
  for node in nodes.dropFirst() {
    context.addLine(to: node)
  }
  context.strokePath()

  for node in nodes {
    let nodeRect = NSRect(x: node.x - 7, y: node.y - 7, width: 14, height: 14)
    context.setFillColor(accent.withAlphaComponent(0.42).cgColor)
    context.fillEllipse(in: nodeRect)
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.45).cgColor)
    context.strokeEllipse(in: nodeRect)
  }
  context.restoreGState()
}

func render(
  specification: ScreenshotSpecification,
  source: NSImage,
  mark: NSImage
) -> NSImage {
  let canvas: NSSize
  let screenRect: NSRect
  let markRect: NSRect
  let labelRect: NSRect
  let headlineRect: NSRect
  let headlineFont: NSFont
  let labelFont: NSFont

  switch specification.platform {
  case .iPhone:
    canvas = NSSize(width: 1320, height: 2868)
    screenRect = rect(
      fromTop: 554,
      x: 141,
      width: 1038,
      height: 2254,
      canvas: canvas
    )
    markRect = rect(fromTop: 82, x: 96, width: 84, height: 84, canvas: canvas)
    labelRect = rect(fromTop: 101, x: 202, width: 540, height: 52, canvas: canvas)
    headlineRect = rect(
      fromTop: 235,
      x: 96,
      width: 1100,
      height: 245,
      canvas: canvas
    )
    headlineFont = .systemFont(ofSize: 98, weight: .bold)
    labelFont = .systemFont(ofSize: 34, weight: .semibold)
  case .iPad:
    canvas = NSSize(width: 2064, height: 2752)
    screenRect = rect(
      fromTop: 448,
      x: 177,
      width: 1710,
      height: 2280,
      canvas: canvas
    )
    markRect = rect(fromTop: 72, x: 132, width: 76, height: 76, canvas: canvas)
    labelRect = rect(fromTop: 92, x: 230, width: 720, height: 50, canvas: canvas)
    headlineRect = rect(
      fromTop: 202,
      x: 132,
      width: 1700,
      height: 210,
      canvas: canvas
    )
    headlineFont = .systemFont(ofSize: 96, weight: .bold)
    labelFont = .systemFont(ofSize: 32, weight: .semibold)
  case .mac:
    canvas = NSSize(width: 1280, height: 800)
    screenRect = rect(
      fromTop: 151,
      x: 140,
      width: 1000,
      height: 625,
      canvas: canvas
    )
    markRect = rect(fromTop: 34, x: 48, width: 45, height: 45, canvas: canvas)
    labelRect = rect(fromTop: 46, x: 108, width: 320, height: 28, canvas: canvas)
    headlineRect = rect(
      fromTop: 94,
      x: 48,
      width: 1120,
      height: 50,
      canvas: canvas
    )
    headlineFont = .systemFont(ofSize: 40, weight: .bold)
    labelFont = .systemFont(ofSize: 19, weight: .semibold)
  }

  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvas.width),
    pixelsHigh: Int(canvas.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bitmapFormat: [],
    bytesPerRow: 0,
    bitsPerPixel: 0
  )!
  let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)!

  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = graphicsContext
  drawBackground(in: graphicsContext.cgContext, canvas: canvas, accent: specification.accent)
  drawBrandMark(mark, in: markRect)
  drawText(
    "PVE COMPANION",
    in: labelRect,
    font: labelFont,
    color: NSColor.white.withAlphaComponent(0.9),
    letterSpacing: labelFont.pointSize * 0.08
  )
  drawText(
    specification.headline,
    in: headlineRect,
    font: headlineFont,
    color: .white,
    lineSpacing: headlineFont.pointSize * 0.04,
    letterSpacing: -headlineFont.pointSize * 0.025
  )
  drawRoundedImage(
    source,
    in: screenRect,
    radius: max(20, screenRect.width * 0.026)
  )
  NSGraphicsContext.restoreGraphicsState()

  let image = NSImage(size: canvas)
  image.addRepresentation(bitmap)
  return image
}

func writeJPEG(_ image: NSImage, to output: URL) throws {
  guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let jpeg = bitmap.representation(
      using: .jpeg,
      properties: [.compressionFactor: 0.94]
    )
  else {
    throw RenderError.imageEncodingFailed(output)
  }

  try FileManager.default.createDirectory(
    at: output.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try jpeg.write(to: output, options: .atomic)
}

func printUsage() {
  print("usage: swift tool/render_app_store_marketing_screenshots.swift")
}

do {
  let arguments = Array(CommandLine.arguments.dropFirst())
  if arguments == ["--help"] {
    printUsage()
    exit(EXIT_SUCCESS)
  }
  guard arguments.isEmpty else {
    throw RenderError.unsupportedArguments
  }

  let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
  let screenshotRoot = repositoryRoot.appendingPathComponent("docs/app-store/screenshots")
  let sourceRoot = screenshotRoot.appendingPathComponent("source/en-US")
  let outputRoot = screenshotRoot.appendingPathComponent("en-US")
  let markURL = repositoryRoot.appendingPathComponent("assets/brand/pve_companion_mark.png")
  guard let mark = NSImage(contentsOf: markURL) else {
    throw RenderError.missingImage(markURL)
  }

  for specification in screenshots {
    let sourceURL = sourceRoot
      .appendingPathComponent(specification.directory)
      .appendingPathComponent(specification.filename)
    let outputURL = outputRoot
      .appendingPathComponent(specification.directory)
      .appendingPathComponent(specification.filename)
    guard let source = NSImage(contentsOf: sourceURL) else {
      throw RenderError.missingImage(sourceURL)
    }
    try writeJPEG(
      render(specification: specification, source: source, mark: mark),
      to: outputURL
    )
    print("Rendered \(outputURL.path)")
  }
} catch {
  fputs("error: \(error.localizedDescription)\n", stderr)
  exit(EXIT_FAILURE)
}
