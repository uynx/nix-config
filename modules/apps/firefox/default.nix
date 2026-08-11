{
  flake.homeModules.firefox =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.firefox ];
    };
}
