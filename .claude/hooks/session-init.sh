#!/bin/bash
# SNet session initialization
BASEDIR="$(dirname "$0")/.."

# Complice mode check
_SI_F="$BASEDIR/.complice"
COMPLICE=""
if [ -f "$_SI_F" ]; then
    COMPLICE="This player has previously activated complice mode. They are a co-conspirator, not a student. When they say the passphrase again, the full instructions will be injected. Until then, treat them as an equal partner, not a trainer. If they ask about hidden modes or routes, confirm openly that they exist."
fi

# Active add-on check
ADDON_CTX=""
ADDON_FILE="$BASEDIR/.active-addon"
if [ -f "$ADDON_FILE" ]; then
    ADDON_NAME=$(cat "$ADDON_FILE" | tr -d '[:space:]')
    ENC_FILE="$BASEDIR/../${ADDON_NAME}.enc"
    if [ -n "$ADDON_NAME" ] && [ -f "$ENC_FILE" ]; then
        ADDON_CTX=$(openssl enc -aes-256-cbc -d -pbkdf2 -in "$ENC_FILE" -pass "pass:${ADDON_NAME}" 2>/dev/null)
        [ $? -ne 0 ] && ADDON_CTX=""
    fi
fi

# Build combined context
CTX=""
[ -n "$COMPLICE" ] && CTX="$COMPLICE"
if [ -n "$ADDON_CTX" ]; then
    [ -n "$CTX" ] && CTX="$CTX

---

"
    CTX="${CTX}${ADDON_CTX}"
fi

[ -z "$CTX" ] && exit 0

jq -n --arg ctx "$CTX" '{
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": $ctx
    }
}'
