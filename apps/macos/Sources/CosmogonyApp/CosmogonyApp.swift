import CosmogonyCore
import SwiftUI

@main
struct CosmogonyApp: App {
    @StateObject private var model = AppModel.bootstrap()

    var body: some Scene {
        WindowGroup("Cosmogony") {
            RootView()
                .environmentObject(model)
        }

        Settings {
            SettingsRootView()
                .environmentObject(model)
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
        }
    }
}
