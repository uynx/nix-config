{
  # System, not home: showmethekey ships a polkit policy for /dev/input, and
  # polkit only reads policies out of the system profile. From home.packages
  # the binary installs but input access silently fails.
  flake.nixosModules.screenUtils =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.showmethekey ];
    };

  # Wayland zoom.
  flake.homeModules.screenUtils =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.woomer ];
    };
}
