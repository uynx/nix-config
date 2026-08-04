{
  # macos-* keys are kept deliberately: ghostty ignores them on Linux, and this
  # tier is the one shared with a future darwin host.
  flake.homeModules.ghostty = {
    programs.ghostty.enable = true;

    home.file.".config/ghostty/config".text = ''
      font-family = "Hack Nerd Font"
      font-size = 12
      font-thicken = true
      font-thicken-strength = 64

      theme = "Flexoki Dark"

      window-padding-x = 10
      window-padding-y = 10
      window-padding-balance = true
      window-decoration = auto
      macos-titlebar-style = transparent
      macos-titlebar-proxy-icon = hidden
      macos-window-shadow = true

      background-opacity = 0.92

      cursor-style = bar
      cursor-style-blink = true
      mouse-hide-while-typing = true
      scroll-to-bottom = keystroke

      window-save-state = never
      working-directory = home
      clipboard-paste-protection = true
      confirm-close-surface = false

      # Superscripts, Subscripts, Letterlike, and Number Forms
      font-codepoint-map = U+2070-U+209F="JuliaMono"
      font-codepoint-map = U+2100-U+214F="JuliaMono"
      font-codepoint-map = U+2150-U+218F="JuliaMono"

      # Mathematical Operators and Supplemental Math
      font-codepoint-map = U+2200-U+22FF="JuliaMono"
      font-codepoint-map = U+27C0-U+27EF="JuliaMono"
      font-codepoint-map = U+2980-U+29FF="JuliaMono"
      font-codepoint-map = U+2A00-U+2AFF="JuliaMono"

      # Alphanumeric Symbols (Script, Fraktur, Double-Struck)
      font-codepoint-map = U+1D400-U+1D7FF="JuliaMono"

      # Diacritics and Combining Marks
      font-codepoint-map = U+20D0-U+20FF="JuliaMono"

      # Structural Symbols (Arrows, Technical, Geometric, Braille)
      font-codepoint-map = U+2190-U+21FF="JuliaMono"
      font-codepoint-map = U+27F0-U+27FF="JuliaMono"
      font-codepoint-map = U+2900-U+297F="JuliaMono"
      font-codepoint-map = U+2B00-U+2BFF="JuliaMono"
      font-codepoint-map = U+2300-U+23FF="JuliaMono"
      font-codepoint-map = U+25A0-U+25FF="JuliaMono"
      font-codepoint-map = U+2800-U+28FF="JuliaMono"

      # Custom reload keybind to avoid conflict with shell history search
      keybind = ctrl+alt+r=reload_config
    '';
  };
}
