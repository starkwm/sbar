import Foundation
import StarkConfiguration

/// Strips JSONC comments and trailing commas before decoding.
enum ConfigurationDecoder {
  static func decode(from data: Data) throws -> Configuration {
    try JSONDecoder().decode(Configuration.self, from: JSONC.normalized(data))
  }
}
