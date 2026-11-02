import CryptoKit
import Darwin
import Foundation

struct EventKitHelperLocation: Sendable {
  static let bundleName = "Sbar EventKit.app"
  static let changeNotification = Notification.Name("dev.starkwm.sbar.eventkit.changed")

  static func resolve(executable: URL) throws -> EventKitHelperLocation {
    let app = executable.resolvingSymlinksInPath().deletingLastPathComponent()
      .appending(path: bundleName)
    guard let bundle = Bundle(url: app),
      let build = bundle.object(forInfoDictionaryKey: "SbarBuildIdentifier") as? String,
      !build.isEmpty,
      let binary = bundle.executableURL,
      FileManager.default.isExecutableFile(atPath: binary.path)
    else {
      throw EventKitHelperError(
        message:
          "EventKit helper missing. Run make build, or install Sbar EventKit.app beside the sbar executable."
      )
    }
    return EventKitHelperLocation(app: app, build: build)
  }

  var app: URL
  var build: String

  var socketPath: String {
    let identity = app.resolvingSymlinksInPath().path + ":" + build
    let digest = SHA256.hash(data: Data(identity.utf8)).prefix(12).map {
      String(format: "%02x", $0)
    }.joined()
    return "/tmp/sbar-eventkit-\(getuid())/\(digest).sock"
  }

  func prepareDirectory() throws {
    let path = URL(fileURLWithPath: socketPath).deletingLastPathComponent().path
    if mkdir(path, 0o700) != 0 && errno != EEXIST {
      throw EventKitHelperError(message: "Cannot create EventKit helper socket directory.")
    }
    var info = stat()
    guard lstat(path, &info) == 0, info.st_uid == getuid(),
      info.st_mode & S_IFMT == S_IFDIR, info.st_mode & 0o777 == 0o700
    else { throw EventKitHelperError(message: "EventKit helper socket directory is not private.") }
  }
}
