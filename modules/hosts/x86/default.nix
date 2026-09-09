{ self, inputs, ... }:
{
  # Reads like the asahi host on purpose: same bundle names, one line per
  # component. Differs only where the hardware does — `gamingNative` instead
  # of `gaming` (that one's the Fedora/FEX container that exists solely
  # because asahi is 16 KiB-page aarch64) and no `campus-wifi` (this machine
  # never leaves the house).
  flake.nixosConfigurations.x86 = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = with self.nixosModules; [
      core
      hardwareX86
      homeManagerBase

      desktopNiri
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

      # Generated on the machine during install and copied in here, exactly as
      # REINSTALL.md does it for asahi.
      ./_hardware-configuration.nix

      { networking.hostName = "x86"; }
    ];
  };
}
