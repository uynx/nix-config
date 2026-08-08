{ moduleWithSystem, ... }:
{
  # Config lands in a store NOCTALIA_CONFIG_DIR, so noctalia's settings GUI
  # still cannot save — same trade as before, now without a forced symlink in
  # the home directory. To tune in the GUI instead, set `outOfStoreConfig` to a
  # writable path: the wrapper seeds it once and hands editing back. The
  # wrapper also ships `dump-noctalia-shell`, which prints the running settings
  # as Nix, replacing the rm/restart/copy-back loop.
  #
  # Two settings are asserted in ./settings.json rather than patched over it
  # here, since `dump-noctalia-shell` round-trips through that file anyway:
  #   templates.activeTemplates[].enabled — all false. The ghostty template
  #     spams "Unknown color" every login (Flexoki omits its terminal_normal_*
  #     keys) and theming belongs in Nix.
  #   notifications.enabled — true. Nothing else here claims
  #     org.freedesktop.Notifications, so with it off every notify-send in the
  #     config silently no-ops.
  flake.wrappers.noctalia-shell =
    { wlib, pkgs, ... }:
    let
      saved = builtins.fromJSON (builtins.readFile ./settings.json);
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

      # Nested rather than one `//`: that is a shallow merge and would drop
      # every other wallpaper.* key in the file.
      settings = saved // {
        # The one override that cannot live in the file: a store path.
        wallpaper = saved.wallpaper // {
          directory = "${../../wallpapers}";
        };
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
