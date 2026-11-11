#!/bin/sh
# UserPromptSubmit (spec §12.2). For each Work item key the prompt or the
# current branch names, the first time this session, one line pointing the
# agent at the repository and at the key's Context pack; the model judges
# whether a key-shaped word such as UTF-8 is a Work item. Also deletes session
# state older than 7 days. State: `keys`. Records nothing.

[ -r "${0%/*}/common.sh" ] || exit 0
# shellcheck source-path=SCRIPTDIR source=common.sh
. "${0%/*}/common.sh"

hook_start || exit 0

# Sessions not touched for 7 days; this one was touched by hook_start.
(cd "$sessions" 2>/dev/null && find . ! -name . -prune -type d -mtime +6 -exec rm -rf {} + 2>/dev/null)

# keys_in: the key-shaped words on stdin, one per line, each once, in order.
keys_in() {
    sed -E 's/[A-Z][A-Z0-9]+-[0-9]+/\
&\
/g' | sed -n -E '/^[A-Z][A-Z0-9]+-[0-9]+$/p' | awk '!seen[$0]++'
}

# Only the prompt is searched: a key in `cwd` or `transcript_path` is no
# prompt's.
prompt_keys=$(json_string prompt | keys_in)

branch=
branch_keys=
if has_git; then
    branch=$(git -C "$cwd" symbolic-ref --short -q HEAD 2>/dev/null)
    branch_keys=$(printf '%s\n' "$branch" | keys_in)
fi

repository=$(repository_of "$cwd")

nl='
'
for key in $(printf '%s\n%s\n' "$prompt_keys" "$branch_keys" | awk 'NF && !seen[$0]++'); do
    note keys "$key" || continue

    clauses=
    if [ -n "$repository" ]; then
        clauses="repository is $repository (git remote origin)"
    fi
    case "$nl$prompt_keys$nl" in
        *"$nl$key$nl"*) ;;
        *) clauses="${clauses:+$clauses; }branch $branch names $key" ;;
    esac
    if [ -n "$clauses" ]; then
        printf 'Living Context: %s. If no Living Context pack for %s is in your context, call get_context %s.\n' \
            "$clauses" "$key" "$key"
    else
        printf 'Living Context: if no Living Context pack for %s is in your context, call get_context %s.\n' \
            "$key" "$key"
    fi
done

exit 0
