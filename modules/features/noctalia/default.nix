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

      # The ghostty template expects `terminal_normal_*` colour keys that the
      # custom Flexoki scheme does not define, so it threw ~52 "Unknown color"
      # lines on every login. It could never have applied anyway: ghostty's
      # config is a read-only store symlink.
      disableGhostty = map (t: t // { enabled = t.enabled && t.id != "ghostty"; });

      settings = lib.recursiveUpdate saved {
        # Shared with the SDDM greeter, which uses the same directory.
        wallpaper.directory = "${../../wallpapers}";
        templates.activeTemplates = disableGhostty saved.templates.activeTemplates;
      };
    in
    {
      home.packages = [ pkgs.noctalia-shell ];

      home.file.".config/noctalia/settings.json".text = builtins.toJSON settings;

      # Flexoki, matching ghostty's "Flexoki Dark" and the neovim colorscheme.
      home.file.".config/noctalia/colorschemes/Flexoki/Flexoki.json".source = ./Flexoki.json;
    };
}
