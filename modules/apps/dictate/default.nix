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
    in
    {
      systemd.user.services.phonon = {
        Unit.Description = "Phonon-2 speech server for dictate";
        Service = {
          ExecStart = "${pkgs.python3.withPackages (_: [ fermion ])}/bin/fermion serve ${phononModel}/model_phonon2_c4c_int6 --host 127.0.0.1 --port ${port} --served-model-name phonon-2";
          Environment = "HF_HUB_OFFLINE=1";
          Restart = "on-failure";
          MemoryMax = "2G";
        };
        Install.WantedBy = [ "default.target" ];
      };

      shellHooks.update = [ "update-phonon" ];

      xdg.dataFile."icons/hicolor/scalable/apps/dictate-mic.svg".source = ./dictate-mic.svg;

      home.packages = [
        update-phonon
        (pkgs.writeShellApplication {
          name = "dictate";
          runtimeInputs = with pkgs; [
            curl
            wl-clipboard
            wtype
            libnotify
            pipewire
            gnused
            coreutils
          ];
          text = ''
            recordPid=/tmp/whisper-dictate.pid
            audio=/tmp/whisper-dictate.wav
            url=http://127.0.0.1:${port}/v1/audio/transcriptions

            recording=0
            if [ -f "$recordPid" ]; then
              pid=$(cat "$recordPid" || true)
              if [ -n "''${pid:-}" ] && [ -d "/proc/$pid" ]; then
                case $(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null || true) in
                  *pw-record*) recording=1 ;;
                esac
              fi
              [ "$recording" -eq 1 ] || rm -f "$recordPid" "$audio"
            fi

            if [ "$recording" -eq 1 ]; then
              pid=$(cat "$recordPid")
              rm -f "$recordPid"
              kill "$pid" 2>/dev/null || true
              sleep 0.2

              [ -f "$audio" ] || exit 0
              notify-send "Dictation" "Transcribing..." -i dictate-mic || true

              if ! text=$(curl -sf --retry 10 --retry-connrefused --retry-delay 2 --max-time 60 \
                -F file=@"$audio" -F response_format=text "$url" \
                | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'); then
                rm -f "$audio"
                notify-send "Dictation" "The phonon service is not answering" -i dictate-mic || true
                exit 0
              fi
              rm -f "$audio"

              if [ -n "$text" ]; then
                printf '%s' "$text" | wl-copy
                wtype "$text" 2>/dev/null || true
              else
                notify-send "Dictation" "No speech detected" -i dictate-mic || true
              fi
            else
              rm -f "$audio"
              nodes=$(pw-cli ls Node 2>/dev/null || true)
              target=()
              case $nodes in
                *'node.name = "effect_output.j314-mic"'*) target=(--target effect_output.j314-mic) ;;
              esac
              pw-record "''${target[@]}" --format=s16 --rate=16000 --channels=1 "$audio" >/dev/null 2>&1 &
              echo $! > "$recordPid"
              notify-send "Dictation" "Recording... press Super+D again to finish." -i dictate-mic || true
            fi
          '';
        })
      ];
    };
}
