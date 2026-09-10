{ self, ... }:
{
  flake.darwinModules.user =
    { pkgs, ... }:
    {
      users.users.${self.lib.user.name} = {
        home = self.lib.user.darwinHome;
        shell = pkgs.fish;
      };

      system.primaryUser = self.lib.user.name;

      programs.fish.enable = true;

      environment.shells = with pkgs; [
        fish
        dash
        bash
        bashInteractive
      ];
    };
}
