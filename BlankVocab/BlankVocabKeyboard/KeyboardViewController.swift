import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
    private let model = KeyboardModel()
    private var heightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        model.controller = self

        let host = UIHostingController(rootView: KeyboardRootView(model: model))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let h = view.heightAnchor.constraint(equalToConstant: model.preferredHeight)
        h.priority = UILayoutPriority(999)
        h.isActive = true
        heightConstraint = h
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        syncTraits()
        model.refreshContext()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        model.needsGlobe = needsInputModeSwitchKey
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        syncTraits()
        if !model.dictOpen { model.refreshContext() }
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        if !model.dictOpen { model.refreshContext() }
    }

    func updateHeight() {
        heightConstraint?.constant = model.preferredHeight
        UIView.animate(withDuration: 0.2) { self.view.superview?.layoutIfNeeded() }
    }

    private func syncTraits() {
        model.hasFullAccess = hasFullAccess
        model.needsGlobe = needsInputModeSwitchKey
    }
}
