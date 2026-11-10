{
  flake.nixosModules.personalAssistant =
    { pkgs, lib, ... }:
    let
      simplex = pkgs.callPackage ./_simplex-cli.nix { };
      # Sites flag the HeadlessChrome token with harder challenges, so the browser reports a stock desktop Chrome.
      userAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/${lib.versions.major pkgs.ungoogled-chromium.version}.0.0.0 Safari/537.36";
      environment = [
        "AGENT_OWNS_MACHINE=1"
        "PATH=/run/wrappers/bin:/etc/profiles/per-user/uynx/bin:/run/current-system/sw/bin"
      ];
      bridge = "${pkgs.bun}/bin/bun %h/dotfiles/assistant/bridge.ts";
      browserPython = pkgs.python3.withPackages (p: [ p.playwright ]);
      browser = pkgs.writeShellScriptBin "assistant-browser" ''
        export ASSISTANT_EXTENSIONS_DIR="$HOME/.local/share/assistant-extensions"
        ab="$HOME/dotfiles/assistant/browser/ab.py"
        hs=$(/run/wrappers/bin/sudo ${pkgs.iproute2}/bin/ip netns exec assistant-browser ${pkgs.wireguard-tools}/bin/wg show wg-assistant latest-handshakes 2>/dev/null | ${pkgs.coreutils}/bin/cut -f2)
        # The browser tunnel is used only while the host VPN is down and the tunnel handshook in the last 3 minutes.
        if ${pkgs.iproute2}/bin/ip link show obscuravpn >/dev/null 2>&1 || [ $(( $(${pkgs.coreutils}/bin/date +%s) - ''${hs:-0} )) -gt 180 ]; then
          ${pkgs.systemd}/bin/systemctl --user stop personal-assistant-browser
          ${pkgs.systemd}/bin/systemctl --user start personal-assistant-browser-direct
          exec ${browserPython}/bin/python3 "$ab" "$@"
        fi
        ${pkgs.systemd}/bin/systemctl --user stop personal-assistant-browser-direct
        ${pkgs.systemd}/bin/systemctl --user start personal-assistant-browser
        exec /run/wrappers/bin/sudo -E ${pkgs.iproute2}/bin/ip netns exec assistant-browser ${pkgs.util-linux}/bin/runuser --preserve-environment -u uynx -- ${browserPython}/bin/python3 "$ab" "$@"
      '';
      browserDirect = pkgs.writeShellScriptBin "assistant-browser-direct" ''
        export ASSISTANT_EXTENSIONS_DIR="$HOME/.local/share/assistant-extensions"
        exec ${browserPython}/bin/python3 "$HOME/dotfiles/assistant/browser/ab.py" "$@"
      '';
      browserService = prefix: {
        Unit.Description = "Dedicated assistant Chromium browser, headless";
        Service = {
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/.local/state %h/.local/share/agent-browser/profile";
          ExecStart = "${prefix}${pkgs.util-linux}/bin/flock -n -E 0 %h/.local/state/agent-browser.lock ${pkgs.ungoogled-chromium}/bin/chromium --user-data-dir=%h/.local/share/agent-browser/profile --remote-debugging-port=9333 --headless=new --window-size=1280,900 --user-agent='${userAgent}' --no-first-run --no-default-browser-check --password-store=basic --disable-features=DisableLoadExtensionCommandLineSwitch --load-extension=%h/.local/share/assistant-extensions/fkgkibajhfbepljeaefdnfnegdcjomkh/1.75.0_0,%h/.local/share/assistant-extensions/bkdgflcldnnnapblkhphbgpggdiikppg/2026.10.6_0";
          Environment = environment;
          UMask = "0077";
          Restart = "on-failure";
          RestartSec = 10;
          MemoryHigh = "3G";
          MemorySwapMax = "2G";
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
          personal-assistant-browser = browserService "/run/wrappers/bin/sudo -E ${pkgs.iproute2}/bin/ip netns exec assistant-browser ${pkgs.util-linux}/bin/runuser --preserve-environment -u uynx -- ";
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
          personal-assistant-mailclean = {
            Unit.Description = "Move mail with no remaining use to Trash";
            Service = {
              Type = "oneshot";
              WorkingDirectory = "%h/dotfiles/assistant";
              Environment = environment;
              EnvironmentFile = "-%h/.config/personal-assistant/runtime.env";
              ExecStart = "${pkgs.util-linux}/bin/flock -n -E 0 %t/assistant-mailclean.lock ${pkgs.dash}/bin/dash -c 'mkdir -p %h/applications && exec claude -p --dangerously-skip-permissions --model opus \"$(cat %h/dotfiles/assistant/mail-cleanup.md)\" >> %h/applications/mailclean.log 2>&1'";
            };
          };
          personal-assistant-skillscout = {
            Unit.Description = "Test newly praised agent skills and read how others run always-on agents";
            Service = {
              Type = "oneshot";
              WorkingDirectory = "%h/dotfiles/assistant";
              Environment = environment;
              EnvironmentFile = "-%h/.config/personal-assistant/runtime.env";
              TimeoutStartSec = "75min";
              ExecStart = "${pkgs.util-linux}/bin/flock -n -E 0 %t/assistant-skillscout.lock ${pkgs.dash}/bin/dash -c 'mkdir -p %h/aoa_tmp/skillscout && exec claude -p --dangerously-skip-permissions --model opus \"$(cat %h/dotfiles/assistant/skill-scout.md)\" >> %h/aoa_tmp/skillscout/run.log 2>&1'";
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
          personal-assistant-mailclean = {
            Unit.Description = "Daily mail cleanup at 6 AM Eastern";
            Timer = {
              OnCalendar = "*-*-* 06:00:00 America/New_York";
              Persistent = true;
            };
            Install.WantedBy = [ "timers.target" ];
          };
          personal-assistant-skillscout = {
            Unit.Description = "Daily skill and agent scout at 5 AM Eastern";
            Timer = {
              OnCalendar = "*-*-* 05:00:00 America/New_York";
              Persistent = true;
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
