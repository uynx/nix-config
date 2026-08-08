{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = with self.homeModules; [
      dev
      git
      nvim
    ];
    # Wireshark is a system module on NixOS — packet capture needs a setuid
    # wrapper and a group — and a plain app on macOS.
    nixos = [ self.nixosModules.wireshark ];
    # colima is the container runtime on macOS, where there is no host Docker.
    homeDarwin = with self.homeModules; [
      colima
      wireshark
    ];
  };
in
{
  # Language toolchains, git and the editor. Portable.
  flake.nixosModules.programming = bundle.nixos;
  flake.darwinModules.programming = bundle.darwin;
}
