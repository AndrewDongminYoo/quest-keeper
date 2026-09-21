import Darwin
import Foundation

private enum SyntheticFailure: Error {
    case rejected
}

@main
private enum Spike116GenerationFailureTest {
    static func main() async {
        let records = await generateResultRecords(titles: ["first", "second", "third"]) { title in
            if title == "second" {
                throw SyntheticFailure.rejected
            }
            return ["\(title) step"]
        }

        guard records.count == 3,
              records[0].caseID == "case-01",
              records[0].status == .generated,
              records[1].caseID == "case-02",
              records[1].status == .generationFailed,
              records[1].subquests.isEmpty,
              records[2].caseID == "case-03",
              records[2].status == .generated,
              records[2].subquests == ["third step"] else {
            FileHandle.standardError.write(Data("generation failure was not preserved\n".utf8))
            exit(EXIT_FAILURE)
        }

        print("generation failure preserved and later cases continued")
    }
}
