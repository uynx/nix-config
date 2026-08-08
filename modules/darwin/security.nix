{
  # The darwin twin of `system/security.nix`. macOS exposes far less than the
  # sysctl surface there — the application firewall, the lock screen and the
  # login window are the whole of what nix-darwin can assert.
  flake.darwinModules.security = {
    # If AirDrop stops working while the firewall is on, allow rapportd by hand:
    #   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/libexec/rapportd
    #   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /usr/libexec/rapportd
    networking.applicationFirewall = {
      enable = true;
      enableStealthMode = true;
    };

    system.defaults = {
      screensaver = {
        askForPassword = true;
        askForPasswordDelay = 0;
      };

      loginwindow = {
        GuestEnabled = false;
        DisableConsoleAccess = true;
      };
    };
  };
}
