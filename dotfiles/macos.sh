# set brave 
open -a "Brave Browser" --args --make-default-browser

open -a "Brave Browser" --args \
--enable-caret-browsing \
--no-first-run \
--no-default-browser-check \
--reduce-accept-language \
--disable-features=PrivacySandboxAdsAPIs \
--disable-domain-reliability \
--no-pings \
--disable-features=Translate \
--disable-prompt-on-repost
