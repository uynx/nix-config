{
  flake.nixosModules.niri =
    { pkgs, ... }:
    {
      programs.niri.enable = true;

      # noctalia's battery widget reads Quickshell.Services.UPower and hides
      # itself when no device is on the bus, so without this the icon is simply
      # absent. Waybar polled /sys/class/power_supply directly and never needed it.
      services.upower.enable = true;

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

  # niri config is plain KDL and live-reloads on save, so it stays a real file
  # rather than being generated from Nix attrs. The one substitution is the
  # xwayland-satellite binary, which has to be an absolute store path.
  #
  # Done with replaceStrings rather than pkgs.replaceVars: the latter fails the
  # build on any leftover @identifier@, and wpctl's @DEFAULT_AUDIO_SINK@ /
  # @DEFAULT_AUDIO_SOURCE@ are literal syntax, not placeholders.
  flake.homeModules.niri =
    { pkgs, lib, ... }:
    {
      home.file.".config/niri/config.kdl".text =
        builtins.replaceStrings [ "@xwaylandSatellite@" ] [ (lib.getExe pkgs.xwayland-satellite) ]
          (builtins.readFile ./config.kdl);
    };
}
