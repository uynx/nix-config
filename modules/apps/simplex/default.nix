{
  flake.homeModules.simplex =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.simplex-chat-desktop ];
    };
}
