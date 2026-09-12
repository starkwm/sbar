import Darwin
import Foundation

struct ThroughputProvider {
  private let origin = ContinuousClock.now
  private var previous: [String: ThroughputCounters] = [:]
  private var previousTime: Double?
  private var histories: [String: [ThroughputRate]] = [:]

  mutating func sample() -> ThroughputState {
    let duration = origin.duration(to: .now).components
    let now = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
    var head: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&head) == 0 else { return record(counters: nil, at: now) }
    defer { freeifaddrs(head) }
    var counters: [String: ThroughputCounters] = [:]
    var cursor = head
    while let entry = cursor {
      let interface = entry.pointee
      if interface.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
        interface.ifa_flags & UInt32(IFF_LOOPBACK) == 0,
        let name = interface.ifa_name,
        let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self).pointee
      {
        counters[String(cString: name)] = ThroughputCounters(
          received: UInt64(data.ifi_ibytes),
          sent: UInt64(data.ifi_obytes),
          index: if_nametoindex(name)
        )
      }
      cursor = interface.ifa_next
    }
    return record(counters: counters, at: now)
  }

  mutating func reset() {
    previous = [:]
    previousTime = nil
    histories = [:]
  }

  mutating func record(counters: [String: ThroughputCounters]?, at time: Double) -> ThroughputState
  {
    guard let counters, time.isFinite else {
      reset()
      return ThroughputState()
    }
    let elapsed = previousTime.map { time - $0 }
    defer {
      previous = counters
      previousTime = time
    }
    guard let elapsed, elapsed > 0, elapsed <= 10 else {
      histories = [:]
      return ThroughputState()
    }
    histories = histories.filter { counters[$0.key] != nil }
    for (name, current) in counters {
      guard let old = previous[name], old.index == current.index,
        current.received >= old.received, current.sent >= old.sent
      else {
        histories[name] = []
        continue
      }
      let rate = ThroughputRate(
        download: Double(current.received - old.received) / elapsed,
        upload: Double(current.sent - old.sent) / elapsed
      )
      var history = histories[name] ?? []
      history.append(rate)
      if history.count > 30 { history.removeFirst(history.count - 30) }
      histories[name] = history
    }
    return ThroughputState(histories: histories)
  }
}

struct ThroughputCounters {
  var received: UInt64
  var sent: UInt64
  var index: UInt32 = 0
}
