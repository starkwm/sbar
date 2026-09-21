import Darwin
import Foundation

struct MemoryProvider {
  static func sample(host: host_t) -> MemoryState {
    var info = vm_statistics64()
    var count = mach_msg_type_number_t(
      MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
    )
    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics64(host, HOST_VM_INFO64, $0, &count)
      }
    }

    guard result == KERN_SUCCESS else { return MemoryState() }

    return state(
      active: info.active_count,
      wired: info.wire_count,
      compressed: info.compressor_page_count,
      pageSize: UInt64(getpagesize()),
      totalBytes: ProcessInfo.processInfo.physicalMemory
    )
  }

  static func state(
    active: UInt32,
    wired: UInt32,
    compressed: UInt32,
    pageSize: UInt64,
    totalBytes: UInt64
  ) -> MemoryState {
    guard pageSize > 0 else { return MemoryState() }

    let pages = UInt64(active) + UInt64(wired) + UInt64(compressed)
    let (used, overflow) = pages.multipliedReportingOverflow(by: pageSize)
    guard !overflow else { return MemoryState() }

    let state = MemoryState(usedBytes: used, totalBytes: totalBytes)

    return state.available ? state : MemoryState()
  }
}
