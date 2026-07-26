{
  # Vendor CLIs with no nixpkgs derivation. Installed imperatively on first
  # activation, guarded so a rebuild is a no-op once present.
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

      # Electron leaves a headless process behind if only the window is closed,
      # so drop any stale one before launching. Was querying hyprctl, which has
      # not existed since the move to niri — so the stale process was never
      # actually cleaned up.
      antigravity-launcher = pkgs.writeShellScriptBin "antigravity-launcher" ''
        set -eu

        HAS_WINDOW=$(${N} msg -j windows 2>/dev/null | ${J} -r '.[] | select(((.app_id // "") | ascii_downcase) == "antigravity") | .pid' 2>/dev/null || true)
        if [ -z "$HAS_WINDOW" ]; then
          ${pkgs.procps}/bin/pkill -f "/.local/share/antigravity/antigravity" 2>/dev/null || true
          sleep 0.1
        fi
        exec ${home}/.local/share/antigravity/antigravity "$@"
      '';

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
        antigravity-launcher
        dictate
      ];

      xdg.desktopEntries.antigravity = {
        name = "Antigravity";
        genericName = "Text Editor";
        comment = "Antigravity AI Code Editor";
        exec = "${antigravity-launcher}/bin/antigravity-launcher %U";
        icon = "antigravity";
        type = "Application";
        categories = [
          "Development"
          "IDE"
        ];
      };

      home.sessionPath = [
        "${home}/.grok/bin"
        "${home}/.local/bin"
      ];

      # The only things left pointing outside the store, deliberately: the agent
      # skills and AGENTS.md are rewritten by the memory workflow constantly, so
      # a read-only store symlink would break it. Reproducible via their own git
      # repo, just not pinned to a system generation.
      home.file = {
        ".agents/skills".source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/skills";
        ".agents/AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/AGENTS.md";
      };

      home.activation.installAgy = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -f "${home}/.local/bin/agy" ]; then
          ${pkgs.curl}/bin/curl -fsSL https://antigravity.google.com/install.sh | ${pkgs.bash}/bin/bash || true
        fi
      '';

      home.activation.createRequiredDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p \
          "${home}/ai_memory/concepts" \
          "${home}/ai_memory/journal" \
          "${home}/dotfiles" \
          "${home}/nixos-config" \
          "${home}/.local/share/antigravity"
      '';

      home.activation.installGrok = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -f "${home}/.grok/bin/grok" ]; then
          ${pkgs.curl}/bin/curl -fsSL https://x.ai/cli/install.sh | ${pkgs.bash}/bin/bash || true
        fi
      '';

      home.activation.installCodex = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -f "${home}/.local/bin/codex" ]; then
          ${pkgs.nodejs}/bin/npm install -g --prefix ${home}/.local @openai/codex || true
        fi
      '';

      home.activation.installClaude = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -f "${home}/.local/bin/claude" ]; then
          ${pkgs.curl}/bin/curl -fsSL https://claude.ai/install.sh | ${pkgs.bash}/bin/bash || true
        fi
      '';

    };
}
