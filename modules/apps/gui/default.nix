{
  flake.homeModules.gui =
    { pkgs, ... }:
    let
      tor-browser = pkgs.callPackage ./_tor-browser.nix { };
      mullvad-browser = pkgs.callPackage ./_mullvad-browser.nix { };
    in
    {
      home.packages = [
        pkgs.obsidian
        pkgs.libreoffice
        pkgs.qbittorrent
        pkgs.wireshark
        pkgs.proton-pass-cli
        pkgs.bitwarden-desktop
        pkgs.bitwarden-cli
        pkgs.whatsapp-electron
        mullvad-browser
        tor-browser
      ];
      home.sessionVariables.PROTON_PASS_KEY_PROVIDER = "fs";
    };
}
