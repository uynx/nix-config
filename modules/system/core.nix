{ self, ... }:
{
  flake.nixosModules.core = { pkgs, ... }: {
    imports = with self.nixosModules; [
      nixSettings
      locale
      networking
      dnscrypt
      security
      audio
      bluetooth
      fonts
      user
      nixLd
      fish
    ];

    environment.etc.nixos.source = "${self.lib.user.home}/nix-config";

    environment.systemPackages = with pkgs; [
      git
      vim
      wget
      curl
      brightnessctl
    ];

    system.stateVersion = "26.05";
  };
}
