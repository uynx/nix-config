{
  flake.nixosModules.fonts = { pkgs, ... }: {
    systemd.tmpfiles.rules = [
      # Prebuilt Flutter apps (RustDesk) read only /usr/share/fonts and render no text without it.
      "L+ /usr/share/fonts - - - - /run/current-system/sw/share/X11/fonts"
    ];

    fonts = {
      fontDir.enable = true;
      packages = with pkgs; [
        nerd-fonts.hack
        julia-mono
        cantarell-fonts
        dejavu_fonts
        liberation_ttf
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
      ];
    };
  };
}
