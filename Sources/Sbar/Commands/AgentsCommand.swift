import ArgumentParser
import Foundation
import SbarCore

struct AgentsCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "agents",
    abstract: "Report and inspect native agent activity.",
    subcommands: [Report.self, List.self, Dismiss.self, Setup.self, Doctor.self]
  )

  struct Report: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Send an acknowledged activity report. JSON input uses version 1."
    )
    @OptionGroup var options: SocketOptions
    @Option var source: String?
    @Option var session: String?
    @Option(name: .customLong("run")) var runID: String?
    @Option var state: String?
    @Option var sequence: Int = 0
    @Option var replaces: String?
    @Option var title: String?
    @Option var project: String?
    @Option var agent: String?
    @Option var host: String?
    @Option var identity: String?
    @Option var heartbeatSeconds: Double?
    @Option(help: "Versioned JSON file, or - for standard input.") var json: String?

    mutating func run() throws {
      let value: JSONValue
      if let json {
        let data =
          try json == "-"
          ? FileHandle.standardInput.readToEnd() ?? Data()
          : Data(contentsOf: URL(fileURLWithPath: json))
        value = try JSONDecoder().decode(JSONValue.self, from: data)
      } else {
        guard let source, let session, let run = runID, let state else {
          throw ValidationError("Expected --source, --session, --run and --state, or --json.")
        }
        var fields: [String: JSONValue] = [
          "version": .number(1), "source": .string(source), "session": .string(session),
          "run": .string(run), "state": .string(state), "sequence": .number(Double(sequence)),
        ]
        for (key, value) in [
          "replaces": replaces, "title": title, "project": project, "agent": agent, "host": host,
          "identity": identity,
        ] { if let value { fields[key] = .string(value) } }
        if let heartbeatSeconds { fields["heartbeatSeconds"] = .number(heartbeatSeconds) }
        value = .object(fields)
      }
      try options.send(ControlRequest(command: "agents", arguments: ["report"], value: value))
    }
  }

  struct List: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List reported sessions as JSON.")
    @OptionGroup var options: SocketOptions
    mutating func run() throws {
      try options.send(ControlRequest(command: "agents", arguments: ["list"]))
    }
  }

  struct Dismiss: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Dismiss a conversation until its next run or state change."
    )
    @OptionGroup var options: SocketOptions
    @Option var source: String
    @Option var session: String
    mutating func run() throws {
      try options.send(ControlRequest(command: "agents", arguments: ["dismiss", source, session]))
    }
  }
  struct Setup: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Install or remove owned agent hooks in an explicit config root."
    )
    @OptionGroup var options: SocketOptions
    @Option var source: String
    @Option var root: String
    @Flag var remove = false
    mutating func run() throws {
      try AgentsCommand.adapter(
        ["setup", "--source", source, "--root", root, "--socket", options.socket]
          + ["--sbar", AgentsCommand.executablePath]
          + (remove ? ["--remove"] : [])
      )
    }
  }

  struct Doctor: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Check adapter executable and native reporting socket."
    )
    @OptionGroup var options: SocketOptions
    @Option var source: String
    mutating func run() throws {
      try AgentsCommand.adapter(
        ["doctor", "--source", source, "--socket", options.socket]
          + ["--sbar", AgentsCommand.executablePath]
      )
    }
  }

  // Installed hooks call back into this binary. Symlinks stay unresolved so upgrades keep working.
  static var executablePath: String {
    let invoked = CommandLine.arguments[0]
    if invoked.contains("/") { return URL(fileURLWithPath: invoked).standardizedFileURL.path }
    let paths = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":")
    return paths.map { "\($0)/\(invoked)" }.first {
      FileManager.default.isExecutableFile(atPath: $0)
    } ?? invoked
  }

  static func adapter(_ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = try [ControlClient.agentAdapterURL().path] + arguments
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw ExitCode(process.terminationStatus) }
  }

}
