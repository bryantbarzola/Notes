import Foundation

public struct Note: Identifiable, Equatable {
    public let filename: String
    public var content: String

    public init(filename: String, content: String) {
        self.filename = filename
        self.content = content
    }

    public var id: String { filename }

    public var title: String {
        for rawLine in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if !line.isEmpty { return line }
        }
        return "New Note"
    }
}

private let filenameFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone.current
    f.dateFormat = "yyyy-MM-dd-HHmm"
    return f
}()

public func timestampFilename(for date: Date, existing: Set<String>) -> String {
    let base = filenameFormatter.string(from: date)
    var candidate = "\(base).md"
    var n = 2
    while existing.contains(candidate) {
        candidate = "\(base)-\(n).md"
        n += 1
    }
    return candidate
}
