{ self, ... }:
{
  flake.nixosModules.wireshark =
    { pkgs, ... }:
    {
      programs.wireshark = {
        enable = true;
        package = pkgs.wireshark;
      };
      users.users.${self.lib.user.name}.extraGroups = [ "wireshark" ];
    };

  flake.homeModules.wireshark =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.wireshark ];
    };
}
