# Enable zram on Fedora Asahi Linux

This guide explains how to enable **zram** on Fedora Asahi Linux while keeping an existing Btrfs-backed swapfile as a fallback swap device.

With this setup, Linux uses compressed zram swap first. The swapfile on disk is used only when zram becomes full.

## Requirements

- Fedora Asahi Linux
- An existing swapfile or swap partition
- Administrator access with `sudo`

This guide assumes that the existing swap device is a Btrfs-backed swapfile, but the zram configuration works with any existing swap device.

## 1. Check the current swap configuration

Before making changes, inspect the active swap devices:

```bash
swapon --show
zramctl
cat /sys/module/zswap/parameters/enabled
```

- `swapon --show` lists active swap devices and their priorities.
- `zramctl` lists active zram devices. If it returns no output, zram is not active.
- If the zswap parameter returns `Y`, zswap is enabled.

Example output for a system using only a swapfile:

```text
NAME               TYPE SIZE USED PRIO
/var/swap/swapfile file   8G  50M   -1
```

## 2. Install the required package

Install `zram-generator`:

```bash
sudo dnf install zram-generator
```

`zram-generator` is the recommended systemd-integrated tool for creating and managing zram swap devices on Fedora and Fedora Asahi Linux.

If the package is already installed, `dnf` will report:

```text
Package "zram-generator-..." is already installed.
Nothing to do.
```

No additional packages are required for this setup.

## 3. Create the zram configuration

Create the configuration file:

```bash
sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
```

This configuration creates a zram swap device equal to half of the physical RAM, compressed with `zstd`, and assigns it priority `100`.

The existing disk swap device remains at its current, lower priority. Linux therefore uses zram first and the disk swap only afterward.

### Choose the zram size

| Configuration | zram size |
|---|---|
| `zram-size = ram / 2` | Half of physical RAM |
| `zram-size = ram * 3 / 4` | Three quarters of physical RAM |
| `zram-size = ram` | Same size as physical RAM |

For most systems, `ram / 2` is a balanced default. zram compresses data, but it still uses real RAM, so avoid allocating more zram than physical memory.

## 4. Disable zswap

zswap and zram can coexist, but zswap may intercept memory pages before they reach zram. To make zram the first swap layer, disable zswap.

Disable it immediately:

```bash
echo 0 | sudo tee /sys/module/zswap/parameters/enabled
```

Make the change persistent across reboots:

```bash
echo 'w /sys/module/zswap/parameters/enabled - - - - 0' | sudo tee /etc/tmpfiles.d/disable-zswap.conf
```

This is important on Fedora Asahi Linux because the system may automatically enable zswap when it detects an existing swapfile.

## 5. Enable and start zram

Reload systemd and enable the zram setup service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now systemd-zram-setup@zram0.service
```

## 6. Verify that zram is active

Run:

```bash
swapon --show
zramctl
cat /sys/module/zswap/parameters/enabled
```

A successful configuration should show:

- `/dev/zram0` with a higher priority than the existing swap device
- The `zstd` compression algorithm
- zswap disabled, indicated by `N` or `0`

Example:

```text
NAME               TYPE      SIZE  USED PRIO
/var/swap/swapfile file        8G 51.3M   -1
/dev/zram0         partition 3.7G    0B  100
```

```text
NAME       ALGORITHM DISKSIZE DATA COMPR TOTAL STREAMS MOUNTPOINT
/dev/zram0 zstd          3.7G  16K   64B   48K         [SWAP]
```

```text
N
```

The exact zram size depends on the amount of RAM installed in the system.

## 7. Monitor zram

Use these commands to monitor memory and swap usage:

```bash
free -h
swapon --show
zramctl
```

In the `zramctl` output:

- `DATA` is the uncompressed data stored in zram.
- `COMPR` is the compressed size of that data.
- `TOTAL` is the total RAM used by the zram device, including metadata.

## 8. Change the zram size

Edit the configuration file:

```bash
sudo nano /etc/systemd/zram-generator.conf
```

For example, to use 75 percent of RAM:

```ini
[zram0]
zram-size = ram * 3 / 4
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
```

Apply the change:

```bash
sudo systemctl daemon-reload
sudo systemctl restart systemd-zram-setup@zram0.service
```

Then verify the new configuration:

```bash
swapon --show
zramctl
```

## Important notes

- **Do not remove the existing swapfile or swap partition if you need hibernation.** zram cannot be used for hibernation because its contents exist only in RAM.
- Keeping both zram and disk swap is useful: zram improves responsiveness, while disk swap provides additional capacity.
- If zram fills frequently, increase its size moderately or reduce memory-heavy workloads.
- If zram is not needed anymore, disable and remove it:

```bash
sudo systemctl disable --now systemd-zram-setup@zram0.service
sudo rm /etc/systemd/zram-generator.conf
sudo systemctl daemon-reload
```
