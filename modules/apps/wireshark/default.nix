{ self, ... }:
{
  # Not `home.packages`, which is where this lived and where it could never
  # capture: dumpcap needs the setcap'd wrapper and the `wireshark` group that
  # only this option creates. The default package is the CLI; the GUI is the
  # point here.
  flake.nixosModules.wireshark =
    { pkgs, ... }:
    {
      programs.wireshark = {
        enable = true;
        package = pkgs.wireshark;
      };
      users.users.${self.lib.user.name}.extraGroups = [ "wireshark" ];
    };

  # macOS has no equivalent: capture there needs ChmodBPF, installed outside
  # nix by the vendor package. The app alone still reads captures.
  flake.homeModules.wireshark =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.wireshark ];
    };
}
