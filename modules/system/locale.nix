{
  flake.nixosModules.locale = {
    time.timeZone = "America/Chicago";
    console.useXkbConfig = true;
    # xkb lives under services.xserver even on Wayland; console.useXkbConfig reads it.
    services.xserver = {
      enable = false;
      xkb = {
        layout = "us";
        options = "caps:escape";
      };
    };
  };
}
