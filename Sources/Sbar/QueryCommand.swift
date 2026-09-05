import ArgumentParser
import Foundation
import SbarCore

struct QueryCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "query",
    abstract: "Query the running bar."
  )
  @OptionGroup var options: SocketOptions

  @Flag(help: "Show configuration errors, action failures, and recent events.")
  var diagnostics = false

  @Flag(help: "List connected display IDs and names.")
  var displays = false

  mutating func validate() throws {
    if diagnostics && displays {
      throw ValidationError("Choose either --diagnostics or --displays.")
    }
  }

  mutating func run() throws {
    let arguments = diagnostics ? ["diagnostics"] : displays ? ["displays"] : []
    try options.send(ControlRequest(command: "query", arguments: arguments))
  }
}
