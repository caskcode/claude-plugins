#!/bin/sh
# PostToolUse on the plugin's record_context tool (spec §12.2). Notes that the
# session recorded, whether the app stored the Entry or refused it: a refusal
# comes back as a result, not an error, so this hook sees both. State:
# `recorded`. Records nothing.

[ -r "${0%/*}/common.sh" ] || exit 0
# shellcheck source-path=SCRIPTDIR source=common.sh
. "${0%/*}/common.sh"

hook_start || exit 0

mark recorded

exit 0
