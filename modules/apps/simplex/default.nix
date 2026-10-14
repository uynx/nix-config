{
  flake.homeModules.simplex =
    { pkgs, lib, ... }:
    {
      home.packages = [ pkgs.simplex-chat-desktop ];

      xdg.desktopEntries."chat.simplex.app" = {
        name = "SimpleX Chat";
        genericName = "Private messenger";
        exec = lib.getExe pkgs.simplex-chat-desktop;
        icon = "${pkgs.simplex-chat-desktop}/share/icons/simplex.png";
        terminal = false;
        categories = [
          "Network"
          "Chat"
        ];
      };
    };
}
