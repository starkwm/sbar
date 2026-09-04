import Foundation

struct ConfigurationSchema {
  static func data() throws -> Data {
    guard let url = Bundle.module.url(forResource: "config.schema", withExtension: "json") else {
      throw CocoaError(.fileReadNoSuchFile)
    }
    return try Data(contentsOf: url)
  }
}
