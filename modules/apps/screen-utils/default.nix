{
  # showmethekey has to be a system package, not a home one: it ships a polkit
  # policy to read /dev/input, and polkit only reads policies out of the system
  # profile. In home.packages the binary installs but input access silently
  # fails. Preferred over wshowkeys, which is unmaintained since 2021 and wants
  # a setuid wrapper instead.
  flake.nixosModules.screenUtils =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.showmethekey ];
    };

  # Wayland zoom. Uses zwlr_screencopy_manager_v1, which niri implements.
  flake.homeModules.screenUtils =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.woomer ];
    };
}
