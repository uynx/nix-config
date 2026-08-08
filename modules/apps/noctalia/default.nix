{ moduleWithSystem, lib, ... }:
{
  # Config lands in a store NOCTALIA_CONFIG_DIR, so noctalia's settings GUI
  # still cannot save — same trade as before, now without a forced symlink in
  # the home directory. To tune in the GUI instead, set `outOfStoreConfig` to a
  # writable path: the wrapper seeds it once and hands editing back. The
  # wrapper also ships `dump-noctalia-shell`, which prints the running settings
  # as Nix, replacing the rm/restart/copy-back loop.
  flake.wrappers.noctalia-shell =
    { wlib, pkgs, ... }:
    let
      saved = builtins.fromJSON (builtins.readFile ./settings.json);

      # All off: the ghostty one spams "Unknown color" every login (Flexoki
      # omits its terminal_normal_* keys) and theming belongs in Nix anyway.
      disableTemplates = map (t: t // { enabled = false; });
    in
    {
      imports = [ wlib.wrapperModules.noctalia-shell ];

      # Password dots are the one lock screen element with no colour setting;
      # they follow mPrimary, which makes them amber next to the greeter's
      # plain foreground.
      package = pkgs.noctalia-shell.overrideAttrs (_: {
        postInstall = ''
          substituteInPlace $out/share/noctalia-shell/Modules/LockScreen/LockScreenPanel.qml \
            --replace-fail 'isSelected ? Color.mOnPrimary : Color.mPrimary' \
                           'isSelected ? Color.mOnPrimary : Color.mOnSurface'
        '';
      });

      settings = lib.recursiveUpdate saved {
        wallpaper.directory = "${../../wallpapers}";
        templates.activeTemplates = disableTemplates saved.templates.activeTemplates;

        # Nothing else on this host claims org.freedesktop.Notifications, so
        # with this off every notify-send in the config silently no-ops.
        notifications.enabled = true;
      };

      colors = builtins.fromJSON (builtins.readFile ./Flexoki.json);
    };

  flake.homeModules.noctalia = moduleWithSystem (
    { self', ... }:
    {
      home.packages = [ self'.packages.noctalia-shell ];
    }
  );
}
