{
  # These are repackaged Linux tarballs in _tor-browser.nix / _mullvad-browser.nix;
  # macOS gets the vendors' signed builds instead. Named for this directory, not
  # for the bundle that imports it — Obscura's own cask is in apps/obscura.
  flake.darwinModules.privacyBrowsers = {
    homebrew.casks = [
      "tor-browser"
      "mullvad-browser"
    ];
  };
}
