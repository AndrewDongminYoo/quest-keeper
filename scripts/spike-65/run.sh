#!/bin/bash
# Two-process reproduction spike for issue #65.
#
# Builds `main.swift` together with the repository's own `@Model` sources — copied at run time, so
# the harness cannot drift from the schema — and runs a shortcut-side and a widget-side process over
# one store file, gated by files rather than by timing.
#
# See docs/notes/shortcut-widget-payload-race-spike.md for the arms, the controls, and the measured
# result. Re-run this when one of that note's watch conditions changes.
#
#   scripts/spike-65/run.sh [simulator-udid] [runs-per-arm]
#
# With a UDID the harness is built for the iOS simulator and each process is launched with
# `simctl spawn`; without one it is built and run for the host. Both were measured and agreed.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${HERE}/../.." && pwd)"
UDID="${1:-}"
RUNS="${2:-20}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "${WORK}/src" "${WORK}/store" "${WORK}/gate"

# The seven types QuestModelContainer.makeSchema() declares, taken from the working tree so the
# harness always compiles against the current models. Six files, because RetentionInstallation is
# declared in RetentionEvent.swift — if it is ever split out, add its file here.
for name in Quest RetentionEvent ExperimentAssignment DailyFocusSelection RoutineRule RoutineCompletion; do
	cp "${ROOT}/QuestKeeperShared/${name}.swift" "${WORK}/src/"
done
cp "${HERE}/main.swift" "${WORK}/src/"

if [[ -n ${UDID} ]]; then
	SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
	swiftc -swift-version 6 -O -target arm64-apple-ios26.5-simulator -sdk "${SDK}" \
		-o "${WORK}/harness" "${WORK}/src"/*.swift
	run() { xcrun simctl spawn "${UDID}" "${WORK}/harness" "$@"; }
	# `|| true` because the lookup exits nonzero when the app is not installed on that simulator,
	# and under `pipefail` that would kill the script before the fresh-store fallback below.
	GROUP="$(xcrun simctl get_app_container "${UDID}" kr.donminzzi.QuestKeeper groups 2>/dev/null | awk -F'\t' '/group.kr.donminzzi.QuestKeeper/ {print $2}' || true)"
else
	swiftc -swift-version 6 -O -o "${WORK}/harness" "${WORK}/src"/*.swift
	run() { "${WORK}/harness" "$@"; }
	GROUP=""
fi

STORE="${WORK}/store/default.store"
if [[ -n ${GROUP} ]] && [[ -f "${GROUP}/Library/Application Support/default.store" ]]; then
	# A copy, so the spike never mutates the simulator's own data.
	cp "${GROUP}/Library/Application Support/default.store"* "${WORK}/store/"
	echo "store: copied from ${GROUP}"
else
	echo "store: fresh (no installed app container found)"
fi

run_case() {
	local label="$1" arm="$2" control="$3" qid
	rm -rf "${WORK}/gate" && mkdir -p "${WORK}/gate"
	qid="$(run seed "${STORE}")"
	echo "--- ${label} (arm=${arm} control=${control}) quest=${qid} ---"
	if [[ ${control} == yes ]]; then
		# Positive control: B commits before A opens its container, so A must report the completion.
		: >"${WORK}/gate/a-ready"
		run b "${STORE}" "${WORK}/gate" "${qid}"
		run a "${STORE}" "${WORK}/gate" "${qid}" "${arm}"
	else
		run b "${STORE}" "${WORK}/gate" "${qid}" &
		local bpid=$!
		run a "${STORE}" "${WORK}/gate" "${qid}" "${arm}"
		wait "${bpid}"
	fi
}

{
	run_case CONTROL 1 yes
	for i in $(seq 1 "${RUNS}"); do run_case "ARM1-run${i}" 1 no; done
	for i in $(seq 1 "${RUNS}"); do run_case "ARM2-run${i}" 2 no; done
} | tee "${WORK}/spike.log"

echo "=== tally ==="
for key in OBJECT=STALE OBJECT=FRESH RESULT=STALE RESULT=FRESH; do
	printf '%-14s %s\n' "${key}" "$(grep -c "${key}" "${WORK}/spike.log" || true)"
done
printf '%-14s %s\n' "B commits" "$(grep -c '\[B\] .* commit quest=' "${WORK}/spike.log" || true)"
