//
//  ProxyGroupMenuItemView.swift
//  ClashX
//
//  Created by yicheng on 2019/10/16.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa

class ProxyGroupMenuItemView: NSView {
    let groupNameLabel: NSTextField
    let selectProxyLabel: NSTextField
    let arrowLabel = NSTextField(labelWithString: "▶")
    var isMouseInsideView = false
    var isMenuOpen = false
    let effectView: NSVisualEffectView = {
        let effectView = NSVisualEffectView()
        effectView.material = .popover
        effectView.state = .active
        effectView.isEmphasized = true
        effectView.blendingMode = .behindWindow
        return effectView
    }()

    init(group: ClashProxyName, targetProxy: ClashProxyName) {
        groupNameLabel = VibrancyTextField(labelWithString: group)
        selectProxyLabel = VibrancyTextField(labelWithString: targetProxy)
        if #available(macOS 10.15, *) {
            super.init(frame: .zero)
        } else {
            super.init(frame: NSRect(x: 0, y: 0, width: 0, height: 20))
        }
        // self
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 20).isActive = true

        // background
        addSubview(effectView)
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        effectView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        effectView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        effectView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

        // arrow
        effectView.addSubview(arrowLabel)
        arrowLabel.translatesAutoresizingMaskIntoConstraints = false
        arrowLabel.rightAnchor.constraint(equalTo: effectView.rightAnchor, constant: -10).isActive = true
        arrowLabel.centerYAnchor.constraint(equalTo: effectView.centerYAnchor).isActive = true

        // group
        groupNameLabel.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(groupNameLabel)
        groupNameLabel.leftAnchor.constraint(equalTo: effectView.leftAnchor, constant: 20).isActive = true
        groupNameLabel.centerYAnchor.constraint(equalTo: effectView.centerYAnchor).isActive = true
        // select
        selectProxyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        effectView.addSubview(selectProxyLabel)
        selectProxyLabel.rightAnchor.constraint(equalTo: effectView.rightAnchor, constant: -30).isActive = true
        selectProxyLabel.centerYAnchor.constraint(equalTo: effectView.centerYAnchor).isActive = true

        // space
        selectProxyLabel.leftAnchor.constraint(greaterThanOrEqualTo: groupNameLabel.rightAnchor, constant: 30).isActive = true

        // font
        let font = NSFont.menuFont(ofSize: 14)
        groupNameLabel.font = font
        selectProxyLabel.font = font
        
        groupNameLabel.textColor = NSColor.labelColor
        selectProxyLabel.textColor = NSColor.secondaryLabelColor
        arrowLabel.textColor = NSColor.labelColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if #available(macOS 10.15.1, *) {
            trackingAreas.forEach { removeTrackingArea($0) }
            enclosingMenuItem?.submenu?.delegate = self
            addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil))
        }
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if #available(macOS 10.15, *) {} else {
            if let view = superview {
                view.autoresizingMask = [.width]
            }
        }
    }

    override func mouseEntered(with event: NSEvent) {
        if #available(macOS 10.15.1, *) {
            isMouseInsideView = true
            setNeedsDisplay(bounds)
        }
    }

    override func mouseExited(with event: NSEvent) {
        if #available(macOS 10.15.1, *) {
            isMouseInsideView = false
            setNeedsDisplay(bounds)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let menu = enclosingMenuItem else { return }
        let isHighlighted: Bool
        if #available(macOS 10.15.1, *) {
            isHighlighted = isMouseInsideView || isMenuOpen
        } else {
            isHighlighted = menu.isHighlighted
        }
        let labelBgStyle: NSView.BackgroundStyle = isHighlighted ? .emphasized : .normal
        groupNameLabel.cell?.backgroundStyle = labelBgStyle
        selectProxyLabel.cell?.backgroundStyle = labelBgStyle
        arrowLabel.cell?.backgroundStyle = labelBgStyle
        effectView.material = isHighlighted ? .selection : .popover
    }
}

extension ProxyGroupMenuItemView: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if #available(macOS 10.15.1, *) {
            isMenuOpen = true
            setNeedsDisplay(bounds)
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        if #available(macOS 10.15.1, *) {
            isMenuOpen = false
            setNeedsDisplay(bounds)
        }
    }
}


