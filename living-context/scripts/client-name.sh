#!/bin/sh
# PreToolUse on the plugin's record_context tool (spec §12.2). Names the
# Client: sets the call's `client` input to "Claude Code" through
# `updatedInput`, so the Entry shows it without the model passing it.
# `updatedInput` replaces the whole input, so the call's own `tool_input` is
# passed back as sent, with `client` added after its last member: a `client`
# the model sent too is overridden, since a JSON parser keeps the last of two
# same-named members. Decides no permission, so the call goes on to the
# usual prompt. Not in auto mode: auto mode reviewed the input the model
# sent and denies a call a hook changed afterwards, so there the call is
# left as it is. Prints nothing when `tool_input` can't be read. No state;
# records nothing.

[ -r "${0%/*}/common.sh" ] || exit 0
# shellcheck source-path=SCRIPTDIR source=common.sh
. "${0%/*}/common.sh"

read_input

[ "$(json_string permission_mode)" = auto ] && exit 0

# The top-level `tool_input` object from the token stream, as sent, with
# `client` added; nothing when there is no such object or it never closes.
# A string token is a line of its own starting with `"`; braces and
# brackets are counted on the other lines only, so none inside a string
# counts.
updated=$(json_tokens | awk -v client='"client":"Claude Code"' '
function walk(text,    i, c) {
    for (i = 1; i <= length(text); i++) {
        c = substr(text, i, 1)
        if (c == "{" || c == "[") {
            depth++
        } else if (c == "}" || c == "]") {
            depth--
            if (state == "object" && depth == 1) {
                body = body substr(text, 1, i - 1)
                done = 1
                exit
            }
        }
    }
    if (state == "object") {
        body = body text
    }
}
BEGIN { depth = 0; state = "seek" }
state == "seek" && /^"/ {
    if (depth == 1 && $0 == "\"tool_input\"") {
        state = "key"
    }
    next
}
state == "seek" { walk($0); next }
state == "key" {
    if (!/^[ \t]*:[ \t]*\{/) {
        # A string value equal to "tool_input", not the key.
        state = "seek"
        walk($0)
        next
    }
    rest = $0
    sub(/^[ \t]*:[ \t]*\{/, "", rest)
    depth++
    state = "object"
    walk(rest)
    next
}
state == "object" && /^"/ { body = body $0; next }
state == "object" { walk($0) }
END {
    if (done) {
        printf "{%s%s%s}\n", body, (body ~ /^[ \t]*$/ ? "" : ","), client
    }
}
')

[ -n "$updated" ] || exit 0

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","updatedInput":%s}}\n' "$updated"

exit 0
