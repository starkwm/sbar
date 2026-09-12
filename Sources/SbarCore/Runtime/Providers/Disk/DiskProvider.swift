import Darwin
import Foundation

struct DiskProvider {
  static func volume(for path: String) -> DiskVolume? {
    let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    guard FileManager.default.fileExists(atPath: resolved) else { return nil }
    var info = statfs()
    guard statfs(resolved, &info) == 0 else { return nil }
    let mount = withUnsafePointer(to: &info.f_mntonname) {
      $0.withMemoryRebound(to: CChar.self, capacity: Int(MNAMELEN)) { String(cString: $0) }
    }
    // A leftover directory for an unmounted /Volumes drive must not report the root disk.
    if resolved.hasPrefix("/Volumes/") {
      let components = resolved.split(separator: "/")
      let expected = "/Volumes/\(components[1])"
      guard mount == expected || mount.hasPrefix(expected + "/") else { return nil }
    }
    return DiskVolume(
      identity: "\(info.f_fsid.val.0):\(info.f_fsid.val.1)",
      mountPath: mount,
      path: resolved
    )
  }

  static func read(_ volume: DiskVolume) -> DiskState {
    guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: volume.path),
      let free = attributes[.systemFreeSize] as? NSNumber,
      let total = attributes[.systemSize] as? NSNumber
    else { return DiskState() }
    let state = DiskState(freeBytes: free.int64Value, totalBytes: total.int64Value)
    return state.available ? state : DiskState()
  }

  private var mounts: [String: String] = [:]

  mutating func sample(
    paths: Set<String>,
    resolve: (String) -> DiskVolume? = Self.volume,
    read: (DiskVolume) -> DiskState = Self.read
  ) -> [String: DiskState] {
    mounts = mounts.filter { paths.contains($0.key) }
    var volumes: [String: DiskState] = [:]
    var result: [String: DiskState] = [:]
    for path in paths.sorted() {
      guard let volume = resolve(path),
        mounts[path].map({ $0 == volume.mountPath }) ?? true
      else {
        result[path] = DiskState()
        continue
      }
      let state = volumes[volume.identity] ?? read(volume)
      guard let after = resolve(path), after.identity == volume.identity,
        after.mountPath == volume.mountPath
      else {
        result[path] = DiskState()
        continue
      }
      volumes[volume.identity] = state
      if state.available { mounts[path] = volume.mountPath }
      result[path] = state
    }
    return result
  }
}

struct DiskVolume {
  var identity: String
  var mountPath: String
  var path: String
}
