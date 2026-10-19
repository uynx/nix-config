{
  flake.homeModules.firefox =
    { pkgs, lib, ... }:
    let
      prefs =
        fn: attrs:
        lib.concatStrings (lib.mapAttrsToList (k: v: "${fn}(\"${k}\", ${builtins.toJSON v});\n") attrs);
    in
    {
      home.packages = [
        (pkgs.firefox.override {
          extraPolicies = {
            DisableTelemetry = true;
            DisableFirefoxStudies = true;
            DisablePocket = true;
            DisableFirefoxAccounts = true;
            DisableFeedbackCommands = true;
            DisableAppUpdate = true;
            DontCheckDefaultBrowser = true;
            NoDefaultBookmarks = true;
            SkipTermsOfUse = true;
            OverrideFirstRunPage = "";
            OverridePostUpdatePage = "";
            CaptivePortal = false;
            NetworkPrediction = false;
            SearchSuggestEnabled = false;
            VisualSearchEnabled = false;
            IPProtectionAvailable = false;
            OfferToSaveLogins = false;
            DisableFormHistory = true;
            HttpsOnlyMode = "enabled";
            AIControls = {
              Default.Value = "blocked";
              Translations.Value = "available";
            };
            GenerativeAI.Enabled = false;
            EnableTrackingProtection = {
              Value = true;
              Cryptomining = true;
              Fingerprinting = true;
              EmailTracking = true;
              SuspectedFingerprinting = true;
            };
            UserMessaging = {
              ExtensionRecommendations = false;
              FeatureRecommendations = false;
              UrlbarInterventions = false;
              SkipOnboarding = true;
              MoreFromMozilla = false;
              FirefoxLabs = false;
            };
            FirefoxHome = {
              SponsoredTopSites = false;
              Pocket = false;
              SponsoredPocket = false;
              Stories = false;
              SponsoredStories = false;
            };
            FirefoxSuggest = {
              WebSuggestions = false;
              SponsoredSuggestions = false;
              ImproveSuggest = false;
            };
            SearchEngines = {
              Add = [
                {
                  Name = "Brave Search";
                  URLTemplate = "https://search.brave.com/search?q={searchTerms}";
                  Alias = "@brave";
                }
              ];
              Default = "Brave Search";
            };
            ExtensionSettings."uBlock0@raymondhill.net" = {
              installation_mode = "force_installed";
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
            };
          };
          extraPrefs =
            prefs "lockPref" {
              "toolkit.telemetry.unified" = false;
              "toolkit.telemetry.enabled" = false;
              "toolkit.telemetry.server" = "data:,";
              "toolkit.telemetry.archive.enabled" = false;
              "toolkit.telemetry.newProfilePing.enabled" = false;
              "toolkit.telemetry.updatePing.enabled" = false;
              "toolkit.telemetry.firstShutdownPing.enabled" = false;
              "toolkit.telemetry.shutdownPingSender.enabled" = false;
              "toolkit.telemetry.bhrPing.enabled" = false;
              "toolkit.telemetry.coverage.opt-out" = true;
              "toolkit.coverage.opt-out" = true;
              "toolkit.coverage.endpoint.base" = "";
              "datareporting.healthreport.uploadEnabled" = false;
              "datareporting.policy.dataSubmissionEnabled" = false;
              "datareporting.usage.uploadEnabled" = false;
              "browser.newtabpage.activity-stream.feeds.telemetry" = false;
              "browser.newtabpage.activity-stream.telemetry" = false;
              "browser.search.serpEventTelemetryCategorization.enabled" = false;
              "app.normandy.enabled" = false;
              "app.normandy.api_url" = "";
              "app.shield.optoutstudies.enabled" = false;
              "nimbus.rollouts.enabled" = false;
              "breakpad.reportURL" = "";
              "browser.tabs.crashReporting.sendReport" = false;
              "browser.crashReports.unsubmittedCheck.autoSubmit2" = false;
              "browser.discovery.enabled" = false;
              "browser.uitour.enabled" = false;
              "dom.private-attribution.submission.enabled" = false;
              "extensions.webcompat-reporter.enabled" = false;
              "permissions.manager.defaultsUrl" = "";
              "browser.safebrowsing.malware.enabled" = false;
              "browser.safebrowsing.phishing.enabled" = false;
              "browser.safebrowsing.blockedURIs.enabled" = false;
              "browser.safebrowsing.downloads.enabled" = false;
              "browser.safebrowsing.downloads.remote.enabled" = false;
              "browser.safebrowsing.provider.google4.gethashURL" = "";
              "browser.safebrowsing.provider.google4.updateURL" = "";
              "browser.safebrowsing.provider.google.gethashURL" = "";
              "browser.safebrowsing.provider.google.updateURL" = "";
              "captivedetect.canonicalURL" = "";
              "network.connectivity-service.enabled" = false;
              "network.prefetch-next" = false;
              "network.http.speculative-parallel-limit" = 0;
              "network.early-hints.preconnect.max_connections" = 0;
              "browser.places.speculativeConnect.enabled" = false;
              "browser.urlbar.speculativeConnect.enabled" = false;
              "browser.newtabpage.activity-stream.default.sites" = "";
              "browser.newtabpage.activity-stream.showSponsored" = false;
              "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
              "browser.newtabpage.activity-stream.showSponsoredCheckboxes" = false;
              "browser.newtabpage.activity-stream.unifiedAds.tiles.enabled" = false;
              "browser.newtabpage.activity-stream.unifiedAds.spocs.enabled" = false;
              "browser.newtabpage.activity-stream.unifiedAds.adsFeed.enabled" = false;
              "browser.newtabpage.activity-stream.unifiedAds.endpoint" = "";
              "browser.newtabpage.activity-stream.feeds.weatherfeed" = false;
              "browser.newtabpage.activity-stream.widgets.enabled" = false;
              "browser.topsites.contile.enabled" = false;
              "browser.urlbar.quicksuggest.enabled" = false;
              "browser.urlbar.addons.featureGate" = false;
              "browser.urlbar.amp.featureGate" = false;
              "browser.urlbar.importantDates.featureGate" = false;
              "browser.urlbar.market.featureGate" = false;
              "browser.urlbar.mdn.featureGate" = false;
              "browser.urlbar.trending.featureGate" = false;
              "browser.urlbar.weather.featureGate" = false;
              "browser.urlbar.wikipedia.featureGate" = false;
              "browser.urlbar.yelp.featureGate" = false;
              "browser.urlbar.yelpRealtime.featureGate" = false;
              "browser.urlbar.trustPanel.breachAlerts.featureGate" = false;
              "extensions.getAddons.showPane" = false;
              "extensions.htmlaboutaddons.recommendations.enabled" = false;
              "browser.vpn_promo.enabled" = false;
              "browser.promo.focus.enabled" = false;
              "browser.contentblocking.report.hide_vpn_banner" = true;
              "browser.ml.chat.enabled" = false;
              "browser.ml.chat.menu" = false;
              "browser.ml.linkPreview.enabled" = false;
              "browser.tabs.groups.smart.enabled" = false;
              "browser.search.update" = false;
              "browser.region.network.url" = "";
              "browser.region.update.enabled" = false;
              "media.gmp-manager.url" = "data:text/plain,";
              "media.gmp-provider.enabled" = false;
              "media.gmp-gmpopenh264.enabled" = false;
              "security.csp.reporting.enabled" = false;
            }
            + prefs "defaultPref" {
              "security.OCSP.enabled" = 0;
              "privacy.globalprivacycontrol.enabled" = true;
              "browser.cache.disk.enable" = false;
              "network.IDN_show_punycode" = true;
              "pdfjs.enableScripting" = false;
              "signon.formlessCapture.enabled" = false;
              "browser.aboutConfig.showWarning" = false;
            };
        })
      ];
    };
}
