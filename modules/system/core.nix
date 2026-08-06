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
      # user.nix makes fish the login shell, so the overlay that points
      # pkgs.fish at the wrapped build has to be in reach of every host.
      fish
    ];

    # Only RustDesk uses this. Its app state lives outside the flake, so
    # nothing else should be installed this way.
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
