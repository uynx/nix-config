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

    # Only RustDesk uses this. Keep until it runs from nixpkgs instead, or the
    # installed Flatpak stops working with nothing to replace it.
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

    system.stateVersion = "26.05";
  };
}
