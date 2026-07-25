{
  # Quickshell-based desktop shell: bar, launcher, notifications, lock screen.
  #
  # settings.json stays mutable in ~/.config/noctalia so the settings GUI keeps
  # working. Only the colour scheme is managed here — freezing settings.json
  # would make it a read-only store symlink and disable that GUI.
  flake.homeModules.noctalia = { pkgs, ... }: {
    home.packages = [ pkgs.noctalia-shell ];

    # Flexoki, matching ghostty's "Flexoki Dark" and the neovim colorscheme.
    # Select it in Noctalia's settings once it appears.
    home.file.".config/noctalia/colorschemes/Flexoki/Flexoki.json".source = ./Flexoki.json;
  };
}
