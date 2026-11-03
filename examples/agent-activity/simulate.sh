#!/bin/bash
# Exercise only the example socket; no real agent configuration changes.
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
socket="$root/examples/agent-activity/control.sock"
session=$(uuidgen)

report() {
  local name=$1 sequence=$2 state=$3
  "$root/.build/debug/sbar" agents report \
    --socket "$socket" \
    --source simulation --session "$session-$name" --run demo \
    --sequence "$sequence" --state "$state" \
    --title "Example $name" --project "$root" --agent simulator
}

report build 0 working
report review 0 working
sleep 2
report review 1 needsInput
sleep 2
report build 1 finished
