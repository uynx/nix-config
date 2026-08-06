{ self, inputs, ... }:
{
  flake.nixosConfigurations.asahi = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    specialArgs = { inherit inputs; };
    modules = with self.nixosModules; [
      core
      hardwareAsahi
      niri
      sddm
      screenUtils
      steamAsahi
      obscura
      homeManagerBase

      ./_hardware-configuration.nix
      inputs.determinate.nixosModules.default
      inputs.nixos-apple-silicon.nixosModules.apple-silicon-support

      { networking.hostName = "asahi"; }
      {
        home-manager.users.${self.lib.user.name}.imports = with self.homeModules; [
          desktopHome
          programming
          steamAsahi
          {
            home = {
              username = self.lib.user.name;
              homeDirectory = self.lib.user.home;
              stateVersion = "26.05";
              sessionVariables = {
                EDITOR = "nvim";
                VISUAL = "nvim";
                GSK_RENDERER = "gl";
              };
            };
          }
        ];
      }
    ];
  };
}
