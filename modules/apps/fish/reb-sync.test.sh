#!/usr/bin/env dash
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

# remote.git, dad (the machine running reb) and brandon (pushes to main) start on one shared commit.
fresh() {
    rm -rf "$work/remote.git" "$work/dad" "$work/brandon"
    git init -q --bare -b main "$work/remote.git"
    git clone -q "$work/remote.git" "$work/dad" 2>/dev/null
    printf 'one\ntwo\nthree\n' >"$work/dad/f"
    git -C "$work/dad" add -A
    git -C "$work/dad" commit -q -m init
    git -C "$work/dad" push -q origin main
    git clone -q "$work/remote.git" "$work/brandon"
}

sync() { bash -euo pipefail "$here/reb-sync.sh" "$@" >/dev/null 2>&1; }
check() {
    name=$1 ok=$2
    if [ "$ok" = 1 ]; then
        echo "ok   $name"
    else
        echo "FAIL $name"
        fails=$((fails + 1))
    fi
}
remote_ref() { git -C "$work/remote.git" rev-parse --verify -q "refs/heads/$1"; }

fresh
printf 'b\n' >"$work/brandon/b.txt"
git -C "$work/brandon" add -A
git -C "$work/brandon" commit -q -m "brandon change"
git -C "$work/brandon" push -q origin main
printf 'a\n' >"$work/dad/a.txt"
sync pull "$work/dad"
code=$?
check "pull puts upstream work under local edits and commits the local edits" \
    "$([ "$code" -eq 0 ] && [ -f "$work/dad/b.txt" ] && [ -f "$work/dad/a.txt" ] && git -C "$work/dad" diff --quiet HEAD && echo 1 || echo 0)"

before=$(git -C "$work/dad" rev-parse HEAD)
sync pull "$work/dad"
code=$?
check "pull with nothing new changes nothing" \
    "$([ "$code" -eq 0 ] && [ "$(git -C "$work/dad" rev-parse HEAD)" = "$before" ] && echo 1 || echo 0)"

git -C "$work/dad" remote set-url origin "$work/nowhere.git"
sync pull "$work/dad"
code=$?
check "pull offline succeeds and changes nothing" \
    "$([ "$code" -eq 0 ] && [ "$(git -C "$work/dad" rev-parse HEAD)" = "$before" ] && echo 1 || echo 0)"
sync push "$work/dad" trey 0
code=$?
check "push offline succeeds" "$([ "$code" -eq 0 ] && echo 1 || echo 0)"

fresh
printf 'one\nBRANDON\nthree\n' >"$work/brandon/f"
git -C "$work/brandon" commit -q -am "brandon edits f"
git -C "$work/brandon" push -q origin main
printf 'one\nDAD\nthree\n' >"$work/dad/f"
sync pull "$work/dad"
code=$?
dad_head=$(git -C "$work/dad" rev-parse HEAD)
check "pull on a real conflict exits 3 and leaves dad's tree as it was, no rebase half-done" \
    "$([ "$code" -eq 3 ] && [ "$(cat "$work/dad/f")" = "$(printf 'one\nDAD\nthree')" ] && [ -z "$(git -C "$work/dad" status --porcelain)" ] && [ ! -d "$work/dad/.git/rebase-merge" ] && echo 1 || echo 0)"
main_before=$(remote_ref main)
sync push "$work/dad" trey 3
check "push after a conflict goes to conflict-trey and leaves main alone" \
    "$([ "$(remote_ref conflict-trey)" = "$dad_head" ] && [ "$(remote_ref main)" = "$main_before" ] && echo 1 || echo 0)"

fresh
printf 'a\n' >"$work/dad/a.txt"
sync pull "$work/dad"
sync push "$work/dad" trey 0
check "push after a clean pull reaches main" \
    "$([ "$(remote_ref main)" = "$(git -C "$work/dad" rev-parse HEAD)" ] && echo 1 || echo 0)"

fresh
printf 'one\nBRANDON\nthree\n' >"$work/brandon/f"
git -C "$work/brandon" commit -q -am "brandon edits f"
git -C "$work/brandon" push -q origin main
printf 'one\nDAD\nthree\n' >"$work/dad/f"
sync pull "$work/dad"
sync push "$work/dad" trey 3
git -C "$work/brandon" fetch -q origin
git -C "$work/brandon" pull -q --no-rebase origin main >/dev/null 2>&1
git -C "$work/brandon" merge -q -X theirs origin/conflict-trey >/dev/null 2>&1
git -C "$work/brandon" push -q origin main
sync pull "$work/dad"
code=$?
sync push "$work/dad" trey "$code"
check "after the conflict is fixed on main the next reb pushes and deletes conflict-trey" \
    "$([ -z "$(remote_ref conflict-trey)" ] && [ "$(remote_ref main)" = "$(git -C "$work/dad" rev-parse HEAD)" ] && echo 1 || echo 0)"

fresh
printf 'a\n' >"$work/dad/a.txt"
sync pull "$work/dad"
printf 'b\n' >"$work/brandon/b.txt"
git -C "$work/brandon" add -A
git -C "$work/brandon" commit -q -m "brandon pushes first"
git -C "$work/brandon" push -q origin main
main_before=$(remote_ref main)
sync push "$work/dad" trey 0
code=$?
check "push rejected because main moved falls back to conflict-trey and succeeds" \
    "$([ "$code" -eq 0 ] && [ "$(remote_ref main)" = "$main_before" ] && [ "$(remote_ref conflict-trey)" = "$(git -C "$work/dad" rev-parse HEAD)" ] && echo 1 || echo 0)"

[ "$fails" -eq 0 ]
