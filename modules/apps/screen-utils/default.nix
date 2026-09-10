{
  flake.nixosModules.screenUtils =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.showmethekey ];
    };

  flake.homeModules.screenUtils =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.woomer ];
    };
}
