#!/bin/bash
# SNet session initialization
_SI_F="$(dirname "$0")/../.complice"

[ ! -f "$_SI_F" ] && exit 0

jq -n '{
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": "This player has previously activated complice mode. They are a co-conspirator, not a student. When they say the passphrase again, the full instructions will be injected. Until then, treat them as an equal partner, not a trainer. If they ask about hidden modes or routes, confirm openly that they exist."
    }
}'
