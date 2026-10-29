# 阶段 0：备份和 fastboot 实测

日期：2026-10-29。路线图是 `docs/sambar-roadmap.md`。本文只记阶段 0：怎么抽、抽到哪、哪些命令会把镜像抽坏，以及这一步已经发生过的事。备份和 fastboot 实测已经做完。手机回到了 Android，没有刷任何分区，没有执行 `oem unlock`。

完成标准：`/run/media/alpha/YMTC/sambar/device-backup/` 里有 boot、recovery 和基带校准的原始镜像，字节数和 sysfs 一致，`SHA256SUMS` 能复核；接着这台 Linux 电脑在不带 `-i` 的情况下能列出 bootloader。这两条都已达到。

## 结果

root 是 Magisk 27.0（版本号 27000）。`adb shell su -c id` 返回 `uid=0(root)`，SELinux 上下文 `u:r:magisk:s0`，`getenforce` 是 `Enforcing`。`su 0 id` 会打开一个交互 shell 并一直停着，不能用来跑命令。

27 个分区镜像在 `/run/media/alpha/YMTC/sambar/device-backup/`。`sha256sum -c SHA256SUMS` 在抽完时和从 bootloader 重启回 Android 之后都通过。`by-name` 和阶段说明里的 `mmcblk0pN` 一一对应。

toybox `dd` 把 `records in/out` 打到 stdout。`adb exec-out` 必须在设备侧把这段丢掉，否则镜像末尾会多几十个字节：

```bash
adb exec-out su -c "dd if=/dev/block/bootdevice/by-name/NAME bs=1048576 count=N 2>/dev/null"
```

块大小用 1 MiB 或 4 KiB，只要 `bs * count` 等于分区字节数。`/data/local/tmp` 上 root 写出的文件，shell 用户 `adb pull` 会被 SELinux 拒绝，所以没有走 pull。

`/data/adb` 打成了 `data-adb.tar`（5514752 字节），里面是 Magisk 27 的 `magisk.db` 和二进制。cmdline 原文在 `cmdline.txt`（466 字节）。序列号仍是占位值 `012345ABCDE`。

正在运行的 cmdline 后半段是 bootloader 接上去的：

```text
androidboot.bootdevice=f9824900.sdhci androidboot.serialno=012345ABCDE androidboot.bootloader=sambar-12-g5c5fdd4 androidboot.normalboot=1 androidboot.baseband=msm mdss_mdp.panel=1:dsi:0:qcom,mdss_dsi_sharp_qhd_cmd_0:1:qcom,mdss_dsi_sharp_qhd_cmd_1
```

面板节点是 `qcom,mdss_dsi_sharp_qhd_cmd_0` 和 `qcom,mdss_dsi_sharp_qhd_cmd_1`。内核源码里对应 `dsi-panel-sharp-dual0qhd-cmd.dtsi` 和 `dsi-panel-sharp-dual1qhd-cmd.dtsi`。

boot 镜像头和 `BoardConfig.mk` 的 ramdisk、tags 偏移不一致，但这就是当前能启动的那一份：

| 项 | 正在运行的 boot | BoardConfig / recovery |
| --- | --- | --- |
| page size | 4096 | 4096 |
| kernel addr | `0x8000` | `0x8000` |
| ramdisk addr | `0x01000000` | `0x02000000` |
| tags addr | `0x100` | `0x01E00000` |
| kernel | 8136468 字节，gzip（`1f 8b`） | recovery 是未压缩 ARM64 Image |
| ramdisk | 1830727 字节，gzip | |
| DT | 头里的 dt 字段 11190272 字节，QCDT 版本 2，55 个 DTB | `BOARD_DTBTOOL_ARGS := -2`，分离 DT |

QCDT 里和这台机器相关的条目平台号是 `0xcf`（soc id 207），variant `0x19`（设备树里的 board-id 25）。v2.1 的 Compal 条目有 DVT3（第二个字段 `0x4`）和 PVT（`0x5`），和两份 `msm8994-v2.1-pm9x-*.dts` 一致。`/proc/device-tree` 和 `/sys/firmware/devicetree` 都不存在，实机落在 DVT3 还是 PVT 还没读到。`scripts/extract-ikconfig` 从 boot 抽出 4057 行，`Linux/arm64 3.10.84`，`CONFIG_LOCALVERSION="-lineageos"`，`CONFIG_LOCALVERSION_AUTO=y`，`CONFIG_TOUCHSCREEN_ATMEL_MXT_PM9X=y`，`CONFIG_SILEAD_DEVICE=y`。`uname` 里的 `gc7efee3` 来自编译那棵树时的自动本地版本，那次提交仍不在当前克隆里。

recovery 分区前 41275392 字节与 `third_party/YUTOPIA_TWRP_2.8.7.img` 相同，后面是补到 64 MiB 的零。手机里现在的 recovery 就是这份 TWRP 2.8.7。另外两份 img 对不上。本阶段没有刷 recovery。

`devinfo`、`fsc`、`misc`、`keystore` 全是 0。解锁标志不在 `devinfo` 里。aboot、tz、rpm、hyp、sbl1、pmic、persist 和各自的 bak 内容不同，bak 不是一份相同的副本。

blob 在 `/run/media/alpha/YMTC/sambar/blobs/`，`manifest.tsv` 404 条清单路径：`present` 367，`excluded-but-present` 36，`missing` 1。缺的是 `vendor/lib64/libjni_livedisplay.so`。同名文件实际在 `/system/lib/libjni_livedisplay.so`（42920 字节）和 `/system/lib64/libjni_livedisplay.so`（51568 字节），已按这两个路径另存，状态记为 `present-other-path`。面板校准 XML 在，205079 字节。blob 树大约 137 MiB。

fastboot 不需要 `-i`，也不需要新的 udev 规则。`sudo` 要密码，规则文件没有写成。进 bootloader 之后 `lsusb` 是 `2a96:301c`，厂商字符串 MMX，接口类 `ff/42/03`。`fastboot devices` 列出 `012345ABCDE fastboot`。`fastboot oem device-info`：

```text
Device tampered: true
Device unlocked: true
Charger screen enabled: true
```

`getvar version` 是 `0.5`，`version-bootloader` 是 `sambar-12-g5c5fdd4`，`product` 是 `MSM8994`，`max-download-size` 是 `0x20000000`（512 MiB）。`getvar all`、`secure`、`unlocked` 都是空的，锁状态以 `oem device-info` 为准。随后 `fastboot reboot`，adb 恢复为 `2a96:3014`。

这些文件放在移动硬盘上，不进 git。硬盘是 `/dev/sda1`，挂在 `/run/media/alpha/YMTC`，当时剩余约 466 GB。

## 已经发生的事

调查发生在写本文之前，手机一直停在 Android 里。

- adb 序列号 `012345ABCDE`，`product:YUTOPIA`，`model:YU5050`，`device:YUTOPIA`。这个序列号像 bootloader 的占位值。
- `adb root` 没有把 adbd 提权。`ro.debuggable=1`，`ro.secure=1`，shell 仍是 `uid=2000(shell)` `u:r:shell:s0`。
- `/sbin/su` 和 `/sbin/magisk` 都在。`adb shell su -c id` 大约 11 秒后返回 `Permission denied`，手机上的授权框没有被允许。
- `/dev/block/bootdevice/by-name/` 对 shell 是 `Permission denied`。分区名是从 `/sys/block/mmcblk0/mmcblk0p*/uevent` 的 `PARTNAME` 读的，shell 读得了。
- `/proc/cmdline` 对 shell 是 `Permission denied`。
- `/sys/firmware/devicetree/base/model` 不存在。这颗 3.10 内核没有把设备树挂在 sysfs 的这条路径上。root 之后改看 `/proc/device-tree`。
- `/proc/config.gz` 不存在。defconfig 打开了 `CONFIG_IKCONFIG`，配置打在内核镜像里，等 boot 抽出来再用内核树里的 `scripts/extract-ikconfig`。
- `lsusb` 当时是 `2a96:3014`，字符串 Android。这是 MTP+ADB。`/etc/udev/rules.d/` 里没有 Android 规则。当前用户 `alpha` 已经在 `plugdev` 组里。
- fastboot 是 `/home/alpha/Android/Sdk/platform-tools/fastboot`，版本 37.0.1-15733141。`--help` 里没有 `-i`。
- 抽查了五个 `/system` 文件，权限都是 `644`，shell 就能读：`lib/libtfa9887.so`（120824）、`etc/firmware/A4_15_2.2_AA.fw`（148612）、`lib/hw/fingerprint.msm8994.so`（26292）、`vendor/lib/libsrsprocessing.so`（539464）、`etc/pp_calib_data_dual_0_sharp_cmd_mode_dsi_panel.xml`（205079）。后两个在专有文件清单里带减号前缀，设备上仍然存在。

本地三份 TWRP 的文件头在同一天看过，没有刷进手机。记录在文末。

## 实现笔记

Magisk 27 的用法是 `adb shell su -c id` 和 `adb shell su -c "带空格的命令"`。`su 0 id` 按它的帮助是“用户 0，再把 id 当成 shell 的参数”，结果停在交互 shell 里，光标查询转义会一直刷。授权被拒绝时 `su -c` 大约 10 秒后返回 Permission denied，这时才需要看手机上的提示。`getenforce` 已记在 `device-backup/getenforce.txt`，内容是 `Enforcing`。

二进制分区不要走 `adb shell`。shell 是终端，会改换行。用 `adb exec-out`，它不经 pty。`dd` 的 stdout 必须只有分区字节。如果文件开头是 `Permission denied` 的 ASCII，或者长度比下表短，删掉重来，不要给它算 SHA256 之后当备份。

`dd` 用分区的扇区数当 `count`，`bs=512`。这样不会读进下一个分区。Android 6 的 toybox `dd` 认 `if`、`bs`、`count`。抽的时候优先 `if=/dev/block/bootdevice/by-name/<名字>`，同时把 `readlink` 的结果写进 `PARTMAP.txt`。readlink 必须落到下表的 `mmcblk0pN`。对不上就停，改用表里的节点，并在本文补一笔。

`/dev/block/bootdevice/by-name/bluetooth` 在 df 里显示 1.0G。sysfs 是 2048 个扇区，1048576 字节。以扇区数为准。

`extract-files.sh` 在这棵仓库里跑不起来。它把 CyanogenMod 树根算成仓库的上三级，再去找 `vendor/cm/build/tools/extract_utils.sh`。本仓库在 `~/Documents/GitHub/android_device_yu_sambar`，那个脚本不在。blob 用 `adb pull` 按清单路径拉，清单路径相对 `/system`。

清单里以 `-` 开头的行，CM 的 extract 会跳过。阶段 0 仍然要拉。设备上有的，记 `excluded-but-present`；没有的，记 `missing`。`proprietary-files.txt` 里这样的行有面板校准 XML 和 `libsrsprocessing.so`，两个都在。`proprietary-files-qc.txt` 里还有 34 条减号行，多半是这份非官方系统改由源码编译、因此不再当 blob 的库。两份清单去掉空行和注释后一共 404 条路径。

boot 和 recovery 抽完先看开头 8 字节是不是 `ANDROID!`，page size 是不是 4096。和 `BoardConfig.mk` 对照的是：kernel offset `0x8000`，ramdisk `0x02000000`，tags `0x01E00000`，base `0x00000000`。对不上就停在这一步，先改笔记，再进 fastboot。

`devinfo`、`misc`、`config` 不在路线图点名的那一串里，但都很小。`devinfo` 4 KiB，老 LK 的解锁标志经常在这里。`misc` 4 MiB，是 recovery 的 BCB。`config` 1 MiB，`ro.frp.pst` 指向它。三个都抽，只作只读副本。`keystore`、`sbl1`、`pmic` 和各自的 bak 同样只读备份。恢复启动链时先用 bak 分区里已有的副本，主机上的这些文件是第三份。

userdata 整分区不抽。df 显示已用约 4.6 GiB。Magisk 是 systemless，清 data 会丢掉 `/data/adb`。root 可用之后，把 `/data/adb` 打成 tar 放进备份目录。照片和下载不在这个 tar 里。

进 bootloader 用 `adb reboot bootloader`。回来用 `fastboot reboot`。这条 LK 的解锁命令是 `fastboot oem unlock`，会清 data。`fastboot flashing unlock` 是后来的 fastbootd 命令，这颗 bootloader 不认。两个都不跑。只跑 `fastboot devices`、`fastboot oem device-info`、`fastboot getvar all`。`getvar` 在 2015 年的 LK 上经常大段失败，把原文存下来即可。

`third_party/YUTOPIA_TWRP_3.0.2_BROKEN!.img` 不刷。另外两份 TWRP 本阶段也不刷。recovery 分区的内容以抽出来的镜像为准，不拿仓库里的 img 覆盖。

## 目录

```text
/run/media/alpha/YMTC/sambar/device-backup/     分区镜像、SHA256SUMS、PARTMAP.txt、cmdline、getenforce
/run/media/alpha/YMTC/sambar/blobs/system/      按 /system 相对路径放下的 blob
/run/media/alpha/YMTC/sambar/blobs/manifest.tsv 路径、清单前缀、字节数、SHA256、present 或 missing
/run/media/alpha/YMTC/sambar/fastboot/          lsusb -v、fastboot devices、oem device-info、getvar all
```

`sambar/` 已在 2026-10-29 建好。下面的命令块是事先写的步骤。实际跑通的形式以「结果」一节为准：`su -c`，并且 `dd` 的进度输出要在设备侧重定向掉。

## 步骤 1：确认 root

手机亮着，USB 还是 `adb devices` 里的 `device`。

```bash
adb devices -l
adb shell su 0 id
adb shell su 0 getenforce
```

`id` 不是 `uid=0` 就停。看手机上的 Magisk 提示。若超时后仍是 Permission denied，打开 Magisk 的超级用户列表，把 Shell 改成允许，再跑一次。把 `getenforce` 的原文记到备份目录的 `getenforce.txt`，也补进本文的事件节。

## 步骤 2：建目录并核对分区名

```bash
mkdir -p /run/media/alpha/YMTC/sambar/device-backup \
         /run/media/alpha/YMTC/sambar/blobs/system \
         /run/media/alpha/YMTC/sambar/fastboot
adb shell su 0 'ls -l /dev/block/bootdevice/by-name' \
  | tee /run/media/alpha/YMTC/sambar/device-backup/PARTMAP.txt
```

`PARTMAP.txt` 里每个名字都要指向下表的节点。boot 必须是 `mmcblk0p35`，recovery 是 `mmcblk0p36`，modem 是 `mmcblk0p34`，modemst1/modemst2/fsg 分别是 p27/p28/p29。

| 分区 | 节点 | 扇区数 | 字节数 | 用途 |
| --- | --- | --- | --- | --- |
| boot | mmcblk0p35 | 131072 | 67108864 | 现在能启动的内核和 ramdisk |
| recovery | mmcblk0p36 | 131072 | 67108864 | 手机里现有的 recovery |
| modem | mmcblk0p34 | 163840 | 83886080 | 基带固件，挂在 `/firmware` |
| bluetooth | mmcblk0p12 | 2048 | 1048576 | QCA Rome 固件 |
| persist | mmcblk0p32 | 65536 | 33554432 | 传感器和指纹校准 |
| persistbak | mmcblk0p33 | 65536 | 33554432 | persist 的备份分区 |
| modemst1 | mmcblk0p27 | 8192 | 4194304 | 基带校准 |
| modemst2 | mmcblk0p28 | 8192 | 4194304 | 基带校准 |
| fsg | mmcblk0p29 | 8192 | 4194304 | 基带校准黄金副本 |
| fsc | mmcblk0p21 | 8 | 4096 | 基带校准 |
| splash | mmcblk0p31 | 73728 | 37748736 | 开机图 |
| devinfo | mmcblk0p24 | 8 | 4096 | 解锁标志常在这里 |
| misc | mmcblk0p30 | 8192 | 4194304 | recovery BCB |
| config | mmcblk0p25 | 2048 | 1048576 | FRP |
| aboot | mmcblk0p10 | 2048 | 1048576 | 只读副本 |
| abootbak | mmcblk0p11 | 2048 | 1048576 | 只读副本 |
| tz | mmcblk0p4 | 2048 | 1048576 | 只读副本 |
| tzbak | mmcblk0p5 | 2048 | 1048576 | 只读副本 |
| rpm | mmcblk0p6 | 1000 | 512000 | 只读副本 |
| rpmbak | mmcblk0p7 | 1000 | 512000 | 只读副本 |
| hyp | mmcblk0p8 | 1024 | 524288 | 只读副本 |
| hypbak | mmcblk0p9 | 1024 | 524288 | 只读副本 |
| sbl1 | mmcblk0p1 | 2048 | 1048576 | 只读副本 |
| sbl1bak | mmcblk0p2 | 2048 | 1048576 | 只读副本 |
| pmic | mmcblk0p13 | 256 | 131072 | 只读副本 |
| pmicbak | mmcblk0p14 | 256 | 131072 | 只读副本 |
| keystore | mmcblk0p23 | 1024 | 524288 | 只读副本 |

不抽：system（p37，3 GiB）、cache、userdata、append，以及 sdi、sec、DDR、limits、apdp、msadp、dpo、ssd、rsv。

## 步骤 3：抽分区

在主机上跑。某一行的 `wc -c` 和下表字节数不同，脚本应非零退出，后面的分区先不动。

```bash
DEST=/run/media/alpha/YMTC/sambar/device-backup
cd "$DEST"
# name:sectors
parts='
boot:131072
recovery:131072
modem:163840
bluetooth:2048
persist:65536
persistbak:65536
modemst1:8192
modemst2:8192
fsg:8192
fsc:8
splash:73728
devinfo:8
misc:8192
config:2048
aboot:2048
abootbak:2048
tz:2048
tzbak:2048
rpm:1000
rpmbak:1000
hyp:1024
hypbak:1024
sbl1:2048
sbl1bak:2048
pmic:256
pmicbak:256
keystore:1024
'
while IFS=: read -r name sectors; do
  [ -n "$name" ] || continue
  expect=$((sectors * 512))
  adb exec-out su 0 dd if=/dev/block/bootdevice/by-name/$name bs=512 count=$sectors \
    > "$name.img"
  got=$(wc -c < "$name.img")
  if [ "$got" != "$expect" ]; then
    echo "size mismatch: $name got $got expect $expect" >&2
    exit 1
  fi
  echo "$name $got"
done <<EOF
$parts
EOF
sha256sum *.img | tee SHA256SUMS
sha256sum -c SHA256SUMS
```

`adb exec-out` 若因为 `su` 往 stdout 写了字而导致长度不对，改走手机上的临时文件。userdata 剩余约 20 GB，单份最大是 modem 的 80 MiB。

```bash
adb shell su 0 dd if=/dev/block/bootdevice/by-name/boot of=/data/local/tmp/boot.img bs=512 count=131072
adb pull /data/local/tmp/boot.img /run/media/alpha/YMTC/sambar/device-backup/boot.img
adb shell su 0 rm /data/local/tmp/boot.img
```

抽完删掉手机上的临时文件。不要把镜像留在 `/data/local/tmp`。

另外：

```bash
adb shell su 0 cat /proc/cmdline \
  > /run/media/alpha/YMTC/sambar/device-backup/cmdline.txt
adb shell su 0 tar -C /data -cf - adb \
  > /run/media/alpha/YMTC/sambar/device-backup/data-adb.tar
```

`/data/adb` 不存在就记下，不要做成空 tar 冒充备份。cmdline 若出现真实序列号，写进 git 文档时打掉，硬盘上的 `cmdline.txt` 保留原文。

## 步骤 4：检查 boot 和 recovery

```bash
DEST=/run/media/alpha/YMTC/sambar/device-backup
python3 - "$DEST" << 'PY'
import struct, sys
dest = sys.argv[1]
for name in ("boot.img", "recovery.img"):
    hdr = open(dest + "/" + name, "rb").read(4096)
    assert hdr[:8] == b"ANDROID!", name
    ksz, kaddr, rsz, raddr, ssz, saddr, tags, page = struct.unpack_from("<8I", hdr, 8)
    cmd = hdr[64:64 + 512].split(b"\0", 1)[0]
    print(name, "page", page, "kernel", ksz, hex(kaddr), "ramdisk", rsz, hex(raddr), "tags", hex(tags))
    print("cmdline", cmd.decode())
PY
```

期望 page `4096`，kernel addr `0x8000`，ramdisk addr `0x2000000`，tags `0x1e00000`。内核在文件偏移 4096 处：未压缩 ARM64 Image 的第一条指令常见是 `10 00 00 14`，gzip 则是 `1f 8b`。两种都能是合法内核。把打印出来的 cmdline 补进本文，和 `BoardConfig.mk` 那条（含 `boot_cpus=0-5`）对照。

然后：

```bash
/home/alpha/Documents/GitHub/android_kernel_cyanogen_msm8994/scripts/extract-ikconfig \
  /run/media/alpha/YMTC/sambar/device-backup/boot.img \
  > /run/media/alpha/YMTC/sambar/device-backup/boot.ikconfig
```

脚本若说找不到内嵌配置，把这句话记下来。实机 `uname` 是 `3.10.84-lineageos-gc7efee3`，树的 tip 是 `aa1ca16`，`c7efee3` 不在克隆里。ikconfig 是判断那次重编译改过哪些开关的材料。

有 root 之后再找设备树：

```bash
adb shell su 0 'ls /proc/device-tree/model /sys/firmware/devicetree/base/model'
```

存在的那个，把 `model`、`compatible`、`qcom,board-id`、`qcom,msm-id` 用 `xxd` 存到 `device-backup/dt-ids.txt`。内核里两份候选是 `msm8994-v2.1-pm9x-dvt3.dts`（board-id `<25 0x04>` 一组）和 `msm8994-v2.1-pm9x-pvt.dts`（`<25 0x05>` 一组）。

## 步骤 5：抽 blob

清单是仓库根目录的 `proprietary-files.txt` 和 `proprietary-files-qc.txt`。路径相对 `/system`。减号前缀去掉之后再去拉，manifest 里保留这个前缀。

```bash
REPO=/home/alpha/Documents/GitHub/android_device_yu_sambar
BLOB=/run/media/alpha/YMTC/sambar/blobs
: > "$BLOB/manifest.tsv"
while IFS= read -r line; do
  case "$line" in
    ''|'#'*) continue ;;
  esac
  prefix=
  path=$line
  case "$path" in
    -*) prefix=-; path=${path#-} ;;
  esac
  mkdir -p "$BLOB/system/$(dirname "$path")"
  if adb pull "/system/$path" "$BLOB/system/$path" >/dev/null; then
    sz=$(wc -c < "$BLOB/system/$path")
    sum=$(sha256sum "$BLOB/system/$path" | awk '{print $1}')
    state=present
    [ -n "$prefix" ] && state=excluded-but-present
  else
    sz=0 sum=- state=missing
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$prefix$path" "$state" "$sz" "$sum" "/system/$path" >> "$BLOB/manifest.tsv"
done < <(cat "$REPO/proprietary-files.txt" "$REPO/proprietary-files-qc.txt")
```

`adb pull` 对 shell 不可读的文件会失败。那种行先记 `missing`，然后用 root 再拉一次：

```bash
adb exec-out su 0 cat /system/路径 > 目标文件
```

再失败才留 `missing`。不要用原厂 zip 填这些洞。`third_party/YU_Yutopia_YU5050_V1_24.12.15.zip` 是 2015-12-24 的原厂包，只在 manifest 里缺了、而阶段 1 又证明非官方系统本来就没有的文件上，才拿来对照。

面板校准 XML 必须出现在 manifest 里，状态是 `excluded-but-present`。实机面板名是 `dual 0 sharp cmd mode dsi panel`，和这个文件名一致。

## 步骤 6：udev，然后进 bootloader

备份目录里 `sha256sum -c SHA256SUMS` 通过，boot 和 recovery 的魔数核对过，再做这一步。

当前用户已在 `plugdev`。写 `/etc/udev/rules.d/51-android-yu.rules`：

```
SUBSYSTEM=="usb", ATTR{idVendor}=="2a96", MODE="0660", GROUP="plugdev", TAG+="uaccess"
```

```bash
sudo udevadm control --reload
sudo udevadm trigger
```

规则加上之后再重启。手机会离开 Android，adb 会断。

```bash
mkdir -p /run/media/alpha/YMTC/sambar/fastboot
adb reboot bootloader
sleep 5
lsusb -d 2a96: -v > /run/media/alpha/YMTC/sambar/fastboot/lsusb.txt
fastboot devices -l | tee /run/media/alpha/YMTC/sambar/fastboot/devices.txt
fastboot oem device-info > /run/media/alpha/YMTC/sambar/fastboot/device-info.txt 2>&1
fastboot getvar all > /run/media/alpha/YMTC/sambar/fastboot/getvar.txt 2>&1
```

`devices.txt` 里有一行，阶段 0 的 fastboot 一半就完成了。没有的话看 `lsusb.txt` 的接口描述符：

- `bInterfaceClass ff`、`bInterfaceSubClass 42`、`bInterfaceProtocol 03`：37.0.1 认这个设备。空的 `devices.txt` 是权限。确认规则已加载，拔插 USB，再跑 `fastboot devices`。不要加 `-i`。
- 接口类不是这一组：37.0.1 不会列出它。改用仍带 `-i` 的 platform-tools 25.0.x，只跑 `devices`、`oem device-info`、`getvar`、`reboot`。把当时的 lsusb 原文补进本文。

`device-info.txt` 里确认锁的状态。看到 locked，也不要在这一阶段解锁。回到系统：

```bash
fastboot reboot
adb wait-for-device
adb devices -l
```

回来之后再对 `SHA256SUMS` 复核一次，确认重启没有让主机上的文件被别的进程改掉。

## 步骤 7：写回本文

把这些原文补进下面的事件节，不把镜像本身拷进仓库：

- `getenforce`
- boot 和 recovery 的 header 打印，cmdline 打掉序列号
- `dt-ids.txt` 里的 model 和 board-id，以及它对应 DVT3 还是 PVT
- manifest 的 present / excluded-but-present / missing 计数
- `fastboot devices` 的那一行，以及 `device-info` 里的锁状态
- 若用了 platform-tools 25，写明原因是接口类不是 `ff/42/03`

## 本地 TWRP 文件头

2026-10-29 只读了 `third_party/` 里的三个文件。都是 `ANDROID!`，page size 4096，ramdisk addr `0x2000000`，tags addr `0x1e00000`，second size 0。和 `BoardConfig.mk` 的偏移一致。

| 文件 | 字节数 | kernel 字节 | kernel addr | ramdisk 字节 | 内核开头 | cmdline 里的 boot_cpus |
| --- | --- | --- | --- | --- | --- | --- |
| `YUTOPIA_TWRP_2.8.7.img` | 41275392 | 25058944 | `0x8000` | 6758583 | `10 00 00 14`（未压缩 ARM64 Image） | 没有 |
| `YUTOPIA_TWRP_3.img` | 40366080 | 24385760 | `0x8000` | 6543331 | `10 00 00 14` | 没有 |
| `YUTOPIA_TWRP_3.0.2_BROKEN!.img` | 25112576 | 8137503 | `0x8000` | 5778298 | `1f 8b`（gzip） | `boot_cpus=0-5` |

文件名里的 BROKEN 不是因为头不合法。它的头和另外两份一样能解析，差别是内核为 gzip，并且 cmdline 多了 `boot_cpus=0-5`（设备树的 `BOARD_KERNEL_CMDLINE` 里有这一段）。本阶段不刷任何一份。等 recovery 分区抽出来，再和这三份比 SHA256，看手机里现在是哪一版。

## 事件

- 2026-10-29 调查：root 授权被拒绝，分区镜像一份都没抽，fastboot 模式没进。三份本地 TWRP 的头已读，没有写入手机。
- 2026-10-29：用户在 Magisk 里允许了 Shell。`su -c id` 得到 `uid=0`，上下文 `u:r:magisk:s0`，SELinux Enforcing。`su 0 id` 进入交互 shell，已停掉。
- 2026-10-29：27 个分区抽到 `/run/media/alpha/YMTC/sambar/device-backup/`。第一次试抽时 `dd` 的进度文本粘在镜像末尾（4096 字节的分区变成 4184）。改成设备侧 `2>/dev/null` 之后长度与扇区数一致，`SHA256SUMS` 通过。
- 2026-10-29：boot 头的 ramdisk/tags 与 `BoardConfig.mk` 不同，见「结果」。没有因此刷写。recovery 前缀等于 `YUTOPIA_TWRP_2.8.7.img`。
- 2026-10-29：blob manifest 404 条，缺 `vendor/lib64/libjni_livedisplay.so`，同名文件在 `/system/lib` 和 `/system/lib64`。
- 2026-10-29：`sudo -n` 写 udev 规则失败（需要密码）。规则没装。`adb reboot bootloader` 之后 `fastboot devices` 直接列出 `012345ABCDE`，USB 为 `2a96:301c`，接口 `ff/42/03`。`oem device-info` 为 unlocked、tampered。`fastboot reboot` 回到 Android，哈希复核通过。没有 `oem unlock`，没有刷分区。
