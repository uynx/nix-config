{
  flake.darwinModules.brave =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.brave ];
    };

  flake.homeModules.braveShortcuts = {
    xdg.configFile."yt-dlp/config".text = "--cookies-from-browser brave\n";

    home.sessionVariables.AGENT_BROWSER_EXECUTABLE_PATH = "/Applications/Nix Apps/Brave Browser.app/Contents/MacOS/Brave Browser";

    targets.darwin.defaults."com.brave.Browser".NSUserKeyEquivalents = {
      "Close Window" = "~w";
      "Quit Brave" = "@q";
      "Quit Brave Browser" = "@q";
    };
  };
}
