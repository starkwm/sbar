import Darwin

actor SystemMetricsSampler {
  private var cpu = CPUProvider()
  private var throughput = ThroughputProvider()

  func resetCPU() {
    cpu.reset()
  }

  func sample(_ types: Set<ItemType>) -> MetricsSnapshot {
    let host = mach_host_self()
    defer { mach_port_deallocate(mach_task_self_, host) }

    var values: [ItemType: String] = [:]

    let cpuState = types.contains(.cpu) ? cpu.sample(host: host) : nil
    let memoryState = types.contains(.memory) ? MemoryProvider.sample(host: host) : nil
    if types.contains(.disk) { values[.disk] = DiskProvider.sample() }
    if types.contains(.throughput) { values[.throughput] = throughput.sample() }

    return MetricsSnapshot(values: values, cpu: cpuState, memory: memoryState)
  }
}

struct MetricsSnapshot: Sendable {
  var values: [ItemType: String]
  var cpu: CPUState?
  var memory: MemoryState?
}
