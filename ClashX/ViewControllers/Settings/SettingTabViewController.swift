//
//  SettingTabViewController.swift
//  ClashX Pro
//
//  Created by yicheng on 2022/11/20.
//  Copyright © 2022 west2online. All rights reserved.
//

import Cocoa

class SettingTabViewController: NSTabViewController, NibLoadable {
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(macOS 15, *) {
            // NSTabViewController .toolbar style renders as a large gray block
            // on macOS 15 Sequoia — the toolbar layout changed significantly.
            // Fall back to segmentedControlOnTop which renders cleanly.
            tabStyle = .segmentedControlOnTop
        } else {
            tabStyle = .toolbar
        }
        configureTabIcons()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureTabIcons() {
        let symbolNames = ["gearshape", "keyboard", "hammer"]
        let fallbackGlyphs = ["⚙︎", "⌨︎", "🔨"]

        for (idx, item) in tabViewItems.enumerated() where idx < min(symbolNames.count, fallbackGlyphs.count) {
            if #available(macOS 11, *), let image = NSImage(systemSymbolName: symbolNames[idx], accessibilityDescription: nil) {
                item.image = image
            } else {
                item.image = makeFallbackIcon(glyph: fallbackGlyphs[idx])
            }
        }
    }

    private func makeFallbackIcon(glyph: String) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]

        let rect = NSRect(x: 0, y: 1, width: size.width, height: size.height)
        (glyph as NSString).draw(in: rect, withAttributes: attrs)
        image.isTemplate = true
        return image
    }
}
