import Testing

@testable import SbarCore

struct ProviderTests {
  @Test("CPU usage uses sample deltas, not lifetime totals")
  func cpuDelta() {
    #expect(
      SystemMetricsSampler.cpuUsage(previous: [100, 100, 800, 0], current: [120, 110, 870, 0])
        == 0.3
    )
    #expect(SystemMetricsSampler.cpuUsage(previous: [], current: [1, 2, 3, 4]) == nil)
    #expect(SystemMetricsSampler.cpuUsage(previous: [1, 2, 3, 4], current: [1, 2, 3, 4]) == nil)
  }
}
