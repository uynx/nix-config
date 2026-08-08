{
  # There is no Brave Origin on macOS — ./default.nix builds it from the Debian
  # package, which leaves the Mac with ordinary Brave. Hence `brave`, not
  # `braveOrigin`: it is a different browser, not the same one delivered twice.
  flake.darwinModules.brave = {
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
