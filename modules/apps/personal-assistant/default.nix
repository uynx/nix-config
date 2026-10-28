{
  flake.nixosModules.personalAssistant = { pkgs, ... }: {
    environment.systemPackages = [
      (pkgs.callPackage ./_simplex-cli.nix { })
      pkgs.protonmail-bridge
    ];
  };
}
