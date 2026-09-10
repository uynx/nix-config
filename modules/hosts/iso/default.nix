{ self, inputs, ... }:
{
  flake.nixosConfigurations.iso = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [
      inputs.nixos-apple-silicon.nixosModules.apple-silicon-installer

      { nixpkgs.hostPlatform.system = "aarch64-linux"; }

      self.nixosModules.nixSettings

      (
        { pkgs, ... }:
        {
          documentation.nixos.enable = inputs.nixpkgs.lib.mkForce false;

          environment.etc."REINSTALL.md".source = ../../../REINSTALL.md;
          systemd.tmpfiles.rules = [ "L+ /home/nixos/REINSTALL.md - - - - /etc/REINSTALL.md" ];

          programs.nix-ld.enable = true;

          environment.systemPackages =
            with inputs.nixpkgs.legacyPackages.aarch64-linux;
            [
              vim
              git
              gh
              bitwarden-cli
              jq
              sops
              rage
              cryptsetup
              curl
              ripgrep
              fd
            ]
            ++ [ (pkgs.callPackage ../../apps/ai-tools/_ai-clis.nix { }).claude-code ];
        }
      )
    ];
  };
}
