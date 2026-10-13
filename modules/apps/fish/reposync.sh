export GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=10'

stuck=()

sync_one() {
  local repo=$1 name pulled=0 pushed=0 behind ahead files dirty note=
  name=$(basename "$repo")
  g() { git -C "$repo" "$@"; }

  g fetch -q origin 2>/dev/null || { echo "$name: offline, skipped"; return; }
  read -r ahead behind < <(g rev-list --left-right --count HEAD...origin/main)

  if [ "$behind" -gt 0 ]; then
    if ! g rebase -q --autostash origin/main >/dev/null 2>&1; then
      files=$(g diff --name-only --diff-filter=U | paste -sd' ' -)
      g rebase --abort
      echo "$name: CONFLICT, your commits clash with upstream in: $files"
      stuck+=("$name")
      return
    fi
    files=$(g diff --name-only --diff-filter=U | paste -sd' ' -)
    if [ -n "$files" ]; then
      echo "$name: CONFLICT, your uncommitted edits clash with upstream in: $files (the edits are also in git stash)"
      stuck+=("$name")
      return
    fi
    pulled=$behind
  fi
  if [ "$ahead" -gt 0 ]; then
    if g push -q origin HEAD:main 2>/dev/null; then
      pushed=$ahead
    else
      echo "$name: CONFLICT, push to origin/main was rejected"
      stuck+=("$name")
      return
    fi
  fi

  if [ "$pulled" -gt 0 ] && [ "$pushed" -gt 0 ]; then
    note="pulled $pulled, pushed $pushed"
  elif [ "$pulled" -gt 0 ]; then
    note="pulled $pulled"
  elif [ "$pushed" -gt 0 ]; then
    note="pushed $pushed"
  else
    note="up to date"
  fi
  dirty=$(g status --porcelain | wc -l)
  if [ "$dirty" -eq 1 ]; then
    note="$note; 1 uncommitted file"
  elif [ "$dirty" -gt 1 ]; then
    note="$note; $dirty uncommitted files"
  fi
  echo "$name: $note"
}

for repo; do
  sync_one "$repo"
done

if [ "${#stuck[@]}" -gt 0 ]; then
  echo "Resolve: ${stuck[*]}"
  exit 1
fi
