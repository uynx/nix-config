{
  # Mod+N / Mod+M profile launchers for niri. Split from darwin.nix rather than
  # branched: different browser binary, different window handling, and only
  # Linux has a .desktop file. What the two do share is in _common.nix.
  flake.homeModules.launchers =
    { pkgs, ... }:
    let
      common = import ./_common.nix;

      brave = pkgs.writeShellApplication {
        name = "brave-activation";
        text = ''
          braveHome="''${XDG_CONFIG_HOME:-$HOME/.config}/BraveSoftware"
          ${common.pickProfile}

          # Strict fingerprinting is absent from brave://settings/shields
          # until this feature is enabled; it is what masks the WebGL
          # vendor/renderer string that Standard leaves untouched.
          exec brave-origin \
            --enable-features=BraveShowStrictFingerprintingMode \
            --user-data-dir="$data" \
            --profile-directory=Default \
            ${common.hardening} \
            "$@"
        '';
      };
    in
    {
      home.packages = [ brave ];

      # Same filename shadows the packaged brave-origin.desktop, whose Exec has
      # no --user-data-dir and opens an empty third profile. home.file, not
      # xdg.desktopEntries: ~/.local/share outranks the profile in
      # XDG_DATA_DIRS, so this wins outright instead of relying on the hiPrio
      # collision that desktopEntries resolves it with (apps/steam takes that route).
      home.file.".local/share/applications/brave-origin.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Brave Origin
        GenericName=Web Browser
        Icon=brave-origin
        Exec=brave-activation Personal %U
        Terminal=false
        StartupNotify=true
        StartupWMClass=brave-origin
        Categories=Network;WebBrowser;
        MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/about;x-scheme-handler/unknown;
      '';
    };
}
