#!/usr/bin/env bash
# Read one trigger file (stdin) and check it. Usage: bash trigger-read.sh <name> < file
# Prints kind=, target=, when=, ask=, error= — the one parser, shared by the dashboard
# and the scheduler (schedule.sh), so they can't disagree on what is valid.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=flow-lib.sh
. "$HERE/flow-lib.sh"
# shellcheck source=trigger-lib.sh
. "$HERE/trigger-lib.sh"
T="$(mktemp)"
trap 'rm -f "$T"' EXIT
cat > "$T"
trigger_read "$T" "${1:?Usage: trigger-read.sh <name> < file}"
