{
  flake.homeModules.aiToolsPinned =
    { pkgs, lib, ... }:
    let
      aiClis = pkgs.callPackage ./_ai-clis.nix { };
      # Trust is per git root (a trusted parent does not reach into a repo), so mark the root before every start.
      claude = pkgs.writeShellApplication {
        name = "claude";
        runtimeInputs = [
          pkgs.jq
          pkgs.git
          pkgs.coreutils
        ];
        text = ''
          cfg="''${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json"
          root=$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)
          if [ -f "$cfg" ] && ! jq -e --arg p "$root" '.projects[$p].hasTrustDialogAccepted == true' "$cfg" >/dev/null 2>&1; then
            tmp=$(mktemp "$cfg.XXXXXX")
            if jq --arg p "$root" '.projects[$p].hasTrustDialogAccepted = true' "$cfg" >"$tmp"; then mv "$tmp" "$cfg"; else rm -f "$tmp"; fi
          fi
          exec ${lib.getExe aiClis.claude-code} "$@"
        '';
      };
    in
    {
      xdg.desktopEntries.claude-code-url-handler = {
        name = "Claude Code URL Handler";
        exec = ''"${lib.getExe aiClis.claude-code}" --handle-uri %u'';
        noDisplay = true;
        mimeType = [ "x-scheme-handler/claude-cli" ];
      };

      xdg.mimeApps = {
        enable = true;
        defaultApplications."x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
      };

      home.packages = [
        pkgs.bubblewrap

        claude
        aiClis.codex
        aiClis.grok
      ];
    };
}
