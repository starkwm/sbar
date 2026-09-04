import AppKit
import SwiftUI

struct SettingsView: View {
    let store: ConfigurationStore
    let reload: () -> Void

    var body: some View {
        Form {
            LabeledContent("Configuration", value: store.configurationURL.path).textSelection(.enabled)
            if let errorMessage = store.errorMessage {
                LabeledContent("Last error", value: errorMessage).foregroundStyle(.red)
            } else {
                LabeledContent("Status", value: "Loaded")
            }
            Button("Reload Configuration", action: reload)
            Button("Save Configuration") {
                // The store reports any failure through errorMessage above.
                try? store.save(store.configuration)
            }
            Button("Reveal Configuration") {
                NSWorkspace.shared.activateFileViewerSelecting([store.configurationURL])
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 300)
        .navigationTitle("StarkBar Settings")
    }
}
