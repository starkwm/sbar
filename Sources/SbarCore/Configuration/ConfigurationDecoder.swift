import Foundation
import StarkConfiguration

/// Removes configuration-only syntax before decoding the existing JSON model.
enum ConfigurationDecoder {
  static func decode(from data: Data) throws -> Configuration {
    try JSONDecoder().decode(Configuration.self, from: normalized(data))
  }

  static func normalized(_ data: Data) throws -> Data {
    try JSONC.normalized(data)
  }
}
