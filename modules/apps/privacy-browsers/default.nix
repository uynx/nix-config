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

      update-privacy-browsers = self.lib.mkUpdater pkgs {
        name = "update-privacy-browsers";
        inputs = [ pkgs.ripgrep ];
        text = ''
          base=https://dist.torproject.org
          file=$HOME/nix-config/modules/apps/privacy-browsers/pins.json
          skipped=0

          url() {
            echo "$base/$1/$3/$2-linux-x86_64-$3.tar.xz"
          }

          newest() {
            fetch "$base/$1/" \
              | rg -o -r '$1' 'href="([0-9][0-9.]*)/"' \
              | sort -Vr \
              | while read -r v; do
                if fetch -I -o /dev/null "$(url "$1" "$2" "$v")" 2>/dev/null; then
                  echo "$v"
                  break
                fi
              done
          }

          skip() {
            printf '%-16s SKIPPED (%s)\n' "$1" "$2"
            skipped=$((skipped + 1))
          }

          bump() {
            name=$1 dist=$2

            current=$(jq -r --arg n "$name" '.[$n].version' "$file")
            latest=$(newest "$dist" "$name" || true)
            if [ -z "$latest" ]; then
              skip "$name" "no x86_64 stable build listed"
              return 0
            fi

            if [ "$current" != "$latest" ]; then
              if ! hash=$(sri "$(url "$dist" "$name" "$latest")"); then
                skip "$name" "prefetch failed"
                return 0
              fi
              jq_write "$file" --arg n "$name" --arg v "$latest" --arg h "$hash" \
                '.[$n] = { version: $v, hash: $h }' "$file"
            fi
            report "$name" "$current" "$latest"
          }

          bump tor-browser     torbrowser
          bump mullvad-browser mullvadbrowser

          if [ "$skipped" -gt 0 ]; then
            echo "$skipped not updated this run — rerun to retry."
          fi
        '';
      };
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
