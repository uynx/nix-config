{
  flake.nixosModules.niri = { pkgs, ... }: {
    programs.niri.enable = true;

    # niri has no built-in XWayland; X11 clients need this bridge.
    environment.systemPackages = with pkgs; [
      xwayland-satellite
      wl-clipboard
      playerctl
    ];

    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gnome
        xdg-desktop-portal-gtk
      ];
      config.common.default = [
        "gnome"
        "gtk"
      ];
    };
  };
}
