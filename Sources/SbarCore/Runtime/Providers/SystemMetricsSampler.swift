import Darwin

actor SystemMetricsSampler {
  private var disk = DiskProvider()
  private var cpu = CPUProvider()
  private var throughput = ThroughputProvider()

  func resetBaselines() {
    cpu.reset()
    throughput.reset()
  }

  func sample(_ types: Set<ItemType>, diskPaths: Set<String> = []) -> MetricsSnapshot {
    let host = mach_host_self()
    defer { mach_port_deallocate(mach_task_self_, host) }

    let cpuState = types.contains(.cpu) ? cpu.sample(host: host) : nil
    let memoryState = types.contains(.memory) ? MemoryProvider.sample(host: host) : nil
    let disks = disk.sample(paths: diskPaths)
    let throughputState = types.contains(.throughput) ? throughput.sample() : nil

    return MetricsSnapshot(
      throughput: throughputState,
      cpu: cpuState,
      memory: memoryState,
      disks: disks
    )
  }
}

struct MetricsSnapshot: Sendable {
  var throughput: ThroughputState?
  var cpu: CPUState?
  var memory: MemoryState?
  var disks: [String: DiskState]
}
