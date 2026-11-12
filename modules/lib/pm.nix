{ self, ... }:
{
  # The trader checkout; PM_ROOT for every shell and unit comes from here and nowhere else.
  flake.lib.pm.root = "${self.lib.user.home}/prediction_markets";
}
