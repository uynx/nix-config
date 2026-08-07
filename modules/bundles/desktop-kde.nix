{ self, ... }:
{
  # The alternative to `desktopNiri` — swap the one line in a host. Plasma
  # brings its own greeter theme, panel, screenshot tool and GTK bridge, so
  # none of the niri desktop's parts are wanted alongside it.
  #
  # Never built here; this exists so the swap is a real one-liner rather than a
  # rewrite. On a machine driven remotely over RustDesk, add
  # `services.displayManager.defaultSession = "plasmax11"` — Wayland re-prompts
  # for screen capture on every connection.
  flake.nixosModules.desktopKde = self.lib.mkBundle {
    nixos = [
      (
        { pkgs, ... }:
        {
          services.desktopManager.plasma6.enable = true;
          # No `package` here: plasma6 already selects kdePackages.sddm, and a
          # second definition collides rather than overriding.
          services.displayManager.sddm = {
            enable = true;
            wayland.enable = true;
          };
          environment.systemPackages = [ pkgs.kdePackages.spectacle ];

          services.gnome.gnome-keyring.enable = true;
          security.pam.services.sddm.enableGnomeKeyring = true;
        }
      )
    ];
  };
}
