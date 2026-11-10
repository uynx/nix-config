{
  flake.darwinModules.brave =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.brave ];
    };

  flake.homeModules.braveShortcuts =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      bravePrefs = pkgs.writeShellApplication {
        name = "brave-prefs";
        runtimeInputs = [
          pkgs.jq
          pkgs.coreutils
        ];
        text = builtins.readFile ./prefs/apply.sh;
      };
      home = "${config.home.homeDirectory}/Library/Application Support/BraveSoftware";
    in
    {
      home.activation.bravePrefs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${bravePrefs}/bin/brave-prefs "${home}/Brave-Browser" \
          "${./prefs/personal.json}:Default/Preferences" "${./prefs/local-state.json}:Local State"
        run ${bravePrefs}/bin/brave-prefs "${home}/Brave-Browser-School" \
          "${./prefs/school.json}:Default/Preferences" "${./prefs/local-state.json}:Local State"
      '';

      xdg.configFile."yt-dlp/config".text = "--cookies-from-browser brave\n";

      home.sessionVariables.AGENT_BROWSER_EXECUTABLE_PATH = "/Applications/Nix Apps/Brave Browser.app/Contents/MacOS/Brave Browser";

      targets.darwin.defaults."com.brave.Browser".NSUserKeyEquivalents = {
        "Close Window" = "~w";
        "Quit Brave" = "@q";
        "Quit Brave Browser" = "@q";
      };
    };
}
