import Foundation

extension ProviderRuntime {
  func tooltip(for item: Item, displayUUID: String? = nil) -> String? {
    guard let source = item.tooltip else { return item.label ?? item.id }
    guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    // Configuration validation reports syntax errors before a view receives the item.
    guard let template = try? TooltipTemplate(source, type: item.type) else { return nil }
    let presentation = presentation(for: item, displayUUID: displayUUID)
    var values = presentation?.tooltipValues ?? [:]
    let text: String
    if let presentation {
      text =
        presentation.segments.isEmpty
        ? presentation.text
        : presentation.segments.map(\.text).filter { !$0.isEmpty }.joined(separator: " ")
    } else {
      switch item.type {
      case .datetime:
        text = DateTimeFormatter.string(
          itemDates[item.id] ?? currentDate,
          format: item.format,
          dateStyle: item.dateStyle,
          timeStyle: item.timeStyle
        )
      case .frontApplication:
        let name = itemSnapshots[item.id] ?? sharedValues[.frontApplication] ?? ""
        values["name"] = name
        text = item.label ?? name
      case .text: text = item.label ?? ""
      case .group, .popup: text = item.label ?? item.id
      case .divider, .spacer: text = ""
      default: text = itemSnapshots[item.id] ?? sharedValues[item.type] ?? ""
      }
    }
    values["id"] = item.id
    values["label"] = item.label ?? item.id
    values["text"] = text
    values["summary"] = presentation?.accessibilityLabel ?? text
    return template.render(values: values)
  }
}
