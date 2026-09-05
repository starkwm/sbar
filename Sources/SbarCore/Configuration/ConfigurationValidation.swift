import Foundation

public enum ConfigurationValidation {
  public static func validate(url: URL) throws {
    do {
      let configuration = try JSONDecoder().decode(
        Configuration.self,
        from: Data(contentsOf: url)
      )
      try configuration.validate()
    } catch {
      throw MessageError.message(ConfigurationStore.describe(error))
    }
  }
}
