{
  # Read as `self.lib.user`. Home modules should prefer `config.home.homeDirectory`
  # over `home` — this exists for the NixOS side, which has no such option.
  flake.lib.user = {
    name = "uynx";
    home = "/home/uynx";
    darwinHome = "/Users/uynx";
  };
}
