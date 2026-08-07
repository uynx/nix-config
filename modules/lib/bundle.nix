{ self, ... }:
{
  # A bundle is one host-facing line that pulls both tiers of a component at
  # once. Without this a host has two lists — NixOS modules and Home Manager
  # imports — and adding or dropping anything means editing both, which is how
  # a "desktop environment" ends up scattered across three places.
  #
  # Requires home-manager, so every host taking a bundle must also take
  # `homeManagerBase`. Darwin has its own module system and cannot use these.
  flake.lib.mkBundle =
    {
      nixos ? [ ],
      home ? [ ],
    }:
    {
      imports = nixos;
      home-manager.users.${self.lib.user.name}.imports = home;
    };
}
