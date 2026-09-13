import Foundation

public enum ConfigurationValidator {
  public static func validate(url: URL) throws {
    do {
      let configuration = try ConfigurationDecoder.decode(
        from: Data(contentsOf: url)
      )
      try configuration.validate()
    } catch {
      throw MessageError.message(ConfigurationStore.describe(error))
    }
  }
}
