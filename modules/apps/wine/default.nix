{
  flake.homeModules.wine =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.wineWow64Packages.stagingFull
        pkgs.winetricks
      ];
    };
}
