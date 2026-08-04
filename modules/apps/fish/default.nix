{
  flake.homeModules.fish = { pkgs, ... }: {
    programs.fish = {
      enable = true;
      interactiveShellInit = ''
        set -g fish_greeting ""
        fish_vi_key_bindings
      '';
      # Android VM, sized to the monitor it opens on. Must be the *logical*
      # size, used as niri reports it — do not divide by the scale again. A
      # mismatch does not letterbox the picture, it scales every click, since
      # qemu maps pointer position by proportion.
      functions.android.body = ''
        set -l state ~/.local/share/waydroid-vm

        # The external monitor if attached, otherwise whichever output has focus.
        set -l output
        if ${pkgs.niri}/bin/niri msg -j outputs | ${pkgs.jq}/bin/jq -e 'has("HDMI-A-1")' >/dev/null 2>&1
            set output (${pkgs.niri}/bin/niri msg -j outputs | ${pkgs.jq}/bin/jq -c '."HDMI-A-1"')
        else
            set output (${pkgs.niri}/bin/niri msg -j focused-output)
        end

        set -l size (printf '%s' "$output" | ${pkgs.jq}/bin/jq -er '.logical | "\(.width) \(.height)"' | string split ' ')
        if test (count $size) -ne 2
            echo "Could not read the monitor size from niri."
            return 1
        end

        # The disk image lives in the working directory; running this anywhere
        # else starts a blank Android and re-downloads 1.6 GB.
        mkdir -p $state
        cd $state
        or return 1

        set -x QEMU_OPTS "-device virtio-gpu-gl-pci,xres=$size[1],yres=$size[2] -display gtk,gl=on,show-menubar=off -full-screen"
        nix run ~/nixos-config#nixosConfigurations.waydroid.config.system.build.vm
      '';
      functions.reb.body = ''
        set -l target "asahi"
        set -l repo ~/nixos-config
        if test (count $argv) -gt 0; set target $argv[1]; end

        # A flake build cannot see untracked files, so an unstaged new module is
        # silently skipped.
        git -C $repo add -A

        # nh elevates itself, so no sudo here.
        if nh os switch $repo -H $target -- --impure
            # Checkpoint commit for rollback, not a real message — reword if the
            # change deserves one.
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
        update = "update-brave-origin && update-ai-clis && nix flake update --flake ~/nixos-config";
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
