{
  # Quickshell-based desktop shell: bar, launcher, notifications, lock screen.
  # Supports Hyprland natively, so it can replace waybar/fuzzel/dunst without
  # touching the compositor.
  #
  # Config is still mutable in ~/.config/noctalia for now. Once the GUI settings
  # are dialled in, snapshot them with
  #   noctalia-shell ipc call state all > settings.json
  # and bake them via wrapper-modules, the same way vimjoyer does.
  flake.homeModules.noctalia = { pkgs, ... }: {
    home.packages = [ pkgs.noctalia-shell ];
  };
}
