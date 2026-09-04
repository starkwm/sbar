import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    let store: ConfigurationStore
    let reload: () -> Void

    var body: some View {
        @Bindable var editor = editor
        VStack(spacing: 0) {
            BarView(configuration: editor.validationError == nil ? editor.draft : editor.baseline)
                .frame(height: editor.draft.bar.height.isFinite ? min(96, max(20, editor.draft.bar.height)) : 32)
                .allowsHitTesting(false)
                .accessibilityLabel("Bar preview")
            Divider()
            TabView {
                HSplitView {
                    List(selection: $editor.selection) {
                        ForEach(ConfigurationEditor.Section.allCases) { section in
                            Section(section.rawValue.capitalized) {
                                ForEach(editor.items(in: section)) { item in
                                    Text(item.label ?? item.id).tag(item.id)
                                        .draggable(item.id)
                                        .dropDestination(for: String.self) { ids, _ in
                                            guard let id = ids.first else { return false }
                                            editor.move(id, to: section, before: item.id)
                                            return true
                                        }
                                        .contextMenu {
                                            Button("Remove", role: .destructive) { editor.remove(item.id) }
                                            ForEach(ConfigurationEditor.Section.allCases) { destination in
                                                Button("Move to \(destination.rawValue)") { editor.move(item.id, to: destination) }
                                            }
                                        }
                                }
                                Button("Add item") { editor.add(to: section) }
                                    .dropDestination(for: String.self) { ids, _ in
                                        guard let id = ids.first else { return false }
                                        editor.move(id, to: section)
                                        return true
                                    }
                            }
                        }
                    }.frame(minWidth: 180, idealWidth: 220, maxWidth: 300)
                    if let item = selectedItem {
                        ItemInspector(item: item).id(editor.selection)
                    } else { ContentUnavailableView("Select an item", systemImage: "sidebar.left") }
                }.tabItem { Text("Layout") }
                themeForm.tabItem { Text("Theme") }
                diagnostics.tabItem { Text("Diagnostics") }
            }
            Divider()
            if let error = editor.validationError ?? editor.message ?? store.errorMessage {
                Text(error).foregroundStyle(.red).textSelection(.enabled).padding(8)
            }
            if editor.dirty && store.configuration != editor.baseline {
                Text("The live configuration changed. Reload to discard this draft, or save to replace it.").foregroundStyle(.orange).padding(8)
            }
            HStack {
                Button("Reload") { reload(); editor.load(store.configuration) }
                Button("Import…", action: importConfiguration)
                Button("Export…", action: exportConfiguration)
                Button("Reveal") { NSWorkspace.shared.activateFileViewerSelecting([store.configurationURL]) }
                Spacer()
                Text(editor.dirty ? "Unsaved changes" : "Saved").foregroundStyle(.secondary)
                Button("Save") {
                    do { try store.save(editor.draft); editor.load(store.configuration) }
                    catch { editor.message = error.localizedDescription }
                }.keyboardShortcut("s").disabled(editor.validationError != nil)
            }.padding()
        }
        .frame(minWidth: 840, minHeight: 620)
        .onAppear { editor.load(store.configuration) }
        .onChange(of: store.configuration) { _, value in if !editor.dirty { editor.load(value) } }
        .navigationTitle("StarkBar Settings")
    }

    @State private var editor = ConfigurationEditor()
    @Environment(ActionRunner.self) private var actions
    @Environment(EventBus.self) private var events

    private var selectedItem: Binding<ItemConfiguration>? {
        for section in ConfigurationEditor.Section.allCases {
            if let index = editor.items(in: section).firstIndex(where: { $0.id == editor.selection }) {
                let original = editor.items(in: section)[index]
                return Binding(get: { editor.items(in: section).first(where: { $0.id == original.id }) ?? original }, set: { item in
                    var items = editor.items(in: section)
                    guard items.indices.contains(index), items[index].id == original.id else { return }
                    items[index] = item
                    editor.replace(items, in: section)
                })
            }
        }
        return nil
    }

    private var themeForm: some View {
        Form {
            Picker("Position", selection: $editor.draft.bar.position) { Text("Top").tag(BarPosition.top); Text("Bottom").tag(BarPosition.bottom) }
            Picker("Displays", selection: $editor.draft.bar.displays) { Text("Main").tag(DisplaySelection.main); Text("All").tag(DisplaySelection.all); Text("Selected").tag(DisplaySelection.selected) }
            if editor.draft.bar.displays == .selected {
                ForEach(NSScreen.screens, id: \.self) { screen in
                    if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                        Toggle("\(screen.localizedName) (\(number.uint32Value))", isOn: Binding(get: {
                            editor.draft.bar.displayIDs?.contains(number.uint32Value) == true
                        }, set: { selected in
                            var ids = editor.draft.bar.displayIDs ?? []
                            ids.removeAll { $0 == number.uint32Value }
                            if selected { ids.append(number.uint32Value) }
                            editor.draft.bar.displayIDs = ids
                        }))
                    }
                }
            }
            Picker("Window level", selection: Binding(get: { editor.draft.bar.windowLevel ?? .statusBar }, set: { editor.draft.bar.windowLevel = $0 })) {
                ForEach(BarWindowLevel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Toggle("Pass mouse through empty regions", isOn: Binding(get: { editor.draft.bar.mousePassThrough ?? false }, set: { editor.draft.bar.mousePassThrough = $0 }))
            TextField("Bar height", value: $editor.draft.bar.height, format: .number)
            Section("Bar theme") {
                TextField("Background", text: Binding(get: { editor.draft.theme?.background ?? "" }, set: { var theme = editor.draft.theme ?? BarTheme(); theme.background = $0.isEmpty ? nil : $0; editor.draft.theme = theme }))
                TextField("Horizontal padding", value: themeNumber(\.horizontalPadding), format: .number)
                TextField("Item spacing", value: themeNumber(\.itemSpacing), format: .number)
            }
            Section("Default item style") {
                StyleEditor(style: Binding(get: { editor.draft.theme?.itemStyle ?? ItemStyle() }, set: { var theme = editor.draft.theme ?? BarTheme(); theme.itemStyle = $0; editor.draft.theme = theme }))
                Button("Reset theme") { editor.draft.theme = nil }
            }
        }.formStyle(.grouped)
    }

    private var diagnostics: some View {
        Form {
            LabeledContent("Configuration", value: store.configurationURL.path).textSelection(.enabled)
            if let error = actions.errorMessage { LabeledContent("Last action error", value: error) }
            Section("Recent runtime events") {
                ForEach(Array(events.recent.enumerated()), id: \.offset) { _, event in
                    LabeledContent(event.kind.rawValue, value: event.name)
                }
            }
        }.formStyle(.grouped)
    }

    private func themeNumber(_ key: WritableKeyPath<BarTheme, Double?>) -> Binding<Double?> {
        Binding(get: { editor.draft.theme?[keyPath: key] }, set: { value in var theme = editor.draft.theme ?? BarTheme(); theme[keyPath: key] = value; editor.draft.theme = theme })
    }

    private func importConfiguration() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let value = try JSONDecoder().decode(BarConfiguration.self, from: Data(contentsOf: url))
            try value.validate()
            editor.draft = value
            editor.message = nil
        } catch { editor.message = error.localizedDescription }
    }

    private func exportConfiguration() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "config.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try editor.draft.validate()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(editor.draft).write(to: url, options: .atomic)
            editor.message = nil
        } catch { editor.message = error.localizedDescription }
    }
}
