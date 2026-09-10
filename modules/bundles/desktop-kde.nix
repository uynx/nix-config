{ self, ... }:
{
  flake.nixosModules.desktopKde =
    (self.lib.mkBundle {
      nixos = [
        (
          { pkgs, ... }:
          {
            services.desktopManager.plasma6.enable = true;
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
    }).nixos;
}
