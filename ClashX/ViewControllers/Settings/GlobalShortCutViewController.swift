//
//  GlobalShortCutViewController.swift
//  ClashX Pro
//
//  Created by yicheng on 2023/5/26.
//  Copyright © 2023 west2online. All rights reserved.
//

import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleSystemProxyMode = Self("shortCut.toggleSystemProxyMode")
    static let copyShellCommand = Self("shortCut.copyShellCommand")
    static let copyExternalShellCommand = Self("shortCut.copyExternalShellCommand")

    static let modeDirect = Self("shortCut.modeDirect")
    static let modeRule = Self("shortCut.modeRule")
    static let modeGlobal = Self("shortCut.modeGlobal")

    static let log = Self("shortCut.log")
    static let dashboard = Self("shortCut.dashboard")
    static let openMenu = Self("shortCut.openMenu")

}

enum KeyboardShortCutManager {
    static func setup() {
        KeyboardShortcuts.onKeyUp(for: .toggleSystemProxyMode) {
            AppDelegate.shared.actionSetSystemProxy(nil)
        }

        KeyboardShortcuts.onKeyUp(for: .copyShellCommand) {
            AppDelegate.shared.actionCopyExportCommand(AppDelegate.shared.copyExportCommandMenuItem)
        }

        KeyboardShortcuts.onKeyUp(for: .copyExternalShellCommand) {
            AppDelegate.shared.actionCopyExportCommand(AppDelegate.shared.copyExportCommandExternalMenuItem)
        }

        KeyboardShortcuts.onKeyUp(for: .modeDirect) {
            AppDelegate.shared.switchProxyMode(mode: .direct)
        }

        KeyboardShortcuts.onKeyUp(for: .modeRule) {
            AppDelegate.shared.switchProxyMode(mode: .rule)
        }

        KeyboardShortcuts.onKeyUp(for: .modeGlobal) {
            AppDelegate.shared.switchProxyMode(mode: .global)
        }

        KeyboardShortcuts.onKeyUp(for: .log) {
            AppDelegate.shared.actionShowLog(nil)
        }

        KeyboardShortcuts.onKeyUp(for: .dashboard) {
            AppDelegate.shared.actionDashboard(nil)
        }

        KeyboardShortcuts.onKeyUp(for: .openMenu) {
            AppDelegate.shared.statusItem.button?.performClick(nil)
        }
    }
}

class GlobalShortCutViewController: NSViewController {

    @IBOutlet weak var proxyBox: NSBox!
    @IBOutlet weak var modeBoxView: NSView!
    @IBOutlet weak var otherBoxView: NSView!

    override func viewDidLoad() {
        super.viewDidLoad()

        let systemProxy = KeyboardShortcuts.RecorderCocoa(for: .toggleSystemProxyMode)
        let copyShellCommand = KeyboardShortcuts.RecorderCocoa(for: .copyShellCommand)
        let copyShellCommandExternal = KeyboardShortcuts.RecorderCocoa(for: .copyExternalShellCommand)
        addGridView(in: proxyBox.contentView!, with: [
            [NSTextField(labelWithString: NSLocalizedString("System Proxy", comment: "")), systemProxy],
            [NSTextField(labelWithString: NSLocalizedString("Copy Shell Command", comment: "")), copyShellCommand],
            [NSTextField(labelWithString: NSLocalizedString("Copy Shell Command (External)", comment: "")), copyShellCommandExternal]
        ])

        addGridView(in: modeBoxView, with: [
            [NSTextField(labelWithString: NSLocalizedString("Direct Mode", comment: "")), KeyboardShortcuts.RecorderCocoa(for: .modeDirect)],
            [NSTextField(labelWithString: NSLocalizedString("Rule Mode", comment: "")), KeyboardShortcuts.RecorderCocoa(for: .modeRule)],
            [NSTextField(labelWithString: NSLocalizedString("Global Mode", comment: "")), KeyboardShortcuts.RecorderCocoa(for: .modeGlobal)]
        ])

        addGridView(in: otherBoxView, with: [
            [NSTextField(labelWithString: NSLocalizedString("Open Menu", comment: "")), KeyboardShortcuts.RecorderCocoa(for: .openMenu)],
            [NSTextField(labelWithString: NSLocalizedString("Open Log", comment: "")), KeyboardShortcuts.RecorderCocoa(for: .log)],
            [NSTextField(labelWithString: NSLocalizedString("Open Dashboard", comment: "")), KeyboardShortcuts.RecorderCocoa(for: .dashboard)]
        ])
    }

    func addGridView(in superView: NSView, with views: [[NSView]]) {
        let gridView = NSGridView(views: views)
        gridView.rowSpacing = 10
        gridView.rowAlignment = .firstBaseline
        superView.addSubview(gridView)
        gridView.makeConstraintsToBindToSuperview(NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        gridView.setContentHuggingPriority(.required, for: .vertical)
        gridView.setContentCompressionResistancePriority(.required, for: .vertical)
        gridView.xPlacement = .trailing
        gridView.column(at: 0).xPlacement = .leading
    }
}
