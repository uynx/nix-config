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

          exec brave-origin \
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
      # xdg.desktopEntries, precisely because this has to *shadow* something:
      # ~/.local/share outranks the profile unconditionally, where an entry
      # from desktopEntries lands in the same profile as the package and has to
      # win on hiPrio. apps/steam shadows nothing, so it uses the typed option.
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
