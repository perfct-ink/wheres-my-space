#!/bin/bash
# Stop hook: after a turn, run tests + make dev; commit automatically if both pass.
# Wired via .claude/settings.json (Stop hook).
#
# xcodebuild resolves two matching destinations for this Mac (arch:arm64 and
# arch:x86_64, same device id) and picks one with a "WARNING: Using the first
# of multiple matching destinations" - this ambiguity is what caused the
# intermittent "test runner hung before establishing connection" failures.
# Pinning arch=arm64 removes the ambiguity.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT" || exit 0

APP_NAME="WheresMySpace"
TEST_LOG="/tmp/wheresmyspace-hook-test.log"
BUILD_LOG="/tmp/wheresmyspace-hook-build.log"

json_msg() {
  jq -n --arg msg "$1" '{systemMessage: $msg}'
}

# Stop hooks must no-op when stop_hook_active is true, otherwise a hook whose
# own output causes another Stop event can recurse indefinitely.
HOOK_INPUT="$(cat)"
if echo "$HOOK_INPUT" | jq -e '.stop_hook_active == true' > /dev/null 2>&1; then
  exit 0
fi

# Nothing changed -> nothing to test, build, or commit.
if [ -z "$(git status --porcelain)" ]; then
  exit 0
fi

run_tests() {
  pkill -x "$APP_NAME" 2>/dev/null
  xcodebuild test -project WheresMySpace.xcodeproj -scheme WheresMySpace -destination 'platform=macOS,arch=arm64' >> "$TEST_LOG" 2>&1
}

: > "$TEST_LOG"
if ! run_tests; then
  echo "(hook) first attempt failed, retrying once" >> "$TEST_LOG"
  if ! run_tests; then
    json_msg "Auto-commit hook: unit tests failed (after retry), skipped build and commit. Log: $TEST_LOG"
    exit 0
  fi
fi

if ! make dev > "$BUILD_LOG" 2>&1; then
  json_msg "Auto-commit hook: tests passed but 'make dev' failed, skipped commit. Log: $BUILD_LOG"
  exit 0
fi

git add -A

if git diff --cached --quiet; then
  exit 0
fi

STATUS="$(git diff --cached --name-status)"
COUNT="$(echo "$STATUS" | wc -l | tr -d ' ')"
ACTIONS="$(echo "$STATUS" | cut -c1 | sort -u)"
ACTION_COUNT="$(echo "$ACTIONS" | wc -l | tr -d ' ')"

if [ "$ACTION_COUNT" -eq 1 ]; then
  case "$ACTIONS" in
    A) VERB="Add" ;;
    D) VERB="Remove" ;;
    *) VERB="Update" ;;
  esac
else
  VERB="Update"
fi

NAMES="$(echo "$STATUS" | awk '{print $NF}' | xargs -n1 basename | paste -sd ', ' -)"
if [ "$COUNT" -le 3 ]; then
  SUBJECT="$VERB $NAMES"
else
  FIRST3="$(echo "$STATUS" | awk '{print $NF}' | xargs -n1 basename | head -3 | paste -sd ', ' -)"
  SUBJECT="$VERB $FIRST3, +$((COUNT - 3)) more"
fi

git commit -m "$SUBJECT" --quiet
HASH="$(git rev-parse --short HEAD)"
json_msg "Auto-commit hook: tests + build passed. Committed $HASH: $SUBJECT"
