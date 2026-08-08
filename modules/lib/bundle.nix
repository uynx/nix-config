{ self, ... }:
{
  # A bundle is one host-facing line that pulls every tier of a component at
  # once. Without this a host has two lists — system modules and Home Manager
  # imports — and adding or dropping anything means editing both, which is how
  # a "desktop environment" ends up scattered across three places.
  #
  # Returns both platforms because the Home Manager half is usually identical on
  # each and only the system half differs; a bundle file assigns `.nixos` and
  # `.darwin` to the two module sets so a NixOS host and a darwin host list the
  # very same bundle name. Requires home-manager, so every host taking a bundle
  # must also take `homeManagerBase`.
  #
  # `homeLinux` / `homeDarwin` exist so a bundle whose home tier differs by one
  # entry still writes the shared list once. Two calls to this would restate it,
  # which is the same two-lists-to-keep-in-sync problem the helper exists to end.
  flake.lib.mkBundle =
    {
      nixos ? [ ],
      darwin ? [ ],
      home ? [ ],
      homeLinux ? [ ],
      homeDarwin ? [ ],
    }:
    let
      hm = modules: { home-manager.users.${self.lib.user.name}.imports = modules; };
    in
    {
      nixos = hm (home ++ homeLinux) // {
        imports = nixos;
      };
      darwin = hm (home ++ homeDarwin) // {
        imports = darwin;
      };
    };
}
