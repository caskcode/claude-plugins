# shellcheck shell=sh
# Shared by the Living Context command hooks (spec §12.2). Sourced, never run.
#
# POSIX sh plus git: no jq, no bash. Each hook reads Claude Code's hook JSON
# on stdin and keeps its state in ${CLAUDE_PLUGIN_DATA}/sessions/<session_id>/.
# A hook never fails the agent: any problem ends it quietly with status 0.

set -f
# Byte-wise ranges, so [A-Z] in a key and the session id's characters mean
# the same in every locale.
LC_ALL=C
export LC_ALL

soh=$(printf '\001')
tab=$(printf '\t')

# The hook's JSON on stdin, on one line: JSON strings hold no raw line
# breaks, so the only ones are between tokens.
read_input() {
    input=$(tr '\n\r' '  ')
}

# The hook's JSON with each string on a line of its own, so a key is a line
# `"name"`, then a line `:`, then its string value: no string's content can
# pass for a key, however it is escaped.
json_tokens() {
    printf '%s\n' "$input" | sed -E 's/"([^"\\]|\\.)*"/\
&\
/g'
}

# json_string NAME [WITHIN]: the first string value of field NAME, still
# JSON-escaped; empty when there is none. With WITHIN, only from field
# WITHIN on, as `tool_input`, so a field of the same name in `tool_response`
# is never taken for it.
json_string() {
    json_tokens | sed -n "/^\"${2:-$1}\"\$/,\$p" | sed -n "/^\"$1\"\$/{
n
/^[[:space:]]*:[[:space:]]*\$/!b
n
s/^\"\(.*\)\"\$/\1/p
q
}"
}

# json_literal NAME: the first non-string value (true, false, a number) of
# field NAME; empty when there is none or it is a string.
json_literal() {
    json_tokens | sed -n "/^\"$1\"\$/{
n
s/^[[:space:]]*:[[:space:]]*\([A-Za-z0-9.+-]*\).*/\1/p
q
}"
}

# Undoes the JSON escapes a path can carry (\\, \", \/, \t), in one pass.
json_unescape() {
    sed -e 's/\\\\/'"$soh"'/g' -e 's/\\"/"/g' -e 's/\\\//\//g' -e 's/\\t/'"$tab"'/g' \
        -e 's/'"$soh"'/\\/g'
}

# json_escape TEXT: TEXT as the inside of a JSON string.
json_escape() {
    printf '%s\n' "$1" | tr -d '\001-\010\013-\037' |
        sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/'"$tab"'/\\t/g' |
        sed -e ':a' -e '$!N' -e '$!ba' -e 's/\n/\\n/g'
}

# Reads the input and finds this session's state directory, $state, making it
# and marking it in use. Sets $session, $sessions, $state and $cwd. Fails, so
# the hook does nothing, without a plugin data directory or a usable session.
hook_start() {
    read_input
    case ${CLAUDE_PLUGIN_DATA:-} in
        /*) ;;
        *) return 1 ;;
    esac
    session=$(json_string session_id)
    case $session in
        '' | *[!A-Za-z0-9_-]*) return 1 ;;
    esac
    sessions=${CLAUDE_PLUGIN_DATA%/}/sessions
    state=$sessions/$session
    mkdir -p "$state" 2>/dev/null || return 1
    # A session in use is never one the 7-day cleanup removes.
    touch "$state" 2>/dev/null
    cwd=$(json_string cwd | json_unescape)
    [ -d "$cwd" ] || cwd=$PWD
    return 0
}

# mark NAME: makes this session's state file NAME, quietly. Not with `:`: a
# failed redirection on a special builtin ends a POSIX shell.
mark() {
    printf '' 2>/dev/null >>"$state/$1"
}

# marked NAME: whether this session's state file NAME exists.
marked() {
    [ -e "$state/$1" ]
}

# note NAME LINE: adds LINE to this session's state file NAME, unless it is
# there already; fails when it was there, or can't be added.
note() {
    if grep -Fqx -- "$2" "$state/$1" 2>/dev/null; then
        return 1
    fi
    printf '%s\n' "$2" 2>/dev/null >>"$state/$1"
}

# has_git: whether git is there to ask.
has_git() {
    command -v git >/dev/null 2>&1
}

# percent_decode TEXT: TEXT with each %XX of a printable ASCII character
# decoded, as the app decodes a URL's path. Any other % is left, and fails
# the repository check, as the app's does.
percent_decode() {
    decode_rest=$1
    decode_done=
    while :; do
        case $decode_rest in
            *%[2-7][0-9A-Fa-f]*) ;;
            *) break ;;
        esac
        decode_head=${decode_rest%%%[2-7][0-9A-Fa-f]*}
        decode_rest=${decode_rest#"$decode_head"%}
        decode_hex=${decode_rest%"${decode_rest#??}"}
        decode_rest=${decode_rest#??}
        # shellcheck disable=SC2059 # the format is the octal escape built here
        decode_done=$decode_done$decode_head$(printf "\\$(printf '%03o' "0x$decode_hex")")
    done
    printf '%s\n' "$decode_done$decode_rest"
}

# normalize_remote URL: a git remote as owner/name, as the app reads one
# (spec §4.3, backend/src/api/code-path.ts): scheme, user, host and .git
# removed, lowercased. Empty for a remote that is a local path.
normalize_remote() {
    remote=$1
    case $remote in
        [Ff][Ii][Ll][Ee]://*) return 0 ;;
        [A-Za-z]*://*)
            remote_path=${remote#*://}
            case $remote_path in
                */*) remote_path=${remote_path#*/} ;;
                *) return 0 ;;
            esac
            remote_path=$(percent_decode "${remote_path%%[?#]*}")
            ;;
        /* | '~'* | .* | [A-Za-z]:[\\/]*) return 0 ;;
        *:*)
            remote_host=${remote%%:*}
            case $remote_host in
                '' | */* | *[[:space:]]*) remote_path=$remote ;;
                *) remote_path=${remote#*:} ;;
            esac
            ;;
        *) remote_path=$remote ;;
    esac
    remote_path=$(printf '%s\n' "$remote_path" | tr '[:upper:]' '[:lower:]' | sed -e 's:/*$::' -e 's:\.git$::')
    remote_path=${remote_path#/}
    # `github.com/owner/name` with no scheme: the host goes too.
    remote_first=${remote_path%%/*}
    remote_rest=${remote_path#*/}
    case $remote_first in
        *.*) case $remote_rest in */*) remote_path=$remote_rest ;; esac ;;
    esac
    case /$remote_path/ in
        *//* | */./* | */../*) return 0 ;;
    esac
    case $remote_path in
        *[!a-z0-9_./-]*) return 0 ;;
        */*) printf '%s\n' "$remote_path" ;;
    esac
}

# repository_of DIR: the repository DIR is in, as owner/name from its
# `origin`; empty outside git or without a remote one.
repository_of() {
    has_git || return 0
    remote=$(git -C "$1" remote get-url origin 2>/dev/null) || return 0
    normalize_remote "$remote"
}
