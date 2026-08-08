{
  flake.homeModules.braveOrigin =
    { pkgs, lib, ... }:
    let
      # dash, not writeShellApplication: nothing here needs bash, and the Python
      # this replaced spent more lines dodging writePython3Bin's PEP8 check than
      # doing the job. Same shape as `update-ai-clis`' `bump` on purpose.
      update-brave-origin = pkgs.writers.writeDashBin "update-brave-origin" ''
        set -eu
        export PATH=${
          lib.makeBinPath (
            with pkgs;
            [
              coreutils
              curl
              gnugrep
              gnused
              jq
              nix
            ]
          )
        }

        base=https://brave-browser-apt-release.s3.brave.com
        file=$HOME/nixos-config/modules/apps/brave-origin/pins.json

        current=$(jq -r .version "$file")
        latest=$(curl -fsSL "$base/dists/stable/main/binary-arm64/Packages" \
          | grep -A20 '^Package: brave-origin$' \
          | sed -n 's/^Version: \([0-9.]*\).*/\1/p' \
          | head -1)

        if [ -z "$latest" ]; then
          echo "brave-origin: no version in the package index" >&2
          exit 1
        fi
        if [ "$current" = "$latest" ]; then
          printf '%-12s %s (up to date)\n' brave-origin "$current"
          exit 0
        fi

        # Both hashes are fetched before anything is written, so a failed fetch
        # leaves the old pair intact rather than a mixed one. Keys are the Debian
        # arch names, which _brave-origin.nix indexes directly.
        hash_for() {
          nix hash convert --hash-algo sha256 --to sri \
            "$(nix-prefetch-url --type sha256 \
              "$base/pool/main/b/brave-origin/brave-origin_''${latest}_$1.deb")"
        }
        arm64=$(hash_for arm64)
        amd64=$(hash_for amd64)

        tmp=$(mktemp)
        jq -n --arg v "$latest" --arg a "$arm64" --arg x "$amd64" \
          '{ version: $v, arm64: $a, amd64: $x }' >"$tmp"
        mv "$tmp" "$file"

        printf '%-12s %s -> %s\n' brave-origin "$current" "$latest"
      '';
    in
    {
      home.packages = [ update-brave-origin ];

      # Registered rather than named by `update` itself: this only exists on a
      # host that took the `web` bundle, and the stub hosts do not.
      shellHooks.update = [ "update-brave-origin" ];

      programs.chromium = {
        enable = true;
        package = pkgs.callPackage ./_brave-origin.nix { };
      };
    };
}
