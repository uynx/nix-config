{ self, ... }:
{
  # Homebrew is the escape hatch for everything nixpkgs cannot build for macOS:
  # signed .app bundles, notarized installers and the AI vendors' own binaries.
  # Only the switch lives here — each app dir contributes its own casks, so a
  # component stays in one place the way it does on NixOS.
  #
  # `brew` itself is not installed by this; run the official installer once on a
  # fresh machine or the activation fails with "command not found".
  flake.darwinModules.homebrew = {
    homebrew = {
      enable = true;
      # Casks that self-update in place otherwise never move, because brew
      # keeps reading the stale version it recorded at install time.
      greedyCasks = true;
      onActivation = {
        autoUpdate = true;
        upgrade = true;
        # Removes anything installed by hand that no module asks for, which is
        # what keeps this list the truth about the machine.
        cleanup = "zap";
      };
      masApps = {
        cakewallet = 1334702542;
      };
    };

    home-manager.users.${self.lib.user.name}.shellHooks.update = [
      "brew update && brew upgrade"
    ];
  };
}
