import Foundation

public enum MessageError: Error, LocalizedError {
  case message(String)

  public var errorDescription: String? {
    if case .message(let message) = self { message } else { "Socket error" }
  }
}
