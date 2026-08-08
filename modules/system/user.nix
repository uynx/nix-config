{ self, ... }:
{
  flake.nixosModules.user =
    { pkgs, ... }:
    {
      programs.fish.enable = true;
      users.users.${self.lib.user.name} = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "networkmanager"
          "video"
          "audio"
          "kvm"
        ];
        shell = pkgs.fish;
      };
    };
}
