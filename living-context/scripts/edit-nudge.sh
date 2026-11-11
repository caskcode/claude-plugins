#!/bin/sh
# PostToolUse on Edit|Write|MultiEdit|NotebookEdit (spec §12.2). On the first
# edit in a directory this session, asks the agent to read that directory's
# Entries with search_context before changing files there. Notes that the
# session edited files, for the Stop net. State: `dirs`, `edited`. Records
# nothing.

[ -r "${0%/*}/common.sh" ] || exit 0
# shellcheck source-path=SCRIPTDIR source=common.sh
. "${0%/*}/common.sh"

hook_start || exit 0

mark edited

edited=$(json_string file_path tool_input | json_unescape)
[ -n "$edited" ] || edited=$(json_string notebook_path tool_input | json_unescape)
[ -n "$edited" ] || exit 0
case $edited in
    /*) ;;
    *) edited=$cwd/$edited ;;
esac

dir=${edited%/*}
dir=$(cd -P -- "${dir:-/}" 2>/dev/null && pwd -P) || exit 0

note dirs "$dir" || exit 0

repository=$(repository_of "$dir")
[ -n "$repository" ] || exit 0
# The directory from the repository root, ending in /; empty at the root,
# which search_context takes no path for.
path=$(git -C "$dir" rev-parse --show-prefix 2>/dev/null) || exit 0
[ -n "$path" ] || exit 0

printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' \
    "$(json_escape "Living Context: call search_context { repository: $repository, path: $path } before changing files here.")"

exit 0
