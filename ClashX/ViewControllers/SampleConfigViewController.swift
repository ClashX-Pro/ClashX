//
//  SampleConfigViewController.swift
//  ClashX
//
//  Created by 称一称 on 2018/6/13.
//  Copyright © 2018年 west2online. All rights reserved.
//

import Cocoa

class SampleConfigViewController: NSViewController {

    @IBOutlet weak var serverAddressTextField: NSTextField!
    @IBOutlet weak var serverPortTextField: NSTextField!
    @IBOutlet weak var serverPasswordTextField: NSSecureTextField!
    @IBOutlet weak var serverencryptMethodBox: NSComboBox!
    override func viewDidLoad() {
        super.viewDidLoad()
        serverencryptMethodBox.addItems(withObjectValues: [
            "RC4-MD5",
            "AES-128-CTR",
            "AES-192-CTR",
            "AES-256-CTR",
            "AES-128-CFB",
            "AES-192-CFB",
            "AES-256-CFB",
            "CHACHA20",
            "CHACHA20-IETF",
            "XCHACHA20",
            "AEAD_AES_128_GCM",
            "AEAD_AES_192_GCM",
            "AEAD_AES_256_GCM",
            "AEAD_CHACHA20_POLY1305"
            ])

    }
    
    func vaildConfig()->Bool {
        if let port = Int(serverPortTextField.stringValue) {
            if port > 0 && port <= 65535 {
                return serverPortTextField.stringValue.count > 0 &&
                serverPasswordTextField.stringValue.count > 0
            }
        }
        return false
    }
    
    func generateConfig() {
        let originalConfig = NSData(contentsOfFile: Bundle.main.path(forResource: "sampleConfig", ofType: "ini")!)
        
        var configStr = String(data: originalConfig! as Data, encoding: .utf8)
        
        let targetStr = "Proxy = ss, \(serverAddressTextField.stringValue), \(serverPortTextField.stringValue), \(serverencryptMethodBox.stringValue), \(serverPasswordTextField.stringValue)"
        
        configStr = configStr?.replacingOccurrences(of: "{{placeHolder}}", with: targetStr)
        
        // save to ~/.config/clash/config.ini
        let path = (NSHomeDirectory() as NSString).appendingPathComponent("/.config/clash/config.ini")

        if (FileManager.default.fileExists(atPath: path)) {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
        }
        try? configStr?.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
                
    }
    
        func shakeWindows(){
            let numberOfShakes:Int = 8
            let durationOfShake:Float = 0.5
            let vigourOfShake:Float = 0.05
            let window = self.view.window
            let frame:CGRect = (window?.frame)!
            let shakeAnimation = CAKeyframeAnimation()
    
            let shakePath = CGMutablePath()
            shakePath.move(to: CGPoint(x:NSMinX(frame), y:NSMinX(frame)))
    
            for _ in 1...numberOfShakes{
                shakePath.addLine(to: CGPoint(x: NSMinX(frame) - frame.size.width * CGFloat(vigourOfShake), y: NSMinY(frame)))
                shakePath.addLine(to: CGPoint(x: NSMinX(frame) + frame.size.width * CGFloat(vigourOfShake), y: NSMinY(frame)))
            }
    
            shakePath.closeSubpath()
            shakeAnimation.path = shakePath
            shakeAnimation.duration = CFTimeInterval(durationOfShake)
            window?.animations = [NSAnimatablePropertyKey("frameOrigin"):shakeAnimation]
            window?.animator().setFrameOrigin(window!.frame.origin)
        }

    
    
    @IBAction func actionConfirm(_ sender: Any) {
        if (vaildConfig()) {
            generateConfig()
            self.view.window?.windowController?.close()
            DispatchQueue(label: "com.w2fzu.ssqueue", attributes: .concurrent).async {
//                updateConfigC()
            }
        } else {
            shakeWindows()
        }
        
    }
    
}
