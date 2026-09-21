import Testing

/// Returns as soon as asynchronous work completes, with a deadline for failures.
@MainActor
func waitUntil(
  timeout: Duration = .seconds(2),
  sourceLocation: SourceLocation = #_sourceLocation,
  _ condition: () -> Bool
) async throws {
  let deadline = ContinuousClock.now.advanced(by: timeout)

  while !condition(), ContinuousClock.now < deadline {
    try await Task.sleep(for: .milliseconds(5))
  }

  #expect(
    condition(),
    "Condition did not become true before the deadline",
    sourceLocation: sourceLocation
  )
}
