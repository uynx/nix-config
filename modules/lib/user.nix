{ lib, ... }:
let
  home = "/home/uynx";
  darwinHome = "/Users/uynx";
in
{
  flake.lib.user = {
    name = "uynx";
    inherit home darwinHome;

    homeFor = system: if lib.hasSuffix "darwin" system then darwinHome else home;
  };
}
