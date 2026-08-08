{
  # Brave Origin is built here from the Debian arm64 package, which leaves macOS
  # with ordinary Brave.
  flake.darwinModules.webCasks = {
    homebrew.casks = [ "brave-browser" ];
  };

  # Process isolation is per --user-data-dir, so the shortcuts differ from Linux:
  #   Cmd+W     close tab (browser default)
  #   Option+W  close window (other windows and the other instance keep running)
  #   Cmd+Q     quit *this* instance only
  flake.homeModules.braveShortcuts = {
    targets.darwin.defaults."com.brave.Browser".NSUserKeyEquivalents = {
      "Close Window" = "~w";
      "Quit Brave" = "@q";
      "Quit Brave Browser" = "@q";
    };
  };
}
