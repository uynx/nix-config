{
  flake.homeModules.simplex =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      home.packages = [ pkgs.simplex-chat-desktop ];

      xdg.desktopEntries."chat.simplex.app" = {
        name = "SimpleX Chat";
        genericName = "Private messenger";
        exec = "${lib.getExe pkgs.bash} -c \"exec ${lib.getExe pkgs.simplex-chat-desktop} >${config.xdg.cacheHome}/simplex-launch.log 2>&1\"";
        icon = "${pkgs.simplex-chat-desktop}/share/icons/simplex.png";
        terminal = false;
        categories = [
          "Network"
          "Chat"
        ];
      };
    };
}
