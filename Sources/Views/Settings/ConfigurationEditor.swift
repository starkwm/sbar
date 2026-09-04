import Foundation
import Observation

@MainActor @Observable
final class ConfigurationEditor {
    enum Section: String, CaseIterable, Identifiable { case left, center, right; var id: String { rawValue } }

    var draft = BarConfiguration.default
    var baseline = BarConfiguration.default
    var selection: String?
    var message: String?
    var dirty: Bool { draft != baseline }
    var validationError: String? {
        do { try draft.validate(); return nil } catch { return error.localizedDescription }
    }

    func load(_ configuration: BarConfiguration) {
        draft = configuration
        baseline = configuration
        message = nil
    }

    func items(in section: Section) -> [ItemConfiguration] {
        switch section { case .left: draft.items.left; case .center: draft.items.center; case .right: draft.items.right }
    }

    func replace(_ items: [ItemConfiguration], in section: Section) {
        switch section { case .left: draft.items.left = items; case .center: draft.items.center = items; case .right: draft.items.right = items }
    }

    func add(to section: Section) {
        let item = ItemConfiguration(id: UUID().uuidString, type: .text, label: "New item")
        replace(items(in: section) + [item], in: section)
        selection = item.id
    }

    func remove(_ id: String) {
        for section in Section.allCases { replace(items(in: section).filter { $0.id != id }, in: section) }
        if selection == id { selection = nil }
    }

    func move(_ id: String, to section: Section, before target: String? = nil) {
        guard id != target, let item = (draft.items.left + draft.items.center + draft.items.right).first(where: { $0.id == id }) else { return }
        remove(id)
        var destination = items(in: section)
        let index = target.flatMap { target in destination.firstIndex { $0.id == target } } ?? destination.endIndex
        destination.insert(item, at: index)
        replace(destination, in: section)
        selection = id
    }
}
