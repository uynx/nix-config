{
  # Everything about the AI CLIs that is the same on both platforms: the shared
  # skills/AGENTS.md wiring, and `update-ai-clis` — the one entry point that
  # maintains every tool. How the tools themselves arrive differs per platform:
  # linux.nix pins them, darwin.nix brews them.
  flake.homeModules.aiTools =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      home = config.home.homeDirectory;
      inherit (pkgs.stdenv.hostPlatform) isLinux;

      skillsDir = "${home}/dotfiles/skills";
      sharedSkills =
        if builtins.pathExists skillsDir then
          builtins.attrNames (
            lib.filterAttrs (n: t: t == "directory" && !lib.hasPrefix "." n) (builtins.readDir skillsDir)
          )
        else
          [ ];

      update-ai-clis = pkgs.writeShellApplication {
        name = "update-ai-clis";
        runtimeInputs =
          with pkgs;
          [ coreutils ] # timeout, bounding hermes below
          # Everything else this script runs is Linux-only now — macOS takes its
          # whole AI toolchain from Homebrew.
          ++ lib.optionals isLinux [
            curl
            nix
            gnused
            jq
            nodejs
            uv
            git # hermes' installer clones its own repo

            # t3 pulls node-pty, which has no linux-arm64 prebuild and compiles on
            # install. Without these npm dies on `c++: not found`.
            python3
            gnumake
            gcc
            binutils
          ];
        text = ''
          # Home Manager activation calls this with --missing-only to make a
          # fresh machine self-populate. $HOME is /homeless-shelter there, so
          # every path below is the literal home instead.
          missingOnly=
          if [ "''${1:-}" = --missing-only ]; then
            missingOnly=1
          fi
          export PATH="$PATH:${home}/.local/bin${lib.optionalString isLinux ":${home}/.hermes/bin"}"

          # hermes' installer pulls unicode-animations, whose postinstall writes
          # a spinner demo to /dev/tty and never exits unless CI is set.
          export CI=1

          # Counts pins and tools this run could not reach, for the summary at
          # the end. Declared out here so it spans the Linux-only pin section
          # and the rolling installs below, which both feed it.
          skipped=0

          ${lib.optionalString isLinux ''
            file=${home}/nix-config/modules/apps/ai-tools/pins.json

            # bump <name> <latest-version> <aarch64-url> <x86_64-url>
            # Both architectures are pinned from whichever machine runs this, so
            # the other one can rebuild without a prefetch of its own. One
            # unreachable vendor must not cost every later pin. Under errexit a
            # failed prefetch would abort the whole run, so each step reports and
            # returns instead, and callers use `try_bump`.
            bump() {
              name=$1 latest=$2 url_arm=$3 url_x86=$4

              # An empty or null version means the lookup failed, and pasting it
              # into the URL would prefetch a 404 page rather than the artifact.
              if [ -z "$latest" ] || [ "$latest" = null ]; then
                printf '%-12s SKIPPED (lookup failed)\n' "$name"
                return 1
              fi

              # Refuse to invent a key: `.[$n] = …` would happily create one, so a
              # typo'd name would add a pin nothing reads instead of failing.
              current=$(jq -r --arg n "$name" '.[$n].version // ""' "$file")
              if [ -z "$current" ]; then
                echo "$name: no such pin in $file" >&2
                return 1
              fi
              if [ "$current" = "$latest" ]; then
                printf '%-12s %s (up to date)\n' "$name" "$current"
                return 0
              fi

              prefetch() {
                nix hash convert --hash-algo sha256 --to sri \
                  "$(nix-prefetch-url --type sha256 "$1")"
              }

              # Both or neither: a pin carrying one new hash beside one stale one
              # would build a mismatched binary on the machine that was skipped.
              # `||` short-circuits, so a failed aarch64 fetch skips the x86 one.
              if ! hash_arm=$(prefetch "$url_arm") || ! hash_x86=$(prefetch "$url_x86"); then
                printf '%-12s SKIPPED (prefetch failed)\n' "$name"
                return 1
              fi

              # Written via mktemp and mv, so a pin is either fully updated or
              # untouched. That is what makes skipping one safe to continue past.
              tmp=$(mktemp)
              jq --arg n "$name" --arg v "$latest" --arg a "$hash_arm" --arg x "$hash_x86" \
                '.[$n] = { version: $v, hash: { "aarch64-linux": $a, "x86_64-linux": $x } }' \
                "$file" >"$tmp"
              mv "$tmp" "$file"

              printf '%-12s %s -> %s\n' "$name" "$current" "$latest"
            }

            try_bump() {
              bump "$@" || skipped=$((skipped + 1))
            }

            # Every lookup below is timed out: curl's default connect timeout
            # is 300 s, so one blocked vendor otherwise freezes the whole run
            # with no output at all.
            if [ -z "$missingOnly" ]; then
            claude=$(curl -fsSL --connect-timeout 10 --max-time 30 https://downloads.claude.ai/claude-code-releases/latest | tr -d '[:space:]' || true)
            try_bump claude-code "$claude" \
              "https://downloads.claude.ai/claude-code-releases/$claude/linux-arm64/claude" \
              "https://downloads.claude.ai/claude-code-releases/$claude/linux-x64/claude"

            # npm, not the GitHub feed — the GitHub tarball omits the code-mode
            # host binary, so the feed has to match the source we actually fetch.
            codex=$(curl -fsSL --connect-timeout 10 --max-time 30 https://registry.npmjs.org/@openai/codex/latest | jq -r '.version' || true)
            try_bump codex "$codex" \
              "https://registry.npmjs.org/@openai/codex/-/codex-$codex-linux-arm64.tgz" \
              "https://registry.npmjs.org/@openai/codex/-/codex-$codex-linux-x64.tgz"

            grok=$(curl -fsSL --connect-timeout 10 --max-time 30 https://x.ai/cli/stable | tr -d '[:space:]' || true)
            try_bump grok "$grok" "https://x.ai/cli/grok-$grok-linux-aarch64" \
              "https://x.ai/cli/grok-$grok-linux-x86_64"

            kimi=$(curl -fsSL --connect-timeout 10 --max-time 30 https://code.kimi.com/kimi-code/latest | tr -d '[:space:]' || true)
            try_bump kimi "$kimi" \
              "https://code.kimi.com/kimi-code/binaries/$kimi/kimi-code-linux-arm64" \
              "https://code.kimi.com/kimi-code/binaries/$kimi/kimi-code-linux-x64"

            opencode=$(curl -fsSL --connect-timeout 10 --max-time 30 https://api.github.com/repos/sst/opencode/releases/latest \
              | jq -r '.tag_name | ltrimstr("v")' || true)
            try_bump opencode "$opencode" \
              "https://github.com/sst/opencode/releases/download/v$opencode/opencode-linux-arm64.tar.gz" \
              "https://github.com/sst/opencode/releases/download/v$opencode/opencode-linux-x64.tar.gz"

            cursor=$(curl -fsSL --connect-timeout 10 --max-time 30 --compressed https://cursor.com/install | sed -n 's|.*downloads\.cursor\.com/lab/\([^/]*\)/.*|\1|p' | head -1 || true)
            try_bump cursor-agent "$cursor" \
              "https://downloads.cursor.com/lab/$cursor/linux/arm64/agent-cli-package.tar.gz" \
              "https://downloads.cursor.com/lab/$cursor/linux/x64/agent-cli-package.tar.gz"

            echo
            echo 'rolling (takes effect now, no rebuild):'
            fi
          ''}

          get_ver() {
            bin=$1
            case "$bin" in
              agy) agy --version 2>/dev/null | head -1 ;;
              openclaw) openclaw --version 2>/dev/null | head -1 | sed 's/OpenClaw //' ;;
              t3) t3 --version 2>/dev/null | head -1 | sed 's/t3 //' ;;
              qwen) (qwen --version 2>/dev/null || qwen-code --version 2>/dev/null) | head -1 ;;
              # Drop the local-commit suffix. hermes carries local modifications
              # as a commit and `hermes update` resets them away, so comparing
              # the raw strings reported a version change on every single run.
              hermes) hermes --version 2>/dev/null | head -1 | sed -e 's/Hermes Agent //' -e 's/ · local .*//' ;;
              *) echo "" ;;
            esac
          }

          # Keep stderr: a swallowed failure here reads exactly like success,
          # which is how this once installed nothing at all.
          roll() {
            name=$1
            shift
            if [ -n "$missingOnly" ] && command -v "$name" >/dev/null 2>&1; then
              return
            fi
            # `|| true`: errexit plus pipefail would abort the whole run when a
            # tool is present but its --version fails.
            before=$(get_ver "$name" || true)
            if err=$("$@" 2>&1); then
              after=$(get_ver "$name" || true)
              if [ -n "$before" ] && [ -n "$after" ] && [ "$before" = "$after" ]; then
                printf '  %-12s %s (up to date)\n' "$name" "$after"
              elif [ -n "$before" ] && [ -n "$after" ]; then
                printf '  %-12s %s -> %s\n' "$name" "$before" "$after"
              elif [ -n "$after" ]; then
                printf '  %-12s %s\n' "$name" "$after"
              else
                printf '  %-12s ok\n' "$name"
              fi
            else
              printf '  %-12s FAILED\n' "$name"
              printf '%s\n' "$err" | tail -3 | sed 's/^/               /'
              skipped=$((skipped + 1))
            fi
          }

          ${lib.optionalString isLinux ''
            # On Linux, agy is maintained by its self-updater / vendor script.
            # On macOS, the `antigravity-cli` Homebrew cask manages it.
            if command -v agy >/dev/null 2>&1; then
              roll agy    agy update
            else
              roll agy    sh -c 'curl -fsSL --connect-timeout 10 --max-time 30 https://antigravity.google/cli/install.sh | bash'
            fi
          ''}
          ${lib.optionalString (!isLinux) ''
            if [ -f /opt/homebrew/bin/agy ] && [ ! -L /opt/homebrew/bin/agy ]; then
              rm -f /opt/homebrew/bin/agy
            fi
          ''}
          ${lib.optionalString isLinux ''
            # macOS gets all three from Homebrew instead: `openclaw-cli` and
            # `qwen-code` as formulas, t3 as the `t3-code` desktop app.
            roll openclaw npm install -g --prefix "${home}/.local" openclaw
            roll t3       npm install -g --prefix "${home}/.local" t3
            roll qwen     npm install -g --prefix "${home}/.local" @qwen-code/qwen-code
          ''}
          ${lib.optionalString isLinux ''
            # On Linux, hermes is maintained by its vendor installer / self-updater.
            # On macOS, the `hermes-agent` Homebrew formula manages it.
            if ! command -v hermes >/dev/null 2>&1; then
              # First install builds several npm workspaces and took 20 minutes
              # here. roll() buffers output until the command returns, so
              # without this line the run is indistinguishable from a hang --
              # which is what it was mistaken for. The installer bounds its own
              # npm calls and nothing else, so the outer bound is still ours.
              printf '  %-12s installing, first run takes many minutes...\n' hermes
              roll hermes timeout 2400 sh -c 'curl -fsSL --connect-timeout 10 --max-time 30 https://hermes-agent.nousresearch.com/install.sh \
                | bash -s -- --non-interactive --hermes-home ${home}/.hermes'
            elif [ -z "$missingOnly" ]; then
              ver=$(get_ver hermes || true)
              # hermes does its own network I/O and bounds none of it, so a
              # stalled lookup parks the whole run here with nothing printed.
              # Only 124 means the bound fired: any other non-zero exit is
              # hermes answering, and the grep below still decides what it meant.
              rc=0
              check=$(timeout 60 hermes update --check 2>&1) || rc=$?
              if [ "$rc" -eq 124 ]; then
                printf '  %-12s SKIPPED (update check timed out)\n' hermes
                skipped=$((skipped + 1))
              elif printf '%s' "$check" | grep -q 'Already up to date'; then
                printf '  %-12s %s (up to date)\n' hermes "$ver"
              else
                roll hermes timeout 300 hermes update --yes
              fi
            fi
          ''}

          # Exits 0 even with skips. Every pin is written atomically, so a
          # skipped one leaves the file consistent and there is no reason to
          # stop `update` from relocking the flake afterwards. A hard crash
          # still exits non-zero under errexit, which is what the caller's
          # `; or return 1` is actually for.
          if [ "$skipped" -gt 0 ]; then
            echo
            echo "$skipped not updated this run — rerun to retry."
          fi
        '';
      };
    in
    {
      home.packages = [ update-ai-clis ];

      # Registered rather than named by `update` itself, so a host without the
      # AI bundle does not get an `update` that calls a missing command.
      shellHooks.update = [ "update-ai-clis" ];

      home.sessionVariables = {
        # Without these a self-updater fetches a newer build into ~/.local and
        # the pin stops being what actually runs.
        DISABLE_AUTOUPDATER = "1";
        GROK_DISABLE_AUTOUPDATER = "1";
        OPENCODE_DISABLE_AUTOUPDATE = "1";

        # Appended, not home.sessionPath: that prepends, letting a self-installed
        # binary here silently outrank its pinned version.
        PATH = "$PATH:${home}/.local/bin";
      }
      # hermes' browser tool otherwise makes Playwright fetch its own Ubuntu
      # Chromium, which will not run unpatched here. Reuses whatever browser the
      # host already builds rather than adding 3.2 GB of pkgs.chromium — so it
      # only applies on a host that took the `web` bundle. The macOS half is in
      # `apps/brave-origin/darwin.nix`: a cask leaves nothing in `config` to
      # test here.
      // lib.optionalAttrs config.programs.chromium.enable {
        AGENT_BROWSER_EXECUTABLE_PATH = "${config.programs.chromium.package}/bin/brave-origin";
      };

      # One set of skills and one AGENTS.md, wired to wherever each CLI expects
      # to find them. Deliberately outside the store: the memory workflow
      # rewrites both constantly and a read-only store symlink would break it.
      #
      # Cursor is the one tool that gets skills but not instructions: its user
      # rules are .mdc files with frontmatter, which a plain AGENTS.md is not.
      home.file =
        lib.genAttrs
          [
            ".agents/AGENTS.md"
            ".claude/CLAUDE.md"
            ".codex/AGENTS.md"
            ".cursorrules"
            ".cursor/rules/system.mdc"
            ".gemini/AGENTS.md" # agy, whose state dir is Antigravity's
            ".grok/AGENTS.md"
            ".kimi-code/AGENTS.md"
            ".openclaw/AGENTS.md"
            ".qwen/QWEN.md"
            ".config/opencode/AGENTS.md"
          ]
          (_: {
            source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/AGENTS.md";
          })
        //
          lib.genAttrs
            [
              ".agents/skills"
              ".claude/skills"
              ".cursor/skills"
              ".gemini/skills"
              ".grok/skills"
              ".kimi-code/skills"
              ".openclaw/skills"
              ".qwen/skills"
              ".config/opencode/skills"
            ]
            (_: {
              source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/skills";
            })
        # codex is the exception: ~/.codex/skills already holds its own vendor
        # skills under .system, and a directory symlink would displace them. So
        # each skill is linked individually alongside them. Read impurely
        # because the source is a working copy, not a flake input; a machine
        # without the dotfiles clone simply gets none.
        // lib.listToAttrs (
          map (skill: {
            name = ".codex/skills/${skill}";
            value.source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/skills/${skill}";
          }) sharedSkills
        )
        // lib.optionalAttrs isLinux {
          ".local/share/applications/t3.desktop".text = ''
            [Desktop Entry]
            Type=Application
            Name=T3 Code
            GenericName=AI coding workspace
            Exec=${home}/.local/bin/t3
            Terminal=false
            Categories=Development;
          '';
        };

      # Each hermes update snapshots its whole state dir, and that state dir
      # holds .env and auth.json — so every run leaves another plaintext copy of
      # its credentials lying around indefinitely. Keep a week for rollback.
      systemd.user.tmpfiles.rules = lib.optionals isLinux [
        "e ${home}/.hermes/state-snapshots - - - 7d"
      ];
      # hermes finds extra skills through a config key rather than a path, and
      # writes that config itself, so it cannot be a store symlink. Appending is
      # safe only while it has no `skills:` block of its own; if it grows one,
      # the key has to be merged in by hand instead.
      home.activation.hermesSharedSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        cfg="${home}/.hermes/config.yaml"
        if [ -f "$cfg" ] && ! grep -qE '^skills:|external_dirs' "$cfg"; then
          printf '\nskills:\n  external_dirs:\n    - %s\n' "${home}/.agents/skills" >>"$cfg"
        fi
      '';

      # On Linux agy, openclaw, t3, qwen and hermes cannot be pinned, so a fresh
      # machine would otherwise have most but not all of the CLIs. This installs
      # only what is absent, making every later rebuild a no-op, and never fails
      # the activation — an offline rebuild must still succeed.
      home.activation.installRollingAiClis = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${update-ai-clis}/bin/update-ai-clis --missing-only || true
      '';
    };
}
