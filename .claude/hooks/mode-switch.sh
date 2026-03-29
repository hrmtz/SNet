#!/bin/bash
# SNet add-on mode switcher (hidden commands)
# Decrypts add-on .enc files using the command as passphrase

BASEDIR="$(dirname "$0")/../.."

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // .content // .message // empty' 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')

[ -z "$PROMPT" ] && exit 0

case "$PROMPT" in
    njslyr|gis) ;;
    vanilla)
        rm -f "$BASEDIR/.claude/.active-addon"
        jq -n '{
            "hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": "All add-ons disabled. Back to vanilla."
            }
        }'
        exit 0
        ;;
    *) exit 0 ;;
esac

ENC_FILE="$BASEDIR/${PROMPT}.enc"
[ ! -f "$ENC_FILE" ] && exit 0

CONTENT=$(openssl enc -aes-256-cbc -d -pbkdf2 -in "$ENC_FILE" -pass "pass:${PROMPT}" 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$CONTENT" ]; then
    echo "$PROMPT" > "$BASEDIR/.claude/.active-addon"
    jq -n --arg ctx "$CONTENT" '{
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": $ctx
        }
    }'
fi
