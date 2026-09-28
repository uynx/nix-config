{ self, ... }:
{
  flake.homeModules.privacyBrowsers =
    { pkgs, lib, ... }:
    let
      pins = builtins.fromJSON (builtins.readFile ./pins.json);

      browser =
        name: dist:
        pkgs.stdenvNoCC.mkDerivation {
          pname = name;
          inherit (pins.${name}) version;
          src = pkgs.fetchurl {
            url = "https://dist.torproject.org/${dist}/${pins.${name}.version}/${name}-linux-x86_64-${pins.${name}.version}.tar.xz";
            inherit (pins.${name}) hash;
          };
          dontFixup = true;
          installPhase = ''
            cp -r Browser $out
            touch $out/is-packaged-app
            substituteInPlace $out/fonts/fonts.conf \
              --replace-fail '<dir prefix="cwd">fonts</dir>' "<dir>$out/fonts</dir>"
            if [ -f $out/TorBrowser/Tor/torrc-defaults ]; then
              substituteInPlace $out/TorBrowser/Tor/torrc-defaults \
                --replace-fail './TorBrowser' "$out/TorBrowser"
            fi
          '';
        };

      # start-*-browser greps the VM's ARM /proc/cpuinfo for sse2 and quits, so exec the binary itself
      entry = pkg: exe: name: {
        inherit name;
        exec = "env FONTCONFIG_FILE=${pkg}/fonts/fonts.conf ${pkg}/${exe}";
        icon = "${pkg}/browser/chrome/icons/default/default128.png";
      };

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

        url() {
          echo "$base/$1/$3/$2-linux-x86_64-$3.tar.xz"
        }

        newest() {
          curl -fsSL --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 10 --max-time 30 "$base/$1/" \
            | sed -n 's|.*href="\([0-9][0-9.]*\)/".*|\1|p' \
            | sort -Vr \
            | while read -r v; do
              if curl -fsI --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 10 --max-time 30 \
                -o /dev/null "$(url "$1" "$2" "$v")"; then
                echo "$v"
                break
              fi
            done
        }

        bump() {
          name=$1 dist=$2

          current=$(jq -r --arg n "$name" '.[$n].version' "$file")
          latest=$(newest "$dist" "$name" || true)
          if [ -z "$latest" ]; then
            printf '%-16s SKIPPED (no x86_64 stable build listed)\n' "$name"
            skipped=$((skipped + 1))
            return 0
          fi
          if [ "$current" = "$latest" ]; then
            printf '%-16s %s (up to date)\n' "$name" "$current"
            return 0
          fi

          raw=$(nix-prefetch-url --type sha256 "$(url "$dist" "$name" "$latest")") || {
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
        }

        bump tor-browser     torbrowser
        bump mullvad-browser mullvadbrowser

        if [ "$skipped" -gt 0 ]; then
          echo "$skipped not updated this run — rerun to retry."
        fi
      '';
    in
    {
      imports = [ self.homeModules.x86Emu ];

      home.packages =
        if pkgs.stdenv.hostPlatform.isAarch64 then
          [ update-privacy-browsers ]
        else
          with pkgs;
          [
            tor-browser
            mullvad-browser
          ];

      shellHooks.update = lib.optional pkgs.stdenv.hostPlatform.isAarch64 "update-privacy-browsers";

      x86Apps = lib.mkIf pkgs.stdenv.hostPlatform.isAarch64 {
        tor-browser = entry (browser "tor-browser" "torbrowser") "firefox" "Tor Browser";
        mullvad-browser =
          entry (browser "mullvad-browser" "mullvadbrowser") "mullvadbrowser"
            "Mullvad Browser";
      };
    };
}
