//
//  AutoUpgradeManager.swift
//  ClashFX
//

import Cocoa
import Sparkle

class AutoUpgradeManager: NSObject {
    static let shared = AutoUpgradeManager()

    private let updaterController: SPUStandardUpdaterController

    override private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    // MARK: Public

    func setup() {}

    func setupCheckForUpdatesMenuItem(_ item: NSMenuItem) {
        item.target = updaterController
        item.action = #selector(SPUStandardUpdaterController.checkForUpdates(_:))
    }

    func addChannelMenuItem(_ button: NSPopUpButton) {}

    var updater: SPUUpdater {
        updaterController.updater
    }
}
