{ self, inputs, ... }:
let
  inherit (self.lib) user;

  shared = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";
    extraSpecialArgs = { inherit inputs; };
    users.${user.name}.home.stateVersion = "26.05";
    sharedModules = [ self.homeModules.shellHooks ];
  };
in
{
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
      sharedModules = shared.sharedModules ++ [ inputs.mac-app-util.homeManagerModules.default ];
    };
  };
}
