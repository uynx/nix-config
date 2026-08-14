{ moduleWithSystem, ... }:
let
  # niri's cargo constraint rejects libdisplay-info 0.4. Both the NixOS pkgs
  # and perSystem's need the same substitution — perSystem does not see the
  # overlay below — so the override is written once here and used by both.
  overrideNiri =
    prev:
    let
      downgrade = map (x: if (x.pname or "") == "libdisplay-info" then prev.libdisplay-info_0_2 else x);
    in
    prev.niri.overrideAttrs (old: {
      buildInputs = downgrade (old.buildInputs or [ ]);
      nativeBuildInputs = downgrade (old.nativeBuildInputs or [ ]);
    });
in
{
  # KDL stays a real file rather than becoming the wrapper's structured
  # settings — niri takes --config, so there is nothing to translate.
  # replaceStrings, not pkgs.replaceVars: replaceVars fails the build on any
  # leftover @identifier@, and wpctl's @DEFAULT_AUDIO_SINK@ is literal KDL
  # syntax, not a placeholder.
  #
  # Cost of baking it: the config is a store path, so editing no longer
  # live-reloads. Changing a binding now means a rebuild.
  flake.wrappers.niri =
    {
      wlib,
      pkgs,
      lib,
      ...
    }:
    let
      niri = overrideNiri pkgs;
      rendered =
        builtins.replaceStrings [ "@xwaylandSatellite@" ] [ (lib.getExe pkgs.xwayland-satellite) ]
          (builtins.readFile ./config.kdl);
    in
    {
      imports = [ wlib.modules.default ];

      package = niri;

      # Wrapping drops passthru, and services.displayManager.sessionPackages
      # rejects any package that does not declare which sessions it provides.
      passthru.providedSessions = [ "niri" ];

      filesToPatch = [
        "share/applications/*.desktop"
        "share/wayland-sessions/*.desktop"
        "share/systemd/user/*.service"
      ];

      # NIRI_CONFIG, not a prepended --config flag: niri rejects the global
      # flag ahead of a subcommand, so flags."--config" breaks every
      # `niri msg` call — which the Steam module and fish's android function
      # both depend on. The env var is parsed independently of arguments.
      #
      # Validated at build time, so a KDL mistake fails the build instead of
      # leaving a compositor that will not start at the next login.
      env.NIRI_CONFIG = pkgs.runCommand "niri-config.kdl" { } ''
        cp ${pkgs.writeText "niri-config-unchecked.kdl" rendered} $out
        ${lib.getExe niri} validate -c $out
      '';
    };

  flake.nixosModules.niri = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      nixpkgs.overlays = [ (_: prev: { niri = overrideNiri prev; }) ];

      programs.niri = {
        enable = true;
        package = self'.packages.niri;
      };

      # noctalia's battery widget reads UPower and silently hides itself when
      # nothing is on the bus.
      services.upower.enable = true;

      # Only RustDesk uses flatpak. Its app state lives outside the flake, so
      # nothing else should be installed this way. It lives here rather than in
      # core because it asserts on xdg.portal, which only a desktop provides —
      # in core it made the headless host stubs fail to evaluate.
      services.flatpak.enable = true;

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
    }
  );

  flake.homeModules.niri = {
    shellHooks.rebPostSwitch = ''
      if type -q niri; and niri msg version >/dev/null 2>&1
          set -l niri_cfg (grep -o "/nix/store/[^\" ]*-niri-config.kdl" (type -p niri) | head -n1)
          if test -n "$niri_cfg"
              niri msg action load-config-file --path $niri_cfg
          end
      end
    '';
  };
}
