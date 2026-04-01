import CosmogonyCore
import SwiftUI

private extension AppAppearance {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

@main
struct CosmogonyApp: App {
    @StateObject private var model = AppModel.bootstrap()

    var body: some Scene {
        WindowGroup("Cosmogony") {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(model.settings.appearance.preferredColorScheme)
        }

        Settings {
            SettingsRootView()
                .environmentObject(model)
                .preferredColorScheme(model.settings.appearance.preferredColorScheme)
        }

        MenuBarExtra("Cosmogony", systemImage: "square.stack.3d.up.fill") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Cosmogony")
                    .font(.headline)
                Text(model.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                Button("Capture Current Page") {
                    model.captureCurrentPage()
                }
                Button("Capture Clipboard") {
                    model.captureClipboard()
                }
                Divider()
                SettingsLink {
                    Text("Open Settings")
                }
            }
            .padding(12)
            .preferredColorScheme(model.settings.appearance.preferredColorScheme)
        }
    }
}
