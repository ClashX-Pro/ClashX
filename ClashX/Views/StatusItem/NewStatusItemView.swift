//
//  NewStatusMenuView.swift
//  ClashX Pro
//
//  Created by yicheng on 2023/3/1.
//  Copyright © 2023 west2online. All rights reserved.
//

import AppKit
import SwiftUI
@available(macOS 10.15, *)
class NewStatusMenuView: NSHostingView<SwiftUIView>, StatusItemViewProtocol {
    private var viewModel: StatusMenuViewModel!

    static func create(on button: NSView) -> NewStatusMenuView {
        let model = StatusMenuViewModel()
        let view = NewStatusMenuView(rootView: SwiftUIView(viewModel: model))
        view.viewModel = model
        view.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: button.topAnchor),
            view.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return view
    }
    func updateViewStatus(enableProxy: Bool) {
        viewModel.image = StatusItemTool.getMenuImage(enableProxy: enableProxy)
    }

    func updateSpeedLabel(up: Int, down: Int) {
        let upSpeed = StatusItemTool.getSpeedString(for: up)
        let downSpeed = StatusItemTool.getSpeedString(for: down)
        if upSpeed != viewModel.upSpeed {viewModel.upSpeed = upSpeed}
        if downSpeed != viewModel.downSpeed {viewModel.downSpeed = downSpeed}
    }

    func showSpeedContainer(show: Bool) {
        viewModel.showSpeed = show
    }

    func updateSize(width: CGFloat) {}
}

@available(macOS 10.15, *)
class StatusMenuViewModel: ObservableObject {
    @Published var image = StatusItemTool.getMenuImage(enableProxy: false)
    @Published var upSpeed = "0KB/s"
    @Published var downSpeed = "0KB/s"
    @Published var showSpeed = true
}

@available(macOS 10.15, *)
struct SwiftUIView: View {
    @ObservedObject var viewModel: StatusMenuViewModel
    var body: some View {
        HStack(alignment: .center) {
                Image(nsImage: $viewModel.image.wrappedValue).renderingMode(.template)
                    .resizable().aspectRatio(contentMode: .fit).frame(width: 16, height: 16)

            if $viewModel.showSpeed.wrappedValue {
                Spacer(minLength: 0)
                VStack(alignment: .trailing) {
                    Text($viewModel.upSpeed.wrappedValue)
                    Text($viewModel.downSpeed.wrappedValue)
                }.font(Font(StatusItemTool.font))
            }
        }
        .frame(width: $viewModel.showSpeed.wrappedValue ? statusItemLengthWithSpeed - 6 : 25)
        .frame(minHeight: 22)
    }
}

@available(macOS 10.15, *)
struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUIView(viewModel: StatusMenuViewModel())
    }
}
