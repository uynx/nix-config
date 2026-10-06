_: {
  flake.homeModules.wluma =
    { lib, pkgs, ... }:
    {
      config = lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && pkgs.stdenv.hostPlatform.isAarch64) {
        services.wluma = {
          enable = true;
          settings = {
            als.iio = {
              path = "/sys/bus/iio/devices";
              thresholds = {
                "0" = "night";
                "20" = "dark";
                "80" = "dim";
                "250" = "normal";
                "500" = "bright";
                "800" = "outdoors";
              };
            };
            output.backlight = [
              {
                name = "eDP-1";
                path = "/sys/class/backlight/apple-panel-bl";
                capturer = "none";
              }
            ];
          };
        };
      };
    };
}
