{ self, ... }:
{
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
