{
  # codex and grok are pinned derivations in _ai-clis.nix, bumped by
  # `update-ai-clis`. `agy` and `claude` are deliberately NOT pinned: both ship
  # their own updater and reinstall into ~/.local, so a pin only loses a race.
  flake.homeModules.aiTools =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      home = "/home/uynx";
      N = "${lib.getExe pkgs.niri}";
      J = "${lib.getExe pkgs.jq}";

      aiClis = pkgs.callPackage ./_ai-clis.nix { };

      # Bumps the pins in _ai-clis.nix from each vendor's own release feed, so a
      # rebuild ships today's CLI without dragging the rest of nixpkgs forward.
      # Run by the `update` alias alongside update-brave-origin.
      #
      # Each tool needs two things: where to ask for the latest version, and how
      # to build the download URL from it. Adding a tool means one more `bump`
      # call here plus a matching entry in _ai-clis.nix.
      update-ai-clis = pkgs.writeShellApplication {
        name = "update-ai-clis";
        runtimeInputs = with pkgs; [
          curl
          nix
          gnused
          jq
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

          codex=$(curl -fsSL https://api.github.com/repos/openai/codex/releases/latest \
            | jq -r '.tag_name | ltrimstr("rust-v")')
          bump codex "$codex" \
            "https://github.com/openai/codex/releases/download/rust-v$codex/codex-aarch64-unknown-linux-musl.tar.gz"

          grok=$(curl -fsSL https://x.ai/cli/stable | tr -d '[:space:]')
          bump grok "$grok" "https://x.ai/cli/grok-$grok-linux-aarch64"
        '';
      };

      # 140 MB, pinned by hash instead of curl'd on first run into
      # ~/.local/share, so dictation works on a fresh machine with no network.
      whisperModel = pkgs.fetchurl {
        url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";
        hash = "sha256-oDd5yG3zMjB19eeWyyzlAp8A7Ihp7uP9+4l6/jbG0AI=";
      };

      # Push-to-talk dictation: first press records, second transcribes and
      # types the result. Was a loose script in ~/dotfiles pointing at an
      # imperatively-installed whisper binary; both are now store paths.
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

            # writeShellApplication turns on errexit and pipefail, so without the
            # `|| true` a non-zero whisper-cli aborts here and the "no speech"
            # branch below can never run.
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
        wl-clipboard
        wtype
        sox
        dictate
        update-ai-clis

        # Listed one by one rather than attrValues: callPackage wraps the set
        # with `override` helpers, which are not packages.
        aiClis.codex
        aiClis.grok
      ];

      # PREPENDED, so anything here shadows a packaged binary of the same name.
      # That is intended for `agy` and `claude`, which own their own updates;
      # a stray npm codex hid the pinned one here for a week (fixed 2026-08-03).
      home.sessionPath = [ "${home}/.local/bin" ];

      # The only things left pointing outside the store, deliberately: the agent
      # skills and AGENTS.md are rewritten by the memory workflow constantly, so
      # a read-only store symlink would break it. Reproducible via their own git
      # repo, just not pinned to a system generation.
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
