{ lib, ... }:
let
  home = "/home/uynx";
  darwinHome = "/Users/uynx";
in
{
  # Read as `self.lib.user`. Home modules should prefer `config.home.homeDirectory`
  # over `home` — this exists for the NixOS side, which has no such option.
  flake.lib.user = {
    name = "uynx";
    inherit home darwinHome;

    # For the tier that has neither: a perSystem output knows only its system
    # string, and a shared module must derive the path rather than name one.
    homeFor = system: if lib.hasSuffix "darwin" system then darwinHome else home;
  };
}
