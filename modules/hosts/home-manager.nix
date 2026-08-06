{ inputs, ... }:
let
  shared = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";
    extraSpecialArgs = { inherit inputs; };
  };
in
{
  # Every host's home-manager wiring except which modules the user gets, which
  # is the only part that legitimately differs per host.
  flake.nixosModules.homeManagerBase = {
    imports = [ inputs.home-manager.nixosModules.home-manager ];
    home-manager = shared;
  };

  flake.darwinModules.homeManagerBase = {
    imports = [ inputs.home-manager.darwinModules.home-manager ];
    home-manager = shared;
  };
}
