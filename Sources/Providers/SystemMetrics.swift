import Darwin
import Foundation

actor SystemMetrics {
    static func cpuUsage(previous: [UInt32], current: [UInt32]) -> Double? {
        guard previous.count == 4, current.count == 4 else { return nil }
        let delta = zip(current, previous).map { Double($0 &- $1) }
        let total = delta.reduce(0, +)
        return total > 0 ? (total - delta[Int(CPU_STATE_IDLE)]) / total : nil
    }

    private var previousCPU: [UInt32] = []
    private var previousNetwork: (date: Date, received: UInt64, sent: UInt64)?

    func sample(_ types: Set<ItemType>) -> [ItemType: String] {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        var values: [ItemType: String] = [:]
        if types.contains(.cpu) {
            var info = host_cpu_load_info()
            var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
                }
            }
            if result == KERN_SUCCESS {
                let current = [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3]
                values[.cpu] = Self.cpuUsage(previous: previousCPU, current: current).map { "CPU \(Int($0 * 100))%" } ?? "CPU —"
                previousCPU = current
            }
        }
        if types.contains(.memory) {
            var info = vm_statistics64()
            var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    host_statistics64(host, HOST_VM_INFO64, $0, &count)
                }
            }
            if result == KERN_SUCCESS {
                let pages = UInt64(info.active_count) + UInt64(info.wire_count) + UInt64(info.compressor_page_count)
                let used = pages * UInt64(getpagesize())
                values[.memory] = "RAM \(ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .memory))"
            }
        }
        if types.contains(.disk) {
            if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
               let free = attributes[.systemFreeSize] as? NSNumber {
                values[.disk] = "\(ByteCountFormatter.string(fromByteCount: free.int64Value, countStyle: .file)) free"
            }
        }
        if types.contains(.throughput) {
            var head: UnsafeMutablePointer<ifaddrs>?
            if getifaddrs(&head) == 0 {
                defer { freeifaddrs(head) }
                var received: UInt64 = 0
                var sent: UInt64 = 0
                var cursor = head
                while let entry = cursor {
                    let interface = entry.pointee
                    if interface.ifa_addr?.pointee.sa_family == UInt8(AF_LINK), interface.ifa_flags & UInt32(IFF_LOOPBACK) == 0,
                       let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self).pointee {
                        received += UInt64(data.ifi_ibytes)
                        sent += UInt64(data.ifi_obytes)
                    }
                    cursor = interface.ifa_next
                }
                let now = Date()
                if let previousNetwork {
                    let seconds = max(0.1, now.timeIntervalSince(previousNetwork.date))
                    let down = received >= previousNetwork.received ? Double(received - previousNetwork.received) / seconds : 0
                    let up = sent >= previousNetwork.sent ? Double(sent - previousNetwork.sent) / seconds : 0
                    values[.throughput] = "↓\(Int(down / 1024)) ↑\(Int(up / 1024)) KB/s"
                }
                previousNetwork = (now, received, sent)
            }
        }
        return values
    }
}
