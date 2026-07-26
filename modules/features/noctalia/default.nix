{ lib, ... }:
{
  # Quickshell-based desktop shell: bar, launcher, notifications, lock screen.
  #
  # settings.json is generated here rather than shipped verbatim, so paths that
  # would otherwise point into the home directory become store paths. The file
  # ends up a read-only store symlink, which means noctalia's settings GUI can
  # no longer save. To change a setting: edit settings.json in this repo and
  # rebuild. To experiment in the GUI first: `rm ~/.config/noctalia/settings.json`,
  # restart noctalia, tune it, then copy the result back here.
  flake.homeModules.noctalia =
    { pkgs, ... }:
    let
      saved = builtins.fromJSON (builtins.readFile ./settings.json);

      # All of noctalia's "apply theme to app" templates are off. Two reasons:
      # the ghostty one threw ~52 "Unknown color" lines every login because the
      # custom Flexoki scheme does not define its `terminal_normal_*` keys, and
      # the ones aimed at apps Nix does not manage (btop, yazi, discord, code,
      # steam) genuinely wrote files into ~/.config — which is exactly the
      # unmanaged drift this repo exists to remove. Theming belongs in Nix.
      disableTemplates = map (t: t // { enabled = false; });

      settings = lib.recursiveUpdate saved {
        # Shared with the SDDM greeter, which uses the same directory.
        wallpaper.directory = "${../../wallpapers}";
        templates.activeTemplates = disableTemplates saved.templates.activeTemplates;
      };
    in
    {
      home.packages = [ pkgs.noctalia-shell ];

      home.file.".config/noctalia/settings.json".text = builtins.toJSON settings;

      # Flexoki, matching ghostty's "Flexoki Dark" and the neovim colorscheme.
      home.file.".config/noctalia/colorschemes/Flexoki/Flexoki.json".source = ./Flexoki.json;
    };
}
