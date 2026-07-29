{
  flake.nixosModules.user = { pkgs, ... }: {
    programs.fish.enable = true;
    users.users.uynx = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
        "audio"
        "docker"
        "kvm"
      ];
      shell = pkgs.fish;
    };
  };
}
