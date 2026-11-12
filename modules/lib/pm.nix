{ self, ... }:
{
  # The trader checkout; PM_ROOT for every shell and unit comes from here and nowhere else.
  flake.lib.pm.root = "${self.lib.user.home}/prediction_markets";
  # The assistant checkout, whose secrets hold the API credits key the lanes fall back to.
  flake.lib.pm.assistant = "${self.lib.user.home}/dotfiles/assistant";
}
