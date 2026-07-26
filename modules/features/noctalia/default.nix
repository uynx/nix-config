{
  # Quickshell-based desktop shell: bar, launcher, notifications, lock screen.
  #
  # settings.json is frozen here, so ~/.config/noctalia/settings.json is a
  # read-only store symlink and noctalia's settings GUI can no longer save.
  # To change a setting: edit settings.json in this repo and rebuild. To try
  # something interactively first, `rm ~/.config/noctalia/settings.json`,
  # restart noctalia, tune it in the GUI, then copy the result back here.
  flake.homeModules.noctalia =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.noctalia-shell ];

      home.file.".config/noctalia/settings.json".source = ./settings.json;

      # Flexoki, matching ghostty's "Flexoki Dark" and the neovim colorscheme.
      home.file.".config/noctalia/colorschemes/Flexoki/Flexoki.json".source = ./Flexoki.json;
    };
}
