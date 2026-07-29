{
  flake.homeModules.theme = { pkgs, ... }: {
    gtk =
      let
        # No Flexoki GTK theme package exists, and building one is far more work
        # than it is worth. Overriding libadwaita's named colours gets most of
        # the way there: GTK4/libadwaita apps pick these up directly. Older GTK3
        # apps that ship their own stylesheet will still look Adwaita-dark.
        flexoki = ''
          @define-color accent_color #d0a215;
          @define-color accent_bg_color #d0a215;
          @define-color accent_fg_color #100f0f;
          @define-color destructive_bg_color #d14d41;
          @define-color destructive_fg_color #100f0f;
          @define-color success_bg_color #879a39;
          @define-color success_fg_color #100f0f;
          @define-color warning_bg_color #d0a215;
          @define-color warning_fg_color #100f0f;
          @define-color error_bg_color #d14d41;
          @define-color error_fg_color #100f0f;
          @define-color window_bg_color #100f0f;
          @define-color window_fg_color #cecdc3;
          @define-color view_bg_color #100f0f;
          @define-color view_fg_color #cecdc3;
          @define-color headerbar_bg_color #1c1b1a;
          @define-color headerbar_fg_color #cecdc3;
          @define-color card_bg_color #1c1b1a;
          @define-color card_fg_color #cecdc3;
          @define-color popover_bg_color #1c1b1a;
          @define-color popover_fg_color #cecdc3;
          @define-color sidebar_bg_color #1c1b1a;
          @define-color sidebar_fg_color #cecdc3;
          @define-color borders #403e3c;
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
