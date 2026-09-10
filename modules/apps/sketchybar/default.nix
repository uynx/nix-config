{ self, ... }:
{
  flake.darwinModules.sketchybar =
    { pkgs, ... }:
    {
      services.sketchybar = {
        enable = true;
        extraPackages = with pkgs; [
          aerospace
          cava
          jq
          python3
          sqlite
        ];
      };

      launchd.user.agents.weather-watcher.serviceConfig = {
        ProgramArguments = [
          "/bin/bash"
          "-c"
          "/run/current-system/sw/bin/sketchybar --trigger weather_update"
        ];
        WatchPaths = [
          "${self.lib.user.darwinHome}/Library/Containers/com.apple.weather/Data/Library/Caches/com.apple.weather"
        ];
        RunAtLoad = false;
      };
    };

  flake.homeModules.sketchybar =
    { config, ... }:
    {
      home.file.".config/sketchybar".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/sketchybar";
    };
}
