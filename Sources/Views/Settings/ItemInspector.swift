import SwiftUI

struct ItemInspector: View {
    @Binding var item: ItemConfiguration

    var body: some View {
        Form {
            LabeledContent("ID", value: item.id).textSelection(.enabled)
            Toggle("Enabled", isOn: $item.enabled)
            Picker("Type", selection: $item.type) {
                ForEach(ItemType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            TextField("Label", text: string(\.label))
            TextField("SF Symbol", text: string(\.symbol))
            TextField("Clock format", text: string(\.format))
            TextField("Overflow priority", value: $item.priority, format: .number)
            Section("Style overrides") {
                StyleEditor(style: Binding(get: { item.style ?? ItemStyle() }, set: { item.style = $0 }))
                Button("Use theme defaults") { item.style = nil }
            }
            Section("Primary click") { ActionEditor(action: $item.primaryAction) }
            Section("Secondary action") { ActionEditor(action: $item.secondaryAction) }
            Section("Popup") { TextField("Text", text: string(\.popup), axis: .vertical) }
            if item.type == .command {
                Section("Command") {
                    TextField("Shell script", text: Binding(get: { item.command?.script ?? "" }, set: { item.command = command(script: $0) }), axis: .vertical)
                    TextField("Interval (seconds; blank runs once)", value: Binding(get: { item.command?.interval }, set: { var c = command(); c.interval = $0; item.command = c }), format: .number)
                    TextField("Trigger event", text: Binding(get: { item.command?.event ?? "" }, set: { var c = command(); c.event = $0.isEmpty ? nil : $0; item.command = c }))
                }
            }
            DisclosureGroup("Advanced item JSON (including children)") { JSONEditor(value: $item).id(item.id) }
        }.formStyle(.grouped)
    }

    private func command(script: String? = nil) -> CommandConfiguration {
        var command = item.command ?? CommandConfiguration(script: "")
        if let script { command.script = script }
        return command
    }

    private func string(_ key: WritableKeyPath<ItemConfiguration, String?>) -> Binding<String> {
        Binding(get: { item[keyPath: key] ?? "" }, set: { item[keyPath: key] = $0.isEmpty ? nil : $0 })
    }
}

private struct ActionEditor: View {
    @Binding var action: ItemAction?

    var body: some View {
        Toggle("Enabled", isOn: Binding(get: { action != nil }, set: { action = $0 ? ItemAction(kind: .url, value: "") : nil }))
        if action != nil {
            Picker("Action", selection: Binding(get: { action?.kind ?? .url }, set: { action?.kind = $0 })) {
                ForEach(ItemAction.Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            TextField("Value", text: Binding(get: { action?.value ?? "" }, set: { action?.value = $0 }))
        }
    }
}
