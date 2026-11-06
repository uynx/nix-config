{ self, inputs, ... }:
{
  flake.darwinConfigurations.darwin = inputs.nix-darwin.lib.darwinSystem {
    specialArgs = { inherit inputs; };
    modules = with self.darwinModules; [
      core
      homeManagerBase

      desktopMacos
      shell
      programming
      ai
      privacy
      web
      siteBlock
      media
      comms
      office
      latex
      prismlauncher

      secrets
      cloud

      {
        networking = {
          hostName = "MacBook-Pro";
          computerName = "MacBook-Pro";
        };
        nixpkgs.hostPlatform = "aarch64-darwin";
      }
    ];
  };
}
