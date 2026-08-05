{
  flake.nixosModules.niri =
    { pkgs, ... }:
    {
      nixpkgs.overlays = [
        (final: prev: {
          niri = prev.niri.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
              (prev.libdisplay-info_0_2.dev or prev.libdisplay-info_0_2)
            ];
          });
        })
      ];

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
    let
      rendered =
        builtins.replaceStrings [ "@xwaylandSatellite@" ] [ (lib.getExe pkgs.xwayland-satellite) ]
          (builtins.readFile ./config.kdl);
    in
    {
      # Validated at build time, so a KDL mistake fails `reb` instead of leaving
      # a compositor that will not start at the next login.
      home.file.".config/niri/config.kdl".source = pkgs.runCommand "niri-config.kdl" { } ''
        cp ${pkgs.writeText "niri-config-unchecked.kdl" rendered} $out
        ${lib.getExe pkgs.niri} validate -c $out
      '';
    };
}
