{ self, ... }:
{
  flake.nixosModules.desktopKde =
    (self.lib.mkBundle {
      nixos = [
        (
          { pkgs, ... }:
          {
            services = {
              desktopManager.plasma6.enable = true;
              displayManager.sddm = {
                enable = true;
                wayland.enable = true;
              };
              gnome.gnome-keyring.enable = true;
            };
            environment.systemPackages = [ pkgs.kdePackages.spectacle ];
            security.pam.services.sddm.enableGnomeKeyring = true;
          }
        )
      ];
    }).nixos;
}
