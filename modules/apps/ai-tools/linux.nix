{
  # The Linux half of the AI tooling: the six CLIs that ship an aarch64-linux
  # artifact worth pinning.
  # `update-ai-clis` (in default.nix) rewrites pins.json; a rebuild follows.
  flake.homeModules.aiToolsPinned =
    { pkgs, ... }:
    let
      aiClis = pkgs.callPackage ./_ai-clis.nix { };
    in
    {
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
