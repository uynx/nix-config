{
  flake.homeModules.mangohud =
    { pkgs, lib, ... }:
    {
      programs.mangohud = {
        enable = true;
        settings = {
          toggle_hud = "Shift_R+F12";
          position = "top-left";
          fps = true;
          frametime = true;
          frame_timing = true;
          gpu_stats = true;
          gpu_temp = true;
          gpu_core_clock = true;
          vram = true;
          cpu_stats = true;
          cpu_temp = true;
          ram = true;
        };
      };
}
