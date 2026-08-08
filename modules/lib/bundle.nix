{ self, ... }:
{
  # A bundle is one host-facing line that pulls every tier of a component at
  # once. Without this a host has two lists — system modules and Home Manager
  # imports — and adding or dropping anything means editing both, which is how
  # a "desktop environment" ends up scattered across three places.
  #
  # Returns both platforms because the Home Manager half is identical on each
  # and only the system half differs; a bundle file assigns
  # `.nixos` and `.darwin` to the two module sets so a NixOS host and a darwin
  # host list the very same bundle name. Requires home-manager, so every host
  # taking a bundle must also take `homeManagerBase`.
  flake.lib.mkBundle =
    {
      nixos ? [ ],
      darwin ? [ ],
      home ? [ ],
    }:
    let
      user = {
        home-manager.users.${self.lib.user.name}.imports = home;
      };
    in
    {
      nixos = user // {
        imports = nixos;
      };
      darwin = user // {
        imports = darwin;
      };
    };
}
