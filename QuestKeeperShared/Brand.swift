import Foundation

/// 화면에 그려지는 제품명. 앱 헤더와 위젯 헤더가 같은 값을 쓴다.
///
/// 카탈로그 키가 아니라 상수인 이유: 제품명은 현지화 대상이 아니라서 로캘별 값이 갈리지 않는다.
/// 카탈로그에 넣으면 동기화 지점이 Swift `defaultValue:` + `ko` + `en` 세 곳으로 늘어나기만 한다.
/// 예외는 `WidgetStrings.configurationDisplayName` 하나인데, WidgetKit의 configuration이
/// `LocalizedStringResource`를 요구해서 형태를 고를 수 없다.
///
/// 이름을 바꿀 때 놓치기 쉬운 자리들은 `docs/notes/app-name-rename-scope.md`가 정리한다.
nonisolated enum Brand {
    /// 던전 헤더에 쓰는 표시명.
    static let displayName = "QUEST KEEPER"

    /// `systemSmall` 위젯처럼 폭이 좁은 자리에 쓰는 축약형.
    /// 표시명을 자른 문자열이 아니라 따로 고르는 값이다.
    static let shortName = "QUEST"
}
