import SwiftUI

struct JSONEditor<Value: Codable & Equatable>: View {
    @Binding var value: Value

    var body: some View {
        VStack(alignment: .leading) {
            TextEditor(text: $text).font(.system(.body, design: .monospaced)).frame(minHeight: 160)
            if let error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
            HStack {
                Button("Apply JSON") {
                    do { value = try JSONDecoder().decode(Value.self, from: Data(text.utf8)); error = nil }
                    catch { self.error = error.localizedDescription }
                }
                Button("Reset JSON") { refresh() }
            }
        }.onAppear { refresh() }
    }

    @State private var text = ""
    @State private var error: String?

    private func refresh() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        text = (try? encoder.encode(value)).map { String(decoding: $0, as: UTF8.self) } ?? ""
        error = nil
    }
}
