import AppKit
import Observation

@MainActor @Observable
final class ActionRunner {
    static func expand(_ value: String, environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        var result = value
        for (key, replacement) in environment {
            result = result.replacingOccurrences(of: "${\(key)}", with: replacement)
        }
        return (result as NSString).expandingTildeInPath
    }

    private(set) var errorMessage: String?
    @ObservationIgnored private var tasks: [UUID: Task<Void, Never>] = [:]

    func run(_ action: ItemAction) {
        switch action.kind {
        case .url:
            guard let url = URL(string: Self.expand(action.value)), ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") else {
                errorMessage = "Invalid URL action."
                return
            }
            errorMessage = NSWorkspace.shared.open(url) ? nil : "Could not open URL."
        case .application:
            let value = Self.expand(action.value)
            let url = value.hasPrefix("/") ? URL(fileURLWithPath: value) : NSWorkspace.shared.urlForApplication(withBundleIdentifier: value)
            guard let url else { errorMessage = "Application not found."; return }
            NSWorkspace.shared.openApplication(at: url, configuration: .init()) { [weak self] _, error in
                let message = error?.localizedDescription
                Task { @MainActor [weak self] in self?.errorMessage = message }
            }
        case .command:
            let id = UUID()
            tasks[id] = Task { [weak self] in
                defer { self?.tasks[id] = nil }
                do {
                    let result = try await CommandRunner.run(executable: "/bin/sh", arguments: ["-c", action.value])
                    self?.errorMessage = result.status == 0 ? nil : "Command exited \(result.status): \(result.output)"
                } catch { self?.errorMessage = error.localizedDescription }
            }
        }
    }

    func stop() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }
}
