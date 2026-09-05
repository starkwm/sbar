import Darwin
import Foundation

struct MemoryProvider {
  static func sample(host: host_t) -> String? {
    var info = vm_statistics64()
    var count = mach_msg_type_number_t(
      MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
    )
    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics64(host, HOST_VM_INFO64, $0, &count)
      }
    }

    if result == KERN_SUCCESS {
      let pages =
        UInt64(info.active_count) + UInt64(info.wire_count) + UInt64(info.compressor_page_count)
      let used = pages * UInt64(getpagesize())
      return
        "RAM \(ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .memory))"
    }

    return nil
  }
}
