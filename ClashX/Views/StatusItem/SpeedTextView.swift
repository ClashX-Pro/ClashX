//
//  SpeedTextView.swift
//  ClashX
//
//  Custom NSView that draws speed text directly using NSString.draw(at:withAttributes:)
//  instead of NSTextField, to avoid the rendering loop bug on macOS 26+ (Tahoe)
//  where NSTextField in NSStatusBarButton causes infinite redraws and high CPU usage.
//

import AppKit

class SpeedTextView: NSView {
    private var upSpeed: String = "0KB/s"
    private var downSpeed: String = "0KB/s"

    override var isFlipped: Bool {
        true
    }

    var textWidth: CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: StatusItemTool.font]
        let upWidth = (upSpeed as NSString).size(withAttributes: attrs).width
        let downWidth = (downSpeed as NSString).size(withAttributes: attrs).width
        return ceil(max(upWidth, downWidth))
    }

    func update(up: String, down: String) {
        upSpeed = up
        downSpeed = down
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let font = StatusItemTool.font
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
        ]

        let upSize = (upSpeed as NSString).size(withAttributes: attrs)
        let downSize = (downSpeed as NSString).size(withAttributes: attrs)

        let upX = bounds.width - upSize.width
        let downX = bounds.width - downSize.width

        (upSpeed as NSString).draw(at: NSPoint(x: upX, y: 1), withAttributes: attrs)
        (downSpeed as NSString).draw(at: NSPoint(x: downX, y: bounds.height / 2 + 1), withAttributes: attrs)
    }
}
