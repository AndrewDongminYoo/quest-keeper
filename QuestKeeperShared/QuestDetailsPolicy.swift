import Foundation

nonisolated enum QuestDetailsPolicy {
    static let maximumLength = 1_000
    static let maximumScalars = maximumLength * 4

    static func constrainedInput(_ details: String) -> String {
        let byCharacter = String(details.prefix(maximumLength))
        guard byCharacter.unicodeScalars.count > maximumScalars else { return byCharacter }
        return String(String.UnicodeScalarView(byCharacter.unicodeScalars.prefix(maximumScalars)))
    }

    static func normalized(_ details: String?) -> String? {
        guard let details else { return nil }
        let lineNormalized = details
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let trimmed = lineNormalized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var collapsed = ""
        var newlineRun = 0
        for character in trimmed {
            if character == "\n" {
                newlineRun += 1
                if newlineRun <= 2 { collapsed.append(character) }
            } else {
                newlineRun = 0
                collapsed.append(character)
            }
        }
        let bounded = constrainedInput(collapsed)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return bounded.isEmpty ? nil : bounded
    }
}
