import Darwin
import Foundation

struct CPUProvider {
  static func usage(previous: [UInt32], current: [UInt32]) -> Double? {
    guard previous.count == 4, current.count == 4 else { return nil }

    let delta = zip(current, previous).map { Double($0 &- $1) }
    let total = delta.reduce(0, +)

    return total > 0 ? (total - delta[Int(CPU_STATE_IDLE)]) / total : nil
  }

  private var previousCPU: [UInt32] = []

  mutating func sample(host: host_t) -> String? {
    var info = host_cpu_load_info()
    var count = mach_msg_type_number_t(
      MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size
    )
    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
      }
    }

    if result == KERN_SUCCESS {
      let current = [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3]
      let value =
        Self.usage(previous: previousCPU, current: current).map { "CPU \(Int($0 * 100))%" }
        ?? "CPU —"
      previousCPU = current
      return value
    }

    return nil
  }
}
