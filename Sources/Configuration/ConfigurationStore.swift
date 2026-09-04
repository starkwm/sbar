import Foundation
import Observation

@MainActor @Observable
final class ConfigurationStore {
    private struct Document: Encodable {
        private enum CodingKeys: String, CodingKey { case schema = "$schema" }

        let configuration: BarConfiguration

        func encode(to encoder: any Encoder) throws {
            try configuration.encode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("config.schema.json", forKey: .schema)
        }
    }

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
    var backupURL: URL { configurationURL.appendingPathExtension("bak") }

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

    func apply(_ candidate: BarConfiguration) throws {
        try candidate.validate()
        guard candidate != configuration else { return }
        configuration = candidate
        errorMessage = nil
        configurationDidChange?()
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

    /// Preserves the previous file before replacing it, including invalid externally edited JSON.
    func save(_ candidate: BarConfiguration) throws {
        do {
            try candidate.validate()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(Document(configuration: candidate))
            let directory = configurationURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try ConfigurationSchema.data().write(to: directory.appending(path: "config.schema.json"), options: .atomic)
            let previous: Data?
            do {
                previous = try Data(contentsOf: configurationURL)
            } catch CocoaError.fileReadNoSuchFile {
                previous = nil
            }
            if let previous { try previous.write(to: backupURL, options: .atomic) }
            try data.write(to: configurationURL, options: .atomic)
            errorMessage = nil
            guard candidate != configuration else { return }
            configuration = candidate
            configurationDidChange?()
        } catch {
            errorMessage = Self.describe(error)
            throw error
        }
    }
}
