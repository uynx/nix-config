{
  flake.homeModules.ungoogledChromium =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.ungoogled-chromium ];
      home.sessionVariables.AGENT_BROWSER_EXECUTABLE_PATH = "${pkgs.ungoogled-chromium}/bin/chromium";
    };
}
