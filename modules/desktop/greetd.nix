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

        # Flexoki Dark, matching ghostty and neovim. No Flexoki GTK theme
        # exists, so the palette is applied directly rather than via a package.
        extraCss = ''
          window, .background {
            background-color: #100f0f;
            color: #cecdc3;
          }
          entry, button {
            background-color: #403e3c;
            color: #cecdc3;
            border: 1px solid #575653;
            border-radius: 6px;
          }
          entry:focus {
            border-color: #d0a215;
          }
          button:hover {
            background-color: #575653;
          }
          label {
            color: #cecdc3;
          }
          .title, #clock {
            color: #d0a215;
          }
        '';
      };

      # ReGreet builds its session list from wayland-sessions desktop files.
      # programs.niri.enable does not install one, so without this the session
      # picker is empty and there is nothing to log into.
      services.displayManager.sessionPackages = [ pkgs.niri ];

      services.gnome.gnome-keyring.enable = true;
      security.pam.services.greetd.enableGnomeKeyring = true;
    };
}
