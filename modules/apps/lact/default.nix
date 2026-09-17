{
  flake.nixosModules.lact = {
    services.lact = {
      enable = true;

      # Populating settings symlinks /etc/lact/config.yaml, so the GUI can no longer save — retune by editing here.
      settings = {
        version = 7;
        apply_settings_timer = 5;
        daemon = {
          log_level = "info";
          admin_group = "wheel";
          disable_clocks_cleanup = false;
        };
        gpus."10DE:1B81-3842:5173-0000:01:00.0" = {
          fan_control_enabled = true;
          fan_control_settings = {
            mode = "curve";
            static_speed = 0.5;
            temperature_key = "edge";
            interval_ms = 500;
            curve = {
              "40" = 0.0;
              "50" = 0.3;
              "60" = 0.45;
              "70" = 0.6;
              "80" = 0.85;
              "85" = 1.0;
            };
            spindown_delay_ms = 5000;
            change_threshold = 2;
          };
          power_mizer_mode = "Adaptive";
          power_cap = 170.0;
          gpu_clock_offsets."0" = 125;
          mem_clock_offsets."0" = 200;
        };
      };
    };
  };
}
