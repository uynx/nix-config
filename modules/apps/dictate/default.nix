{
  flake.homeModules.dictate =
    { pkgs, ... }:
    let
      py = pkgs.python3Packages;
      fermion = py.buildPythonPackage {
        pname = "fermion-research";
        version = "0.2.9";
        format = "wheel";
        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/0a/32/bc70c7911d1ff1719e3e4a0db95d3bea5228e8249edd2b02dad6bc97fbb4/fermion_research-0.2.9-py3-none-any.whl";
          hash = "sha256-aL01tfKtOXqwICdS7z6g6V2tZNwBmvDzuuvfX5X+MI4=";
        };
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
      phononArchive = pkgs.fetchurl {
        url = "https://huggingface.co/FermionResearch/Phonon-2/resolve/ca1bef26bcd8ef4a7e16d0636d8a77bb25e298ee/phonon-2.bps.tar.zst";
        hash = "sha256-mBJXlbbdpy9cbu6boz0ZgV32XcsYtQo1e/n3PJk1MJ4=";
      };
      phononModel = pkgs.runCommand "phonon-2" { nativeBuildInputs = [ pkgs.zstd ]; } ''
        mkdir -p $out/model_phonon2_c4c_int6
        tar --zstd -xf ${phononArchive} -C $out/model_phonon2_c4c_int6
      '';
    in
    {
      home.packages = [
        (pkgs.writeShellApplication {
          name = "dictate";
          runtimeInputs = with pkgs; [
            (python3.withPackages (_: [ fermion ]))
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
            model=${phononModel}/model_phonon2_c4c_int6

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
              notify-send "Dictation" "Transcribing..." -i microphone-sensitivity-high-symbolic || true

              text=$(HF_HUB_OFFLINE=1 fermion transcribe "$model" "$audio" 2>/dev/null \
                | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
              rm -f "$audio"

              if [ -n "$text" ]; then
                printf '%s' "$text" | wl-copy
                wtype "$text" 2>/dev/null || true
              else
                notify-send "Dictation" "No speech detected" -i dialog-warning-symbolic || true
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
              notify-send "Dictation" "Recording... press Super+D again to finish." -i media-record-symbolic || true
            fi
          '';
        })
      ];
    };
}
