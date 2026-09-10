{
  flake.homeModules.braveOrigin =
    { pkgs, lib, ... }:
    let
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
        file=$HOME/nix-config/modules/apps/brave-origin/pins.json

        current=$(jq -r .version "$file")
        latest=$(curl -fsSL --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 10 --max-time 60 \
          "$base/dists/stable/main/binary-arm64/Packages" \
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

      shellHooks.update = [ "update-brave-origin" ];

      programs.chromium = {
        enable = true;
        package = pkgs.callPackage ./_brave-origin.nix { };
      };

      xdg.configFile."mimeapps.list".force = true;
      xdg.dataFile."applications/mimeapps.list".force = true;

      xdg.mimeApps = {
        enable = true;
        defaultApplications = lib.genAttrs [
          "text/html"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
          "x-scheme-handler/about"
          "x-scheme-handler/unknown"
        ] (_: "brave-origin.desktop");
      };
    };
}
