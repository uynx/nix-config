{ moduleWithSystem, ... }:
{
  flake.wrappers.yazi =
    { wlib, ... }:
    {
      imports = [ wlib.wrapperModules.yazi ];

      settings.yazi.mgr = {
        show_hidden = true;
        sort_by = "modified";
        sort_dir_first = true;
      };

      flavors.flexoki = ./flexoki.yazi;
      settings.theme.flavor = {
        dark = "flexoki";
        light = "flexoki";
      };
    };

  # `y` is Home Manager's shellWrapperName, reimplemented here because the
  # wrapper ships the binary only. Without it yazi cannot change the shell's
  # directory on exit — that is the whole point of the wrapper function.
  flake.homeModules.yazi = moduleWithSystem (
    { self', ... }:
    { lib, ... }:
    {
      home.packages = [ self'.packages.yazi ];

      programs.fish.functions.y.body = ''
        set -l tmp (mktemp -t "yazi-cwd.XXXXXX")
        ${lib.getExe self'.packages.yazi} $argv --cwd-file="$tmp"
        if set -l cwd (command cat -- "$tmp"); and test -n "$cwd"; and test "$cwd" != "$PWD"
            builtin cd -- "$cwd"
        end
        rm -f -- "$tmp"
      '';
    }
  );
}
