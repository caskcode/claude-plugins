#!/bin/sh
# Stop (spec §12.2). Stops the agent at most once a session, when the session
# named a Work item and edited files but recorded nothing, to record what it
# learned or say there is nothing. Never while the agent is already
# continuing for a Stop hook. State: `stop-nudged`. Records nothing.

[ -r "${0%/*}/common.sh" ] || exit 0
# shellcheck source-path=SCRIPTDIR source=common.sh
. "${0%/*}/common.sh"

hook_start || exit 0

[ "$(json_literal stop_hook_active)" = false ] || exit 0
[ -s "$state/keys" ] || exit 0
marked edited || exit 0
! marked recorded || exit 0
! marked stop-nudged || exit 0
mark stop-nudged || exit 0

printf '{"decision":"block","reason":"%s"}\n' \
    "$(json_escape "Before you finish: if this session learned something a teammate starting later work in this area should know, record it now with record_context, following the Living Context skill. If nothing qualifies, reply only 'Nothing to record.'")"

exit 0
