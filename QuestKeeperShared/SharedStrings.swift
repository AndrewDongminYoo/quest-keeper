import Foundation

/// 앱과 위젯이 함께 쓰는 문자열 리소스. 두 번들의 카탈로그에 같은 키가 선언되어 있다.
nonisolated enum SharedStrings {
    static func monsterName(_ kind: MonsterKind) -> LocalizedStringResource {
        switch kind {
        case .slime: LocalizedStringResource("monster.slime", defaultValue: "슬라임")
        case .bat: LocalizedStringResource("monster.bat", defaultValue: "박쥐")
        case .mushroom: LocalizedStringResource("monster.mushroom", defaultValue: "버섯")
        case .skeleton: LocalizedStringResource("monster.skeleton", defaultValue: "스켈레톤")
        case .orc: LocalizedStringResource("monster.orc", defaultValue: "오크")
        case .mimic: LocalizedStringResource("monster.mimic", defaultValue: "미믹")
        case .dragon: LocalizedStringResource("monster.dragon", defaultValue: "드래곤")
        case .golem: LocalizedStringResource("monster.golem", defaultValue: "골렘")
        case .lich: LocalizedStringResource("monster.lich", defaultValue: "리치")
        }
    }
}
