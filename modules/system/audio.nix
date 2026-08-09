{
  flake.nixosModules.audio = {
    # Without it pipewire runs at normal priority and drops buffers under load.
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
  };
}
