//
//  ClashWebViewContoller.swift
//  ClashX
//
//  Created by yicheng on 2018/8/28.
//  Copyright © 2018年 west2online. All rights reserved.
//

import Cocoa
import RxCocoa
import RxSwift
import WebKit

enum WebCacheCleaner {
    static func clean() {
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
        Logger.log("[WebCacheCleaner] All cookies deleted")
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            for record in records {
                WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
                Logger.log("[WebCacheCleaner] Record \(record) deleted")
            }
        }
    }
}

class ClashWebViewContoller: NSViewController {
    let webview: CustomWKWebView = .init()
    var bridge: JSBridge?
    let disposeBag = DisposeBag()
    let minSize = NSSize(width: 920, height: 580)

    let effectView = NSVisualEffectView()

    private static let apiGuardJS: String = """
    (function() {
      var BLOCKED = ['/upgrade', '/restart'];
      var orig = window.fetch;
      window.fetch = function(input, init) {
        var url = (typeof input === 'string') ? input : (input.url || '');
        for (var i = 0; i < BLOCKED.length; i++) {
          if (url.indexOf(BLOCKED[i]) !== -1) {
            var method = ((init && init.method) || 'GET').toUpperCase();
            if (method === 'POST' || method === 'PUT' || method === 'PATCH') {
              return Promise.resolve(new Response(
                JSON.stringify({message: 'Managed by ClashFX'}),
                {status: 403, headers: {'Content-Type': 'application/json'}}
              ));
            }
          }
        }
        return orig.apply(this, arguments);
      };
      var origXHR = XMLHttpRequest.prototype.open;
      XMLHttpRequest.prototype.open = function(method, url) {
        for (var i = 0; i < BLOCKED.length; i++) {
          if (url.indexOf(BLOCKED[i]) !== -1 && /^(POST|PUT|PATCH)$/i.test(method)) {
            this._blocked = true;
          }
        }
        return origXHR.apply(this, arguments);
      };
      var origSend = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.send = function() {
        if (this._blocked) {
          Object.defineProperty(this, 'status', {get: function(){return 403}});
          Object.defineProperty(this, 'responseText', {get: function(){return '{"message":"Managed by ClashFX"}'}});
          if (typeof this.onload === 'function') this.onload();
          return;
        }
        return origSend.apply(this, arguments);
      };
    })();
    """

    private static let hideUpgradeJS: String = """
    (function() {
      var HIDE_LABELS = ['GEO Databases', 'Dashboard UI', 'Restart', 'Upgrade'];
      function hideItems(root) {
        var labels = root.querySelectorAll('div');
        for (var i = 0; i < labels.length; i++) {
          var el = labels[i];
          if (el.children.length > 0) continue;
          var txt = el.textContent.trim();
          for (var j = 0; j < HIDE_LABELS.length; j++) {
            if (txt.indexOf(HIDE_LABELS[j]) !== -1) {
              var row = el.parentElement;
              if (row) row.style.display = 'none';
              break;
            }
          }
        }
      }
      var mo = new MutationObserver(function() { hideItems(document); });
      mo.observe(document.documentElement, {childList: true, subtree: true});
      document.addEventListener('DOMContentLoaded', function() { hideItems(document); });
    })();
    """

    override func loadView() {
        view = NSView(frame: NSRect(origin: .zero, size: minSize))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        webview.uiDelegate = self
        webview.navigationDelegate = self

        webview.customUserAgent = "ClashFX Runtime"
        if #available(macOS 13.3, *) {
            webview.isInspectable = true
        }
        webview.setValue(false, forKey: "drawsBackground")

        let layoutPatchJS = """
        (function() {
          var s = document.createElement('style');
          s.textContent = [
            'aside, [class*="aside"], [class*="sidebar"], [class*="Sidebar"] { padding-top: 28px !important; }',
            '[class*="_p5j7u"] { height: 28px !important; min-height: 0 !important; overflow: hidden !important; }'
          ].join(' ');
          if (document.head) document.head.appendChild(s);
          else document.addEventListener('DOMContentLoaded', function() { document.head.appendChild(s); });
        })();
        """
        let guardScript = WKUserScript(source: Self.apiGuardJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        let hideScript = WKUserScript(source: Self.hideUpgradeJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        let padScript = WKUserScript(source: layoutPatchJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        webview.configuration.userContentController.addUserScript(guardScript)
        webview.configuration.userContentController.addUserScript(hideScript)
        webview.configuration.userContentController.addUserScript(padScript)

        bridge = JsBridgeUtil.initJSbridge(webview: webview, delegate: self)

        webview.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        NotificationCenter.default.rx.notification(.reloadDashboard).bind {
            [weak self] _ in
            self?.webview.reload()
        }.disposed(by: disposeBag)

        loadWebRecourses()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.titleVisibility = .hidden
        view.window?.titlebarAppearsTransparent = true
        view.window?.styleMask.insert(.fullSizeContentView)

        view.window?.isOpaque = false
        view.window?.backgroundColor = NSColor.clear
        view.window?.toolbar = NSToolbar()
        view.window?.toolbar?.showsBaselineSeparator = false
        view.wantsLayer = true
        view.layer?.cornerRadius = 10

        view.window?.minSize = minSize
    }

    func setupView() {
        view.addSubview(effectView)
        view.addSubview(webview)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        effectView.frame = view.bounds
        webview.frame = view.bounds
    }

    func loadWebRecourses() {
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: Date(timeIntervalSince1970: 0), completionHandler: {})
        // defaults write com.clashfx.app webviewUrl "your url"
        if let userDefineUrl = UserDefaults.standard.string(forKey: "webviewUrl"), let url = URL(string: userDefineUrl) {
            Logger.log("get user define url: \(url)")
            webview.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 0))
            return
        }
        let port = ConfigManager.shared.apiPort
        let secret = ConfigManager.shared.apiSecret
        var defaultUrl = "http://127.0.0.1:\(port)/ui/#/setup?hostname=127.0.0.1&port=\(port)"
        if !secret.isEmpty {
            defaultUrl += "&secret=\(secret)"
        }
        if let url = URL(string: defaultUrl) {
            Logger.log("dashboard url:\(defaultUrl)")
            webview.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 0))
            return
        }
        Logger.log("load dashboard url fail", level: .error)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        NSAlert.alert(with: message)
        completionHandler()
    }
}

extension ClashWebViewContoller: WKUIDelegate, WKNavigationDelegate {
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        Logger.log("[dashboard] webview crashed", level: .error)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {}

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        Logger.log("[dashboard] load request \(String(describing: navigationAction.request.url?.absoluteString))", level: .debug)
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Logger.log("[dashboard] didFinish \(String(describing: navigation))", level: .info)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Logger.log("[dashboard] \(String(describing: navigation)) error: \(error)", level: .error)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

class CustomWKWebView: WKWebView {
    var dragableAreaHeight: CGFloat = 30
    let alwaysDragableLeftAreaWidth: CGFloat = 150

    private func isInDargArea(with event: NSEvent?) -> Bool {
        guard let event = event else { return false }
        let x = event.locationInWindow.x
        let y = (window?.frame.size.height ?? 0) - event.locationInWindow.y
        return x < alwaysDragableLeftAreaWidth || y < dragableAreaHeight
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        if isInDargArea(with: event) {
            return true
        }
        return super.acceptsFirstMouse(for: event)
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if isInDargArea(with: event) {
            window?.performDrag(with: event)
        }
    }
}
