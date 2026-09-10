{ self, ... }:
let
  c = self.lib.flexoki;
in
{
  flake.homeModules.git = {
    programs.fish.shellAliases = {
      wt = "git worktree list";
      wta = "git worktree add";
      wtr = "git worktree remove";
    };

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
      enableGitIntegration = true;
      options = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
        plus-style = "syntax #1e2b18";
        minus-style = "syntax #33201d";
        plus-emph-style = "syntax #2f4523";
        minus-emph-style = "syntax #55302b";
        line-numbers-plus-style = c.green;
        line-numbers-minus-style = c.red;
        line-numbers-zero-style = c.dim;
        file-style = c.yellow;
        hunk-header-style = c.blue;
      };
    };

    programs.git = {
      enable = true;
      ignores = [ "**/.claude/settings.local.json" ];
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
        url."git@github.com:".insteadOf = "https://github.com/";

        gpg.format = "ssh";
        commit.gpgsign = true;
        tag.gpgsign = true;

        gpg.ssh.allowedSignersFile = "~/.config/git/allowed_signers";
        merge.conflictstyle = "zdiff3";
        rerere.enabled = true;
      };
    };
  };
}
