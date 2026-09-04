import Foundation

struct RefreshPolicy: Codable, Equatable, Sendable {
    enum Mode: String, Codable, CaseIterable, Sendable { case event, interval, manual }
    var mode: Mode
    var seconds: Double?
    var event: String?
}
