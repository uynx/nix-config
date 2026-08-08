{
  # Read as `self.lib.flexoki`. Every themed program here spelled these out
  # again, so a retint meant editing seven files and hoping none was missed.
  #
  # Values are ghostty's "Flexoki Dark" verbatim — do not invent replacements.
  # Re-read them from
  # `$(nix build --print-out-paths 'nixpkgs#ghostty-bin^out')/Applications/Ghostty.app/Contents/Resources/ghostty/themes/Flexoki Dark`.
  flake.lib.flexoki = {
    bg = "#100f0f";
    fg = "#cecdc3";
    selection = "#403e3c";
    dim = "#575653";
    gray = "#878580";

    red = "#d14d41";
    green = "#879a39";
    yellow = "#d0a215";
    blue = "#4385be";
    cyan = "#3aa99f";
    magenta = "#ce5d97";

    # ghostty's palette 9-14, the darker half of each hue. Only the three
    # anything here uses.
    redDeep = "#af3029";
    yellowDeep = "#ad8301";
    blueDeep = "#205ea6";
  };
}
