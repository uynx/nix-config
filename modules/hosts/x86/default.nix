{ self, inputs, ... }:
{
  flake.nixosConfigurations.x86 = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = with self.nixosModules; [
      core
      hardwareX86
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

      virt
      gamingNative

      campus-wifi

      ./_hardware-configuration.nix

      { networking.hostName = "x86"; }
      {
        boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
      }
    ];
  };
}
