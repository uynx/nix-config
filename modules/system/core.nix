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

    environment.systemPackages = with pkgs; [
      git
      vim
      wget
      curl
      ghostty
      brightnessctl
    ];

    system.stateVersion = "26.05";
  };
}
