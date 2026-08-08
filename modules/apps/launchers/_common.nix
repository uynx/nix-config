{
  # The two launchers diverge on how a window is found and how the browser is
  # started; they agree on which profile is which and how Brave is hardened.
  # Underscore-prefixed so import-tree skips it — this is not a module.

  # Expects the caller to have set $braveHome, since the two platforms keep
  # their profiles under different roots. Sets $name and $data, and consumes
  # the profile argument.
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
    # Strict fingerprinting is absent from brave://settings/shields until this
    # feature is enabled; it is what masks the WebGL vendor/renderer string
    # that Standard leaves untouched. Still has to be selected by hand, once
    # per --user-data-dir.
    "--enable-features=BraveShowStrictFingerprintingMode"
    "--disable-breakpad"
    "--no-pings"
    "--disable-domain-reliability"
    "--disable-background-networking"
    "--no-default-browser-check"
    "--no-first-run"
  ];
}
