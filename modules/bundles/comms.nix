{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = [ self.homeModules.comms ];
  };
in
{
  # Chat clients. Both platforms take theirs from nixpkgs; the module picks the
  # right WhatsApp and leaves Vesktop off macOS.
  flake.nixosModules.comms = bundle.nixos;
  flake.darwinModules.comms = bundle.darwin;
}
