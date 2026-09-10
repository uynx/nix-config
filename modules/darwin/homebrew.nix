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
      masApps = {
        cakewallet = 1334702542;
      };
    };

    home-manager.users.${self.lib.user.name}.shellHooks.update = [
      "brew update && brew upgrade"
    ];
  };
}
