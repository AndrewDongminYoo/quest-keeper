# BLUEPRINT — QuestKeeper (가칭)

> 마감을 지키지 못하면 픽셀 용사가 죽은 눈으로 다음날을 맞는, 오프라인 우선 게이미피케이션 투두 앱.
> **1차 목표는 앱 출시가 아니라 iOS 네이티브 기본기의 핵심 관통 라인을 브릿지 없이 통과하는 것.**

---

## Goal

- 플러터/RN 브릿지로 "회피"해오던 OS 경계 — 백그라운드 시간 판정, 로컬 알림 라이프사이클, 위젯, 1st-party 데이터 스택, 앱 생명주기 — 를 순수 네이티브로 직접 통과한다.
- 게이미피케이션(중요도 × 긴급도 = 몹 레벨, 마감 실패 시 용사 사망)을 **학습 커리큘럼을 끌고 오는 장치**로 사용한다. 화려함이 목적이 아니다.
- 완주 기준은 "혼자 힘으로 OS 경계를 넘어봤다"는 검증 가능한 자신감.

## Success Criteria

- 앱을 6개월간 안 열었다가 다시 열어도 용사 상태가 **결정론적으로 올바르게 재구성**된다 (실시간 이벤트 의존 0).
- DB에 `HP`/`isDead` 같은 파생 상태가 저장되어 있지 않다. 저장되는 것은 원시 사실(`deadline`, `completedAt`, `importance`)뿐이다.
- 마감 알림이 스케줄→취소→재등록 라이프사이클을 정확히 따른다 (완료 시 pending 알림 제거됨).
- 홈 화면 위젯이 앱을 열지 않고도 용사 상태(건강/사망)를 반영한다.
- 전 과정 Swift 6 strict concurrency 켜짐 (`Sendable`, actor, `async/await`) 상태로 컴파일된다.

## Constraints / Non-goals

- **1차 스코프 제외**: CloudKit 동기화, ARKit, SpriteKit 파티클, 멀티 디바이스, 계정/로그인, 백엔드.
- 로컬 온리, 단일 디바이스, 오프라인 우선.
- 픽셀 아트 폴리싱은 최소한(스프라이트 시트 프레임 교체 수준)으로만. 애니메이션 완성도는 후순위.
- 서드파티 의존성 최소화. 애플 1st-party 스택으로 직접 짜는 것이 학습 목적의 핵심.

## Tech Stack (fixed)

- Swift 6 / SwiftUI / SwiftData (`@Model`, `@Query`)
- UserNotifications (`UNCalendarNotificationTrigger`)
- WidgetKit + App Group (앱↔위젯 데이터 공유)
- `TimelineView` 기반 스프라이트 애니메이션 (SpriteKit은 후속 단계 옵션)

---

## Core Design Principle — "저장은 사실만, 상태는 파생"

이 원칙이 전체 아키텍처의 뼈대이며, 어떤 게이미피케이션 규칙을 추가해도 깨지지 않아야 한다.

- **저장(persist)**: `task.deadline`, `task.completedAt`, `task.importance` — 시간이 지나도 변하지 않는 원시 사실.
- **파생(derive)**: 용사 HP, 사망 여부, 몹 레벨, 긴급도 — 모두 **조회 시점의 현재 시각 대비 계산**.
- 마감 판정은 이벤트 기반이 아니라 **상태 재구성(state replay)**: 앱이 다시 열리는 순간 `lastOpened`와 각 태스크 `deadline`을 비교해 그 사이에 죽었어야 할 용사를 소급 계산한다.
- **긴급도 = 마감까지 남은 시간의 함수** (저장값 아님). 시간이 흐르면 같은 태스크의 긴급도가 자동 상승 → Eisenhower 매트릭스를 실시간으로 움직이는 축으로 전환.
- **몹 레벨 = 중요도(저장) × 긴급도(파생)**.

---

## Phase 1 — 데이터 모델 & 파생 계층 (뼈대)

목표: 저장/파생 경계를 코드로 못박는다. UI 없이 로직만.

- [ ] SwiftData `@Model Task` 정의 — 저장 필드는 원시 사실만 (`id`, `title`, `deadline`, `completedAt?`, `importance`)
- [ ] `TaskDerivation` computed layer 작성 — `urgency(at:)`, `mobLevel(at:)`, 파생값은 절대 저장 안 함
- [ ] `HeroState` 파생 로직 — `heroState(tasks:now:lastOpened:)` 순수 함수, 입력 동일하면 출력 동일 (결정론)
- [ ] 단위 테스트: "6개월 후 재오픈" 시나리오로 상태 재구성 검증
- [ ] 단위 테스트: 같은 태스크가 시간 경과에 따라 긴급도/몹레벨 상승하는지 검증
- [ ] Swift 6 strict concurrency 켜고 경고 0으로 컴파일

## Phase 2 — 태스크 CRUD & 용사 뷰 (앱 생명주기)

목표: SwiftUI 생명주기와 `@Query`를 파생 계층에 연결.

- [ ] SwiftData `ModelContainer` 구성, `@Query`로 태스크 목록 바인딩
- [ ] 태스크 생성/편집/완료 UI (완료 = `completedAt` 기록, 삭제와 구분)
- [ ] 용사 뷰 — `@Query` 결과 + 현재 시각을 파생 계층에 흘려 상태 렌더링
- [ ] `scenePhase` 감지 → `.active` 전환 시 `lastOpened` 갱신 및 상태 재구성 트리거
- [ ] `TimelineView`로 긴급도/카운트다운이 실시간 갱신되게 (타이머 수동 관리 회피)
- [ ] 픽셀 용사 스프라이트: 건강/사망 2상태 최소 구현 (프레임 교체)

## Phase 3 — 로컬 알림 라이프사이클 (UserNotifications)

목표: 스케줄→취소→재등록 사이클을 정확히.

- [ ] 알림 권한 요청 플로우 (`UNUserNotificationCenter`, 거부 상태 처리 포함)
- [ ] 태스크 생성/수정 시 `UNCalendarNotificationTrigger`로 마감 임박·초과 알림 스케줄
- [ ] 완료 시 해당 태스크의 pending 알림 취소 (`removePendingNotificationRequests`)
- [ ] 마감 변경 시 기존 알림 제거 후 재등록 (중복 알림 방지)
- [ ] 엣지 케이스: 과거 마감으로 생성된 태스크는 알림 스케줄 스킵
- [ ] 알림 탭 → 해당 태스크로 딥링크 (`UNNotificationResponse` 처리)

## Phase 4 — 홈 화면 위젯 (WidgetKit + App Group)

목표: 앱을 열지 않고도 용사 상태를 반영.

- [ ] App Group 설정, SwiftData 스토어를 앱↔위젯 공유 컨테이너로 이동
- [ ] Widget Extension 생성, `TimelineProvider`로 용사 상태 스냅샷 제공
- [ ] 타임라인 엔트리를 마감 시각 기준으로 생성 (긴급도 변화가 위젯에 반영되게)
- [ ] 태스크 완료/생성 시 `WidgetCenter.reloadTimelines`로 위젯 갱신 트리거
- [ ] 위젯에서도 상태는 파생 — 저장된 사실로부터 위젯이 독립적으로 계산하는지 확인

## Phase 5 — 통합 검증 & 회고

목표: 관통 라인 완성 확인, 학습 정리.

- [ ] Success Criteria 전 항목 수동 검증 (특히 장기 미오픈 재구성)
- [ ] 실기기에서 백그라운드 장시간 방치 후 재오픈 시나리오 테스트
- [ ] "저장은 사실만" 원칙이 지켜졌는지 모델 감사 (파생 상태 저장 필드 0 확인)
- [ ] 짧은 회고 메모: 브릿지로 회피했던 지점 중 이번에 직접 넘은 것 정리

---

## Backlog (2차 이후, 스코프 밖)

- CloudKit 동기화 (충돌 처리, 다중 디바이스)
- Live Activities / Dynamic Island 마감 카운트다운 (ActivityKit)
- SpriteKit 전환: 타격 이펙트, 파티클, 몹 처치 애니메이션
- 몹 도감 / 콤보 / 스트릭 등 게임 다이내믹 확장
- ARKit Measure 클론을 별도 학습 프로젝트로

## Open Questions

- 용사 "죽은 눈" 상태의 회복 조건 — 다음 태스크 완료 시 부활? 하루 유예? (게임 밸런스, Phase 1 전에 확정 권장)
- 몹 레벨 공식의 정규화 범위 — `importance × urgency`를 몇 단계 몹으로 매핑할지
- 하루에 여러 태스크 실패 시 용사 데미지 누적 방식 (선형 vs 즉사)
