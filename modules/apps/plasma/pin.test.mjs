import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const src = readFileSync(new URL("./pin.js", import.meta.url), "utf8");

function widget(type) {
  const w = { type, config: {}, reloaded: false, currentConfigGroup: [] };
  w.writeConfig = (key, value) => {
    w.config[w.currentConfigGroup.join("/") + ":" + key] = value;
  };
  w.reloadConfig = () => {
    w.reloaded = true;
  };
  return w;
}

function run(panelWidgets, launchers) {
  const out = [];
  const panels = () => panelWidgets.map((ws) => ({ widgets: () => ws }));
  const body = src.replace("@launchers@", JSON.stringify(launchers));
  new Function("panels", "print", body)(panels, (s) => out.push(String(s)));
  return out.join("\n");
}

test("the task manager gets the declared launchers in order", () => {
  const tasks = widget("org.kde.plasma.icontasks");
  run([[widget("org.kde.plasma.kickoff"), tasks]], ["brave-origin.desktop", "com.mitchellh.ghostty.desktop"]);
  assert.deepEqual(tasks.config["General:launchers"], [
    "applications:brave-origin.desktop",
    "applications:com.mitchellh.ghostty.desktop",
  ]);
  assert.equal(tasks.reloaded, true);
});

test("it reports how many task managers it updated, so the caller can retry before the panel exists", () => {
  assert.equal(run([], ["firefox.desktop"]), "0");
  assert.equal(
    run([[widget("org.kde.plasma.icontasks")], [widget("org.kde.plasma.icontasks")]], ["firefox.desktop"]),
    "2",
  );
});
