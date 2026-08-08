{
  # Bitwarden only. Proton Pass stays on the Linux side for now; if it moves
  # over, the cask goes here and the `isLinux` guards in ./default.nix go.
  flake.darwinModules.passwords = {
    homebrew.casks = [ "bitwarden" ];
  };
}
