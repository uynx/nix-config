{ self, ... }:
{
  # The darwin twin of `system/user.nix`. The account already exists on macOS,
  # so this only points it at the wrapped fish and tells nix-darwin whose
  # defaults to write.
  flake.darwinModules.user =
    { pkgs, ... }:
    {
      # home-manager derives home.homeDirectory from this and any second
      # definition collides rather than overriding, so the account set here is
      # the only place either is stated.
      users.users.${self.lib.user.name} = {
        home = self.lib.user.darwinHome;
        shell = pkgs.fish;
      };

      system.primaryUser = self.lib.user.name;

      programs.fish.enable = true;
      programs.bash.enable = true;

      environment.shells = with pkgs; [
        fish
        dash
        bash
        bashInteractive
      ];
    };
}
