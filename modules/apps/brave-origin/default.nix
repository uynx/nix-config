{ self, ... }:
{
  flake.homeModules.braveOrigin =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      bravePrefs = pkgs.writeShellApplication {
        name = "brave-prefs";
        runtimeInputs = [
          pkgs.jq
          pkgs.coreutils
        ];
        text = builtins.readFile ./prefs/apply.sh;
      };
      update-brave-origin = self.lib.mkUpdater pkgs {
        name = "update-brave-origin";
        inputs = [ pkgs.ripgrep ];
        text = ''
          base=https://brave-browser-apt-release.s3.brave.com
          file=$HOME/nix-config/modules/apps/brave-origin/pins.json

          current=$(jq -r .version "$file")
          latest=$(fetch "$base/dists/stable/main/binary-arm64/Packages" \
            | rg -A20 '^Package: brave-origin$' \
            | rg -o -r '$1' '^Version: ([0-9.]+)' \
            | sort -V \
            | tail -n1 || true)

          if [ -z "$latest" ]; then
            echo "brave-origin: no version in the package index" >&2
            exit 1
          fi

          if [ "$current" != "$latest" ]; then
            deb() { sri "$base/pool/main/b/brave-origin/brave-origin_''${latest}_$1.deb"; }
            arm64=$(deb arm64)
            amd64=$(deb amd64)
            jq_write "$file" -n --arg v "$latest" --arg a "$arm64" --arg x "$amd64" \
              '{ version: $v, arm64: $a, amd64: $x }'
          fi
          report brave-origin "$current" "$latest"
        '';
      };
    in
    {
      home.packages = [ update-brave-origin ];

      shellHooks.update = [ "update-brave-origin" ];

      # Settings pages are blocked by policy, so these snapshots are the only way settings reach a machine.
      home.activation.bravePrefs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${bravePrefs}/bin/brave-prefs "${config.home.homeDirectory}/.config/BraveSoftware/Brave-Browser" \
          "${./prefs/personal.json}:Default/Preferences" \
          "${./prefs/school.json}:Profile 1/Preferences" \
          "${./prefs/local-state.json}:Local State"
      '';

      programs.chromium = {
        enable = true;
        package = pkgs.callPackage ./_brave-origin.nix { };
      };

      xdg = {
        configFile."mimeapps.list".force = true;
        configFile."yt-dlp/config".text = "--cookies-from-browser brave+gnomekeyring\n";
        dataFile."applications/mimeapps.list".force = true;

        mimeApps = {
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
    };
}
