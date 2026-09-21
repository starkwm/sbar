import AppKit

@MainActor
final class AerospaceProvider {
  static func query() async -> AerospaceState {
    guard let path = WorkspaceProvider.executable("aerospace") else {
      return AerospaceState(unavailable: "Aerospace not installed")
    }

    let displays = displayMapping()

    do {
      let result = try await ProcessRunner.run(
        executable: path,
        arguments: [
          "list-workspaces", "--all", "--json", "--format",
          "%{workspace}%{workspace-is-focused}%{workspace-is-visible}%{monitor-appkit-nsscreen-screens-id}",
        ],
        timeout: 2,
        mergeStandardError: false
      )
      guard result.exitCode == 0, displays == displayMapping() else { return AerospaceState() }

      return try AerospaceState.parse(Data(result.output.utf8), displays: displays)
    } catch { return AerospaceState() }
  }

  private static func displayMapping() -> [Int: String] {
    Dictionary(
      uniqueKeysWithValues: NSScreen.screens.enumerated().compactMap { index, screen in
        guard
          let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
            as? NSNumber,
          let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue()
        else { return nil }

        return (index + 1, CFUUIDCreateString(nil, uuid) as String)
      }
    )
  }

  private let read: @MainActor () async -> AerospaceState
  private var polling: Task<Void, Never>?
  private var refresh: Task<Void, Never>?
  private var update: (@MainActor (AerospaceState) -> Void)?
  private var generation = UUID()

  init(read: @escaping @MainActor () async -> AerospaceState = AerospaceProvider.query) {
    self.read = read
  }

  func start(update: @escaping @MainActor (AerospaceState) -> Void) {
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

      let state = await self.read()
      guard !Task.isCancelled, self.generation == generation else { return }

      self.refresh = nil
      self.update?(state)
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
