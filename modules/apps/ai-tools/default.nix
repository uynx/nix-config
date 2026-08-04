{
  # `update-ai-clis` is the only entry point for every AI CLI. Tools shipping an
  # aarch64-linux artifact are pinned in _ai-clis.nix and the script rewrites
  # the pin (needs `reb` after); the rest get their vendor installer run into
  # ~/.local/bin.
  flake.homeModules.aiTools =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      home = "/home/uynx";

      aiClis = pkgs.callPackage ./_ai-clis.nix { };

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
        runtimeInputs = with pkgs; [
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
          file=${home}/nixos-config/modules/apps/ai-tools/_ai-clis.nix

          # Home Manager activation calls this with --missing-only to make a
          # fresh machine self-populate. $HOME is /homeless-shelter there, so
          # every path below is the literal home instead.
          missingOnly=
          if [ "''${1:-}" = --missing-only ]; then
            missingOnly=1
          fi
          export PATH="$PATH:${home}/.local/bin:${home}/.hermes/bin"

          # bump <name> <latest-version> <download-url>
          bump() {
            name=$1 latest=$2 url=$3
            current=$(sed -n "s/^    $name = { version = \"\([^\"]*\)\".*/\1/p" "$file")
            if [ "$current" = "$latest" ]; then
              printf '%-12s %s (up to date)\n' "$name" "$current"
              return
            fi
            hash=$(nix hash convert --hash-algo sha256 --to sri \
              "$(nix-prefetch-url --type sha256 "$url")")
            sed -i "s|^    $name = { version = \"[^\"]*\"; hash = \"[^\"]*\"; };|    $name = { version = \"$latest\"; hash = \"$hash\"; };|" "$file"
            printf '%-12s %s -> %s\n' "$name" "$current" "$latest"
          }

          if [ -z "$missingOnly" ]; then
          claude=$(curl -fsSL https://downloads.claude.ai/claude-code-releases/latest | tr -d '[:space:]')
          bump claude-code "$claude" \
            "https://downloads.claude.ai/claude-code-releases/$claude/linux-arm64/claude"

          codex=$(curl -fsSL https://api.github.com/repos/openai/codex/releases/latest \
            | jq -r '.tag_name | ltrimstr("rust-v")')
          bump codex "$codex" \
            "https://github.com/openai/codex/releases/download/rust-v$codex/codex-aarch64-unknown-linux-musl.tar.gz"

          grok=$(curl -fsSL https://x.ai/cli/stable | tr -d '[:space:]')
          bump grok "$grok" "https://x.ai/cli/grok-$grok-linux-aarch64"

          kimi=$(curl -fsSL https://code.kimi.com/kimi-code/latest | tr -d '[:space:]')
          bump kimi "$kimi" \
            "https://code.kimi.com/kimi-code/binaries/$kimi/kimi-code-linux-arm64"

          opencode=$(curl -fsSL https://api.github.com/repos/sst/opencode/releases/latest \
            | jq -r '.tag_name | ltrimstr("v")')
          bump opencode "$opencode" \
            "https://github.com/sst/opencode/releases/download/v$opencode/opencode-linux-arm64.tar.gz"

          cursor=$(curl -fsSL https://cursor.com/install | sed -n 's|.*downloads\.cursor\.com/lab/\([^/]*\)/.*|\1|p' | head -1)
          bump cursor-agent "$cursor" \
            "https://downloads.cursor.com/lab/$cursor/linux/arm64/agent-cli-package.tar.gz"

          echo
          echo 'rolling (takes effect now, no rebuild):'
          fi

          # Keep stderr: a swallowed failure here reads exactly like success,
          # which is how this once installed nothing at all.
          roll() {
            name=$1
            shift
            if [ -n "$missingOnly" ] && command -v "$name" >/dev/null 2>&1; then
              return
            fi
            printf '  %-12s ' "$name"
            if err=$("$@" 2>&1); then
              echo ok
            else
              echo FAILED
              printf '%s\n' "$err" | tail -3 | sed 's/^/               /'
            fi
          }

          roll agy      agy update
          roll openclaw npm install -g --prefix "${home}/.local" openclaw
          roll t3       npm install -g --prefix "${home}/.local" t3
          roll qwen     npm install -g --prefix "${home}/.local" @qwen-code/qwen-code
          # Vendor installer, not `uv tool install`: upstream marks every pypi
          # install unsupported. It brings its own node and uv under ~/.hermes,
          # so it costs minutes and is only worth running when hermes is absent.
          # Afterwards `hermes update` maintains itself, and `--check` settles it
          # in about a second. --check always exits 0, hence the string match; if
          # upstream reworded it we would merely go back to updating every run.
          if ! command -v hermes >/dev/null 2>&1; then
            roll hermes sh -c 'curl -fsSL https://hermes-agent.nousresearch.com/install.sh \
              | bash -s -- --non-interactive --hermes-home ${home}/.hermes'
          elif [ -z "$missingOnly" ]; then
            if hermes update --check 2>&1 | grep -q 'Already up to date'; then
              printf '  %-12s %s\n' hermes 'ok (up to date)'
            else
              roll hermes hermes update --yes
            fi
          fi
        '';
      };

      # Pinned rather than fetched on first run, so dictation works offline.
      whisperModel = pkgs.fetchurl {
        url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";
        hash = "sha256-oDd5yG3zMjB19eeWyyzlAp8A7Ihp7uP9+4l6/jbG0AI=";
      };

      # Push-to-talk dictation: first press records, second transcribes and
      # types the result.
      dictate = pkgs.writeShellApplication {
        name = "dictate";
        runtimeInputs = with pkgs; [
          whisper-cpp
          wl-clipboard
          wtype
          libnotify
          pipewire
          gnused
          coreutils
        ];
        text = ''
          recordPid=/tmp/whisper-dictate.pid
          audio=/tmp/whisper-dictate.wav
          model=${whisperModel}

          if [ -f "$recordPid" ]; then
            pid=$(cat "$recordPid")
            rm -f "$recordPid"
            kill "$pid" 2>/dev/null || true
            sleep 0.2

            [ -f "$audio" ] || exit 0
            notify-send "Whisper Dictation" "Transcribing..." -i microphone-sensitivity-high-symbolic || true

            # writeShellApplication sets errexit and pipefail, so without
            # `|| true` the "no speech" branch below can never run.
            text=$(whisper-cli -m "$model" -f "$audio" --no-timestamps -nt 2>/dev/null \
              | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
            rm -f "$audio"

            if [ -n "$text" ]; then
              printf '%s' "$text" | wl-copy
              wtype "$text" 2>/dev/null || true
              notify-send "Dictation" "$text" -i edit-paste-symbolic || true
            else
              notify-send "Dictation" "No speech detected" -i dialog-warning-symbolic || true
            fi
          else
            rm -f "$audio"
            pw-record --format=s16 --rate=16000 --channels=1 "$audio" >/dev/null 2>&1 &
            echo $! > "$recordPid"
            notify-send "Whisper Dictation" "Recording... Press shortcut again to finish." -i media-record-symbolic || true
          fi
        '';
      };
    in
    {
      home.packages = with pkgs; [
        wtype
        sox
        dictate
        update-ai-clis

        aiClis.claude-code
        aiClis.codex
        aiClis.grok
        aiClis.kimi
        aiClis.opencode
        aiClis.cursor-agent
      ];

      home.sessionVariables = {
        # Without these a self-updater fetches a newer build into ~/.local and
        # the pin stops being what actually runs.
        DISABLE_AUTOUPDATER = "1";
        GROK_DISABLE_AUTOUPDATER = "1";
        OPENCODE_DISABLE_AUTOUPDATE = "1";
        AGY_CLI_DISABLE_AUTO_UPDATE = "1";

        # Appended, not home.sessionPath: that prepends, letting a self-installed
        # binary here silently outrank its pinned version.
        PATH = "$PATH:${home}/.local/bin";

        # hermes' browser tool otherwise makes Playwright fetch its own Ubuntu
        # Chromium, which will not run unpatched here. Reuses the brave-origin
        # already built for this host rather than adding 3.2 GB of pkgs.chromium.
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
            ".grok/AGENTS.md"
            ".kimi-code/AGENTS.md"
            ".openclaw/AGENTS.md"
            ".qwen/QWEN.md"
            ".config/opencode/AGENTS.md"
          ]
          (_: { source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/AGENTS.md"; })
        // lib.genAttrs
          [
            ".agents/skills"
            ".claude/skills"
            ".grok/skills"
            ".cursor/skills"
            ".kimi-code/skills"
            ".openclaw/skills"
            ".qwen/skills"
            ".config/opencode/skills"
          ]
          (_: { source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/skills"; })
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
        );

      home.activation.createRequiredDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p \
          "${home}/ai_memory/topics" \
          "${home}/ai_memory/journal" \
          "${home}/dotfiles" \
          "${home}/nixos-config"
      '';

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

      # agy, openclaw, t3 and hermes cannot be pinned, so a fresh machine would
      # otherwise have six of the ten CLIs. This installs only what is absent,
      # making every later rebuild a no-op, and never fails the activation —
      # an offline rebuild must still succeed.
      home.activation.installRollingAiClis = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${update-ai-clis}/bin/update-ai-clis --missing-only || true
      '';
    };
}
