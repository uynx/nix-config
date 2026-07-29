{
  flake.homeModules.gui = { pkgs, ... }: {
    home.packages = with pkgs; [
      obsidian
      libreoffice
      qbittorrent
      wireshark
      proton-vpn
      proton-pass-cli
      whatsapp-electron
    ];
    home.sessionVariables.PROTON_PASS_KEY_PROVIDER = "fs";

  };
}
