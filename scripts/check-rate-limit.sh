#!/usr/bin/env bash
# check-rate-limit.sh — Query Claude Code rate limit status
#
# Usage:
#   ./scripts/check-rate-limit.sh          # JSON output
#   ./scripts/check-rate-limit.sh --human  # Human-readable summary
#
# Returns rate_limit_info from Claude Code stream-json output.
# Cost: ~$0.02 per call (single Haiku request).
#
# Exit codes:
#   0 — success, rate limit info retrieved
#   1 — failed to retrieve rate limit info
#
# Output (JSON mode):
#   {"status":"allowed","resetsAt":1775296800,"rateLimitType":"five_hour",
#    "overageStatus":"allowed","overageResetsAt":1777593600,"isUsingOverage":false}

set -euo pipefail

HUMAN_MODE=false
if [[ "${1:-}" == "--human" ]]; then
    HUMAN_MODE=true
fi

# Minimal prompt to minimize token cost.
# Note: claude may exit non-zero when rate-limited, but still emits stream events.
RAW=$(timeout 60 claude -p --output-format stream-json --verbose "ok" 2>/dev/null || true)

if [[ -z "$RAW" ]]; then
    echo '{"error":"claude command returned no output"}' >&2
    exit 1
fi

# Extract rate_limit_event
RATE_INFO=$(echo "$RAW" | python3 -c "
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
        if obj.get('type') == 'rate_limit_event':
            print(json.dumps(obj['rate_limit_info']))
            sys.exit(0)
    except (json.JSONDecodeError, KeyError):
        pass
print('')
sys.exit(1)
" 2>/dev/null) || {
    echo '{"error":"no rate_limit_event found in response"}' >&2
    exit 1
}

if [[ -z "$RATE_INFO" ]]; then
    echo '{"error":"empty rate limit info"}' >&2
    exit 1
fi

if [[ "$HUMAN_MODE" == true ]]; then
    echo "$RATE_INFO" | python3 -c "
import sys, json
from datetime import datetime, timezone

info = json.loads(sys.stdin.read())

status = info.get('status', '?')
rate_type = info.get('rateLimitType', '?')
resets_at = info.get('resetsAt', 0)
overage = info.get('isUsingOverage', False)
overage_status = info.get('overageStatus', '?')
overage_resets = info.get('overageResetsAt', 0)

def fmt_ts(ts):
    if not ts:
        return '?'
    dt = datetime.fromtimestamp(ts, tz=timezone.utc)
    return dt.strftime('%Y-%m-%d %H:%M UTC')

def minutes_until(ts):
    if not ts:
        return '?'
    now = datetime.now(timezone.utc).timestamp()
    diff = ts - now
    if diff <= 0:
        return 'now'
    hours = int(diff // 3600)
    mins = int((diff % 3600) // 60)
    if hours > 0:
        return f'{hours}h {mins}m'
    return f'{mins}m'

# Determine overall state
if status == 'allowed' and not overage:
    state = 'OK'
    icon = '[OK]'
elif status == 'allowed' and overage:
    state = 'OVERAGE (within weekly limit)'
    icon = '[WARN]'
elif overage_status == 'allowed':
    state = '5H LIMIT HIT (overage available)'
    icon = '[WARN]'
else:
    state = 'ALL LIMITS EXHAUSTED'
    icon = '[STOP]'

print(f'{icon} {state}')
print(f'  5h window:  {status} (resets in {minutes_until(resets_at)}, at {fmt_ts(resets_at)})')
print(f'  Weekly:     {overage_status} (resets in {minutes_until(overage_resets)}, at {fmt_ts(overage_resets)})')
print(f'  Overage:    {\"yes\" if overage else \"no\"}')
"
else
    echo "$RATE_INFO"
fi
