{ self, inputs, ... }:
let
  # Settings is one page app whose menu clicks never reload, so blocking only its Shields subpage left content filters editable.
  settingsPages = [
    "brave://settings"
    "chrome://settings"
    "brave://adblock"
    "chrome://adblock"
  ];

  social = [
    "youtube.com"
    "youtu.be"
    "youtube-nocookie.com"
    "facebook.com"
    "fb.com"
    "fb.watch"
    "instagram.com"
    "twitter.com"
    "x.com"
    "tiktok.com"
    "snapchat.com"
    "reddit.com"
    "redd.it"
    "pinterest.com"
    "tumblr.com"
    "threads.net"
    "threads.com"
    "bsky.app"
    "twitch.tv"
    "9gag.com"
    "4chan.org"
  ];

  proxies = [
    "croxyproxy.com"
    "croxyproxy.rocks"
    "croxy.network"
    "croxy.org"
    "blockaway.net"
    "proxyium.com"
    "proxysite.com"
    "proxysite.cloud"
    "proxysite.site"
    "kproxy.com"
    "4everproxy.com"
    "filterbypass.me"
    "plainproxies.com"
    "hidemyass.com"
    "hide.me"
    "whoer.net"
    "megaproxy.com"
    "zend2.com"
    "zalmos.com"
    "webproxy.net"
    "blewpass.com"
    "anonymouse.org"
    "freeproxy.win"
    "proxfree.com"
    "my-proxy.com"
    "vpnbook.com"
    "dontfilter.us"
    "hidester.com"
    "wombatproxy.com"
    "turbohide.org"
    "newipnow.com"
    "site2unblock.com"
    "unblockproxy.me"
    "unblock-web.site"
    "free-proxy.cz"
    "spys.one"
    "proxyserver.com"
    "filterbreak.com"
    "bypasslocal.com"
    "unblocksite.id"
    "freeopenproxy.com"
    "webproxy.to"
    "genmirror.com"
    "proxydocker.com"
    "sitenable.com"
    "sitenable.ch"
    "sitenable.co"
    "sitenable.info"
    "sitenable.pw"
    "sitenable.top"
    "free-proxy-list.net"
    "zalmos.net"
    "hidester.org"
    "vpnbrowse.com"
    "browserling.com"
    "hyperbeam.com"
    "neverinstall.com"
    "now.gg"
    "kasmweb.com"
    "browsergap.xyz"
    "browserstack.com"
    "lambdatest.com"
    "saucelabs.com"
    "rammerhead.org"
    "titaniumnetwork.org"
    "incog.works"
    "holyubofficial.net"
    "surfdoge.pro"
    "tomp.app"
    "interstellar-network.github.io"
    "sz-games.github.io"
    "luphoria.com"
    "wisp.host"
    "archive.today"
    "archive.ph"
    "archive.is"
    "archive.li"
    "archive.vn"
    "archive.md"
    "12ft.io"
    "removepaywall.com"
    "printfriendly.com"
    "txtify.it"
    "smry.ai"
    "archivebox.io"
    "translate.googleusercontent.com"
    "webcache.googleusercontent.com"
    "nodeunblocker.com"
    "ccproxy.com"
    "geoproxy.net"
    "translate.goog"
    "web.archive.org"
    "yewtu.be"
    "invidious.io"
    "inv.nadeko.net"
    "piped.video"
    "poketube.fun"
    "nitter.net"
    "nitter.poast.org"
    "xcancel.com"
    "safereddit.com"
    "imginn.com"
    "picuki.com"
    "croxyproxy.net"
    "proxyorb.com"
    "hidemy.name"
  ];

  banned = [
    "tor-browser"
    "mullvad-browser"
  ];

  build = pkgs: rec {
    porn = pkgs.runCommand "porn-names" { } ''
      awk '$1 == "0.0.0.0" && $2 != "0.0.0.0" { print $2 }' ${pkgs.stevenblack-blocklist.porn}/hosts | sort -u > $out
      [ "$(wc -l < $out)" -gt 10000 ]
    '';
    # URLBlocklist reads only its first 1000 entries, so it gets the most-visited porn domains and DNS keeps the full list.
    # awk stops itself; a `| head` here dies of SIGPIPE under the builder's pipefail.
    pornTop = pkgs.runCommand "porn-top" { } ''
      awk -F, -v n=${toString (1000 - builtins.length (social ++ proxies ++ settingsPages))} \
        'NR == FNR { p[$1] = 1; next } { sub(/\r$/, "", $2) } ($2 in p) { print $2; if (++c == n) exit }' \
        ${porn} ${
          pkgs.fetchurl {
            url = "https://tranco-list.eu/download/947N2/1000000";
            hash = "sha256-87PxyBszP0NtFuG+KtG/cvlfoRoneG9fAELyWLjzgt8=";
          }
        } > $out
    '';
    policy = pkgs.runCommand "site-block-policy.json" { nativeBuildInputs = [ pkgs.jq ]; } ''
      jq --rawfile top ${pornTop} '.URLBlocklist += ($top | split("\n") | map(select(. != "")))' ${
        pkgs.writeText "policy.json" (builtins.toJSON {
          URLBlocklist = social ++ proxies ++ settingsPages;
          IncognitoModeAvailability = 1;
          TorDisabled = true;
          DnsOverHttpsMode = "off";
          BuiltInDnsClientEnabled = false;
          BraveShieldsEnabledForUrls = [ "*" ];
          BraveShieldsDisabledForUrls = [
            "https://docs.google.com/*"
            "https://drive.google.com/*"
          ];
        })
      } > $out
      jq -e '.URLBlocklist | length <= 1000 and ([.[] | select(. == "pornhub.com" or . == "xvideos.com" or . == "youtube.com")] | length == 3) and all(. != "wikipedia.org")' $out
    '';
    phonePolicy = pkgs.runCommand "site-block-phone.json" { nativeBuildInputs = [ pkgs.jq ]; } ''
      jq '{
        privateDns: "dns.quad9.net",
        userRestrictions: ["disallow_config_private_dns", "no_safe_boot", "no_add_user", "no_factory_reset"],
        hidden: ["app.vanadium.browser"],
        appRestrictions: { "com.brave.browser": . }
      }' ${policy} > $out
    '';
  };

  phoneSync =
    pkgs:
    let
      b = build pkgs;
      apk =
        pkgs.runCommand "site-block-phone.apk"
          {
            nativeBuildInputs = [
              inputs.nixpkgs.legacyPackages.x86_64-linux.aapt
              pkgs.jdk_headless
              pkgs.zip
            ];
            ANDROID_JAR = pkgs.runCommand "android-36.jar" { nativeBuildInputs = [ pkgs.unzip ]; } ''
              unzip -p ${
                pkgs.fetchurl {
                  url = "https://dl.google.com/android/repository/platform-36_r02.zip";
                  hash = "sha256-N2BzaaKMW2QLOnmYho1FiY68t3dWWg6F+azzbyljHS4=";
                }
              } '*/android.jar' > $out
            '';
            R8_JAR = pkgs.fetchurl {
              url = "https://dl.google.com/android/maven2/com/android/tools/r8/8.13.25/r8-8.13.25.jar";
              hash = "sha256-DU8vaMT8vJQ07/Ei9B/rb7HZjv0vqlMM7Bq6yrHOoD0=";
            };
          }
          "bash ${./phone/build-apk.sh} ${./phone} ${b.phonePolicy} $out";
    in
    pkgs.writeShellApplication {
      name = "phone-sync";
      runtimeInputs = with pkgs; [
        android-tools
        apksigner
        jq
        ripgrep
        gawk
        coreutils
      ];
      text = ''
        export PHONE_SYNC_APK=${apk} PHONE_SYNC_POLICY=${b.phonePolicy}
        ${builtins.readFile ./phone/phone-sync.sh}
      '';
    };

  dns = porn: {
    services.dnscrypt-proxy.settings.blocked_names.blocked_names_file = porn;
  };
in
{
  flake.nixosModules.siteBlock =
    { config, lib, pkgs, ... }:
    let
      b = build pkgs;
    in
    {
      imports = [ (dns b.porn) ];

      # /etc/hosts holds while the VPN's resolver replaces dnscrypt.
      networking.hostFiles = [ "${pkgs.stevenblack-blocklist.porn}/hosts" ];
      networking.extraHosts = lib.concatMapStringsSep "\n" (d: "0.0.0.0 ${d} www.${d}") proxies;

      assertions = [
        {
          assertion = !lib.any (p: lib.any (n: lib.hasPrefix n (p.name or "")) banned) config.home-manager.users.${self.lib.user.name}.home.packages;
          message = "Brandon banned Tor Browser and Mullvad Browser on 2026-11-05 and asked that they never come back. Do not remove this check or the site block.";
        }
      ];

      environment.systemPackages = [ (phoneSync pkgs) ];
      home-manager.users.${self.lib.user.name}.sops.secrets.site-block-keystore.path =
        "${self.lib.user.home}/.config/site-block/keystore.p12.b64";

      environment.etc = {
        "brave/policies/managed/site-block.json".source = b.policy;
        "chromium/policies/managed/site-block.json".source = b.policy;
        "firefox/policies/policies.json".text = builtins.toJSON {
          policies.WebsiteFilter.Block = map (d: "*://*.${d}/*") (social ++ proxies);
        };
      };
    };

  # The iPad cannot take a browser policy, so its DNS profile points here: the same lists, served over Tailscale Funnel.
  flake.nixosModules.ipadDns =
    { lib, pkgs, ... }:
    let
      b = build pkgs;
      stamps = lib.importJSON ../../system/dns-stamps.json;
      state = "/var/lib/ipad-dns";
      names = pkgs.runCommand "ipad-blocked-names" { } ''
        sort -u ${b.porn} ${pkgs.writeText "social-proxies" (lib.concatLines (social ++ proxies))} > $out
      '';
      settings = (pkgs.formats.toml { }).generate "ipad-dns.toml" {
        listen_addresses = [ "127.0.0.1:5354" ];
        server_names = lib.attrNames stamps;
        static = lib.mapAttrs (_: stamp: { inherit stamp; }) stamps;
        doh_servers = true;
        require_dnssec = false;
        blocked_names.blocked_names_file = "${names}";
        local_doh = {
          listen_addresses = [ "127.0.0.1:3443" ];
          path = "/482d82a678197e27cad729ab9b1005ee";
          cert_file = "${state}/cert.pem";
          cert_key_file = "${state}/key.pem";
        };
      };
      cert = pkgs.writeShellScript "ipad-dns-cert" ''
        [ -s ${state}/key.pem ] || ${pkgs.openssl}/bin/openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 3650 -subj /CN=localhost -keyout ${state}/key.pem -out ${state}/cert.pem
      '';
    in
    {
      systemd.services.ipad-dns = {
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        serviceConfig = {
          DynamicUser = true;
          StateDirectory = "ipad-dns";
          ExecStartPre = cert;
          ExecStart = "${pkgs.dnscrypt-proxy}/bin/dnscrypt-proxy -config ${settings}";
          Restart = "always";
          RestartSec = 5;
        };
      };
      systemd.services.ipad-dns-funnel = {
        wantedBy = [ "multi-user.target" ];
        wants = [ "tailscaled.service" "ipad-dns.service" ];
        after = [ "tailscaled.service" "ipad-dns.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          # The setting persists in tailscaled; "-" and the timeout keep a Funnel outage from failing a rebuild.
          ExecStart = "-${pkgs.tailscale}/bin/tailscale funnel --bg https+insecure://127.0.0.1:3443";
          TimeoutStartSec = 30;
        };
      };
    };

  flake.darwinModules.siteBlock =
    { config, lib, pkgs, ... }:
    let
      b = build pkgs;
    in
    {
      imports = [ (dns b.porn) ];

      assertions = [
        {
          assertion = !lib.any (c: builtins.elem (c.name or c) banned) config.homebrew.casks;
          message = "Brandon banned Tor Browser and Mullvad Browser on 2026-11-05 and asked that they never come back. Do not remove this check or the site block.";
        }
      ];

      # Chromium on macOS accepts only forced prefs, and /Library/Managed Preferences is the one place that counts as forced.
      system.activationScripts.postActivation.text = ''
        mkdir -p "/Library/Managed Preferences"
        /usr/bin/plutil -convert xml1 -o "/Library/Managed Preferences/com.brave.Browser.plist" ${b.policy}
      '';
    };
}
