import Foundation
import Testing

@testable import SbarCore

@Suite("RegionStyle")
struct RegionStyleTests {
  @Test("section fields inherit independently and explicit zero and transparency override")
  func inheritance() throws {
    let theme = try JSONDecoder().decode(
      Theme.self,
      from: Data(
        ##"{"regionStyle":{"background":"#112233","cornerRadius":8,"horizontalPadding":10,"itemSpacing":6},"regions":{"right":{"background":"#00000000","cornerRadius":0,"horizontalPadding":null}}}"##
          .utf8
      )
    )
    try theme.validate()
    let right = try #require(theme.regions?.right).resolved(over: theme.regionStyle)

    #expect(right.background == "#00000000")
    #expect(right.cornerRadius == 0)
    #expect(right.horizontalPadding == 10)
    #expect(right.itemSpacing == 6)
    #expect(try JSONDecoder().decode(Theme.self, from: JSONEncoder().encode(theme)) == theme)

    let old = try JSONDecoder().decode(Theme.self, from: Data("{}".utf8))

    #expect(old.regionStyle == nil)
    #expect(old.regions == nil)
  }

  @Test("schema and runtime agree on region style bounds")
  func validation() throws {
    let schema = try #require(
      JSONSerialization.jsonObject(with: ConfigurationSchema.data()) as? [String: Any]
    )
    let definitions = try #require(schema["$defs"] as? [String: Any])
    let style = try #require(definitions["regionStyle"] as? [String: Any])
    let properties = try #require(style["properties"] as? [String: Any])

    for key in [
      "cornerRadius", "horizontalPadding", "verticalPadding", "borderWidth", "itemSpacing",
    ] {
      let field = try #require(properties[key] as? [String: Any])
      let upper = try #require(field["maximum"] as? Double)

      for value in [0, upper, -1, upper + 1] {
        let decoded = try JSONDecoder().decode(
          RegionStyle.self,
          from: JSONSerialization.data(withJSONObject: [key: value])
        )

        if (0...upper).contains(value) {
          try decoded.validate(path: "theme.regions.right")
        } else {
          #expect(
            throws: ConfigurationError.invalidValue(
              path: "theme.regions.right.\(key)",
              reason: "Must be between 0.0 and \(upper)."
            )
          ) {
            try decoded.validate(path: "theme.regions.right")
          }
        }
      }
    }
    for key in ["background", "borderColor"] {
      let decoded = try JSONDecoder().decode(
        Theme.self,
        from: JSONSerialization.data(withJSONObject: ["regions": ["left": [key: "red"]]])
      )

      #expect(
        throws: ConfigurationError.invalidValue(
          path: "theme.regions.left.\(key)",
          reason: "Use #RRGGBB or #RRGGBBAA."
        )
      ) { try decoded.validate() }
    }
  }
}
