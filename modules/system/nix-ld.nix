{
  # Needed by unpackaged binaries (Antigravity tarball, etc.)
  flake.nixosModules.nixLd = { pkgs, ... }: {
    programs.nix-ld = {
      enable = true;
      libraries = with pkgs; [
        glib
        gtk3
        pango
        cairo
        atk
        at-spi2-core
        nspr
        nss
        libX11
        libXcomposite
        libXdamage
        libXext
        libXfixes
        libXrandr
        libxcb
        libxkbcommon
        mesa
        libgbm
        libglvnd
        expat
        dbus
        cups
        alsa-lib
        systemd
      ];
    };
  };
}
