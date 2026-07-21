# Local product analytics v1 (AND-33)

Quest Keeper records anonymous product facts to `analytics-v1.jsonl` in the App Group. It does not
send data to a server or third-party SDK. The in-app share action is the only export path.

## Funnel and metrics

The funnel is first `app_activated` → `first_value_experienced` → first `quest_completed` → D1/D7
return → another completion. First value means that a newly created quest is present as a pending
row on the dungeon board, not merely that an onboarding screen or save tap occurred.

- D1/D7 retention: an `app_activated` on local calendar day +1/+7 after the installation's first
  activation. Include only installations whose observation window has closed.
- WAU: an installation with `quest_created`, `quest_completed`, `quest_retried`,
  `daily_focus_selected`, or `weekly_plan_set` during the latest seven local calendar days.
  `app_activated` alone counts only as a weekly visitor.
- Weekly repeat completer: an installation with at least two `quest_completed` events in that window.
- Time to first value is clamped to 0...86,400 seconds; the two-minute rate uses values <= 120.

## Event dictionary

All events carry `event_id`, `event_name`, ISO-8601 UTC `occurred_at`, captured `local_day`, anonymous
`installation_id`, `session_id`, app/build versions, `platform`, `schema_version`, and `is_test`.

| Event | Properties |
| --- | --- |
| `app_activated` | `activation_type`, `entry_source` |
| `quest_created` | `quest_key`, `importance`, `deadline_bucket`, `creation_source` |
| `first_value_experienced` | `quest_key`, `elapsed_seconds`, `experience_version` |
| `quest_completed` | `quest_key`, `completion_source`, `deadline_state`, `is_first_completion` |
| `quest_retried` | `quest_key`, `days_since_deadline` |
| `notification_opened` | `quest_key`, `notification_kind`, `destination` |

Reserved names, which must not be emitted until their features exist: `onboarding_started`,
`onboarding_exited`, `daily_focus_selected`, `recovery_option_selected`, `weekly_summary_viewed`,
`weekly_plan_set`, `notification_permission_responded`, `notification_preference_changed`,
`metagame_prototype_viewed`, and `metagame_feedback_submitted`.

## Privacy contract

`quest_key` is SHA-256 of an installation-specific random salt and the quest UUID. Never record quest
titles or fragments, notification bodies, arbitrary user input, exact deadlines, original quest UUIDs,
notification identifiers, contact details, advertising IDs, device names, IP/location, or raw localized
error descriptions. Debug logging may contain the event name and non-sensitive property keys only.

## Baseline report

Combine participant exports, deduplicate by `event_id`, exclude `is_test` and unsupported schemas, then
sort by `installation_id` and `local_day`. Report cohort week, new installations, first-value rate,
two-minute first-value rate, first-completion rate, D1, D7, and repeat-completion rate. Keep breakdowns
to app version, experience/experiment variant, and first completion source. Record input hashes, report
time, and calculation version. Treat fewer than 30 installations as directional; freeze the first
baseline only after at least 14 days.
