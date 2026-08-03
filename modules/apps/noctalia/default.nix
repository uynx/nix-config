{ lib, ... }:
{
  # settings.json is generated so home-dir paths become store paths. Side effect:
  # the GUI can no longer save. To tune in the GUI, rm the file, restart, tune,
  # then copy it back here.
  flake.homeModules.noctalia =
    { pkgs, ... }:
    let
      saved = builtins.fromJSON (builtins.readFile ./settings.json);

      # Templates all off: the ghostty one spams "Unknown color" every login
      # (Flexoki omits its terminal_normal_* keys), and the rest write into
      # ~/.config for apps Nix does not manage. Theming belongs in Nix.
      disableTemplates = map (t: t // { enabled = false; });

      settings = lib.recursiveUpdate saved {
        wallpaper.directory = "${../../wallpapers}";
        templates.activeTemplates = disableTemplates saved.templates.activeTemplates;
      };
    in
    {
      home.packages = [ pkgs.noctalia-shell ];

      # force: noctalia rewrites this at runtime, and the resulting .bak collision
      # aborts the entire activation, leaving no managed file linked at all.
      home.file.".config/noctalia/settings.json" = {
        text = builtins.toJSON settings;
        force = true;
      };

      # Flexoki, matching ghostty's "Flexoki Dark" and the neovim colorscheme.
      home.file.".config/noctalia/colorschemes/Flexoki/Flexoki.json".source = ./Flexoki.json;
    };
}
