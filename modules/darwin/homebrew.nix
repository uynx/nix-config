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
      "[ -L /opt/homebrew/bin/agy ] || rm -f /opt/homebrew/bin/agy; brew update && brew upgrade"
    ];
  };
}
