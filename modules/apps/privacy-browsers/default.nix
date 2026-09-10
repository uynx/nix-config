{
  flake.homeModules.privacyBrowsers =
    { pkgs, lib, ... }:
    let
      update-privacy-browsers = pkgs.writers.writeDashBin "update-privacy-browsers" ''
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

        base=https://dist.torproject.org
        file=$HOME/nix-config/modules/apps/privacy-browsers/pins.json
        skipped=0

        versions() {
          curl -fsSL --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 10 --max-time 30 "$base/$1/" \
            | sed -n 's|.*href="\([0-9][^"/]*\)/".*|\1|p' \
            | sort -Vr
        }

        arm_url() {
          echo "$base/$1/$3/$2-linux-aarch64-$3.tar.xz"
        }

        has_arm() {
          curl -fsI --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 10 --max-time 30 -o /dev/null \
            "$(arm_url "$1" "$2" "$3")"
        }

        newest_arm() {
          for v in $(versions "$1" || true); do
            if [ -n "''${2:-}" ] && ! echo "$v" | grep -Eq '^[0-9]+(\.[0-9]+)*$'; then
              continue
            fi
            if has_arm "$1" "$3" "$v"; then
              echo "$v"
              return 0
            fi
          done
        }

        bump() {
          name=$1 dist=$2 prefix=$3

          current=$(jq -r --arg n "$name" '.[$n].version // ""' "$file")
          if [ -z "$current" ]; then
            printf '%-16s FAILED (no pin in %s)\n' "$name" "$file"
            skipped=$((skipped + 1))
            return 0
          fi

          latest=$(newest_arm "$dist" "" "$prefix" || true)
          if [ -z "$latest" ]; then
            printf '%-16s SKIPPED (no aarch64 build listed)\n' "$name"
            skipped=$((skipped + 1))
          elif [ "$current" = "$latest" ]; then
            printf '%-16s %s (up to date)\n' "$name" "$current"
          else
            raw=$(nix-prefetch-url --type sha256 "$(arm_url "$dist" "$prefix" "$latest")") || {
              printf '%-16s SKIPPED (prefetch failed)\n' "$name"
              skipped=$((skipped + 1))
              return 0
            }
            hash=$(nix hash convert --hash-algo sha256 --to sri "$raw")

            tmp=$(mktemp)
            jq --arg n "$name" --arg v "$latest" --arg h "$hash" \
              '.[$n] = { version: $v, hash: $h }' "$file" >"$tmp"
            mv "$tmp" "$file"
            printf '%-16s %s -> %s\n' "$name" "$current" "$latest"
          fi

          stable=$(newest_arm "$dist" stable "$prefix" || true)
          if [ -n "$stable" ]; then
            printf '\n  ***  %s: an aarch64 STABLE build now exists (%s).\n' "$name" "$stable"
            printf '  ***  Point its URL at the stable series and leave the alpha.\n\n'
          fi
        }

        bump tor-browser     torbrowser     tor-browser
        bump mullvad-browser mullvadbrowser mullvad-browser

        if [ "$skipped" -gt 0 ]; then
          echo "$skipped not updated this run — rerun to retry."
        fi
      '';
    in
    {
      home.packages =
        if pkgs.stdenv.hostPlatform.isAarch64 then
          [
            (pkgs.callPackage ./_tor-browser.nix { })
            (pkgs.callPackage ./_mullvad-browser.nix { })
            update-privacy-browsers
          ]
        else
          with pkgs;
          [
            tor-browser
            mullvad-browser
          ];

      shellHooks.update = lib.optional pkgs.stdenv.hostPlatform.isAarch64 "update-privacy-browsers";
    };
}
