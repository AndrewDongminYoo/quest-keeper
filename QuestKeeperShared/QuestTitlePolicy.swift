import Foundation

nonisolated enum QuestTitlePolicy {
    static let maximumLength = 120
    /// 결합 문자(combining marks) 남용으로 grapheme 1개가 수 MB로 부풀어도 저장되지 않도록 하는
    /// 유니코드 스칼라 상한. `maximumLength` 문자를 정상 표현하기에 충분히 넉넉하되, 폭주는 막는다.
    static let maximumScalars = maximumLength * 4
    /// 정규화 전에 원본을 먼저 자르는 스칼라 상한. 단축어 입력은 편집기의 실시간 `constrainedInput`을
    /// 거치지 않으므로, 수 MB짜리 문자열이 그대로 분할·복사·결합되지 않게 한다.
    /// 정상 입력의 정규화 결과가 바뀌지 않도록 저장 상한보다 넉넉하게 잡는다.
    static let maximumRawScalars = maximumScalars * 8

    /// 원본 입력을 `maximumRawScalars`까지만 읽는다. 상한까지만 스칼라를 세므로
    /// 길이 확인 자체가 입력 전체를 훑지 않는다.
    static func boundedRawInput(_ title: String) -> String {
        let scalars = title.unicodeScalars
        guard let cutoff = scalars.index(
            scalars.startIndex, offsetBy: maximumRawScalars, limitedBy: scalars.endIndex
        ), cutoff != scalars.endIndex else { return title }
        return String(String.UnicodeScalarView(scalars[..<cutoff]))
    }

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
        let collapsed = boundedRawInput(title)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return constrainedInput(collapsed)
    }
}
