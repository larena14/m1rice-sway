# Snapper on a separate Btrfs subvolume — Fedora Asahi

Guide to configure Snapper on Fedora Asahi, storing root snapshots in a separate Btrfs subvolume.

Replace these values with your own:

| Value | Example | Description |
|---|---|---|
| `<BTRFS_DEVICE>` | `/dev/nvme0n1p6` | Btrfs partition |
| `<UUID>` | `d981e36c-...` | Main Btrfs filesystem UUID |
| `<BTRFS_TOP_LEVEL_ID>` | `5` | Btrfs top-level subvolume ID |
| `<SNAPSHOTS_SUBVOL>` | `snapshots` | Name of the snapshots subvolume |
| `<SNAPSHOTS_MOUNT>` | `/.snapshots` | Mount point for snapshots |
| `<SNAPPER_CONFIG>` | `root` | Snapper configuration name |
| `<SNAPSHOT_LIMIT>` | `4` | Maximum snapshots; 4 = two DNF pre/post pairs |

## 1. Collect Btrfs information

Get the filesystem UUID:

```bash
sudo blkid <BTRFS_DEVICE>
```

Example:

```bash
sudo blkid /dev/nvme0n1p6
```

List all subvolumes and their IDs:

```bash
sudo btrfs subvolume list <BTRFS_DEVICE>
```

Show the currently mounted root subvolume:

```bash
findmnt -no TARGET,SOURCE,OPTIONS /
```

Show details of the root subvolume:

```bash
sudo btrfs subvolume show /
```

Get the subvolume ID of the currently mounted root:

```bash
sudo btrfs inspect-internal rootid /
```

Show the filesystem default subvolume:

```bash
sudo btrfs subvolume get-default /
```

The Btrfs top-level subvolume normally has ID `5`. It is not listed by `btrfs subvolume list`, but it can be mounted directly with `subvolid=5`.

## 2. Install packages

```bash
sudo dnf install snapper libdnf5-plugin-actions
```

## 3. Create the snapshots subvolume

Mount the top-level Btrfs filesystem:

```bash
sudo mkdir -p /mnt/btrfs
sudo mount -o subvolid=<BTRFS_TOP_LEVEL_ID> <BTRFS_DEVICE> /mnt/btrfs
sudo btrfs subvolume create /mnt/btrfs/<SNAPSHOTS_SUBVOL>
sudo umount /mnt/btrfs
```

Example:

```bash
sudo mkdir -p /mnt/btrfs
sudo mount -o subvolid=5 /dev/nvme0n1p6 /mnt/btrfs
sudo btrfs subvolume create /mnt/btrfs/snapshots
sudo umount /mnt/btrfs
```

Final subvolume layout:

```text
root
home
var/swap
snapshots
```

## 4. Mount the snapshots subvolume

Add this line to `/etc/fstab`:

```fstab
UUID=<UUID>  <SNAPSHOTS_MOUNT>  btrfs  subvol=<SNAPSHOTS_SUBVOL>,compress=zstd:1,ssd,discard=async,space_cache=v2  0 0
```

Example:

```fstab
UUID=d981e36c-3ee4-4e71-a86a-99bddfc7c17d  /.snapshots  btrfs  subvol=snapshots,compress=zstd:1,ssd,discard=async,space_cache=v2  0 0
```

Then run:

```bash
sudo mkdir -p <SNAPSHOTS_MOUNT>
sudo systemctl daemon-reload
sudo mount <SNAPSHOTS_MOUNT>
findmnt <SNAPSHOTS_MOUNT>
```

Example:

```bash
sudo mkdir -p /.snapshots
sudo systemctl daemon-reload
sudo mount /.snapshots
findmnt /.snapshots
```

The source must show:

```text
/dev/nvme0n1p6[/snapshots]
```

## 5. Create the Snapper configuration

Important: `<SNAPSHOTS_MOUNT>` must **not** exist before running `create-config`.

```bash
sudo umount <SNAPSHOTS_MOUNT>
sudo rmdir <SNAPSHOTS_MOUNT>
sudo snapper -c <SNAPPER_CONFIG> create-config /
```

Example:

```bash
sudo umount /.snapshots
sudo rmdir /.snapshots
sudo snapper -c root create-config /
```

Snapper creates a nested `root/.snapshots` subvolume. Replace it with the separate snapshots subvolume:

```bash
sudo mkdir -p /mnt/btrfs
sudo mount -o subvolid=<BTRFS_TOP_LEVEL_ID> <BTRFS_DEVICE> /mnt/btrfs
sudo btrfs subvolume delete /mnt/btrfs/root/.snapshots
sudo umount /mnt/btrfs

sudo mkdir -p <SNAPSHOTS_MOUNT>
sudo mount <SNAPSHOTS_MOUNT>
```

Example:

```bash
sudo mkdir -p /mnt/btrfs
sudo mount -o subvolid=5 /dev/nvme0n1p6 /mnt/btrfs
sudo btrfs subvolume delete /mnt/btrfs/root/.snapshots
sudo umount /mnt/btrfs

sudo mkdir -p /.snapshots
sudo mount /.snapshots
```

Verify:

```bash
sudo snapper -c <SNAPPER_CONFIG> list
sudo snapper -c <SNAPPER_CONFIG> create --description "Test"
sudo snapper -c <SNAPPER_CONFIG> list
```

Example:

```bash
sudo snapper -c root list
sudo snapper -c root create --description "Test"
sudo snapper -c root list
```

Delete the test snapshot:

```bash
sudo snapper -c <SNAPPER_CONFIG> delete <TEST_SNAPSHOT_ID>
```

Example:

```bash
sudo snapper -c root delete 1
```

## 6. Set retention

Keep at most two DNF `pre`/`post` pairs:

```bash
sudo snapper -c <SNAPPER_CONFIG> set-config \
  TIMELINE_CREATE=no \
  TIMELINE_CLEANUP=no \
  NUMBER_CLEANUP=yes \
  NUMBER_MIN_AGE=0 \
  NUMBER_LIMIT=<SNAPSHOT_LIMIT> \
  NUMBER_LIMIT_IMPORTANT=<SNAPSHOT_LIMIT>
```

Example:

```bash
sudo snapper -c root set-config \
  TIMELINE_CREATE=no \
  TIMELINE_CLEANUP=no \
  NUMBER_CLEANUP=yes \
  NUMBER_MIN_AGE=0 \
  NUMBER_LIMIT=4 \
  NUMBER_LIMIT_IMPORTANT=4
```

Enable hourly cleanup:

```bash
sudo systemctl enable --now snapper-cleanup.timer
```

Check the schedule:

```bash
systemctl cat snapper-cleanup.timer
systemctl list-timers snapper-cleanup.timer --no-pager
```

Default schedule:

```ini
OnBootSec=10m
OnUnitActiveSec=1h
```

## 7. Automatic DNF snapshots

Create the DNF actions file:

```bash
sudo mkdir -p /etc/dnf/libdnf5-plugins/actions.d
sudo nano /etc/dnf/libdnf5-plugins/actions.d/snapper.actions
```

Paste, replacing `<SNAPPER_CONFIG>` with your configuration name:

```ini
pre_transaction::::/usr/bin/sh -c echo\ "tmp.snapper_descr=$(ps\ -o\ command\ --no-headers\ -p\ '${pid}')"
pre_transaction::::/usr/bin/sh -c echo\ "tmp.snapper_pre_number=$(snapper\ -c\ <SNAPPER_CONFIG>\ create\ -t\ pre\ -c\ number\ -p\ -d\ '${tmp.snapper_descr}')"
post_transaction::::/usr/bin/sh -c [\ -n\ "${tmp.snapper_pre_number}"\ ]\ &&\ snapper\ -c\ <SNAPPER_CONFIG>\ create\ -t\ post\ -c\ number\ --pre-number\ "${tmp.snapper_pre_number}"\ -d\ "${tmp.snapper_descr}"\ ;\ echo\ tmp.snapper_pre_number\ ;\ echo\ tmp.snapper_descr
```

Example for the default `root` configuration:

```ini
pre_transaction::::/usr/bin/sh -c echo\ "tmp.snapper_descr=$(ps\ -o\ command\ --no-headers\ -p\ '${pid}')"
pre_transaction::::/usr/bin/sh -c echo\ "tmp.snapper_pre_number=$(snapper\ -c\ root\ create\ -t\ pre\ -c\ number\ -p\ -d\ '${tmp.snapper_descr}')"
post_transaction::::/usr/bin/sh -c [\ -n\ "${tmp.snapper_pre_number}"\ ]\ &&\ snapper\ -c\ root\ create\ -t\ post\ -c\ number\ --pre-number\ "${tmp.snapper_pre_number}"\ -d\ "${tmp.snapper_descr}"\ ;\ echo\ tmp.snapper_pre_number\ ;\ echo\ tmp.snapper_descr
```

## 8. Test

```bash
sudo dnf install cowsay
sudo dnf remove cowsay
sudo snapper -c <SNAPPER_CONFIG> list
```

Example:

```bash
sudo dnf install cowsay
sudo dnf remove cowsay
sudo snapper -c root list
```

You should see `pre` and `post` snapshots with `Cleanup=number`.

Force cleanup:

```bash
sudo snapper -c <SNAPPER_CONFIG> cleanup number
sudo snapper -c <SNAPPER_CONFIG> list
```

Example:

```bash
sudo snapper -c root cleanup number
sudo snapper -c root list
```

## 9. Rollback

List snapshots:

```bash
sudo snapper -c <SNAPPER_CONFIG> list
```

Example:

```bash
sudo snapper -c root list
```

Compare the current system with a snapshot:

```bash
sudo snapper -c <SNAPPER_CONFIG> diff <SNAPSHOT_ID>..0
```

Example:

```bash
sudo snapper -c root diff 9..0
```

Restore the root subvolume:

```bash
sudo snapper -c <SNAPPER_CONFIG> rollback <SNAPSHOT_ID>
sudo reboot
```

Example:

```bash
sudo snapper -c root rollback 9
sudo reboot
```

This restores only `/`. `/home` and `var/swap` remain untouched.

## Useful commands

```bash
# List snapshots
sudo snapper -c <SNAPPER_CONFIG> list

# Create a manual snapshot
sudo snapper -c <SNAPPER_CONFIG> create --description "Manual snapshot"

# Delete a snapshot
sudo snapper -c <SNAPPER_CONFIG> delete <SNAPSHOT_ID>

# Show configuration
sudo snapper -c <SNAPPER_CONFIG> get-config

# Run cleanup manually
sudo snapper -c <SNAPPER_CONFIG> cleanup number

# Check Btrfs space
sudo btrfs filesystem usage /

# List Btrfs subvolumes
sudo btrfs subvolume list <BTRFS_DEVICE>

# Show the Btrfs top-level/default subvolume
sudo btrfs subvolume get-default /
```
