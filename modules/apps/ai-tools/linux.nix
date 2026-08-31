{
  # The Linux half of the AI tooling: the six CLIs worth pinning. Each ships an
  # aarch64-linux and an x86_64-linux artifact, so pins.json holds one hash per
  # architecture and the same list serves both asahi and x86.
  # `update-ai-clis` (in default.nix) rewrites pins.json; a rebuild follows.
  flake.homeModules.aiToolsPinned =
    { pkgs, lib, ... }:
    let
      aiClis = pkgs.callPackage ./_ai-clis.nix { };
    in
    {
      # Claude Code writes this itself on first use, with the store path of the
      # build that happened to be running. Every pin bump then leaves it aimed
      # at a path GC will collect, and `claude-cli://` links die silently.
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

      # Named one by one rather than with `attrValues`: callPackage adds
      # `override` / `overrideDerivation` to the returned set, which would land
      # in home.packages as non-packages.
      home.packages = [
        # What the CLIs reach for when they sandbox a command they are about to
        # run; without it they fall back to running it unsandboxed.
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
