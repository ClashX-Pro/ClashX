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
    private let useLegacyLabels: Bool = {
        if #available(macOS 26, *) {
            return false
        }
        return true
    }()

    private var upLabel: NSTextField?
    private var downLabel: NSTextField?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override var isFlipped: Bool {
        true
    }

    private func commonInit() {
        guard useLegacyLabels else { return }

        let up = Self.makeLegacyLabel()
        let down = Self.makeLegacyLabel()
        upLabel = up
        downLabel = down

        addSubview(up)
        addSubview(down)

        NSLayoutConstraint.activate([
            up.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            up.trailingAnchor.constraint(equalTo: trailingAnchor),
            down.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0),
            down.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        update(up: upSpeed, down: downSpeed)
    }

    private static func makeLegacyLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "0KB/s")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = StatusItemTool.font
        label.textColor = .labelColor
        label.alignment = .right
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isBordered = false
        label.drawsBackground = false
        label.lineBreakMode = .byClipping
        return label
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
        if useLegacyLabels {
            upLabel?.stringValue = up
            downLabel?.stringValue = down
            needsLayout = true
            return
        }
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        // Auto Layout may resolve bounds after the initial draw call (which
        // would have had zero-height bounds). Re-trigger drawing whenever
        // the layout changes so the text is visible after first layout pass.
        if bounds.height > 0 {
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !useLegacyLabels else { return }

        let font = StatusItemTool.font
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]

        let upSize = (upSpeed as NSString).size(withAttributes: attrs)
        let downSize = (downSpeed as NSString).size(withAttributes: attrs)

        let upX = bounds.width - upSize.width
        let downX = bounds.width - downSize.width

        (upSpeed as NSString).draw(at: NSPoint(x: upX, y: 1), withAttributes: attrs)
        (downSpeed as NSString).draw(at: NSPoint(x: downX, y: bounds.height / 2 + 1), withAttributes: attrs)
    }
}
