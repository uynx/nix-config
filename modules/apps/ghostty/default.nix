{ moduleWithSystem, ... }:
{
  flake.wrappers.ghostty =
    { pkgs, wlib, ... }:
    {
      imports = [ wlib.modules.default ];

      package = pkgs.ghostty;
      flagSeparator = "=";
      flags."--config-file" = ./config;

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
      home.packages = lib.mkIf (!isDarwin) [ self'.packages.ghostty ];

      programs.ghostty = lib.mkIf isDarwin {
        enable = true;
        package = pkgs.ghostty-bin;
      };

      home.file.".config/ghostty/config" = lib.mkIf isDarwin {
        text = builtins.readFile ./config + ''

          font-size = 16
        '';
      };
    }
  );
}
