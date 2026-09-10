{
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
