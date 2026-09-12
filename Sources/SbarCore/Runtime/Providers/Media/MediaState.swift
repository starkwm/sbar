import Foundation

struct MediaState: Equatable, Sendable {
  var players: [MediaSource: MediaPlayerState] = [:]

  var text: String { presentation(for: Item(id: "media", type: .media)).text }

  func selected(source: MediaSourceSelection?) -> MediaPlayerState? {
    switch source {
    case .music: return players[.music]
    case .spotify: return players[.spotify]
    case .automatic, nil:
      return players.values.max {
        if $0.status.priority != $1.status.priority {
          return $0.status.priority < $1.status.priority
        }
        return $0.sequence < $1.sequence
      }
    }
  }

  func presentation(for item: Item) -> WidgetPresentation {
    let settings = item.media ?? MediaConfiguration()
    let player = selected(source: settings.source)
    let status = player?.status ?? .unknown
    let fallback: String
    let symbol: ItemSymbol
    let selectedSymbol: WidgetSymbol?
    switch status {
    case .playing:
      fallback = "Playing"
      symbol = "play.fill"
      selectedSymbol = settings.symbols?.playing
    case .paused:
      fallback = "Paused"
      symbol = "pause.fill"
      selectedSymbol = settings.symbols?.paused
    case .stopped:
      fallback = "Stopped"
      symbol = "stop.fill"
      selectedSymbol = settings.symbols?.stopped
    case .unknown:
      fallback = player == nil ? "Waiting for playback" : "Playback unavailable"
      symbol = "questionmark"
      selectedSymbol = settings.symbols?.unavailable
    }
    let metadata = [player?.title ?? "", player?.artist ?? ""].filter { !$0.isEmpty }
    let visible = [
      settings.showTitle == false ? "" : player?.title ?? "",
      settings.showArtist == false ? "" : player?.artist ?? "",
    ].filter { !$0.isEmpty }
    let separator = settings.separator ?? " — "
    let label =
      ([player?.source.name ?? "", status == .unknown ? fallback : status.rawValue.capitalized]
      + metadata)
      .filter { !$0.isEmpty }.joined(separator: ", ")
    return WidgetPresentation(
      text: settings.showTitle == false && settings.showArtist == false
        ? "" : visible.isEmpty ? fallback : visible.joined(separator: separator),
      symbol: settings.showSymbol == false
        ? nil : item.symbol ?? settings.symbols?.resolve(selectedSymbol) ?? symbol,
      hidden: status == .paused && settings.hideWhenPaused == true
        || status == .stopped && settings.hideWhenStopped == true
        || status != .playing && settings.hideWhenNotPlaying == true,
      accessibilityLabel: label
    )
  }
}

enum MediaSource: String, CaseIterable, Sendable {
  case music, spotify

  var name: String { self == .music ? "Music" : "Spotify" }
  var bundleIdentifier: String { self == .music ? "com.apple.Music" : "com.spotify.client" }
  var notificationName: Notification.Name {
    Notification.Name(
      self == .music ? "com.apple.Music.playerInfo" : "com.spotify.client.PlaybackStateChanged"
    )
  }
}

enum MediaPlaybackStatus: String, Sendable {
  case playing, paused, stopped, unknown

  var priority: Int {
    switch self {
    case .playing: 3
    case .paused: 2
    case .stopped: 1
    case .unknown: 0
    }
  }
}

struct MediaPlayerState: Equatable, Sendable {
  static func parse(
    _ info: [String: String]?,
    source: MediaSource,
    previous: Self?,
    sequence: UInt64
  ) -> Self {
    let raw = info?["Player State"]?.trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    let status = raw.flatMap(MediaPlaybackStatus.init(rawValue:)) ?? .unknown
    guard status == .playing || status == .paused else {
      return Self(source: source, status: status, sequence: sequence)
    }
    let title = info?["Name"]?.trimmingCharacters(in: .whitespacesAndNewlines)
    let artist = info?["Artist"]?.trimmingCharacters(in: .whitespacesAndNewlines)
    let sameTrack = title == previous?.title || (status == .paused && title == nil)
    return Self(
      source: source,
      status: status,
      title: title ?? (sameTrack ? previous?.title ?? "" : ""),
      artist: artist ?? (sameTrack ? previous?.artist ?? "" : ""),
      sequence: sequence
    )
  }

  var source: MediaSource
  var status: MediaPlaybackStatus
  var title: String = ""
  var artist: String = ""
  var sequence: UInt64 = 0
}
