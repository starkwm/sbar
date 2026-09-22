import AppKit
import Foundation
import Testing

@testable import SbarCore

@Suite("MediaState")
@MainActor
struct MediaWidgetTests {
  @Test(
    "selected(source:): automatic selection prefers playing sources and uses recency to break ties"
  )
  func selection() {
    let playback = NotificationCenter()
    let provider = MediaProvider(playbackCenter: playback, workspaceCenter: NotificationCenter())
    var state = MediaState()
    provider.start { state = $0 }
    defer { provider.stop() }
    playback.post(
      name: MediaSource.music.notificationName,
      object: nil,
      userInfo: ["Player State": "Playing", "Name": "Music track", "Artist": "Artist"]
    )
    playback.post(
      name: MediaSource.spotify.notificationName,
      object: nil,
      userInfo: ["Player State": "Paused", "Name": "Spotify track"]
    )

    #expect(state.selected(source: .automatic)?.source == .music)
    #expect(state.selected(source: .spotify)?.title == "Spotify track")

    playback.post(
      name: MediaSource.spotify.notificationName,
      object: nil,
      userInfo: ["Player State": "Playing", "Name": "Spotify track"]
    )

    #expect(state.selected(source: nil)?.source == .spotify)

    playback.post(
      name: MediaSource.music.notificationName,
      object: nil,
      userInfo: ["Player State": "Playing", "Name": "Music track"]
    )

    #expect(state.selected(source: nil)?.source == .music)

    playback.post(
      name: MediaSource.music.notificationName,
      object: nil,
      userInfo: ["Player State": "Paused"]
    )

    #expect(state.selected(source: nil)?.source == .spotify)
    #expect(state.selected(source: .music)?.title == "Music track")
  }

  @Test(
    "MediaPlayerState.parse: preserves paused metadata, clears stopped tracks, and handles malformed fields"
  )
  func parsing() {
    let playing = MediaPlayerState.parse(
      ["Player State": " Playing ", "Name": " Title ", "Artist": " Artist "],
      source: .music,
      previous: nil,
      sequence: 1
    )

    #expect(playing.status == .playing)
    #expect(playing.title == "Title")
    #expect(playing.artist == "Artist")

    let paused = MediaPlayerState.parse(
      ["Player State": "Paused"],
      source: .music,
      previous: playing,
      sequence: 2
    )

    #expect(paused.title == "Title")
    #expect(paused.artist == "Artist")

    let changed = MediaPlayerState.parse(
      ["Player State": "Playing", "Name": "New"],
      source: .music,
      previous: paused,
      sequence: 3
    )

    #expect(changed.artist.isEmpty)

    let missing = MediaPlayerState.parse(
      ["Player State": "Playing"],
      source: .music,
      previous: changed,
      sequence: 4
    )

    #expect(missing.title.isEmpty)

    for info in [nil, ["Player State": "Stopped"], ["Player State": "Unexpected"]]
      as [[String: String]?]
    {
      let state = MediaPlayerState.parse(info, source: .music, previous: playing, sequence: 5)

      #expect(state.title.isEmpty)
      #expect(state.artist.isEmpty)
      #expect(state.status == (info?["Player State"] == "Stopped" ? .stopped : .unknown))
    }

    let playback = NotificationCenter()
    let provider = MediaProvider(playbackCenter: playback, workspaceCenter: NotificationCenter())
    var result = MediaState()
    provider.start { result = $0 }
    defer { provider.stop() }
    playback.post(
      name: MediaSource.music.notificationName,
      object: nil,
      userInfo: ["Player State": "Playing", "Name": 123, "Artist": ["invalid"]]
    )

    #expect(result.text == "Playing")

    playback.post(
      name: MediaSource.music.notificationName,
      object: nil,
      userInfo: ["Name": "No state"]
    )

    #expect(result.text == "Playback unavailable")
  }

  @Test(
    "presentation(for:): title, artist, separator, state symbols, and hidden states retain accessible metadata"
  )
  func appearance() {
    var state = MediaState(players: [
      .music: MediaPlayerState(source: .music, status: .playing, title: "Title", artist: "Artist")
    ])
    var item = Item(
      id: "media",
      type: .media,
      media: MediaConfiguration(
        symbols: MediaSymbols(
          font: "Shared",
          size: 18,
          playing: .glyph("P"),
          paused: .system("pause")
        ),
        hideWhenPaused: true,
        hideWhenStopped: true
      )
    )
    let playing = state.presentation(for: item)

    #expect(playing.text == "Title — Artist")
    #expect(playing.symbol == .glyph("P", font: "Shared", size: 18))
    #expect(playing.accessibilityLabel == "Music, Playing, Title, Artist")
    #expect(!playing.hidden)

    state.players[.music]?.status = .paused

    #expect(state.presentation(for: item).hidden)
    #expect(state.presentation(for: item).text == "Title — Artist")
    #expect(state.presentation(for: item).symbol == "pause")

    #expect(state.presentation(for: item).accessibilityLabel.contains("Artist"))

    item.symbol = "star"

    #expect(state.presentation(for: item).symbol == "star")

    item.media?.showSymbol = false

    #expect(state.presentation(for: item).symbol == nil)

    state.players[.music] = MediaPlayerState(source: .music, status: .stopped)

    #expect(state.presentation(for: item).hidden)
    #expect(MediaState().text == "Waiting for playback")
    #expect(
      MediaState(players: [.music: MediaPlayerState(source: .music, status: .paused)]).text
        == "Paused"
    )
    #expect(
      MediaState(players: [.music: MediaPlayerState(source: .music, status: .stopped)]).text
        == "Stopped"
    )

    item.media?.source = .spotify

    #expect(!state.presentation(for: item).hidden)

    for name in ["play.fill", "pause.fill", "stop.fill", "questionmark"] {
      #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil)
    }
  }

  @Test(
    "ProviderRuntime.presentation(for:): hideWhenNotPlaying follows playback notifications and the selected source"
  )
  func playbackVisibility() {
    let playback = NotificationCenter()
    let provider = MediaProvider(playbackCenter: playback, workspaceCenter: NotificationCenter())
    var state = MediaState()
    provider.start { state = $0 }
    defer { provider.stop() }
    var item = Item(
      id: "media",
      type: .media,
      media: MediaConfiguration(hideWhenNotPlaying: true)
    )

    #expect(state.presentation(for: item).hidden)

    for status in ["Playing", "Paused", "Playing", "Stopped", "Unexpected"] {
      playback.post(
        name: MediaSource.music.notificationName,
        object: nil,
        userInfo: ["Player State": status]
      )

      #expect(state.presentation(for: item).hidden == (status != "Playing"))
    }

    playback.post(
      name: MediaSource.music.notificationName,
      object: nil,
      userInfo: ["Player State": "Playing", "Name": "Music track"]
    )
    item.media?.source = .spotify

    #expect(state.presentation(for: item).hidden)

    playback.post(
      name: MediaSource.spotify.notificationName,
      object: nil,
      userInfo: ["Player State": "Paused", "Name": "Spotify track"]
    )

    #expect(state.presentation(for: item).hidden)

    item.media?.source = .automatic

    #expect(!state.presentation(for: item).hidden)
    #expect(state.presentation(for: item).text == "Music track")
  }

  @Test("MediaProvider.start: termination clears a player's track and restores the other source")
  func termination() {
    let playback = NotificationCenter()
    let workspace = NotificationCenter()
    let provider = MediaProvider(
      playbackCenter: playback,
      workspaceCenter: workspace,
      terminatedBundle: { $0.userInfo?["bundle"] as? String }
    )
    var state = MediaState()
    provider.start { state = $0 }
    defer { provider.stop() }
    playback.post(
      name: MediaSource.music.notificationName,
      object: nil,
      userInfo: ["Player State": "Playing", "Name": "Music track"]
    )
    playback.post(
      name: MediaSource.spotify.notificationName,
      object: nil,
      userInfo: ["Player State": "Playing", "Name": "Spotify track"]
    )
    workspace.post(
      name: NSWorkspace.didTerminateApplicationNotification,
      object: nil,
      userInfo: ["bundle": "com.spotify.client"]
    )

    #expect(state.players[.spotify]?.status == .stopped)
    #expect(state.players[.spotify]?.title.isEmpty == true)
    #expect(state.selected(source: nil)?.source == .music)

    let previous = state
    workspace.post(
      name: NSWorkspace.didTerminateApplicationNotification,
      object: nil,
      userInfo: ["bundle": "unrelated"]
    )

    #expect(state == previous)
  }

  @Test(
    "MediaProvider.start: repeated start replaces observers, stop detaches both centers, and restart resets state"
  )
  func lifecycle() {
    let playback = NotificationCenter()
    let workspace = NotificationCenter()
    let provider = MediaProvider(
      playbackCenter: playback,
      workspaceCenter: workspace,
      terminatedBundle: { $0.userInfo?["bundle"] as? String }
    )
    var oldUpdates = 0
    var updates: [MediaState] = []
    provider.start { _ in oldUpdates += 1 }
    provider.start { updates.append($0) }
    playback.post(
      name: MediaSource.music.notificationName,
      object: nil,
      userInfo: ["Player State": "Playing", "Name": "Track"]
    )

    #expect(oldUpdates == 1)
    #expect(updates.count == 2)

    provider.stop()
    playback.post(
      name: MediaSource.music.notificationName,
      object: nil,
      userInfo: ["Player State": "Paused"]
    )
    workspace.post(
      name: NSWorkspace.didTerminateApplicationNotification,
      object: nil,
      userInfo: ["bundle": "com.apple.Music"]
    )

    #expect(updates.count == 2)

    provider.start { updates.append($0) }

    #expect(updates.last?.players.isEmpty == true)

    workspace.post(
      name: NSWorkspace.didTerminateApplicationNotification,
      object: nil,
      userInfo: ["bundle": "com.apple.Music"]
    )

    #expect(updates.count == 4)

    provider.stop()
  }

  @Test(
    "MediaConfiguration.validate: configuration round trips and validates source and glyph settings"
  )
  func configuration() throws {
    let item = try JSONDecoder().decode(
      Item.self,
      from: Data(
        #"{"id":"media","type":"media","media":{"source":"spotify","showSymbol":true,"hideWhenPaused":true,"hideWhenStopped":true,"hideWhenNotPlaying":true,"symbols":{"font":"Shared","size":18,"playing":{"glyph":"P"}}}}"#
          .utf8
      )
    )
    try item.media?.validate(path: "media")

    #expect(item.media?.hideWhenNotPlaying == true)
    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)

    for json in ["{}", #"{"hideWhenNotPlaying":null}"#, #"{"hideWhenNotPlaying":false}"#] {
      let settings = try JSONDecoder().decode(MediaConfiguration.self, from: Data(json.utf8))
      let defaultItem = Item(id: "media", type: .media, media: settings)

      #expect(!MediaState().presentation(for: defaultItem).hidden)
    }
    for json in [
      #"{"source":"invalid"}"#,
      #"{"hideWhenNotPlaying":"true"}"#,
      #"{"symbols":{"font":" "}}"#, #"{"symbols":{"size":73}}"#,
      #"{"symbols":{"playing":{"glyph":"P"}}}"#,
    ] {
      #expect(throws: (any Error).self) {
        let settings = try JSONDecoder().decode(MediaConfiguration.self, from: Data(json.utf8))
        try settings.validate(path: "media")
      }
    }

    #expect(throws: ConfigurationError.self) {
      try Configuration(
        bar: .init(),
        items: .init(right: [Item(id: "text", type: .text, media: MediaConfiguration())])
      ).validate()
    }
  }

  @Test(
    "ProviderRuntime.presentation(for:): refresh captures source and playback changes even when track text stays unchanged"
  )
  func refresh() throws {
    for mode in ["manual", "event"] {
      let configuration = try JSONDecoder().decode(
        Configuration.self,
        from: Data(
          """
          {"schemaVersion":1,"bar":{},"items":{"right":[{"id":"media","type":"media","media":{"source":"music","hideWhenPaused":true},"refresh":{"mode":"\(mode)"}}]}}
          """.utf8
        )
      )
      let runtime = ProviderRuntime()
      runtime.configure(configuration)
      defer { runtime.stop() }
      let item = try #require(configuration.items.active.first)
      var state = MediaState(players: [
        .music: MediaPlayerState(source: .music, status: .playing, title: "Track")
      ])
      runtime.updateWidgetState(.media(state), for: .media)
      runtime.trigger("media")

      #expect(runtime.presentation(for: item)?.symbol == "play.fill")

      state.players[.music]?.status = .paused
      state.players[.spotify] = MediaPlayerState(source: .spotify, status: .playing, title: "Other")
      runtime.updateWidgetState(.media(state), for: .media)

      #expect(runtime.presentation(for: item)?.hidden == (mode == "event"))

      runtime.trigger("media")

      #expect(runtime.presentation(for: item)?.symbol == "pause.fill")
      #expect(runtime.presentation(for: item)?.text == "Track")
      #expect(runtime.presentation(for: item)?.hidden == true)
    }
  }
}
