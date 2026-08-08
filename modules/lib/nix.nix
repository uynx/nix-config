{ self, ... }:
{
  # Read as `self.lib.caches`. The same two binary caches on both platforms —
  # only the option names differ, since determinate owns nix.conf on macOS and
  # refuses the plain `nix.settings` keys. Stated once so adding a cachix is
  # one edit rather than two files that silently drift apart.
  flake.lib.caches = {
    substituters = [
      "https://nix-community.cachix.org"
      "https://numtide.cachix.org"
    ];
    publicKeys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "numtide.cachix.org-1:2ps1kLBUWnL9yCkD69XfYIa2VclDuxsBeE266mGrW0o="
    ];
  };

  # `nix run uynx#btop` from any directory, no flake path needed. Takes the home
  # directory because the two platforms disagree about where it is.
  flake.lib.selfRegistry = home: {
    ${self.lib.user.name}.to = {
      type = "git";
      url = "file://${home}/nixos-config";
    };
  };
}
