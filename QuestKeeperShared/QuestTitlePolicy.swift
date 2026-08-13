import Foundation

nonisolated enum QuestTitlePolicy {
    static let maximumLength = 120
    /// 결합 문자(combining marks) 남용으로 grapheme 1개가 수 MB로 부풀어도 저장되지 않도록 하는
    /// 유니코드 스칼라 상한. `maximumLength` 문자를 정상 표현하기에 충분히 넉넉하되, 폭주는 막는다.
    static let maximumScalars = maximumLength * 4

    /// 실시간 입력용 상한. 문자 수와 스칼라 수를 모두 제한한다.
    /// `String.prefix`는 grapheme(Character) 단위라 결합 문자로 부풀린 클러스터를 걸러내지 못하므로
    /// 스칼라 수도 함께 조인다.
    static func constrainedInput(_ title: String) -> String {
        let byCharacter = String(title.prefix(maximumLength))
        guard byCharacter.unicodeScalars.count > maximumScalars else { return byCharacter }
        return String(String.UnicodeScalarView(byCharacter.unicodeScalars.prefix(maximumScalars)))
    }

    /// 저장 시점 정규화. 가장자리 trim만으로는 가운데 개행이 남아 카드·행이 수십 줄로 늘어나므로
    /// 공백·개행 런을 단일 공백으로 접은 뒤 길이를 제한한다.
    static func normalized(_ title: String) -> String {
        let collapsed = title
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return constrainedInput(collapsed)
    }
}
