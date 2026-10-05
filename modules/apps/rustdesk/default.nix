{ self, ... }:
{
  flake.homeModules.rustdesk =
    { pkgs, ... }:
    let
      pin = builtins.fromJSON (builtins.readFile ./pins.json);
      host = pkgs.stdenv.hostPlatform;

      rustdesk = pkgs.stdenv.mkDerivation {
        pname = "rustdesk";
        inherit (pin) version;
        src = pkgs.fetchurl {
          url = "https://github.com/rustdesk/rustdesk/releases/download/${pin.version}/rustdesk-${pin.version}-${host.parsed.cpu.name}.deb";
          hash = pin.hash.${host.system};
        };
        nativeBuildInputs = with pkgs; [
          dpkg
          autoPatchelfHook
        ];
        buildInputs = with pkgs; [
          atk
          cairo
          dbus
          gdk-pixbuf
          glib
          gst_all_1.gst-plugins-base
          gst_all_1.gstreamer
          gtk3
          libepoxy
          libpulseaudio
          libx11
          libxcb
          libxfixes
          libxkbcommon
          libxtst
          pango
          stdenv.cc.cc.lib
          wayland
        ];
        runtimeDependencies = with pkgs; [
          libayatana-appindicator
          libva
          xdotool
        ];
        unpackCmd = "dpkg-deb -x $src source";
        dontStrip = true;
        installPhase = ''
          mkdir -p $out/bin
          cp -r usr/share $out/share
          ln -s $out/share/rustdesk/rustdesk $out/bin/rustdesk
        '';
      };

      update-rustdesk = self.lib.mkUpdater pkgs {
        name = "update-rustdesk";
        text = ''
          file=$HOME/nix-config/modules/apps/rustdesk/pins.json

          deb() { echo "https://github.com/rustdesk/rustdesk/releases/download/$1/rustdesk-$1-$2.deb"; }

          current=$(jq -r .version "$file")
          latest=$(fetch https://api.github.com/repos/rustdesk/rustdesk/releases/latest | jq -r .tag_name)

          if [ "$current" != "$latest" ]; then
            if ! arm=$(sri "$(deb "$latest" aarch64)") || ! x86=$(sri "$(deb "$latest" x86_64)"); then
              printf '%-16s SKIPPED (prefetch failed)\n' rustdesk
              exit 0
            fi
            jq_write "$file" -n --arg v "$latest" --arg a "$arm" --arg x "$x86" \
              '{ version: $v, hash: { "aarch64-linux": $a, "x86_64-linux": $x } }'
          fi
          report rustdesk "$current" "$latest"
        '';
      };
    in
    {
      home.packages = [
        rustdesk
        update-rustdesk
      ];

      shellHooks.update = [ "update-rustdesk" ];
    };
}
