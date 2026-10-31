import Foundation

nonisolated enum QuestDetailsPolicy {
    static let maximumLength = 1_000
    static let maximumScalars = maximumLength * 4
    /// `QuestTitlePolicy.maximumRawScalars`와 같은 이유로 정규화 전에 원본을 먼저 자른다.
    static let maximumRawScalars = maximumScalars * 8

    static func boundedRawInput(_ details: String) -> String {
        let scalars = details.unicodeScalars
        guard let cutoff = scalars.index(
            scalars.startIndex, offsetBy: maximumRawScalars, limitedBy: scalars.endIndex
        ), cutoff != scalars.endIndex else { return details }
        return String(String.UnicodeScalarView(scalars[..<cutoff]))
    }

    static func constrainedInput(_ details: String) -> String {
        let byCharacter = String(details.prefix(maximumLength))
        guard byCharacter.unicodeScalars.count > maximumScalars else { return byCharacter }
        return String(String.UnicodeScalarView(byCharacter.unicodeScalars.prefix(maximumScalars)))
    }

    static func normalized(_ details: String?) -> String? {
        guard let details else { return nil }
        let lineNormalized = boundedRawInput(details)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let trimmed = lineNormalized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var collapsedLines: [String] = []
        var previousLineWasBlank = false
        for line in trimmed.split(separator: "\n", omittingEmptySubsequences: false) {
            let lineIsBlank = line.allSatisfy { $0.isWhitespace }
            if lineIsBlank {
                if !previousLineWasBlank { collapsedLines.append("") }
            } else {
                collapsedLines.append(String(line))
            }
            previousLineWasBlank = lineIsBlank
        }
        let collapsed = collapsedLines.joined(separator: "\n")
        let bounded = constrainedInput(collapsed)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return bounded.isEmpty ? nil : bounded
    }
}
