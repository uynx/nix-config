{ self, ... }:
{
  flake.darwinModules.homebrew = {
    homebrew = {
      enable = true;
      greedyCasks = true;
      onActivation = {
        autoUpdate = true;
        upgrade = true;
        cleanup = "zap";
      };
    };

    home-manager.users.${self.lib.user.name}.shellHooks.update = [
      "brew update && brew upgrade"
    ];
  };
}
