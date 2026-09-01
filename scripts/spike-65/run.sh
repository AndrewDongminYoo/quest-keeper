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

# The schema is read out of QuestModelContainer.makeSchema() rather than restated here, so adding a
# model to production cannot leave the harness silently measuring an older store shape. Each type's
# declaring file is then located by its declaration, which also survives a file being split or
# renamed. An unlocatable type is a hard failure: a partial schema would migrate the copied store.
TYPES="$(sed -n '/Schema(\[/,/\])/p' "${ROOT}/QuestKeeperShared/QuestModelContainer.swift" |
	grep -oE '[A-Za-z_][A-Za-z0-9_]*\.self' | sed 's/\.self$//' || true)"
[[ -n ${TYPES} ]] || {
	echo "could not read the schema from QuestModelContainer.swift" >&2
	exit 1
}
for name in ${TYPES}; do
	source_file="$(grep -lE "(final )?class ${name}\b" "${ROOT}/QuestKeeperShared"/*.swift | head -1 || true)"
	[[ -n ${source_file} ]] || {
		echo "could not locate the declaration of ${name}" >&2
		exit 1
	}
	cp "${source_file}" "${WORK}/src/"
done
cp "${HERE}/main.swift" "${WORK}/src/"
{
	echo "import SwiftData"
	echo "func modelSchema() -> Schema {"
	echo "    Schema(["
	for name in ${TYPES}; do echo "        ${name}.self,"; done
	echo "    ])"
	echo "}"
} >"${WORK}/src/schema.swift"

if [[ -n ${UDID} ]]; then
	SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
	# Architecture and deployment target come from the host and the installed SDK; hard-coding
	# arm64 would build something an Intel host's simulator cannot launch.
	ARCH="$(uname -m)"
	SDK_VERSION="$(xcrun --sdk iphonesimulator --show-sdk-version)"
	TARGET="${ARCH}-apple-ios${SDK_VERSION}-simulator"
	swiftc -swift-version 6 -O -target "${TARGET}" -sdk "${SDK}" \
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

# The run is a watch condition, so it has to fail when the measurement changes rather than print a
# different number and exit 0. Each expectation below is one of the claims in the note: the positive
# control reads the store correctly, the negative control still observes staleness (without it a
# clean verdict is a blind spot, not a measurement), and the re-fetch never comes back stale.
expect() {
	local label="$1" pattern="$2" wanted="$3" actual
	actual="$(grep -c "${pattern}" "${WORK}/spike.log" || true)"
	printf '%-14s %-4s (expected %s)\n' "${label}" "${actual}" "${wanted}"
	[[ ${actual} == "${wanted}" ]] || failures+=("${label}: got ${actual}, expected ${wanted}")
}

echo "=== tally ==="
failures=()
expect "OBJECT=STALE" 'OBJECT=STALE' "${RUNS}"
expect "OBJECT=FRESH" 'OBJECT=FRESH' 1
expect "RESULT=STALE" 'RESULT=STALE' 0
expect "RESULT=FRESH" 'RESULT=FRESH' "$((RUNS * 2 + 1))"
expect "B commits" '\[B\] .* commit quest=' "$((RUNS * 2 + 1))"

if ((${#failures[@]} > 0)); then
	echo
	echo "SPIKE CHANGED — the recorded measurement no longer holds:" >&2
	printf '  %s\n' "${failures[@]}" >&2
	echo "Re-read docs/notes/shortcut-widget-payload-race-spike.md before acting on this." >&2
	exit 1
fi
echo
echo "SPIKE UNCHANGED — the re-fetch stays fresh and the negative control stays stale."
