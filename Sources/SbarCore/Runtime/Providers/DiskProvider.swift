import Foundation

struct DiskProvider {
  static func sample() -> String? {
    if let attributes = try? FileManager.default.attributesOfFileSystem(
      forPath: NSHomeDirectory()
    ),
      let free = attributes[.systemFreeSize] as? NSNumber
    {
      return
        "\(ByteCountFormatter.string(fromByteCount: free.int64Value, countStyle: .file)) free"
    }

    return nil
  }
}
