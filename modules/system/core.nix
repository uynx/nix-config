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
