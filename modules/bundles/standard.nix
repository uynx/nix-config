{ self, ... }:
{
  # Everything a new NixOS host gets by default; hosts add hardware, a desktop and gaming.
  flake.nixosModules.standard = {
    imports = with self.nixosModules; [
      core
      homeManagerBase
      userPassword
      shell
      programming
      ai
      secrets
      privacy
      cloud
      web
      media
      comms
      office
      latex
      virt
      prismlauncher
      campus-wifi
    ];
  };
}
