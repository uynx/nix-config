const launchers = @launchers@.map((id) => "applications:" + id);
let updated = 0;
for (const panel of panels()) {
  for (const w of panel.widgets()) {
    if (w.type !== "org.kde.plasma.icontasks") continue;
    w.currentConfigGroup = ["General"];
    w.writeConfig("launchers", launchers);
    w.reloadConfig();
    updated++;
  }
}
print(updated);
