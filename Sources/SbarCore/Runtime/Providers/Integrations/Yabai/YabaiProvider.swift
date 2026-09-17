import Foundation

@MainActor
final class YabaiProvider {
  static func query() async -> YabaiState {
    guard let path = WorkspaceProvider.executable("yabai") else {
      return YabaiState(unavailable: "Yabai not installed")
    }
    do {
      let before = try await queryDisplays(path)
      let result = try await ProcessRunner.run(
        executable: path,
        arguments: ["-m", "query", "--spaces"],
        timeout: 2,
        mergeStandardError: false
      )
      guard result.exitCode == 0 else { return YabaiState() }
      let after = try await queryDisplays(path)
      guard before == after else { return YabaiState() }
      return try YabaiState.parse(Data(result.output.utf8), displays: after)
    } catch { return YabaiState() }
  }

  private static func queryDisplays(_ path: String) async throws -> [YabaiDisplay] {
    let result = try await ProcessRunner.run(
      executable: path,
      arguments: ["-m", "query", "--displays"],
      timeout: 2,
      mergeStandardError: false
    )
    guard result.exitCode == 0 else { throw ProcessError.exitStatus(result.exitCode) }
    return try JSONDecoder().decode([YabaiDisplay].self, from: Data(result.output.utf8)).sorted {
      $0.index < $1.index
    }
  }

  private let retryInterval: Duration
  private let read: @MainActor () async -> YabaiState
  private var polling: Task<Void, Never>?
  private var refresh: Task<Void, Never>?
  private var update: (@MainActor (YabaiState) -> Void)?
  private var generation = UUID()

  init(
    retryInterval: Duration = .milliseconds(100),
    read: @escaping @MainActor () async -> YabaiState = YabaiProvider.query
  ) {
    self.retryInterval = retryInterval
    self.read = read
  }

  func start(update: @escaping @MainActor (YabaiState) -> Void) {
    stop()
    self.update = update
    requestRefresh()
    polling = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(2)) } catch { return }
        guard let self else { return }
        if self.refresh == nil { self.requestRefresh() }
      }
    }
  }

  func requestRefresh() {
    guard update != nil else { return }
    refresh?.cancel()
    generation = UUID()
    let generation = generation
    refresh = Task { [weak self] in
      do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
      guard let self else { return }
      for attempt in 0..<3 {
        let state = await self.read()
        guard !Task.isCancelled, self.generation == generation else { return }
        if state.unavailable == nil || state.unavailable == "Yabai not installed" || attempt == 2 {
          self.refresh = nil
          self.update?(state)
          return
        }
        do { try await Task.sleep(for: self.retryInterval) } catch { return }
      }
    }
  }

  func stop() {
    generation = UUID()
    polling?.cancel()
    polling = nil
    refresh?.cancel()
    refresh = nil
    update = nil
  }
}
