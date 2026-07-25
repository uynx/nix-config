{
  # Vendor CLIs with no nixpkgs derivation. Installed imperatively on first
  # activation, guarded so a rebuild is a no-op once present.
  flake.homeModules.aiTools =
    { config, pkgs, lib, ... }:
    let
      home = "/home/uynx";
      H = "${pkgs.hyprland}/bin/hyprctl";
      J = "${pkgs.jq}/bin/jq";

      # Electron leaves a headless process behind if only the window is closed,
      # so drop any stale one before launching.
      antigravity-launcher = pkgs.writeShellScriptBin "antigravity-launcher" ''
        set -eu

        HAS_WINDOW=$(${H} clients -j 2>/dev/null | ${J} -r '.[] | select(((.class // "") | ascii_downcase) == "antigravity") | .pid' 2>/dev/null || true)
        if [ -z "$HAS_WINDOW" ]; then
          ${pkgs.procps}/bin/pkill -f "/.local/share/antigravity/antigravity" 2>/dev/null || true
          sleep 0.1
        fi
        exec ${home}/.local/share/antigravity/antigravity "$@"
      '';
    in
    {
      home.packages = with pkgs; [
        wl-clipboard
        wtype
        sox
        antigravity-launcher
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

      home.file = {
        ".agents/skills".source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/skills";
        ".agents/AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/AGENTS.md";
        ".local/bin/dictate".source =
          config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/scripts/maintenance/dictate";
      };

      home.activation.installAgy = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -f "${home}/.local/bin/agy" ]; then
          ${pkgs.curl}/bin/curl -fsSL https://antigravity.google.com/install.sh | ${pkgs.bash}/bin/bash || true
        fi
      '';

      # Modern Copilot plugins keep the token in auth.db; avante.nvim wants hosts.json.
      home.activation.copilotBridge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        AUTH_DB="${home}/.config/github-copilot/auth.db"
        HOSTS_JSON="${home}/.config/github-copilot/hosts.json"
        if [ -f "$AUTH_DB" ]; then
          TOKEN=$(${pkgs.sqlite}/bin/sqlite3 "$AUTH_DB" "SELECT cast(token_ciphertext as text) FROM oauth_tokens LIMIT 1;" 2>/dev/null)
          if [ -n "$TOKEN" ]; then
            mkdir -p "$(dirname "$HOSTS_JSON")"
            printf '{\n  "github.com": {\n    "oauth_token": "%s"\n  }\n}\n' "$TOKEN" >"$HOSTS_JSON"
            chmod 600 "$HOSTS_JSON"
          fi
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

      home.activation.installWhisperCpp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -f "${home}/.local/bin/whisper-cli" ]; then
          mkdir -p "${home}/.local/share/whisper.cpp" "${home}/.local/bin"
          export PATH="${pkgs.gzip}/bin:${pkgs.gnutar}/bin:${pkgs.curl}/bin:${pkgs.coreutils}/bin:$PATH"
          curl -fsSL https://github.com/ggml-org/whisper.cpp/releases/download/v1.9.1/whisper-bin-ubuntu-arm64.tar.gz | tar -xz -C "${home}/.local/share/whisper.cpp" --strip-components=1
          ln -sf "${home}/.local/share/whisper.cpp/whisper-cli" "${home}/.local/bin/whisper-cli"
        fi
      '';
    };
}
