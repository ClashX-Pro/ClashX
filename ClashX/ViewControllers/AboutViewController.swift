//
//  AboutViewController.swift
//  ClashX
//
//  Created by CYC on 2018/8/19.
//  Copyright © 2018年 west2online. All rights reserved.
//

import Cocoa

class AboutViewController: NSViewController {
    @IBOutlet var versionLabel: NSTextField!
    @IBOutlet var buildTimeLabel: NSTextField!
    @IBOutlet var coreVersionLabel: NSTextField!

    lazy var compileDate: Date = {
        let bundleName = Bundle.main.infoDictionary!["CFBundleName"] as? String ?? "Info.plist"
        if let infoPath = Bundle.main.path(forResource: bundleName, ofType: nil),
            let infoAttr = try? FileManager.default.attributesOfItem(atPath: infoPath),
            let infoDate = infoAttr[FileAttributeKey.creationDate] as? Date {
            return infoDate
        }
        return Date()
    }()

    lazy var clashCoreVersion: String = {
        return Bundle.main.infoDictionary?["coreVersion"] as? String ?? "unknown"
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "About"

        let version = AppVersionUtil.currentVersion
        let build = AppVersionUtil.currentBuild
        let isBeta = AppVersionUtil.isBeta ? " Beta" : ""

        versionLabel.stringValue = "Version: \(version) (\(build))\(isBeta)"
        coreVersionLabel.stringValue = clashCoreVersion
        buildTimeLabel.stringValue = compileDate.description
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        NSApp.activate(ignoringOtherApps: true)
        view.window?.styleMask.remove(.resizable)
        view.window?.makeKeyAndOrderFront(self)
    }
}

@IBDesignable
class HyperlinkTextField: NSTextField {
    @IBInspectable var href: String = ""

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: NSCursor.pointingHand)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.foregroundColor: NSColor.linkColor,
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue as AnyObject,
        ]
        attributedStringValue = NSAttributedString(string: stringValue, attributes: attributes)
    }

    override func mouseDown(with theEvent: NSEvent) {
        if let localHref = URL(string: href) {
            NSWorkspace.shared.open(localHref)
        }
    }
}
