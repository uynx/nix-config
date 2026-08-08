{
  # Both are Electron apps nixpkgs packages for Linux only.
  flake.darwinModules.commsCasks = {
    homebrew.casks = [
      "vesktop"
      "whatsapp"
    ];
  };
}
