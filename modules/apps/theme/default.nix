{ self, ... }:
{
  flake.homeModules.theme = { pkgs, ... }: {
    gtk =
      let
        c = self.lib.flexoki;
        # Flexoki's base-950. The only surface shade the terminal palette has
        # no entry for, so it stays here.
        surface = "#1c1b1a";

        # No Flexoki GTK theme exists, so override libadwaita's named colours
        # instead. GTK3 apps shipping their own stylesheet stay Adwaita-dark.
        flexoki = ''
          @define-color accent_color ${c.yellow};
          @define-color accent_bg_color ${c.yellow};
          @define-color accent_fg_color ${c.bg};
          @define-color destructive_bg_color ${c.red};
          @define-color destructive_fg_color ${c.bg};
          @define-color success_bg_color ${c.green};
          @define-color success_fg_color ${c.bg};
          @define-color warning_bg_color ${c.yellow};
          @define-color warning_fg_color ${c.bg};
          @define-color error_bg_color ${c.red};
          @define-color error_fg_color ${c.bg};
          @define-color window_bg_color ${c.bg};
          @define-color window_fg_color ${c.fg};
          @define-color view_bg_color ${c.bg};
          @define-color view_fg_color ${c.fg};
          @define-color headerbar_bg_color ${surface};
          @define-color headerbar_fg_color ${c.fg};
          @define-color card_bg_color ${surface};
          @define-color card_fg_color ${c.fg};
          @define-color popover_bg_color ${surface};
          @define-color popover_fg_color ${c.fg};
          @define-color sidebar_bg_color ${surface};
          @define-color sidebar_fg_color ${c.fg};
          @define-color borders ${c.selection};
        '';
      in
      {
        enable = true;
        gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
        gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
        gtk3.extraCss = flexoki;
        gtk4.extraCss = flexoki;
      };

    dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

    home.pointerCursor = {
      enable = true;
      gtk.enable = true;
      x11.enable = true;
      package = pkgs.capitaine-cursors;
      name = "capitaine-cursors";
      size = 24;
    };
  };
}
