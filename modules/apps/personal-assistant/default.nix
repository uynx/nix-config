{
  flake.nixosModules.personalAssistant =
    { pkgs, ... }:
    let
      simplex = pkgs.callPackage ./_simplex-cli.nix { };
      environment = [
        "AGENT_OWNS_MACHINE=1"
        "PATH=/run/wrappers/bin:/etc/profiles/per-user/uynx/bin:/run/current-system/sw/bin"
      ];
      bridge = "${pkgs.bun}/bin/bun %h/dotfiles/assistant/bridge.ts";
      browserPython = pkgs.python3.withPackages (p: [ p.playwright ]);
      browser = pkgs.writeShellScriptBin "assistant-browser" ''
        export ASSISTANT_EXTENSIONS_DIR="$HOME/.local/share/assistant-extensions"
        exec sudo -E ${pkgs.iproute2}/bin/ip netns exec assistant-browser ${pkgs.util-linux}/bin/runuser --preserve-environment -u uynx -- ${browserPython}/bin/python3 "$HOME/dotfiles/assistant/browser/ab.py" "$@"
      '';
      browserDirect = pkgs.writeShellScriptBin "assistant-browser-direct" ''
        export ASSISTANT_EXTENSIONS_DIR="$HOME/.local/share/assistant-extensions"
        exec ${browserPython}/bin/python3 "$HOME/dotfiles/assistant/browser/ab.py" "$@"
      '';
      browserService = prefix: {
        Unit.Description = "Dedicated assistant Chromium browser";
        Service = {
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/.local/state %h/.local/share/agent-browser/profile";
          ExecStart = "${prefix}${pkgs.util-linux}/bin/flock -n -E 0 %h/.local/state/agent-browser.lock ${pkgs.ungoogled-chromium}/bin/chromium --user-data-dir=%h/.local/share/agent-browser/profile --remote-debugging-port=9333 --no-first-run --no-default-browser-check --password-store=basic --disable-features=DisableLoadExtensionCommandLineSwitch --load-extension=%h/.local/share/assistant-extensions/fkgkibajhfbepljeaefdnfnegdcjomkh/1.75.0_0,%h/.local/share/assistant-extensions/bkdgflcldnnnapblkhphbgpggdiikppg/2026.10.6_0";
          Environment = environment;
          UMask = "0077";
          Restart = "on-failure";
          RestartSec = 10;
        };
      };
    in
    {
      imports = [ ./_vpn.nix ];
      environment.systemPackages = [
        simplex
        pkgs.protonmail-bridge
        browser
        browserDirect
      ];
      home-manager.users.uynx = {
        systemd.user.services = {
          personal-assistant-browser =
            (browserService "sudo -E ${pkgs.iproute2}/bin/ip netns exec assistant-browser ${pkgs.util-linux}/bin/runuser --preserve-environment -u uynx -- ")
            // {
              Install.WantedBy = [ "graphical-session.target" ];
            };
          personal-assistant-browser-direct = browserService "";
          personal-assistant-simplex = {
            Unit.Description = "Personal assistant SimpleX daemon";
            Service = {
              ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/.local/share/personal-assistant/simplex";
              ExecStart = "${pkgs.util-linux}/bin/flock -n -E 0 %t/assistant-simplex.lock ${simplex}/bin/simplex-chat -d %h/.local/share/personal-assistant/simplex/chat -p 5225 --create-bot-display-name BrandonAssistant";
              Restart = "on-failure";
              RestartSec = 5;
              UMask = "0077";
            };
            Install.WantedBy = [ "default.target" ];
          };
          personal-assistant-bridge = {
            Unit = {
              Description = "Durable SimpleX queue for the personal assistant";
              After = [ "personal-assistant-simplex.service" ];
              Wants = [ "personal-assistant-simplex.service" ];
            };
            Service = {
              ExecStart = "${pkgs.util-linux}/bin/flock -n -E 0 %t/assistant-bridge.lock ${bridge} daemon";
              Environment = environment;
              EnvironmentFile = "-%h/.config/personal-assistant/runtime.env";
              Restart = "on-failure";
              RestartSec = 5;
              UMask = "0077";
            };
            Install.WantedBy = [ "default.target" ];
          };
          personal-assistant-session = {
            Unit = {
              Description = "Personal assistant Claude session in its own tmux server";
              After = [ "personal-assistant-bridge.service" ];
              Wants = [ "personal-assistant-bridge.service" ];
            };
            Service = {
              ExecStart = "${pkgs.dash}/bin/dash %h/dotfiles/assistant/session.sh";
              ExecStop = "${pkgs.tmux}/bin/tmux -L personal-assistant kill-server";
              Environment = environment;
              Restart = "always";
              RestartSec = 5;
              UMask = "0077";
            };
            Install.WantedBy = [ "default.target" ];
          };
          personal-assistant-heartbeat = {
            Unit.Description = "Wake the personal assistant for inbox and calendar checks";
            Service = {
              Type = "oneshot";
              ExecStart = "${bridge} heartbeat";
            };
          };
          personal-assistant-rotate = {
            Unit.Description = "Request a fresh personal assistant session and handoff";
            Service = {
              Type = "oneshot";
              ExecStart = "${bridge} rotate";
            };
          };
        };
        systemd.user.timers = {
          personal-assistant-heartbeat = {
            Unit.Description = "Personal assistant heartbeat every twenty minutes";
            Timer = {
              OnBootSec = "5min";
              OnUnitActiveSec = "20min";
            };
            Install.WantedBy = [ "timers.target" ];
          };
          personal-assistant-rotate = {
            Unit.Description = "Fresh personal assistant session at 4 AM Eastern";
            Timer = {
              OnCalendar = "*-*-* 04:00:00 America/New_York";
              Persistent = true;
            };
            Install.WantedBy = [ "timers.target" ];
          };
        };
      };
    };
}
