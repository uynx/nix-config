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
        # Bounded like every lookup in update-ai-clis, and for the same reason:
        # curl's default connect timeout is 300 s and a stalled transfer has no
        # bound at all, so one unreachable host hangs the whole `update` chain
        # with no output instead of failing.
        latest=$(curl -fsSL --connect-timeout 10 --max-time 60 \
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

      # The default browser. Declared here rather than left to whichever app
      # last wrote mimeapps.list — a hand-set default is invisible on a fresh
      # machine, where links then open in nothing at all.
      # Both copies are overwritten rather than backed up, and that is not
      # optional: apps rewrite these on every launch (Bitwarden recreated both
      # within seconds of a fresh login), so the backup Home Manager takes
      # collides with the one it took last time and **the switch fails** —
      # "would be clobbered by backing up". `xdg.mimeApps` writes the
      # `~/.local/share/applications` copy too, for pre-2014 lookup order.
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
