//
//  StatusItemView.swift
//  ClashX
//
//  Created by CYC on 2018/6/23.
//  Copyright © 2018年 yichengchen. All rights reserved.
//

import AppKit
import Foundation
import RxCocoa
import RxSwift

class StatusItemView: NSView, StatusItemViewProtocol {
    @IBOutlet var imageView: NSImageView!
    @IBOutlet var speedContainerView: NSView!

    private var speedTextView: SpeedTextView!

    // Use -1 so the first updateSpeedLabel(0, 0) call always triggers a redraw.
    var up: Int = -1
    var down: Int = -1

    weak var statusItem: NSStatusItem?

    private var usesSnapshotStatusRendering: Bool {
        if #available(macOS 11, *) {
            return false
        }
        if #available(macOS 10.15, *) {
            return true
        }
        return false
    }

    static func create(statusItem: NSStatusItem?) -> StatusItemView {
        var topLevelObjects: NSArray?
        if Bundle.main.loadNibNamed("StatusItemView", owner: self, topLevelObjects: &topLevelObjects) {
            let view = (topLevelObjects!.first(where: { $0 is NSView }) as? StatusItemView)!
            view.statusItem = statusItem
            view.setupView()
            view.imageView.image = StatusItemTool.menuImage

            if view.usesSnapshotStatusRendering {
                statusItem?.button?.image = nil
                statusItem?.button?.title = ""
                statusItem?.button?.imagePosition = .imageOnly
                view.refreshStatusItemSnapshot()
            } else if let button = statusItem?.button {
                // 修复 macOS 15+ 兼容性：在添加新子视图前移除所有现有子视图
                // 这样可以避免在新版 macOS 中因为多次添加子视图而导致的崩溃
                button.subviews.forEach { $0.removeFromSuperview() }
                button.addSubview(view)
                button.imagePosition = .imageOverlaps
            } else {
                Logger.log("button = nil")
                AppDelegate.shared.openConfigFolder(self)
            }
            view.updateViewStatus(enableProxy: false)
            return view
        }
        return NSView() as! StatusItemView
    }

    func setupView() {
        // Replace NSTextField with custom draw-based view to avoid
        // macOS 26+ status bar NSTextField infinite redraw loop (high CPU bug)
        speedTextView = SpeedTextView()
        speedTextView.translatesAutoresizingMaskIntoConstraints = false
        speedContainerView.subviews.forEach { $0.removeFromSuperview() }
        speedContainerView.addSubview(speedTextView)
        NSLayoutConstraint.activate([
            speedTextView.leadingAnchor.constraint(equalTo: speedContainerView.leadingAnchor),
            speedTextView.trailingAnchor.constraint(equalTo: speedContainerView.trailingAnchor),
            speedTextView.topAnchor.constraint(equalTo: speedContainerView.topAnchor),
            speedTextView.bottomAnchor.constraint(equalTo: speedContainerView.bottomAnchor)
        ])

        updateSpeedLabel(up: 0, down: 0)
    }

    func updateSize(width: CGFloat) {
        frame = CGRect(x: 0, y: 0, width: width, height: 22)
        if usesSnapshotStatusRendering {
            refreshStatusItemSnapshot()
        }
    }

    func updateViewStatus(enableProxy: Bool) {
        if enableProxy {
            imageView.contentTintColor = NSColor.labelColor
        } else {
            imageView.contentTintColor = NSColor.labelColor.withSystemEffect(.disabled)
        }
        if usesSnapshotStatusRendering {
            refreshStatusItemSnapshot()
        }
    }

    func updateSpeedLabel(up: Int, down: Int) {
        guard !speedContainerView.isHidden else { return }
        var needsResize = false
        if up != self.up {
            self.up = up
            needsResize = true
        }
        if down != self.down {
            self.down = down
            needsResize = true
        }
        if needsResize {
            speedTextView.update(
                up: SpeedUtils.getSpeedString(for: up),
                down: SpeedUtils.getSpeedString(for: down)
            )
            updateDynamicWidth()
            if usesSnapshotStatusRendering {
                refreshStatusItemSnapshot()
            }
        }
    }

    func showSpeedContainer(show: Bool) {
        speedContainerView.isHidden = !show
        if show {
            updateDynamicWidth()
            speedTextView.needsDisplay = true
        }
        if usesSnapshotStatusRendering {
            refreshStatusItemSnapshot()
        }
    }

    private func updateDynamicWidth() {
        guard !speedContainerView.isHidden else { return }
        let maxTextWidth = speedTextView.textWidth
        let neededWidth = 32.0 + maxTextWidth
        let width = max(statusItemLengthWithSpeed, neededWidth)

        if abs(frame.width - width) > 0.5 {
            updateSize(width: width)
            statusItem?.length = width
        }
    }

    private func refreshStatusItemSnapshot() {
        guard usesSnapshotStatusRendering, let statusItem = statusItem else { return }
        statusItem.updateImage(withView: self)
    }
}

private extension NSStatusItem {
    func updateImage(withView view: NSView) {
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }
        let data = view.dataWithPDF(inside: view.bounds)
        let image = NSImage(data: data)
        image?.isTemplate = true
        button?.image = image
    }
}
