/// Build version embedded in the sbar executable.
struct Version {
  /// Current generated version.
  static let current = Self(value: "v0.0.1")

  /// Version string printed by `sbar --version`.
  let value: String
}
