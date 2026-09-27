# Reinstalling a machine

Covers `asahi` (NixOS beside macOS on the MacBook), `darwin` (that macOS) and
`x86` (the desktop). The repo reproduces the *system*; the only secret it cannot
hold is the age identity that decrypts `secrets/`, kept in Bitwarden. Everything
else converges from `reb`.

## 1. Before wiping anything

Nothing in this table is in git, Drive or iCloud, and `tmutil` has no
destination. Copy it to an external disk.

| macOS | Asahi |
|---|---|
| `~/513 ~/514 ~/546 ~/589 ~/comps` | anything outside the three repos |
| `~/Documents ~/Pictures ~/Music ~/Downloads` | Steam library, if worth 236 GB of copying |
| `~/.local/share/atuin` (shell history) | `~/.local/share/atuin` |

`~/gdrive` needs nothing: it is an rclone mount, and its contents come back once
secrets land.

Then, while this machine still works:

* **Open the Bitwarden secure note `sops age key` from the phone** and check it
  is non-empty. It is the entire recovery for every host — one age identity, one
  recipient in `.sops.yaml`. The older `GPG master key` note decrypts nothing.
* **Get a Bitwarden 2FA code on the phone.** The chain is
  `Bitwarden → age key → everything`; if the second factor lives only in Ente
  Auth on the machine being erased, the vault holding the key is locked. Ente
  syncs server-side, so the phone app or the Ente recovery key is enough —
  confirm it, do not assume it.
* **Push `~/nix-config`, `~/dotfiles` and `~/ai_memory`.** Every clone below
  comes from GitHub, never from a backup.

## 2. Choose the depth (MacBook)

* **NixOS root only** — macOS, the Asahi stub (p3) and the ESP (p4) stay. Skip
  steps 4 and 5; in step 6, reformat the existing root instead of creating one.
* **Full** — macOS is reinstalled too, which destroys p3, p4 and the root. Do
  every step, in order.

## 3. Build the Asahi installer stick

The flake has no `linux-builder` and no `extra-platforms`, so the `aarch64-linux`
ISO **cannot be built on the Mac** — build it from the running NixOS install,
before wiping it.

```bash
cd ~/nix-config
nix build .#nixosConfigurations.iso.config.system.build.isoImage --impure
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

**This image has only been booted in QEMU.** Keep a stock Asahi ISO on a second
stick; if the custom one fails, boot the stock one and run Determinate's
installer in its live environment. That costs only faster eval and the
preconfigured substituters.

The image carries `claude`, `vim`, `git`, `gh`, `bw`, `rg` and `fd`, so the
install can be driven from an agent session. It has no browser, so Claude Code
and `gh` both log in with the paste-a-code flow on a phone, and no `~/dotfiles`,
so the session runs without `CLAUDE.md` or skills until that is cloned.

## 4. The macOS stick (fallback only)

Erase All Content and Settings needs no stick. This is for a Mac that boots but
will not erase; one that does not boot at all needs a DFU restore from a second
Mac instead.

The installer app's `Info.plist` does not say what it installs —
`DTPlatformVersion`, `CFBundleShortVersionString` and `DTSDKBuild` describe the
SDK it was built against (a 26.6.2 installer reports `26.6.1` / `21.6.01` /
`25G74`). Read the payload:

```bash
hdiutil attach -nobrowse -readonly -noverify \
  "/Volumes/Install macOS Tahoe/Install macOS Tahoe.app/Contents/SharedSupport/SharedSupport.dmg"
rg -o '<key>(OSVersion|Build)</key>\s*<string>[^<]*' -U \
  "/Volumes/Shared Support/com_apple_MobileAsset_MacSoftwareUpdate/com_apple_MobileAsset_MacSoftwareUpdate.xml"
hdiutil detach "/Volumes/Shared Support"
```

Rewrite the stick only if that build is older than what
`softwareupdate --list-full-installers` offers:

```bash
softwareupdate --fetch-full-installer --full-installer-version <version>
sudo "/Applications/Install macOS Tahoe.app/Contents/Resources/createinstallmedia" \
  --volume "/Volumes/Install macOS Tahoe"
```

`softwareupdate` exits 0 even when the download fails (`PKDownloadError Code=8`
at 90%), so check `/Applications/Install macOS Tahoe.app` exists. Re-read the
stick's disk identifier right before writing; it changes across replugs.

## 5. Reinstall macOS

Always before the Linux side: a macOS install updates the shared Apple SFR, and
m1n1 must be newer than the SFR it boots against, so macOS-after-NixOS can leave
a stub that no longer boots.

Erase All Content and Settings, then, still in macOS:

```bash
curl https://alx.sh | sh     # choose "UEFI environment only"
```

The NixOS partition is made by hand in step 6. This run also writes a fresh
`vendorfw/` to the ESP — the only way that firmware ever refreshes.

Leave FileVault **off** until `alx.sh` finishes, so the resize needs no
`diskutil apfs unlockVolume`. Then `sudo fdesetup enable` with a local recovery
key, not iCloud escrow, and store that key in Bitwarden. It is near-instant on
Apple Silicon. LUKS covers only the NixOS root; FileVault is the only encryption
macOS gets.

Bootstrap nix-darwin. Sign into the App Store first — `mas` needs it, or
`cakewallet` silently never installs.

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# new terminal, so nix is on PATH
nix shell nixpkgs#bitwarden-cli nixpkgs#gh
bw login && bw unlock
bw get notes 'sops age key' | install -Dm600 /dev/stdin ~/.config/sops/age/keys.txt
gh auth login
git clone https://github.com/uynx/nix-config.git ~/nix-config
nix run nix-darwin -- switch --flake ~/nix-config#darwin --impure
```

The age key goes in before the first switch for the reason in step 9: a missing
key fails the sops launchd agent while `darwin-rebuild` still exits 0. Verify:

```fish
launchctl list | rg sops        # org.nix-community.home.sops-nix, status 0
ls -l ~/.ssh/id_ed25519         # symlink into ~/.config/sops-nix/secrets
ls ~/.config/sops-nix/secrets   # six files: the ssh key plus five rclone
ssh -T git@github.com           # GitHub greeting; exits 1 even on success
```

From here `reb` works normally.

eduroam is a configuration profile, which nix-darwin cannot install and Apple
makes a human approve; its credentials live in the login keychain, not sops:

```fish
open modules/system/umass-eduroam.mobileconfig
```

Then System Settings → General → Device Management → Install, join `eduroam`,
and enter `<netid>@umass.edu` with the NetID password.

## 6. Live environment

Boot the stick; it autologs in. Bring up networking with `nmcli` or `iwctl`.
Keep USB-C ethernet or phone tethering at hand: if firmware extraction failed,
there is no Wi-Fi.

### Partitions

**Partition numbers do not survive a macOS reinstall. Read the table before
typing any device node** — `sgdisk -p /dev/nvme0n1` and
`parted /dev/nvme0n1 unit GiB print free`. After the 2026-09-03 rebuild:

| part | contents | rule |
|---|---|---|
| p1 | `iBootSystemContainer` | never touch |
| p2 | macOS APFS container | never touch |
| p3 | Asahi stub, m1n1 + U-Boot | from `alx.sh` |
| p4 | `EFI - NIXOS`, the ESP | **never `mkfs`** |
| p5 | `RecoveryOSContainer` | **never touch — this index used to be the root** |
| p6 | NixOS root | created by hand below |

macOS Recovery lands on whatever index is spare, and upstream warns that damaging
the first or the last partition can cost the whole disk. The root is the
partition you create, never one you find.

p4 holds `vendorfw/firmware.cpio`, `m1n1/` and `EFI/`; the installer finds it
through `/proc/device-tree/chosen/asahi,efi-system-partition` to extract
firmware. Reformat it and the installer loses Wi-Fi and the installed system
loses its bootloader, recoverable only by redoing step 5.

After a full wipe the root does not exist — `alx.sh` leaves the freed space
unallocated between p4 and recovery. Create it in the largest free block:

```bash
sgdisk -n 0:0:0 -t 0:8300 -c 0:NIXOS /dev/nvme0n1
partprobe /dev/nvme0n1
lsblk -o NAME,SIZE,FSTYPE,PARTLABEL /dev/nvme0n1    # confirm the number it got
```

For a root-only wipe, skip that and use the existing root's number.

### Encrypt, format, mount

LUKS wraps the block device, so it comes before `mkfs` and cannot be added later.

```bash
cryptsetup luksFormat /dev/nvme0n1p6      # the root, as read above
cryptsetup open /dev/nvme0n1p6 cryptroot
mkfs.ext4 -L nixos /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt
mkdir -p /mnt/boot && mount /dev/nvme0n1p4 /mnt/boot
mkdir -p /boot && mount --bind /mnt/boot /boot
```

`cryptsetup` and `gh auth login` need a real TTY. From an agent's shell,
`cryptsetup` fails with `Nothing to read on input` and writes nothing; run them
at the console, or suspend the agent with `Ctrl+Z` and `fg` back.

The bind mount exists because `peripheralFirmwareDirectory = /boot/vendorfw` in
`modules/hardware/asahi.nix` is a path literal read at eval time, and the live
image has no `/boot`. Without it `nixos-install` dies before building anything.

### Swap

The live image has no swap and the machine has 16 GB. Without swap the OOM killer
takes out `nix` partway through the Rust builds: exit 137, nothing in the log,
`Out of memory: Killed process ... (nix)` only in `dmesg`.

```bash
fallocate -l 32G /mnt/.swapfile && chmod 600 /mnt/.swapfile
mkswap /mnt/.swapfile && swapon /mnt/.swapfile
```

## 7. Clone the flake

The repo is private and the SSH key that would authenticate is inside it, so
HTTPS through `gh` is the only way in:

```bash
gh auth login
mkdir -p /mnt/home/uynx
git clone https://github.com/uynx/nix-config.git /mnt/home/uynx/nix-config
```

The clone lives in the target home, so it is the one the installed system uses.
The HTTPS remote keeps working after first boot: git's `insteadOf` rewrite to
SSH applies at connect time.

## 8. Hardware config and install

```bash
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/home/uynx/nix-config/modules/hosts/asahi/_hardware-configuration.nix
```

Never skip this because the file already exists: it pins the old root and LUKS
UUIDs, which change on every reformat. `nixos-generate-config` writes the
`boot.initrd.luks.devices.cryptroot` entry itself.

The generated `boot.initrd.availableKernelModules` is nearly empty (`usb_storage`,
`sdhci_pci`). Leave it: the option merges with the Asahi set from
`apple-silicon-support`, and the built initrd carries `hid-apple` and both
`spi-hid-apple` modules, so the internal keyboard works at the passphrase
prompt.

Commit, then install — `import-tree` silently skips untracked files:

```bash
cd /mnt/home/uynx/nix-config && git add -A && git commit -m "hardware config"
nixos-install --flake /mnt/home/uynx/nix-config#asahi --impure \
  --no-root-passwd --max-jobs 2 --cores 4
```

`--impure` keeps the firmware directory a real path. `--max-jobs 2 --cores 4`
keeps the Rust builds (`wasmtime`, `determinate-nix`, `obs-studio`, the
`obscuravpn` chain) inside 16 GB. Expect about 75 minutes and 50 GB written;
`linux-asahi` comes from the cache, so there is no kernel compile. Check
`nixos-install`'s own exit status — piping it into `tail` reports `tail`'s.

`sops-install-secrets` failing with
`cannot read keyfile '/home/uynx/.config/sops/age/keys.txt'` is expected here;
step 9 fixes it.

Then the four things `nixos-install` leaves undone:

```bash
chown -R 1000:100 /mnt/home/uynx
rm -f /mnt/etc/nixos/*.nix && rmdir /mnt/etc/nixos
swapoff /mnt/.swapfile && rm /mnt/.swapfile
nixos-enter --root /mnt -c 'passwd uynx'
reboot
```

* **`passwd` is not optional.** `modules/system/user.nix` sets no
  `hashedPassword` and `mutableUsers` is true, so the password lives only in the
  new, empty `/etc/shadow`. Skip it and the install is green, the desktop works,
  and nothing gets past the greeter.
* **`/etc/nixos` must go** because `core.nix` makes it a symlink to
  `/home/uynx/nix-config`, and activation will not replace a directory holding
  real files. The symptom is `could not create symlink /etc/nixos`.
* The installed system makes its own 16 GB `/swapfile`.

The ESP fits **three** generations: 476 M, of which ~126 M is firmware and each
kernel/initrd pair is 91 M. `configurationLimit` in
`modules/hardware/asahi.nix` is 10, so the fourth generation's activation dies
with ENOSPC mid-write.

## 9. First boot: the age key

Log in as `uynx`. Everything works except secrets — `sops-nix.service` has
failed because its key is missing.

```fish
bw login && bw unlock
bw get notes 'sops age key' | install -Dm600 /dev/stdin ~/.config/sops/age/keys.txt
systemctl --user restart sops-nix.service
```

If `bw unlock` says `The decryption operation failed` with the right password,
the CLI's cached keys are stale after a vault KDF change; `bw logout && bw login`
is the only fix.

Verify:

```fish
systemctl --user status sops-nix.service    # active (exited)
ls -l ~/.ssh/id_ed25519                     # symlink into ~/.config/sops-nix/secrets
ssh -T git@github.com                       # GitHub greeting; exits 1 even on success
```

The SSH key needs no restore: the public half is already on GitHub, and the
private half is ciphertext in `secrets/secrets.yaml`. The `.pub` file that
commit signing reads is derived from it by a `home.activation` hook in
`modules/apps/sops` on the next `reb`.

**The age key must be in place before the first `reb`.** A missing key fails the
user unit while `nixos-rebuild` still exits 0: a green rebuild, a working
desktop, no SSH key, no Drive mount, and only an inactive unit to show for it.

## 10. Converge

```fish
cd ~/nix-config && reb
```

Reboot once. The AI CLIs install themselves through
`home.activation.installRollingAiClis`, the Steam container rebuilds on first
launch, and rclone remounts `~/gdrive`. Steam game data is gone unless it was
backed up in step 1.

## 11. The x86 desktop

Steps 9 and 10 apply unchanged. Steps 2–8 are Apple-specific; this replaces them.

### 11.1 The stick

Build it on the desktop itself before wiping, or on the MacBook's NixOS, where
`boot.binfmt.emulatedSystems = [ "x86_64-linux" ]` makes it buildable. The Mac
has no `linux-builder`.

```bash
nix build .#nixosConfigurations.iso-x86.config.system.build.isoImage
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

About 35 minutes, nearly all of it the 3.1 GiB fetch; the image is 3.3 GiB.

It is graphical — GNOME, autologin as `nixos`, Brave — so the Bitwarden web
vault opens on the machine being installed and the age key is never retyped off
a phone. `bw`, `sops`, `rage`, `cryptsetup`, `gh` and `claude` are on it, and so
is this file. Keep a stock NixOS graphical ISO on a second stick: the 1070 runs
on nouveau in the live image and GDM may fall back to X11.

### 11.2 Partition

Read the disk first — it may hold a Windows ESP worth reusing or data worth
keeping:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,PARTLABEL
sgdisk -p /dev/nvme0n1
```

Wiping the whole disk:

```bash
sgdisk -Z /dev/nvme0n1
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:ESP   /dev/nvme0n1
sgdisk -n 2:0:0   -t 2:8300 -c 2:NIXOS /dev/nvme0n1
partprobe /dev/nvme0n1

mkfs.fat -F32 -n BOOT /dev/nvme0n1p1
cryptsetup luksFormat /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 cryptroot
mkfs.ext4 -L nixos /dev/mapper/cryptroot

mount /dev/mapper/cryptroot /mnt
mkdir -p /mnt/boot && mount /dev/nvme0n1p1 /mnt/boot
```

The 1 GiB ESP has no Apple firmware in it, so `configurationLimit = 10` fits.
The same TTY rule as step 6 applies to `cryptsetup` and `gh auth login`. No
`/boot` bind mount is needed; that is an Asahi firmware quirk.

### 11.3 Flake, hardware config, install

```bash
gh auth login
mkdir -p /mnt/home/uynx
git clone https://github.com/uynx/nix-config.git /mnt/home/uynx/nix-config

nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/home/uynx/nix-config/modules/hosts/x86/_hardware-configuration.nix
```

Before committing, check the new file:

* **Re-add** `boot.initrd.luks.devices."cryptroot".allowDiscards = true;` — the
  generated file drops it, and without it LUKS blocks discards, the weekly
  `fstrim` does nothing, and writes slow as the drive fills. The cost is that
  someone holding the disk can see how much of it is in use.
* **`availableKernelModules` must include `xhci_pci` and `usbhid`.** Every
  keyboard here is USB; a passphrase prompt that cannot read one is
  unrecoverable.

```bash
cd /mnt/home/uynx/nix-config && git add -A && git commit -m "x86 hardware config"
nixos-install --flake /mnt/home/uynx/nix-config#x86 --no-root-passwd
```

No `--impure`: the x86 host evaluates purely. `--max-jobs`/`--cores` stay at
their defaults; if `free -g` shows 16 GB, clamp them and add the swapfile as in
step 6. The NVIDIA driver is unfree, so it is never in the binary cache — expect
a local kernel-module compile.

Then the same cleanup as step 8:

```bash
chown -R 1000:100 /mnt/home/uynx
rm -f /mnt/etc/nixos/*.nix && rmdir /mnt/etc/nixos
nixos-enter --root /mnt -c 'passwd uynx'
reboot
```

After first boot there is no Steam container to rebuild: this host uses native
Steam (`gamingNative`).
