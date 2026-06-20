/// Pure, UI-agnostic model of the open-tabs "working set" (Sublime-style).
/// Order is open order; ids are note ids. No SwiftUI here.
public struct TabSet {
    public private(set) var ids: [String]

    public init(ids: [String] = []) {
        self.ids = ids
    }

    public func contains(_ id: String) -> Bool {
        ids.contains(id)
    }

    public mutating func open(_ id: String) {
        guard !ids.contains(id) else { return }
        ids.append(id)
    }

    /// Removes `id`. If `id` was the active tab, returns the id to activate next
    /// (the last remaining tab, or nil if none). Otherwise returns `active`
    /// unchanged.
    public mutating func close(_ id: String, active: String?) -> String? {
        ids.removeAll { $0 == id }
        if active == id {
            return ids.last
        }
        return active
    }

    public mutating func clear() {
        ids.removeAll()
    }
}
