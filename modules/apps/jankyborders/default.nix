{
  flake.homeModules.jankyborders = {
    services.jankyborders = {
      enable = true;
      settings = {
        style = "round";
        width = 4.0;
        hidpi = "on";
        active_color = "0xffffffff";
        inactive_color = "0x00000000";
      };
    };
  };
}
