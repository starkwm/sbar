import Foundation
import Observation

@MainActor @Observable
final class ConfigurationStore {
    private(set) var configuration = BarConfiguration.default
    private(set) var errorMessage: String?

    var configurationURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/starkbar/config.json")
    }

    func load() {
        guard FileManager.default.fileExists(atPath: configurationURL.path) else {
            configuration = .default
            errorMessage = nil
            return
        }
        do {
            let decoded = try JSONDecoder().decode(BarConfiguration.self, from: Data(contentsOf: configurationURL))
            try decoded.validate()
            configuration = decoded
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
