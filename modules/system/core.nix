{ self, ... }:
{
  flake.nixosModules.core = { pkgs, ... }: {
    imports = with self.nixosModules; [
      nixSettings
      locale
      networking
      security
      audio
      bluetooth
      fonts
      user
      nixLd
    ];

    services.flatpak.enable = true;

    environment.systemPackages = with pkgs; [
      git
      vim
      wget
      curl
      ghostty
      brightnessctl
      flatpak
    ];

    boot.binfmt.emulatedSystems = [ "x86_64-linux" ];

    system.stateVersion = "26.05";
  };
}
