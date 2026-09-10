{
  flake.darwinModules.security = {
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
