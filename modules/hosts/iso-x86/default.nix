{ self, inputs, ... }:
{
  flake.nixosConfigurations.iso-x86 = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [
      "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-gnome.nix"

      { nixpkgs.hostPlatform.system = "x86_64-linux"; }

      self.nixosModules.nixSettings

      (
        { pkgs, lib, ... }:
        {
          isoImage.squashfsCompression = "zstd -Xcompression-level 6";

          documentation.nixos.enable = lib.mkForce false;

          services.desktopManager.gnome.favoriteAppsOverride = ''
            [org.gnome.shell]
            favorite-apps=[ 'brave-origin.desktop', 'org.gnome.Console.desktop', 'firefox.desktop', 'gparted.desktop', 'org.gnome.Nautilus.desktop' ]
          '';

          environment.etc."REINSTALL.md".source = ../../../REINSTALL.md;
          systemd.tmpfiles.rules = [ "L+ /home/nixos/REINSTALL.md - - - - /etc/REINSTALL.md" ];

          programs.nix-ld.enable = true;

          environment.systemPackages =
            with pkgs;
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
            ++ [
              (pkgs.callPackage ../../apps/brave-origin/_brave-origin.nix { })
              (pkgs.callPackage ../../apps/ai-tools/_ai-clis.nix { }).claude-code
            ];
        }
      )
    ];
  };
}
