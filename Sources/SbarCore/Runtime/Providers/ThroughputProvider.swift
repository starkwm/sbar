import Darwin
import Foundation

struct ThroughputProvider {
  private var previousNetwork: (date: Date, received: UInt64, sent: UInt64)?

  mutating func sample() -> String? {
    var head: UnsafeMutablePointer<ifaddrs>?
    if getifaddrs(&head) == 0 {
      defer { freeifaddrs(head) }
      var received: UInt64 = 0
      var sent: UInt64 = 0
      var cursor = head

      while let entry = cursor {
        let interface = entry.pointee
        if interface.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
          interface.ifa_flags & UInt32(IFF_LOOPBACK) == 0,
          let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self).pointee
        {
          received += UInt64(data.ifi_ibytes)
          sent += UInt64(data.ifi_obytes)
        }
        cursor = interface.ifa_next
      }

      let now = Date()
      var value: String?
      if let previousNetwork {
        let seconds = max(0.1, now.timeIntervalSince(previousNetwork.date))
        let down =
          received >= previousNetwork.received
          ? Double(received - previousNetwork.received) / seconds : 0
        let up = sent >= previousNetwork.sent ? Double(sent - previousNetwork.sent) / seconds : 0
        value = "↓\(Int(down / 1024)) ↑\(Int(up / 1024)) KB/s"
      }

      previousNetwork = (now, received, sent)
      return value
    }

    return nil
  }
}
