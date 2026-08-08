{
  flake.nixosModules.locale = {
    time.timeZone = "America/Chicago";
    console.useXkbConfig = true;
    # xkb lives under services.xserver even on Wayland; console.useXkbConfig
    # reads it, and the server itself stays off at its own default.
    services.xserver.xkb = {
      layout = "us";
      options = "caps:escape";
    };
  };
}
