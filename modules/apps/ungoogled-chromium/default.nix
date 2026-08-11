{
  flake.homeModules.ungoogledChromium =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.ungoogled-chromium ];
    };
}
