import Darwin

actor SystemMetricsSampler {
  private var cpu = CPUProvider()
  private var throughput = ThroughputProvider()

  func sample(_ types: Set<ItemType>) -> [ItemType: String] {
    let host = mach_host_self()
    defer { mach_port_deallocate(mach_task_self_, host) }

    var values: [ItemType: String] = [:]

    if types.contains(.cpu) { values[.cpu] = cpu.sample(host: host) }
    if types.contains(.memory) { values[.memory] = MemoryProvider.sample(host: host) }
    if types.contains(.disk) { values[.disk] = DiskProvider.sample() }
    if types.contains(.throughput) { values[.throughput] = throughput.sample() }

    return values
  }
}
