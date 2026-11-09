#!/usr/bin/env bash
#
# mayhem/test.sh — RUN this repo's OWN functional test suite (already built by mayhem/build.sh).
# exit 0 = pass. EDIT per repo. PATCH-grade oracle: after an agent patches the source, the grader
# rebuilds (build.sh) then runs this. DELETE this file if the repo has no meaningful tests.
#
# IMPORTANT:
#  * Must assert BEHAVIOR/OUTPUT, not just exit status. The oracle has to check asserted values /
#    golden-output diffs / known-answer results — so a PATCH that "fixes" a bug by making the program
#    exit(0) (or any no-op) FAILS here. Running inputs and checking only "exit 0 / didn't crash" is
#    NOT a functional test (it's trivially reward-hackable) — use the project's real assertion suite.
#  * Do NOT build here — mayhem/build.sh already compiled the test suite (with the project's normal
#    flags). This script only RUNS the pre-built tests and reports counts. If the test runner is
#    missing, that's a build.sh bug — fail loudly rather than silently rebuilding.
#  * REQUIRED OUTPUT — a CTRF (https://ctrf.io) summary so Mayhem/the PATCH grader reads the counts:
#      - writes a CTRF JSON report to ${CTRF_REPORT:-$SRC/ctrf-report.json}, and
#      - prints a one-line `CTRF {...}` marker to stdout (same JSON, compact).
#    Only `results.summary` (with tests/passed/failed/pending/skipped/other) is required.
#    Use the emit_ctrf helper below; it computes tests = passed+failed+skipped and sets the exit
#    code (0 iff failed==0). Map your framework's output to passed/failed/skipped.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"   # build parallelism; env-overridable, falls back to nproc (use -j"$MAYHEM_JOBS")
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
# Writes a CTRF report (file + stdout `CTRF {...}` marker) and returns non-zero iff failed>0.
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

# Upstream's capture regression suite: tests/tests.pl runs ../capture/capture over every tests/pcap/*.pcap
# and diffs the parsed sessions against the committed pcap/<name>.test golden JSON (TAP output).
# The suite needs ES-free capture mode only; the viewer/API tests (.t files) need Elasticsearch and are not run.
T="$SRC/mayhem/build/oracle/tests"
[ -x "$SRC/mayhem/build/oracle/capture/capture" ] || { echo "oracle capture binary missing - mayhem/build.sh did not run" >&2; emit_ctrf "arkime-tests.pl" 0 1 0; exit 1; }
cd "$T"
expected=$(ls pcap/*.pcap | wc -l)
out=$(timeout 3000 perl tests.pl 2>&1) ; rc=$?
echo "$out" | tail -n 40
passed=$(printf '%s\n' "$out" | grep -c '^ok ')
failed=$(printf '%s\n' "$out" | grep -c '^not ok ')

# KAT probe, outside perl: a known pcap must parse to the exact golden session fields.
kat_fail=0
probe=$(../capture/capture --tests -c config.test.ini -n test -r pcap/dns-udp.pcap 2>&1 1>/dev/null | ./tests.pl --fix)
printf '%s\n' "$probe" | grep -qF '"nameserver" : "ns3.p16.dynect.net"' || kat_fail=1
printf '%s\n' "$probe" | grep -qF '"ip" : "192.30.252.128"' || kat_fail=1

# A run that produced fewer verdicts than there are pcaps (or perl failed) is a failure, not a pass.
missing=$(( expected - passed - failed ))
[ "$missing" -lt 0 ] && missing=0
failed=$(( failed + missing + kat_fail ))
[ "$rc" -ne 0 ] && [ "$failed" -eq 0 ] && failed=1
emit_ctrf "arkime-tests.pl" "$passed" "$failed" 0
