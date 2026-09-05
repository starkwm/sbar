import Foundation

@MainActor
final class MediaProvider {
  private var observers: [NSObjectProtocol] = []

  func start(update: @escaping @MainActor (String) -> Void) {
    stop()
    update("Waiting for playback")

    for name in ["com.apple.Music.playerInfo", "com.spotify.client.PlaybackStateChanged"] {
      let token = DistributedNotificationCenter.default().addObserver(
        forName: Notification.Name(name),
        object: nil,
        queue: .main
      ) { notification in
        let info = notification.userInfo
        let state = info?["Player State"] as? String ?? ""
        let title = info?["Name"] as? String ?? ""
        let artist = info?["Artist"] as? String ?? ""
        let value =
          state == "Playing"
          ? [title, artist].filter { !$0.isEmpty }.joined(separator: " — ") : "Paused"

        MainActor.assumeIsolated { update(value) }
      }
      observers.append(token)
    }
  }

  func stop() {
    for observer in observers { DistributedNotificationCenter.default().removeObserver(observer) }
    observers.removeAll()
  }
}
