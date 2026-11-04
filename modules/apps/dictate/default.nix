{ self, ... }:
{
  flake.homeModules.dictate =
    { pkgs, ... }:
    let
      pin = builtins.fromJSON (builtins.readFile ./pins.json);
      py = pkgs.python3Packages;
      fermion = py.buildPythonPackage {
        pname = "fermion-research";
        inherit (pin.wheel) version;
        format = "wheel";
        src = pkgs.fetchurl { inherit (pin.wheel) url hash; };
        dependencies = with py; [
          torch
          transformers
          numpy
          huggingface-hub
          soundfile
          scipy
          zstandard
          safetensors
        ];
        # The loader checks its prebuilt .so files against pinned SHA-256s, so nothing may rewrite them.
        dontStrip = true;
        dontPatchELF = true;
      };
      phononArchive = pkgs.fetchurl { inherit (pin.model) url hash; };
      update-phonon = self.lib.mkUpdater pkgs {
        name = "update-phonon";
        text = ''
          file=$HOME/nix-config/modules/apps/dictate/pins.json
          to_sri() { nix hash convert --hash-algo sha256 --to sri "$1"; }

          meta=$(fetch https://pypi.org/pypi/fermion-research/json)
          wheel=$(printf '%s' "$meta" | jq -e '[.urls[] | select(.filename | endswith("-py3-none-any.whl"))][0]')
          rev=$(fetch https://huggingface.co/api/models/FermionResearch/Phonon-2 | jq -er .sha)
          archive=$(fetch "https://huggingface.co/FermionResearch/Phonon-2/raw/$rev/config.json" | jq -er .artifact.sha256)

          current=$(jq -r .wheel.version "$file" 2>/dev/null || echo none)
          latest=$(printf '%s' "$meta" | jq -er .info.version)
          jq_write "$file" -n \
            --arg v "$latest" --argjson w "$wheel" --arg wh "$(to_sri "$(printf '%s' "$wheel" | jq -r .digests.sha256)")" \
            --arg r "$rev" --arg mh "$(to_sri "$archive")" \
            '{ wheel: { version: $v, url: $w.url, hash: $wh },
               model: { rev: $r, url: "https://huggingface.co/FermionResearch/Phonon-2/resolve/\($r)/phonon-2.bps.tar.zst", hash: $mh } }'
          report phonon "$current" "$latest"
        '';
      };
      phononModel = pkgs.runCommand "phonon-2" { nativeBuildInputs = [ pkgs.zstd ]; } ''
        mkdir -p $out/model_phonon2_c4c_int6
        tar --zstd -xf ${phononArchive} -C $out/model_phonon2_c4c_int6
      '';
      port = "8765";
      desktopItem = pkgs.makeDesktopItem {
        name = "dictate";
        desktopName = "Dictation";
        exec = "dictate";
        icon = "dictate-mic";
        noDisplay = true;
        extraConfig."X-KDE-Shortcuts" = "Meta+D";
      };
    in
    {
      systemd.user.services.phonon = {
        Unit.Description = "Phonon-2 speech server for dictate";
        Service = {
          ExecStart = "${
            pkgs.python3.withPackages (_: [ fermion ])
          }/bin/fermion serve ${phononModel}/model_phonon2_c4c_int6 --host 127.0.0.1 --port ${port} --served-model-name phonon-2";
          Environment = "HF_HUB_OFFLINE=1";
          Restart = "on-failure";
          MemoryMax = "2G";
        };
        Install.WantedBy = [ "default.target" ];
      };

      shellHooks.update = [ "update-phonon" ];

      xdg.dataFile."icons/hicolor/scalable/apps/dictate-mic.svg".source =
        "${pkgs.papirus-icon-theme}/share/icons/Papirus/64x64/devices/audio-input-microphone.svg";

      programs.plasma.shortcuts."services/dictate.desktop"._launch = "Meta+D";

      home.packages = [
        update-phonon
        desktopItem
        (pkgs.writeShellApplication {
          name = "dictate";
          runtimeInputs = with pkgs; [
            curl
            wl-clipboard
            wtype
            ydotool
            libnotify
            pipewire
            python3
            util-linux
            coreutils
          ];
          text = ''
            pidfile=/tmp/whisper-dictate.pid
            if [ -f "$pidfile" ]; then
              pid=$(cat "$pidfile" || true)
              if [ -n "''${pid:-}" ] && [ -d "/proc/$pid" ]; then
                case $(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null || true) in
                  *dictate_stream*)
                    notify-send "Dictation" "Stopped. Typing the last words..." -i dictate-mic || true
                    kill -TERM "$pid"
                    exit 0
                    ;;
                esac
              fi
              rm -f "$pidfile"
            fi
            setsid flock -n /tmp/whisper-dictate.lock python3 ${./dictate_stream.py} </dev/null >/dev/null 2>&1 &
          '';
        })
        # kglobalaccel binds shortcuts only to desktop files it finds under share/kglobalaccel.
        (pkgs.runCommand "dictate-kglobalaccel" { } ''
          mkdir -p $out/share/kglobalaccel
          ln -s ${desktopItem}/share/applications/dictate.desktop $out/share/kglobalaccel/dictate.desktop
        '')
      ];
    };
}
