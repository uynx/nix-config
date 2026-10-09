{ self, inputs, ... }:
{
  flake.nixosConfigurations.asahi = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    specialArgs = { inherit inputs; };
    modules = with self.nixosModules; [
      core
      hardwareAsahi
      cpuBatteryCap
      homeManagerBase

      # `reb switch` flips ./desktop between niri and kde, then rebuilds and reboots.
      (if builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile ./desktop) == "kde" then desktopKde else desktopNiri)
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
      gaming

      virt

      campus-wifi

      ./_hardware-configuration.nix
      inputs.nixos-apple-silicon.nixosModules.apple-silicon-support

      { networking.hostName = "asahi"; }
      {
        boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
      }
      {
        home-manager.users.${self.lib.user.name}.home.sessionVariables.GSK_RENDERER = "gl";
      }
      {
        home-manager.users.${self.lib.user.name} = {
          # Same as niri: this keyboard has no Print key.
          programs.plasma.shortcuts."services/org.kde.spectacle.desktop" = {
            RectangularRegionScreenShot = inputs.nixpkgs.lib.mkForce [
              "Meta+S"
              "Meta+Shift+S"
            ];
            FullScreenScreenShot = "Meta+Ctrl+S";
          };
        };
      }
    ];
  };
}
