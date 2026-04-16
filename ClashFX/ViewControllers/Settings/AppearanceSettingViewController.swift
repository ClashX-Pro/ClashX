//
//  AppearanceSettingViewController.swift
//  ClashFX
//
//  Created by copilot on 2026/4/15.
//

import Cocoa

class AppearanceSettingViewController: NSViewController {
    override func loadView() {
        let width: CGFloat = 400
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 120))
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let box = NSBox()
        box.translatesAutoresizingMaskIntoConstraints = false
        box.title = NSLocalizedString("Tray Icon", comment: "")

        let picker = TrayIconPickerView()
        box.contentView?.addSubview(picker)

        if let cv = box.contentView {
            NSLayoutConstraint.activate([
                picker.topAnchor.constraint(equalTo: cv.topAnchor, constant: 10),
                picker.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
                picker.trailingAnchor.constraint(lessThanOrEqualTo: cv.trailingAnchor, constant: -20),
                cv.bottomAnchor.constraint(equalTo: picker.bottomAnchor, constant: 10),
            ])
        }

        contentView.addSubview(box)
        NSLayoutConstraint.activate([
            box.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            box.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            box.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            contentView.bottomAnchor.constraint(greaterThanOrEqualTo: box.bottomAnchor, constant: 20),
        ])

        view = contentView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Appearance", comment: "")
        preferredContentSize = NSSize(width: 400, height: 160)
    }
}
