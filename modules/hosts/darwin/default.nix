{ self, inputs, ... }:
{
  # macOS on the same physical MacBook that dual-boots the `asahi` host.
  # Separate module system: nix-darwin has no boot.loader, systemd, or
  # services.greetd, so nothing under modules/shared or modules/desktop
  # applies here. Only homeModules cross the boundary.
  #
  # STUB: cannot be built from aarch64-linux. Evaluates only.
  flake.darwinConfigurations.darwin = inputs.nix-darwin.lib.darwinSystem {
    system = "aarch64-darwin";
    specialArgs = { inherit inputs; };
    modules = [
      inputs.home-manager.darwinModules.home-manager

      {
        networking.hostName = "darwin";
        system.stateVersion = 5;
        nixpkgs.hostPlatform = "aarch64-darwin";
      }
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "bak";
          extraSpecialArgs = { inherit inputs; };
          users.uynx.imports = with self.homeModules; [
            programming
            {
              home.username = "uynx";
              home.homeDirectory = "/Users/uynx";
              home.stateVersion = "26.05";
            }
          ];
        };
      }
    ];
  };
}
