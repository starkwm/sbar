import ArgumentParser
import Foundation
import SbarCore

struct RemindersCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "reminders",
    abstract: "Inspect native Reminders lists. Reading requires full Reminders permission.",
    subcommands: [RemindersListsCommand.self]
  )
}

struct RemindersListsCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "lists",
    abstract: "Request Reminders access and print list IDs, titles and accounts as JSON."
  )

  @MainActor
  static func output(
    read: @MainActor () async throws -> [ReminderList] = { try await RemindersDiscovery.lists() }
  ) async throws -> String {
    let lists = try await read()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return String(decoding: try encoder.encode(lists), as: UTF8.self)
  }

  mutating func run() throws {
    // Keep the CLI's main run loop available for the native authorization callback,
    // without changing how the synchronous start command launches AppKit.
    try MainActor.assumeIsolated {
      var result: Result<String, any Error>?
      Task { @MainActor in
        do { result = .success(try await Self.output()) } catch {
          result = .failure(error)
        }
      }
      while result == nil {
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
      }
      print(try result!.get())
    }
  }
}
