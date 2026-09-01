# nixos-config

Dendritic flake: `flake-parts` + `import-tree`. Every `.nix` under `modules/` is
imported automatically and modules find each other by output name, never by
path — so files can be moved freely, and directories are pure navigation.
Anything prefixed `_` is skipped by import-tree.

## Layout

| Path | Role |
|------|------|
| `modules/parts.nix` | flake-parts plumbing; declares the flake outputs that need to merge |
| `modules/lib/` | `flake.lib` — the user identity and the `mkBundle` helper |
| `modules/hosts/` | One dir per machine, plus the Home Manager base wiring |
| `modules/hardware/` | Per-architecture hardware, no software choices |
| `modules/system/` | Base NixOS every host wants; no desktop, no hardware |
| `modules/darwin/` | The same for macOS — nix-darwin has its own module system |
| `modules/apps/` | One dir per program, holding **every** tier it needs |
| `modules/bundles/` | The host-facing switches — one line each, both tiers |
| `steam-asahi/` | Fedora Asahi Steam container and runbook |

`modules/apps/<name>/` is the unit of *implementation*: niri's NixOS module and
its KDL config live in the same directory, and a directory may export any mix of
`nixosModules`, `darwinModules`, `homeModules` and wrapped `packages`. Where a
program needs a different delivery on macOS — a cask instead of a nixpkgs build —
that goes in `<name>/darwin.nix`, beside the shared half rather than off in a
macOS tree of its own.

`modules/bundles/<name>.nix` is the unit of *choice*. A bundle pulls every tier
of a component together so a host lists it once. Without this a host has two
separate lists and dropping a component means editing both.

## The two platforms

`mkBundle` returns both a NixOS and a darwin module from one definition, because
the Home Manager half is usually identical and only the system half differs. So
`modules/hosts/darwin/` reads like `modules/hosts/asahi/`: the same bundle names,
one line each, and moving a component between the machines is moving a line.
Where the home tier differs by an entry or two, `homeLinux` and `homeDarwin` add
to the shared `home` list rather than restating it — a bundle is one `mkBundle`
call, never two.

Everything portable is shared as-is. Where a package exists on only one platform
the *app module* absorbs it — a `lib.optional stdenv.hostPlatform.isLinux` beside
the package, and a cask in `darwin.nix` — so hosts never branch. An app splits
into two files only when the platforms share no *structure*, the way
`apps/launchers/` does — different browser binary, different window handling —
and whatever text the two halves still have in common goes in an `_`-prefixed
file beside them rather than in both. One differing package name stays a
ternary. Two rules keep that working:

* **Never branch a module on `pkgs`.** `if isDarwin then … else …` around a
  module body makes the import depend on config, which is an infinite recursion
  inside Home Manager. Use `lib.mkIf` on the *values* instead — see
  `modules/apps/ghostty/default.nix`.
* **A darwin module may not share a name with the bundle that imports it**:
  `flake.darwinModules.office` defined in terms of `self.darwinModules.office`
  is the same recursion by another route. Otherwise a darwin module is named
  after its own directory, matching the home module beside it — only
  `mediaCasks` needs a distinct name, because `apps/media/` and the `media`
  bundle are spelled the same.

A third rule keeps the shell out of it:

* **The shell may not name a component.** `apps/fish/` holds no command that
  drives another program: `vpn` lives in `apps/obscura/`, `android` in
  `apps/waydroid/`. A component that needs to
  run something at `update` or `reb` time registers it through `shellHooks`
  (declared in `apps/fish/default.nix`, loaded for every Home Manager user by
  `homeManagerBase`), so a host that drops the component drops the command with
  it rather than keeping one that fails.

## Adding or removing a component

Edit exactly one line in `modules/hosts/<host>/default.nix`. Delete `ai` and
every AI CLI, its skills wiring and dictation are gone. Replace `desktopNiri`
with `desktopKde` and the compositor, greeter, bar and GTK theme all change
together.

| Bundle | Contents | macOS |
|---|---|---|
| `desktopNiri` | niri, sddm-astronaut greeter, noctalia, GTK theme, screen utils, `android` | — |
| `desktopKde` | Plasma 6, sddm, spectacle | — |
| `desktopMacos` | AeroSpace, SketchyBar, JankyBorders, wallpaper, file associations | only |
| `shell` | fish, ghostty, tmux, starship, yazi, btop, CLI tooling | yes |
| `programming` | language toolchains, git, nvim (+ colima on macOS) | yes |
| `office` | obsidian, libreoffice | yes (`libreoffice-bin`) |
| `latex` | texlive scheme-full (stable pin) | yes |
| `media` | obs, mpv, qbittorrent, image tooling | casks OBS/Streamlabs/BlackHole |
| `comms` | vesktop, whatsapp | whatsapp only, no vesktop |
| `web` | brave-origin and its profile launchers | cask Brave + menu shortcuts |
| `secrets` | sops (age), rage, Bitwarden | Bitwarden only; needs its own key in `.sops.yaml` |
| `cloud` | rclone gdrive + crypt mount (pulls `sops` itself) | needs its own secrets |
| `privacy` | obscura VPN + egress lockdown + `vpn`, tor and mullvad browsers | three casks, no `vpn` |
| `ai` | every AI CLI, shared skills/AGENTS.md, dictation | Homebrew CLIs + desktop apps |
| `gaming` | Steam via the Fedora/FEX distrobox container | — |

Every bundle needs `homeManagerBase`, on either platform — it carries the Home
Manager wiring and the `shellHooks` option declarations.

On macOS the AI CLIs come from Homebrew rather than the pins in
`modules/apps/ai-tools/linux.nix`, which are aarch64-linux artifacts, and the
desktop apps come along with them. `update-ai-clis` still maintains the tools
that have neither a pin nor a formula (agy, openclaw, t3 and hermes);
`greedyCasks` keeps the rest current on every rebuild.

## Commands

```bash
reb              # rebuild (stages first — a flake build cannot see untracked files)
update && reb    # relock every input + bump pinned tools, then rebuild
update nvf       # relock one input only
```

`reb` targets the machine's own hostname on Linux and `darwin` on macOS, and
drives `nh os` or `nh darwin` accordingly; pass a host name to override it. The
hostname doubles as the flake attribute on every NixOS host here, which is why
that needs no per-host branch. Both commands are
assembled per host: `update` runs the pin updaters this host installed and
`reb` runs its post-switch hooks, so neither names a component this host may
not have. `nix fmt` formats the tree with nixfmt, and `statix check .` should
report nothing.

Rebuilds need `--impure`, which `reb` passes: the Asahi firmware directory has
to stay a real path, and the AI skills are read out of a working copy. See
`modules/hardware/asahi.nix`.

## Fresh install

Everything except one file is in this repo. That file is the age identity that
decrypts `secrets/`, and it has to be in place **before the first `reb`** —
without it `sops-nix.service` fails while the rebuild still succeeds, so you
get a working desktop with no SSH key and no Drive mount and nothing but an
inactive unit to say why.

```bash
bw login && bw unlock                 # or run these from the installer ISO
bw get notes 'sops age key' | install -Dm600 /dev/stdin ~/.config/sops/age/keys.txt
gh auth login
git clone https://github.com/uynx/nix-config.git ~/nixos-config
cd ~/nixos-config && reb
```

The HTTPS clone URL is deliberate — `git` rewrites GitHub HTTPS to SSH at
connect time, which cannot work until the SSH key comes out of sops.

## First rebuild on a Mac

Homebrew itself is not declarative — install it once, or the activation fails
with `command not found`:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
nix run nix-darwin -- switch --flake ~/nixos-config#darwin --impure
```

After that first switch `reb` works like it does on Linux.
