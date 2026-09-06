import AppKit
import Foundation

@MainActor
final class MediaProvider {
  private let playbackCenter: NotificationCenter
  private let workspaceCenter: NotificationCenter
  private let terminatedBundle: @Sendable (Notification) -> String?
  private var observers: [NSObjectProtocol] = []
  private var terminationObserver: NSObjectProtocol?
  private var state = MediaState()
  private var sequence: UInt64 = 0
  private var generation = UUID()
  private var update: (@MainActor (MediaState) -> Void)?

  init(
    playbackCenter: NotificationCenter = DistributedNotificationCenter.default(),
    workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
    terminatedBundle: @escaping @Sendable (Notification) -> String? = {
      ($0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
    }
  ) {
    self.playbackCenter = playbackCenter
    self.workspaceCenter = workspaceCenter
    self.terminatedBundle = terminatedBundle
  }

  func start(update: @escaping @MainActor (MediaState) -> Void) {
    stop()
    self.update = update
    update(state)
    let generation = generation
    for source in MediaSource.allCases {
      let token = playbackCenter.addObserver(
        forName: source.notificationName,
        object: nil,
        queue: .main
      ) { [weak self] notification in
        let info = notification.userInfo
        let metadata = ["Player State", "Name", "Artist"].reduce(into: [String: String]()) {
          if let value = info?[$1] as? String { $0[$1] = value }
        }
        MainActor.assumeIsolated {
          guard let self, self.generation == generation else { return }
          self.sequence += 1
          self.state.players[source] = MediaPlayerState.parse(
            metadata,
            source: source,
            previous: self.state.players[source],
            sequence: self.sequence
          )
          self.update?(self.state)
        }
      }
      observers.append(token)
    }
    let terminatedBundle = terminatedBundle
    terminationObserver = workspaceCenter.addObserver(
      forName: NSWorkspace.didTerminateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      let identifier = terminatedBundle(notification)
      MainActor.assumeIsolated {
        guard let self, self.generation == generation,
          let identifier,
          let source = MediaSource.allCases.first(where: { $0.bundleIdentifier == identifier })
        else { return }
        self.sequence += 1
        self.state.players[source] = MediaPlayerState(
          source: source,
          status: .stopped,
          sequence: self.sequence
        )
        self.update?(self.state)
      }
    }
  }

  func stop() {
    generation = UUID()
    for observer in observers { playbackCenter.removeObserver(observer) }
    observers = []
    if let terminationObserver { workspaceCenter.removeObserver(terminationObserver) }
    terminationObserver = nil
    update = nil
    state = MediaState()
    sequence = 0
  }
}
