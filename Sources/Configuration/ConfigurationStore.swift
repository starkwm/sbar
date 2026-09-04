import Foundation
import Observation

@MainActor @Observable
final class ConfigurationStore {
    private static func describe(_ error: any Error) -> String {
        let path: [any CodingKey]
        let message: String
        switch error {
        case let DecodingError.keyNotFound(key, context):
            path = context.codingPath + [key]
            message = "Required value is missing."
        case let DecodingError.typeMismatch(_, context):
            path = context.codingPath
            message = context.debugDescription
        case let DecodingError.valueNotFound(_, context):
            path = context.codingPath
            message = "Value must not be null."
        case let DecodingError.dataCorrupted(context):
            path = context.codingPath
            message = context.debugDescription
        default:
            return error.localizedDescription
        }
        let location = path.reduce("") { result, key in
            if let index = key.intValue { return result + "[\(index)]" }
            return result.isEmpty ? key.stringValue : result + "." + key.stringValue
        }
        return "\(location.isEmpty ? "$" : location): \(message)"
    }

    let configurationURL: URL
    private(set) var configuration = BarConfiguration.default
    private(set) var errorMessage: String?

    @ObservationIgnored var configurationDidChange: (() -> Void)?
    @ObservationIgnored private var watcher: ConfigurationWatcher?

    init(configurationURL: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/starkbar/config.json")) {
        self.configurationURL = configurationURL
    }

    func startObserving() {
        guard watcher == nil else { return }
        watcher = ConfigurationWatcher(url: configurationURL) { [weak self] in self?.load() }
        watcher?.start()
        load()
    }

    func stopObserving() {
        watcher?.stop()
        watcher = nil
    }

    func load() {
        do {
            let decoded: BarConfiguration
            do {
                decoded = try JSONDecoder().decode(BarConfiguration.self, from: Data(contentsOf: configurationURL))
            } catch CocoaError.fileReadNoSuchFile {
                decoded = .default
            }
            try decoded.validate()
            errorMessage = nil
            guard decoded != configuration else { return }
            configuration = decoded
            configurationDidChange?()
        } catch {
            errorMessage = Self.describe(error)
        }
    }
}
