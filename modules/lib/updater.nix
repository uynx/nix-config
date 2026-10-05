{ lib, ... }:
let
  shellFns = {
    fetch = ''
      fetch() {
        curl -fsSL --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 10 --max-time 60 "$@"
      }
    '';

    sri = ''
      sri() {
        nix hash convert --hash-algo sha256 --to sri "$(nix-prefetch-url --type sha256 "$1")"
      }
    '';

    jqWrite = ''
      jq_write() {
        local out=$1 tmp
        shift
        tmp=$(mktemp)
        jq "$@" >"$tmp"
        mv "$tmp" "$out"
      }
    '';

    report = ''
      report() {
        if [ "$2" = "$3" ]; then
          printf '%-16s %s (up to date)\n' "$1" "$2"
        else
          printf '%-16s %s -> %s\n' "$1" "$2" "$3"
        fi
      }
    '';
  };
in
{
  flake.lib = {
    inherit shellFns;

    mkUpdater =
      pkgs:
      {
        name,
        inputs ? [ ],
        text,
      }:
      pkgs.writers.writeDashBin name ''
        set -eu
        export PATH=${
          lib.makeBinPath (
            with pkgs;
            [
              coreutils
              curl
              jq
              nix
            ]
            ++ inputs
          )
        }

        ${lib.concatStrings (lib.attrValues shellFns)}
        ${text}
      '';
  };
}
