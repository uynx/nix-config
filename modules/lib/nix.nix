{ self, inputs, ... }:
{
  flake.lib = {
    determinateNixOverlay = final: _: {
      nix = inputs.determinate.inputs.nix.packages.${final.stdenv.hostPlatform.system}.default;
    };

    caches = {
      substituters = [ "https://nix-community.cachix.org" ];
      publicKeys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
    };

    selfRegistry = home: {
      ${self.lib.user.name}.to = {
        type = "git";
        url = "file://${home}/nix-config";
      };
    };
  };
}
