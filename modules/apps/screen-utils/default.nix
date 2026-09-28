{
  flake.nixosModules.screenUtils =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.showmethekey ];
    };

  flake.homeModules.screenUtils =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        woomer
        grim
        slurp
        wlrctl
      ];
    };
}
