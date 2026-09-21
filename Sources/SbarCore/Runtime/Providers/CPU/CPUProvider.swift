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
  private var previousTime: TimeInterval?
  private var samples: [Double] = []

  mutating func sample(host: host_t) -> CPUState {
    var info = host_cpu_load_info()
    var count = mach_msg_type_number_t(
      MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size
    )
    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
      }
    }

    let ticks =
      result == KERN_SUCCESS
      ? [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3] : nil

    return record(ticks: ticks, at: Date.timeIntervalSinceReferenceDate)
  }

  mutating func reset() {
    previousCPU = []
    previousTime = nil
    samples = []
  }

  mutating func record(ticks: [UInt32]?, at time: TimeInterval) -> CPUState {
    guard let ticks, ticks.count == 4 else {
      reset()

      return CPUState()
    }

    let elapsed = previousTime.map { time - $0 }
    let usage = Self.usage(previous: previousCPU, current: ticks)
    previousCPU = ticks
    previousTime = time
    guard let elapsed, elapsed > 0, elapsed <= 10, let usage else {
      samples = []

      return CPUState()
    }

    samples.append(usage * 100)

    if samples.count > 30 { samples.removeFirst(samples.count - 30) }

    return CPUState(samples: samples)
  }
}
