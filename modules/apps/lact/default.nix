{
  flake.nixosModules.lact =
    { config, ... }:
    {
      services.lact.enable = true;

      # Written literally, not via services.lact.settings: that renders integer keys as strings and lactd refuses the config.
      environment.etc."lact/config.yaml".text = ''
        version: 7
        daemon:
          log_level: info
          admin_group: wheel
          disable_clocks_cleanup: false
        apply_settings_timer: 5
        gpus:
          10DE:1B81-3842:5173-0000:01:00.0:
            fan_control_enabled: true
            fan_control_settings:
              mode: curve
              static_speed: 0.5
              temperature_key: edge
              interval_ms: 500
              curve:
                40: 0.0
                50: 0.3
                60: 0.45
                70: 0.6
                80: 0.85
                85: 1.0
              spindown_delay_ms: 5000
              change_threshold: 2
            power_mizer_mode: Adaptive
            power_cap: 170.0
            gpu_clock_offsets:
              0: 125
            mem_clock_offsets:
              0: 200
        current_profile: null
        auto_switch_profiles: false
      '';

      systemd.services.lactd.restartTriggers = [ config.environment.etc."lact/config.yaml".source ];
    };
}
