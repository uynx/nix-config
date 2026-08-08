{
  # Upstream ships a signed .app for macOS, so nothing here is built — and the
  # egress lockdown in ./default.nix has no macOS counterpart at all.
  flake.darwinModules.obscura = {
    homebrew.casks = [ "obscura-vpn" ];
  };
}
