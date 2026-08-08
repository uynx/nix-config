{
  # OBS' nixpkgs build is Linux-only; the other two install kernel-level audio
  # components and could never come from nix.
  flake.darwinModules.mediaCasks = {
    homebrew.casks = [
      "obs"
      "streamlabs"
      # Loopback device the status bar's visualiser reads system audio through.
      "blackhole-2ch"
    ];
  };
}
