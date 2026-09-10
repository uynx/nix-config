{
  pickProfile = ''
    name=''${1:-}
    case "$name" in
      Personal) data="$braveHome/Brave-Browser" ;;
      School)   data="$braveHome/Brave-Browser-School" ;;
      *) echo "usage: brave-activation Personal|School" >&2; exit 1 ;;
    esac
    shift
  '';

  hardening = builtins.concatStringsSep " " [
    "--enable-features=BraveShowStrictFingerprintingMode"
    "--disable-breakpad"
    "--no-pings"
    "--disable-domain-reliability"
    "--disable-background-networking"
    "--no-default-browser-check"
    "--no-first-run"
  ];
}
