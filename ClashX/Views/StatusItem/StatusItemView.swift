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

    static func create(statusItem: NSStatusItem?) -> StatusItemView {
        var topLevelObjects: NSArray?
        if Bundle.main.loadNibNamed("StatusItemView", owner: self, topLevelObjects: &topLevelObjects) {
            let view = (topLevelObjects!.first(where: { $0 is NSView }) as? StatusItemView)!
            view.statusItem = statusItem
            view.setupView()
            view.imageView.image = StatusItemTool.menuImage

            if let button = statusItem?.button {
                // Remove any existing subviews before adding to avoid duplicate-subview
                // crashes on repeated StatusItem creation (affects macOS 15+).
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
        // macOS 26+ status bar NSTextField infinite redraw loop (high CPU bug).
        // SpeedTextView automatically falls back to NSTextField on macOS < 26,
        // so this is safe for all supported OS versions including macOS 10.15.
        speedTextView = SpeedTextView()
        speedTextView.translatesAutoresizingMaskIntoConstraints = false
        speedContainerView.subviews.forEach { $0.removeFromSuperview() }
        speedContainerView.addSubview(speedTextView)
        NSLayoutConstraint.activate([
            speedTextView.leadingAnchor.constraint(equalTo: speedContainerView.leadingAnchor),
            speedTextView.trailingAnchor.constraint(equalTo: speedContainerView.trailingAnchor),
            speedTextView.topAnchor.constraint(equalTo: speedContainerView.topAnchor),
            speedTextView.bottomAnchor.constraint(equalTo: speedContainerView.bottomAnchor),
            speedContainerView.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 3)
        ])

        updateSpeedLabel(up: 0, down: 0)
    }

    func updateSize(width: CGFloat) {
        frame = CGRect(x: 0, y: 0, width: width, height: 22)
    }

    func updateViewStatus(enableProxy: Bool) {
        if enableProxy {
            imageView.contentTintColor = NSColor.labelColor
        } else {
            imageView.contentTintColor = NSColor.labelColor.withSystemEffect(.disabled)
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
        }
    }

    func showSpeedContainer(show: Bool) {
        speedContainerView.isHidden = !show
        if show {
            updateDynamicWidth()
            speedTextView.needsDisplay = true
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
}
