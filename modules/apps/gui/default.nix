{
  flake.homeModules.gui =
    { pkgs, ... }:
    let
      pkgsX86 = import pkgs.path {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
    in
    {
      home.packages = [
        pkgs.obsidian
        pkgs.libreoffice
        pkgs.qbittorrent
        pkgs.wireshark
        pkgs.proton-pass-cli
        pkgs.whatsapp-electron
        pkgsX86.mullvad-browser
        pkgsX86.tor-browser
      ];
      home.sessionVariables.PROTON_PASS_KEY_PROVIDER = "fs";
    };
}
