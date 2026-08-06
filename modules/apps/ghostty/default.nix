{ self, ... }:
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
    };

  # Still Home Manager's module, only with the wrapped build: its desktop entry
  # is DBusActivatable, so the launcher needs the D-Bus and systemd units that
  # this module generates and a bare home.packages entry does not.
  flake.homeModules.ghostty =
    { pkgs, ... }:
    {
      programs.ghostty = {
        enable = true;
        package = self.packages.${pkgs.stdenv.hostPlatform.system}.ghostty;
      };
    };
}
