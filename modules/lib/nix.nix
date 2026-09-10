{ self, inputs, ... }:
{
  flake.lib.determinateNixOverlay = final: _: {
    nix = inputs.determinate.inputs.nix.packages.${final.stdenv.hostPlatform.system}.default;
  };

  flake.lib.caches = {
    substituters = [
      "https://nix-community.cachix.org"
      "https://numtide.cachix.org"
    ];
    publicKeys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "numtide.cachix.org-1:2ps1kLBUWnL9yCkD69XfYIa2VclDuxsBeE266mGrW0o="
    ];
  };

  flake.lib.selfRegistry = home: {
    ${self.lib.user.name}.to = {
      type = "git";
      url = "file://${home}/nix-config";
    };
  };
}
