{
  flake.homeModules.fish = { pkgs, ... }: {
    programs.fish = {
      enable = true;
      interactiveShellInit = ''
        set -g fish_greeting ""
        fish_vi_key_bindings
      '';
      functions.reb.body = ''
        set -l target "asahi"
        set -l repo ~/nixos-config
        if test (count $argv) -gt 0; set target $argv[1]; end

        # Stage before building: a flake build cannot see untracked files, so a
        # newly written module is silently skipped unless it is at least staged.
        git -C $repo add -A

        if sudo nixos-rebuild switch --flake $repo#$target --impure
            # Commit only on success, so a broken config never becomes a commit.
            # This is a checkpoint for rolling back, not a substitute for real
            # commit messages — amend or reword it if the change deserves one.
            if not git -C $repo diff --cached --quiet
                git -C $repo commit -q -m "rebuild "(date '+%Y-%m-%d %H:%M:%S')
                echo "Committed as "(git -C $repo rev-parse --short HEAD)
            end
        else
            echo "Rebuild failed. Changes are staged but not committed."
            return 1
        end
      '';
      functions.pass-find.body = ''
        if not pass-cli test >/dev/null 2>&1
            pass-cli test
            or return 1
        end
        pass-cli item list Personal --output json | jq -r '(.items // .)[] | "[\((.item_type // .itemType // .type // "unknown") | ascii_upcase)] \(.title // .name)\t\(.id // .item_id // .itemId)"' | fzf --ansi --header="Select an item to view credentials" --with-nth=1 | string split \t | read -l display_name id
        if test -n "$id"
            pass-cli item view --vault-name Personal --item-id $id
        end
      '';
      shellAliases = {
        update = "update-brave-origin && nix flake update --flake ~/nixos-config";
        word = "libreoffice --writer";
        powerpoint = "libreoffice --impress";
        gen = "nix-env --list-generations";
        wt = "git worktree list";
        wta = "git worktree add";
        wtr = "git worktree remove";
        vi = "nvim";
        vim = "nvim";
        tree = "eza --tree --icons";
        ll = "eza -la --icons --group-directories-first --header --git-ignore";
        pf = "pass-find";
      };
      plugins = [
        {
          name = "sudope";
          src = pkgs.fishPlugins.plugin-sudope;
        }
      ];
    };
  };
}
