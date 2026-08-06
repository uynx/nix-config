{ moduleWithSystem, ... }:
{
  # Sets GIT_CONFIG_GLOBAL to a store path, so `git config --global` now fails
  # read-only and ~/.gitconfig is ignored. Change settings here and rebuild.
  flake.wrappers.git =
    { wlib, pkgs, lib, ... }:
    {
      imports = [ wlib.wrapperModules.git ];

      # delta is invoked by name as the pager, so it has to be on the wrapped
      # git's own PATH rather than merely installed.
      runtimePkgs = [ pkgs.delta ];

      settings = {
        # Home Manager's delta module writes into programs.git, which this
        # replaces, so its settings are spelled out here instead. Without them
        # delta is installed and never used.
        core.pager = lib.getExe pkgs.delta;
        interactive.diffFilter = "${lib.getExe pkgs.delta} --color-only";
        delta = {
          navigate = true;
          side-by-side = true;
          line-numbers = true;
          # No Flexoki .tmTheme exists, so syntax highlighting keeps bat's
          # default and only delta's own decorations are recoloured.
          plus-style = "syntax #1e2b18";
          minus-style = "syntax #33201d";
          plus-emph-style = "syntax #2f4523";
          minus-emph-style = "syntax #55302b";
          line-numbers-plus-style = "#879a39";
          line-numbers-minus-style = "#d14d41";
          line-numbers-zero-style = "#575653";
          file-style = "#d0a215";
          hunk-header-style = "#4385be";
        };

        user = {
          name = "Brandon Alexander";
          email = "brandonwalex@pm.me";
          signingkey = "~/.ssh/id_ed25519.pub";
        };
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
        core = {
          editor = "nvim";
          fsmonitor = true;
          untrackedCache = true;
        };
        gpg.format = "ssh";
        commit.gpgsign = true;
        tag.gpgsign = true;
        merge.conflictstyle = "zdiff3";
        rerere.enabled = true;
      };
    };

  flake.homeModules.git = moduleWithSystem (
    { self', ... }:
    {
      home.packages = [ self'.packages.git ];

      programs.gh = {
        enable = true;
        settings = {
          git_protocol = "ssh";
          editor = "nvim";
        };
      };

      programs.lazygit = {
        enable = true;
        settings = {
          gui.showIcons = true;
          git.paging = {
            colorArg = "always";
            pager = "bat --style=plain";
          };
        };
      };
    }
  );
}
