struct WorkspaceText {
  struct Entry {
    var name: String
    var index: Int?
    var identifier: String
    var active: Bool
    var focused: Bool
    var visible: Bool
    var fullscreen: Bool = false
    var tint: String?
    var emphasized = false
    var nameSymbol: ItemSymbol?

    var values: [String: String] {
      [
        "value": name, "name": name, "index": index.map(String.init) ?? "",
        "workspaceId": identifier, "active": String(active), "focused": String(focused),
        "visible": String(visible), "fullscreen": String(fullscreen),
      ]
    }
  }

  var current: Entry?
  var entries: [Entry] = []

  func apply(to presentation: WidgetPresentation, for item: Item) -> WidgetPresentation {
    guard let source = item.text ?? (current?.nameSymbol != nil ? "{{value}}" : nil),
      let template = try? TextTemplate(
        source,
        fields: TextTemplate.fields(for: item.type),
        allowedValues: TextTemplate.allowedValues(for: item.type)
      )
    else { return presentation }

    var values = current?.values ?? [:]
    values["value"] = presentation.text
    values["id"] = item.id
    values["total"] = String(entries.count)
    values["available"] = String(current != nil)
    let runs = template.renderRuns(
      values,
      entries: entries.map(\.values),
      preserveField: { name, index in
        (name == "name" || name == "value")
          && (index.map { entries[$0] } ?? current)?.nameSymbol != nil
      }
    )
    var result = presentation
    result.text = runs.map(\.text).joined()

    if template.containsSymbol && !runs.contains(where: \.symbol) { result.symbol = nil }
    if runs.contains(where: { $0.entry != nil || $0.field != nil }) {
      if runs.contains(where: { $0.entry != nil }) { result.tint = nil }

      let inactiveTint: String?

      switch item.type {
      case .spaces: inactiveTint = item.spaces?.tints?.inactive
      case .aerospace: inactiveTint = item.aerospace?.tints?.inactive
      case .yabai: inactiveTint = item.yabai?.tints?.inactive
      default: inactiveTint = nil
      }

      result.segmentSpacing = 0
      result.segments = runs.map { run in
        let entry = run.entry.map { entries[$0] }
        let nameSymbol = run.field == nil ? nil : (entry ?? current)?.nameSymbol

        return WidgetSegment(
          text: nameSymbol == nil ? run.text : "",
          symbol: nameSymbol,
          tint: run.separator ? inactiveTint : run.entry == nil ? presentation.tint : entry?.tint,
          emphasized: !run.separator && (entry?.emphasized ?? false)
        )
      }
    } else {
      result.segments = []
    }

    return result
  }
}
