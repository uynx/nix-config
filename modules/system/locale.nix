{
  flake.nixosModules.locale = {
    time.timeZone = "America/New_York";
    console.useXkbConfig = true;
    services.xserver.xkb = {
      layout = "us";
      options = "caps:escape";
    };
  };
}
