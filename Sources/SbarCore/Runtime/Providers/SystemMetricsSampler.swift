import Darwin

actor SystemMetricsSampler {
  private var disk = DiskProvider()
  private var cpu = CPUProvider()
  private var throughput = ThroughputProvider()

  func resetCPU() {
    cpu.reset()
  }

  func sample(_ types: Set<ItemType>, diskPaths: Set<String> = []) -> MetricsSnapshot {
    let host = mach_host_self()
    defer { mach_port_deallocate(mach_task_self_, host) }

    var values: [ItemType: String] = [:]

    let cpuState = types.contains(.cpu) ? cpu.sample(host: host) : nil
    let memoryState = types.contains(.memory) ? MemoryProvider.sample(host: host) : nil
    let disks = disk.sample(paths: diskPaths)
    if types.contains(.throughput) { values[.throughput] = throughput.sample() }

    return MetricsSnapshot(values: values, cpu: cpuState, memory: memoryState, disks: disks)
  }
}

struct MetricsSnapshot: Sendable {
  var values: [ItemType: String]
  var cpu: CPUState?
  var memory: MemoryState?
  var disks: [String: DiskState]
}
