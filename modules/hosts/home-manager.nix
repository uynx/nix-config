{ self, inputs, ... }:
let
  inherit (self.lib) user;

  shared = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";
    extraSpecialArgs = { inherit inputs; };
    users.${user.name}.home.stateVersion = "26.05";
  };
in
{
  # Every host's home-manager wiring except which modules the user gets, which
  # is the only part that legitimately differs per host. stateVersion lives here
  # rather than per host because leaving it out is not a visible omission — the
  # host simply stops evaluating, which is how both stubs broke.
  flake.nixosModules.homeManagerBase = {
    imports = [ inputs.home-manager.nixosModules.home-manager ];
    home-manager = shared;
  };

  flake.darwinModules.homeManagerBase = {
    imports = [
      inputs.home-manager.darwinModules.home-manager
      inputs.mac-app-util.darwinModules.default
    ];
    home-manager = shared // {
      sharedModules = [ inputs.mac-app-util.homeManagerModules.default ];
    };
  };
}
