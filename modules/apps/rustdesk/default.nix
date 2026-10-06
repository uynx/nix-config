{
  flake.homeModules.rustdesk =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.rustdesk ];
    };
}
