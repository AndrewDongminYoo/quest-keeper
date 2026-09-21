import Darwin
import Foundation
import FoundationModels

@Generable(description: "A quest split into a short ordered list of concrete Korean actions")
struct QuestSplit {
    @Guide(description: "Three to five concrete Korean action steps in execution order", .count(3...5))
    var subquests: [String]
}

private struct AvailabilityReport: Encodable {
    let modelAvailability: String
    let supportsKorean: Bool
    let contextSize: Int
}

private struct ResultRecord: Encodable {
    let caseID: String
    let subquests: [String]
}

private struct EvaluationOutput: Encodable {
    let results: [ResultRecord]
}

private enum CLIError: LocalizedError {
    case usage
    case pathsMustBeAbsolute
    case invalidTitleCount(Int)
    case unavailableModel(String)
    case unsupportedKoreanLocale

    var errorDescription: String? {
        switch self {
        case .usage:
            return "usage: run.sh --check-availability | --input <absolute-path> --output <absolute-path>"
        case .pathsMustBeAbsolute:
            return "input and output paths must be absolute"
        case .invalidTitleCount(let count):
            return "expected exactly 20 non-empty titles, got \(count)"
        case .unavailableModel(let reason):
            return "system language model is unavailable: \(reason)"
        case .unsupportedKoreanLocale:
            return "system language model does not support ko-KR"
        }
    }
}

@main
private enum Spike116 {
    static func main() async {
        do {
            try await run()
        } catch {
            let message = error.localizedDescription + "\n"
            FileHandle.standardError.write(Data(message.utf8))
            exit(EXIT_FAILURE)
        }
    }

    private static func run() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments == ["--check-availability"] {
            try printJSON(availabilityReport())
            return
        }

        guard arguments.count == 4,
              arguments[0] == "--input",
              arguments[2] == "--output" else {
            throw CLIError.usage
        }

        let inputPath = arguments[1]
        let outputPath = arguments[3]
        guard inputPath.hasPrefix("/"), outputPath.hasPrefix("/") else {
            throw CLIError.pathsMustBeAbsolute
        }

        let titles = try readTitles(at: inputPath)
        guard titles.count == 20 else {
            throw CLIError.invalidTitleCount(titles.count)
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw CLIError.unavailableModel(availabilityDescription(model.availability))
        }
        guard model.supportsLocale(Locale(identifier: "ko-KR")) else {
            throw CLIError.unsupportedKoreanLocale
        }

        var records: [ResultRecord] = []
        records.reserveCapacity(titles.count)
        for (index, title) in titles.enumerated() {
            let session = LanguageModelSession(
                model: model,
                instructions: "The person's locale is ko-KR. You MUST respond in Korean. Split the quest into concrete actions without adding commentary."
            )
            let response = try await session.respond(
                to: "Split this quest into practical steps: \(title)",
                generating: QuestSplit.self
            )
            records.append(
                ResultRecord(
                    caseID: String(format: "case-%02d", index + 1),
                    subquests: response.content.subquests
                )
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(EvaluationOutput(results: records))
        try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
    }

    private static func readTitles(at path: String) throws -> [String] {
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        return contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func availabilityReport() -> AvailabilityReport {
        let model = SystemLanguageModel.default
        return AvailabilityReport(
            modelAvailability: availabilityDescription(model.availability),
            supportsKorean: model.supportsLocale(Locale(identifier: "ko-KR")),
            contextSize: model.contextSize
        )
    }

    private static func availabilityDescription(
        _ availability: SystemLanguageModel.Availability
    ) -> String {
        switch availability {
        case .available:
            return "available"
        case .unavailable(.deviceNotEligible):
            return "unavailable:device-not-eligible"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "unavailable:apple-intelligence-not-enabled"
        case .unavailable(.modelNotReady):
            return "unavailable:model-not-ready"
        @unknown default:
            return "unavailable:unknown"
        }
    }

    private static func printJSON<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}
