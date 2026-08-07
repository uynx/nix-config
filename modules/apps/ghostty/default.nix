{ moduleWithSystem, ... }:
{
  # macos-* keys in ./config are kept deliberately: ghostty ignores them on
  # Linux, and this tier is the one shared with a future darwin host.
  flake.wrappers.ghostty =
    { pkgs, wlib, ... }:
    {
      # No upstream wrapper module for ghostty, so this drives the generic one.
      imports = [ wlib.modules.default ];

      package = pkgs.ghostty;
      flagSeparator = "=";
      flags."--config-file" = ./config;

      # The default only patches .desktop files. Ghostty's entry is
      # DBusActivatable, so the launcher goes through the D-Bus service — which
      # in turn names a SystemdService, and that takes precedence over its own
      # Exec line. All three have to be patched or the launcher silently starts
      # the inner binary with none of the config above.
      filesToPatch = [
        "share/applications/*.desktop"
        "share/dbus-1/services/*.service"
        "share/systemd/user/*.service"
      ];
    };

  flake.homeModules.ghostty = moduleWithSystem (
    { self', ... }:
    {
      home.packages = [ self'.packages.ghostty ];
    }
  );
}
