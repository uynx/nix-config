{ inputs, ... }:
{
  # Declares flake.homeModules as a real flake-parts option so multiple
  # feature modules can each contribute to it and get merged.
  imports = [ inputs.home-manager.flakeModules.home-manager ];

  # Architectures perSystem blocks get evaluated for.
  # Add "aarch64-darwin" when the MacBook joins this repo.
  config.systems = [ "aarch64-linux" ];
}
