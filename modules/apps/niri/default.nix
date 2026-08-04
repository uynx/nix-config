{
  flake.nixosModules.niri =
    { pkgs, ... }:
    {
      programs.niri.enable = true;

      # noctalia's battery widget reads UPower and silently hides itself when
      # nothing is on the bus.
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

  # KDL that live-reloads on save, so it stays a real file. replaceStrings, not
  # pkgs.replaceVars: replaceVars fails the build on any leftover @identifier@,
  # and wpctl's @DEFAULT_AUDIO_SINK@ is literal KDL syntax, not a placeholder.
  flake.homeModules.niri =
    { pkgs, lib, ... }:
    {
      home.file.".config/niri/config.kdl".text =
        builtins.replaceStrings [ "@xwaylandSatellite@" ] [ (lib.getExe pkgs.xwayland-satellite) ]
          (builtins.readFile ./config.kdl);
    };
}
