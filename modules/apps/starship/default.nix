{ self, moduleWithSystem, ... }:
let
  c = self.lib.flexoki;
in
{
  flake.wrappers.starship =
    { wlib, ... }:
    {
      imports = [ wlib.wrapperModules.starship ];

      settings = {
        add_newline = false;
        command_timeout = 3000;
        palette = "flexoki";
        palettes.flexoki = {
          black = c.bg;
          inherit (c) red;
          inherit (c) green;
          inherit (c) yellow;
          inherit (c) blue;
          purple = c.magenta;
          inherit (c) cyan;
          white = c.fg;
        };
      };
    };

  flake.homeModules.starship = moduleWithSystem (
    { self', ... }:
    { lib, ... }:
    {
      home.packages = [ self'.packages.starship ];

      programs.fish.interactiveShellInit = lib.mkAfter ''
        if test "$TERM" != dumb
          ${lib.getExe self'.packages.starship} init fish | source
        end
      '';
    }
  );
}
