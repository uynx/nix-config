{ self, ... }:
let
  settingsPages = [
    "brave://settings/shields"
    "chrome://settings/shields"
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

  banned = [
    "tor-browser"
    "mullvad-browser"
  ];

  build =
    pkgs:
    let
      porn = pkgs.runCommand "porn-names" { } ''
        awk '$1 == "0.0.0.0" && $2 != "0.0.0.0" { print $2 }' ${pkgs.stevenblack-blocklist.porn} | sort -u > $out
      '';
    in
    {
      inherit porn;
      policy = pkgs.runCommand "site-block-policy.json" { nativeBuildInputs = [ pkgs.jq ]; } ''
        jq -n --rawfile porn ${porn} --argjson social '${builtins.toJSON (social ++ settingsPages)}' '{
          URLBlocklist: (($porn | split("\n") | map(select(. != ""))) + $social),
          IncognitoModeAvailability: 1,
          TorDisabled: true,
          DnsOverHttpsMode: "off",
          BuiltInDnsClientEnabled: false,
          BraveShieldsEnabledForUrls: ["*"],
          BraveShieldsDisabledForUrls: []
        }' > $out
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

      assertions = [
        {
          assertion = !lib.any (p: lib.any (n: lib.hasPrefix n (p.name or "")) banned) config.home-manager.users.${self.lib.user.name}.home.packages;
          message = "Brandon banned Tor Browser and Mullvad Browser on 2026-11-05 and asked that they never come back. Do not remove this check or the site block.";
        }
      ];

      environment.etc = {
        "brave/policies/managed/site-block.json".source = b.policy;
        "chromium/policies/managed/site-block.json".source = b.policy;
        "firefox/policies/policies.json".text = builtins.toJSON {
          policies.WebsiteFilter.Block = map (d: "*://*.${d}/*") social;
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
