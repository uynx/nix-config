{ self, inputs, ... }:
{
  # Reads like the asahi host on purpose: same bundle names, one line per
  # component. Differs only where the hardware does — no `gaming` (that bundle
  # is the Fedora/FEX container that exists solely because asahi is 16 KiB-page
  # aarch64; native Steam is the x86 answer and is not written yet) and no
  # `eduroam` (this machine never leaves the house).
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

      # Generated on the machine during install and copied in here, exactly as
      # REINSTALL.md does it for asahi. Uncomment once that file exists.
      # ./_hardware-configuration.nix

      { networking.hostName = "x86"; }
    ];
  };
}
