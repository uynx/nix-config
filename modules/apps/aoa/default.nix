{ self, ... }:
{
  # Persistent units of the weather trading project (repo ~/always_on_agent) on agent and x86 (asahi takes only aoa-up, its scheduler loop). Experiment arms stay
  # transient (ops/run.sh); these are the boot entry, the recorders x86 keeps as unit files, the timers and the nightly tests.
  flake.nixosModules.aoa =
    { config, pkgs, ... }:
    let
      user = self.lib.user.name;
      host = config.networking.hostName;
      path = "PATH=/run/wrappers/bin:/etc/profiles/per-user/${user}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:%h/.local/bin";
      recorder = desc: cmd: mem: {
        Unit = {
          Description = "aoa ${desc}, second copy recording the same public feeds as agent";
          After = [ "network-online.target" ];
        };
        Service = {
          WorkingDirectory = "%h/aoa_collector";
          Environment = [ path ];
          ExecStartPre = "%h/always_on_agent/ops/pull.sh %h/aoa_collector";
          ExecStart = "/bin/sh -c 'exec ${cmd}'";
          Restart = "always";
          RestartSec = 30;
          MemoryMax = mem;
        };
        Install.WantedBy = [ "default.target" ];
      };
      oneshot = desc: cmd: extra: {
        Unit.Description = "always_on_agent: ${desc}";
        Service = {
          Type = "oneshot";
          Environment = [ path ];
          WorkingDirectory = "%h/always_on_agent";
          ExecStartPre = "%h/always_on_agent/ops/pull.sh %h/always_on_agent";
          ExecStart = cmd;
        } // extra;
      };
      timer = desc: calendar: {
        Unit.Description = "always_on_agent: ${desc}";
        Timer = {
          OnCalendar = calendar;
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
      common.aoa-up = {
        Unit = {
          Description = "always_on_agent: start this machine's recorders, paper traders and scheduler";
          X-SwitchMethod = "keep-old";
        };
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          Environment = [ path ];
          ExecStart = "%h/always_on_agent/ops/up.sh";
        };
        Install.WantedBy = [ "default.target" ];
      };
      agentServices = {
        aoa-daily = oneshot "daily data refresh (Polymarket and Kalshi results, forecasts, order-book archive)" "/bin/sh -c 'ops/daily.sh >> wallet_study/daily.log 2>&1'" {
          Slice = "aoa-heavy.slice";
          MemoryHigh = "4G";
        };
        aoa-ifsfresh = oneshot "save each newly public ECMWF run (all three field sets)" "/bin/sh -c 'ops/ifs_fresh.sh >> weather/ifs_fresh.log 2>&1'" { MemoryHigh = "3G"; };
        aoa-tests = oneshot "nightly unit tests, one status line in data/tests.log" "%h/always_on_agent/ops/tests.sh" { MemoryHigh = "4G"; };
        aoa-clifork = oneshot "daily CLI fork flag for the US temperature ladders, after the West Coast CLIs issue" "/bin/sh -c 'devenv shell -- python -m ops.cli_fork >> data/cli_fork.log 2>&1'" { MemoryHigh = "2G"; };
        aoa-refit = oneshot "submit the monthly seasonal refit to x86 (row L2-30)" "/bin/sh %h/always_on_agent/ops/refit_month.sh submit" { MemoryHigh = "256M"; };
        aoa-lanesboot = {
          Unit = {
            Description = "Start the weather research agents";
            X-SwitchMethod = "keep-old";
          };
          Service = {
            Type = "oneshot";
            RemainAfterExit = true;
            TimeoutStartSec = "5min";
            Environment = [ path ];
            ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/.local/state/aoa-lanes";
            ExecStart = "%h/always_on_agent/ops/lanes.sh boot";
            ExecStartPost = "${pkgs.coreutils}/bin/touch %h/.local/state/aoa-lanes/started";
          };
        };
        aoa-lanes-resume = {
          Unit = {
            Description = "Restore weather research agents after a reboot";
            X-SwitchMethod = "keep-old";
            ConditionPathExists = "%h/.local/state/aoa-lanes/started";
          };
          Service = {
            Type = "oneshot";
            RemainAfterExit = true;
            TimeoutStartSec = "5min";
            ExecStart = "/run/current-system/sw/bin/systemctl --user start aoa-lanesboot.service";
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
      agentTimers = {
        aoa-daily = timer "daily data refresh at 06:00" "*-*-* 06:00:00";
        aoa-ifsfresh = timer "ECMWF run refresh, one minute after each run's last step is public and hourly as a catch-all" [
          "*-*-* *:20:00"
          "*-*-* 00,12:31:00 UTC"
          "*-*-* 00,12:34:00 UTC"
          "*-*-* 07,19:37:00 UTC"
          "*-*-* 07,19:40:00 UTC"
        ];
        aoa-tests = timer "nightly unit tests at 03:30" "*-*-* 03:30:00";
        aoa-clifork = timer "daily CLI fork flag at 10:45Z" "*-*-* 10:45:00 UTC";
        aoa-refit = timer "monthly seasonal refit on the 1st at 02:00" "*-*-01 02:00:00";
      };
      x86Services = {
        aoa-collector2 = recorder "collector" "secretspec run --provider sops://secrets.enc.yaml --reason collector -- engine/target/release/collector --poly-tag 103040 \"KXHIGH*\" \"KXLOW*\" 2>> data_collector.log" "1G";
        # Phase 45 against agent's 0: the two hosts' 90 s polls then sit 45 s apart, a 45 s cadence for the earliest-of-two feed (row L7-27).
        aoa-live2 = recorder "live2" "env AOA_POLL_PHASE=45 secretspec run --provider sops://secrets.enc.yaml --reason live-weather -- python3 -u -m weather.live >> weather/live.log 2>&1" "512M";
        aoa-enslog2 =
          let
            base = recorder "enslog2" "python3 -u -m weather.ens_log >> weather/ens_log.err 2>&1" "512M";
          in
          base
          // {
            Service = base.Service // {
              Environment = [
                path
                "AOA_ENS_HOURS=1,7,13,19"
              ];
            };
          };
        aoa-fcruns2 = recorder "fcruns2" "python3 -u -m weather.fc_runs >> weather/fc_runs.err 2>&1" "512M";
        aoa-aprs2 = recorder "aprs2" "python3 -u -m weather.aprs >> weather/aprs.log 2>&1" "256M";
        aoa-wis22 = recorder "wis22" "devenv shell -- python3 -u -m weather.wis2 >> weather/wis2.log 2>&1" "1G";
      };
    in
    {
      home-manager.users.${user} =
        { lib, ... }:
        {
          systemd.user.servicesStartTimeoutMs = 600000;
          systemd.user.services = common // (if host == "agent" then agentServices else { }) // (if host == "x86" then x86Services else { });
          systemd.user.timers = if host == "agent" then agentTimers else { };
          # Never set Restart= here: one-pass scheduler jobs (aoa-job-*) share the prefix and must not rerun.
          xdg.configFile."systemd/user/aoa-.service.d/backoff.conf".text = ''
            [Unit]
            StartLimitIntervalSec=0

            [Service]
            RestartSteps=5
            RestartMaxDelaySec=1min
          '';
          # The same units were hand-placed before this module existed; Home Manager refuses to link over a plain file.
          home.activation.aoaAdoptUnits = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
            for f in $HOME/.config/systemd/user/aoa-*.service $HOME/.config/systemd/user/aoa-*.timer $HOME/.config/systemd/user/*.wants/aoa-*; do
              [ -e "$f" ] && [ ! -L "$f" ] || [ -L "$f" ] && case "$(readlink "$f")" in /nix/store/*) continue ;; esac
              [ -e "$f" ] || [ -L "$f" ] || continue
              run rm -f "$f"
            done
          '';
        };
    };
}
