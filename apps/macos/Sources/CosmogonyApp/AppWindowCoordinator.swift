import AppKit
import Combine
import CosmogonyCore
import SwiftUI

@MainActor
final class AppWindowCoordinator: NSObject {
    static let shared = AppWindowCoordinator()

    private weak var mainWindow: NSWindow?
    private var recallPanel: RecallOverlayPanel?
    private var overlayVisibilityCancellable: AnyCancellable?
    private var openMainWindowAction: (() -> Void)?
    private var boundModelID: ObjectIdentifier?

    func bind(model: AppModel) {
        let modelID = ObjectIdentifier(model)
        guard boundModelID != modelID else { return }

        boundModelID = modelID
        model.activateBackstageHandler = { [weak self] in
            self?.activateBackstage()
        }

        overlayVisibilityCancellable = model.$isRecallOverlayPresented
            .removeDuplicates()
            .sink { [weak self, weak model] isPresented in
                guard let self, let model else { return }
                if isPresented {
                    presentRecallOverlay(using: model)
                } else {
                    hideRecallOverlay()
                }
            }
    }

    func registerMainWindow(_ window: NSWindow?) {
        guard let window, !(window is RecallOverlayPanel) else { return }
        mainWindow = window
    }

    func setOpenMainWindowAction(_ action: @escaping () -> Void) {
        openMainWindowAction = action
    }

    private func presentRecallOverlay(using model: AppModel) {
        let panel = recallPanel ?? makeRecallPanel()
        recallPanel = panel

        let rootView = RecallOverlayRootView()
            .environmentObject(model)
        panel.contentViewController = NSHostingController(rootView: rootView)

        if let screen = targetScreen() {
            panel.setFrame(screen.frame, display: true)
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
    }

    private func hideRecallOverlay() {
        recallPanel?.orderOut(nil)
    }

    private func activateBackstage() {
        if bestMainWindow() == nil {
            openMainWindowAction?()
        }

        NSApp.activate(ignoringOtherApps: true)
        orderBackstageWindowFront(attempt: 0)
    }

    private func orderBackstageWindowFront(attempt: Int) {
        if let window = bestMainWindow() {
            registerMainWindow(window)
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            return
        }

        guard attempt < 6 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.orderBackstageWindowFront(attempt: attempt + 1)
        }
    }

    private func makeRecallPanel() -> RecallOverlayPanel {
        let panel = RecallOverlayPanel(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.ignoresMouseEvents = false
        return panel
    }

    private func targetScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        if let pointedScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            return pointedScreen
        }
        if let mainWindow, let screen = mainWindow.screen {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private func bestMainWindow() -> NSWindow? {
        if let mainWindow, !(mainWindow is RecallOverlayPanel) {
            return mainWindow
        }

        return NSApp.windows.first { window in
            !(window is RecallOverlayPanel) &&
            !window.isMiniaturized &&
            window.canBecomeMain
        }
    }
}

private final class RecallOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

struct MainWindowRegistrationView: View {
    @Environment(\.openWindow) private var openWindow

    let coordinator: AppWindowCoordinator

    var body: some View {
        WindowAccessor { window in
            coordinator.registerMainWindow(window)
        }
        .frame(width: 0, height: 0)
        .onAppear {
            coordinator.setOpenMainWindowAction {
                openWindow(id: "main")
            }
        }
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            onResolve(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onResolve(nsView.window)
        }
    }
}
