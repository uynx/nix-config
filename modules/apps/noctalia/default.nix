{ lib, ... }:
{
  # Generating settings.json makes home-dir paths store paths, at the cost of
  # the GUI no longer saving. To tune in the GUI: rm the file, restart, tune,
  # copy it back here.
  flake.homeModules.noctalia =
    { pkgs, ... }:
    let
      saved = builtins.fromJSON (builtins.readFile ./settings.json);

      # All off: the ghostty one spams "Unknown color" every login (Flexoki
      # omits its terminal_normal_* keys) and theming belongs in Nix anyway.
      disableTemplates = map (t: t // { enabled = false; });

      settings = lib.recursiveUpdate saved {
        wallpaper.directory = "${../../wallpapers}";
        templates.activeTemplates = disableTemplates saved.templates.activeTemplates;
      };
    in
    {
      home.packages = [ pkgs.noctalia-shell ];

      # force: noctalia rewrites this at runtime, and the .bak collision aborts
      # the whole activation.
      home.file.".config/noctalia/settings.json" = {
        text = builtins.toJSON settings;
        force = true;
      };

      home.file.".config/noctalia/colorschemes/Flexoki/Flexoki.json".source = ./Flexoki.json;
    };
}
