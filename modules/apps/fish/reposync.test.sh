#!/usr/bin/env dash
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

# mk NAME: remote-NAME.git, me/NAME (the machine running reposync) and other/NAME (someone else) share one commit.
mk() {
    git init -q --bare -b main "$work/remote-$1.git"
    mkdir -p "$work/me" "$work/other"
    git clone -q "$work/remote-$1.git" "$work/me/$1" 2>/dev/null
    printf 'one\ntwo\nthree\n' >"$work/me/$1/f"
    git -C "$work/me/$1" add -A
    git -C "$work/me/$1" commit -q -m init
    git -C "$work/me/$1" push -q origin main
    git clone -q "$work/remote-$1.git" "$work/other/$1" 2>/dev/null
}
fresh() {
    rm -rf "$work/me" "$work/other" "$work"/remote-*.git
    for n in "$@"; do mk "$n"; done
}
commit_in() { # commit_in DIR FILE CONTENT
    printf '%s\n' "$3" >"$1/$2"
    git -C "$1" add -A
    git -C "$1" commit -q -m "edit $2"
}
other_pushes() { # other_pushes NAME FILE CONTENT
    commit_in "$work/other/$1" "$2" "$3"
    git -C "$work/other/$1" push -q origin main
}
run() {
    out=$(bash -euo pipefail "$here/reposync.sh" "$@" 2>&1)
    code=$?
}
check() {
    if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi
}
has() { case $out in *"$1"*) return 0 ;; *) return 1 ;; esac; }
head_of() { git -C "$1" rev-parse HEAD; }
remote_main() { git -C "$work/remote-$1.git" rev-parse refs/heads/main; }

fresh a
before=$(head_of "$work/me/a")
run "$work/me/a"
check "a repo that matches its remote reports up to date and changes nothing" \
    '[ "$code" -eq 0 ] && has "a: up to date" && [ "$(head_of "$work/me/a")" = "$before" ]'

fresh a
other_pushes a b.txt b
run "$work/me/a"
check "a repo behind its remote pulls and reports it" \
    '[ "$code" -eq 0 ] && has "a: pulled 1" && [ -f "$work/me/a/b.txt" ]'

fresh a
commit_in "$work/me/a" a.txt a
run "$work/me/a"
check "a repo ahead of its remote pushes and reports it" \
    '[ "$code" -eq 0 ] && has "a: pushed 1" && [ "$(remote_main a)" = "$(head_of "$work/me/a")" ]'

fresh a
other_pushes a b.txt b
commit_in "$work/me/a" a.txt a
run "$work/me/a"
check "a repo that diverged cleanly rebases and pushes" \
    '[ "$code" -eq 0 ] && has "a: pulled 1, pushed 1" && [ -f "$work/me/a/b.txt" ] && [ "$(remote_main a)" = "$(head_of "$work/me/a")" ]'

fresh a
printf 'one\nEDIT\nthree\n' >"$work/me/a/f"
printf 'x\n' >"$work/me/a/new.txt"
other_pushes a b.txt b
before=$(git -C "$work/me/a" rev-list --count HEAD)
run "$work/me/a"
check "uncommitted edits survive a pull and are reported, never committed" \
    '[ "$code" -eq 0 ] && has "a: pulled 1; 2 uncommitted files" && [ -f "$work/me/a/b.txt" ] && [ "$(cat "$work/me/a/f")" = "$(printf "one\nEDIT\nthree")" ] && [ "$(git -C "$work/me/a" rev-list --count HEAD)" = "$((before + 1))" ]'

fresh a
printf 'x\n' >"$work/me/a/new.txt"
run "$work/me/a"
check "an up to date repo with one uncommitted file says so" \
    '[ "$code" -eq 0 ] && has "a: up to date; 1 uncommitted file" && ! has "files"'

fresh a
printf 'one\nBRANDON\nthree\n' >"$work/other/a/f"
git -C "$work/other/a" commit -q -am "other edits f"
git -C "$work/other/a" push -q origin main
commit_in "$work/me/a" f "$(printf 'one\nME\nthree')"
mine=$(head_of "$work/me/a")
main_before=$(remote_main a)
run "$work/me/a"
check "committed work that clashes with upstream exits 1, names the file, and leaves the repo untouched" \
    '[ "$code" -eq 1 ] && has "a: CONFLICT, your commits clash with upstream in: f" && [ "$(head_of "$work/me/a")" = "$mine" ] && [ -z "$(git -C "$work/me/a" status --porcelain)" ] && [ ! -d "$work/me/a/.git/rebase-merge" ] && [ "$(remote_main a)" = "$main_before" ]'

fresh a
printf 'one\nME\nthree\n' >"$work/me/a/f"
printf 'one\nBRANDON\nthree\n' >"$work/other/a/f"
git -C "$work/other/a" commit -q -am "other edits f"
git -C "$work/other/a" push -q origin main
run "$work/me/a"
check "uncommitted edits that clash with upstream exit 1, leave markers in the file and keep the stash" \
    '[ "$code" -eq 1 ] && has "a: CONFLICT, your uncommitted edits clash with upstream in: f" && [ -n "$(git -C "$work/me/a" stash list)" ] && [ "$(sed -n 2p "$work/me/a/f")" = "<<<<<<< Updated upstream" ]'

fresh a
git -C "$work/me/a" remote set-url origin "$work/nowhere.git"
commit_in "$work/me/a" a.txt a
run "$work/me/a"
check "an unreachable remote is reported, not failed" \
    '[ "$code" -eq 0 ] && has "a: offline, skipped"'

fresh a b
printf 'one\nBRANDON\nthree\n' >"$work/other/a/f"
git -C "$work/other/a" commit -q -am "other edits f"
git -C "$work/other/a" push -q origin main
commit_in "$work/me/a" f "$(printf 'one\nME\nthree')"
other_pushes b b.txt b
run "$work/me/a" "$work/me/b"
check "one conflicted repo does not stop the next, and the run exits 1 naming it" \
    '[ "$code" -eq 1 ] && has "a: CONFLICT" && has "b: pulled 1" && [ -f "$work/me/b/b.txt" ] && has "Resolve: a"'

[ "$fails" -eq 0 ]
