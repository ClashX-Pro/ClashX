//
//  TrayIconPickerView.swift
//  ClashFX
//
//  Created by copilot on 2026/4/15.
//

import Cocoa

class TrayIconPickerView: NSView {
    private let dropZone = NSView()
    private let imageView = NSImageView()
    private let placeholderLabel = NSTextField(labelWithString: "")
    private let selectButton = NSButton()
    private let resetButton = NSButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false

        // Image preview area (acts as drop zone)
        dropZone.translatesAutoresizingMaskIntoConstraints = false
        dropZone.wantsLayer = true
        dropZone.layer?.borderWidth = 1.5
        dropZone.layer?.borderColor = NSColor.separatorColor.cgColor
        dropZone.layer?.cornerRadius = 8

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.image = StatusItemTool.menuImage
        dropZone.addSubview(imageView)

        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.stringValue = NSLocalizedString("Drop PNG here", comment: "")
        placeholderLabel.textColor = .secondaryLabelColor
        placeholderLabel.font = NSFont.systemFont(ofSize: 11)
        placeholderLabel.alignment = .center
        dropZone.addSubview(placeholderLabel)

        addSubview(dropZone)

        // Buttons stack
        selectButton.translatesAutoresizingMaskIntoConstraints = false
        selectButton.title = NSLocalizedString("Select Image", comment: "")
        selectButton.bezelStyle = .rounded
        selectButton.target = self
        selectButton.action = #selector(selectImage)

        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.title = NSLocalizedString("Reset", comment: "")
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetImage)

        let buttonStack = NSStackView(views: [selectButton, resetButton])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        addSubview(buttonStack)

        NSLayoutConstraint.activate([
            dropZone.topAnchor.constraint(equalTo: topAnchor),
            dropZone.leadingAnchor.constraint(equalTo: leadingAnchor),
            dropZone.widthAnchor.constraint(equalToConstant: 64),
            dropZone.heightAnchor.constraint(equalToConstant: 64),

            imageView.centerXAnchor.constraint(equalTo: dropZone.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: dropZone.centerYAnchor, constant: -8),
            imageView.widthAnchor.constraint(equalToConstant: 32),
            imageView.heightAnchor.constraint(equalToConstant: 32),

            placeholderLabel.centerXAnchor.constraint(equalTo: dropZone.centerXAnchor),
            placeholderLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 2),
            placeholderLabel.widthAnchor.constraint(equalTo: dropZone.widthAnchor, constant: -4),

            buttonStack.leadingAnchor.constraint(equalTo: dropZone.trailingAnchor, constant: 12),
            buttonStack.centerYAnchor.constraint(equalTo: dropZone.centerYAnchor),

            bottomAnchor.constraint(equalTo: dropZone.bottomAnchor),
        ])

        updateIconPreview()
    }

    private func updateIconPreview() {
        let hasCustom = FileManager.default.fileExists(atPath: StatusItemTool.customImagePath)
        placeholderLabel.isHidden = hasCustom
        resetButton.isHidden = !hasCustom
    }

    // MARK: - Drag and Drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true,
            .urlReadingContentsConformToTypes: ["public.png"],
        ]) as? [URL], !urls.isEmpty else {
            return []
        }
        dropZone.layer?.borderColor = NSColor.controlAccentColor.cgColor
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        dropZone.layer?.borderColor = NSColor.separatorColor.cgColor
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        dropZone.layer?.borderColor = NSColor.separatorColor.cgColor
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true,
            .urlReadingContentsConformToTypes: ["public.png"],
        ]) as? [URL], let srcURL = urls.first else {
            return false
        }
        return applyImage(from: srcURL)
    }

    // MARK: - Actions

    @objc private func selectImage() {
        let panel = NSOpenPanel()
        panel.title = NSLocalizedString("Select Tray Icon Image", comment: "")
        panel.allowedFileTypes = ["png"]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let srcURL = panel.url else { return }
        _ = applyImage(from: srcURL)
    }

    @objc private func resetImage() {
        let destPath = StatusItemTool.customImagePath
        if FileManager.default.fileExists(atPath: destPath) {
            try? FileManager.default.removeItem(atPath: destPath)
        }
        reloadIcon()
    }

    private static let maxIconDimension: CGFloat = 128

    private func applyImage(from srcURL: URL) -> Bool {
        guard let image = NSImage(contentsOf: srcURL) else {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Failed to change tray icon", comment: "")
            alert.informativeText = NSLocalizedString("The file could not be loaded as an image.", comment: "")
            alert.runModal()
            return false
        }

        if let rep = image.representations.first {
            let pixelSize = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
            if pixelSize.width > TrayIconPickerView.maxIconDimension || pixelSize.height > TrayIconPickerView.maxIconDimension {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = NSLocalizedString("Failed to change tray icon", comment: "")
                alert.informativeText = String(
                    format: NSLocalizedString("Image is too large (%d×%d). Maximum allowed size is %d×%d pixels.", comment: ""),
                    Int(pixelSize.width), Int(pixelSize.height),
                    Int(TrayIconPickerView.maxIconDimension), Int(TrayIconPickerView.maxIconDimension)
                )
                alert.runModal()
                return false
            }
        }

        let destPath = StatusItemTool.customImagePath
        let destURL = URL(fileURLWithPath: destPath)
        let destDir = destURL.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destPath) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: srcURL, to: destURL)
        } catch {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Failed to change tray icon", comment: "")
            alert.informativeText = error.localizedDescription
            alert.runModal()
            return false
        }
        reloadIcon()
        return true
    }

    private func reloadIcon() {
        StatusItemTool.reloadMenuImage()
        imageView.image = StatusItemTool.menuImage

        if let view = AppDelegate.shared.statusItemView as? StatusItemView {
            view.imageView.image = StatusItemTool.menuImage
        }

        updateIconPreview()
    }
}
