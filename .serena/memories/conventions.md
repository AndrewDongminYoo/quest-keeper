# Conventions

## Test frameworks (per target — do not mix)

- `QuestKeeperTests` unit tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`) — NOT XCTest.
- `QuestKeeperUITests` use XCTest.
- Match the framework of the target you write in.

## Persistence guardrail

`@Model` types (`Quest`) hold raw facts only. See `mem:core` for the full forbidden-field list. Adding a derived field to a `@Model` is a design violation, not a convenience. A rg guard enforces this (see `mem:task_completion`).

## Derivation purity

New game rules go in the pure derivation layer (`mem:derivation`) as deterministic functions taking facts + `now`, never as stored state or event side effects. Notifications and widgets are side effects around stored facts, not sources of truth.

## Language

Korean comments and user-facing strings are intentional — do NOT translate them. Code identifiers and commit messages are English. Voice is quest-flavored but shame-free: use `전투 추가`/`내일 도전하기`/`완료`; avoid `실패했습니다`/`무덤이 누적되었습니다`/`HP가 감소했습니다` (see `DESIGN.md` Voice).

## Docs

Soft-wrapped prose, one sentence per line. Every fenced code block gets a language id. `docs/specs/` = behavior contracts, `docs/plans/` = implementation plans, `docs/notes/` = evidence logs/retros.

## Commits

Conventional commits, English, grouped by concern. No Co-Author lines.

## Naming / structure

Feature code grouped by role under `QuestKeeper/` (`Models`/`Derivation`/`Actions`/`Views`/`Notifications`/`WidgetSupport`). Derivation namespaces are caseless `enum`s (e.g. `HeroDerivation`, `GameBalance`, `QuestActions`, `QuestNotificationPlanner`) used as static-function namespaces; state values are `struct`s (`HeroState`, `QuestSnapshot`, `WidgetDungeonPayload`).
