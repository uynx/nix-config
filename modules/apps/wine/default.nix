{
  flake.homeModules.wine =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.wineWowPackages.stagingFull
        pkgs.winetricks
      ];
    };
}
