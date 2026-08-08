import XCTest

/// UI 테스트가 시뮬레이터의 언어 설정과 무관하게 항상 한국어로 실행되도록 로케일을 고정한다.
/// 로컬라이제이션 이후 테스트가 검증하는 문자열은 `Locale.current`를 통해 해석되므로,
/// 이 인자가 없으면 영어 시뮬레이터에서 조용히 실패한다.
let uiTestKoreanLocaleArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
