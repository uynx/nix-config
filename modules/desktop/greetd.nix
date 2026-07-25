{
  # ReGreet is a GTK greeter for greetd, run inside cage (a minimal kiosk
  # compositor). Noctalia cannot do this job — it ships a LockScreen, which
  # locks an already-running session, whereas a greeter runs as the `greeter`
  # user before any session exists.
  flake.nixosModules.greetd =
    { pkgs, ... }:
    {
      services.greetd.enable = true;

      programs.regreet = {
        enable = true;

        # Deliberately not catppuccin-gtk: it is broken in this nixpkgs pin
        # (its python catppuccin dep fails on matplotlib.style.core), and a
        # greeter that will not build means no way to log in.
        theme = {
          name = "Adwaita-dark";
          package = pkgs.gnome-themes-extra;
        };
        iconTheme = {
          name = "Papirus-Dark";
          package = pkgs.papirus-icon-theme;
        };
        cursorTheme = {
          name = "capitaine-cursors";
          package = pkgs.capitaine-cursors;
        };
        font = {
          name = "Hack Nerd Font";
          package = pkgs.nerd-fonts.hack;
          size = 12;
        };

        settings.background = {
          path = "/home/uynx/dotfiles/wallpaper.png";
          fit = "Cover";
        };
      };

      # ReGreet builds its session list from wayland-sessions desktop files.
      # programs.niri.enable does not install one, so without this the session
      # picker is empty and there is nothing to log into.
      services.displayManager.sessionPackages = [ pkgs.niri ];

      services.gnome.gnome-keyring.enable = true;
      security.pam.services.greetd.enableGnomeKeyring = true;
    };
}
