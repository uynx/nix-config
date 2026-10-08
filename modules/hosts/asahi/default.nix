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
          plasmaPinned = [
            "brave-origin.desktop"
            "com.mitchellh.ghostty.desktop"
            "org.kde.dolphin.desktop"
          ];
          plasmaWallpaper = ../../wallpapers/wallpaper.png;
          plasmaShortcuts = {
            ksmserver."Lock Session" = "Screensaver\tMeta+Ctrl+Q,Screensaver\tMeta+L,Lock Session";
            kwin."Window Close" = "Meta+Q\tAlt+F4,Alt+F4,Close Window";
            plasmashell."manage activities" = "none,Meta+Q,Show Activity Switcher";
          };
        };
      }
    ];
  };
}
