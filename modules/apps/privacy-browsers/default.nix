{
  flake.homeModules.privacyBrowsers =
    { pkgs, lib, ... }:
    let
      # aarch64 Linux builds of both browsers exist **only in the alpha
      # series** — dist.torproject.org ships 15.0.x stable as x86_64 (plus i686
      # for Tor) and nothing else. An alpha is a small crowd to hide in, so the
      # run ends by probing for a stable aarch64 build and shouting when one
      # finally appears.
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

        # Newest first. The server lists only live releases, so this is a
        # handful of lines rather than the whole archive.
        versions() {
          curl -fsSL --connect-timeout 10 --max-time 30 "$base/$1/" \
            | sed -n 's|.*href="\([0-9][^"/]*\)/".*|\1|p' \
            | sort -Vr
        }

        arm_url() {
          echo "$base/$1/$3/$2-linux-aarch64-$3.tar.xz"
        }

        # A published version does not imply an aarch64 tarball in it, so each
        # candidate is probed rather than assumed. No -S here: a 404 is the
        # expected answer for most probes and must not print as an error.
        has_arm() {
          curl -fsI --connect-timeout 10 --max-time 30 -o /dev/null \
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

        # bump <pin-name> <dist-dir> <tarball-prefix>
        bump() {
          name=$1 dist=$2 prefix=$3

          # Refuse to invent a key: `.[$n] = …` would happily create one, so a
          # typo would add a pin nothing reads instead of failing.
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

            # mktemp + mv, so a pin is either fully updated or untouched.
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

        # Exits 0 even with skips, so `update` still reaches the flake relock.
        if [ "$skipped" -gt 0 ]; then
          echo "$skipped not updated this run — rerun to retry."
        fi
      '';
    in
    {
      # The two derivations beside this file exist only because nixpkgs has no
      # aarch64 build. On x86_64 it has both, on the stable series rather than
      # the alpha these pins are stuck on — so take them and skip the updater,
      # which has nothing left to maintain there.
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

      # Registered rather than named by `update` itself, so a host without these
      # browsers does not get an `update` that calls a missing command.
      shellHooks.update = lib.optional pkgs.stdenv.hostPlatform.isAarch64 "update-privacy-browsers";
    };
}
