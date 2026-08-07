{
  # Deliberately NOT wrapped. A wrapper puts the config in GIT_CONFIG_GLOBAL
  # inside one binary, so every other git — a devshell's, a container's, CI's —
  # sees no identity at all and refuses to commit. Git config describes the
  # user, not one executable, so it belongs in ~/.config/git/config where any
  # git picks it up.
  flake.homeModules.git = {
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

    programs.delta = {
      enable = true;
      # Defaults to false, so enabling delta alone installs it and never wires
      # it up — git keeps using its built-in pager with no error anywhere.
      enableGitIntegration = true;
      options = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
        # No Flexoki .tmTheme exists, so syntax highlighting keeps bat's default
        # and only delta's own decorations are recoloured.
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
    };

    programs.git = {
      enable = true;
      settings = {
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
        # Rewrites at connect time, not clone time, so a repo cloned over HTTPS
        # starts using SSH the moment the key exists — no `remote set-url`.
        # That is the fresh-hardware path: the key lives inside this repo, so
        # the first clone has to be HTTPS, before any of this config exists.
        url."git@github.com:".insteadOf = "https://github.com/";

        gpg.format = "ssh";
        commit.gpgsign = true;
        tag.gpgsign = true;
        merge.conflictstyle = "zdiff3";
        rerere.enabled = true;
      };
    };
  };
}
