{
  # Desktop apps only — both CLIs come from nixpkgs on either platform.
  flake.darwinModules.passwordsCasks = {
    homebrew.casks = [
      "bitwarden"
      "proton-pass"
    ];
  };
}
