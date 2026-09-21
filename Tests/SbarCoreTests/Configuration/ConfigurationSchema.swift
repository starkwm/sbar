import Foundation

struct ConfigurationSchema {
  static func data() throws -> Data {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let url = root.appending(path: "Sources/SbarCore/Resources/config.schema.json")

    return try Data(contentsOf: url)
  }
}
