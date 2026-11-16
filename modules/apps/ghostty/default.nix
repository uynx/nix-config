{ self, moduleWithSystem, ... }:
let
  config = tmux: builtins.readFile ./config + "command = ${tmux}/bin/tmux -L term new-session\n";
in
{
  flake.wrappers.ghostty =
    { pkgs, wlib, ... }:
    {
      imports = [ wlib.modules.default ];

      package = pkgs.ghostty;
      flagSeparator = "=";
      flags."--config-file" = pkgs.writeText "ghostty-config" (
        config self.packages.${pkgs.stdenv.hostPlatform.system}.tmux
      );

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
        text = config self'.packages.tmux + "font-size = 16\n";
      };
    }
  );
}
