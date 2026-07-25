{ self, ... }:
{
  flake.nixosModules.core = { pkgs, ... }: {
    imports = with self.nixosModules; [
      nixSettings
      locale
      networking
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
      fuzzel
      brightnessctl
      flatpak
    ];

    system.stateVersion = "26.05";
  };
}
