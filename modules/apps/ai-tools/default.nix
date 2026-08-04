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

      update-ai-clis = pkgs.writeShellApplication {
        name = "update-ai-clis";
        runtimeInputs = with pkgs; [
          curl
          nix
          gnused
          jq
          nodejs
          uv

          # t3 pulls node-pty, which has no linux-arm64 prebuild and compiles on
          # install. Without these npm dies on `c++: not found`.
          python3
          gnumake
          gcc
          binutils
        ];
        text = ''
          file=${home}/nixos-config/modules/apps/ai-tools/_ai-clis.nix

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

          claude=$(curl -fsSL https://downloads.claude.ai/claude-code-releases/latest | tr -d '[:space:]')
          bump claude-code "$claude" \
            "https://downloads.claude.ai/claude-code-releases/$claude/linux-arm64/claude"

          codex=$(curl -fsSL https://api.github.com/repos/openai/codex/releases/latest \
            | jq -r '.tag_name | ltrimstr("rust-v")')
          bump codex "$codex" \
            "https://github.com/openai/codex/releases/download/rust-v$codex/codex-aarch64-unknown-linux-musl.tar.gz"

          grok=$(curl -fsSL https://x.ai/cli/stable | tr -d '[:space:]')
          bump grok "$grok" "https://x.ai/cli/grok-$grok-linux-aarch64"

          kimi=$(curl -fsSL https://api.github.com/repos/MoonshotAI/kimi-cli/releases/latest \
            | jq -r .tag_name)
          bump kimi "$kimi" \
            "https://github.com/MoonshotAI/kimi-cli/releases/download/$kimi/kimi-$kimi-aarch64-unknown-linux-gnu.tar.gz"

          opencode=$(curl -fsSL https://api.github.com/repos/sst/opencode/releases/latest \
            | jq -r '.tag_name | ltrimstr("v")')
          bump opencode "$opencode" \
            "https://github.com/sst/opencode/releases/download/v$opencode/opencode-linux-arm64.tar.gz"

          cursor=$(curl -fsSL https://cursor.com/install | sed -n 's|.*downloads\.cursor\.com/lab/\([^/]*\)/.*|\1|p' | head -1)
          bump cursor-agent "$cursor" \
            "https://downloads.cursor.com/lab/$cursor/linux/arm64/agent-cli-package.tar.gz"

          echo
          echo 'rolling (takes effect now, no rebuild):'

          # Keep stderr: a swallowed failure here reads exactly like success,
          # which is how this once installed nothing at all.
          roll() {
            printf '  %-12s ' "$1"
            shift
            if err=$("$@" 2>&1); then
              echo ok
            else
              echo FAILED
              printf '%s\n' "$err" | tail -3 | sed 's/^/               /'
            fi
          }

          roll agy      agy update
          roll openclaw npm install -g --prefix "$HOME/.local" openclaw
          roll t3       npm install -g --prefix "$HOME/.local" t3
          roll hermes   uv tool install --upgrade hermes-agent
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
      };

      # Deliberately outside the store: the memory workflow rewrites these
      # constantly and a read-only store symlink would break it.
      home.file = {
        ".agents/skills".source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/skills";
        ".agents/AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/AGENTS.md";
      };

      home.activation.createRequiredDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p \
          "${home}/ai_memory/topics" \
          "${home}/ai_memory/journal" \
          "${home}/dotfiles" \
          "${home}/nixos-config"
      '';
    };
}
