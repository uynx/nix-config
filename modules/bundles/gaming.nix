{ self, ... }:
{
  # Steam through the Fedora/FEX distrobox container. Asahi-only: the container
  # exists because the host kernel is 16 KiB-page aarch64, and every helper
  # script drives niri's IPC.
  flake.nixosModules.gaming =
    (self.lib.mkBundle {
      nixos = [ self.nixosModules.steamAsahi ];
      home = [ self.homeModules.steamAsahi ];
    }).nixos;
}
