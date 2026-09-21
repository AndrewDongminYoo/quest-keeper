# On-Device Quest Splitting Validation

Tracked as Linear AND-116.
The evidence snapshot is dated 2026-09-21.

## Decision

Use Apple Foundation Models on-device as the provisional cost strategy, with no cost-recovery mechanism.
Reject advertisements, bring-your-own API keys, server inference, and backend infrastructure for this scope.
Preserve the current manual guide as the fallback.

Production implementation remains deferred until a human scores outputs for 20 real quest titles.
Eleven or more usable results pass the quality gate.
Ten or fewer usable results reject or defer the feature.

## Product Contract

The proposed feature must preserve these existing promises:

- no account;
- no advertisements;
- no developer-operated server;
- quest titles and descriptions remain local to the device; and
- generation works offline after the system model is ready.

Availability is conditional rather than universal.
The feature can be offered only when the device is eligible for Apple Intelligence, the system model is ready, the region is supported, and the Korean locale is supported.
When any condition fails, the manual guide remains available and the core quest flow remains unchanged.

## Technical Basis

`SystemLanguageModel` exposes the on-device model, availability status, locale support, and context size.
Apple documents that the model is available only on Apple Intelligence-enabled devices in supported regions, and it recommends checking availability before creating a session.
Apple also documents `supportsLocale(_:)` for checking whether the current or explicit locale is supported.

The spike uses `@Generable` and `@Guide` to request a structured list of three to five Korean subquests.
Apple describes guided generation as constrained structured output and documents that arrays can be generated with count guides.
The spike creates a fresh `LanguageModelSession` for every title so one case does not carry transcript context into the next case.

Apple states that Foundation Models requests run on-device, can work offline, require no account or API key, and have no per-request cost to the developer or user.
That makes the framework the provisional no-cost path for this feature, but it does not establish output quality or universal device coverage.

## Local Probe

The following local probe results were observed on 2026-09-21:

| Probe                                         | Observed result    |
| --------------------------------------------- | ------------------ |
| `SystemLanguageModel.default.availability`    | `available`        |
| `supportsLocale(Locale(identifier: "ko-KR"))` | `true`             |
| `contextSize`                                 | `4096`             |
| Synthetic title                               | `이사 준비하기`    |
| Structured output                             | Three Korean steps |

The synthetic result proved that this local machine could produce one structured response.
It did not prove that the steps were useful, and it cannot replace evaluation with 20 real titles.

A transient local run with 20 synthetic Korean titles was observed during harness development, but its result and validator output were not retained as an inspectable artifact.
Record that structural evidence as `[PARTIAL]` rather than treating it as an acceptance result.
The repository independently verifies the input-count and privacy guards, but not a completed 20-case generation run.

## Evaluation Harness

Run the availability probe without title generation:

```bash
scripts/spike-116/run.sh --check-availability
```

The command returns JSON fields for `modelAvailability`, `supportsKorean`, and `contextSize`.

For the manual quality run, create a private UTF-8 text file outside the repository with exactly 20 non-empty titles, one title per line.
Pass explicit absolute paths for both the input and result files:

```bash
scripts/spike-116/run.sh \
  --input /absolute/private/path/quest-titles.txt \
  --output /absolute/private/path/quest-splitting-results.json
```

Before compilation, the runner resolves both paths to canonical physical locations and rejects the repository root or any descendant, including a symlink that resolves into the repository.
After that privacy boundary passes, the Swift harness validates the exact title count before checking model availability or starting generation.
The result contains opaque identifiers from `case-01` through `case-20` and a structured subquest list for each case.
It does not copy source titles into the result JSON and does not assign a score.
The evaluator keeps the private input file as the local lookup between case identifiers and source titles.

## Human Scoring Protocol

Score each of the 20 cases once against its source title.
Mark a result usable only when all of these conditions hold:

1. It contains three to five non-empty Korean subquests.
2. The subquests preserve the intent of the source quest.
3. The subquests are concrete enough to act on without another model request.
4. The sequence is coherent and does not add an unrelated obligation.
5. The wording remains practical and shame-free.

Record a short rejection reason for every unusable case.
Do not tune the prompt against individual evaluation titles during the same scoring pass.

The gate is binary:

- 11 to 20 usable results: pass the spike and permit a separate production implementation plan.
- 0 to 10 usable results: reject or defer production implementation and retain the manual guide.

Passing this gate does not itself authorize production code, telemetry, monetization, or release work.

## Current Result

The platform and locale probe passed on the observed machine.
The 20-case synthetic structure check remains `[PARTIAL]` because no inspectable result artifact was retained.
The quality gate remains `[UNKNOWN]` because no 20-title real-input evaluation or human scoring was performed.
The production feature remains deferred.

## Sources

- [SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)
- [Supporting languages and locales with Foundation Models](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models)
- [Meet the Foundation Models framework, WWDC25](https://developer.apple.com/videos/play/wwdc2025/286/)
- [Platforms State of the Union, WWDC25](https://developer.apple.com/videos/play/wwdc2025/102/)
