repo=$2
export GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=10'

g() { git -C "$repo" "$@"; }
# obscura reconnects right before the push, and a stalled HTTPS push otherwise never returns.
net() { timeout 30 git -C "$repo" "$@"; }

case $1 in
pull)
  g rebase --abort 2>/dev/null || true
  g add -A
  g diff --cached --quiet || g commit -q -m "rebuild $(date '+%Y-%m-%d %H:%M:%S')"
  net fetch -q origin 2>/dev/null || { echo "Offline, skipping sync."; exit 0; }
  g merge-base --is-ancestor origin/main HEAD && exit 0
  g rebase -q origin/main >/dev/null 2>&1 || { g rebase --abort; exit 3; }
  ;;
push)
  target=$3 conflict=$4
  if [ "$conflict" = 0 ] && net push -q origin HEAD:main 2>/dev/null; then
    net push -q origin --delete "conflict-$target" 2>/dev/null || true
    exit 0
  fi
  net push -q -f origin "HEAD:refs/heads/conflict-$target" 2>/dev/null || echo "Could not reach GitHub, will retry on the next reb."
  ;;
esac
