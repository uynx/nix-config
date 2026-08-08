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
        # Redefining the standard colour names retints every module at once.
        palette = "flexoki";
        palettes.flexoki = {
          black = c.bg;
          red = c.red;
          green = c.green;
          yellow = c.yellow;
          blue = c.blue;
          purple = c.magenta;
          cyan = c.cyan;
          white = c.fg;
        };
      };
    };

  # Not Home Manager's module: it exports STARSHIP_CONFIG as a session variable
  # pointing at ~/.config/starship.toml, which would outrank the config the
  # wrapper carries. So this contributes the shell hook itself.
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
