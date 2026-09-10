{ inputs, ... }:
{
  flake.nixosModules.rustdesk = {
    imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

    services.flatpak = {
      enable = true;

      remotes = [
        {
          name = "flathub";
          location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
        }
      ];

      packages = [ "com.rustdesk.RustDesk" ];

      update.onActivation = true;
    };
  };
}
