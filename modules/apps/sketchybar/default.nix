{ self, ... }:
{
  # Status bar framing the notch. System tier, not home: the launchd agent runs
  # out of /run/current-system, which is also where the trigger below finds it.
  flake.darwinModules.sketchybar =
    { pkgs, ... }:
    {
      services.sketchybar = {
        enable = true;
        # Its helper scripts shell out to all five; a missing one shows up as a
        # blank item rather than an error.
        extraPackages = with pkgs; [
          aerospace
          cava
          jq
          python3
          sqlite
        ];
      };

      # The weather item has no feed of its own — it reads whatever the system
      # Weather app last cached, so the bar refreshes when that file changes.
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
