import Foundation

struct ConfigurationSchema {
    static func data(bundle: Bundle = .main) throws -> Data {
        let resource: URL?
        if bundle.bundleURL.pathExtension == "app" {
            resource = bundle.resourceURL?.appending(path: "StarkBar_StarkBar.bundle/config.schema.json")
        } else {
            resource = Bundle.module.url(forResource: "config.schema", withExtension: "json")
        }
        guard let url = resource else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        return try Data(contentsOf: url)
    }
}
