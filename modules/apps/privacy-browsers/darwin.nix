{
  # These are repackaged Linux tarballs in _tor-browser.nix / _mullvad-browser.nix;
  # macOS gets the vendors' signed builds instead. Obscura rides along because
  # its NixOS module — the egress lockdown — has no macOS counterpart either.
  flake.darwinModules.privacyCasks = {
    homebrew.casks = [
      "tor-browser"
      "mullvad-browser"
      "obscura-vpn"
    ];
  };
}
