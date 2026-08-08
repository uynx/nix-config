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
    { pkgs, lib, ... }:
    let
      inherit (pkgs.stdenv.hostPlatform) isDarwin;
    in
    {
      # mkIf rather than two separate modules: branching on `pkgs` at the module
      # level would make the import itself depend on config, which is an
      # infinite recursion inside Home Manager.
      home.packages = lib.mkIf (!isDarwin) [ self'.packages.ghostty ];

      # nixpkgs has no darwin ghostty to wrap — only the notarized build, which
      # ignores the wrapper's .desktop patching anyway. Same config file, one
      # Retina-sized override on top.
      programs.ghostty = lib.mkIf isDarwin {
        enable = true;
        package = pkgs.ghostty-bin;
      };

      home.file.".config/ghostty/config" = lib.mkIf isDarwin {
        text = ''
          config-file = ${./config}
          font-size = 16
        '';
      };
    }
  );
}
