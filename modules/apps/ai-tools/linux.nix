{
  flake.homeModules.aiToolsPinned =
    { pkgs, lib, ... }:
    let
      aiClis = pkgs.callPackage ./_ai-clis.nix { };
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

        aiClis.claude-code
        aiClis.codex
        aiClis.grok
        aiClis.kimi
        aiClis.opencode
        aiClis.cursor-agent
      ];
    };
}
