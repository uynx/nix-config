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

    systemd.tmpfiles.rules = [ "L+ /bin/dash - - - - ${pkgs.dash}/bin/dash" ];

    documentation.nixos.enable = false;

    system.stateVersion = "26.05";
  };
}
