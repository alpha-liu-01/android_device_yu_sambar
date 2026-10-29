# 阶段 3：第一套可交互系统

日期：2026-10-26。阶段 2 已收口。本文件只记阶段 3 的推荐步骤，以及以后做的时候要补的实现笔记和事件。路线图仍是 `docs/g0215d-android-16-roadmap.md`。

完成标准（2026-10-27 调整）：18.1 先做成一套可以日常使用的系统，然后才进入阶段 4。交互桌面已经达到，不再是收口标准。收口要加上 USB 文件传输、振动、硬件视频和音频编解码、前后摄拍照和短视频、指纹录入与解锁。SELinux 保持 permissive，denial 有记录。短信、VoLTE、第二张卡、通话回声消除、蓝牙耳机通话、NFC、红外、FM、TWRP 的振动、重分区都不挡住这次收口。刷 boot 之前原厂 boot 已另存。日常进 recovery 用 2016-10-07 那份能挂上 data 的镜像。`#17` 留在硬盘上，只做内核画面测试。

步骤 1 到步骤 5 已结束。背光已经能亮。一次误开机里 SurfaceFlinger 不再崩溃，翻页 ioctl 因为句柄里的虚拟地址被改写而失败。`gralloc.default` 已改为把本进程映射留在进程内，翻页改用句柄里的字节 `offset`。随后一次开机里，`panel_hold.sh` 在 composer 打开 `fb0` 的同时写了 `blank`，两边都没有返回。脚本加上 8 秒等待后，composer 和 SurfaceFlinger 都完成初始化并进入了开机动画；将 `fb_post` 改为 `FB_ACTIVATE_NOW | FB_ACTIVATE_FORCE` 调 `FBIOPUT_VSCREENINFO` 并补上 `libaudiohal` 6.0 回退后，屏幕已能看到开机动画，`audioserver` 也不再崩溃。动画停住是因为系统缺少 `android.hardware.wifi.xml` 等硬件特性权限文件，`SystemUI` 在 `provideWifiManager` 返回空指针崩溃，进而触发 `RescueParty` 调用尚未加载元数据的 `ModuleInfoProvider.getModuleInfo`（加密最小框架下 `ModuleMetadata` 非 `coreApp` 被跳过），导致 `system_server` 反复重启（共 18 次）。硬件特性权限 XML 已补齐，`ModuleInfoProvider` 在缺少元数据包时也已将 `mMetadataLoaded` 置为 `true`。重启后系统顺利走过开机动画并显示出 `CryptKeeper` 解密失败界面（Holo 样式），画面上下颠倒对应 `persist.panel.inversemounted=180`（Android 11 对应 `ro.surface_flinger.primary_display_orientation=ORIENTATION_180`），同时触发了步骤 1「18.1 若要求加密升级或格式化 data，先停」的停机点。从这份 recovery 执行重启到 bootloader 会直接重新开机，进不了 fastboot。触摸芯片曾停在引导模式，原厂固件 `A4_2F_4.0_05.fw` 已写回，`atmel_mxt_ts` 已重新绑定。

## 推荐停在 Lineage 18.1

用户态用 LineageOS 18.1，也就是 Android 11。内核继续用阶段 2 的 `#17`（4.4.302，私有仓库 `alpha-liu-01/android_kernel_gree_g0215d` 的 `g0215d` 分支）。

选 18.1 是因为这台手机的分区现在放得下它。system 是 3 GiB（`3221225472` 字节），没有 vendor、odm、product、super。本地已有的一加 3 `lineage-18.1` 树，`recovery.fstab` 写明 non-A/B、non-split、没有 `vendor.img`，`BOARD_SYSTEMIMAGE_PARTITION_SIZE` 是 `3154116608`。这个大小落在格力这块 3 GiB 的 system 里。

小米 `lineage-22.2` 的 `msm8996-common` 另要 `872415232` 字节（832 MiB）的 vendor。本仓库的 `BoardConfig.mk` 已经把 vendor 大小留空，那份对 common 的继承是阶段 4 重分区之后的布局。18.1 的 lunch 先不包含它。

20 和 21 先不作为这一阶段的构建树。18.1 的桌面和下面的验收表过了之后，再看那一代的镜像能不能放进现有 system。现在本地没有 20 或 21 的 msm8996 设备树，再同步一份整树对第一次点亮桌面没有更多信息。

`/run/media/alpha/YMTC/lineage-23.2/` 是 Android 16 的用户态，清单里没有 MSM8996 的设备树，也不能 lunch 18.1。18.1 的清单要单独放在这块移动硬盘上。23.2 那份树留给阶段 5。

一加 3 的 18.1 树只提供「vendor 留在 system 里」的平台形状，以及 `BoardConfig`、init、fstab、sepolicy、manifest 从 Android 7 长到 11 的样子。面板时序、Atmel 触摸、Goodix 指纹、格力相机库不从那棵树拿。内核也不换成它的 `kernel/oneplus/msm8996`。

## 阶段 2 留下的四件事落在哪一步

| 阶段 2 留下的事 | 落在 |
| --- | --- |
| 电源键熄屏再亮屏还没单独按过。recovery 脚本每 2 秒写 `blank 0` 并托住背光 | 步骤 6。系统 ramdisk 里没有 `phase2-debug.sh` |
| 启动日志里仍有 `0x34` 然后 `0x28` 的 DMA 超时 | 步骤 6。四项检查通过就记下来，继续验收。画面出横纹或触摸停在 CFGERR，就回到 `#17` 这颗内核 |
| 触摸配置仍是芯片 NVM 的 `53a963`。原厂 raw 在 `/system/etc/firmware/` | 步骤 3 把固件放进镜像，步骤 7 看 `config_csum` |
| 系统 boot 仍是原厂 3.18 | 步骤 4、步骤 5。第一次刷 boot 之前核对备份 |

## 步骤 1：确认还能退回去

推荐：刷写之前核对阶段 0 的备份还在，并且能对上。

- data：`third_party/2026-10-26--07-27-02_HALO_1.2.1_D1/`，TWRP 文件备份，md5 已通过。不含内部存储 `/data/media`
- system：同目录旁的 System 备份，以及 `g0215d/device-backup/` 里的 `system.img`
- boot：`device-backup` 里的原厂 boot。内核是 2017-04-12 的 `3.18.20-perf`，ramdisk 是 HALO 加 SuperSU
- 进 recovery 用 `device-backup/recovery.img`。那是 2016-10-07 的 `3.18.20-perf` 加上 TWRP 3.0.2，阶段 0 用它挂上过 `/data` 和内部存储。`#17` 的用户态也是这份 TWRP，但 4.4 内核的 ICE 映射读不出 ext4，见下面的事件
- 18.1 的 fstab 继续写 `encryptable=footer`，和一加 3 的 18.1 一样。同一份 2016 recovery 就能挂现在的 data。文件加密的新 TWRP 留到 data 真的改成 FBE 再做
- 退回 Android 6 时写 boot 和 system。recovery 保持这份能读 footer 的镜像。启动链分区（aboot、xbl、tz、rpm、hyp、cmnlib、keymaster、modemst、fsg）不动。只有 data 被格式化或改成文件加密之后，恢复才要先刷回这份 recovery，再写 boot、system，并用已有的 TWRP 文件备份恢复 data

第一次刷机不格式化 data。18.1 若要求加密升级或格式化 data，先停。清掉会丢掉那约 7.5 GB 的解密数据，以及 `/data/su.img`。

刷回能挂载 data 的 recovery：

```text
fastboot flash recovery /run/media/alpha/YMTC/g0215d/device-backup/recovery.img
```

### 实现笔记

当前 recovery 是 `#17`：TWRP 3.0.2 的用户态，内核 `4.4.302-perf+`。`/etc/recovery.fstab` 里 data 是 ext4、`encryptable=footer`、`length=-16384`。userdata 节点是 `sda9`。system 分区 `sde18` 能挂上。fstab 里的外置卡 `mmcblk1` 和 USB-OTG `sdg` 没有对应设备。

TWRP 用默认口令解开了 footer。日志是 `Device is encrypted with the default password` 和 `Successfully decrypted with default password`。映射类型是 `req-crypt`，参数 `fde_enabled ice`，新块设备是 `/dev/block/dm-0`。内核写了 `Mapping block_device /dev/block/sda9 to dm-req-crypt ok!`。`dm-0` 大小 `59212754944`，比 `sda9` 的 `59212771328` 少 16384，正好是 footer。

这块 `dm-0` 的 1024 字节处不是 ext4 超级块。`EXT4-fs (dm-0): VFS: Can't find ext4 filesystem`，手动 `mount -t ext4` 返回 `Invalid argument`。`/data/media` 是这块文件系统里的目录，所以内部存储和 data 一起失败。日志里的 `Unable to mount storage` 就是这件事。MTP 还另有一句 `could not open MTP driver`，`/dev/mtp_usb` 不存在；那是 4.4 用 configfs 之后的 USB 节点，和文件系统读不出来是两件事。

挂上 data 的办法是刷回 2016 年那份 recovery。在这颗 4.4 上修 ICE，留到真的要在 `#17` 里读写 data 时再做。

3.18 这份 recovery 上的核对：

- `device-backup/SHA256SUMS` 十一份镜像全部通过。TWRP 的 `data.ext4.win` md5 `96887c51eba11e8b2bb34551d356dd4b`，`system.ext4.win` md5 `a5ca564ded4d198a57312b21dd846ff0`，都通过
- 正在运行的 boot 分区与 `boot.img` 相同，SHA256 `07b402f192d2ddeee4646455cd33085055b3cc85193f47afed177de6ae4e11de`。recovery 分区与 `recovery.img` 相同，SHA256 `4c14c80cfc6a8b77f354cd5d939d9bc94a3d2f3df02f0a39eeb107907c6f76ac`
- system 分区 3221225472 字节。和 `system.img` 相比，主超级块（0–4096）以及偏移 2895872 起的 16 KiB 日志不同。日志魔数是 jbd2，其中 22 个字节不同。空闲块 399041、空闲 inode 192091，两边一样。其余数据块一致。`#17` 挂过这块 system：挂载时间被写成 1970-01-01，挂载次数从 3 变成 103，累计写入增加 1800 KB。文件没有增删。现在不需要为了步骤 1 把 `system.img` 刷回去
- `/data` 和 `/sdcard` 都挂在 `dm-0` 上。容量 54.2 GB，已用 10.3 GB，可用 43.8 GB。`/data/su.img` 是 96 MB。`/data/media` 是 9.0 GB、6205 个文件，仍然不在 TWRP 的 Data 备份里
- 外置卡和 USB-OTG 的节点是空的，fstab 里的那两项挂不上

### 事件

2026-10-26：机器先停在 `#17` recovery。画面和 adb 正常，`uname` 含 `4.4.302`，`ro.twrp.version=3.0.2-0`。cache 已挂上。data、`/data/media` 未挂上。

同日稍后刷回 `device-backup/recovery.img`。`uname` 是 `3.18.20-perf`，编译时间 Fri Oct 7 15:28:14 CST 2016，TWRP `3.0.2-0`。默认口令解密成功，`/data` 和 `/sdcard` 已挂上。boot、recovery 与备份字节相同。system 只差超级块和日志头。TWRP 界面显示内置存储剩余 44897 MB，与日志里的 Free 一致。步骤 1 结束。

## 步骤 2：准备 18.1 用户态

推荐：在移动硬盘上按 LineageOS 18.1 的清单同步一份用户态。内置盘不放这棵树。同步范围是能 lunch 出 `lineage_g0215d` 的平台，加上 `device/qcom/sepolicy-legacy-um`。小米和一加的专有 vendor 不下载。格力 blob 从 `device-backup/system.img` 和 System 备份里抽。

本仓库现在的 `device.mk` 继承 `device/xiaomi/msm8996-common`。那份 common 是 `lineage-22.2`。18.1 的产品文件要换成不含这份继承的板级 makefile，放进 18.1 树里的 `device/gree/g0215d`。仓库里现有的骨架留在原地，给阶段 4 接回 common。

### 实现笔记

用户态在 `/run/media/alpha/YMTC/lineage-18.1`，约 99 GB。清单是 `LineageOS/android.git` 的 `lineage-18.1`。`repo sync -c --no-tags --no-clone-bundle`。`device/qcom/sepolicy-legacy-um` 在默认清单里，已经检出。`vendor/oneplus`、`vendor/xiaomi`、`kernel/oneplus` 没有下载。

第一次同步末尾，`external/python/httplib2` 和 `external/squashfs-tools` 被 AOSP 回了 HTTP 429。单独再同步这两项之后，整树 `repo sync` 成功。

`device/gree/g0215d` 放在这棵 18.1 树里，没有继承 `device/xiaomi/msm8996-common`，也没有继承 `device/oppo/common`。本仓库里给阶段 4 用的骨架没有改。`BoardConfig.mk` 写了实机分区：system `3221225472`，cache `268435456`，userdata `59212771328`，boot 和 recovery 各 `67108864`。没有 `vendor.img`。构建系统因此把 `TARGET_COPY_OUT_VENDOR` 定成 `system/vendor`。fstab 里 data 只有 ext4，标志是 `encryptable=footer`。dsp 是 ext4，modem 和 bluetooth 是 vfat，persist 是 ext4。

内核偏移沿用阶段 2：基址 `0x80000000`，页 4096，tags `0x00000100`，ramdisk `0x01000000`。cmdline 用 `cma=32M` 和 `androidboot.selinux=permissive`。`TARGET_NO_KERNEL := true`，这棵树不编内核。Lineage 在没写 `TARGET_KERNEL_SOURCE` 时会从设备目录推成 `kernel/gree/g0215d`，那个目录现在不存在，因为内核编译被关掉了。

`lunch lineage_g0215d-userdebug` 选出的是 Android 11、`LINEAGE_VERSION=18.1-20261026-UNOFFICIAL-g0215d`、`BUILD_ID=RQ3A.211001.001`。lunch 时有一句 `Trying dependencies-only mode on a non-existing device tree?`，因为 `device/gree/g0215d` 不是 repo 管理的 git 项目，没有 `lineage.dependencies`。没有去拉一加或小米的依赖。

### 事件

2026-10-26：步骤 1 以界面上的内置存储剩余 44897 MB 收口。同日同步完 18.1，并 lunch 成功。没有刷机。

## 步骤 3：板级产品放进 system

推荐：18.1 的镜像是一块 system。`BOARD_SYSTEMIMAGE_PARTITION_SIZE` 用实机的 `3221225472`。不生成 `vendor.img`。`TARGET_COPY_OUT_VENDOR` 在这套 non-split 布局里落在 `/system/vendor`。

这一步要放进镜像的板级文件：

- 音频：`audio_platform_info.xml`、`mixer_paths_tasha.xml`。扬声器走 SLIMBUS
- 键位：`gpio-keys.kl`、`tiny4412-key.kl`。导航是实体键
- 相机配置：`msm8996_camera_G0215D.xml`，路径保持 `/system/etc/camera/`。传感器以这份 XML 里的 `s5k3p3`、`ov8858` 为准
- 触摸固件：`A4_2F_4.0_05.fw` 和 `Gree2_4005_V2.06_20170223.raw`，放在 `/system/etc/firmware/`。System 备份里已经有这两份。CM 列表里的 `A4_35_1.0_AA.fw` 和 `A4_35.raw` 在这台手机上不存在
- 分辨率：1440×2560，`xxxhdpi`。heap 和 overlay 按这块 2K 屏写，不照一加 3 的 1080p、6 GB 内存

开机后的 init 沿用原厂脚本的动作：等触摸节点出现，把固件写到 `update_fw`，把 raw 写到 `update_cfg`，再写 `plugin`。这棵内核的 `plugin` 只记录命令，不会跑原厂 `atmel_stand` 引擎。配置要靠 `update_cfg` 写进去。

SELinux 在内核 cmdline 里保持 `androidboot.selinux=permissive`。denial 存下来，这一阶段不切 enforcing。

### 实现笔记

板级文件在 `/run/media/alpha/YMTC/lineage-18.1/device/gree/g0215d`。本仓库的阶段 4 骨架没有改。两份触摸固件只放在那棵树里，校验和与 `docs/reference/g0215d-halo-blobs.sha256` 一致：`A4_2F_4.0_05.fw` 188908 字节，`9ef8974c82b967fe05815453ded7bb21f8e7ae8befba7044bca327f0f704f949`；`Gree2_4005_V2.06_20170223.raw` 8285 字节，开头是 `OBP_RAW V1`，`8460144470d0087e27026161ab10bb3133118118ea47cb927755c60d7e6f80ad`。没有放入 `A4_35_1.0_AA.fw` 和 `A4_35.raw`。

`lunch` 看到的安装路径：

- `system/vendor/etc/audio_platform_info.xml`、`mixer_paths_tasha.xml`。扬声器路径走 `SLIM_0_RX`，耳机走 `SLIMBUS_6_RX`
- `system/vendor/usr/keylayout/gpio-keys.kl`、`tiny4412-key.kl`。`gpio-keys.kl` 里 key 59 是 `GREE_KEY`
- `system/etc/camera/msm8996_camera_G0215D.xml`。后摄 `s5k3p3`（CameraId 0），前摄 `ov8858`（CameraId 2）
- `system/etc/firmware/` 下的两份触摸文件
- `system/bin/init.atmel_ts.sh` 和 `system/etc/init/init.gree.rc`

`init.gree.rc` 的 `atmel_tp_init` 是 `class main`、`oneshot`、root。脚本等到 `12-004a/update_fw` 出现，再写入原厂那两行文件名，等 1 秒，然后写 `ac enable 1` 和 `pl enable 20`。cmdline 增加了 `firmware_class.path=/system/etc/firmware`，给 `request_firmware` 用。`plugin` 仍然只被这颗内核记下来。

分辨率 1440×2560，`xxxhdpi`，`ro.sf.lcd_density=640`，`qemu.hw.mainkeys=1`，overlay 里 `config_showNavigationBar` 为 false。heap 用 4 GB 配置：`heapstartsize=8m`，`heapgrowthlimit=256m`，`heapsize=512m`，`heaptargetutilization=0.6`，`heapminfree=8m`，`heapmaxfree=16m`。`heapgrowthlimit` 按 1440×2560 的缓冲从 4 GB 档的 192m 提到 256m，`heapsize` 仍是 512m。

`BOARD_SYSTEMIMAGE_PARTITION_SIZE` 是 `3221225472`。`BOARD_USES_VENDORIMAGE` 为空，`TARGET_COPY_OUT_VENDOR` 是 `system/vendor`。cmdline 里仍是 `androidboot.selinux=permissive`。denial 要等系统真的启动后再存，这一步没有切 enforcing，也没有刷机。

### 事件

2026-10-26：固件从 `device-backup/system.img` 的 `etc/firmware` 抽出，大小和校验和与 blob 清单一致。`lunch lineage_g0215d-userdebug` 再次通过，上面的拷贝路径和属性都在产品变量里。

## 步骤 4：把 `#17` 打进 boot

推荐：boot 镜像的内核就是阶段 2 的 `Image.gz-dtb`，只带格力这一份 DTB。18.1 的构建系统不要去编 `kernel/oneplus/msm8996`，也不要重编 `g0215d` 工作树，除非步骤 6 把问题退回内核。

打包参数与阶段 2 相同：页大小 4096，内核地址 `0x80008000`，ramdisk `0x81000000`，tags `0x80000100`。`#17` 页对齐后落在 `0x80c36000`，和 ramdisk 之间仍有空隙。内核必须停在 `0x81000000` 之下。

系统 boot 的 cmdline 用现在这块原厂 boot 的 `cma=32M@0-0xffffffff`，并带上 `androidboot.selinux=permissive`。recovery 测试用过的 `cma=16M` 只属于那份 recovery。bootloader 还会自己追加 HMP、`androidboot.bootdevice=624000.ufshc`、verified boot 状态，以及面板选择 `qcom,mdss_dsi_nt35597_wqxga_cmd` 的 `config0` 加 `split_dsi`。这些不写进镜像头。

`fastboot boot` 在这台 bootloader 上不可用。验证只能 `fastboot flash boot`。刷之前把 `device-backup` 里的原厂 boot 再对一次校验和，确认退路文件还是 2017-04-12 那份。

系统 ramdisk 里不放 `phase2-debug.sh`。

### 实现笔记

boot 镜像是 `/run/media/alpha/YMTC/g0215d/boot-test/boot-phase3.img`，13611008 字节，SHA256 `b36b827ece0c0926d3661cae36c6bb356afb16e6411f9d20247b06176c82792c`。头是 `ANDROID!`，header version 0。页大小 4096，内核地址 `0x80008000`，ramdisk `0x81000000`，tags `0x80000100`。内核与阶段 2 的 `Image.gz-dtb` 字节相同，12769992 字节，页对齐后落到 `0x80c36000`，和 ramdisk 之间空 3973120 字节。解压后的版本串是 `Linux version 4.4.302-perf+`、`#17 SMP PREEMPT Mon Oct 26 15:43:24 EDT 2026`。后面只拼了一份 DTB，model 是 `Gree G0215D MSM8996 v3 + PMI8996`。18.1 没有去编 `kernel/oneplus/msm8996`，也没有重编这棵内核。`TARGET_NO_KERNEL` 仍是 true。

cmdline 是 `cma=32M@0-0xffffffff`，带 `androidboot.selinux=permissive` 和 `firmware_class.path=/system/etc/firmware`，末尾是构建系统会加的 `buildvariant=userdebug`。没有写入 HMP、`androidboot.bootdevice`、verified boot 或 `split_dsi`。

ramdisk 是 18.1 的第一阶段 `init`，静态链接，`Android 30`，1844448 字节。里面有 `/fstab.qcom`，只挂 system，标志是 `wait,first_stage_mount`。第一阶段 init 要靠这一行把 system 挂上并切到它，然后执行 `/system/bin/init`。vendor 里的 fstab 仍不列 system，切根之后由它挂 data、cache、modem、dsp、bluetooth、persist。ramdisk 里没有 `phase2-debug.sh`。

为了让 kati 能解析 msm8996 的 display makefile，`BoardConfig.mk` 加了 `TARGET_USES_HWC2` 和 `TARGET_USES_GRALLOC1`。当前 `vendor/apn` 依赖清单里没有的 `pyyaml`，所以在 18.1 树里放了一份 PyYAML 5.4.1，只为生成 ninja。这两件事都没有编进 boot。

`device-backup/boot.img` 仍是 `07b402f192d2ddeee4646455cd33085055b3cc85193f47afed177de6ae4e11de`。没有刷机。`fastboot boot` 仍然不能用来验证，验证要等步骤 5 的 `fastboot flash boot`。

### 事件

2026-10-26：`m ramdisk` 得到 18.1 的第一阶段 ramdisk。`#17` 打进 `boot-phase3.img`，头里的地址和页对齐落点与阶段 2 一致。原厂 boot 的校验和未变。没有刷入。

## 步骤 5：第一次刷写的范围

推荐：只刷 boot 和 system。recovery、cache、userdata、persist、modem、dsp、bluetooth 保持不动。

不刷 `third_party/` 里的卡刷包。MIUI 包和底层包的脚本会写启动链。Resurrection Remix 和自用 lineage13 包用的是原厂或 TWRP 那两颗 3.18 内核。

刷完用 recovery 的 `#17` 作为退路：系统起不来时，从 recovery 看得到画面和 adb，再用备份写回 boot 和 system。

### 实现笔记

system 镜像是 `/run/media/alpha/YMTC/g0215d/boot-test/system-phase3.img`，稀疏格式，文件 1485095408 字节，SHA256 `a47ca832c639044ec1e22ed5b08aaa3afab6a44d5fb58820886a723af8c00410`。展开后正好 `3221225472` 字节。根上的 `init` 指向 `/system/bin/init`。`/system/etc/firmware/` 里有 `A4_2F_4.0_05.fw` 和 `Gree2_4005_V2.06_20170223.raw`。vendor fstab 的 userdata 仍是 `encryptable=footer`，没有 quota，也不列 `/system`。`ro.build.version.release=11`，`ro.lineage.version=18.1-20261026-UNOFFICIAL-g0215d`。

这次 `m systemimage` 在主机上补了几处，都只在 18.1 树里：ncurses 5 的符号链接、arm64 WebView 的 git-lfs 实体、`make-apns.py` 在 Python 3.8 上的 `ElementTree.indent`。Ubuntu 的 `mke2fs.conf` 带 `orphan_file`，AOSP 的 mke2fs 1.45.4 读不懂，所以 `out/soong/host/linux-x86/bin/mke2fs` 和 `out/host/linux-x86/bin/mke2fs` 外面套了一层，改读 `system/extras/ext4_utils/mke2fs.conf`。这些都没有写进手机。

从当时的 2016 recovery 进 fastboot，只写了 boot 和 system。boot 用 `boot-phase3.img`，system 用上面这份稀疏镜像。fastboot 的 `max-download-size` 是 `0x20000000`，system 分成三段写入，三段都是 OKAY。没有 `fastboot -w`，没有格式化 data。recovery、cache、userdata、persist、modem、dsp、bluetooth 没有写。`third_party/` 的卡刷包没有刷。手机停在 fastboot。

`device-backup/boot.img` 仍是 `07b402f192d2ddeee4646455cd33085055b3cc85193f47afed177de6ae4e11de`，`device-backup/system.img` 仍是 `28354e1730de242dbf25201f2bb255f5ea7bdce3a2fc472227c21fa8ebadb513`。recovery 分区仍是 2016 那份。`#17` 的 recovery 镜像仍在 `boot-test/recovery-phase2.img`，这次没有刷进去。系统起不来时，先用现有 recovery 或 fastboot，把 boot 和 system 写回备份：

```text
fastboot flash boot /run/media/alpha/YMTC/g0215d/device-backup/boot.img
fastboot flash system /run/media/alpha/YMTC/g0215d/device-backup/system.img
```

### 事件

2026-10-26：18.1 的 system 镜像打出来并刷入，同时刷入 `boot-phase3.img`。其余分区未动。手机停在 fastboot，等第一次开机。

## 步骤 6：第一次进系统只看四件事

推荐：第一次开机只看这四件，外加一次电源键。

1. 启动画面出现
2. 桌面 1440×2560，没有横纹
3. 触摸能点
4. adb 起来

然后按一次电源键熄屏，再按一次亮屏。这时没有 recovery 脚本每 2 秒解屏，也没有人把背光托在固定值上。同时看 dmesg 里的 `0x34` / `0x28` 和 T6 状态。

这四件里任何一件失败，或者熄屏再亮屏之后出现横纹、触摸停在 CFGERR，就回到 `#17` 的内核改。用户态先不加包、不升到 20/21。桌面进不去，说明问题还在阶段 2 的板级移植。

四件都过了，把这次的 dmesg 留在事件里，再进步骤 7。

### 实现笔记

`boot-phase3.img` 交出去之后、system 挂上之前就复位了。在 `#17` recovery 里，system 的挂载次数仍是 0，`/sys/fs/pstore` 是空的。同一颗内核可以把这份 18.1 的 ext4 只读挂上，`ro.lineage.version=18.1-20261026-UNOFFICIAL-g0215d`。boot 分区当时和 `boot-phase3.img` 字节相同。

调试镜像是 `/run/media/alpha/YMTC/g0215d/boot-test/boot-debug.img`，13611008 字节，SHA256 `4e0c130ab5ca49c76a19c71932becb7b58aeff5e3db72d7ca508d2b4258ad470`。内核字节、页大小 4096、内核 `0x80008000`、ramdisk `0x81000000`、tags `0x80000100`、header version 0 都和 `boot-phase3.img` 相同。cmdline 多了 `androidboot.init_fatal_reboot_target=recovery`。ramdisk 里原来的 Android 11 init 改名为 `/init.real`。新的 `/init` 先用设备号 8:3 挂上 cache，把 `/dev/kmsg` 逐条同步写到 `/cache/boot-kmsg.txt`，再执行 `/init.real`。标记文件是 `/cache/boot-debug-marker`。

这次只写了 boot。system 仍是 18.1，recovery 仍是 `#17`。

`boot-debug.img` 开机停在第一屏循环，红灯不亮。cache 上没有 `boot-debug-marker`，也没有 `boot-kmsg.txt`。这次 recovery 的开机原因是硬复位，上一次关机是 MSM 拉低 PS_HOLD。pstore 仍是空的。那份 cpio 的名字填充按名字长度对齐，内核的 `N_ALIGN` 要求从流起点对齐。第一个目录项就错了 2 字节，`/init` 没有执行。

下一份是 `/run/media/alpha/YMTC/g0215d/boot-test/boot-debug2.img`，13611008 字节，SHA256 `83b4872c6c95b4f5baac17be8fe317e19d938775be72c0bb952564d316832250`。内核、地址、header version 0 和 cmdline 与上一份相同。ramdisk 用 GNU cpio 的 newc 重打，按内核的 `N_ALIGN` 能走到 `TRAILER!!!`。`/init` 3856 字节，`/init.real` 1844448 字节。

`boot-debug2.img` 的标记是 `mount=0`、`exec=0`。`/cache/boot-kmsg.txt` 里，`init.real` 先等 `dtbo, vbmeta, vendor` 的 uevent，10 秒后超时，然后 `Failed to mount required partitions early`，`InitFatalReboot: signal 6`。donor 的 `msm8996.dtsi` 在 `firmware/android/fstab` 里写了 vendor，`fsmgr_flags` 是 `wait,avb`，`vbmeta/parts` 是 `vbmeta,boot,system,vendor,dtbo,recovery`。第一阶段 init 优先用这份设备树 fstab，ramdisk 里的 `/fstab.qcom` 没有被读到。`boot`、`system`、`recovery` 存在，所以集合里只剩下那三个没有的分区。

格力板级 dts 给这个 fstab 节点加了 `status = "disabled"`。`ReadFstabFromDt` 因此失败，第一阶段改读 ramdisk 的 `/fstab.qcom`，只挂 system。内核 gzip 仍是 `#17`，新 DTB 接在后面，页对齐落点仍是 `0x80c36000`。镜像是 `/run/media/alpha/YMTC/g0215d/boot-test/boot-debug3.img`，13611008 字节，SHA256 `469e5c9705a7bd77aefe7079c7e0db9d96d634100fdf81219e96680ef72d5d07`。

`boot-debug3.img` 的日志里，设备树 fstab 读取失败，接着去打开 `/dev/block/bootdevice/by-name/system`。第一阶段的 uevent 只会在 `androidboot.boot_devices` 命中时建立 `/dev/block/by-name/system`。cmdline 里原有的是 bootloader 追加的 `androidboot.bootdevice=624000.ufshc`，键名不同，所以等了 20 秒后 `Failed to mount /system`。UFS 平台设备是 `soc/624000.ufshc`。

`boot-debug4.img` 的 cmdline 加上 `androidboot.boot_devices=soc/624000.ufshc`。ramdisk fstab 和 system 里的 vendor fstab 都改成 `/dev/block/by-name/`。userdata 仍是 `encryptable=footer`。镜像 13611008 字节，SHA256 `d3c46a49f773b48db47e7d5cdef06b5c33be6c0fc1417f9afd14e38ef264f4de`。只写了 boot，并改了 system 里的那份 fstab。

`boot-debug4.img` 这次挂上了 `/system`，第二阶段 init 也起来了。`/system/etc/init` 里没有任何 `mount_all`，`/data` 和 `/cache` 仍是 system 镜像上的只读目录。`vdc cryptfs init_user0` 因此失败，日志是 `Failure (reboot suppressed): init_user0_failed`。红灯一直亮着，zygote 反复因为建不出 `/data/dalvik-cache` 退出。

userdata 的 footer 魔数是 `0xD0B5B1C4`，版本 1.3，`crypt_type` 是 default，加密名是 `aes-xts`，KDF 是 scrypt-keymaster。flags 含 `CRYPT_DATA_CORRUPT`。fstab 没有 `formattable`。`init.gree.rc` 增加了 `on fs` / `mount_all /vendor/etc/fstab.qcom`。cache、dsp、modem、bluetooth、persist 加了 `nofail`，避免其中一次挂载失败把 userdata 的加密结果盖掉。userdata 一行没改。boot 分区仍是 `boot-debug4.img`。

这次开机日志是 `Unable to read config file '/system/etc/init/init.gree.rc': Skipping insecure file`。adb 写入后文件模式是 `666`，init 拒绝组可写和其他人可写的 rc。`mount_all` 没有执行，现象和上一份相同。`init.gree.rc` 已改成 `644`、`system_file`。`fstab.qcom` 已改成 `644`、`vendor_configs_file`。

权限改完之后，`mount_all` 成功。cache 和 persist 挂上。dsp、modem、bluetooth 的挂载点当时不存在。userdata 被记成 `possibly an encryptable blkdev`，`cryptfs mountdefaultencrypted` 之后属性是 `vold.decrypt=trigger_restart_min_framework`。系统里没有 keymaster 服务。surfaceflinger、zygote、keystore 都收到信号 6，所以屏幕一直黑。footer 的 `failed_decrypt_count` 仍是 0。

随后装上 `android.hardware.graphics.composer@2.1-service` 和 allocator。没有 `hwcomposer.msm8996` 时，这个服务改用 `gralloc.default` 打开 framebuffer。`/vendor/dsp`、`/vendor/firmware_mnt`、`/vendor/bt_firmware` 已建好。`init.gree.rc` 在 `post-fs` 把 logcat 写到 `/cache/boot-logcat.txt`。

这次开机 composer 已注册 `IComposer/default`，SurfaceFlinger 也连上了它。退出点在 `SurfaceFlinger::init`：`couldn't find an OpenGL ES implementation`。`ro.board.platform=msm8996`，镜像里没有 `libEGL_msm8996.so`。keystore 同时退出：`no viable keymaster device found`。进程内的软件 keymaster 只填 `SOFTWARE`，keystore 还要求 `TRUSTED_ENVIRONMENT`；有 HIDL 软件 keymaster 时，keystore 会把它升成默认设备。

system 里补了 `libEGL_swiftshader.so`、`libGLESv1_CM_swiftshader.so`、`libGLESv2_swiftshader.so`（32 位和 64 位，放在 `vendor/lib/egl` 和 `vendor/lib64/egl`），`vendor/build.prop` 写了 `ro.hardware.egl=swiftshader`。同时装上 `android.hardware.keymaster@4.0-service`（`SecurityLevel::SOFTWARE`）和 `libkeymaster4.so`。rc 和二进制的模式、标签已改过。boot 分区仍是 `boot-debug4.img`。软件 keymaster 解不开原来的 scrypt-keymaster footer。

这次开机 SwiftShader 三个库都加载了，gralloc 打开了 `mdssfb_90000`（1440×2560）。`BootAnimationShownTiming` 出现 28 次。大约 7.2 秒时内核写了 `release splash handoff`，面板随后保持黑。system_server 同样退出 28 次，原因是 `No IHealth service instance`。SurfaceFlinger 在 system_server 退出后于 `GLESRenderEngine::drawLayers` 收到信号 11。软件 keymaster 已注册，vold 用它签名时得到 `KM_ERROR_INVALID_KEY_BLOB`（-33），主密钥没有解出来，`failed_decrypt_count` 仍是 0。

随后装上 `android.hardware.health@2.1-service` 和 `android.hardware.health@2.0-impl-2.1.so`。`panel_hold.sh` 在 `sys.boot_completed` 变成 1 之前，每 2 秒写 `fb0/blank` 为 0，并把 `lcd-backlight` 写成 180。

这次开机背光亮了。health 2.1 已注册，`system_server` 走到了 `StartDisplayManager`。`BootAnimationShownTiming` 出现 20 次。SurfaceFlinger 每次都在 `sw::clear` 收到信号 11，故障地址都是 `0x6db6132000`。那是 framebuffer 句柄里带着的分配进程虚拟地址。`gralloc_map` 对 `PRIV_FLAGS_FRAMEBUFFER` 不做 mmap。导入进程里的 SwiftShader 直接写这个地址。`mapper.cpp` 已改为：句柄的 `pid` 不是当前进程时，用句柄里的 fd 重新 mmap。

这次误开机的日志里，SurfaceFlinger 没有再收到信号 11，开机动画记了 `BootAnimationShownTiming`。翻页失败，日志是 `FBIOPUT_VSCREENINFO failed`。导入进程把 mmap 得到的地址写回了句柄的 `base`，这个字段会随 Binder 回到分配进程，yoffset 因此越界。本进程映射改存在进程内表里，不再改 `base`。`fb_post` 用句柄里的字节 `offset` 计算 yoffset；`FBIOPUT_VSCREENINFO` 失败时再试 `FBIOPAN_DISPLAY`。`panel_hold.sh` 当时改成只写一次 `fb0/blank`。

下一次看着屏幕的开机没有背光。logcat 里有两段。前一段从 `10:27:30` 到 `10:31:46`，是这次要看的开机。SurfaceFlinger 在加载 SwiftShader 之后没有打出 EGL 信息，`system_server` 反复停在 `nativeGetPhysicalDisplayIds`，看门狗约每分钟杀掉一次。composer 只打了 `falling back to gralloc module`，没有打出分辨率。同一时刻 `panel_hold.sh` 已经在写 `fb0/blank`，这次写入没有返回，背光亮度也没有写上。后一段从 `10:32:03` 起，是随后尝试进 recovery 时自己重启的那次，不作为这次画面的依据；那段里 composer 在 1 秒内打开了 1440×2560 的 framebuffer。`panel_hold.sh` 已改回每 2 秒写 `blank` 和背光，但第一次写入前先等 8 秒，让 composer 先完成 `fb0` 的打开。

加上 8 秒等待后的这次开机里，composer 和 allocator 都打开了 1440×2560 的 `fb0`，SurfaceFlinger 完成了初始化并打出 `Enter boot animation`，`BootAnimationShownTiming` 也已记录，过程中没有任何显示服务崩溃。屏幕仍然无背光、无画面，原因是两件事叠加：第一，`gralloc.default` 的 `fb_post` 用 `FB_ACTIVATE_VBL` 调 `FBIOPUT_VSCREENINFO`，而内核 `drivers/video/fbdev/core/fbmem.c` 的 `fb_set_var` 只在 `(var->activate & FB_ACTIVATE_MASK) == FB_ACTIVATE_NOW` 时才调用 `fb_pan_display`，`FB_ACTIVATE_VBL` 直接返回 0 而不提交帧；`mdss_fb` 在 unblank 时把 `allow_bl_update` 设为 `false`，要等第一次 `mdss_fb_pan_display_ex` 提交帧调用 `mdss_fb_update_backlight` 才会把背光送给面板，所以没有真实 pan 就既不刷画面也不亮背光。第二，`system_server` 走到音频服务后一直停在 `Waiting for service 'media.audio_policy'`，因为 `libaudiohal` 的 `FactoryHalHidl.cpp` 用 `version != nullptr` 遍历以 `nullptr` 结尾的 `sAudioHALVersions` 数组，并且 `AudioFlinger` 对空的 `mDevicesFactoryHal` 直接解引用，导致 `audioserver` 每 5 秒收到信号 11。`framebuffer.cpp` 的 `fb_post` 当时改为设置 `FB_ACTIVATE_NOW` 并优先调用 `FBIOPAN_DISPLAY`；`FactoryHalHidl.cpp` 改为 `*version != nullptr`，`AudioFlinger.cpp` 构造函数增加了空指针判断，并装上了 `android.hardware.audio.service`、`android.hardware.audio@6.0-impl`、`android.hardware.audio.effect@6.0-impl` 及 32 位音频库。

随后这次开机背光重新亮起，验证了 `mdss_fb_pan_display` 已解开内核的 `allow_bl_update` 背光门控；画面仍然黑且机器发热，日志显示两处原因：第一，内核 `mdss_mdp_overlay.c` 的 `mdss_mdp_overlay_pan_display` 只在 `(fbi->var.activate & FB_ACTIVATE_VBL) || (fbi->var.activate & FB_ACTIVATE_FORCE)` 为真时才调用 `mfd->mdp.kickoff_fnc(mfd, NULL)`。`kickoff_fnc` 负责把新分配的左右 pipe 写进 `mixer->stage_pipe[MDSS_MDP_STAGE_BASE]` 并把像素发往 DSI；只传 `FB_ACTIVATE_NOW`（0）且走 `FBIOPAN_DISPLAY` 时，`fbi->var.activate` 为 0，`kickoff_fnc` 不执行，`mixer->stage_pipe` 保持为空，下一帧 `mdss_mdp_get_staged_pipe` 找不到已挂载的 base pipe，又重新分配两条新 pipe，5 帧之内耗尽全部 2 条 DMA、4 条 RGB、4 条 VIG pipe，之后每秒几十次报错 `mdss_mdp_overlay_pan_display: unable to allocate base pipe`。`fb_post` 已改为 `m->info.activate = FB_ACTIVATE_NOW | FB_ACTIVATE_FORCE` 并调用 `FBIOPUT_VSCREENINFO`，既满足 `fb_set_var` 的 `(activate & FB_ACTIVATE_MASK) == FB_ACTIVATE_NOW`（把 `fbi->var.activate` 更新并调 `fb_pan_display`），又满足 `mdss_mdp_overlay_pan_display` 的 `FB_ACTIVATE_FORCE` 触发 `kickoff_fnc`。第二，`android.hardware.audio.service` 虽然已注册 `IDevicesFactory/default`（6.0），但因缺少 `/vendor/manifest.xml`，`hwservicemanager` 的 `getTransport` 返回 `EMPTY`，`createPreferredImpl` 仍返回空指针，随后在 `AudioFlinger::onFirstRef` 和 `loadHwModule_l` 里解引用 `mDevicesFactoryHal` 再次触发信号 11。`FactoryHalHidl.cpp` 已在 `getTransport` 循环未命中时直接回退调用 `createHalService("6.0", interface, &rawInterface)`，`AudioFlinger::onFirstRef` 与 `loadHwModule_l` 也已加上 `mDevicesFactoryHal != nullptr` 保护。

改成 `FB_ACTIVATE_NOW | FB_ACTIVATE_FORCE` 之后，这次开机屏幕已经显示出 LineageOS 开机动画，`unable to allocate base pipe` 与 `audioserver` 信号 11 均已消失，`AudioFlinger` 打出 `systemReady`。一直停在开机动画且发热，是因为 `system_server` 进入了每 45 秒一次的 Java 崩溃循环（共 18 次）：
1. `/vendor/etc/permissions/` 下当时只有 `handheld_core_hardware.xml`，没有 `android.hardware.wifi.xml` 等硬件特性声明；`SystemServer` 因 `hasSystemFeature(FEATURE_WIFI)` 为假而跳过启动 `WifiService`。随后 `SystemUI` 启动时，`SystemServicesModule.provideWifiManager` 返回 `null`，被 Dagger 的 `@Provides` 非空检查抛出 `NullPointerException` 导致 `com.android.systemui` 崩溃。
2. `com.android.systemui` 崩溃触发 `PackageWatchdog` 与 `RescuePartyObserver.mayObservePackage`，后者调用 `ModuleInfoProvider.getModuleInfo`。因为当前处于加密最小框架（`mOnlyCore = true`），`/system/product/app/ModuleMetadata` 没有 `coreApp="true"` 属性而被 `PackageManager` 跳过，`ModuleInfoProvider.systemReady()` 捕获 `NameNotFoundException` 返回时未把 `mMetadataLoaded` 设为 `true`，导致 `getModuleInfo` 直接抛出 `IllegalStateException: Call to getModuleInfo before metadata loaded`，把整个 `system_server` 杀掉并重启 Zygote。
现在已将 `android.hardware.wifi.xml`、蓝牙、电话、传感器、音频、相机、指纹、GPS、NFC、USB 等 35 个硬件特性 XML 装入 `/system/vendor/etc/permissions/`（并同步写入 `device.mk`），同时修改 `ModuleInfoProvider.java` 在找不到元数据包时也将 `mMetadataLoaded` 置为 `true`，重编并推入了 `services.jar` 与 `oat/arm64/services.*`。

随后这次开机走完了开机动画，进入了 `CryptKeeper` 的解密失败界面（AOSP Holo 样式，未点击恢复出厂按钮），画面无横纹但上下颠倒 180 度。
- **画面上下颠倒 180 度**：实机面板物理反装 180 度（原厂属性 `persist.panel.inversemounted=180`）。`device.mk` 已有 `ro.surface_flinger.primary_display_orientation=ORIENTATION_180`，但当时运行中的 `vendor/build.prop` 没有这条。已在 recovery 里补上 `ro.sf.hwrotation=180`、`persist.panel.inversemounted=180` 和 `ORIENTATION_180`。
- **为什么出现解密失败界面**：第一，userdata 的 FDE footer 里自带 `flags = 0x1008`，含 `CRYPT_DATA_CORRUPT`（`0x8`），`vold` 的 `cryptfs_crypto_complete` 看到该位直接返回 `CRYPTO_COMPLETE_CORRUPT`（-4），`CryptKeeper` 的 `ValidationTask` 随即调用 `showFactoryReset(true)`；第二，原厂 FDE 走的是高通 `req-crypt` + UFS ICE 硬件加密（`aes-xts` + `scrypt_keymaster` + `qseecomd` + `libcryptfs_hw`），而当前 4.4 内核的 ICE 映射对这块 3.18 加密的 `sda9` 尚不能呈出有效 ext4 超级块（见步骤 1 笔记）。这正是步骤 1 约定的「18.1 若要求加密升级或格式化 data，先停」停机点。
- **用户接受格式化 userdata 之后**：不要在这份 `#17` TWRP 的界面里点 Wipe。TWRP 已把 `sda9` 映射成 `dm-0`，界面格式化只会动映射设备，16 KB footer 还在，下次开机仍会进 CryptKeeper。实际做法是先把 `sda9` 末尾 16384 字节的 footer 写成 0（魔数 `0xD0B5B1C4` 已消失），再 `adb reboot recovery` 让 `dm-0` 脱落，然后对整块 `sda9` 做 `mke2fs -t ext4 -F -L userdata`。新文件系统 54.2 GB，已挂上核对，footer 仍是 0。18.1 的 fstab 保持 `encryptable=footer`，没有 footer 就不会强制加密。

### 事件

2026-10-26：`boot-debug4.img` 挂上了 system。红灯常亮十几分钟，是因为没有 `mount_all`，`init_user0` 失败后重启被抑制，zygote 反复退出。随后在 system 的 `init.gree.rc` 加上 `mount_all`。再开机时 init 因文件模式 `666` 跳过了这个 rc。权限改为 `644` 后，`mount_all` 认出加密 userdata，最小框架里的 surfaceflinger 和 zygote 退出。随后装上 framebuffer composer。

同日：composer 起来之后，SurfaceFlinger 因没有 OpenGL ES 实现退出，keystore 因没有 keymaster 退出。红灯仍常亮，机器不发热。随后装上 SwiftShader 和软件 keymaster 4.0。

同日稍后：SwiftShader 已加载，开机动画在日志里记过，屏幕仍黑。system_server 因没有 IHealth 反复退出。随后装上 health 2.1，并加上解开 `fb0`、托住背光的脚本。

同日再后：背光已亮，画面仍黑。SurfaceFlinger 写到了分配进程的 framebuffer 地址。`gralloc.default` 已改为在导入进程里重新映射。

同日：从 recovery 重启到 bootloader 会直接重新开机。手动回到 recovery 后没有触摸，画面没有横纹。芯片停在引导模式，状态是 `APP_CRC_FAIL`，探测失败，没有输入设备。引导地址 `0x26` 上写回 `A4_2F_4.0_05.fw` 之后，驱动报 Family 164、Variant 47、固件 V4.0.05，T100 范围 X1439 Y2559，`config_csum` 是 `53a963`，T6 回到 `0x0`。TWRP 已打开 `event2`。`init.atmel_ts.sh` 不再每次开机重写应用固件。

同日再后：那次误开机的 cache 日志里，SurfaceFlinger 保持运行，画面仍黑。原因是翻页 ioctl 失败。`gralloc.default` 和 `panel_hold.sh` 已按上面的笔记更新。

同日：按这次修改重启后，第一屏之后黑屏，红灯常亮，没有背光，机器不发热。看着屏幕的那一段日志里，`blank` 写入和 framebuffer 打开撞在一起，SurfaceFlinger 没有完成图形初始化。`panel_hold.sh` 已改为先等 8 秒。

同日再后：等待 8 秒的开机里，composer 与 SurfaceFlinger 正常进入开机动画，无背光是因为 `fb_post` 的 `FB_ACTIVATE_VBL` 在内核 `fb_set_var` 中不触发 `fb_pan_display`，`mdss_fb` 的首帧背光门控一直未解开；同时 `system_server` 卡在等待崩溃的 `audioserver`。

同日：将 `fb_post` 改为 `FB_ACTIVATE_NOW` 后，背光重新亮起，但画面仍黑且发热。kmsg 显示 `mdss_mdp_overlay_pan_display` 需要 `fbi->var.activate` 含 `FB_ACTIVATE_VBL` 或 `FB_ACTIVATE_FORCE` 才会调 `kickoff_fnc` 把 pipe 挂上 mixer，否则 5 帧内耗尽全部 10 条 SSPP pipe（4928 次 `unable to allocate base pipe`）；同时无 `/vendor/manifest.xml` 时 `getTransport` 返回 `EMPTY`，`AudioFlinger::onFirstRef` 再次空指针崩溃。已把 `fb_post` 改为 `FB_ACTIVATE_NOW | FB_ACTIVATE_FORCE` 调 `FBIOPUT_VSCREENINFO`，并为 `libaudiohal` 与 `AudioFlinger` 补上 6.0 直接回退和 `onFirstRef` 空指针检查。

同日再后：屏幕已显示开机动画，MDP 管道泄漏与 `audioserver` 崩溃均已消除。动画卡住是因为缺少 `android.hardware.wifi.xml` 等权限文件导致 `SystemUI` 的 `provideWifiManager` 空指针崩溃，进而触发 `RescueParty` 调用 `ModuleInfoProvider.getModuleInfo` 抛出 `IllegalStateException: Call to getModuleInfo before metadata loaded`，使 `system_server` 重启 18 次。已补齐 `/vendor/etc/permissions/` 下的硬件特性 XML，并更新 `services.jar`（`ModuleInfoProvider` 在元数据包未安装时标记 `mMetadataLoaded = true`）。

同日：重启后顺利走过开机动画，进入 `CryptKeeper` 解密失败界面，画面上下颠倒 180 度，未按恢复出厂按钮。180 度方向已写入运行中的 `vendor/build.prop`。用户随后接受格式化 userdata。未使用 `#17` TWRP 界面 Wipe。已清掉 `sda9` footer，并对整块分区建成未加密 ext4（54.2 GB，可挂载）。等下一次进系统验证桌面。

2026-10-27：首次开机走完 `LineageSetupWizard` 并进入 `Launcher3`（`QuickstepLauncher`）桌面与 `Settings`，触摸与 180 度屏幕倒装方向均验证正常。步骤 6（启动进入桌面）完成，转入步骤 7 逐项验收与硬件修复。

## 步骤 7：验收

交互项已经有记录，按下面的剩余顺序继续。前一项没有记录就先不跳到下一项。

已通过，本阶段不再重做：

1. 启动动画
2. 桌面，无横纹
3. 触摸。`config_csum` 仍是 `53a963`，验收当时就继续了
4. Wi-Fi
5. 扬声器、听筒、免提通话
6. 蓝牙（开关、扫描、配对、A2DP）
7. 传感器。SSC 校准在 persist 里，没有刷 persist
8. 第一张卡识别、驻网、蜂窝数据、听筒和免提通话
9. 休眠唤醒（背光）
10. USB 功能切换。文件传输双向、PTP、MIDI、USB 网络共享都切换过，见 7I
11. 振动。DRV2605 v1.1 已绑定，设置走的 vibrator HAL 能下发定时振动，见 7J。TWRP 里的振动以后再说
12. 硬件视频和音频编解码。Venus `OMX.qcom.video.decoder.avc` / `OMX.qcom.video.encoder.avc` 与 ADSP `OMX.qcom.audio.decoder.aac`（经 `adsprpcd` 从 `/dsp` 动态加载 `HeaacDecoderModule.so.1`）均已在冷启动后验证通过，见 7K
13. 相机。后摄 `s5k3p3`、前摄 `ov8858` 都能预览、拍照、录短视频。系统自带相机冷启动后能预览，拍出 3456x4608 的照片，见 7L
14. 指纹。录入一枚 Finger 1（`1681692777`），锁屏上这根手指能解开，另一根手指被拒绝。见 7M、同日第三十六轮。第一次拒绝之后芯片不再采图的问题已修，见同日第六十三轮

不挡住这次收口，但成品 ROM 还要做：VoLTE/IMS（短信和第二张卡已经能用）、通话后回 LTE、回声消除（语音拓扑目前是关掉的）、蓝牙耳机通话、NFC 读卡、SELinux enforcing、加密。红外已做，见同日第六十一轮。FM 能收到台、音量键能调，见同日第六十二轮。应用打开失败已修，使用者确认能听，见同日第六十七轮。当前要刷的包见同日第六十八轮。NFC 协议栈已起来，设置页不再卡，读卡还没确认，见同日第六十四轮。可刷写的安装包见同日第五十八轮，更新的一份见同日第六十六轮。顺序见下面「距离成品 ROM」。充电能充上电即可，电流和温度留到阶段 5。基带版本是 `MPSS.TH.2.0.c1`，RIL blob 用格力自己的。

SELinux 保持 permissive。每次开机把 denial 存下来。

### 距离成品 ROM

阶段 3 的交互验收已经做完。下面是到一套可以交给别人刷的 18.1 为止还要做的事，按建议的顺序。第 1 项已经做完，见同日第三十七轮。阶段 4（从 userdata 划出 vendor，再接到小米 `lineage-22.2`）是下一代平台，不排在这张表里。前摄停流偶尔多等 3 秒、冷启动有一次报 0 个相机、`netmgrd` 偶发 Scudo abort 后被 init 拉起，都不单列；做相机或蜂窝时顺手看。

1. **指纹改成强生物识别**。已做，见同日第三十七轮。`config_biometric_sensors` 写成 `0:2:15`，框架按强生物识别登记，成功比对会调用 `addAuthToken`。令牌是 69 字节、版本 0、类型是指纹、HMAC 全 0；这套软件 KeyStore 只拒版本或长度不对的令牌，不校验 HMAC。整机重启后第一次解锁仍要图案，这是 Android 的开机强认证，跟指纹强弱无关。
2. **VoLTE**。短信和第二张卡已经能用。IMS 仍未注册。当前这张联通卡在 Bell 上的调通已经停下。第四十五轮第 1 项已经做完，见同日第四十六轮：自动选择不是关的，插上移动卡会按卡重选，但不保证落到 `volte_op` 或 `volte_su`。第 2 项已经做完，见同日第四十七轮：`IImsRadio` 在重启后仍由 `lshal` 看到，没有写进 manifest，注册状态按 IMSA 报，现在是未注册。第 3 项已经做完，见同日第四十八轮：移动卡走默认运营商配置时，增强型 4G 不会被关掉。没有换格力的 `libril-qc-qmi-1.so`，没有拨出电话。通话后回 LTE 仍只在电话落到 3G 时才重要，跟在这一项后面看。
3. **通话能听清**。听筒和免提两个方向已经有声音，靠的是把 vocproc 拓扑改成 `NONE`。回声消除和降噪因此没有。有线耳机和蓝牙 SCO 通话也有声音，见同日第五十六轮。有线耳机通话音量键改的是 `STREAM_VOICE_CALL`。第五十六轮写了 `RX5`/`RX6` 主路音量，听感没变；第五十七轮改写 `RX1`/`RX2` 的 mix 音量，这才是 `INT1_2`/`INT2_2` 的寄存器。可能的尝试和顺序见同日第四十九轮。第 1 项已经听过，见同日第五十轮：房间不吵；回声出现在对方的 iPhone 上，格力贴耳时自己这边不放出回声。第 2 项已经对过号，见同日第五十一轮：固件里有 `0x10F89` / `0x10F8A`，ACDB 给听筒和免提的都是这一对。第 3 项不再重做，见同日第五十二轮：7F 补记里已经有这次提交的 `ADSP_EFAILED`。第 4 项条件不成立，见同日第五十三轮，没有改听筒拓扑。第 5 项没有缺的注册，见同日第五十四轮，没有改音频 HAL，也没有再打一通。第五十五轮起不再改拓扑：听筒和免提保持 `NONE`，回声还在。这一项在安装包之前。
4. **用户能自己刷的 ROM 包**。已做，见同日第五十八轮。那一包是 `g0215d/boot-test/lineage-18.1-20261028-UNOFFICIAL-g0215d.zip`，只含 boot 和 system，boot 还是 `boot-fp8.img`。同日第六十六轮另打了一份，boot 换成现在手机上的 `#49`，system 里有 FM 应用，仍不带 recovery。那一份打不开收音机，已被第六十八轮换掉。2016 年的 TWRP 3.0.2 在这块未加密的 data 上刷过，分区哈希和刷之前一致，data 没有格式化。日常 recovery 从第五十九轮起换成 TWRP 3.7.0_11。2016 那份镜像还在 `device-backup/recovery.img`，启动失败时刷回去。
5. **能解密的新 TWRP**。已做，见同日第五十九轮和同日第六十轮。第五十九轮：TeamWin android-11 上的 3.7.0_11，未加密的 data 能挂，system-as-root 认 `/system_root/system/build.prop`，第五十八轮的包能刷，画面、触摸和振动都对。第六十轮：文件加密的 data 用原来的图案解开，日志是 `User 0 Decrypted Successfully`，`/data/media/0` 是明文目录名。
6. **手机加密**。文件加密已经在用：ext4 policy v1，内容 `aes-256-xts`，文件名 `aes-256-cts`，legacy session keyring。TWRP 能解开，见同日第六十轮。桌面锁屏还没收回来：为了走出 logo，`locksettings` 里的 `sp-handle` 被删过，`spblob` 还在。这一项还没记成做完。4.4 内核不实现 `FS_IOC_ADD_ENCRYPTION_KEY`，软件 keymaster 写不了 ICE keyslot，所以不用 footer 全盘加密，也不用 metadata encryption。开机后第一次解锁仍要图案，这是 Android 的规则，和指纹强弱无关。
7. **红外**。已做，见同日第六十一轮。海信 Roku 电视用小米遥控器里海信的第 16 套配置打开了。发射走 I2C 上的 Raon，不是 GPIO 脉冲。学习还没做，原厂 `com.gree.irremote` 没有装。
8. **FM 收音机**。已做。芯片和耳机出声见同日第六十二轮。102.1 没有杂音，音量键能调。`FM2` 打开芯片的失败见同日第六十七轮，使用者确认修好了。当前刷机包见同日第六十八轮。
9. **NFC**。协议栈已经起来，设置页不再卡住，见同日第六十四轮。芯片是 PN547，读卡还没确认，这一项先不记成做完。eSE 仍没有。
10. **SELinux enforcing**。放在最后。前面每加一个 HAL 都会多一批 denial；现在切只会反复改策略。转之前先补蓝牙、RIL、指纹、相机已经记下来的 denial。在此之前保持 permissive，开机 denial 继续存。

### 实现笔记

- **首次进入桌面的日志隔离**：`/cache/boot-logcat.txt` 中在进 TWRP 前有两次因按键时机未进 recovery 而产生的几秒短开机（行 34904–39264 与 39265–41990），已剔除；真正的桌面会话位于行 15160–34903（历时约 8 分钟，包含 `FallbackHome` → `LineageSetupWizard` → `QuickstepLauncher` → `Settings`）。
- **桌面 ~2 FPS 严重卡顿与滚动时半面屏幕变黑闪烁的根因与修复**：
  1. **Write-Combine 显存直绘与双 DSI 扫描撕裂**：NT35597 为 1440×2560 双 DSI 命令模式屏（`split_mode:2 left:720 right:720`）。当 `gralloc.default` 的 `NUM_BUFFERS = 2` 时，`GRALLOC_USAGE_HW_FB` 直接把 `fb0` 的非缓存 Write-Combine 物理内存交给 SwiftShader 做 CPU 逐像素光栅化与混合（比缓存内存慢约 10 倍），且 `HWC2OnFbAdapter` 返回的 `outRetireFence = -1`，导致 SwiftShader 在下一帧开头执行 `sw::clear`（清黑）时，MDP 正好在扫描左/右半屏（720 列）的 DMA 传输，直接造成半面屏幕黑屏剧烈闪烁。
  2. **391 次 `hwservicemanager` 1000ms 阻塞**：因系统缺少 `/vendor/etc/vintf/manifest.xml`，`getTransport` 对 `IMapper@4.0/@3.0/@2.0`、`IPower`、`ISensors`、`IOmxStore` 等查询全部触发 `waitForHwService` 1 秒硬超时（单次开机累计阻塞 391 秒）。
  3. **修复方案**：将 `gralloc.default`（`framebuffer.cpp`）中 `NUM_BUFFERS` 改为 `1`（并令 `module->numBuffers = 1`），使 SurfaceFlinger 的合成缓冲改用带 CPU L1/L2 Cache 的普通 `ashmem` 内存；待 SwiftShader 在缓存内存中完成整帧渲染后，由 `fb_post` 用单次 ~1.5 ms 的顺序 `memcpy` 拷入 `fb0`，随后立即调用 `FBIOPUT_VSCREENINFO`（`FB_ACTIVATE_NOW | FB_ACTIVATE_FORCE`, `yoffset = 0`）触发双 DSI 同步刷新；同时编写并安装 `/vendor/etc/vintf/manifest.xml`，彻底消除 391 次 1 秒阻塞。
- **USB 仅充电、无 ADB 的根因与修复**：
  - 4.4 内核使用 ConfigFS USB Gadget，控制器为 `6a00000.dwc3`（`/sys/class/udc/6a00000.dwc3`）。桌面日志中缺少 `/config/usb_gadget/g1` 树与 `/dev/usb-ffs/adb` 挂载，且 `/system/default.prop` 中 `ro.adb.secure=1`、`persist.sys.usb.config=none`。
  - 修复：在 `init.gree.rc` 的 `on boot` 中建立 `/config/usb_gadget/g1`（`0x18d1`/`0x4ee7`）、挂载 `functionfs adb` 到 `/dev/usb-ffs/adb`，设置 `sys.usb.controller=6a00000.dwc3`、`sys.usb.configfs=1`、`persist.sys.usb.config=adb`，将 `/system/default.prop` 改为 `ro.adb.secure=0`，并清除 `/data/property/persistent_properties` 中的旧 `none` 记录。
- **背光调节与电源键亮灭屏（`lights.msm8996` + `light@2.0-service`）**：
  - `HWC2OnFbAdapter` 的 `setPowerMode` 是空操作，按电源键熄屏时不会写 `/sys/class/graphics/fb0/blank`。
  - 在 `device/gree/g0215d/liblight/` 实现格力专用的 `lights.msm8996.so`：写 `/sys/class/leds/lcd-backlight/brightness`、`/sys/class/leds/button-backlight/brightness` 及红绿蓝三色灯，并在背光降为 0 时自动向 `/sys/class/graphics/fb0/blank` 写 `4`（`FB_BLANK_POWERDOWN`）、背光大于 0 时写 `0`（`FB_BLANK_UNBLANK`），从而打通电源键休眠唤醒与亮度条调节。
- **Wi-Fi（QCA6174 PCIe / `qcacld-2.0`）固件与 HAL 接通**：
  - 内核 `boot-kmsg.txt` 显示 PCIe 总线已枚举出 `0000:01:00.0`（QCA6174 `168c:003e`），`cnss_wlan_pci` 已挂接；`qcacld-2.0` 静态编入内核时延迟到用户态向 `/sys/module/wlan/parameters/fwpath` 写入路径才触发 `hdd_driver_init()`。
  - 从实机 `modem` 分区（`image/`）和 `persist` 分区提取 `qwlan30.bin`、`otp30.bin`、`bdwlan30.bin`、`utf30.bin`、`data.msc` 与原厂 `wlan_mac.bin`（`[redacted]`），配合 `WCNSS_cfg.dat` 与 `WCNSS_qcom_cfg.ini` 放入 `/system/etc/firmware/` 及 `wlan/qca_cld/`。在 TWRP 中实测写入 `echo sta > /sys/module/wlan/parameters/fwpath` 后，内核在 0.85 秒内完成固件下载（`Host SW:4.0.11.213X, FW:4.1.2.42, HW:QCA6174_REV3_2`）并成功生成 `wlan0` 接口。
  - 已编译并推入 `android.hardware.wifi@1.0-service`、`wpa_supplicant`、`hostapd`、`libwifi-hal.so`、`libcld80211.so` 及 VINTF fragment。
- **Phase 3 剩余子阶段路线图（按调整后的优先级推进）**：
  - **7A（显示防撕裂、USB ADB、锁屏背光常亮修复与设置网络闪退排查）**：
    - 实机重启已确认：半屏黑闪/撕裂彻底消失，系统内 USB ADB 已认出 `[redacted] device`。
    - **锁屏 2–3 秒后背光重亮（黑屏但背光常亮）的根因与修复**：`init.gree.rc` 中的 `service panel_hold` 未加 `oneshot`。当 `sys.boot_completed=1` 后，`panel_hold.sh` 跳过 `while` 循环（不再写 `0` 到 `fb0/blank`），但仍执行末尾两行 `echo 180 > .../lcd-backlight/brightness` 后退出；`init` 每隔 5 秒重启一次该服务，导致 `lights.msm8996` 刚把屏幕 blank 并关掉背光，`panel_hold.sh` 就把背光重新拉回 180（而 `fb0` 仍保持 blank 黑屏）。已为 `service panel_hold` 加上 `oneshot`，并修改 `panel_hold.sh` 仅在 `sys.boot_completed != 1` 且背光为 `0` 时执行一次点亮。
    - **USB ADB 在 `SystemServer` 就绪后掉回仅 MTP（`18d1:4ee1`）的根因与修复**：`AdbService.initAdbState()` 通过读取 `/data/property/persistent_properties` 中的 `persist.sys.usb.config` 是否包含 `adb` 来决定 `mIsAdbUsbEnabled`，并在 `systemReady()` 中将结果写入 `Settings.Global.ADB_ENABLED`。由于首次开机遗留 `persist.sys.usb.config=mtp`，`SystemServer` 启动完成后会将 `on boot` 临时拉起的 `mtp,adb` 重置为 `mtp`。已在 `init.gree.rc` 中加入 `on property:persist.sys.usb.config=mtp` 与 `on property:persist.sys.usb.config=none` 自动重写为 `mtp,adb`，并在 `sys.boot_completed=1` 时执行 `settings put global adb_enabled 1`。
    - **设置 → 网络和互联网闪退的根因与修复**：通过在线 ADB 抓取 `logcat -b crash` 定位到 `com.android.settings` 抛出 `NullPointerException: Cannot return null from a non-@Nullable @Provides method`（位于 `SystemServicesModule_ProvideWifiManagerFactory.proxyProvideWifiManager` 及 `WifiEnabler.setupSwitchController`）。根因并非移动数据未就绪，而是 `/vendor/etc/permissions/` 下缺少 `android.hardware.wifi.xml`（及 `android.hardware.wifi.direct.xml`），导致 `SystemServer` 跳过启动 `WifiService`，`context.getSystemService(Context.WIFI_SERVICE)` 返回 `null`。已在 `device.mk` 中补齐全部硬件 feature XML（`android.hardware.wifi.xml`、`android.hardware.wifi.direct.xml`、`android.hardware.vulkan.*`、`handheld_core_hardware.xml` 等）。
  - **7B（Adreno 530 GPU 硬件加速与 SDM 硬件合成，优先级上调至音频之前）**：
    - 已从格力 G0215D 原厂固件提取带 OEM TrustZone 签名的 `a530_zap.mdt/.b00/.b01/.b02/.elf`，结合 MSM8996 同平台（OnePlus 3 LineageOS 18.1）的 Adreno 530 微码（`a530_pfp.fw`、`a530_pm4.fw`、`a530_gpmu.fw2`、`a530v3_gpmu.fw2`、`a530v3_seq.fw2`）与 32/64 位 OpenGL ES 3.2 / Vulkan 1.0 闭源库（`libEGL_adreno.so`、`libGLESv2_adreno.so`、`libGLESv1_CM_adreno.so`、`eglSubDriverAndroid.so`、`vulkan.msm8996.so`、`libgsl.so`、`libadreno_utils.so`、`libllvm-glnext.so`、`libCB.so`、`libOpenCL.so`、`libRSDriver_adreno.so`、`libsdm-color.so` 等）放入 `device/gree/g0215d/firmware/` 与 `gpu/`。
    - 已开启 `BOARD_USES_ADRENO := true`、`TARGET_USES_ION := true`，由 `hardware/qcom-caf/msm8996/display` 编译出 32/64 位 `gralloc.msm8996.so`、`hwcomposer.msm8996.so`、`memtrack.msm8996.so`、`libsdmcore.so`、`libsdmutils.so`、`libqdMetaData.so`、`libqdutils.so`、`libqservice.so`、`libdrmutils.so`、`libgpu_tonemapper.so`、`libdisplayconfig.so` 以及 HIDL 服务 `android.hardware.graphics.allocator@2.0-service`、`android.hardware.graphics.composer@2.1-service`、`android.hardware.graphics.mapper@2.0-impl`、`android.hardware.memtrack@1.0-service`。
    - 已在 `init.gree.rc` 与 `/vendor/ueventd.rc` 配置 `/dev/kgsl-3d0`（`0666`）、`/dev/ion`（`0666`）、`/dev/mdss_rotator`（`0664`）与 `/sys/class/graphics/fb0/*` 节点权限，将 `ro.hardware.egl=adreno`、`ro.hardware.vulkan=msm8996`、`ro.opengles.version=196610` 写入属性，并重新打包生成完整 `system.img`。
    - **实机验证与内核/硬件健康度证明**：
      - **Adreno 530 与 SDM HWC2 满速硬件合成**：`dumpsys SurfaceFlinger` 证明 `GLES: Qualcomm, Adreno (TM) 530, OpenGL ES 3.2 V@269.0` 已接管渲染，壁纸、桌面与 SystemUI 全部走 `DEVICE`（MDP 硬件叠加层）合成，刷新率稳定 `60.00 fps`。
      - **GPU/CPU 调频与内核调度器零隐患证明**：检查 `/sys/class/kgsl/kgsl-3d0/devfreq` 确认 `msm-adreno-tz` 调频器正常工作（空闲自动降至 `133 MHz`，滑动时动态升频至 `624 MHz`）；检查 `/sys/devices/system/cpu/cpufreq/` 确认 Kryo 小核簇（`policy0`: `307.2 MHz – 1.593 GHz`）与大核簇（`policy2`: `307.2 MHz – 2.150 GHz`）均由 `schedutil` 调度器正常管理，所有核心 `online = 0-3`，无 thermal 降频或死锁；锁屏后背光彻底保持熄灭（`lcd-backlight/brightness = 0`），USB ADB 全程稳定在线。
    - **Wi-Fi 搜不到网络的根因与热修复**：
      - 审计 `logcat` 与 `dmesg` 发现：`/vendor/etc/vintf/manifest.xml` 主文件与 `/vendor/etc/vintf/manifest/android.hardware.wifi.supplicant.xml` 同时声明了 `android.hardware.wifi.supplicant`，导致 `libvintf` 报错 `files are mutually exclusive` 并拒绝解析整个 `/vendor/etc/vintf/manifest/` 目录，进而使 `IWifi` 与 `IHostapd` 无法注册；同时 `WCNSS_qcom_cfg.ini` 中 `gEnableIpTcpUdpChecksumOffload=1` 在旧固件下阻塞扫描，且 `wpa_supplicant` HIDL 服务配置缺失。
      - 修复：移除重复的 `android.hardware.wifi.supplicant.xml` fragment，在 `init.gree.rc` 的 `wpa_supplicant` 服务中加入 `-O/data/vendor/wifi/wpa/sockets -dd`，并将 `WCNSS_qcom_cfg.ini` 中的卸载项关闭。重启用户态（您刚才看到的“手机自己软重启”正是我们在后台执行 `stop && start` 以使 VINTF 生效）后，Wi-Fi 立即成功扫描并自动连上 5GHz 路由（`SSID: "Not 6GHz"`, `5765MHz`, `RSSI: -26`, 协商速率 `433Mbps`）。
      - **开关弹回（补记）**：主清单后来也去掉了 `ISupplicant`，准备只留 `wpa_supplicant` 的 `LOCAL_VINTF_FRAGMENTS`（`hidl/1.3/manifest.xml`，装到 `/vendor/etc/vintf/manifest/manifest.xml`）。7B 已经把手机上那份 fragment 删了，20:16 推上去的主清单和仓库一致、里面也没有这项。`lshal` 里 `ISupplicant` 只剩 `FC`，`hwservicemanager` 对 1.1–1.3 报 `Cannot find entry in either framework or device manifest`。框架退回 1.0，走 `listInterfaces`。rc 没有 `-i wlan0`，接口要靠 1.1 的 `addInterface`，所以列出 0 个，`setupIface got null iface`，开关约 1 秒回到 `DisabledState`。`wlan0` 和固件是好的（`fwpath=sta`，`QCA6174_REV3_2`）。把编译产物里的 fragment 推回 `/vendor/etc/vintf/manifest/manifest.xml` 并重启。`lshal` 变成 `DM,FC`，1.0 到 1.3 都在。冷启动后自动连上 `Not 6GHz`（5765 MHz，433 Mbps，`10.0.0.108`），`ping 8.8.8.8` 和 `google.com` 都通。没有改设备树，也没有重编内核。下次整镜像会带上同一份 fragment。
    - **“前 4 下滑动慢半拍、随后极度流畅”的根因与根治**：
      - **根因定位**：通过抓取 `/data/system/dropbox/system_app_anr@1793079489824.txt.gz` 与 `system_server` 线程栈发现，由于本机 `PRODUCT_SHIPPING_API_LEVEL := 23`（Android 6.0 首发）未开启 `PRODUCT_ENFORCE_VINTF_MANIFEST`，`system/libhidl/transport/ServiceManagement.cpp` 中的 `kEnforceVintfManifest` 为 `false`。每当任何进程调用 `getRawServiceInternal()` 查询设备清单（或未启动的 HAL，如 `IDumpstateDevice@1.0`、`IPower@1.0`、`IBiometricsFingerprint@2.1`、甚至每次调节亮度/按键背光时 `LightsService::setLight_native` 内部调用 `ILight::getService()`），`libhidlbase.so` 都会无条件执行一段硬编码的 **`sleep(1)`（整整 1000ms 睡眠）**！
      - **锁竞争链条**：当手指触摸屏幕唤醒按键灯或触发窗口切换时，`PhotonicModulator` / `PowerManagerService` 线程持有 `PowerManagerService` 全局锁 `<0x0e5a2d54>` 进入 `setLight_native -> ILight::getService() -> sleep(1)`，导致负责分发触摸焦点与窗口状态的 `android.display` 线程在 `setButtonBrightnessOverrideFromWindowManagerInternal` 上阻塞等待同一把锁；同时 `Settings` 主界面在 `onResume` 时并发查询 `IDumpstateDevice` 等多个未注册 HAL，触发连续数次 `sleep(1)`（正好对应“划 4 下屏幕、等待约 4 秒才有反应，一旦查完缓存住后就 60fps 丝滑无掉帧”）。
      - **修复验证**：修改 `system/libhidl/transport/ServiceManagement.cpp` 移除 `!kEnforceVintfManifest` 分支下的 `sleep(1)`，并将二进制补丁实时打入实机 `/system/lib64/libhidlbase.so` 与 `/system/lib/libhidlbase.so`，同时禁用尚未配好固件而后台循环 abort 的 `com.android.bluetooth`。重启用户态后实测：`LightsService` 响应耗时从 `>1000ms` 降至 `<1ms`，`Excessive delay setting light` 与 `HidlServiceManagement` 1 秒阻塞日志彻底清零，触摸与界面切换即点即应。
  - **7H（正面导航键：一颗实体 Home + 两侧虚拟 Back / 最近任务）**：
    - **现象**：`qemu.hw.mainkeys=1` 且 `config_showNavigationBar=false`，软件导航栏被关掉。正面下方中间实体键和两侧虚拟键完全无响应，无法回桌面或后退。
    - **输入设备**：修复前内核只有 `qpnp_pon`（电源 / 音量减）、`gpio-keys`（音量加 / 原 MTP 相机键）、`atmel_mxt_ts T100 touchscreen`。原厂还有一个名为 `tiny4412-key` 的输入设备，这一棵内核里没有。
    - **实体 Home 根因**：原厂 DTS 把 PM8994 GPIO 5 标成 `key_home`，`linux,code = 102`（`KEY_HOME`）。当前内核继承 `msm8996-mtp.dtsi`，同一脚被写成 `cam_focus` / `528`（`KEY_FOCUS`）。同时仓库里的 `gpio-keys.kl` 含非法标签 `GREE_KEY`，`KeyLayoutMap` 整文件解析失败，EventHub 回退到 `Generic.kl`（`102 = MOVE_HOME`，不是 Home）。结果：按下实体键内核报 FOCUS，框架不当作导航键。
    - **两侧电容键根因**：两块电容键不接 Atmel 触摸屏，而是由 **Goodix GF816M 指纹芯片**经 SPI 读出。原厂 `tiny4412-key` 这个名字就写在原厂内核 Goodix 驱动的字符串里（原厂 `Image` 偏移 `0x1239ec1`）。触摸驱动来自乐视 Le Max 2，那台机器的 `touch_keyevent`（`T15@0=139,1=172,2=158`）会让人以为键在 T15 上。实测排除了这条路：T37 参考值显示 T15 节点（X26 Y15–17，参考约 16300）确实有扫描，但按住两侧键时 delta 始终在 ±11 以内，CTRL 打开、阈值降到 8 也没有任何报文。当前内核没有 Goodix 驱动，SPI5 上也没有设备，所以按键无人读取。
    - **GF816M 协议**（从原厂 `Image` 反汇编得到）：
      - 写：`[0xF0, addr_hi, addr_lo, data…]`。
      - 读：先发 `[0xF0, hi, lo]`，再全双工发 `[0xF1, …]`，长度为 len+1，数据从 rx[1] 开始。两段的 `delay_usecs` 都是 5，SPI mode 0、8 位、1 MHz。
      - 寄存器：`0x8140` 状态（bit7 就绪；HOME 0x20/0x10、BACK 0x08/0x04、MENU 0x02/0x01，分别是掩码/状态）；`0x8043` 模式（0 图像、1 按键、2 睡眠、3 FF、0x56 调试）；`0x8047` 249 字节配置；`0x8040` 心跳（芯片 `0xC6`，主机每秒写 `0xAA`）；`0x8000` 版本串 `GFx16M`；`0x41E4` 为 `0xBE` 表示固件在跑。
      - 原厂复位时序：拉高、5 ms、拉低、16 ms、拉高、70 ms，再 `msleep(300)`。固件在芯片 flash 里，原厂的固件下载流程没有照搬。
    - **修复**：
      1. 重写 `gpio-keys.kl`：去掉 `GREE_KEY`；`102` 与旧内核的 `528` 都映射为 `HOME`，`59` / `766` 映射为 `F1`。
      2. 内核新驱动 `drivers/input/misc/gf816m_keys.c`（`CONFIG_INPUT_GF816M_KEYS=y`，匹配 `goodix,gf`）：复位芯片，确认 `0x41E4 == 0xBE`，写入原厂 249 字节配置（原厂 `Image` 偏移 `0x183facc`，末两字节是校验 `0x02 0x01`），切到按键模式，清状态。IRQ 线程读 `0x8140`，上报 `KEY_BACK` / `KEY_MENU`（`KEY_HOME` 只在模块参数 `report_home=1` 时上报，实体 Home 已经走 gpio-keys），再写回 0。每秒一次 ESD 检查：心跳或版本不对就重新初始化。sysfs 有 `mode`（可写）和 `status`。输入设备名沿用原厂的 `tiny4412-key`。
      3. 内核 DTS `g0215d-msm8996-v3-pmi8996-mtp.dts` 按原厂补上 `spi@7579000`（BLSP1 QUP5，IRQ 99，不开 BAM）和子节点 `goodix_fp@0`：复位 GPIO 51，中断 GPIO 121，供电 `pm8994_l19`。pinctrl 用 GPIO 81/83/84 做 `blsp_spi5`，GPIO 82（MISO）上拉。同一文件还覆盖 `gpio_keys`：GPIO 5 → `102 KEY_HOME`，GPIO 4 → `59 KEY_F1`。
      4. `drivers/pinctrl/qcom/pinctrl-msm8996.c`：小米这份表把 GPIO 81–84 的 `blsp_spi5` 功能删掉了，`spi_qsd` 因此报 `Can not set spi_default pins`。已按 CAF 原表补回这四行。
      5. `keylayout/tiny4412-key.kl`：`102 HOME`、`139 APP_SWITCH VIRTUAL`、`158 BACK VIRTUAL`。139 在 Android 11 上要映射成 `APP_SWITCH`（最近任务），不是 `MENU`。
      6. `overlay/lineage-sdk/lineage/res/res/values/config.xml` 把 `config_deviceHardwareKeys` 和 `config_deviceHardwareWakeKeys` 设为 `83`（Home 1 + Back 2 + App switch 16 + Volume 64）。lineage-sdk 默认是 `64`，Settings → System → Buttons 因此不列出任何导航键。实机在下次整编之前用平台签名的 RRO `org.lineageos.g0215d.buttons` 覆盖 `lineageos.platform`，`cmd overlay lookup` 已读到 `83`。
    - **撤回的 T15 方案**：之前为 T15 做的改动全部撤回。工厂 raw 恢复原样（CRC `53A963`，T15 CTRL `00`、阈值 `0x32`）。`init.atmel_ts.sh` 去掉 T15 逻辑，`init.gree.rc` 删掉 `atmel_tp_keys` 服务，`atmel_mxt_ts_T100_touchscreen.kl` 及其在 `device.mk` 的拷贝也删掉。芯片 NVRAM 已写回工厂值并 `BACKUPNV`，`config_csum` 为 `53a963`。T15 在没有按键垫的节点上开着、阈值又是 8，有误报的风险。
    - **实机证明**：内核 `#19` 开机打印 `gf816m_keys spi32766.0: chip GFx16M fw 01.04.04`。sysfs `status` 读到 `status 0x00 heartbeat 0xc6 fw_state 0xbe`，模式为 `0x01`。按两侧键时 `event2`（`tiny4412-key`）上有成对的 `KEY_MENU` / `KEY_BACK` 按下和抬起，`msmgpio 121` 计到 24 次中断。使用者确认返回和最近任务都能用，实体 Home 仍然正常。重启后 `dumpsys input` 显示 `tiny4412-key` 用的是 `/vendor/usr/keylayout/tiny4412-key.kl`。
    - **和指纹的关系**：这个驱动只做按键，不提供原厂指纹 HAL `gx_fpd` 要的 `/dev/goodix_fp` 字符设备和图像模式流程。7G 做指纹时要扩展这个驱动，或者换成完整的 Goodix 驱动。两种做法都必须保留按键上报，因为两侧键读的是同一颗芯片。
  - **7C（音频子系统：WCD9335 + TFA9890，扬声器、耳机、录音都已出声）**：
    - **现象**：修复前没有声卡，`/proc/asound/cards` 为空，`audio.primary.default` 因缺 `/dev/snd/pcmC0D0p` 报错。声卡起来以后又出现两次开机崩溃、Android 播放无声、ACDB 未初始化、录音无声、插耳机仍走扬声器。下面按出现的顺序记录。
    - **硬件**：耳机、听筒和麦克风走 WCD9335（`tasha`，SLIMbus）。扬声器不是 MTP 的两颗 WSA881x，而是一颗 NXP TFA9890，挂在 I2C-6 地址 `0x34`，音频走 QUAT MI2S（AFE 端口 `4102`），复位脚 GPIO 40。
    - **ADSP 起不来**：`fstab.qcom` 把 `modem`、`dsp`、`bluetooth` 挂到 `/vendor/firmware_mnt`、`/vendor/dsp`、`/vendor/bt_firmware`。本机 `/vendor` 就是 `/system/vendor`，镜像里没有这三个目录，所以挂载失败。新增 `rootdir/Android.mk`，在 `$(TARGET_OUT_VENDOR)` 下建好这三个目录。`init.gree.rc` 的 `on boot` 开头写 `/sys/kernel/boot_adsp/boot 1`，之后 ueventd 从 `/vendor/firmware_mnt/image` 读 `adsp.mdt` / `adsp.b*`。`on post-fs-data` 建 `/data/vendor/audio`。
    - **HAL 编译**：`BoardConfig.mk` 打开 `BOARD_USES_ALSA_AUDIO`、`USE_XML_AUDIO_POLICY_CONF`、`AUDIO_USE_LL_AS_PRIMARY_OUTPUT`。`BOARD_SUPPORTS_SOUND_TRIGGER := true` 也必须打开：关掉 sound trigger、listen 和 device arbitration 后，`audio_extn/utils.c` 会剩一个没用到的参数，在 `-Werror` 下编不过。`hardware/qcom-caf/msm8996/audio` 从 `$(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ/usr` 读内核 uapi 头。因为 `TARGET_NO_KERNEL := true`，需要先在内核树里手动导出一次：
      ```
      make O=out ARCH=arm64 headers_install INSTALL_HDR_PATH=/run/media/alpha/YMTC/lineage-18.1/out/target/product/g0215d/obj/KERNEL_OBJ/usr
      ```
      `device.mk` 加入 `audio.primary.msm8996`、`audio.r_submix.default`、`audio.usb.default`、`libqcompostprocbundle`、`libqcomvisualizer`、`libqcomvoiceprocessing`、`libvolumelistener`、`libaudio-resampler`、`tinyplay` / `tinycap` / `tinymix`，以及 `audio_policy_configuration.xml` 和 AOSP 的音量表、r_submix、USB policy 配置。
    - **声卡一直 defer 的三个原因**（都改在内核 DTS 的 `sound-9335` 节点）：
      1. 继承的 `qcom,wsa-max-devs` 要找 WSA881x，本机没有，改为 `<0>`。
      2. 机器驱动把 TFA 的 codec 名写死为 `tfa98xx.3-0034`。`msm8996.c` 改为从 DT 读 `qcom,tfa98xx-codec-name` / `qcom,tfa98xx-codec-dai-name`，DTS 填 `tfa98xx.6-0034` / `tfa98xx-aif-6-34`，并在 `&i2c_6` 下加 `tfa98xx@34`（`nxp,tfa98xx`，`reset-gpio = <&tlmm 40 0>`）。
      3. 机器驱动会链接 PRI 到 QUAT 四个 MI2S 口，任何一个 CPU DAI 不在 `asoc-cpu` 里，整张卡都 defer。按原厂补上 primary MI2S DAI 节点 `dai_pri_mi2s`（`qcom,msm-dai-q6-mi2s-dev-id = <0>`），`asoc-cpu` / `asoc-cpu-names` 写成 MTP 全表再加 `msm-dai-q6-mi2s.0/.1/.3`，共 62 项。同时删掉 `qcom,hdmi-audio-rx`：本机没有 HDMI，`CONFIG_MSM_EXT_DISPLAY` 也没开，`msm_hdmi_audio_codec_rx_dai` 永远不会出现。
    - **声卡注册后开机崩溃（使用者手动进 recovery）**：本机 ramoops 不能用，sysrq 触发的 panic 重启后，pstore 也是空的，引导程序会清内存。调试办法：在 recovery 里注释掉 `init.gree.rc` 的 `boot_adsp` 写入，先让系统开机；然后在可疑路径上加带编号的 `pr_err("... step N"); msleep(150);`，主机端 `adb shell dmesg -w` 实时存日志，再手动 `echo 1 > /sys/kernel/boot_adsp/boot` 触发。最后一条编号就是崩溃位置。这样找到两处：
      1. `msm_audrx_init` 里的 `rtd_aux` 等于 `&card->rtd[num_links]`。没有 aux 设备（`num_aux_devs == 0`）时它指向数组外面，判断 WSA8810 时解引用就崩。改为先判断 `rtd->card->num_aux_devs`。
      2. TFA 驱动是 v6.7.1，它的 `TfaContainer_t` 有 `uint16_t nliveData`，所以期望 index 在偏移 `0x2e`。格力（以及 OnePlus 3）的 `PM1_00` 容器没有这个字段，index 在 `0x2c`。结果 `tfaContDevice` 返回 NULL，`tfa_cont_get_idx` 直接解引用。`tfa_container.c` 新增 `tfaContIndex()`：`0x2e` 处不是 device 描述而 `0x2c` 处是时，用旧位置；`tfa_cont_get_idx` 同时加 NULL 判断。修好后 `mono Profile` 控件读到 `MUSIC_48000`，容器正常加载。
    - **扬声器路由**：`audio_platform_info.xml` 把 `SND_DEVICE_OUT_SPEAKER` 改到 `quat_mi2s_rx` 后端（`QUAT_MI2S_RX`），去掉 24 位设置（TFA 这条链路是 16 位 48 kHz），删除三条 SLIMBUS_0 加 SLIMBUS_6 的“扬声器 + 耳机”组合后端。因为接口不同，HAL 会自己把组合设备拆成两路。`mixer_paths_tasha.xml` 的 `speaker` 路径清空：TFA 是 QUAT MI2S DAI 链路的一部分，不需要 WCD 控件。`firmware/tfa98xx.cnt`（原厂）装到 `/system/etc/firmware/`。
    - **Android 播放无声，`tinyplay` 有声**：`MediaCodecList` 报 `Failed to create audio/raw decoder`。没有 `media_codecs.xml` 时，vendor `OmxStore` 返回 `NO_INIT`，`MediaCodecList` 会在加入 swcodec APEX 的 Codec2 软件解码器之前就停下。新增 `media/media_codecs.xml`（空的 `<MediaCodecs/>`，本机还没有 Venus OMX），装到 `/vendor/etc/`。
    - **ACDB 未初始化**：logcat 报 `ACDB -> Not correctly initialized!`。18.1 的 CAF HAL（LA.UM.8.6）`platform.c` 要 dlsym `acdb_loader_init_v3` 和 `acdb_loader_reload_acdb_files`，少一个就 `goto acdb_init_fail`。格力的 M 版 `libacdbloader.so` 只导出 `acdb_loader_init_v2` 和 `init_ACDB`。这里没有用 `TARGET_LD_SHIM_LIBS`，因为它通过 soong config 写进 runtime APEX 里的 linker。改为新增 `audio/acdbloader/`：
      - 原厂 blob 改名为 `libacdbloader_gree.so`，用 `prebuilts/extract-tools/linux-x86/bin/patchelf-0_9` 把 SONAME 改成同名。
      - 新的 `libacdbloader.so` 是一个垫片（`acdbloader_shim.c`），NEEDED 原厂库。`acdb_loader_init_v3(name, cvd, key_list)` 取链表第一个 key（没有就用 0），转调 `acdb_loader_init_v2`；`acdb_loader_reload_acdb_files` 打一条警告并返回 -1。
      - `device.mk` 装 `libacdbloader`，原厂 `libacdb-fts`、`libacdbrtac`、`libadiertac`、`libaudcal` 放 `/vendor/lib/`，七个 `MTP_*_cal.acdb` 放 `/system/etc/acdbdata/MTP/`，校验和与 blob 清单一致。
      - 实机 logcat 出现 `ACDB initialized`，播放时发出扬声器校准（`acdb_id = 15`）。`Fail to allocate memory for metainfo` 和耳机的 `ACDB AFE returned = -19` 不影响出声。
    - **录音无声**：录音能完成，回放没有声音。原厂 DT 的主麦（`Handset Mic`，AMIC5）用 MIC BIAS4，继承的 MTP 路由是 MIC BIAS3。DTS 覆盖 `qcom,audio-routing`，内容和 MTP 相同，只把 `"AMIC5", "MIC BIAS3", "MIC BIAS3", "Handset Mic"` 改成 MIC BIAS4。原厂的 `Secordary Mic` widget 在这份驱动里不存在，所以 `Analog Mic6` 保留。mixer 路径（`handset-mic` → `adc5`）和原厂一致，没改。
    - **插耳机仍走扬声器**：分两层。
      1. 原厂 `qcom,msm-mbhc-hphl-swh = <1>`，MTP 是 0，DTS 改为 1。
      2. 改完后内核已经检测到插入：`dumpsys input` 里 `Headset Jack` 的 `SwitchValues: 84`，即 `SW_HEADPHONE_INSERT` 加 `SW_JACK_PHYSICAL_INSERT`。但框架默认只读 `/sys/class/switch/h2w`，这棵内核没有这个节点。`overlay/frameworks/base/core/res/res/values/config.xml` 设 `config_useDevInputEventForAudioJack = true`，`WiredAccessoryManager` 改读输入事件。实机只重编了 `framework-res`，推到 `/system/framework/` 后重启；原来那份备份在 `boot-test/framework-res.apk.device-bak`。
    - **内核与镜像**：三个内核文件（`sound/soc/msm/msm8996.c`、`sound/soc/codecs/tfa98xx/tfa_container.c`、`g0215d-msm8996-v3-pmi8996-mtp.dts`）提交为 `79851a82f397`，已推送到 [`alpha-liu-01/android_kernel_gree_g0215d`](https://github.com/alpha-liu-01/android_kernel_gree_g0215d) 的 `g0215d` 分支。boot 镜像是 `/run/media/alpha/YMTC/g0215d/boot-test/boot-audio9.img`，13615104 字节，`sha256 16f5843ce7c406eb9951449ffc64c36bd1e18904c30d28ad548315bf4d9b6cee`。内核结束地址 `0x80c36f69`，仍低于 ramdisk 的 `0x81000000`。cmdline 和 ramdisk 沿用 `boot-audio2.img` / `boot-gf816m.img`。提交前只挪了 `tfa_container.c` 里一段注释的位置，镜像没有重打。
    - **实机证明**：声卡 `msm8996-tasha-mtp-snd-card` 约在开机 10 秒注册，系统正常开机。使用者确认：`tinyplay` 1 kHz 测试音清楚；Eleven 播放清楚；音量键有效；Recorder 录下的人声清楚；插耳机后只有耳机出声、两耳都有，拔出时播放暂停。HAL 日志显示扬声器走 `quat_mi2s_rx`，耳机走 `headphones`（`SLIMBUS_6_RX`）。
    - **还没做**：听筒（`handset`）没有单独测，要等 7F 通话时一起验。耳机麦没有测。语音通话、offload、蓝牙 A2DP 和 Venus 硬件编解码不在 7C。日志里还有几条不影响出声的噪声：`Amplifier initialization failed`（Lineage 没有 amp HAL）、找不到 sound trigger 库、缺 `audio_io_policy.conf`、`audio_route` 跳过部分控件。
    - **实机和镜像的差别**：上面的用户态文件都是手动推进实机 `/system` 的，没有重新打 `system.img`。本仓库和 18.1 设备树已经一致，下一次整编会全部带上。
  - **7D（蓝牙 QCA6174 Rome：开关、扫描、配对、A2DP 都已可用）**：
    - **现象**：修复前 `com.android.bluetooth` 被手动停用（它在后台循环 abort），Settings 的蓝牙开关没有效果，系统里没有蓝牙 HAL。
    - **硬件与内核**：芯片是 QCA6174 Rome，ROM 版本 `0x0302`（3.2），走 UART `/dev/ttyHS0`（`7570000.uart`，`msm_serial_hs`），上电由 `bt_qca6174` 节点的 `bt_power` rfkill 管（`rfkill0`，另有 `extldo` 属性）。这些内核已经有，**这一步不改内核**。固件在 `bluetooth` 分区（`sde21`，vfat），挂到 `/vendor/bt_firmware/image/`：`btfw32.tlv`、`btnv32.bin`、`btnv32.b15`。
    - **没有照搬原厂 `libbt-vendor.so`**：原厂是 Android 6 的 32 位库。18.1 的蓝牙 HAL 是 64 位进程，要 HIDL 版 `android.hardware.bluetooth@1.0`，它再 `dlopen` 厂商库。所以走了和小米 msm8996-common 一样的路：HAL 用 AOSP 自带的 `android.hardware.bluetooth@1.0-impl` / `-service`，厂商库用平台树 `hardware/qcom-caf/bt/libbt-vendor` 从源码编。Rome 的固件下载（`hw_rome.c`）在里面。
    - **`BoardConfig.mk`**：`BOARD_HAVE_BLUETOOTH`、`BOARD_HAVE_BLUETOOTH_QCOM`、`BOARD_HAS_QCA_BT_ROME` 打开。`QCOM_BT_USE_OLD_WCNSS_FILTER := true`，让 libbt-vendor 用不带 `vendor.` 前缀的 `wc_transport.*` 属性，和原厂 `wcnss_filter` 对上。没有开 `QCOM_BT_USE_BTNV`：原厂 `libbtnv.so` 只有 32 位。
    - **`wcnss_filter`**：这是 libbt-vendor 下载完固件后由 `wc_transport.start_hci=true` 拉起的 HCI 过滤进程，负责 IBS 睡眠协议和 UART 时钟投票。平台树里没有它的源码，直接用原厂 `system/bin/wcnss_filter`（64 位，Android 6，`NEEDED` 只有 `libdiag` 和基础库，`libdiag.so` 在 `gpu/lib64` 里已装）。放在 `bluetooth/wcnss_filter`，由 `bluetooth/Android.bp` 的 `cc_prebuilt_binary` 装到 `/vendor/bin/wcnss_filter`。原厂 SHA256 `3f7385d4f9f8ba28d89245b70b1a8bf3b1241ab74ad9fc618cac2d4a0e84d3a3`。`init.gree.rc` 加 `service wcnss_filter`（`user bluetooth`，`disabled`），以及 `on property:wc_transport.start_hci=true/false` 起停。
    - **固件路径**：libbt-vendor 写死读 `/bt_firmware/image/btfw32.tlv`。本机的根就是 system 镜像（第一阶段 init 切根），并且是只读的。启动时 `symlink` 会报 `Read-only file system`，所以改用 `BOARD_ROOT_EXTRA_SYMLINKS += /vendor/bt_firmware:/bt_firmware`，符号链接直接进 system 镜像根。这个链接在 `file_contexts` 里没有标签，`e2fsdroid` 报 `searching for label "/bt_firmware"` 而整镜像编不出来。所以新增 `sepolicy/vendor/file_contexts`：`/bt_firmware(/.*)?  u:object_r:bt_firmware_file:s0`，`BoardConfig.mk` 里用 `BOARD_VENDOR_SEPOLICY_DIRS` 加进去。实机是直接 `mount -o rw,remount /` 后 `ln -s`。
    - **蓝牙地址**：AOSP HAL 的 `Open` 在没有地址时 `LOG_ALWAYS_FATAL("No Bluetooth Address!")`，HAL 进程每次 abort。地址来源是 `ro.bt.bdaddr_path` 指的文件、`ro.boot.btmacaddr` 或持久属性。本机没有 `/persist/bluetooth`。原厂用 `btnvtool -O` 写 NV，地址在 TWRP 的 data 备份里：`/misc/bluedroid/bt_config.conf` 的 `Address = [redacted]`，和 `wlan_mac.bin` 的 Wi-Fi MAC 相同。所以把它放进 `bluetooth/bdaddr`，装到 `/vendor/etc/bluetooth/bdaddr`，`device.mk` 设 `ro.bt.bdaddr_path` 指向它。蓝牙地址因此和原厂一致，设置里读到 `[redacted]`。libbt-vendor 里 `wc_transport.stack_bdaddr` 显示字节序反过来的 `[redacted]`，这是库内部的 little-endian 写法，不是错。
    - **属性与权限**：`device.mk` 设 `vendor.qcom.bluetooth.soc=rome`（libbt-vendor 靠它选 Rome 分支）和 `ro.vendor.rfkilldisabled=0`。`init.gree.rc` 的 `on boot` 把 `rfkill0/type`、`state`、`device/extldo` 和 `/dev/ttyHS0` 交给 `bluetooth:net_bt`（0660），和原厂 `init.qcom.rc` 一致；`post-fs-data` 建 `/data/vendor/bluetooth`。`manifest.xml` 加 `android.hardware.bluetooth@1.0::IBluetoothHci/default`。`device.mk` 的包：`android.hardware.bluetooth@1.0-impl`、`-service`、`libbt-vendor`、`wcnss_filter`。
    - **一个坑：蓝牙 App 仍是停用状态**。`pm enable com.android.bluetooth` 之后要等几秒再重启，否则写盘前就重启，状态会回到 `enabled=3`，系统服务 `Fail to bind to: Intent { act=android.bluetooth.IBluetooth }`。
    - **实机证明（开机后日志）**：HAL 读到 `Got Factory BDA [redacted]`；`rome_soc_init` 读出 `Product ID 0x8`、`ROM Build 0x0302`、`Chipset Version 0x03020044`；UART 改到更高波特率成功；`File Open (/bt_firmware/image/btfw32.tlv)`，补丁下载，再下 `btnv32.bin`；`wc_transport.soc_initialized=1`，`hci_filter_status=1`，`wcnss_filter` 在跑；`AdapterState` 从 `OFF` 走到 `BLE_ON`、`TURNING_ON`、`ON`，约 1.2 秒。关再开一次也正常（过滤进程停止再启动，`rfkill0/state` 0 → 1）。
    - **A2DP**：Android 11 用蓝牙音频 HAL 2.0，由已有的 `android.hardware.audio.service` 通过 `android.hardware.bluetooth.audio@2.0-impl` 提供。`device.mk` 加 `android.hardware.bluetooth.audio@2.0-impl`、`audio.bluetooth.default` 和 `bluetooth_audio_policy_configuration.xml`；`audio_policy_configuration.xml` 用 `xi:include` 引入这个 module；`manifest.xml` 加 `android.hardware.bluetooth.audio@2.0::IBluetoothAudioProvidersFactory/default`。实机 `lshal` 看到两个蓝牙 HAL 都注册，`dumpsys media.audio_flinger` 里有输出线程走 `AUDIO_DEVICE_OUT_BLUETOOTH_A2DP`，会话是 `A2DP_SOFTWARE_ENCODING_DATAPATH`，编码器 AAC。
    - **使用者验证**：扫描能看到附近设备；配对能完成，状态是已连接；播放测试音只从蓝牙耳机出声。刚开机一分钟内有爆音，等系统安静下来后再测，两三分钟后爆音消失，干净。判断是开机初期的负载，不是 UART 或固件问题。
    - **整镜像**：这一步按完整构建验证过。`m systemimage` 成功，`/run/media/alpha/YMTC/g0215d/boot-test/system-7d.img`（稀疏格式，1683460640 字节，`sha256 fed6b2584e1729b76bd9fa5a7fc20b1eef1dd2b3aca44d5a33d8b62822bb59f6`）里有 `/bt_firmware` 符号链接，`wcnss_filter` 是 0755，`bdaddr` 是 0644，两个蓝牙 HAL 在 vintf manifest 里。这份镜像没有刷。boot 和内核这一步都没动，仍是 `boot-audio9.img`。
    - **没做**：HFP/SCO（通话走蓝牙耳机）和蓝牙电话音频要等 7F 一起验。BLE 外设、文件传输 OPP、蓝牙 tethering、LDAC/aptX 没有测。SELinux 仍是 permissive，开机日志里有 `hal_bluetooth_default` 写 `rfkill/state`、设置 `wc_transport.*` 属性、写 `/data/misc/bluedroid/bt_fw_version.txt` 的 denial，转 enforcing 之前要补策略。`libbtnv` 没用，地址固定为原厂那个值。
    - **顺带发现、不属于 7D**：使用者说无法把手机切到 MTP 传文件。当时所有 USB 模式都是灰的，停在仅充电。记到 7I，不在蓝牙这一步处理。
  - **7E（传感器 SSC：BMI160、AK09915、RPR0521、LPS22HB、SHTC1 已在冷启动后列出，并且有事件）**：
    - **现象**：修复前 `dumpsys sensorservice` 是 `No Sensors on the device`，`devInitCheck : -19`。机器上没有传感器 HAL，SLPI 停在 `OFFLINING`。
    - **硬件**：传感器不在 ADSP 上，在 SLPI。固件是 modem 分区里的 `slpi.mdt`（`/vendor/firmware_mnt/image/slpi.*`）。内核 `drivers/sensors/sensors_ssc.c` 提供 `/sys/kernel/boot_slpi/boot`（写 `1` 加载）和 `/dev/sensors`（228,0，`system:system` 660）。`rmt_storage`、`tftp_server` 在 7F 已经在跑。`radio/mkrfs.sh` 的子系统列表加上 `slpi`，给 SLPI 建了和 modem、ADSP 一样的 rfs 符号链接。**不要往 `boot_slpi` 写 `0`**：`restart_level` 是 `RELATED`，卸掉 SLPI 会把整台手机重启。
    - **用户态**：沿用原厂 Android 6 的 64 位栈，不用一加 3 的 `sscrpcd`。`sensors/bin/sensors.qcom`（守护进程，SHA256 `701bee9729375b4c5c297acc41bbd8f1c37bbc12a5298e46ce3d7b62490d91d8`），`sensors.ssc.so`（真正的 HAL，`b9f5a1430f183f5ece6ed933b827da17d71958a7bef5870a189a1fbd355b7118`），`libsensor1.so`、`libsensor_reg.so`。`ro.hardware=qcom`，所以 `hw_get_module("sensors")` 找 `sensors.qcom.so`。原厂 multihal 是 `sensors.msm8996.so`（只在 stock 的 `/system/lib64/hw`，不在 proprietary 树里），拷进 `sensors/lib64/hw/sensors.qcom.so`（`a81cf3044589c8488fdf8d0bd53870ae2801a4579e04c3975109f1206ef338df`）。它把配置路径写死成 `/system/etc/sensors/hals.conf`，两处都改成等长的 `/vendor/etc/sensors/hals.conf`。`hals.conf` 只有一行 `/vendor/lib64/sensors.ssc.so`（原厂还有 `qfp.wakeup.so`，这台机器没有这个文件，去掉）。HIDL 用 AOSP 的 `android.hardware.sensors@1.0-impl` 和 `@1.0-service`，`manifest.xml` 加 `ISensors/default`。
    - **两个不带进来的库**：`sensors.ssc.so` NEEDED `libpower.so`，只要 `acquire_wake_lock` / `release_wake_lock`，18.1 的 `/system/lib64/libpower.so` 已经有，不能把原厂 `libpower` 放进 vendor，否则每个 vendor 进程都会用到旧的。`liblocationservice.so` 只被引用了一个符号 `izat_manager::getIzatManager`，真库会拖进整套 GPS。`sensors/liblocationservice` 是一个返回空指针的桩，融合定位传感器不会出现，加速度、陀螺、磁力、光、接近、气压、湿度不需要它。
    - **`/persist` 不能是符号链接**：守护进程对目录做 `realpath`，再和原路径 `strncmp`，不相等就打 `sns_fsa_la.c(89): invalid directory path`，然后不打开 `sns.reg`。7F 的 `/persist -> /mnt/vendor/persist` 会走到这条。`BoardConfig.mk` 去掉这条 symlink，改成 `BOARD_ROOT_EXTRA_FOLDERS += persist`（镜像里是个空目录）。`init.gree.rc` 的 `on post-fs`（`mount_all` 之后）执行 `mount none /mnt/vendor/persist /persist bind`。校准文件 `/persist/sensors/sns.reg` 还在原来的 persist 分区上，没有刷 persist。
    - **启动顺序**：`/dev/sensors` 在固件加载前就存在，但 SLPI 上的 SMGR 要等守护进程已经打开 `sns.reg`、能提供文件服务，才会把传感器服务注册出来。反过来，HAL 只在进程起来时拉一次传感器列表；守护进程开头有大约两秒在给这台机器没有的 QCCI 服务做超时，这段时间里去问会得到 `EBUSY`，HAL 就缓存一份空列表。`sensors/init.gree.sensors.sh` 放在 `post-fs-data`，用 `exec_start` 挡住 zygote：先 `ctl.start sensors`，等到打开了 `sns.reg`，再写 `boot_slpi`，等 `ONLINE`，再睡 3 秒，最后 `ctl.start vendor.sensors-hal-1-0`。AOSP 自带的 rc 把 HAL 放在 `class hal`，那时候 SLPI 还没好，所以在 `init.gree.rc` 里用 `override` 把它改成 `disabled`。
    - **IPC 路由器要组 3011**：`/system/etc/sec_config` 里服务号 256 起（传感器 QMI）只允许 gid `3011`。原厂这个号是 sensors 用户；Android 11 里 `3011` 的名字是 `uhid`，persist 里的 `sensors` 目录原来就是这个属主。守护进程找用户名 `sensors`，找不到就 `setuid` 到 `nobody`（9999）、`setgid` 到 `net_raw`（3004），并且丢掉附加组。init 拉起来的进程因此不在 3011 里，内核打 `IPC_RTR: msm_ipc_router_send_to: permission failure for sensors.qcom`，HAL 的 SMGR 请求超时。从 adb root 手动拉是好的，因为那个 shell 本来就在 3011 里。`service sensors` 的 `group` 加上 `uhid` 和 `net_raw`，`setgid` 之后附加组还在，检查就过了。
    - **实机证明（冷启动，没有手动起进程）**：`sensors-boot` 约 3.4 秒结束，SLPI `ONLINE`，`/persist` 是 bind mount 不是符号链接。`dumpsys sensorservice` 报 46 个传感器，并且已经有事件：`BMI160 Accelerometer` / `BMI160 Gyroscope`（BOSCH）、`AK09915 Magnetometer`（AKM）、`RPR0521` 的 proximity 和 light（ROHM）、`LPS22HB Barometer`（ST）、`SHTC1/STHW1` 的湿度和环境温度（Sensirion）。另外还有一颗霍尔 `BU52053NVX`。HAL 打了两条 `Not supported sensor`（handle 36 和 64），不是这五颗芯片，没有追。没有刷 persist，没有改内核。SELinux 仍是 permissive。
    - **整镜像**：`m systemimage` 成功，`/run/media/alpha/YMTC/g0215d/boot-test/system-7e.img`（稀疏格式，1699607072 字节，`sha256 ff6a9a6bda215bc03465848c50a51641fb28cd9bd29bc2461e74b2f050d25ea0`）。镜像里 `/persist` 是目录（0755，`persist_file`），不是符号链接；`/firmware`、`/bt_firmware` 仍是符号链接。里面有 `sensors.qcom`、`sensors.ssc.so`、`sensors.qcom.so`、`libsensor1.so`、`libsensor_reg.so`、`liblocationservice.so`、`hals.conf`、`init.gree.sensors.sh`，`init.gree.rc` 里是 `group root uhid net_raw` 和 `mount none /mnt/vendor/persist /persist bind`，manifest 里有 `android.hardware.sensors` 1.0。拷贝脚本时用独立的 `SENSORS_PATH`：`PRODUCT_COPY_FILES` 展开时 `LOCAL_PATH` 已经被别的 makefile 盖掉。这份镜像没有刷。手机上现在跑的是把 rc、脚本和 manifest 推进去之后的那次冷启动。内核和 boot 没有改，仍是 `boot-audio9.img`。
  - **7F（双卡 RIL 与移动数据：SIM 识别、驻网、移动数据已在实机验证）**：
    - **现象**：修复前插着加拿大 Fizz 卡，手机完全没有 SIM 和信号。系统里没有 `rild`、没有 `android.hardware.radio` HAL，`/firmware` 不存在，基带没起。
    - **思路**：不重写 RIL。直接用原厂（Android 6，64 位）的 Qualcomm 电话栈：`qmuxd`、`netmgrd`、`rmt_storage`、`tftp_server`、`irsc_util`、`time_daemon`，以及 QCRIL `libril-qc-qmi-1.so`（加 `libril-qc-radioconfig.so`、`libril-qcril-hook-oem.so`）和一整组 QMI 库、`/etc/data/*.xml`、`qcril.db`。18.1 `hardware/ril` 的 `rild` 与 `libril`（CAF 风格，HIDL）加载 QCRIL。QCRIL 的闭源部分对 libc、libbinder 之外的依赖很少，18.1 的链接器配置是 `[legacy]`，厂商库可以直接用系统库。所有文件放在设备树新目录 `radio/`，`radio/radio.mk` 用 `PRODUCT_COPY_FILES` 装进去，`device.mk` 引入这个 makefile。
    - **目录和挂载（`BoardConfig.mk`、`file_contexts`、`rootdir/Android.mk`）**：
      - `BOARD_ROOT_EXTRA_SYMLINKS += /mnt/vendor/persist:/persist`、`/vendor/firmware_mnt:/firmware`，原因同 7D 的 `/bt_firmware`：根是只读的 system 镜像。`sepolicy/vendor/file_contexts` 给 `/firmware`、`/persist` 补 `firmware_file`、`persist_file` 标签，否则整镜像的 `e2fsdroid` 过不去。7E 把 `/persist` 从符号链接改成了真实目录加 bind mount，见 7E。
      - `tftp_server` 找 `/system/rfs/msm/{mpss,adsp}/{readonly/firmware,hlos,shared,readwrite,ramdumps}`。`radio/mkrfs.sh` 在编译时生成这棵符号链接树（`readonly/firmware → /vendor/firmware_mnt`，`hlos → /persist/hlos_rfs/shared`，`shared → /persist/rfs/shared`，`readwrite → /persist/rfs/msm/<子系统>`，`ramdumps → /data/tombstones/{modem,lpass}`），`rootdir/Android.mk` 里的 `$(TARGET_OUT)/rfs` 目标把它装进 `/system/rfs`。
      - `rmt_storage` 读 `/dev/block/bootdevice/by-name/*`，由 `vendor.gree.radio.rc` 的 `on init` 建 `/dev/block/bootdevice/by-name → /dev/block/by-name`。
    - **init 服务（`radio/vendor.gree.radio.rc`，装到 `/vendor/etc/init`）**：`rmt_storage`（core）、`tftp_server`、`irsc_util "/etc/sec_config"`（oneshot）、`time_daemon`、`qmuxd`、`netmgrd`，权限组沿用原厂 `init.qcom.rc`。`on init` 建 `qmux_radio`、`qmux_audio`、`qmux_bluetooth`、`qmux_gps` 和 `/dev/socket/netmgr` 套接字；`post-fs-data` 建 `/data/misc/radio`、`/data/misc/sms`、`/data/misc/ipa`、`/data/tombstones/{modem,lpass}`、`/persist/hlos_rfs{,/shared}`，并跑 `init.gree.radio.sh`：第一次把 `/vendor/qcril.db` 复制到 `/data/misc/radio/qcril.db`（属主 radio，写 `db_check_done`）。`persist.sys.ssr.restart_level` 写 `subsys0..5/restart_level`。
    - **rild**：`rild.libpath=/vendor/lib64/libril-qc-qmi-1.so`。平台树的 `vendor.ril-daemon` 用 `override` 换成我们的 `ril-daemon`（`/vendor/bin/hw/rild`，user root，组 radio、cache、inet、misc、audio、log、readproc、wakelock、diag，套接字 `rild`、`rild-debug`、`sap_uim_socket1`）。`vendor/etc/init/*.rc` 的解析顺序晚于 `hw/init.gree.rc`，所以 `override` 生效。双卡是两个 rild 进程：`ril-daemon2 ... rild -c 2`（`disabled`，由 `persist.radio.multisim.config=dsds` 触发 `start`）。`-c <id>` 决定 HIDL 服务名 `slot1`、`slot2`。`manifest.xml` 加 `android.hardware.radio@1.1` 的 `IRadio/slot1`、`slot2`、`ISap/slot1`，以及 `android.hardware.radio.deprecated@1.0` 的 `IOemHook/slot1`、`slot2`。`BoardConfig.mk` 设 `TARGET_USES_OLD_MNC_FORMAT := true`。
    - **属性（`radio.mk`）**：`ril.subscription.types=NV,RUIM`、`ro.telephony.default_network=9,9`、`persist.radio.multisim.config=dsds`、一组 `persist.radio.*`、`persist.rild.nitz_*`、`persist.data.*`、`ro.use_data_netmgrd=true`、`persist.rmnet.data.enable=true` 等，来自原厂 `build.prop`。
    - **基带如何启动**：原厂靠 `pm-service`/`pm-proxy` 打开 `/dev/subsys_modem`，QCRIL 通过 `libperipheral_client` 向 `pm-service` 注册。打开这个节点就让 modem 子系统从 `/vendor/firmware_mnt`（`MPSS.TH.2.0.c1`）启动，内核有引用计数。原厂 `pm-service`、`pm-proxy` 是 Android 6 的 C++ Binder 子类，和 A11 的 `libbinder` 虚表不兼容，`pm-proxy` 一启动就在空指针上崩溃。所以自己写了 `radio/libperipheral_client`（`vendor` 共享库，源码 `peripheral_client.cpp`），覆盖原厂同名库：导出 `pm_client_register/connect/disconnect/unregister/event_acknowledge`，`pm_client_connect` 起一个线程先回调 `GOING_ONLINE`，打开 `/dev/subsys_<名字>` 并在进程生命周期内保持打开，再回调 `IS_ONLINE`；其余是空函数。原厂 `pm-service`、`pm-proxy` 不再启动。副作用：modem 从不主动下电。这个库里还放了一个空的 `android::AudioSystem::setErrorCallback(void (*)(int))`，因为 QCRIL 链接了这个 Android 6 的 libmedia 符号，A11 没有它。
    - **二进制补丁**：`time_daemon` 和 `libtime_genoff` 在 EL0 读 `cntpct_el0`，这个内核会陷入，进程 `SIGILL`。把两处指令改成读 `cntvct_el0`（`time_daemon` 偏移 `0x2030`，`libtime_genoff` 偏移 `0x133c`），数值同一个计数器，只是用户态可读。
    - **一个重要的反例：不要用 `SIM_COUNT := 2` 编 libril**。第一版为了双卡定义了 `SIM_COUNT=2`，`libril` 就用 `RIL_Env` 的多卡变体（每次回调多带一个 slot 参数）。QCRIL 用的是每个实例一份的 3 参数 `RIL_Env`，`oemHookRawInd` 里读到的槽号是垃圾值，`rild` 直接崩溃。所以 `libril` 不带 `SIM_COUNT=2`，双卡靠两个 rild 进程。
    - **和平台树模块撞车的文件**：原厂的 `ipacm`、`ipacm-diag`、`libipanat`、`libnetfilter_conntrack`、`libnfnetlink`、`librmnetctl` 与平台树里的同名模块安装路径冲突，`m systemimage` 报重复安装目标。这些原厂副本没有放进 `radio/`，用平台树的版本。`librmnetctl` 平台树版本实测和 `netmgrd` 一起正常。
    - **`ipacm` 关掉**：平台树的 `ipacm` 是按 IPA v3 和 offload HAL 编的，`liboffloadhal.so` 缺，进程 restart-loop。原厂的 `ipacm` 也在 `0x180` 空指针崩溃。不用它，移动数据照样通（IPA 的 `rmnet_ipa` 数据通路不依赖它）。`vendor.gree.radio.rc` 里 `service vendor.ipacm` 带 `override` 和 `disabled`，等于关掉。热点、IPA offload 之后再看。
    - **`radio/etc/data/*.xml`**：构建会对 `.xml` 跑 `xmllint`，原厂的三份 XML 文件开头有注释，在 `<?xml ...?>` 声明之前，报 `XML declaration allowed only at the start of the document`。声明移到第一行，注释放后面，libxml 解析不受影响。
    - **一个事故：黑屏、无背光、红灯**。第一次往机器里推文件，用 `chmod 644 /system/vendor/lib64/*` 把 `lib64/hw` 和 `lib64/egl` 目录也改成 644，系统找不到 `/vendor/lib64/hw/android.hardware.graphics.allocator@2.0-impl.so`，`surfaceflinger` abort，屏幕不亮。`/cache/boot-logcat.txt` 里有这句日志。恢复办法是在 recovery 里挂载 system（`sde18`），对 `vendor/lib64` 下所有目录 `chmod 755`。之后推送脚本只按文件改权限。经验：永远不要对目录通配 `chmod`。
    - **实机证明**：`subsys5 modem` 为 `ONLINE`，两个 rild 向 hwservicemanager 注册 `slot1`、`slot2`，`gsm.sim.state=LOADED,ABSENT`，Fizz 卡（加拿大）识别并加载，驻网 `Fizz EXT`（`302610`），HSPA，漫游标志为 true。关 Wi-Fi 后蜂窝数据通：`rmnet_data0` 拿到 IP，`ping 8.8.8.8` 和域名解析都成功。冷启动一次后仍然成立。
    - **数据被禁用的原因不是 RIL**：`Data disallowed, reasons: ROAMING_DISABLED`、`mobile_data=0`。这是用户设置：`svc data enable`、`settings put global data_roaming1 1`（Fizz 用的是网络共享接入（`302610`），系统把它当成漫游，要在设置里打开数据漫游）。这不是构建里要修的东西。
    - **整镜像**：`m systemimage` 成功，`/run/media/alpha/YMTC/g0215d/boot-test/system-7f.img`（稀疏格式，1697882656 字节，`sha256 654350620fc2703678e913fd219d6c62c375443854ec343b60ef47dba036375f`）。staging 目录里有 `/persist`、`/firmware` 符号链接、`system/rfs` 符号链接树、六个原厂二进制、`vendor.gree.radio.rc`、`qcril.db`，manifest 里有两个 radio HAL，`lib64`、`lib64/hw`、`lib64/egl` 都是 755。这份镜像没有刷。内核和 boot 没有改，仍是 `boot-audio9.img`。
    - **没做、没通过的**：语音通话（后来在下面的"7F 补记"里修好）、短信、VoLTE/IMS、第二张卡（`ABSENT`）、听筒和蓝牙电话音频、LTE（只看到 HSPA）都没有测。`netmgrd` 在一次启动后（13:27:48）被 Scudo 报 `invalid chunk state when deallocating`（Android 6 代码里的重复释放，A11 的 Scudo 不再放过）abort，init 自动重启后正常，原因没有追。如果这样的崩溃反复出现，需要对 `netmgrd` 单独换分配器或补丁。`pm-service` 的替代品不会让 modem 下电，影响功耗。SELinux 仍是 permissive，转 enforcing 之前要给这些守护进程补策略。
  - **7F 补记（通话音频与通话后回 LTE；通话两个方向、听筒和免提已在实机验证）**：
    - **现象**：Fizz EXT（`302610`，漫游伙伴）上拨号能回落 3G 并接通，但听不到对方，对方也听不到。通话结束后手机停在 3G。另外用户把"首选网络类型"切到过 3G 做测试，之后一度忘记切回（`preferred_network_mode=0`），这会让手机永远不上 LTE，和下面的第二点无关。
    - **第一层根因：HAL 开错了语音会话**。QCRIL 的 `qcril_am` 通过 `AudioSystem::setParameters("call_state=2;call_type=UMTS;vsid=297816064")` 通知音频，`297816064 = 0x11C05000`，即 `VoiceMMode1`。CAF HAL 只有在 `AUDIO_FEATURE_ENABLED_MULTI_VOICE_SESSIONS` 打开时才会编 `voice_extn.c`、处理 `call_state`/`vsid`。没开的时候 HAL 忽略这两个参数，在 `adev_set_mode(IN_CALL)` 里起的是传统 CS-Voice 会话（`voice-call`，PCM 设备 40，vsid `0x10C01000`），与基带用的会话对不上。`BoardConfig.mk` 加 `AUDIO_FEATURE_ENABLED_MULTI_VOICE_SESSIONS := true`，重编 `audio.primary.msm8996`（32 位，音频 HAL 是 32 位进程）。日志里能看到 `update_calls: INACTIVE -> ACTIVE vsid:11c05000`、`voice_start_usecase: enter usecase:voicemmode1-call`。
    - **第二层根因：ADSP 拒绝 vocproc 的 topology commit**。开对会话之后仍然没声音。内核里 `voice_setup_vocproc` 的顺序是创建 CVP 会话（`VSS_IVOCPROC_CMD_CREATE_FULL_CONTROL_SESSION_V3`）、设设备通道数（`0x13199`，成功）、`VSS_IVOCPROC_CMD_TOPOLOGY_COMMIT`（`0x13198`）。commit 被 ADSP 返回 `ADSP_EFAILED`（错误码 1），随后 `voice_setup_vocproc: Set topology commit failed err:-131`、`setup voice failed`，会话没有建起来，但电话照样接通，所以表现为"通了没声音"。当时 ACDB 给的拓扑是 TX `0x10F89`、RX `0x10F8A`（`voice_get_topology` 日志里的 69513、69514），CVD 版本 `2.2`。内核需要 CVD ≥ 2.2 才发这条 commit。为什么 ADSP 不接受这两个 ID 还没有查清楚，原厂 3.18 内核里 commit 和设备通道数的代码和我们一样。
    - **验证与绕过**：内核有 `Voice Topology Disable` 控制（`msm_voice_topology_disable_put`，值 `{disable, vsid}`），打开后 `voc_get_tx_rx_topology` 用 `VSS_IVOCPROC_TOPOLOGY_ID_NONE`（`0x10F70`）创建 vocproc，commit 就通过了。用户确认此时听筒两个方向都有声音。这条控制的量程在 tinyalsa 里是 `0..-1`，`tinymix` 会因范围检查拒绝；但 `audio_route` 用 `mixer_ctl_set_array` 不做范围检查，可以在 `mixer_paths_tasha.xml` 里用 `id` 属性逐个下标赋值。
    - **修复（`mixer_paths_tasha.xml`）**：加两个辅助 path：`voicemmode1-no-topology`（`Voice Topology Disable` 下标 0 设 1，下标 1 设 `297816064`）和 `voicemmode2-no-topology`（vsid `299651072 = 0x11DC5000`，第二张卡用）。所有带 `Voice Mixer` 的 `voicemmode1-call*`、`voicemmode2-call*` path（听筒、耳机、HDMI、蓝牙 SCO、afe-proxy、USB，以及 `quat_mi2s_rx_voice` 变体）都引用它。这个控制在每次通话结束时（`voc_update_session_params`）被内核清零，所以必须每次通话开始时写，而 `voicemmode*-call` path 正是每次通话开始时应用，时间也在 `voice_start_usecase` 创建 CVP 之前，顺序对得上。代价：vocproc 没有拓扑，也就没有回声消除、降噪和 ACDB 里的语音处理校准。听筒和免提使用者都说声音正常，没有单独评估回声和底噪。
    - **第三层：免提没声音（麦克风有）**。通话选了 `voice-speaker`（`snd_device` 16）之后，HAL 对 `SND_DEVICE_OUT_VOICE_SPEAKER` 没有 `backend` 条目，沿用默认的 `SLIMBUS_0_RX`，应用 `voice-speaker` → `speaker-mono`，走 WCD9335 内置扬声器通路。这台机器的扬声器是 `QUAT_MI2S_RX` 上的 TFA9890（见 7C），所以没声。原厂 HAL 里有 `SND_DEVICE_OUT_QUAT_MI2S_RX_VOICE`、后端名 `quat_mi2s_rx_voice`，原厂 mixer 里也有 `voicemmode1-call quat_mi2s_rx_voice`（本仓库里早有，没有被用上）。`audio_platform_info.xml` 加 `SND_DEVICE_OUT_VOICE_SPEAKER` → `backend="quat_mi2s_rx_voice" interface="QUAT_MI2S_RX"`，`mixer_paths_tasha.xml` 加空 path `voice-speaker quat_mi2s_rx_voice`。使用者确认免提开关两个方向都正常，听筒仍正常。
    - **调试上踩的坑**：`tinymix` 列表第一列是从 0 开始的序号，ALSA 的 `numid` 是序号加 1。`Voice Topology Disable` 在列表里是 6，`numid` 是 7。第一次用自写的 `ctlw` 工具写了 `numid 6`，实际写的是 `Slowtalk Enable`，所以第一次"关拓扑"的实验没有生效，用户那一通电话仍然无声。已经把 `Slowtalk Enable` 写回 0，重新用 `numid 7` 才得到有声的结果。
    - **通话后停在 3G：没有改动，结论是基带/网络行为**。实机时间线（`dumpsys telephony.registry` 每 5 秒一次）：15:08:43 LTE（Fizz EXT）→ 15:08:53 拨号，CSFB 回落 UMTS → 15:09:06 挂断 → 一直是 UMTS/HSPA，数据 HSPA → 15:12:16 自己回到 LTE，运营商变成 `Fizz`（家网，Videotron `302500`）。也就是约 3 分 10 秒后基带自己回 LTE，并且回去的是家网。这和使用者之前"手动切 3G 再切回 LTE 就好"的观察一致：切换是让基带立刻重新搜网，而不是修了什么。RIL 日志里挂断之后没有任何 `SET_PREFERRED_NETWORK_TYPE` 或选网请求，QCRIL 只是把基带上报的状态转给框架，QCRIL 里也没有"通话后回 LTE"的属性（`libril-qc-qmi-1.so` 里相关的只有 `persist.radio.sglte_csfb`、`persist.radio.sw_mbn_*`、`persist.radio.mbn_path` 等）。原因判断：漫游伙伴（Bell）的 3G 小区没有通过 RRC release 重定向或 SIB19 把手机引回 LTE，手机这个国行基带里也没有加拿大运营商的 MBN（`/vendor/firmware_mnt/image/modem_pr/mcfg/configs/mcfg_sw` 下只有中国、亚太、欧洲、韩国、美国 AT&T/T-Mobile/Sprint/US Cellular/Verizon、巴西等，没有 Rogers/Bell/Telus/Videotron），会话结束后基带只能靠周期性的高优先级 PLMN 搜索把手机拉回家网 LTE。用户态没有稳妥的办法改这个定时器。可选的缓解（没有做）：做一个有系统签名的小 App，监听通话结束后在 RAT 还是 UMTS 时重新下发一次首选网络类型来立即触发重搜，但重搜后回到的多半仍是家网 `Fizz`（上面的结果显示 `Fizz` 不能 CSFB、没有 VoLTE 就不能打电话），所以意义有限；真正的出路是第 3 点的 VoLTE。
    - **VoLTE / IMS**：本轮不做，只给建议，见对话。
    - **内核和 boot**：没有改。排查期间为 `q6voice.c` 临时加的 `#define DEBUG 1` 已 `git checkout` 回退，没有提交。手机当时跑的是带这行调试的 `boot-voicedbg.img`，除多出一堆 `voice_itr_get_next_session` 日志外没有区别，需要换回 `boot-audio9.img`。
    - **整镜像**：`m systemimage` 编出 `/run/media/alpha/YMTC/g0215d/boot-test/system-7f2.img`（稀疏格式，1697907232 字节，`sha256 66136fc6f2fc0c2fea52094d6f42a59ae4d469e34f746114b7ac735be6f3c3d2`），含新的 `audio.primary.msm8996.so`、`mixer_paths_tasha.xml`、`audio_platform_info.xml`，还原了真正的 `libacdbloader.so`（调试期间推过测试版）。实机上这三份已经手动推过并验证；镜像没有刷。
    - **没做、没通过的**：回声和降噪（拓扑关掉了）、耳机和蓝牙通话路径（只改了 mixer，没有测）、第二张卡通话（`voicemmode2-call`，只照第一张卡的办法改了 mixer）、VoLTE/IMS、短信、LTE 上的数据速度。ADSP 为什么拒绝 `0x10F89` / `0x10F8A` 这对拓扑还没有查清，查清之后可以去掉 `no-topology` 绕过，把回声消除找回来。
  - **7I（USB 功能切换：文件传输双向已通过，PTP、MIDI、网络共享都能枚举）**：
    - **现象**：设置里的 USB 模式停在「仅充电」，文件传输、USB 网络共享、MIDI、PTP 全部是灰的。adb 正常，`sys.usb.config` 实际是 `adb`，gadget 上只挂了 `ffs.adb`。`dumpsys usb` 的 `port_manager` 是空的。
    - **根因**：Android 11 的设置在端口没报 `connected` 或 data role 不是 device 时，把整组功能禁用。这台机器没有 `/sys/class/dual_role_usb`，AOSP 的 USB HAL 只扫这个目录，所以一个端口都报不出来。`/sys/class/typec` 也是空的。线的状态在 `extcon0`：`USB=1` 是设备模式。7A 为了保住 adb，把 `persist.sys.usb.config` 的 `mtp` 和 `none` 写回 `mtp,adb`，开机完成时再写一次。这会挡住以后把模式留在充电或纯 MTP，但这次选项是灰的，不是被它拉回去的。
    - **端口 HAL**：`usb/` 里的 `android.hardware.usb@1.0-service.gree`。读 `extcon0` 的 `USB=1`（读不到就看 `android_usb` 的 `CONFIGURED`/`CONNECTED`），上报 `port0`：模式 UFP、data role device、power role sink，三个 `canChange` 都是 false。`supportedModes` 必须等于 `currentMode`。`UsbPortManager` 对非 DRP 端口会把不一致的 current mode 清成 0，端口又变成未连接。拔线后报 NONE。`manifest.xml` 声明 `android.hardware.usb` 1.0 `IUsb/default`。不要再装一份同名 vintf fragment，和主 manifest 撞了 `hwservicemanager` 会拒绝加载。依赖的 `android.hardware.usb@1.0.so` 在 `/system/lib64`，厂商进程找得到。
    - **产品号**：`init.usb.configfs.rc` 负责挂 function，但 `configfs=1` 时原来的 `init.usb.rc` 不写产品号。`init.gree.rc` 补上 Google 的 id：`mtp` `4ee1`、`mtp,adb` `4ee2`、`rndis` `4ee3`、`rndis,adb` `4ee4`、`ptp` `4ee5`、`ptp,adb` `4ee6`、`adb` `4ee7`、`midi` `4ee8`、`midi,adb` `4ee9`。去掉那三条把 `persist.sys.usb.config` 写回 `mtp,adb` 的规则。adb 仍由 `adb_enabled=1` 保持，框架会在所选功能后面加上 `,adb`。
    - **实机**：冷启动后 `vendor.usb-hal-1-0` 在跑，端口 `connected`、`data_role=device`。文件传输：主机看到 `18d1:4ee2`（MTP + debug），从手机读出 `usb-7i-test.txt` 内容 `g0215d-7i`，从电脑写入 `usb-7i-to-phone.txt`，手机上读到 `host-to-phone`。PTP：`18d1:4ee6`，接口类 6 Still Image。MIDI：`18d1:4ee9`。网络共享：`18d1:4ee4`，主机出现一块 `LOWER_UP` 的网卡，切回 MTP 后网卡消失。测完把解锁后的默认功能设成 `mtp`，冷启动后仍是 `mtp,adb`（仅充电不再是默认）。测试文件已删。没有改内核。SELinux 仍是 permissive，二进制标签还是 `system_file`，和传感器 HAL 一样，转 enforcing 之前要补域。
    - **整镜像**：`m systemimage` 成功，`/run/media/alpha/YMTC/g0215d/boot-test/system-7i.img`（稀疏格式，1699783200 字节，`sha256 f0f7f7f0a0f1f351ccff69a870e86420326685a5f514d79751b68b4c0a038cc2`）。里面有 `android.hardware.usb@1.0-service.gree`、`/system/lib64/android.hardware.usb@1.0.so`，`init.gree.rc` 有 `0x4ee9`，manifest 有 `android.hardware.usb`，没有第二份 USB fragment。这份镜像没有刷。手机上现在跑的是推进去之后的那次启动。内核和 boot 没有改，仍是 `boot-audio9.img`。
  - **7J（振动：DRV2605 已绑定，系统定时振动已下发）**：
    - **现象**：整机没有振动，带 4.4 内核的新 TWRP 也没有。板级是 DRV2605，在 `i2c@75b6000`（BLSP2 QUP2）的 `0x5a`，compatible `qcom,haptics-drv2605`。使能是 TLMM GPIO 74，高电平有效；GPIO 48 是触发脚，下拉。
    - **根因**：`CONFIG_TSPDRV` 已经把 `drivers/misc/drv2604.c` 编进内核，但这份驱动没有 `of_match_table`，使能脚写死 GPIO 93，而且读到的芯片 ID 不是 DRV2604 / DRV2604L 就直接失败。格力的 DTS 里也没有这个节点，所以芯片从未被探测。TWRP 用的是同一颗 4.4 内核，所以那边同样没有振动。
    - **内核**：`g0215d-msm8996-v3-pmi8996-mtp.dts` 加上 `haptics@5a` 和 `g0215d_motor_default`（GPIO 74 输出高、GPIO 48 下拉）。驱动认 `qcom,haptics-drv2605`，使能脚改读 `motor,en-gpio`。DRV2605 / DRV2605L 走同一条 timed_output RTP，不要求 `drv2604.bin`；DRV2604 仍按原路径加载波形固件。执行器参数沿用驱动里已有的 LRA、额定电压 `0x30`。
    - **用户态**：设置和来电走的是 HIDL，不是直接写 sysfs。`device.mk` 加入 `android.hardware.vibrator@1.0-service`、`android.hardware.vibrator@1.0-impl`、`vibrator.default`（读 `/sys/class/timed_output/vibrator/enable`）。`manifest.xml` 声明 `android.hardware.vibrator` 1.0 `IVibrator/default`。
    - **实机**：boot 已刷成 `boot-vibe.img`，内核是 `4.4.302-perf+ #27`。`drv2604_probe` 读到状态 `0x64`，打印 `drv2605 v1.1`，`probe succeeded`。`/sys/class/timed_output/vibrator/enable` 写 500 后从约 486 倒计时到 0。`waveform` 里额定电压寄存器 `0x16` 读回 `0x30`。冷启动后 `vendor.vibrator-1-0` 在跑，`lshal` 有 `IVibrator/default`。`cmd vibrator vibrate 400` 记进 `dumpsys vibrator` 的 Previous vibrations：`OneShot{mDuration=400}`，来源是 Shell command。框架还会去找 1.3，找不到就用 1.0，这条日志可以忽略。SELinux 仍是 permissive。TWRP 的振动没有做。
    - **内核与镜像**：`Image.gz-dtb` 12778075 字节，加载地址 `0x80008000`，结束地址 `0x80c37a5b`，仍低于 ramdisk 的 `0x81000000`。boot 镜像是 `/run/media/alpha/YMTC/g0215d/boot-test/boot-vibe.img`，13619200 字节，`sha256 a2fa42abeff5704f6bb731e3198e5646deff1733baf738cef930b9cb1c347c8f`。cmdline 和 ramdisk 沿用 `boot-audio9.img`。已 `dd` 进 `/dev/block/by-name/boot`，读回的 sha256 一致。这一轮重编了内核，属于“本阶段不做”里的例外。内核改动还没提交。
    - **整镜像**：`m systemimage` 成功，`/run/media/alpha/YMTC/g0215d/boot-test/system-7j.img`（稀疏格式，1699832352 字节，`sha256 399ef63dde9b47666c0789388145b92efd6440b5292278eb4452ae1aedf6629a`）。里面有 vibrator 服务、`vibrator.default.so`，manifest 有 `android.hardware.vibrator`。这份镜像没有刷。手机上现在跑的是推进去之后的那次启动，boot 是 `boot-vibe.img`。
    - **相机打开时两侧键不振（补记）**：`msm_sensor_power_up` 成功之后调用 `drv2604_disable_haptics()`，`msm_sensor_power_down` 再调用 `drv2604_enable_haptics()`。这是一加树里的挂钩（`include/linux/drv2604.h`，Sultan，2019）。`disable_refcnt > 0` 时 `vibrator_enable` 直接返回。预览期间传感器一直上电，所以相机开着时两侧键的 `Virtual Key - Press` 会记进 Vibrator Service，电机不动。去掉这两处调用。`boot-cam6.img`（内核 `#34`）已刷，读回一致。预览中注入 BACK，`enable` 剩余读到 26 ms；关掉相机时是 18 ms。两边都是 `config_virtualKeyVibePattern`（`0, 10, 20`）那下大约 10 ms 的点击。MENU 也能读到非 0。相机开着时直接写 `enable` 800，从 790 倒计时到 0。
  - **7K（硬件视频与音频编解码：Venus H.264 硬件解码/编码与 ADSP AAC 硬件解码已通过）**：
    - **Venus 硬件视频编解码**：
      - 固件 `venus.mdt`、`.b00–.b04` 在 `/vendor/firmware_mnt/image/`，通过 `/system/etc/firmware/` 下的符号链接供内核 `msm_vidc` 加载。
      - `device.mk` 加入 `libc2dcolorconvert`、`libhypv_intercept`、`libmm-omxcore`、`libOmxCore`、`libOmxVdec`、`libOmxVenc`、`libstagefrighthw`、`libOmxAacEnc`，安装 `media/media_codecs.xml` 与 `media/mediacodec-arm.policy`（在软件 seccomp 策略基础上放行 32 位 OMX 组件需要的 `_llseek` 和 `sysinfo`）。
      - Android 11 的 `MediaCodecList.cpp`（`GetBuilders`）在 `CCodec::CreateInputSurface()` 非空（软件 Codec2 能建输入 surface）时默认只用 `sOmxNoSurfaceEncoderInfoBuilder`，会把所有 OMX 视频硬件编码器从列表里藏掉。平台树 `frameworks/av/media/libstagefright/MediaCodecList.cpp` 改为始终注册 `sOmxInfoBuilder`，使 `OMX.qcom.video.encoder.avc` / `hevc` 正常暴露。
    - **ADSP 硬件音频解码（`OMX.qcom.audio.decoder.aac`）失败根因**：
      - 补进格力原厂 32 位 `libOmxAacDec.so`、在 `hardware/qcom-caf/msm8996/media/mm-core/src/msm8996/registry_table_android.c` 注册 `OMX.qcom.audio.decoder.aac`、并给 `frameworks/av/services/mediacodec/android.hardware.media.omx@1.0-service.rc` 的 `vendor.media.omx` 加上 `audio` 组（使 `mediacodec` 进程有权打开 `0660 root:audio` 的 `/dev/msm_aac`）之后，`OMX.qcom.audio.decoder.aac` 在 `AUDIO_START` 时仍报错：`audio_aio_open` 内核 `q6asm_open_read_write_v2` 发送 `ASM_STREAM_CMD_OPEN_READWRITE_V2`（`0x10d8d`，格式 `ASM_MEDIA_FMT_AAC_V2 = 0x10da6`）被 ADSP 返回 `ADSP_EFAILED`（`0x1`），驱动映射为 `-ENODEV`（`-131`）。
      - **第一层根因（ADSP 动态模块加载与 `/dsp`）**：审计 `adsp.b08` 符号表与 `/vendor/dsp/map_avs_shared_libs.txt` 发现，MSM8996 的 ADSP 固件只把 MP3 解码器静态编入镜像（`BUILT-IN`），而 AAC（`HeaacDecoderModule.so.1`）、FLAC、ALAC、Vorbis、WMA、Dolby、DTS 等模块都存放在独立的 `dsp` 分区（`/dev/block/by-name/dsp` → `/vendor/dsp`），由 ADSP 在打开对应流时通过 FastRPC 反向调用用户态守护进程 `adsprpcd`（`libadsp_default_listener.so`）从 `/dsp` 动态加载。系统当时既没有跑 `adsprpcd`，根下也没有 `/dsp` 符号链接，所以 ADSP 找不到 `HeaacDecoderModule.so.1`，直接拒绝打开 AAC 流。
      - **第二层根因（Android 6 `libadsprpc.so` 与 4.4 内核 `adsprpc` 的 `cid` 握手不兼容）**：把原厂 `adsprpcd` 跑起来后，进程陷入每 25 ms 一次的重启循环，`dmesg` 报 `'adsprpc_init_process (1536): error != 0'`。对照 4.4 内核 `drivers/char/adsprpc.c` 发现：4.4 在 `fastrpc_device_open()` 中将 `fl->cid` 初始化为 `-1`（`fl->sctx = NULL`），要求用户态先调 `FASTRPC_IOCTL_GETINFO`（`0xc0045208`，传入域 ID `0` 即 `ADSP_DOMAIN_ID`）分配 `fl->cid` 与 `fl->sctx`，随后才能调 `FASTRPC_IOCTL_INIT`；而格力 Android 6 的 `libadsprpc.so` 打开 `/dev/adsprpc-smd` 后直接调 `FASTRPC_IOCTL_INIT`，因 `fl->cid == -1` 被内核返回 `-ENOTTY` / `-ECHRNG`。
    - **修复（不改内核）**：
      1. 编写 `media/libfrp.c`（`media/Android.bp` 编译 32/64 位 `libfrp.so`）：拦截 `open("/dev/adsprpc-smd", ...)`，拿到 fd 后立即下发一次 `ioctl(fd, FASTRPC_IOCTL_GETINFO, &info)`（`info = 0`）。
      2. 修改 32/64 位 `media/lib{,64}/libadsprpc.so`：该库 `.dynsym` 中没有任何 C++ 符号，将其未使用的 `DT_NEEDED` 项 `libc++.so` 原位替换为等长的 `libfrp.so`，并将 `.dynsym` 中的 `UND open` 符号名指向 `libfrp.so`（`.gnu.version` 置为 `1` 全局未版本化），无需 `LD_PRELOAD` 即可让所有加载 `libadsprpc.so` 的 32/64 位进程自动完成域 0 初始化。
      3. `BoardConfig.mk` 增加 `BOARD_ROOT_EXTRA_SYMLINKS += /vendor/dsp:/dsp`（`file_contexts` 标签已在 `device/qcom/sepolicy-legacy-um` 中定义），`device.mk` 安装 `adsprpcd`、`libfrp`、`libadsprpc.so`、`libadsp_default_listener.so`、`libOmxAacDec.so`，`init.gree.rc` 增加 `service adsprpcd /vendor/bin/adsprpcd`（`class main`、`user media`、`group media`）。
    - **实机验证**：冷启动后 `adsprpcd`（`user media`）稳定驻留（`do_sys_poll`），`/dsp -> /vendor/dsp` 生效：
      - 硬件音频解码：`stagefright -a -N OMX.qcom.audio.decoder.aac /data/local/tmp/tone.aac` 输出 `decoded a total of 92160 bytes`（`148.87 KB/sec`）。
      - 硬件视频解码：`stagefright -N OMX.qcom.video.decoder.avc /data/local/tmp/h264.mp4` 输出 `decoded a total of 15 frame(s)`（单帧耗时 `2109.00 usecs`）。
      - 硬件视频编码与解码：`OMX.qcom.video.encoder.avc` 编码生成的 H.264 MP4 及 `stagefright -r` 硬件解码（`159.73 fps`）均通过。测试文件已清理。没有改内核和 boot，仍是 `boot-vibe.img`。
    - **整镜像**：`m systemimage` 成功，`/run/media/alpha/YMTC/g0215d/boot-test/system-7k.img`（稀疏格式，1701663264 字节，`sha256 6f62d3e714f6ddf05820003783777c255202916af1e8cfa563d71d50332479b4`）。staging 目录确认含 `/dsp -> /vendor/dsp`、`/vendor/bin/adsprpcd`、32/64 位 `libfrp.so`、`libadsprpc.so`、`libadsp_default_listener.so`、32 位 `libOmxAacDec.so`、`libOmxVdec.so`、`libOmxVenc.so`。这份镜像没有刷。
  - **7L（相机：前后摄预览、拍照、短视频通过）**：
    - **验收**：用一个测试 APK（`gree.camgrab`，测完已卸载）按 Camera2 API 依次打开 0 号和 1 号相机，YUV 1280x720 预览加 JPEG 拍照，再用 `MediaRecorder` 的 surface 录 1.5 秒 H.264。后摄：预览出帧，照片 133566 字节（720x1280 JPEG，曝光和白平衡正常），视频 1280x720、39 帧。前摄：预览出帧，照片 140204 字节，视频 28 帧。抽帧看过，画面正常。系统自带相机（`com.android.camera2`）冷启动后能预览，拍出 `IMG_20261027_221901.jpg`，3456x4608，5011183 字节。全程没有 `CAM-SMMU` 或 CPP page fault。
    - **已经通的部分**：原厂 32 位 `camera.msm8996.so` 和 `mm-qcamera-daemon` 在跑。内核设备树按原厂接线（后摄 `s5k3p3` CSI0，前摄 `ov8858` CSI2）。`SUB_MODULE_MAX` 收到 Android 6 HAL 的 12，`IR_LED` / `IR_CUT` / `LASER_LED` 挪到后面，否则 `VIDIOC_MSM_SENSOR_INIT_CFG32`（`0xc0bc56ca`，188 字节）对不上。两颗传感器都能 probe，后摄 EEPROM `sunny_a16s05e` 读到了校准。ISP 子模块和 `cpp_firmware_v1_10_0.fw` 已装上。`libshim_mutex.so` 拦了两件事：Android 11 对二次 `pthread_mutex_destroy` 会直接中止；daemon 把 5 亿纳秒加进 `tv_nsec` 却不进位，`pthread_cond_timedwait` 立刻返回，会话 2 的 `open_done` 一直是 0。进位之后，sensor / iface / isp / stats / pproc 的 `start_session` 都返回 1。
    - **静态参数**：Android 6 的 `CameraMetadata` 是 8 字节（指针加锁，没有虚表）。Android 11 多了一个 `Parcelable` 虚表，锁标志落到 HAL 栈上的另一个局部变量里，`update()` 全部报 `CameraMetadata is locked`，`release()` 交出空指针，provider 在 `get_camera_metadata_entry_count` 空指针崩溃。`libshim_metadata.so` 按 8 字节布局实现这些符号，`camera.msm8996.so` 的 `DT_NEEDED` 把等长的 `libcamera_client.so` 换成它，其余符号仍转到系统的 `libcamera_client.so`。换上之后 provider 不再在这里崩溃，`get_number_of_cameras` 是 2。
    - **显示**：vsync 回调按 Android 6 的 28 字节事件读时间戳（偏移 8）。Android 11 的 `Event` 是 40 字节，时间戳在偏移 16，多出来的字节把回调保存的寄存器冲掉，`Looper::pollInner` 跟着崩溃。`libgu2.so` 和 `libgui.so` 等长，HAL 的 `DT_NEEDED` 换成它，只翻译 `getEvents`，其余符号仍走系统的 `libgui.so`。provider 和 `android.hardware.graphics.composer@2.1-service` 都改到 `/dev/binder`，这样 SurfaceFlinger 和 `display.qservice` 在同一个驱动上。冷启动后 `dumpsys media.camera` 是 2 个设备：0 后摄朝向 90，1 前摄朝向 270。
    - **ioctl 尺寸**：把内核 uapi 头按 32 位 ARM 编一遍，算出每个相机 ioctl 号，再和原厂库里出现的常量逐个对。iface 模块只有两条对不上，sensor、CSI、actuator、EEPROM、flash、CPP、buf_mngr 都一致。
      - `VIDIOC_MSM_ISP_CFG_STREAM`：原厂是 44 字节（`0xc02c56c5`），内核 48 字节。反汇编 `libmmcamera2_iface_modules.so` 的调用点：`num_streams` 在偏移 0，8 路 handle 在 4–35，`cmd` 在 36，`sync_frame_id_src` 在 40，少的是末尾的 `dummy`。`boot-cam3` 按 7 路 handle 加 `dummy` 翻译，`cmd` 读错了位置。`boot-cam4` 改成 8 路 handle，不带 `dummy`。
      - `VIDIOC_MSM_ISPIF_CFG`：原厂是 368 字节（`0xc17056c0`），内核 372 字节。差的是小米导入时给 `msm_ispif_param_data` 加的 `reserved_param`（`c9464fb45e41`），dmesg 报 `msm_ispif_subdev_ioctl_unlocked: invalid cmd 0xc17056c0`。`msm_ispif.c` 加一条 368 字节的 case，拷进清零的 `ispif_cfg_data` 再调 `msm_ispif_cmd`。`reserved_param` 是 0，停流超时走默认的 `ISPIF_TIMEOUT_ALL_US`。
    - **`openCamera` 崩溃**：`camera_open` 之后 HAL 调 `sendSingleParam(30)`（`0x42450`），去 `display.qservice` 拿 `IQService`，再在栈上放两个 `Parcel`。Android 6 的 `Parcel` 约 52 字节，Android 11 是 60 字节，写越界，fault `0xfffff784`。`libgu2.so` 补了 `IQService::asInterface`（返回空）和 `Parcel` 的构造、析构、`writeInt32`（都不做事）。HAL 打一行 `getBinder: invalid binder object` 后继续。代价是相机开关不再通知 qservice。
    - **缺的原厂库**：`camera/vendor/lib` 原来没有 JPEG 编码链和 3A 核心。拍照时 `qomx_image_core` 报 `OMX_GetHandle: Cannot load the library`，AEC/AWB/AF 一直是 dummy（`libmmcamera2_q3a_core.so` not found）。从 `third_party/android_vendor_Gree_G0215D-Marshmallow` 补了 18 个 32 位库，依赖都在手机上或在这一组里：`libqomx_jpegenc.so`、`libqomx_jpegenc_pipe.so`、`libqomx_jpegdec.so`、`libmmqjpeg_codec.so`、`libmmqjpegdma.so`、`libmmjpeg.so`、`libjpegehw.so`、`libjpegdhw.so`、`libjpegdmahw.so`、`libmmcamera2_q3a_core.so`、`libmmcamera2_frame_algorithm.so`、`libmmcamera_dummyalgo.so`、`libmmcamera_tintless_algo.so`、`libmmcamera_tintless_bg_pca_algo.so`、`libmmcamera_faceproc.so`、`libmmcamera_imglib_faceproc_adspstub.so`、`libmmcamera_imglib.so`、`libmmcamera_hdr_gb_lib.so`。`libmmcamera_tuning.so` 没放，它要 `libmm-qcamera.so`。
    - **gralloc 句柄**：HAL 按 Android 6 的 `private_handle_t` 读字段。18.1 编的是 `display/gralloc`（`gr_priv_handle.h`），字段顺序变了：偏移 28 原来是 `size`，现在是 `width`；偏移 68 原来是 `width`，现在是 64 位 `base` 的高半，32 位进程里恒为 0。
      - `QCamera3GrallocMemory::registerBuffer` 用偏移 28 当 mmap 长度，1280x720 的缓冲区只映射了 1280 字节。
      - `QCamera3PicChannel::jpegEvtHandle` 用偏移 68 当 JPEG 缓冲区大小，得到 0，把 8 字节的 `camera3_jpeg_blob` 写到缓冲区前 8 字节，`OMX_ImgEnc` 线程 `SEGV_ACCERR`。
      - `camera.msm8996.so` 原位改两条指令：`0x58d3e` 的 `ldr r7, [r1, #28]` 改成 `#52`（`size`），`0x5cb86` 的 `ldr.w sl, [r2, #68]` 改成 `#36`（`unaligned_width`，框架给 BLOB 流请求的大小）。改完是 891308 字节，`sha256 b455af39b59ac91d0c80858c47061e33d370b2d5defcfe9ed4d9fc9a6c192405`。HAL1 的 `QCameraGrallocMemory` 没改，相机走的是 HAL3。
    - **UBWC**：HAL 默认预览和录像都用 UBWC（`CAM_FORMAT_YUV_420_NV12_UBWC`，CPP 日志 `fmt 65`，带 meta plane），给 gralloc 打的是 Android 6 的 `GRALLOC_USAGE_PRIVATE_ALLOC_UBWC`。新 gralloc 只认自己的 `GRALLOC1_PRODUCER_USAGE_PRIVATE_ALLOC_UBWC`（`1 << 28`），两边对缓冲区格式的判断不一致。用法位没有逐位核对。录像时 CPP 访问 IOVA 0，`cam_smmu_check_vaddr_in_range: Cannot find vaddr:0`，`msm_cpp_cfg_frame: page fault occurred`，HAL 报 `camera daemon died`，视频只有 1 帧。`device.mk` 加 `persist.camera.preview.ubwc=0`、`persist.camera.video.ubwc=0`，改用线性 NV12 VENUS。之后录像 39 帧、28 帧，没有 page fault。
    - **系统相机**：手机上没有 `media_profiles`，`CamcorderProfile.hasProfile` 全是 false，`com.android.camera2` 启动就报 `Could not find supported video qualities`。从 cm-14.1 树拿 `configs/media_profiles.xml`，放成 `media/media_profiles_V1_0.xml`，装到 `/vendor/etc`（`sha256 e01989728f2361f1b845922de611f263e452ab249a8ff7d68773c3e9d4319215`）。zygote 预加载 `CamcorderProfile` 时就缓存了 `MediaProfiles`，推完文件要重启才生效。
    - **预览冻结**：`boot-cam4` 上系统相机有三种故障：后摄预览两秒左右定住；切到前摄几秒后定住；再开相机直接报无法连接，没有取景。三种都从 VFE 的 `Drop frame no reg update` 开始。内核 `a9b5f6afbbea`（2017-10，“reconfig regupdate fail buffer”）改了丢帧的处理：错过 reg update 的缓冲区不再报丢，而是留给下一个 SOF（`is_drop_reconfig`、framedrop 周期 1），并且每次 `request_frame` 之后把 `accept_frame` 清零，同一个 SOF 里的第二个请求被拒，内核回空缓冲区（`ISP_ERROR_RETURN_EMPTY_BUFFER`），daemon 记 `iface_axi_handle_output_error: OUTPUT_ERROR`。配套的 daemon 会把自己的请求推后一帧。原厂 daemon 是 2016-10 的，不知道这回事，请求和缓冲区对不上，缓冲区都卡在途中（`queued: 0`），预览定住。之后的会话 `CFG_STREAM` 在 `wait for stream 10003/0 state 4/8 config failed -110` 里卡 9 秒，`force streams to inactive`，daemon 收尾时 `signal 11`，应用报无法连接。`msm_isp_axi_util.c` 把 `msm_isp_drop_frame` 退回旧语义：只把 `bufq_handle & 0xFF` 记进 `reg_update_fail_mask_ext` 报丢，不设 `is_drop_reconfig`，不改 framedrop；`msm_isp_request_frame` 去掉之后的 `accept_frame = false`。`bce627fdfc15` 在 EPOCH1/SOF 中断里开关 `accept_frame` 的部分保留。整个 `git revert a9b5f6afbbea` 合不上，只改这两处，其余 `is_drop_reconfig` 分支不会再走到。换 `boot-cam5` 之后：后摄连续 25 秒、前后摄来回切 6 次（每次停 10 秒）、冷启动 6 次、6 个忙循环压满 CPU 时后摄 40 秒，截图哈希每次都在变，`Drop frame`、`OUTPUT_ERROR`、`force streams to inactive`、`signal 11` 都是 0，daemon 的 pid 没变。旧日志里这四项分别是 18、24、10、12 次。
    - **还没解决**：从前摄切走或关掉前摄时，有时 VFE1 停流等不到 reg update（`wait for stream 2/1 state 9 config failed -110`，`retry...`），重试一次就停下来，多花 3 秒，后面的会话正常。旧日志里也有，那时会走到 `force streams to inactive`。有一次冷启动 provider 报 0 个设备，`dumpsys media.camera` 也是 0，系统相机在 `BOOT_COMPLETED` 时把 `CameraLauncher` 禁用了。手动重启 provider 是 2 个，下一次冷启动也是 2 个，启动器跟着恢复。原因没找到，那次的日志没留住。前摄 EEPROM 库 `libmmcamera_sunny_d8v03c_eeprom.so` 原厂包里也没有（`Failed eeprom_load_library`），前摄没有校准数据也能出图。chromatix module 4 仍是空的，`libthermalclient.so` 也没有。调试时把 `persist.camera.global.debug`、`persist.camera.mm-camera` 设成 3，`persist.camera.sensor.debug` 设成 2，只在手机上，没有写进 `device.mk`。
    - **内核**：当前 boot 是 `/run/media/alpha/YMTC/g0215d/boot-test/boot-fp8.img`，13619200 字节，`sha256 42b9f5320b063d42bb9efb45d412eba6cfdc58855488831eb27d072c92ed15c2`。已刷，读回一致。`uname` 是 `4.4.302-perf+ #43 SMP PREEMPT Wed Oct 28 03:10:33 EDT 2026`。`Image.gz-dtb` 12778246 字节，结束地址 `0x80c37b06`，低于 ramdisk 的 `0x81000000`。cmdline 和 ramdisk 沿用 `boot-cam7.img`。上一份指纹镜像 `boot-fp7.img` 是 13619200 字节，`sha256 79fa6426223e8e444a8a876467981040acbd158359d3af5bc24fcfb0f3fc0bf6`，`uname` 当时是 `#42`。内核改动（设备树、`msm_cam_sensor.h`、`msm_isp_util.c`、`msm_isp_axi_util.c`、`msm_ispif.c`、`msm_sensor.c`、`mdss_fb.c`、`mdss_dsi_panel.c`、`gf816m_keys.c` 等）还没提交。`adsprpcd` 还在。
    - **整镜像**：`/run/media/alpha/YMTC/g0215d/boot-test/system-7l.img`，1745732152 字节，`sha256 205516952e2dd68c8d42e8cd5008be2f80bd7a25eae6aed49a0ee114dc138191`，没有刷。第一次 `m systemimage` 停在 `firmware/cpp_firmware_v1_10_0.fw` 找不到：18.1 树里那份拷贝漏了它，`init.gree.rc`（daemon 的 `LD_PRELOAD libshim_mutex.so`）和 `camera/gree-camera.rc`（provider 的 override）也是旧的。三个文件补齐后重编通过。暂存目录里的 HAL、`libgu2.so`、两个 shim、JPEG 与 3A 库、`media_profiles_V1_0.xml`、两个 rc 和 CPP 固件都和手机上的 md5 一致，`build.prop` 里有两条 `ubwc=0`。
  - **7M**：见同日第二十七轮到同日第三十七轮。校准能完成，锁屏密码能写入。录入从剩余 9 次走到 0，模板 `featrue_0_0_1.dat` 对上编号 `1681692777`。锁屏正确手指 `onAuthenticated(true)`，错误手指 `onAuthenticated(false)`。空读不再报成传感器脏了。解锁之后芯片回到键模式。原来的 7G（相机和指纹只要求进程还在）作废。第三十六轮当时传感器没有写进 `config_biometric_sensors`，那次锁屏跳过了 `addAuthToken`。同日第三十七轮已写成 `0:2:15`，框架按强生物识别登记。

### 事件

2026-10-27：完成首次进桌面后的日志审计（排除末尾两次几秒的误开机，分析行 15160–34903 的桌面会话）：
- **已通过项**：
  1. 启动动画正常播放并平滑交接给 `SystemUI`；
  2. `LineageSetupWizard`、`Launcher3`（`QuickstepLauncher`）桌面与 `Settings` 正常显示，无横纹，180 度方向正确；
  3. Atmel `atmel_mxt_ts` 触摸在桌面与设置中全程响应正常（`init.atmel_ts.sh` 写入 `Gree2_4005_V2.06_20170223.raw` 返回 0，芯片 `config_csum` 保持 `53a963`）。
- **已修复并推入 `/system` 待重启验证项**：
  - 针对屏幕 ~2 FPS 刷新与滚动时半屏变黑闪烁，已更新 `gralloc.default.so`（32/64 位，改为 `ashmem` 缓存渲染 + `memcpy` + `FB_ACTIVATE_NOW | FB_ACTIVATE_FORCE`）与 `/vendor/etc/vintf/manifest.xml`；
  - 针对 USB 仅充电无 ADB，已在 `init.gree.rc` 配置 `6a00000.dwc3` ConfigFS gadget、改 `ro.adb.secure=0` 并清空旧 `persistent_properties`；
  - 针对背光与休眠唤醒，已编译并推入 `lights.msm8996.so` 与 `android.hardware.light@2.0-service`；
  - 针对 Wi-Fi，已提取 `qwlan30.bin`、`otp30.bin`、`bdwlan30.bin`、`utf30.bin`、`data.msc`、`wlan_mac.bin` 并在 TWRP 实测点亮 `wlan0`（`QCA6174_REV3_2`，MAC `[redacted]`），同时编译推入 `android.hardware.wifi@1.0-service` 与 `wpa_supplicant`。

同日稍后：重启进系统实测反馈与第二轮修复（含内核树推送及 Adreno 530 硬件加速构建）：
1. **内核树已推送 GitHub**：将移动硬盘 `/run/media/alpha/YMTC/g0215d/kernel-g0215d` 中未提交的 DT fstab 禁用改动（`arch/arm/boot/dts/qcom/g0215d-msm8996-v3-pmi8996-mtp.dts` 禁用 `firmware/android/fstab` 以避免第一阶段 init 卡在 AVB vbmeta/dtbo 挂载）提交为 `fb30a4238f1a` 并推送到 [`alpha-liu-01/android_kernel_gree_g0215d`](https://github.com/alpha-liu-01/android_kernel_gree_g0215d) 的 `g0215d` 分支。
2. **USB ADB 掉线根因修复**：确认开机初期 `adb devices` 能识别 `[redacted] device`，随后 `AdbService` 读取 `/data/property/persistent_properties` 中的旧值 `persist.sys.usb.config=mtp` 将 USB 切回仅 MTP（`18d1:4ee1`）；已在 `init.gree.rc` 增加属性拦截规则强制保持 `mtp,adb` 并写入 `adb_enabled=1`。
3. **屏幕撕裂完全消除 & Adreno 530 GPU 硬件加速（7B）合入**：`gralloc.default` 的 `ashmem` 离屏缓存合成彻底消除了双 DSI 扫描期的半屏黑闪；为解决 SwiftShader 1–5 FPS 软件渲染瓶颈，已集成格力原厂 `a530_zap.*` 签名固件 + Adreno 530 微码与 32/64 位 OpenGL ES 3.2 / Vulkan 1.0 驱动栈，并编译 `gralloc.msm8996`、`hwcomposer.msm8996`（SDM HWC2）、`memtrack.msm8996` 与配套 HIDL 服务。
4. **锁屏背光 2–3 秒重亮修复**：为 `init.gree.rc` 的 `service panel_hold` 加上 `oneshot` 并限制 `panel_hold.sh` 仅在开机完成前执行一次，根治锁屏后背光被循环拉回 180 的问题。
5. **设置 → 网络和互联网闪退修复**：在线抓取 crash 日志确认闪退原因为缺少 `/vendor/etc/permissions/android.hardware.wifi.xml` 导致 `WifiService` 未启动（`WifiEnabler` 空指针），已补齐全部硬件 feature 权限 XML 并重新打包生成 `system.img`。

同日第三轮实机验证（Adreno 530 满帧运行、Wi-Fi 连通与“前 4 下输入慢半拍”根治）：
1. **GPU/CPU/背光/ADB 全面验证通过**：`SurfaceFlinger` 已由 `Adreno (TM) 530, OpenGL ES 3.2 V@269.0` 硬件合成驱动，满帧 60 FPS；`msm-adreno-tz`（133–624 MHz）与 `schedutil`（小核 307–1593 MHz、大核 307–2150 MHz）调频器运行正常，锁屏背光保持 0 不再重亮，ADB 全程稳定在线。
2. **Wi-Fi 2.4G/5G 扫描与连接修复完成**：删除 `/vendor/etc/vintf/manifest/` 下与主 `manifest.xml` 冲突的重复 `android.hardware.wifi.supplicant.xml` 后，`IWifi@1.4` 与 `ISupplicant@1.3` 正常握手，实机已自动连上 5GHz Wi-Fi（`SSID: "Not 6GHz"`, `5765MHz`, `433Mbps`）。固件、`WCNSS_qcom_cfg.ini`、`wpa_supplicant` overlay、feature XML 与 HAL 软件包此前已在设备树里。真正漏进仓库的只有这一处 VINTF 冲突：主 `manifest.xml` 自己声明了 `android.hardware.wifi.supplicant`，HAL 软件包又再装一份 fragment。现已从本仓库和 18.1 树的 `manifest.xml` 中去掉 `ISupplicant`，下次编镜像时只保留软件包自带的 fragment。
3. **触摸输入“划 4 下才响应、随后完全流畅”的根因与在线根治**：定位到 `system/libhidl/transport/ServiceManagement.cpp` 在 `!kEnforceVintfManifest` 时对每次 `getRawServiceInternal()` 调用执行硬编码 `sleep(1)`（1000ms），导致 `LightsService`（按键灯/背光调节持有 `PowerManagerService` 锁）与 `Settings`（并发查询未注册的 `IDumpstateDevice`/`IPower`/`IBiometricsFingerprint`）反复将主线程与 `android.display` 阻塞数秒。源码改动在 18.1 平台树 `system/libhidl/transport/ServiceManagement.cpp`，不属于本设备仓库；32/64 位 `libhidlbase.so` 已热补丁进实机，并停用后台崩溃循环的 `com.android.bluetooth`。

同日第四轮：正面实体 Home 与两侧虚拟键全部失效。实体 Home 已能回到桌面。两侧电容键和 Buttons 页当时还没好，见下一轮。

同日第五轮：
1. **两侧电容键**：使用者确认中间实体 Home 正常，左右返回 / 最近任务没有反应。复测时 T15 CTRL 又是 `00`。只写 RAM 会被下一次 T6 复位冲掉，而 `update_cfg` 在文件 CRC 仍是 `53A963` 时判定配置已一致、整表不重写。现已把工厂 raw 的 T15 CTRL 改为 `03`，配置 CRC 记为 `63AA53`，实机 `config_csum` 为 `63aa53`，对象表 CTRL 保持 `03`。`keys_on` 读数是 `1`，驱动里的软件门是开的。
2. **Settings → System → Buttons**：lineage-sdk 默认 `config_deviceHardwareKeys=64`，页面不列出 Home / Back / 最近任务。设备树 overlay 与实机 RRO `org.lineageos.g0215d.buttons` 都把它和对应的唤醒位图改成 `83`。`cmd overlay lookup` 读到 `83`。Settings 进程已强制结束后台，重新打开该页即可。Back / 最近任务的熄屏唤醒要等 `system_server` 下次起来才吃到这份资源，也就是下一次重启之后。本机没有 `button-backlight`，所以没有加按键亮度条。

同日第六轮：电容键仍然没有反应。`logcat` 里没有任何 `KEY` / `BACK` / `APP_SWITCH`。当时 T15 CTRL 已是 `03`，阈值仍是工厂的 `50`，实体 Home 正常。把 T15 触摸阈值从 `50` 降到 `8` 并 `BACKUPNV`，芯片校验和变为 `a59c6e`，对应 raw 的配置 CRC 改为 `A59C6E`，避免下次开机 `update_cfg` 把阈值写回 `50`。阈值降到 `8` 时芯片不会自己误报，节点本身是安静的。整表 `update_cfg` 会把手机重启，单字节修改只走 `mem_access` 加 `BACKUPNV`。

同日第七轮：两侧电容键修好，根因是 GF816M 而不是 T15，细节见 7H。
1. **排除 T15**：T37 参考值和 delta 显示 T15 节点被扫描，但按住两侧键时没有信号。原厂 `tiny4412-key` 来自原厂 Goodix 指纹驱动。
2. **内核 `#19`**：新增 `gf816m_keys` 驱动，DTS 增加 SPI5 和 `goodix_fp@0`，pinctrl 补回 GPIO 81–84 的 `blsp_spi5`。`#18` 缺这几行 pinctrl，SPI 控制器报 `Can not set spi_default pins`。这一轮重编了内核，属于“本阶段不做”里的例外。内核改动提交为 `462326055766`，已推送到 [`alpha-liu-01/android_kernel_gree_g0215d`](https://github.com/alpha-liu-01/android_kernel_gree_g0215d) 的 `g0215d` 分支。
3. **boot 镜像**：`/run/media/alpha/YMTC/g0215d/boot-test/boot-gf816m.img`，13615104 字节，`sha256 2f96fb1117bafaa5bfb680de468a0b9bb212cd2ef39d7875ab7b9f480b59380d`。cmdline 和 ramdisk 沿用 `boot-debug4.img`，后者仍是回退用的镜像。刷写前先 `adb root`，`dd` 写 `/dev/block/by-name/boot` 后用 `head -c` 核对 sha256。
4. **撤回 T15 改动**：本仓库、18.1 设备树和实机 `/system` 都已恢复工厂 raw 和原来的 `init.atmel_ts.sh`，删掉 `atmel_tp_keys` 服务和 Atmel 按键 keylayout。芯片 T15 写回 CTRL `00`、阈值 `0x32` 并 `BACKUPNV`。重启后 `config_csum` 为 `53a963`，`gf816m_keys` 正常探测。

同日第八轮：7C 音频，扬声器、耳机、录音都已出声，细节见 7C。
1. **声卡注册**：ADSP 挂载点、`boot_adsp`、WSA 设为 0、TFA DT 节点和名字、primary MI2S 与 `asoc-cpu` 全表、删掉 HDMI 音频，这些改完后声卡注册了，但随后开机崩溃。使用者手动进 recovery，在 recovery 里先停掉 ADSP 自动启动，用带编号的日志行加手动触发 ADSP 找到两处崩溃（`rtd_aux` 越界、TFA 旧容器 index），修好后系统正常开机。
2. **出声**：`tinyplay` 有声而 Android 无声，原因是缺 `media_codecs.xml`。补上之后，再用 `libacdbloader` 垫片接通 ACDB。
3. **录音与耳机**：主麦改用 MIC BIAS4，`hphl-swh` 改为 1，`config_useDevInputEventForAudioJack` 打开。使用者确认录音和耳机正常，拔耳机时播放暂停。
4. **内核**：提交为 `79851a82f397` 并推送。boot 镜像是 `boot-audio9.img`，`sha256 16f5843ce7c406eb9951449ffc64c36bd1e18904c30d28ad548315bf4d9b6cee`。这一轮也重编了内核，属于“本阶段不做”里的例外。

同日第九轮：7D 蓝牙，开关、扫描、配对、A2DP 都能用，细节见 7D。没有动内核和 boot。
1. **HAL 与厂商库**：AOSP `android.hardware.bluetooth@1.0` 加平台树里的 `libbt-vendor`（Rome 固件下载在里面），再加原厂 64 位 `wcnss_filter`。蓝牙 App 从停用恢复。
2. **`/bt_firmware`**：根是只读的 system 镜像，启动时 `symlink` 失败。改成 `BOARD_ROOT_EXTRA_SYMLINKS`，并为它补 `file_contexts` 标签，否则整镜像的 `e2fsdroid` 过不去。
3. **蓝牙地址**：AOSP HAL 没有地址就 abort。把 TWRP 备份里原厂的 `[redacted]` 放进 `bluetooth/bdaddr`。
4. **A2DP**：蓝牙音频 HAL 2.0 加 `audio.bluetooth.default`，policy 引入 `bluetooth_audio_policy_configuration.xml`。使用者确认只从蓝牙耳机出声，开机头一分钟有爆音，之后干净。
5. **整镜像**：`system-7d.img` 编出来了，`sha256 fed6b2584e1729b76bd9fa5a7fc20b1eef1dd2b3aca44d5a33d8b62822bb59f6`，没有刷。

同日第十轮：7F 双卡 RIL 与移动数据，Fizz 卡识别、驻网、蜂窝数据通，细节见 7F。没有动内核和 boot。
1. **电话栈**：用原厂 Android 6 的 `qmuxd`、`netmgrd`、`rmt_storage`、`tftp_server`、`time_daemon`、QCRIL 和 QMI 库，放在设备树 `radio/`。两个 `rild`（`slot1`、`slot2`）加 `libril`（不带 `SIM_COUNT=2`）。
2. **基带启动**：自己写 `libperipheral_client` 替代原厂 `pm-service`、`pm-proxy`（Binder 虚表和 A11 不兼容），打开 `/dev/subsys_modem` 让基带起来。补了 `AudioSystem::setErrorCallback` 的空实现。
3. **补丁与挂载**：`cntpct_el0` 改 `cntvct_el0`（`time_daemon`、`libtime_genoff`）；`/persist`、`/firmware` 用 `BOARD_ROOT_EXTRA_SYMLINKS`；`/system/rfs` 符号链接树在编译时生成。
4. **事故**：第一次推送时 `chmod 644` 把 `lib64/hw` 目录改成 644，开机黑屏无背光红灯。在 recovery 里把目录改回 755 恢复。
5. **平台树冲突**：`ipacm`、`librmnetctl` 等六个原厂副本和平台树模块撞车，改用平台树版本；平台树 `ipacm` 起不来，用 `override` 加 `disabled` 关掉。三份 `data/*.xml` 的声明挪到第一行才能过 `xmllint`。
6. **实机**：驻网 `Fizz EXT`（`302610`），关 Wi-Fi 后蜂窝数据通。数据一开始是关的，原因是漫游设置，在设置里打开数据漫游即可。
7. **整镜像**：`system-7f.img` 编出来了，`sha256 654350620fc2703678e913fd219d6c62c375443854ec343b60ef47dba036375f`，没有刷。
8. **遗留**：通话、短信、VoLTE、SIM2、LTE 没测；`netmgrd` 偶发 Scudo abort（init 会重启它）；7E 传感器仍然跳过。

同日第十一轮：7F 补记，通话没有声音的修复，通话后回 LTE 的结论，细节见 7F 补记。没有动内核和 boot。
1. **语音会话**：`BoardConfig.mk` 打开 `AUDIO_FEATURE_ENABLED_MULTI_VOICE_SESSIONS`，HAL 才会按 QCRIL 的 `call_state`/`vsid` 起 `voicemmode1-call`，而不是传统的 CS-Voice。
2. **ADSP 拒绝 topology commit**：`0x13198` 返回 `ADSP_EFAILED`，会话建不起来但电话照常接通，所以"通了没声音"。用 `Voice Topology Disable`（`numid 7`，不是 6）让 vocproc 用 NONE 拓扑，听筒两个方向有声。放进 `mixer_paths_tasha.xml` 的 `voicemmode{1,2}-no-topology`，每次通话开始时由 `audio_route` 写。代价是没有回声消除和降噪。
3. **免提**：扬声器是 `QUAT_MI2S_RX` 上的 TFA9890，`SND_DEVICE_OUT_VOICE_SPEAKER` 之前走了默认的 `SLIMBUS_0_RX`。`audio_platform_info.xml` 加 `quat_mi2s_rx_voice` 后端，`mixer_paths_tasha.xml` 加空 path `voice-speaker quat_mi2s_rx_voice`。使用者确认免提和听筒两个方向都正常。
4. **通话后停在 3G**：量了一次：挂断后约 3 分 10 秒自己回 LTE，回的是家网 `Fizz`，不是 `Fizz EXT`。RIL 没有发任何选网请求，QCRIL 没有对应属性，基带里没有加拿大 MBN。没有改任何东西，原因和可选缓解写在 7F 补记里。
5. **踩坑**：`ctlw 6` 写的是 `Slowtalk Enable`，`numid` = `tinymix` 序号 + 1。已经写回。
6. **清理**：回退 `q6voice.c` 的临时 `DEBUG`；真正的 `libacdbloader.so` 已还原；`system-7f2.img` 已编，没有刷；手机需要刷回 `boot-audio9.img`。

同日第十二轮：7E 传感器，冷启动后五颗芯片都在，并且已经有事件，细节见 7E。没有动内核和 boot，没有刷 persist。
1. **SLPI**：固件在 modem 分区。写 `1` 到 `/sys/kernel/boot_slpi/boot` 才上线。写 `0` 会把手机重启，脚本里只写 `1`。
2. **用户态**：原厂 `sensors.qcom` + `sensors.ssc.so`，multihal 改名为 `sensors.qcom.so` 并改读 `/vendor/etc/sensors/hals.conf`。HIDL 1.0。`liblocationservice` 用返回空指针的桩，不把 GPS 拖进来。
3. **`/persist`**：守护进程拒绝符号链接。7F 的 symlink 改成空目录，`post-fs` 再 bind mount。`sns.reg` 还是原来那份。
4. **顺序和权限**：先打开 `sns.reg`，再加载 SLPI，等 QCCI 探测结束再起 HAL，并且赶在 zygote 之前，这样 `SensorService` 拿到的不是空列表。`sec_config` 要求 gid 3011（这套系统里叫 `uhid`），init 服务的 `group` 加上它。不然内核报 `permission failure for sensors.qcom`。
5. **实机**：冷启动 `dumpsys` 看到 BMI160 加速度和陀螺、AK09915、RPR0521 光和接近、LPS22HB、SHTC1 湿度和温度，共 46 个传感器，已经有事件。
6. **整镜像**：`system-7e.img` 编出来了，`sha256 ff6a9a6bda215bc03465848c50a51641fb28cd9bd29bc2461e74b2f050d25ea0`，没有刷。镜像里 `/persist` 是目录。

同日第十三轮：收口标准从「桌面可交互」改成「18.1 可以日常使用，然后才进入阶段 4」。没有改代码，也没有刷机。
1. **已通过的交互项**留在原处，不再重做。
2. **剩余顺序**：7I USB 功能切换，7J 振动，7K 硬件视频和音频编解码，7L 相机出图，7M 指纹解锁。7K 不过就不开始 7L。
3. **从阶段 5 挪回来的**：前后摄拍照、短视频、指纹录入与解锁。阶段 5 只在新平台上复查，不再是第一次做这些功能的地方。
4. **不挡住收口**：短信、VoLTE、第二张卡、回声消除、蓝牙耳机通话、NFC、红外、FM、SELinux enforcing、TWRP 的振动。

同日第十四轮：7I USB 功能切换，文件传输双向已通过，PTP、MIDI、网络共享都能枚举，细节见 7I。没有动内核和 boot。
1. **灰掉的原因**：没有端口 HAL。`dumpsys` 的 `port_manager` 是空的，设置就把功能禁用。不是 7A 那组 `persist.sys.usb.config` 回写造成的，那组回写已经去掉。
2. **HAL**：`android.hardware.usb@1.0-service.gree` 按 `extcon0` 的 `USB=1` 报 UFP / device / sink。`supportedModes` 和当前模式一致，否则框架把端口清成未连接。
3. **实机**：MTP 双向拷过文件。PTP 是 Still Image，MIDI 是 `4ee9`，RNDIS 在主机上拉起过网卡。解锁后的默认功能设成 `mtp`。
4. **整镜像**：`system-7i.img` 编出来了，`sha256 f0f7f7f0a0f1f351ccff69a870e86420326685a5f514d79751b68b4c0a038cc2`，没有刷。

同日第十五轮：7J 振动。DRV2605 v1.1 已绑定，`cmd vibrator vibrate 400` 记进了 Vibrator Service，细节见 7J。重编了内核，boot 是 `boot-vibe.img`，已刷。
1. **内核**：原来的 `drv2604` 驱动不认设备树，使能脚写死 93，并且拒绝 DRV2605。DTS 补上 `haptics@5a`，使能改读 GPIO 74。
2. **用户态**：`android.hardware.vibrator@1.0-service` 加 `vibrator.default`，写 `/sys/class/timed_output/vibrator/enable`。
3. **实机**：状态寄存器 `0x64`，额定电压 `0x16` 读回 `0x30`。sysfs 写 500 会倒计时到 0。`vendor.vibrator-1-0` 冷启动自己起来。
4. **镜像**：`boot-vibe.img`，`sha256 a2fa42abeff5704f6bb731e3198e5646deff1733baf738cef930b9cb1c347c8f`，已刷。`system-7j.img` 编出来了，`sha256 399ef63dde9b47666c0789388145b92efd6440b5292278eb4452ae1aedf6629a`，没有刷。内核改动还没提交。

同日第六十八轮：按第六十七轮能听的系统重新打了刷机包。没有刷进手机，没有格式化 data。

1. **包**。`/run/media/alpha/YMTC/g0215d/boot-test/lineage-18.1-20261029-UNOFFICIAL-g0215d.zip`，1799064037 字节，`sha256 e539fe99fa194d9825b8ce969d1ad9c9522d3c6b7d2f6bf7507370efaf302dec`。只含 boot 和 system。`boot.img` 仍是手机上的 `boot-nfc.img`，`sha256 d8648cbfb9b7d92a3dda3794bcb0880d6887c8e5890b558defba77726a240c15`。没有 recovery。安装脚本和第五十八轮一样。
2. **里面有什么**。`/vendor/ueventd.rc` 里 `/dev/radio0` 是 `0660 system media`。`FM2` 带 `ACCESS_BROADCAST_RADIO`，`libqcomfm_jni.so` 用读写方式打开节点。第六十六轮那份打不开收音机，改名为 `lineage-18.1-20261029-UNOFFICIAL-g0215d.fm-open-fail.zip`，哈希仍是 `7db3427cd1a3b1c4969a8b2acb42db499615f75b6e41d5dd01588d41bbc687fd`。

同日第六十七轮：`FM2` 打开收音机失败。应用自己打开 `/dev/radio0` 被拒绝。没有重编内核，没有格式化 data，没有打电话。使用者确认修好了。

1. **日志**。`FmTransceiver: Fail to Open -1`。节点是 `crw-r----- system system`。应用是 `u0_a157`，不在 `system` 组。`open` 失败，后面的上电和调台都没走到。`fm_helium.so` 找不到是预期的：`vendor.qcom.bluetooth.soc` 是 `rome`，走 V4L，不走 iris。
2. **修复**。`ueventd` 把 `/dev/radio0` 改成 `0660 system media`。`FM2` 加上 `ACCESS_BROADCAST_RADIO`，这个权限对应 `media` 组（gid 1013），平台签名直接授予。JNI 改成 `O_RDWR`，只读打开时 `VIDIOC_S_CTRL` 会被拒绝。手机上的库、apk 和 `ueventd.rc` 已经换上，节点现在是 `system:media` `0660`。
3. **实机**。进程组里有 `1013`。`Opened 59`，`turning on 1`，`tuneRadio: 98.1`，回调频率 `98100`。`handle_fm=1048580`，日志是 `Route audio to WiredHeadset`。使用者确认能听，第 8 项记成做完。

同日第六十六轮：TWRP fork 和内核树已经推到 GitHub。新的刷机包带上 FM 应用。没有刷进手机，没有格式化 data，没有打电话。

1. **仓库**。TWRP 是 `android_bootable_recovery` 的 `android-11-g0215d`。打包时 `libapplypatch` 编不过：包含了用不到的 `bmlutils` 和 `mtdutils`，校验读回的循环也被截断了。补上之后是 `01e32e96`。没有对 TeamWin 开 PR。内核是 `android_kernel_gree_g0215d` 的 `g0215d`，`281678a8c263`，红外、Si4705 和 PN547 都在里面。`out/` 没有提交。
2. **包**。当时写到 `/run/media/alpha/YMTC/g0215d/boot-test/lineage-18.1-20261029-UNOFFICIAL-g0215d.zip`，1799064037 字节，`sha256 7db3427cd1a3b1c4969a8b2acb42db499615f75b6e41d5dd01588d41bbc687fd`。第六十八轮把这个文件改名为 `lineage-18.1-20261029-UNOFFICIAL-g0215d.fm-open-fail.zip`。只含 boot 和 system。`boot.img` 就是手机上的 `boot-nfc.img`，13713408 字节，`sha256 d8648cbfb9b7d92a3dda3794bcb0880d6887c8e5890b558defba77726a240c15`。没有 recovery，不会换掉 TWRP 3.7.0_11。不写 aboot、tz、rpm、hyp、cmnlib、keymaster、modemst、fsg、persist。安装脚本和第五十八轮一样：`dd` boot，`simg2img` system。第五十八轮那份 boot 是 `boot-fp8.img`，不要再刷那一份。
3. **FM**。`FM2`（`com.caf.fmradio`）在镜像的 `/system/system_ext/app/FM2/FM2.apk`，1496390 字节。`qcom.fmradio.jar` 在 `/system/framework`，`libqcomfm_jni.so` 在 `system_ext`。`vendor.qcom.bluetooth.soc` 仍是 `rome`，走 `/dev/radio0`，没有打 `fm_helium`，没有设 `BOARD_HAVE_QCOM_FM`。手机上还是旧的 system，要刷这个包桌面才有应用。第 8 项先不记成做完。
4. **NFC**。读卡还没测。第 9 项不记成做完。设备树里加上 FM 包和 `/file_contexts.bin` 的标签这两处还没提交。

同日第六十五轮：`ims_rtp_daemon` 不再吃满一颗核。进程仍是 `system`，QMI 服务还在。没有格式化 data，没有打电话。

1. **原因**。内核的 IPC router 只允许带 `CAP_NET_RAW` 或 `CAP_NET_BIND_SERVICE` 的进程 `bind`。这个服务原来以 `system` 跑，没有这两项能力，`dmesg` 是 `msm_ipc_router_bind: ims_rtp_daemon Do not have permissions`。`bind` 失败后两个 `AF_MSM_IPC` 套接字被关掉，描述符号被 `/dev/hwbinder` 和 `trace_marker` 复用。QMI 线程的 `select` 仍盯着 7 和 8，这两个描述符一直可读，于是空转。`imsrcsd` 不走这条服务器注册，所以是闲的。关掉调试日志停不了这个循环。
2. **修复**。`vendor.gree.radio.rc` 给 `vendor.ims_rtp_daemon` 加了 `capabilities NET_BIND_SERVICE`。没有改成 root。`vendor.imsdatadaemon` 本来就是 root，因为它自己会降到 `system`。init 要重启才读 rc，所以重启了一次。
3. **实机**。重启后 uid 1000，`CapEff` 是 `0x400`（`CAP_NET_BIND_SERVICE`）。描述符 7 和 8 是套接字，不再是 hwbinder。两秒内 CPU tick 增量是 0。这次开机的 `dmesg` 没有新的 permission 行。Wi-Fi 重新关联。

同日第六十四轮：NFC 设置页的卡顿已经消失。这一次 `NfcNci`（pid 8502）的日志里没有错误、没有 `Watchdog`、没有 `INVALID_PARAM`、也没有 HCI 注册失败。读卡还没人贴过，第 9 项先不记成做完。没有格式化 data，没有打电话，没有重启。`dumpsys nfc` 会和路由看门狗抢同一把锁，不要用。

1. **设置页**。PN547 是 NCI 1.0。屏幕解锁时 `ApplyRoutingTask` 拿着 `NfcService` 的锁发 `RF_DISCOVER`。原来的 `POLLING_TECH_MASK=0x6F` 带上 ISO15693、Kovio 和主动 P2P，`P2P_LISTEN_TECH_MASK=0x45` 再带主动监听。芯片回 `41 03 01 09`（`STATUS_INVALID_PARAM`）。协议栈不发发现开始事件，`startRfDiscovery` 一直等，10 秒后看门狗 `doAbort`，进程 `SIGABRT`，大约每 11 秒一次。设置主线程调 `NfcAdapter.isEnabled`，binder 死了就卡住，蓝牙那一页也问 NFC，所以两个界面一起顿。改成 `POLLING_TECH_MASK=0x07`（A/B/F）和 `P2P_LISTEN_TECH_MASK=0x05`（监听 A/F）之后，发现命令是 `21 03 0B 05 00 01 01 01 02 01 80 01 82 01`，应答 `41 03 01 00`。使用者确认 NFC 页面不再卡。`libnfc_nci_jni.so` 里这次等待加上 3 秒超时，以后再被拒绝也不会把设置冻住。`NFC_DEBUG_ENABLED=0`。
2. **这次日志**。芯片仍是 PN547C2，固件 `8.1.26`，和 `libpn547_fw.so` 一致，没有刷固件。`NFA_DM_ENABLE_EVT` 成功。待机时 I2C 回 `0x1ff`、日志写 `Maybe in Standby Mode`，HAL 会重试，这不是故障。`EseAdaptation` 找不到 eSE HAL 是预期的。
3. **调试项**。相机 `persist.camera.global.debug`、`persist.camera.sensor.debug`、`persist.camera.mm-camera` 改成 0。`log.tag.NxpHal` 和 `log.tag.APM_AudioPolicyManager` 改成 `INFO`，后两个不带 `persist`，重启后回到默认。`wpa_supplicant` 的 `-dd` 从 `android.hardware.wifi.supplicant-service.rc` 去掉了，源码和手机上的 rc 都是。init 要重启才重读 rc；当时在跑的进程是去掉 `-dd` 的那份，Wi-Fi 已经重新关联（`COMPLETED`）。重启之后 rc 不再带 `-dd`。在重启之前如果把 Wi-Fi 开关一次，内存里的旧服务定义还会带上 `-dd`。`/data/local/tmp` 里的 boot 和 recovery 镜像删了，目录从大约 458MB 降到 17MB，剩下的是 `radio_push`。tombstone、ANR、dropbox，以及 `/cache/boot-kmsg.txt`、`phase2-dmesg.txt`、`boot-debug-marker` 删了。`/cache` 里那份原厂 boot 压缩包、`/data/fbe-before`、`/data/fbe-staging` 留着。
4. **还在占的一颗核**。`persist.vendor.ims.disableDebugLogs`、`disableADBLogs`、`disableIMSLogs`、`disableDebugDataPathLogs`、`disableQXDMLogs` 都设成 1 之后，`Modem version could not be determined` 不再刷日志。`ims_rtp_daemon` 仍大约每秒 100 个 tick，就是一颗核。烧的是 `ims_rtp_qmi_handler_thread_func`：`select` 的超时是空指针，返回值不看，接着 `qmi_csi_handle_event`，描述符一直可读，所以马上返回。`imsrcsd` 是闲的。树里没有这份源码。进程没有停，它是 VoLTE 的 RTP 路径，IMS 还没做完。没有把 `vendor.qti.hardware.radio.ims` 写进 manifest。

同日第六十三轮：指纹。第一次对不上之后，后面按上去不再振动、也不再识别。熄屏再亮没用。使用者确认修好了。没有删模板，没有改图案，没有动电容按键那条路径。没有重编内核。

1. **现象**。Goodix GF816M。比对失败时守护进程 `gx_MatchCancel`，把芯片设成按键模式（`Set mode:1`）。框架的 `AuthenticationClient` 还留着，等下一张图。下一帧中断是 `Signal in NAV`，不是指纹图，所以不振、也不扫。用图案解开会发 `ERROR_CANCELED`，会话才重新开始。
2. **修复**。`fid == 0` 时先把 `onAuthenticated(false)` 交上去。回调还在厂商 HAL 的栈上，芯片刚切回按键模式，所以另起一个线程，等 100 ms，再直接调 `mDevice->authenticate`。`mAuthActive` 已经清掉，或者 `mAuthGeneration` 变了，就不再打开。成功和 `cancel()` 都会清掉 `mAuthActive` 并加一代。`cancel()` 拿着设备锁改标志再调 `cancel`。重新打开如果返回非 0，先静默 `mDevice->cancel`（不走 `BiometricsFingerprint::cancel`），再试一次。通知回调不拿设备锁。
3. **镜像**。`/vendor/bin/hw/android.hardware.biometrics.fingerprint@2.0-service`，`sha256 c09c35f8e8cf218e5725ec5a8d76fe797592d9b762bd16f09a91a553a86da694`。源码在 18.1 树的 `hardware/lineage/interfaces/biometrics/fingerprint/2.0/BiometricsFingerprint.cpp`。不在认证会话里时，电容键仍走原来的按键模式。

同日第六十二轮：FM 收音机。有线耳机当地线，102.1 是干净的台，音量键能调。没有格式化 data，没有打电话，没有改语音拓扑，没有写 numid 6。内核是 `#48`，已经在手机上。调试进程已经停掉，芯片断电，环回音量是 0。图形界面还没有。

1. **芯片**。不是高通内部的 iris。Silicon Labs Si4705 在 `i2c@75b5000`（`i2c_7`），地址 `0x11`。复位 GPIO 39，中断 GPIO 38，状态 GPIO 78。状态脚已经被 `msm-dai-tdm-tert-rx` 占着，pinctrl 选不上，驱动仍建出 `/dev/radio0`。供电使能是 GPIO 14，驱动在上电时拉高。数字模式，48 kHz。天线输入保持 0；写成 1 时全波段 RSSI 都是 0。耳机是天线，插孔是 Wired Headphones（设备 4），不是带麦的 headset。
2. **声音**。数字音频走 tertiary MI2S，SoC 做主设备。时钟 GPIO 75、76，数据 GPIO 77。`AUDIO_FEATURE_ENABLED_FM_POWER_OPT` 打开之后，HAL 的 `handle_fm=1048580` 走 `play-fm headphones`：Tertiary MI2S 环回到 SLIMBUS 6，再进耳机。`fm_volume` 写 `Tert MI2S LOOPBACK Volume`，范围 0–8192。一开始写成 1.0，混音器是 8192，耳机只能摘下来听。
3. **音量**。这条环回不在 AudioFlinger 的音轨里，音量键当时改的是铃声音量。`libaudioflinger` 在 `STREAM_MUSIC` 的音量写完、放开锁之后，把已经走过曲线的线性增益交给 HAL 的 `fm_volume`。非有限值丢掉。`fmroute listen` 先按当前媒体音量设增益，再占一条静音的 `STREAM_MUSIC`，音量键才落到媒体流上。实测 122、194、122，使用者确认能调。最大一档仍是 8192。
4. **镜像**。内核 `#48`，`4.4.302-perf+`，`Wed Oct 28 20:15:47 EDT 2026`。`Image.gz-dtb` 12866491 字节，`sha256 9a8f41edc3c90efe66f784d15bfb62f53b03e843d3f89ecaf38916dc9ae202ad`。`boot-fm.img` 13709312 字节，`sha256 ca039132edbb5e9e481be9621058a1de67854fa2f0aa73cfcec540d7424aa2f9`，已写入 boot，读回哈希一致。`#47` 的 `boot-ir4.img` 没有覆盖。HAL、`libaudioflinger`、`fmtune`、`fmroute` 是推上去的，没有重编整份 system。内核改动还没推。
5. **应用**。Lineage 的 `packages/apps/FMRadio` 是联发科 JNI，不打开 `/dev/radio0`。树里的高通 `FM2`（`com.caf.fmradio`）通过 `libfmjni` 打开这个节点，音量也走 `fm_volume`。整组 `BOARD_HAVE_QCOM_FM` 还会带上 iris 的 `fm_helium`，这块板子没有那颗芯片。应用还没打包。

同日第六十一轮：红外。海信 Roku 电视用小米遥控器里海信的第 16 套配置打开了。内核是已经在跑的 `#47`，这一轮没有重编内核。没有格式化 data，没有打电话。原厂 `com.gree.irremote` 没有装。学习还没做。

1. **不是脉冲发生器**。发射管后面是 I2C 从设备，兼容串 `raon,remote-ctrl`，地址 `0x50`，总线是 `i2c@75b6000`（这棵树的 `i2c_8`），时钟 400 kHz。使能是 GPIO 50，init 是 GPIO 126，复位是 GPIO 148。I2C 的数据和时钟是 GPIO 6、GPIO 7。`write()` 把一包字节交给芯片，载波和脉冲由芯片产生。Consumer IR 的图案是微秒，不能当成 GPIO 波形打出去。原厂在 `ConsumerIrManager.transmit` 里把图案打成这个包，再写 `/dev/remote_ctrl_dev`。18.1 不改 framework，由 `consumerir.qcom` 做同样的打包。`ro.hardware=qcom`，库是 `consumerir.qcom.so`。节点权限 `0660 system system`。
2. **包**。`pkt[0]` 是 0。`pkt[1..3]` 是载波频率的 24 位大端。后面每个时长一个大端 `u16`。250 字节一块：`unit[0]` 是包号，`unit[1]` 是这块字节数加 2，接着是数据。校验和从包号算起，加上 `unit[1]` 到 `unit[num+1]`，大端放在末尾两字节。写入长度是 `num+4`。最后一块刚好 250 字节时再写 4 字节尾包。每次写入之前把 init 拉低 10 ms 再拉高 10 ms。
3. **总线**。152 字节走 DMA 会报 `OVER_UNDER_RUN`。`i2c_8` 加了 `qcom,disable-dma`，长包走 BLOCK，振动的短写仍走 FIFO。芯片还在发上一帧时，短包会马上 NACK，长包则把控制器等到超时，复位时把正在发的码掐断。`I2C_MSM_TIMEOUT_MIN_USEC` 从 500 ms 改成 3 s，超时不再重试。
4. **时间单位**。芯片把每个 `u16` 当成载波周期数，不是微秒。9000 微秒在 38 kHz 下会被当成 9000 个周期，一帧拉长约 25 倍，电视解不出，摄像头仍能看到红光。换算是 `周期 = 微秒 × 频率 / 1000000`。频率收到原厂那六档：30000、33000、36000、38000、40000、56000。海信这条数据库里是 37910，收成 38000。写完之后 HAL 再等这一帧的微秒数加 80 ms，下一发才开始。
5. **实机**。19:48:43，`miir` 打了 `send key: power`。HAL 是 `carrier 38000 Hz, 72 pulses, 218000 us, first 343 cycles`。内核是 `tx len=152 00 96 00 00 94 70 01 57`，接着 `i2c_master_send=152 success`，大约 7 ms。这次按下没有 `TIMEOUT_ERROR`。`00 96` 是包号 0、长度 150。`00 00 94 70` 是 38000 Hz。`01 57` 是 343 个周期，对应原来的 9037 微秒引导头。使用者确认电视开了。修之前同一条是 `00 96 00 00 94 16 23 4d`：37910 Hz，9037 被当成周期数。
6. **镜像**。内核 `#47`，`4.4.302-perf+`，`Wed Oct 28 19:23:05 EDT 2026`。`Image.gz-dtb` 12782599 字节，`sha256 b90214cd4964da18376957912e4dc982329fabb5f2acf981321dc73aa290ce18`。`boot-ir4.img` 13623296 字节，`sha256 da58ebb0b0ca9c7736de0666eb15024f7e09dc8954aa413ff69a59528f451de9`，这一轮之前已经在手机上。这一轮只换了 HAL。`/vendor/lib64/hw/consumerir.qcom.so` 11520 字节，`sha256 42c530f33266184899890c61de96b56b5fd16fa388e345fe664cbdaf8e848820`。32 位那份 8108 字节，`sha256 98afd5ed4fe6a0cfee6db6f4a53869e923980045d9487eff7a7b7ea010cceeb6`。没有重编整份 system。源码在本仓库和 18.1 树的 `consumerir/consumerir.c`。内核改动还没推。
7. **学习**。接收仍要原厂那套私有接口：先写 `{0x11,0x11,0xee,0xee}`，再把 init 设成输入。取消是 `{0x69,0x69,0x96,0x96}`。Consumer IR 没有这条接收路径。原厂 `com.gree.irremote` 没有装。

同日第六十轮：TWRP 解开已经加密的 data。图案页打开，画一次之后日志是 `User 0 Decrypted Successfully` 和 `Data successfully decrypted`。`/data/system` 与 `/data/media/0` 都是明文目录名。没有格式化 data，没有打电话。恢复内核用的是已经编好的 `#44`，这一轮没有再编内核。

1. **第五十九轮的镜像解不开**。那一份编的时候 data 还没加密。加密打开之后，它能挂上 ext4，目录名能看，文件内容仍是密文，也不弹出图案页。ramdisk 里只有 keymaster 的客户端库，没有服务程序，`hwservicemanager` 找不到 `IKeymasterDevice/default`。4.4 的 recovery init 不会建名为 `fscrypt` 的 session keyring，`installKeyLegacy` 报 `Required key not available`。`CONFIG_EXT4_FS_ICE_ENCRYPTION` 让 `ext4_is_ice_enabled()` 恒为 1，读路径跳过软件解密；密钥装上之后，version 文件首字节仍是密文 `0xf8`，明文应是 `0x31`。`Decrypt_DE` 只重试 3 次、每次 2 ms，keymaster 还没注册。DE 解开时又把 `TW_IS_ENCRYPTED` 清成 0，图案页被跳过。
2. **读路径**。内核 `#44`（`4.4.302-perf+`，`Wed Oct 28 17:17:18 EDT 2026`）在 `fs/ext4/readpage.c` 和 `fs/ext4/inode.c` 里只在 `ext4_using_hardware_encryption(inode)` 时跳过解密。v1 策略的内容模式是 AES-256-XTS，要走软件解密。`Image.gz-dtb` 12777006 字节，`sha256 0a0dafa68df4188dade1509858234436086c375140b906e5a41f0423e26d69dc`。boot 和这份 recovery 都用它。文件名解密走另一条路径，所以目录名可以是明文，文件内容仍是密文。
3. **密钥和图案页**。`BoardConfig.mk` 把 `libkeymaster4.so`、`libpuresoftkeymasterdevice.so` 放进 ramdisk。`/vendor` 是指向 `/system/vendor` 的绝对符号链接，按 vendor 路径去拷会写到主机上，所以用 `BOARD_RECOVERY_IMAGE_PREPARE =` 把 keymaster 和 software gatekeeper 拷进 `system/vendor/bin/hw`。这里必须是 `=`：`:=` 在解析 BoardConfig 时把输出目录展开成空的。`init.recovery.qcom.rc` 在 `on init` 里启动这两个服务。`KeyUtil.cpp` 的 `fscryptKeyring()` 在 session keyring 里没有 `fscrypt` 时自己 `add_key`。`Decrypt_FBE_DE` 改成 50 次、每次 100 ms。DE 成功之后，只有密码类型是 0 才清 `TW_IS_ENCRYPTED`。图案的类型是 2。rc 和 BoardConfig 在本仓库。keyring、重试和图案页在 18.1 的 `bootable/recovery`，`repo sync` 可能冲掉。
4. **keystore**。补上服务之后图案页能开。第一次画立刻失败，日志是 `failed to get gatekeeper service`，gatekeeper 当时还没注册。第二次已经走到 `using secdis`，写出 69 字节的 `/auth_token`，接着 `ctl.start keystore` 返回 `0x20`：init 里没有这个服务，界面停在尝试中约 50 秒。这一版加上 `service keystore /system/bin/keystore /tmp/misc/keystore`（root）和 `service keystore_auth`（`user system`，oneshot），并在 `on init` 里启动 gatekeeper。keystore 拒绝 root 提交的 auth token，所以 auth 进程是 system 用户。等 `/auth_token` 被删掉的时间从 100 ms 放宽到最多 5 秒。只有软件 keymaster 时，keystore 会把它当作 `TRUSTED_ENVIRONMENT`。单独 `start keystore` 能停在运行。
5. **实机**。镜像 28737536 字节，`sha256 a4151492c0ea16b1fbf54166d6a0a682d50fd2a923fee34920c455ee17b6a684`，副本在 `g0215d/boot-test/recovery-twrp-fbe.img`。已写入 recovery，读回前 28737536 字节哈希一致。`uname` 是 `#44`，`ro.twrp.version` 是 `3.7.0_11-g0215d`，display id 是 `lineage_g0215d-userdebug 11 RQ3A.211001.001 eng.alpha.20261028.142903 test-keys`。开机时 `vendor.keymaster-4-0` 和 `vendor.gatekeeper-1-0` 都是 running。`ro.crypto.state=encrypted`，`ro.crypto.type=file`。用户画了一次原来的图案。日志顺序是 `password type: pattern`、handle `[redacted]`、`using secdis`、`Starting keystore...`、`Starting keystore_auth service...`、`spblob v2 / v3`、`User 0 Decrypted Successfully!`、`Data successfully decrypted`。分区标志里同时有 `Is_Encrypted` 和 `Is_Decrypted`。`/data/system` 能看到 `locksettings.db` 一类的名字，`/data/media/0` 能看到 `Alarms`、`DCIM`、`Download`、`Pictures`。`DCIM` 是空目录。更早一次失败的 prepare 已经删掉原来的照片和应用私有数据，这一轮没有把它们找回来。data 用量仍是 1098MB，空闲 54271MB。`/data/misc/vold/user_keys/de/0/version` 读出来是 `0x31`。没有格式化 data。第五十九轮那份镜像 `sha256 e25e7084b3b671c3c26f5d6578efd2f21a10b48b6eff6b1dbecceed1aeca3dd2` 还在 `recovery-twrp-3.7.img`。2016 年的 `device-backup/recovery.img` 也还在。
6. **和第 6 项的关系**。TWRP 用的图案在 `/data/system_de/0/spblob`，handle 是 `[redacted]`。桌面为了走出 logo，删过 `locksettings` 里的 `sp-handle`，所以系统现在不再问这组图案。`spblob` 没有删。第 6 项还没做完。

同日第五十九轮：TWRP 3.7.0_11。能挂上未加密的 data，认 system-as-root，刷过第五十八轮的包。没有格式化 data，没有打开加密，没有打电话，没有重编内核。

1. **选哪一份**。用 TeamWin `android-11` 分支的 3.7.0_11（`8bd48201c3ed825a0acecc0e6dcf125449ab1ec2`，版本串 `3.7.0_11`）。OrangeFox R11 是这套 TWRP 的皮，解不了更多。更新的 R12 对着 Android 12 的 keystore 和更新的内核。Lineage Recovery 不能按 TWRP 的方式备份 data。`#17` 那份 4.4 内核不读当年 3.18 的 ICE 加密盘，这一份也不读。
2. **加密方案**。下一项用 ext4 文件加密 policy v1：内容 `aes-256-xts`，文件名 `aes-256-cts`，legacy session keyring（`installKeyLegacy`）。recovery 的 data 行是 `fileencryption=aes-256-xts:aes-256-cts:v1`，没有 footer，也没有 `length=-16384`。内核有 `CONFIG_EXT4_ENCRYPTION`，没有 `CONFIG_FS_ENCRYPTION`，没有 `FS_IOC_ADD_ENCRYPTION_KEY`，软件 keymaster 也写不了 ICE 的 keyslot，所以不用 metadata encryption，也不用 `fileencryption=ice`。`TW_INCLUDE_CRYPTO` 链上了 `libtwrpfscrypt`，`TW_USE_FSCRYPT_POLICY=1`。ramdisk 里有 keymaster 4.0 和 `libsoftkeymasterdevice`。没有 Titan M 的 `libnos`。实机 `ro.crypto.state` 仍是 `unencrypted`。密码解密要等第 6 项把盘加密之后才能验。软件 keymaster 的密钥在 `/data` 里，加密打开之后可能先要解盘才能读到密钥。
3. **构建**。18.1 树里的 `bootable/recovery` 换成 TeamWin 这份。原来的 AOSP recovery 挪到 `/run/media/alpha/YMTC/g0215d/recovery-lineage-aosp`。以后 `repo sync` 可能把它换回来。`TARGET_NO_KERNEL` 会跳过 recovery 镜像，`PRODUCT_BUILD_RECOVERY_IMAGE` 写在 `lineage_g0215d.mk`，不能写进 `BoardConfig.mk`。内核是 `boot-fp8.img` 里的 `Image.gz-dtb`，12778246 字节，镜像头是 v0，没有重编。面板物理上转了 180 度，`TW_ROTATION=180`，画面是正的。触摸坐标已经落在这个正的画面上，再翻 X 和 Y 会上下颠倒，所以没有 `RECOVERY_TOUCHSCREEN_FLIP_X` / `FLIP_Y`。TWRP 把 `ABS_MT_PRESSURE` 为 0 当成松手，这颗 Atmel 的按下会被丢掉，`minuitwrp/events.cpp` 不再清坐标，松手只看 tracking id 为 -1。`TW_NO_SCREEN_BLANK` 挡不住超时把亮度写成 5 再写成 0，所以加了 `TW_NO_SCREEN_TIMEOUT`。Soong 读不到 BoardConfig 的变量，`TW_ROTATION`、主题、像素格式、fscrypt、不熄屏、忽略零主轴都写进了 `SOONG_CONFIG_makeVarsPlugin_*`。`prebuilt/Android.bp` 不再引用缺的 `external/lptools`。缺的 `libstatssocket.so` 和 `libncurses.so` 放进 ramdisk。`libadbd` 和它的几个库补了 `apex_available:platform`，否则平台变体链不上。`libziparchive` 的 `ZipEntry` 加了 `ZipEntry64` 别名。`libpixelflinger` 补了 `android_memset16` / `32`。
4. **启动**。ueventd 只在 `/dev/block/platform/soc/624000.ufshc/by-name` 建节点，fstab 用的是 `bootdevice`。`init.recovery.qcom.rc` 在 `on init` 里把 ufshc 链到 `/dev/block/bootdevice`，并把 configfs 设回 1，控制器是 `6a00000.dwc3`。`on boot` 写一次 `fb0/blank` 为 0、背光 180，再把 `/system/bin/simg2img` 链到 `/sbin/simg2img`。安装包写死了这个路径，`/sbin` 不是 `/system/bin`。只改 rc 时 ninja 可能不重打 ramdisk，要删掉 `relink_libraries-timestamp`、`ramdisk-recovery.cpio`、`ramdisk-recovery.img` 和 `recovery.img` 再编。编完要对照 `system/lib64/libminuitwrp.so` 和 `recovery/root/system/lib64/libminuitwrp.so`，两份不一样就还是旧镜像。
5. **镜像**。`recovery.img` 28667904 字节，`sha256 e25e7084b3b671c3c26f5d6578efd2f21a10b48b6eff6b1dbecceed1aeca3dd2`，副本在 `g0215d/boot-test/recovery-twrp-3.7.img`。已写入 recovery 分区，读回哈希一致。进去之后 `uname` 是 `4.4.302-perf+`，`ro.twrp.version` 是 `3.7.0_11-g0215d`。`twrp mount /system` 挂的是 `/system_root`，`build.prop` 在 `/system_root/system/build.prop`，display id 是 `lineage_g0215d-userdebug 11 RQ3A.211001.001 eng.alpha.20261027.011022 test-keys`。data 已挂上，`/data/system/locksettings.db` 还在，20480 字节。2016 的 `device-backup/recovery.img`（`sha256 4c14c80cfc6a8b77f354cd5d939d9bc94a3d2f3df02f0a39eeb107907c6f76ac`）留着，新镜像起不来就刷回去。`#17` 的 `recovery-phase2.img` 也还在。
6. **刷包**。同一份 zip，`sha256 1f38baa988c90f23b001743fc239af1c1230ba258d7836e7f878ee23c3c10fc5`。第一次没有 `/sbin/simg2img`，boot 写上了，system 没写。补上链接之后 `twrp install` 打印 `writing boot`、`writing system`、`done`。boot 前 13619200 字节 `sha256 42b9f5320b063d42bb9efb45d412eba6cfdc58855488831eb27d072c92ed15c2`。system 整分区 `sha256 de6a43443d6596f0cf66ee7edf2bbb51ebb02afa267df1ff7a2ae708ecc18cba`。临时目录删了。清掉 misc 前 32 字节再重启，回到桌面。`sys.boot_completed=1`，display id 和 `ro.lineage.version=18.1-20261027-UNOFFICIAL-g0215d` 没变，`ro.crypto.state=unencrypted`，`uname` 仍是 `4.4.302-perf+`，`locksettings.db` 还是 20480 字节。
7. **触摸、画面、振动**。画面方向是正的。先是没有触摸：芯片 T6 是 `0x0`，配置校验和 `53a963`，事件在 `event1`，日志里没有 `TOUCH`。原因是压力 0 被当成松手。修好之后触摸上下颠倒，因为 180 度旋转之外又翻了两轴。去掉翻转之后落点和按钮对齐。振动走 `/sys/class/timed_output/vibrator/enable`，写 80 读回倒计时，使用者确认可用。没有写 `update_fw`。

同日第五十八轮：可刷写的 boot 和 system 包。用 2016-10-07 的 TWRP 3.0.2 刷过，data 没有格式化。没有写 aboot、tz、rpm、hyp、cmnlib、keymaster、modemst、fsg、persist。没有打电话，没有重编内核。

1. **包**。`/run/media/alpha/YMTC/g0215d/boot-test/lineage-18.1-20261028-UNOFFICIAL-g0215d.zip`，2405057680 字节，`sha256 1f38baa988c90f23b001743fc239af1c1230ba258d7836e7f878ee23c3c10fc5`。`boot.img` 就是当前的 `boot-fp8.img`，13619200 字节，`sha256 42b9f5320b063d42bb9efb45d412eba6cfdc58855488831eb27d072c92ed15c2`。`system.img` 是稀疏的。原始内容是当时正在跑的 system 分区，卸下后整分区 3221225472 字节，`sha256 de6a43443d6596f0cf66ee7edf2bbb51ebb02afa267df1ff7a2ae708ecc18cba`。零块写成 FILL，刷到一份不一样的旧分区上也不会把空块留成旧数据。`update-binary` 是 `/sbin/sh`，只对 boot 做 `dd`，对 system 做 `simg2img`。
2. **recovery**。刷包之前手机上的 recovery 是 `#17` 的 `recovery-phase2.img`。这一项要用 2016 年那份能挂上 data 的 TWRP，所以先把 `device-backup/recovery.img` 写入 recovery 分区，`sha256 4c14c80cfc6a8b77f354cd5d939d9bc94a3d2f3df02f0a39eeb107907c6f76ac`。进去之后 `uname` 是 `3.18.20-perf`，TWRP `3.0.2-0`，`/data` 直接挂上，54 GB 里用了 1.2 GB。刷完留在这块分区上，和前面说的日常 recovery 一致。`#17` 那份镜像还在硬盘上。
3. **刷写**。`twrp install` 成功。刷完后 boot 前 13619200 字节、system 全分区的 sha256 都和上面的原始镜像一致。脚本删了临时目录。重启进桌面后 `ro.build.display.id` 仍是 `lineage_g0215d-userdebug 11 RQ3A.211001.001 eng.alpha.20261027.011022 test-keys`，`/data/system/locksettings.db` 还在，耳机音量那份 HAL 里有 `RX1/RX2 Mix Digital Volume`。
4. **进 recovery**。原先 `adb reboot recovery` 不重启。init 在 fstab 里找不到 `/misc`，写不了 BCB 就停住。`fstab.qcom` 加了 `/dev/block/by-name/misc` 挂到 `/misc`。这行在刷上去的 system 里。桌面起来之后 `adb reboot recovery` 能进这份 TWRP，data 仍挂着，再开机回到桌面。本仓库和 18.1 树的 `rootdir/etc/fstab.qcom` 都加了这一行。没有重编 boot。

同日第五十七轮：有线耳机通话音量，第五十六轮写错了寄存器。没有改 mixer，没有拿掉 `no-topology`，没有重编内核，没有打电话。

1. **上一轮的写入发生了，听感没变**。13:28 这通有线耳机通话里，音量从 1 调到 5 时，`platform_write_headset_rx_gain` 把 `RX5`/`RX6 Digital Volume` 从 60 写到 84。耳机仍有声音，大小不变。
2. **通路**。`headphones` 把 `SLIM RX5`/`RX6` 送进 `RX INT1_2` / `RX INT2_2`。这两个 mux 挂在 `RX1`/`RX2` 的 mix path 上，有效音量是 `RX1 Mix Digital Volume` 和 `RX2 Mix Digital Volume`。`RX5`/`RX6 Digital Volume` 是主路，这路通话不经过。
3. **改动**。同一组语音档改去写这两个 mix 音量，离开耳机时写回 84。32 位 HAL 重新推过。下一通有线耳机通话再听音量键。

同日第五十六轮：有线耳机通话音量。没有改 mixer，没有拿掉 `no-topology`，没有重编内核，没有打电话。听筒和免提仍走 `NONE`。

1. **有声音**。有线耳机和蓝牙耳机通话都有声音。拓扑保持 `NONE`，回声那一项没有重开。
2. **音量键确实在改语音流**。13:04:56 插入有线耳机。13:05:22 通话路由是 `WIRED_HEADSET`，13:05:44 才切到免提。这中间 `STREAM_VOICE_CALL` 从 4 调到 1，中间经过 2 和 3。这一分钟的 `audio_hw` 行已经被日志冲掉，看不到 `Voice Rx Gain` 那一行。耳机上的 `HPHL`/`HPHR Volume` 仍是 20，`RX5`/`RX6 Digital Volume` 仍是 84（0 dB）。语音音量只写 `Voice Rx Gain`，那是 DSP 的音量档，不改耳机这路的数字增益。蓝牙通话音量走的是另一路 `STREAM_BLUETOOTH_SCO`，13:08 那次从 7 调到 13，和有线耳机不是同一个控制。
3. **改动**。有线耳机语音走 `SLIM RX5`/`RX6`。输出设备是 `voice-headphones`、`voice-line` 或 ANC 耳机时，按语音音量把 `RX5`/`RX6 Digital Volume` 从 84 往下减，每一档 6 dB，最低一档是 54（-30 dB）。离开这条设备时写回 84，耳机音乐播放仍用原来的 0 dB 再加软件音量。`audio.primary.msm8996.so`（32 位）已推到手机，`android.hardware.audio.service` 已加载这份库。下一通有线耳机通话可以听音量键是否跟着变。

同日第五十五轮：通话听清到此停下。没有改 mixer，没有改 ACDB，没有重编内核，没有打电话。听筒和免提仍走 `NONE`。

1. **现在的结果**。两个方向有声音。回声在对方那一头，房间不吵。回声消除和降噪在拓扑里，`NONE` 把它们一起拿掉了。
2. **已经排除的**。`0x10F89` / `0x10F8A` 在 `adsp.b08` 的登记表里，和 `0x10F71`、`0x10F77` 同一类记录，不是缺号。听筒 ACDB 仍返回这一对。10 月 27 日 14:53:51 的听筒通话里，校准已经写入内核，CVP 创建成功，通道数成功，提交 `0x13198` 返回 `ADSP_EFAILED`。注册命令排在提交之后，和小米、一加的 3.18 相同。
3. **不再试**。把听筒改成 `0x10F71` / `0x10F77` 要再打一通，失败就是无声；固件里这两对的登记形式一样，创建会话已经接受 `0x10F89` / `0x10F8A`，没有理由认为换号就能通过提交。把注册挪到提交之前，和 3.18 的顺序相反，模块是提交时才建出来的。不换 ADSP 固件，不换音频 HAL。第 6 项因此不开始。耳机和蓝牙 SCO 还没在 `NONE` 下听过，那是有没有声音，不是这次的拓扑。

同日第五十四轮：通话听清，做第四十九轮的第 5 项。没有改 mixer，没有改音频 HAL，没有重编内核，没有打电话。听筒拓扑仍是 `NONE`。

1. **`reload` 不是这次提交的路径**。`acdb_loader_reload_acdb_files` 只在参数 `reload_acdb` 时调用，垫片固定返回 -1。`acdb_loader_reload_acdb_files_v2` 格力这份库里没有，开机时 `dlsym` 会记一笔。听筒通话走的是 `acdb_loader_send_voice_cal`。
2. **失败那通听筒已经把校准送进去了**。10 月 27 日 14:53:51，路由是听筒。`send_voice_cal` 是 `acdb_rx = 7`、`acdb_tx = 4`、`feature_set = 0`，接着有 `AUDIO_SET_VOCPROC_CAL`、`AUDIO_SET_VOCPROC_DEV_CFG_CAL`、`AUDIO_SET_VOCPROC_VOL_CAL`，内核打了 `voice_set_cal`。然后 CVP 创建成功，通道数 `0x13199` 成功，拓扑提交 `0x13198` 返回 `ADSP_EFAILED`。这四条注册命令在 `voice_setup_vocproc` 里排在提交之后，这次没有执行到。
3. **和 3.18 的命令一样**。格力没有 3.18 内核源码。小米和一加的 3.18 `q6voice.c` 用同一组命令：`VSS_ISTREAM_CMD_REGISTER_CALIBRATION_DATA_V2`、`VSS_IVOCPROC_CMD_REGISTER_DEVICE_CONFIG`、`VSS_IVOCPROC_CMD_REGISTER_CALIBRATION_DATA_V2`、`VSS_IVOCPROC_CMD_REGISTER_VOL_CALIBRATION_DATA`，也都在拓扑提交之后。听筒没有缺一条可以补上的注册。

同日第五十三轮：通话听清，做第四十九轮的第 4 项。没有改 mixer，没有重编内核，没有打电话。听筒拓扑仍是 `NONE`。

1. **条件**。这一步只在固件有 `0x10F71` 和 `0x10F77`、同时没有被拒的 `0x10F89` / `0x10F8A` 时，才把听筒改成内核那一对再打一通。第五十一轮已经对过 `adsp.b08`：TX 表里 `0x10F71` 和 `0x10F89` 都在，RX 表里 `0x10F77` 和 `0x10F8A` 都在。两对同时在，条件不成立。
2. **没有改听筒**。ACDB 现在给听筒的仍是 `0x10F89` / `0x10F8A`，7F 里这对提交已经是 `ADSP_EFAILED`。换成 `0x10F71` / `0x10F77` 不是这一步要验证的事，听筒继续走 `NONE`。

同日第五十二轮：通话听清，看第四十九轮的第 3 项还要不要做。没有打电话，没有拿掉 `no-topology`。

1. **7F 补记里已经有这次拒绝**。开对 `voicemmode1` 会话之后，通道数 `0x13199` 成功，拓扑提交 `0x13198` 被 ADSP 返回 `ADSP_EFAILED`（错误码 1）。内核接着打 `voice_setup_vocproc: Set topology commit failed err:-131` 和 `setup voice failed`。电话接通，听筒没有声音。当时 `voice_get_topology` 打出的就是 TX `69513`（`0x10F89`）、RX `69514`（`0x10F8A`）。绕过是在这次失败之后才加的。
2. **现在重打不会多出一个字符串**。`voice_send_cvp_topology_commit_cmd` 只把 ADSP 的错误码换成 `adsp_err` 里的字符串。错误码 1 的字符串就是 `ADSP_EFAILED`，对应的 Linux 错误是 `-131`。第五十一轮确认听筒现在仍返回这一对，ACDB 文件和这次提交的代码都没改。免提返回的也是这一对，所以当时即使不在听筒上，字符串也一样。
3. **不重做**。再拿掉听筒的 `no-topology` 打一通，只会再无声一次，记下来的还是这两句。`no-topology` 保持原样。

同日第五十一轮：通话听清，做第四十九轮的第 2 项，只读对拓扑号。没有打电话，没有改 mixer、ACDB 或内核。

1. **固件**。号在 `/firmware/image/adsp.b08` 里，其余 `adsp.b00` 到 `adsp.b06`、`adsp.b09` 和 `adsp.mdt` 没有这几个号。TX 登记表里，`0x10F70`、`0x10F71`、`0x10F89` 的第二项都是 1，`0x10F72` 的第二项是 2。RX 登记表里有 `0x10F77` 和 `0x10F8A`。`0x10F89` 和 `0x10F8A` 都在表里，提交失败不是因为固件没有这个号，这一步之后不用先重编内核。
2. **ACDB 现在返回的一对**。手机上的 `MTP_Handset_cal.acdb`、`MTP_Speaker_cal.acdb` 和树里这两份相同。属性 `0x113AF` 指到拓扑号。听筒：TX 设备 4（`handset-mic`）是 `0x10F89`，RX 设备 7（`voice-handset`）是 `0x10F8A`。免提：TX 设备 11（`voice-speaker-mic`）是 `0x10F89`，RX 设备 14（`voice-speaker`）是 `0x10F8A`。两对相同，和 7F 里听筒那次读到的号一致。
3. **内核里那三个号**。`0x10F71`、`0x10F72`、`0x10F77` 都在固件登记表里。听筒和免提的 ACDB 都没有把它们当成这对设备的拓扑。`0x10F71` 和 `0x10F77` 在这两份 ACDB 里一次都没出现。第 4 步要的是「有 `0x10F71` / `0x10F77`、没有 `0x10F89` / `0x10F8A`」，这个条件不成立。

同日第五十轮：通话听清，做第四十九轮的第 1 项。没有改 mixer，没有重编内核。拓扑仍是 `NONE`。

1. **听到的现象**。房间本身不吵，听筒和免提两边都不觉得吵。回声出在另一台手机上：iPhone 贴着耳朵、格力放在嘴边并且靠得很近时，iPhone 里能听到回声。反过来，格力贴着耳朵、iPhone 放在嘴边时，格力这边不放出回声。
2. **和日志对得上**。这通是 12:15:10 接通、12:16:00 拆线，`call_type=UMTS`，会话 `voicemmode1-call`，vsid `297816064`。12:15:36 到 12:15:49 是免提，其余是听筒。12:15:49 切回听筒时走 `voice-handset` 加 `handset-mic`，ACDB 的 `send_voice_cal` 是 `acdb_rx = 7`、`acdb_tx = 4`、`feature_set = 0`。`voicemmode1-call` 带了 `voicemmode1-no-topology`，启用时没有再报会话号错误；`voc_disable_topology: invalid session_id 0x0` 出现在切免提、切回听筒和挂断时的路径复位上。`feature_set = 0` 加上 `NONE` 拓扑，上行没有回声消除。对方听到的是格力麦克风又把听筒或免提里的声音送回去。iPhone 自己有回声消除，所以格力贴耳时听不到这份回声。
3. **听筒侧音**。切回听筒时 `voice_set_sidetone: enable`，path 是 `sidetone-handset`。这是把自己的声音混进听筒，不是送到对方的那份回声。

同日第四十九轮：通话听清，只列尝试。没有改 mixer，没有重编内核，没有拨出电话。联通卡已拔出。现在这张是 Fizz，`gsm.sim.operator.numeric` 是 `302500`，注册名是 `Fizz EXT`，网络类型 `HSPA`，SIM 是 `LOADED,ABSENT`。`Voice Topology Disable` 仍是第 6 号控制（`numid` 7，不是 6）。`mixer_paths_tasha.xml` 里的 `voicemmode1-no-topology` 还在。

7F 补记里听筒和免提已经两个方向有声。有声是因为 vocproc 用了 `VSS_IVOCPROC_TOPOLOGY_ID_NONE`（`0x10F70`），回声消除和降噪都在拓扑里，所以一起没了。ACDB 当时给出的是 TX `0x10F89`、RX `0x10F8A`。通道数命令 `0x13199` 成功，拓扑提交 `0x13198` 被 ADSP 回 `ADSP_EFAILED`，会话建不起来，电话却接通，表现是通了没有声音。CVD 是 `2.2`，内核因此会发这条提交。原厂 3.18 的提交和通道数代码一样。内核里另外写明的拓扑是 TX `0x10F71`（SM_ECNS）、`0x10F72`（DM_FLUENCE），RX `0x10F77`。免提扬声器是 `QUAT_MI2S` 上的 TFA9890，和听筒不是一条通路。

下面按这个顺序。每一次只动听筒，失败就把 `no-topology` 放回去再试下一条。不要先动耳机和蓝牙。不要写 `numid` 6，那是 `Slowtalk Enable`。家网 `Fizz` 的 LTE 不能 CSFB；测试时如果已经不在 HSPA，先把首选网络临时改成 3G，测完改回。

1. **先听现在的通话**。已做，见同日第五十轮。拓扑保持 `NONE`。听筒说一段、免提说一段，记下哪一头回声、哪一头吵、哪一头其实已经够用。可行性高。风险低：不改路径，就是一通 3G。没有这一步，后面分不清是拓扑没回来，还是听筒和免提本来就不是同一个问题。
2. **只读对拓扑号**。已做，见同日第五十一轮。在 ADSP 固件里找 `0x10F89`、`0x10F8A`，以及 `0x10F71`、`0x10F72`、`0x10F77`。再看 ACDB 现在给听筒和免提各返回哪一对。不打电话，不改文件。可行性高。风险低。若固件里没有 `0x10F89` / `0x10F8A`，提交失败就是号不对，不用先重编内核。结果是这五个号固件里都有，听筒和免提返回的仍是 `0x10F89` / `0x10F8A`。
3. **听筒上抓一次真正的拒绝**。已做，见同日第五十二轮，依据是 7F 补记，没有再打一通。只在这一通里拿掉听筒的 `no-topology`，让 ACDB 的号走到提交，把 ADSP 的错误字符串记下来，挂断后立刻把 `no-topology` 放回。可行性高。风险：这一通听筒没有声音。免提、耳机不要一起拿掉。错误字符串已经是 `ADSP_EFAILED`，`err:-131`。
4. **若固件里有 `0x10F71` 和 `0x10F77`，而没有那对被拒的号**。已结束，见同日第五十三轮。第五十一轮里固件同时有这两对，条件不成立，没有把听筒改成 `0x10F71` / `0x10F77`，也没有为这一步打电话。只对听筒改用这一对，打一通。提交通过而且两个方向仍有声，再听回声。不通过就放回 `NONE`。可行性中等：号在固件里不等于校准也在。风险：这一通无声，或有声但比现在更差。
5. **号在固件里，提交仍失败**。已做，见同日第五十四轮。再看校准。垫片的 `acdb_loader_reload_acdb_files` 现在返回 -1，提交可以因为校准没注册而失败。对照原厂 3.18 的注册校准命令，只补听筒这一条所缺的注册，再打一通。可行性中等。风险同上，并且不要换成另一套音频 HAL。听筒这条的静态、设备配置和音量校准在提交之前已经送到内核；四条注册命令和 3.18 相同，并且排在提交之后。没有补注册，没有打电话。
6. **听筒的非 `NONE` 拓扑已经又有声之后，再做免提**。见同日第五十五轮，听筒没有得到这样的拓扑，这一步不开始。免提是 TFA9890，ACDB 可能给另一对号。听筒的改动不要套到免提上再一起测。可行性中等。风险：免提再次无声，听筒应仍走已经验证的那条。
7. **耳机，然后蓝牙 SCO**。见同日第五十五轮，不和拓扑修在一起做。这两条从来没听过。先在 `NONE` 下确认有没有声音，再套用听筒上已经能用的拓扑。可行性现在低：没声的话问题不在回声消除。不要和前面几步并在一次通话里。

不放进这个顺序：整路删掉 `no-topology`、换掉整份音频 HAL、为这一项改基带或 NV、在第 2 步之前重编内核。

同日第四十八轮：VoLTE，做第四十五轮的第 3 项，只查系统侧的运营商配置。没有改配置，没有写 NV，没有加载 MBN，没有拨出电话。

1. **移动卡落到哪份配置**。`46000`、`46002`、`46004`、`46007`、`46008` 的 carrier id 是 1435，名字是 China Mobile。对应文件是 `carrier_config_carrierid_1435_China-Mobile.xml`。里面只有紧急号码进通话记录、TD-SCDMA，以及视频通话中禁止加通话、保持和视频会议。没有 `carrier_volte_available_bool`，没有增强型 4G 的三项。没有 `carrier_config_mccmnc_46000.xml`。香港那份 carrier id 767 里的 `46000` 只是 TD-SCDMA 漫游名单，不是这份卡的配置，也不改 VoLTE。
2. **缺省值**。框架默认：`enhanced_4g_lte_on_by_default_bool` 是 true，`hide_enhanced_4g_lte_bool` 是 false，`editable_enhanced_4g_lte_bool` 是 true，`carrier_volte_provisioning_required_bool` 是 false。`carrier_volte_available_bool` 默认是 false。`isVolteEnabledByPlatform()` 看到 `persist.dbg.volte_avail_ovr=1` 就返回 true，不会读到那个 false。订阅里还没写过增强型 4G 时，`isEnhanced4gLteModeSettingEnabledByUser()` 用默认的开。两处都过，`Phone.isImsUseEnabled()` 里的 VoLTE 条件才成立。
3. **实机上的包**。`persist.dbg.volte_avail_ovr` 是 1。`/system/system_ext/priv-app/CarrierConfig/CarrierConfig.apk` 里的 1435 和树里这份一样，没有 VoLTE 项。当前这张卡不是移动卡，没有把它的运营商配置当成移动的结果。

同日第四十七轮：VoLTE，做第四十五轮的第 2 项，补上 `IImsRadio` 1.0。没有换格力的 `libril-qc-qmi-1.so`，没有把 HAL 写进 manifest，没有写 NV，没有加载 MBN，没有拨出电话。注册状态没有写成已注册。

1. **服务**。`vendor.imsradio` 用 `ims.apk` 里的 `IImsRadio.Stub` 注册 `imsradio0` 和 `imsradio1`，接口哈希仍是电话进程原来那份。init 在 `class main` 里拉起，用户是 root。system 用户能连上 IMSA，发送返回 `-16`，所以不放在 system 上。没有写进 manifest。`hwservicemanager` 会记一笔 manifest 里没有这项，注册仍然成功。
2. **注册状态**。`ims_reg_query` 只读 IMSA 的 `0x20`。这次读到 valid `1`、status `0`，服务日志是 `slot0 IMSA status 0`，按未注册回报，不是已注册。卡 1 没有 SIM，固定报未注册，不再去连 IMSA。改注册、改配置和通话控制都回 `REQUEST_NOT_SUPPORTED`，不发给基带。
3. **实机**。重启之后 `lshal` 仍有 `vendor.qti.hardware.radio.ims@1.0::IImsRadio/imsradio0` 和 `imsradio1`。电话进程报 `imsRadioV10 availability: available`，1.1 到 1.6 仍不可用。配置请求收到了回应，电话进程没有崩。语音是 Bell LTE，在服务中。SIM 是 `LOADED,ABSENT`。
4. **哈希**。`modemst1` 仍是第四十四轮的 `690fe5f0a044e9598f8169257f391d47552bdde3ea07441df03d405489b960e5`。`modemst2` 在这次以 root 启动该服务的那次重启之后变成 `522fef7320d93f4d994c66dad9dd739be2bdc0fc84ed85d3a2752f1e8d684765`。更早一次以 system 启动、以及重启前那次 root 的只读 IMSA，哈希都没变。这次没有发 IMSS，也没有写 NV。

同日第四十六轮：VoLTE，做第四十五轮的第 1 项，只读自动选择和 `volte_op` 里的 `IMS_enable`。没有写 NV，没有加载 MBN，没有拨出电话。diag 用完已经切回 USB。读之前和读之后，两份 `modemst` 哈希都是第四十四轮那两个值。

1. **自动选择**。`/nv/item_files/mcfg/mcfg_autoselect_by_uim` 和 Subscription01 都是 1 字节 `0x07`。`mcfg_config_force_load` 和 Subscription01 都是 1 字节 `0x01`。`0` 才会走到 modem 里那句 `autoselection disabled`。`0x07` 不是关。同一段日志里另有 `iccid reselect` 和 `imsi reselect`。固件里没有这三位的枚举名，所以不把每一位单独命名。强制加载是 `0x01`，它只表示要加载已经选中的那份，文件里没有 `volte_op` 这个名字。
2. **`IMS_enable`**。`volte_op` 尾部名字是 `Volte_OpenMkt-Commercial-CMCC`，`volte_su` 是 `Volte_Subsidized-Commercial-CMCC`。两份里的 `ims/IMS_enable` 内容字节都是 `0x01`。同目录的 `nov_open` 尾部是 `NoV_OpenMkt-Commercial-CMCC`，同一项是 `0x00`。条目前面那个 `0x07` 是属性，别的 1 字节项也有，不是文件内容。
3. **判断**。插上移动卡时，基带会按卡重选，不会停在「自动选择已关」。重选结果不一定是 `volte_op` 或 `volte_su`，因为移动还有一份 `IMS_enable` 为 `0` 的 `NoV`。选哪一份要看卡号和配置里的匹配，选择表这次没读，也没有激活。
4. **实机**。语音仍是 Bell UMTS，在服务中。SIM 是 `LOADED,ABSENT`。没有拨出电话。

同日第四十五轮：VoLTE，目标改成准备给国内的中国移动用户测试，不再在当前这张联通卡、Bell 网络上把注册做出来。这一轮只改路线，没有写 NV，没有加载 MBN，没有拨出电话。

第四十三轮里还没做的五条都停掉：

1. **补三个小 NV**。那是为了让这台机当前的基带接受 IMSS。`volte_op` 里已经有 `sms_domain_pref` 和 `ue_usage_setting`。写在这张联通卡的 EFS 上，帮不到以后的移动测试，还可能把这台机的语音域留坏。不做。
2. **NAS 改语音域**。只作用在当前这次驻网上，而且可能让来电不再回落 3G。不做。
3. **改 policyman**。第四十四轮已经看到策略文件在。要改的是这台机现在的 EFS，风险高。移动测试用的是移动 MBN 里的策略。不做。
4. **加载一份 MBN**。原计划是找一份不是 CSFB 的联通配置。三份联通都是 CSFB，没有这份。`volte_op` 和 `volte_su` 是移动的，在这张联通卡上激活是错运营商。不在这台机上激活。
5. **换整份 modem 固件**。仍然不做。移动的配置已经在现有镜像里。

新的路线。成功标准留给国内的移动卡、移动自己的 LTE：来电时语音制式仍是 LTE。这台机只用来确认短信、驻网和现有通话没有被弄坏。

1. **只读自动选择**。读 `/nv/item_files/mcfg` 里自动选择和强制加载那几个 1 字节，并确认 `volte_op` 里 `IMS_enable` 的取值。不写，不激活。用来判断插上移动卡时基带会不会自己换到 `volte_op` 或 `volte_su`。可行性高，风险低。
2. **补上真正的 `IImsRadio`**。已做，见同日第四十七轮。格力的 `libril-qc-qmi-1.so` 不换。不在 manifest 里先声明一个起不来的 HAL，也不做一个永远报已注册的空服务。重启之后 `lshal` 能看到 `imsradio`，再考虑写进 manifest。第四十二轮说 HAL 没用，是因为当时的基带拒绝 IMSS；那次拒绝发生在当前这份联通配置上。移动的 `volte_op` 里另有 IMS 项，所以这条回到路线上。可行性中等。风险：HAL 进了 manifest 却注册不上，会拖住开机；转发错了会让电话进程反复崩。做的时候不动这台机的基带。
3. **运营商配置**。已做，见同日第四十八轮。`persist.dbg.volte_avail_ovr=1` 已经让「设备支持 VoLTE」为真。这棵树里没有单独的 `46000` VoLTE 配置。分发前确认移动卡走默认配置时，增强型 4G 不会被运营商配置关掉。只查系统侧。可行性高，风险低。
4. **测试交给移动用户**。中国移动卡，在移动自己的 LTE 上，不漫游。通过是 IMSA 状态离开 0，并且来电时语音制式仍是 LTE。如果自动选择没有落到 `volte_op` 或 `volte_su`，那是这次测试之后的事，不在这张联通卡上提前加载。

同日第四十四轮：VoLTE，做第四十三轮的第 1 项，只读盘点。没有写 NV，没有加载 MBN，没有读策略文件的内容，没有拨出电话。diag 用完已经切回 USB。盘点前后两份 `modemst` 的哈希相同。

1. **`/nv/item_files/ims`**：`IMS_enable`（1 字节），`ims_hybrid_enable` 和它的 Subscription01，`qipcall_1xsmsandvoice`、`qipcall_dan_needed`、`qipcall_is_conf_server_refer_recipient` 及后两个的 Subscription01，`qp_ims_plani_config`（128 字节）及 Subscription01。目录在空名字处结束。没有 `qp_ims_reg_config`、`qp_ims_param_config`。
2. **`/nv/item_files/modem/mmode`**：`device_mode`（1）、`lock_parameters`（82）、`lte_bandpref`（8）及 Subscription01、`lte_bandpref_extn_65_256`（24）、`mmode_1xsxlte_optimization`（51）、`qmi/ui_tty_setting_pri`（1）、`rpm_sys_time`（4）、`scan_scope_rule`（1）、`sd/sdssscr_timers`（204）及 Subscription01、`sw_version`（61）。`voice_domain_pref`、`sms_domain_pref`、`ue_usage_setting` 不在这个目录里。`device_mode`、频段和 `lock_parameters` 的内容没有读。
3. **`/policyman` 在**。`call_mode`、`svc_mode`、`ue_mode`、`freq_list` 各 1 字节，都有 Subscription01。`current_mcc` 4 字节。`device_config` 24 字节，`device_config.xml` 958 字节。`carrier_policy.xml` 4251 字节，Subscription01 同样大小。`rat_mask` 56 字节。内容没有读。modem 里那句没有持久化设备配置，是代码路径；这份 EFS 上策略文件是存在的。
4. **MBN**。联通是 `china/cu/commerci/openmkt`（15744 字节）、`subsidiz`（16596）、`lab/test`（11108）。这三条路径里没有 VoLTE。移动的商业配置有 `volte_op` 和 `volte_su`。没有加拿大运营商。EFS `/nv/item_files/mcfg` 里有自动选择、强制加载和版本号这些小文件，内容没有读。没有加载任何一份。
5. **哈希**。`modemst1`（`sdf1`）`690fe5f0a044e9598f8169257f391d47552bdde3ea07441df03d405489b960e5`，`modemst2`（`sdf2`）`dfbfaa14ad55febfd7314c98a0de77424208a63ffb9daa2aa958c8b5f6fcc91f`。各 2097152 字节。盘点后再算一次，相同。
6. **实机**。语音仍是 Bell UMTS，在服务中，数据仍未注册。SIM 是 `LOADED,ABSENT`。这是盘点之前那通 3G 来电留下的状态。没有拨出电话。

同日第四十三轮：VoLTE，列出基带侧还能试的事。没有改动。没有拨出电话，没有写新的 NV，没有加载 MBN，没有动 modem 镜像和 `fsg`。

固件里已经有 IMS 的实现，modem 字符串里有 `IMS Disabled/Enabled in NV settings` 和 `RegistrationHandlerVoLTE`。系统侧能发的 IMSS 配置读和写都被拒绝。下面按建议的顺序。每一项都还没做。

做的时候共用这几条边界：继续只用已经试过的 EFS open、read、write、stat。不用 opcode 48，不用 format 和 shred。新文件写进去之后没有试过删除，写错的会留在 `modemst` 里。不写 `device_mode`、频段偏好和 `lock_parameters`，不写 `fsg`，不把 `modemst` 的内容拷进仓库。每次只看 LTE 是否还在、SIM 是否仍是 `LOADED,ABSENT`、IMSA 的 Status 有没有离开 0。不要拨出。现在是联通卡漫游在 Bell。配置写对了，Bell 也未必给这张漫游卡做 IMS。4G 上来电仍响，要在联通自己的 LTE 上才算数。在 Bell 上把语音改成只走 PS，来电可能既不走 IMS，也不再落 3G。

1. **只读盘点**。列出 `/nv/item_files/ims`、`mmode`、policyman（若有），以及 `/vendor/firmware_mnt/image/modem_pr/mcfg/configs` 里联通或 VoLTE 的 MBN 名字。记下 `modemst1` 和 `modemst2` 的哈希。可行性高，这些路径已经碰到过一部分。风险低，只读，不拷分区内容。
2. **补三个原本不存在的小 NV**。`voice_domain_pref`、`sms_domain_pref`、`ue_usage_setting` 上一轮 stat 是 errno 2。`IMS_enable` 已经是 `0x01`，出厂的 `ims_hybrid_enable` 也是 `0x01`，这两个不够。一次只建一个缺的文件，写法和 `IMS_enable` 一样，取值用语音优先 PS、短信优先 PS、终端以语音为中心。放在运行中的基带里，等到 `modemst` 哈希变了再重启，确认文件还在、LTE 还在，然后重读 IMSS 和 IMSA。可行性中等：基带把 IMS 开关和 NV 绑在一起，这三个还没写过；策略也可能根本不看它们。风险中等：取值写反会把电话固定成 CSFB，或固定成只走 PS。文件留下后不能靠 format 或 shred 清掉。不要一次写一串。
3. **用 NAS 选网报文改语音域，不写文件**。先读当前的 voice domain，读到了再写成 PS 优先，看 IMSS 的 `0x36` 有没有变，看 IMSA Status。重启后再读一次，确认它落不落盘。可行性中等偏低，运行时参数未必压得过策略，也未必跨过重启。风险中等：读不到原值就不要写。写成只走 PS 之后，IMS 若仍未注册，来电不再回落 3G。
4. **policyman**。先做第 1 项的目录。只有看到明确关掉 IMS 或漫游 IMS 的那一条，才改那一条。可行性现在低：modem 里有 `No persisted device config from EFS`，策略可能没有从 EFS 读。风险高：改错会丢 LTE 或驻不上网。`device_mode` 现是 `0x01`，不动。
5. **选用机里已有的 MBN**。`mcfg_sw` 里已有中国、亚太、欧洲、韩国和几家美国运营商，没有加拿大。OnePlus 的 `CU_DS_CSFB_G` 是 CSFB，加载它是往回走，不加载。AT&T 和 T-Mobile 的 MBN 对不上联通，也不为 Bell 去载。先在现有 `mcfg` 里找名字像联通、而且不是 CSFB 的配置。找到之后用 PDC 选择，激活前记下当前配置。激活后看 LTE、SIM，以及 IMSS 是否还回 `0x36`。可行性中等偏低：原厂这台机的 VoLTE 从来没用过，出厂配置可能就是不注册 IMS。风险高：PDC 激活写进 `modemst`，影响频段、紧急呼叫和 IMS。回退不是删一个小文件。不写 `fsg`，不刷 modem 镜像。
6. **换整份 modem 固件**。可行性低：镜像里已经有 IMS 和 VoLTE 的实现，缺的不是这层代码。风险很高：SIM、驻网和开机都不押在这上面。不做。

顺序停在这里。真正动手时先做第 1 项。第 2 项是第一件写入，一次只写一个文件。第 5 项和第 6 项要等第 2 项没有改变 IMSS 的 `0x36` 再考虑，第 6 项不进入实施。

同日第四十二轮：VoLTE，在改基带之前看系统侧还有没有别的办法。没有拨出电话，没有写 NV，没有换 MBN，没有换格力的 `libril-qc-qmi-1.so`，没有把 `IImsRadio` 写进 manifest，没有重编内核，没有刷整镜像。实机仍是联通卡漫游在 Bell LTE。

1. **不是写坏了请求**：上一轮写开启用的是 QCRIL 自己的报文布局。这一轮改读几条空请求，库能编码的 IMSS 读取（`0x25`、`0x26`、`0x27`、`0x28`、`0x34`、`0x3f`、`0x54`、`0x61`）基带都回 result `1`、error `0x36`、附带值 `3`。写开启仍是附带值 `4`。空请求也被拒，所以不是请求体填错。`0x56` 回了空的成功，RIL 并不用它下发配置。
2. **IMSA**：注册查询成功，有效，状态仍是未注册。288 字节里没有失败原因，也没有 P-CSCF 地址。服务状态查询也成功，几个状态字段有效且是 0。基带没有在走 SIP 注册。
3. **结论**：`IImsRadio`、运营商配置和 IMS APN 最后都要落到这些 IMSS 配置报文上，而基带现在一律拒绝。系统侧没有下一条能单独做完的修复。下一步才是基带配置。电话停在 Bell LTE，SIM 是 `LOADED,ABSENT`，`ImsService` 仍绑定。没有拨出电话。

同日第四十一轮：VoLTE，向基带发一次 IMS 服务开启，看注册状态会不会离开 0。没有拨出电话，没有换格力的 `libril-qc-qmi-1.so`，没有把 `IImsRadio` 写进 manifest，没有重编内核，没有刷整镜像，没有动指纹模板和图案。实机仍是联通卡漫游在 Bell LTE。

1. **报文**：`qcril_qmi_imss_get_ims_reg_config` 发的是 IMSS 消息 `0x26`，应答 280 字节。`qcril_qmi_imss_request_set_ims_registration` 发的是消息 `0x21`，请求 264 字节，末尾两字节是开关的 valid 和值。上一轮日志里的 `qmi send sync res 0` 只是传输返回值。这次用同一套 IDL（IMSS 主版本 1、次版本 `0x26`、库版本 6）直接问基带。读和写的传输都是 0，应答正文是失败：result `1`，error `0x36`。读配置时后面一个有效字段是 `3`，把开关写成 valid `1`、值 `1` 时这个字段是 `4`。应答末尾那两个开关字节仍是 0。`persist.radio.disable_modem_cfg` 不是 `true`，QCRIL 不会在这一步假装成功。
2. **注册**：IMSA 消息 `0x20` 在写入前后都查成功。注册有效位是 1，状态仍是未注册，和 RIL 里的 `IMS registered valid 1, Status 0` 一致。等 8 秒再读，字节没有变。
3. **实机**：没有重启 rild。电话停在 Bell LTE，SIM 是 `LOADED,ABSENT`。`ImsService` 仍绑定。没有拨出电话。

同日第四十轮：VoLTE，让 `IMS_enable` 跨过重启，并看 IMSA/IMSS 是否出现。没有拨出电话，没有换格力的 `libril-qc-qmi-1.so`，没有把 `IImsRadio` 写进 manifest，没有重编内核，没有刷整镜像，没有动指纹模板和图案。实机仍是联通卡漫游在 Bell LTE。

1. **落盘**：`/nv/item_files/ims/IMS_enable` 写成 1 字节 `0x01`。上一轮刚写完就重启，文件会丢。这次在基带里放了一段时间，`modemst1` 和 `modemst2` 的内容变了，再重启文件还在，读回仍是 `0x01`。diag 的 sync opcode 48 仍被基带当成非法命令，没有用它，也没有试 format 和 shred。同目录出厂就有的 `ims_hybrid_enable` 读出来也是 `0x01`。`/efs_force_shutdown_sync` 刚写完立刻重启会丢，隔一会儿再重启则还在。这个标记不是 IMS 起来的原因。
2. **QMI**：文件在开机时已经存在之后，QCRIL 读 IMSS 的 `qcril_qmi_imss_get_ims_reg_config` 和 `get_client_provisioning_config` 都是 `qmi send sync res 0`。IMSA 的状态变成 `IMS registered valid 1, Status 0`。上一轮这两路在 Bell LTE 上一直是 `qmi_client_init_instance returned failure(-3)`。`RIL_REQUEST_IMS_REGISTRATION_STATE` 仍有一次失败，但 IMSA 自己的状态已经能读到，而且是未注册。电话停在 Bell LTE 时 Status 仍是 0。
3. **实机**：单独把两边的 rild 一起拉起来时，无线电会停在 Unknown，整机重启后回到 Bell LTE，SIM 是 `LOADED,ABSENT`。`ImsService` 仍绑定。`ImsRadio HAL is not available` 还在，没有注册 `imsradio0`。没有拨出电话。

同日第三十九轮：VoLTE，查 `ImsRadio HAL is not available` 和 `registered=false`。没有拨出电话，没有换格力的 `libril-qc-qmi-1.so`，没有把 `IImsRadio` 写进 manifest，没有重编内核，没有刷整镜像，没有动指纹模板和图案。实机仍是联通卡漫游在 Bell LTE。

1. **HAL**：CAF 的 `ims.apk` 只找 HIDL 实例 `imsradio0` / `imsradio1` / `imsradio2`，dex 里没有 `rild_ims`。格力 RIL 已经在听 `/dev/socket/qmux_radio/rild_ims0` 和 `rild_ims1`，但不会 `registerAsService("imsradioN")`。`lshal` 里仍然没有 `vendor.qti.hardware.radio.ims`。这个客户端接不上旧 socket，所以日志一直是 HAL 不可用。
2. **基带**：电话已经注册在 Bell LTE 时，QCRIL 连 IMSA 和 IMSS 仍是 `qmi_client_init_instance returned failure(-3)`。IDL 里 IMSA 的 service id 是 `0x21`，IMSS 是 `0x12`。`RIL_REQUEST_IMS_REGISTRATION_STATE` 因此是 `GENERIC_FAILURE`。只把 HAL 补出来，基带不提供这两路 QMI，IMS 也注册不上。modem 镜像里有 `IMSS` / `VoLTE` 字符串，服务只是没有注册上来。
3. **EFS**：`/nv/item_files/ims` 目录在，`IMS_enable` 原来不存在。用 diag 的 EFS open/write/close 写成 1 字节 `0x01`，当时 `stat` 大小是 1，读回也是 `0x01`。重启之后这个文件没了（`stat` errno 2），IMSA 仍超时。opcode 48 的 sync 被基带当成非法命令退回，没有再试别的 opcode（里面有 format 和 shred）。OnePlus 的联通商业 MBN 名字是 `CU_DS_CSFB_G`，策略是 CSFB，不是 VoLTE，没有加载。
4. **实机**：调查中单独重启过 slot 0 的 rild，调制解调器停在 LPM，两边的 rild 一起拉起来之后回到 Bell LTE。`ImsService` 仍绑定。`persist.radio.adb_log_on=1` 才看得到这些 QCRIL 日志。

同日第三十八轮：VoLTE。原厂这台机的 VoLTE 从来没注册过，所以没有把原厂 6.0 的 `ims.apk` 和那套关掉的开关搬过来。短信和第二张卡用户确认已经正常。没有拨出电话，没有重编内核，没有刷整镜像，没有动指纹模板和图案。

1. **平台**：`config_device_volte_available` 和 `config_device_vt_available` 写成 true。`persist.dbg.volte_avail_ovr=1`、`persist.dbg.vt_avail_ovr=1`、`persist.radio.calls.on.ims=1`、`persist.radio.jbims=1`。原厂后两项是 0，基带不会去建 IMS PDN。`android.hardware.telephony.ims` 特性打开。`TeleService` 的 `config_ims_mmtel_package` 写成 `org.codeaurora.ims`，`ImsResolver` 才会去绑。
2. **客户端**：OnePlus 3 的 `org.codeaurora.ims`（实现 `android.telephony.ims.ImsService`），用平台测试密钥重签，放在 `/system/priv-app/ims`。旁边是 `ims-ext-common`、`qti-telephony-utils`、`qti-telephony-hidl-wrapper`，以及 `libimsmedia_jni.so`、`libimscamera_jni.so`。第一次启动缺 `android.hidl.manager.V1_0.IServiceNotification$Stub`，电话进程崩溃；补进 wrapper 之后缺 `libimsmedia_jni.so`，又崩了一次。两处补上之后 `ImsService` 能保持绑定，LTE 回到 Bell。
3. **守护进程**：`imsqmidaemon`、`imsdatadaemon`、`ims_rtp_daemon`、`imsrcsd`。格力的 `libdsi_netctrl.so`、`libqmiservices.so`、`libcneapiclient.so` 没有换。`imsdatadaemon` 链的是私有的 `libdsi_imsctrl.so`（多出 `dsi_query_link_local_network_handle`）、`libds_imsu.so`、`qd_ims.so`，外加 `libcneimsclient.so`（格力的 CNE 没有带卡槽参数的 `CreateCneNetworkRequest`）和本地的 `libandroid_net.so`。`imsdatadaemon` 必须用 root 起：内核 IPC router 的 bind 要 `CAP_NET_RAW`，`user system` 时 dmesg 是 `imsdatadaemon Do not have permissions`，DCM 注册失败。改成 root 之后 `qmi_dcm_register_service rc : 0`。
4. **实机**：联通卡漫游在 Bell LTE，小区 `LteVopsSupportInfo mVopsSupport=1`。`ImsService` 已绑定。`registered=false`，`registrationTechnology=-1`。`ImsSenderRxr` 报 `ImsRadio HAL is not available`，`lshal` 里没有 `vendor.qti.hardware.radio.ims`。这个 HAL 在 OnePlus 的 `libril-qc-qmi-1.so` 里，格力自己的 RIL 没有。没有换这颗 RIL，避免把已经通的驻网、短信和第二张卡换掉。没有拨出电话，所以还不能说 4G 来电能响。

同日第三十七轮：指纹改成强生物识别。没有重编内核，没有动模板和图案，没有刷整镜像。
1. **原因**：`config_biometric_sensors` 是空数组。`AuthService` 不会调用 `initConfiguredStrength`，`mOEMStrength` 停在 0，`isStrongBiometric()` 为假。锁屏成功仍走 `onAuthenticationSucceeded`，日志是 `Skipping addAuthToken`。长时间不用之后，非强生物识别还可能被要求先输入图案。应用密钥也认不了这枚指纹。
2. **强度**：`overlay/frameworks/base/core/res/res/values/config.xml` 加上 `0:2:15`（传感器 0、指纹、`BIOMETRIC_STRONG`）。重编 `framework-res.apk`，41810820 字节，`sha256 9cb41215d10a53896eb8eb9930022e5467efca4b616bf47daf800c78e3016272`，推到 `/system/framework/framework-res.apk`。清了 `/data/resource-cache` 再拉起框架。运行中的资源读出来是 `0:2:15`。日志是 `AuthService: Registering ID: 0 Modality: 2 Strength: 15`，接着 `FingerprintService: initConfiguredStrengthInternal(15)`。`15 & 0x7FFF` 等于 `BIOMETRIC_STRONG`，下次成功会进 `addAuthToken`。
3. **令牌**：Goodix 比对成功时按 `hw_auth_token_t` 填 69 字节。版本字节是 0。challenge 是 `fingerprint_authenticate` 传入的 operation id，小端。user id 和 authenticator id 来自 `fingerprint.txt` 的后两列，小端。具体数值不放进仓库。类型写成 `0x02000000`，是网络序的 `HW_AUTH_FINGERPRINT`。时间戳 `rev` 成网络序。HMAC 32 字节保持 0。HAL 从消息偏移 16 拷这 69 字节，和 `fingerprint_authenticated_t` 里 hat 的位置一致。`KeyStoreService::addAuthToken` 只检查权限、长度 69 和版本 0，不校验 HMAC。软件 Gatekeeper 的 `ComputeSignature` 也把 HMAC 写成 0。这枚令牌会被收下，不会因为 HMAC 为空被拒。
4. **实机**：拉起框架后锁屏在听指纹，`Screen state: 1`，`fpalgo_Match_Start`。这一轮没有新的按压，所以还没有 `AddAuthenticationToken` 那一行。Finger 1（`1681692777`）还在，图案 SP handle 仍是 `[redacted]`。`gx_fpd` 在第一次 `stop` 时 `SIGSEGV`，init 拉起后重新载入模板，比对已经重新开始。没有换指纹库，没有换内核。整机重启后第一次解锁仍要图案，这是开机强认证，不是这枚指纹还弱。

同日第三十六轮：录入和锁屏解锁都通过了。内核仍是 `#43`（`boot-fp8.img`），没有重编。图案锁屏还在。
1. **录入**：04:17:51 到 04:18:03，`onEnrollResult` 的剩余次数从 9 走到 0，编号 `1681692777`。最后一帧 `enrolAddImage progress=100`，质量 93，有效比 100。`Done with client: com.android.settings`。`settings_fingerprint.xml` 里是 Finger 1，`featrue_0_0_1.dat` 和 `fingerprint.txt` 对得上。抬手的空读仍是类型 21，HAL 打 `drop acquired imager-dirty`，框架只有 `Acquired: 0`。前面几次 `error = 5` 是查找传感器取消录入，不是失败。
2. **锁屏**：04:18:17 和 04:18:25 各有一次 `onAuthenticated(false)`，编号 0，对应按错的手指。04:18:20 和 04:18:26 各有一次 `onAuthenticated(true)`，编号 `1681692777`，属主 `com.android.systemui`。成功后 `Set mode:1`。指纹服务计数是接受 3 次、拒绝 2 次、锁定 0 次。`gx_fpd` 没有崩。结束时焦点在桌面，`isKeyguardShowing=false`，芯片模式 `0x01`。
3. **屏幕状态**：锁屏刚开始听指纹时 `is_screen_on` 是 0，芯片先到 FF 模式 3；手指按上去之后切回图像模式再 `fpalgo_Match_Start`，屏幕状态变成 1。两次解锁都走完了这条路。
4. **令牌**：成功时日志是 `Skipping addAuthToken`。`config_biometric_sensors` 是空的，传感器强度是 0，不算强生物识别，令牌没有放进 KeyStore。这次用户已经解过锁，锁屏只靠 `onAuthenticationSucceeded` 就能打开。重启后第一次仍要图案。长时间不用之后，非强生物识别可能被要求先输入图案。没有为这个改框架。图案 SP handle 仍是 `[redacted]`。

同日第三十五轮：手动清掉已录入的指纹之后，新的录入第一次能认出传感器，然后停在 “Lift, then touch again”，后面没有进度。两侧电容键还在。内核仍是 `#43`（`boot-fp8.img`），没有重编。图案锁屏还在。这一版还没在真手指上录完。
1. **现象**：查找传感器的第一下有反应，录入页标题是 “Lift, then touch again”。继续按压，进度条不动。短按仍是 Home。
2. **原因**：04:12:23 录入页的 `gx_Register` 把状态设成 2。手指抬起时状态是 `0xa0`，读线程 `Data abort`，状态回到 1，daemon 打 `Notify type:21`。后面的按下（`0xb0`）和图像帧（`0xc0`）到来时 `g_read_flag` 是 0，帧被丢掉，没有 `enrolAddImage`。类型 21 原来会走 `send_fp_scan_on`，监听线程看到采集码非 0 就再调 `goodix_sensor_fp_enroll`，下一次按压才有图像。上一轮为了不把空读报成传感器脏了，把类型 21 和 22 直接返回，这次重新打开采集的调用也没了。比对时同样靠这个码再调 `goodix_sensor_fp_match`。
3. **修复**：`fingerprint.default.so` 把类型 21 和 22 改回 `mov w22, #3` 再进原来的 `send_fp_scan_on`。库回到 755608 字节，`sha256 f6520c7d67e5ecc1716c09eaebe3304252fc71c45bffe7d0eff8fc2ba967ea2f`，已推到 `/vendor/lib64/hw/fingerprint.default.so`，两边设备树里那份也换了。HAL 的 `notify` 收到 `FINGERPRINT_ACQUIRED_IMAGER_DIRTY` 时只丢给界面的那一跳，监听线程返回后仍会重新采集。新的 `android.hardware.biometrics.fingerprint@2.0-service` 是 26112 字节，`sha256 8315d8337c0a263f3094c6104da72227b20698985968757f631c94c87e1e3be8`，已推到 `/vendor/bin/hw/`。没有换内核，没有刷整镜像。
4. **实机**：重启 `vendor.fps_hal` 之后芯片是 `0x01`，`gx_fpd` 没有换 pid，也没有新的栈保护崩溃。图案锁屏还在，SP handle `[redacted]`，没有改用户的图案。设置里的指纹列表是空的，`fingerprint.txt` 也是空的。真手指还没在这一版上再录一次。

同日第三十四轮：三次录入都完成了，每次都提示传感器脏了。锁屏上正确和错误的手指都没有反应，连失败提示都没有。两侧电容键还在。内核仍是 `#43`（`boot-fp8.img`），没有重编。图案锁屏还在。真手指还没在锁屏上解开。
1. **现象**：设置里三次录入都走到完成。界面多次说传感器脏了，传感器是干净的。锁屏上按压没有任何提示。短按仍是 Home。
2. **录入**：三次会话都是 `Done with client`，没有 `handleError`。框架记下 Finger 1、Finger 2、Finger 3，编号 `1681692777`、`1681692778`、`1681692779`。Goodix 的模板是 `featrue_0_0_1.dat`、`featrue_0_0_2.dat`、`featrue_0_0_3.dat`，`fingerprint.txt` 把槽位对上这三个编号。有效图像是 `enrolAddImage progress=100`，质量 60 和 75，有效比 100。所谓传感器脏了是类型 21：空读（`Data abort`，长度 0，多半是手指离开）被 `GxFpDevice::notify` 当成 `FINGERPRINT_ACQUIRED_IMAGER_DIRTY`。类型 21 和 22 不再送给框架。`fingerprint.default.so` 仍是 755608 字节，`sha256 51dc64fdc4baf55dd30a291ad8cbdf11cf1645660bfbae09c8b26fd34acee7c1`。这一轮没有再录第四枚。
3. **锁屏没反应**：`gx_Match` 先问屏幕是否亮着。`is_screen_on` 里两个 `Parcel` 按 104 字节排布，Android 11 的 `Parcel` 是 120 字节，第二个对象压过栈保护，`gx_fpd` 在 `is_screen_on` 里 `SIGABRT`。daemon 一死，锁屏既没有成功也没有失败。栈帧从 `0x180` 加到 `0x1c0`，第二个 `Parcel` 挪到 `sp+0x120` 之后不再崩。接着交易号仍是 12。这份 Android 11 上 12 是 `wakeUp`，不是 `isInteractive`（第 16 个方法）。回复里没有整数，读出来一直是 0，芯片被切到 FF 模式 3，`fpalgo_Match_Start` 没有跑。`libfpservice.so` 里那条 `mov w1, #12` 改成 `mov w1, #16`。新库 239376 字节，`sha256 dca1195192cca524b1983fdf8e01758275cb874b973dd089f85a293b6e020950`，已推到 `/vendor/lib64/libfpservice.so`，18.1 设备树里那份也换了。
4. **枚举**：Goodix 的 `fingerprint_enumerate` 只打日志，不写结果，调用方的个数留在 100。指纹服务把这 100 个未初始化的编号当成传感器上的模板，把 `settings_fingerprint.xml` 清成空的。磁盘上的三份模板还在。HAL 改为读 `<group>/fingerprint.txt` 的第二列。新的 `android.hardware.biometrics.fingerprint@2.0-service` 是 26096 字节，`sha256 59b82bdc6bd031e080a624323b8db22a1f2680b154734247704ae66873f98d4c`。三枚记录写回 xml 之后重启框架，枚举结果是这三个编号，`Matched: true`，没有删除模板。
5. **实机**：屏幕是 Awake 时，日志是 `Screen state: 1`，接着 `fpalgo_Match_Start`。取消后 `fpalgo_MatchCancel success`，`Set mode:1`，芯片回到 `0x01`，`gx_fpd` 没有再崩。框架起来后 SystemUI 的比对同样是屏幕状态 1 和 `fpalgo_Match_Start`，结束时回到键模式。图案锁屏还在，SP handle `[redacted]`，没有改用户的图案。没有换内核，没有刷整镜像。真手指还没在锁屏上按过这一版。

同日第三十三轮：查找传感器仍停在 “please locate your fingerprint sensor”，短按是 Home。两侧电容键还在。内核仍是 `#43`（`boot-fp8.img`），没有重编。图案锁屏还在。手指还没录入完成。
1. **现象**：图案能设上。查找传感器的界面里按实了，画面不动。短按变成 Home。离开之后两侧电容键仍能用。
2. **原因**：这一按已经走完。03:39:15 图像帧 crc 49177，质量 60，有效比 100。daemon 打 `Notify type:17, msg:10, ext:1`。HAL 打 `GxFpDevice::notify(), msgType=17`，接着 `onAcquired(0)` 和 `onEnrollResult(fid=1681692777, gid=0, rem=9)`。指纹服务记下 `Acquired: 0 0`。查找传感器的界面把第一下进度当成“找到了传感器”，马上取消这次录入，然后停在那里等 `FINGERPRINT_ERROR_CANCELED`。Goodix 的 `fingerprint_cancel` 只把芯片切回键模式，不调用 `notify(FINGERPRINT_ERROR)`。日志里没有 `onError`，也没有切到录入进度那一页。短按 Home 仍是机身上那颗实体键。取消后模式是 `0x01`，所以两侧键还在。`fid` 是 Goodix 为这枚指纹生成的编号，不是读错字段。
3. **修复**：`BiometricsFingerprint::cancel()` 在原厂 `cancel` 返回成功、并且原厂没有已经上报错误时，自己调用 `onError(ERROR_CANCELED)`。源文件在 18.1 树的 `hardware/lineage/interfaces/biometrics/fingerprint/2.0/BiometricsFingerprint.cpp`。新的 `android.hardware.biometrics.fingerprint@2.0-service` 是 26056 字节，`sha256 9c5b4e865d5a8f928680cbefc8e83b3f2f2f49023138c65677a242f8144c70e1`，已推到 `/vendor/bin/hw/`。没有换内核，没有刷整镜像。
4. **实机**：重启 `vendor.gx_fpd` 和 `vendor.fps_hal` 之后，没有手指的录入探针登记了回调，取消时探针收到 `error 5 0`，HAL 打 `onError(5)`。芯片回到 `0x01`。图案锁屏还在，SP handle `[redacted]`，没有改用户的图案。查找传感器之后的录入页还没在真手指上走完，锁屏没解。

同日第三十二轮：查找传感器仍停在 “please locate your fingerprint sensor”，短按是 Home。两侧电容键还在。内核仍是 `#43`（`boot-fp8.img`），没有重编。图案锁屏还在。手指还没在这版 HAL 上录入完成。
1. **现象**：图案能设上。查找传感器的界面里，轻触和长按都没有录入反应，短按变成 Home。离开之后两侧电容键仍能用。
2. **原因**：图像已经读进 `gx_fpd`。轻的一按质量是 5、有效比 14，`Register failed ! ret=142`。按实的一按在 daemon 里到了 10%：`Notify type:17, msg:10, ext:1, ClientID:0`，算法版本 `TEE_68x118_v_1.07.18`。`NotifyClients` 找到了客户端，`notifyCallback` 的 binder 调用返回 0，驱动把 code 1 的单向交易放进指纹 HAL 的 `/dev/binder` 队列。HAL 的线程池只轮询 `/dev/hwbinder`，没有线程读这条队列，交易一直挂着。`GxFpDevice::notify` 没有进去，设置界面不动。短按 Home 仍是机身上那颗实体键。取消时芯片回到模式 `0x01`，所以两侧键还在。
3. **修复**：`hardware/lineage/interfaces/biometrics/fingerprint/2.0/service.cpp` 在 `joinRpcThreadpool` 之前调用 `ProcessState::startThreadPool()`，`Android.bp` 加上 `libbinder`。新的 `android.hardware.biometrics.fingerprint@2.0-service` 已推到 `/vendor/bin/hw/`。`libfpservice.so` 仍是 `sha256 ebad61a8bc74804bd23c95b07431f39bcbe051d619c1d7a8dd59d306ef3c125f`。没有换内核，没有刷整镜像。
4. **实机**：HAL 起来后，binder 上下文里有线程停在轮询。探针让 `gx_Register` 发出一条回调，HAL 打出 `NOTIFY_CALLBACK` 和 `fpcode, GxFpDevice::notify()`。类型 17 和 20 都在 `notify` 的分支里，17 会走到 `send_fp_scan_on`。探针取消后芯片回到 `0x01`。图案锁屏还在，SP handle `[redacted]`，没有改用户的图案。真手指还没在这版 HAL 上按过，锁屏没解。

同日第三十一轮：查找传感器仍无反应，短按是 Home。两侧电容键这次还在。boot 换成 `boot-fp8.img`（内核 `#43`），已刷。图案锁屏还在。手指还没在这版内核上按过。
1. **现象**：图案能设上。查找传感器的界面里，轻触和长按都没有录入反应，短按变成 Home。离开之后两侧电容键仍能用。
2. **原因**：录入进入状态 2 之后，手指把状态打成 `0xc0`（就绪加图像位），`g_read_flag` 是 1。`sig_handler` 打了 `Send g_fasync_sem`，接着打 `Down event should be before data`，因为 `g_touch_flag` 是 0，信号量没有发出去。读线程一直停在等这个信号量，取消时 `length = 0`。上一轮把按键样式的中断在内核里清掉了，daemon 看不到按下，所以图像帧被拒绝。短按 Home 仍是机身上那颗实体键。取消时芯片回到模式 `0x01`，所以两侧键还在。
3. **修复**：状态 2 且正在等图像时，图像中断把 `g_touch_flag` 写成 1 再发信号量，读线程就能取帧。`libfphal.so` 新库 `sha256 1c62075bade4b41f8dfc73f003b018440ba7edf61cfbbf0440d2abaafc86780f`，103840 字节，已推到 `/vendor/lib64/libfphal.so`，两边设备树里那份也换了。图像模式里带 HOME 位、没有图像位的状态也发 `SIGIO`，不再发 netlink，状态字节留给 daemon。BACK/MENU 仍由内核上报。没有刷整镜像。
4. **镜像**：`Image.gz-dtb` 12778246 字节，结束地址 `0x80c37b06`。`boot-fp8.img` 13619200 字节，`sha256 42b9f5320b063d42bb9efb45d412eba6cfdc58855488831eb27d072c92ed15c2`。cmdline 和 ramdisk 沿用 `boot-cam7.img`。已刷，读回一致。内核改动还没提交。
5. **实机**：重启后 `uname` 是 `#43`。芯片模式 `0x01`。`tiny4412-key` 的 `Classes` 是 `0x00000001`。图案锁屏还在，SP handle `[redacted]`，没有改用户的图案。没有手指的录入停在状态 2 两秒，取消后 `Set mode:1`，芯片回到 `0x01`。手指还没按到传感器上。

同日第三十轮：指纹界面仍停在 “please locate your fingerprint sensor”，短按是 Home，两侧电容键又失效。boot 换成 `boot-fp7.img`（内核 `#42`），已刷。图案锁屏还在。手指还没在这版内核上按过。
1. **现象**：和上一轮表面上一样。图案能设上。查找传感器的界面里，轻触和长按都没有录入反应，短按变成 Home。离开之后两侧电容键不再响应。`gx_fpd` 这次没有崩。
2. **原因**：`#41` 在图像模式里把每一次中断都当成图像帧，只发 `SIGIO`。轻触先到的是按键样式的状态（就绪加 HOME 位，没有图像位 6）。`sig_handler` 把它当导航事件。录入停在状态 2、`g_read_flag` 为 1 时，这串中断把读线程的等待拆掉，状态回到 1。后面真正的图像帧（状态 `0xc0`，位 7 和位 6）到来时，`sig_handler` 看到状态不是 2，把帧丢掉，界面一直停在查找传感器。设置里的取消不调用 `postEnroll`，所以 `gx_EngTest(3)` 没有跑，芯片留在模式 `0x00`。`#41` 只在键模式上报 BACK/MENU，两侧键就没了。短按 Home 仍是机身上那颗实体键，`report_home` 是 N。
3. **修复**：图像模式里只有状态同时带就绪位和图像位才发 `SIGIO`，状态字节留给读线程。其余状态由内核上报 BACK/MENU（`report_home` 仍是 N，HOME 位不会变成 `KEY_HOME`），写 0 清掉 `0x8140`，不发 `SIGIO`，也不发 netlink。`fingerprint.default.so` 的 `goodix_sensor_fp_cancel` 在收尾后转去 `goodix_sensor_fp_clear_enroll_env`，取消时也会 `ENG set KEY mode 1`，不再依赖设置去调 `postEnroll`。新库 `sha256 f6520c7d67e5ecc1716c09eaebe3304252fc71c45bffe7d0eff8fc2ba967ea2f`，755608 字节，已推到 `/vendor/lib64/hw/fingerprint.default.so`，两边设备树里那份也换了。没有刷整镜像。
4. **镜像**：`Image.gz-dtb` 12777127 字节，结束地址 `0x80c376a7`。`boot-fp7.img` 13619200 字节，`sha256 79fa6426223e8e444a8a876467981040acbd158359d3af5bc24fcfb0f3fc0bf6`。cmdline 和 ramdisk 沿用 `boot-cam7.img`。已刷，读回一致。内核改动还没提交。
5. **实机**：重启后 `uname` 是 `#42`。芯片模式 `0x01`。`tiny4412-key` 的 `Classes` 是 `0x00000001`。`gx_fpd`（pid 796）和指纹 HAL（pid 843）都在。图案锁屏还在，SP handle `[redacted]`，没有改用户的图案。没有手指的录入探针停在状态 2 两秒（`Got g_read_sem`），取消时没有调用 `postEnroll`，日志是 `Data Abort`、`Set mode:1`，芯片回到 `0x01`。手指还没按到传感器上。

同日第二十九轮：指纹界面停在 “please locate your fingerprint sensor”，短按是 Home，两侧电容键又失效。boot 换成 `boot-fp6.img`（内核 `#41`），已刷。图案锁屏还在。手指还没在这版内核上按过。
1. **现象**：图案能设上。进入查找传感器的界面后，轻触和长按都没有录入反应，短按变成 Home。离开之后两侧电容键不再响应。
2. **原因**：短按 Home 是机身上那颗实体 Home，`report_home` 是 N，指纹芯片没有上报它。轻触被芯片记成状态 `0xb0`（就绪加 HOME 位，没有图像位 6）。录入已经把模式设成 `0x00`，`gx_Register` 进入状态 2。这个按键样式的中断同时发了 `SIGIO` 和 netlink。读线程把一帧读完了，`crc = 52978`，长度 13225。netlink 那条进了 `KeyProcessThread`，`device_action` 想从状态 2 改到状态 3，被拒绝，接着 `NotifyClients` 对空的虚表槽 `blr`，`gx_fpd` 空指针退出。daemon 重启后芯片停在图像模式 `0x00`，内核只在键模式上报 BACK/MENU，所以两侧键没了。后面几次录入的 `gx_Register` 打在已经死掉的 binder 上，新 daemon 收不到。
3. **修复**：图像模式里 `fasync` 已经登记时，中断只发 `SIGIO`，不再发 netlink，状态字节留给读线程。键模式的按键上报和 netlink 不动。`libfpservice.so` 里 `dataCallback`、`notifyCallback`、`gx_SetPWD` 的两个 `Parcel` 按 Android 11 的 120 字节错开，栈帧从 `0x120` 加到 `0x150`，否则图像回调发出去时回复对象会压过栈保护。新库 `sha256 ebad61a8bc74804bd23c95b07431f39bcbe051d619c1d7a8dd59d306ef3c125f`，239376 字节，已推到手机，18.1 树里那份也换了。没有刷整镜像。
4. **实机**：重启后 `uname` 是 `#41`。芯片模式 `0x01`。`tiny4412-key` 的 `Classes` 是 `0x00000001`。`gx_fpd` 和指纹 HAL 都在。这次开机没有新的 `gx_fpd` tombstone。图案锁屏还在，没有改用户的图案。

同日第二十八轮：设置密码回退、设置崩溃、电容键一起失效。boot 换成 `boot-fp5.img`（内核 `#40`），已刷。密码能写入并清掉。指纹录入还在等手指。
1. **现象**：第一次设锁屏好像成功，接着录入指纹时锁屏回到滑动，指纹界面说已经设过屏幕锁定。再试一次，设置进程崩溃，两侧电容键也不再响应。
2. **密码和崩溃**：芯片没有参与。`dumpsys lock_settings` 里 User 0 的 `CredentialType` 一直是 None，`Quality` 是 0。`LockSettingsService` 在 `Initialize SyntheticPassword` 之后打 `Device does not support weaver`，`gatekeeperd` 打 `has no HAL to talk to`，`setLockCredential` 在 `createPasswordBasedSyntheticPassword` 里失败。界面仍进了 `RedactionInterstitial`，所以看起来像设上了。指纹介绍页接着用 `request=1` 收回 `result=1`、`data=null`，`BiometricEnrollIntroduction.onActivityResult` 对空 Intent 取 `getByteArrayExtra`，空指针把设置打崩。设备上没有 `IGatekeeper`。`keymaster@4.0-service` 是在的。
3. **电容键**：和设置崩溃是两件事，和指纹驱动有关。`gf816m_keys` 把 `KEY_CNT` 里的每个键都放进 `keybit`，其中有 `BTN_TOUCH`。`EventHub` 看到 `BTN_TOUCH` 且没有 `ABS_X`/`ABS_Y`，把 `tiny4412-key` 标成外部手写笔（`Classes 0x00000800`），键盘类被拿掉，`tiny4412-key.kl` 用不上。`gx_fpd` 打开 `/dev/goodix_fp` 并登记 `fasync` 之后，按键中断只发给 daemon。空闲时的 `GF_Navigation` 只记 `NAV: Idle state`，不注入按键。崩溃之后的日志里 BACK、HOME、MENU 的状态字节（`0x8c`/`0x88`、`0xb0`/`0xa0`、`0x83`/`0x82`）都走了这条路径。
4. **修复**：`device.mk` 加上 `android.hardware.gatekeeper@1.0-service.software`。二进制、rc 和 VINTF fragment 推到 `/vendor`，18.1 树的 `device.mk` 同步了。主清单没有再写一份 `IGatekeeper`。内核只广告 `KEY_HOME`、`KEY_MENU`、`KEY_BACK`。`fasync` 已登记且中断不是图像帧（状态位 6）时，键模式仍由内核 `gf_report`，`0x8140` 留给 daemon 清，非图像中断继续发 netlink。没有刷整镜像。失败那次留下的 `0000000000000000.e0` 和 `.p1` 已删，当时凭据类型是 None。
5. **实机**：`uname` 是 `#40`。`lshal` 有 `IGatekeeper/default`。这次开机日志里没有 `has no HAL to talk to`。`locksettings set-pin 2580` 成功，`CredentialType` 变成 Pin，`SID` 非 0；马上 `locksettings clear --old 2580`，回到 None。手机上没有留下这组数字。`tiny4412-key` 的 `Classes` 是 `0x00000001`，布局是 `/vendor/usr/keylayout/tiny4412-key.kl`，`getevent -p` 只有 `0066`、`008b`、`009e`。`gx_fpd` 仍打开着 `/dev/goodix_fp`。向 `event2` 注入 `KEY_BACK` 后，按键灯亮度读到 40。手指还没按到传感器上，两侧电容垫也还没在新内核上按过。

同日第二十七轮：7M 指纹录入。boot 换成 `boot-fp4.img`（内核 `#39`），已刷。校准完成了，录入停在等手指。锁屏还没解开。
1. **现象**：`gx_fpd` 起来后校准进入状态 2 就出不来，`gx_Register` 返回 145，算法状态停在 11。芯片模式一直是 `0x01`（按键）。更早一次 `connect` 直接栈检查失败。
2. **原因**：三处叠在一起。`libfp_client.so` 按 Android 6 给每个 `Parcel` 留了 104 字节，Android 11 的 `Parcel` 是 120 字节，回复对象压过栈保护。键模式下内核中断会清掉 `0x8140`，也没有 `SIGIO`，HAL 的 `fasync` 等不到。图像就绪是状态位 6。这个中断如果同时发给 netlink，`GF_Navigation` 马上把位 7 清掉，`get_package_data` 就丢掉这一帧。`/dev/goodix_fp` 原先也没有 `read()`，帧读取返回 -1，日志是 `len = -1`。
3. **修复**：`fingerprint/libfp_client.so` 里 27 个 `Bp` 函数的回复槽加宽到 136 字节，`sha256 dc63ca907158b739974e4eae96e5b3c0218310015e2db14a4a8efd74587f9447`，已推到手机。内核在 `fasync` 登记之后把状态字节留给用户态，并发 `SIGIO`。位 6 的图像中断不再发 netlink，按键中断仍然发。`read()` 从 `0x8141` 读一帧，长度 13225，末尾两字节是前面负载的 16 位和。daemon 没打开设备时，按键仍由内核上报。没有刷整镜像。
4. **实机**：重启 `gx_fpd` 后日志是 `SUCCESS: crc = 35072, len = 13225`，状态从 2 回到 1，写出 `/data/system/fingerprint/localCailibration.dat`（32184 字节），`k` 是 8192，然后回到键模式 `0x01`。HIDL `enroll` 返回 0，`Set mode:0`，`gx_Register` 返回 0，停在状态 2。12 秒后 `cancel`，回到状态 1 和键模式。没有按手指，所以没有录入完成，也没有设锁屏密码，锁屏没解。

同日第二十六轮：两侧电容键的按键灯不亮。boot 换成 `boot-keys.img`，已刷。`uname` 仍是 `#35`，只重编了设备树。
1. **现象**：按下两侧电容键，按键灯完全不亮。上一轮亮度条把 `lights.msm8996` 的 BUTTONS 做成空实现，当时写成「这台机器没有按键灯」。那个判断不对。
2. **原因**：原厂设备树用 PM8994 的 MPP4（`0xa300`）做电流沉，名字是 `button-backlight`，20 mA，手动模式。现在的板级设备树包含了 MTP 的 `msm8996-mtp.dtsi`，那份把 MPP4 配成 HDMI 5V 的数字输出。灯的 class 节点因此不存在，灯光服务写不进去。PowerManager 的按键灯超时是 5 秒，亮度默认是 1.0，框架一直在写 BUTTONS。
3. **修复**：板级设备树关掉 MTP 的 MPP4 数字输出，按原厂参数加上 `qcom,leds-qpnp` 的 `button-backlight`。`liblight/lights.c` 的 BUTTONS 改为写 `/sys/class/leds/button-backlight/brightness`。这是 sysfs，不走面板的 DCS。`init.gree.rc` 把节点交给 `system`。32 位和 64 位 `lights.msm8996.so` 已推到手机。没有刷整镜像。
4. **实机**：节点在，`max_brightness` 是 40。写 0 读回 0，写 40 读回 40。`input keyevent KEYCODE_BACK` 之后读到 40，约 6 秒后回到 0，和 5 秒超时一致。

同日第二十五轮：GPS。原先没有定位引擎。现在 `gps` provider 已登记，换到能收到天空的位置后已经定位。没有动内核，当时的 boot 是 `boot-cam7.img`（`#35`）。没有刷整镜像。
1. **原先**：位置开关是开的，但 `dumpsys location` 只有 `passive` 和 `fused`，`last location` 为空。没有 `android.hardware.gnss` 进程，主清单里没有这项 HAL，`/vendor` 下也没有 `gps.default`、`libloc_api_v02.so` 和 `gps.conf`。`qmuxd` 和 `/dev/socket/qmux_gps` 本来就在。
2. **接上的栈**：Android 11 只认 `IGnss`。用 Lineage 的 `android.hardware.gnss@1.0-service.legacy` 去加载 `gps.default`。`gps.default`、`libloc_core`、`libloc_eng`、`libgps.utils` 从 `hardware/qcom/gps/msm8996` 编。`BOARD_USES_QCOM_HARDWARE` 会跳过 `hardware/qcom/gps`，所以 `gps/Android.mk` 直接把 msm8996 的 makefile 拉进来。2017 年的 64 位 `libloc_api_v02.so` 拷到 `gps/`，经 QMI 跟调制解调器说话。`IGnss` 1.0 只加在主清单里，没有再做一个 fragment。`init.gree.rc` 补了 `/data/misc/location` 的三个目录。`gps.conf` 打开了 XTRA 和 `supl.google.com:7275`。传感器那个 `liblocationservice.so` 桩没有换掉，也没有起 `loc_launcher`。
3. **和 2017 年库对齐的两处**：`LocApiBase` 补了非虚函数 `reportGpsMeasurementData(GpsData&)`，否则 `libloc_api_v02.so` 加载时缺符号。这份库把每颗星写成 24 字节的旧 `GpsSvInfo`（size、32 位 prn、snr、仰角、方位角），现在的 `GnssSvInfo` 是 32 字节。`reportSv` 认出 `size == 24` 后按旧布局拆开，再填成现在的结构。这两处改在 18.1 树的 `hardware/qcom/gps/msm8996/core/`，不在本仓库。
4. **实机**：重启后 `android.hardware.gnss@1.0-service.legacy` 以 `gps` 用户起来，`lshal` 有 `IGnss/default`，进程映射里有 `libloc_api_v02.so`。`gps` provider 的能力是 `0x37`。桌边第一次请求只有星号、CN0 全是 0，40 秒没有经纬度。QMI 打过 `Shim layer present. Do not use QMUXD` 和 `rc=-6`，星号仍然从调制解调器来。`/data/misc/location/xtra/socket_hal_xtra` 不存在，XTRA 守护进程没起。手机换到房间另一侧后，F-Droid 的 GPS Cockpit（`org.woheller69.gpscockpit`）在请求定位。`dumpsys location` 的 `gps` provider 已有定位：水平精度 3 米，高度 98 米，14 颗星，最大 CN0 34、平均 23。首次定位 73 秒，随后 78 次上报，精度均值约 4.1 米，最强 4 颗的平均 CN0 约 32 dB-Hz，参与定位的是 GPS 和 GLONASS。Wi-Fi 仍连着 `Not 6GHz`，地址 `10.0.0.110`。

同日第二十四轮：下拉亮度条拖动卡顿。boot 换成 `boot-cam7.img`（内核 `#35`），已刷。
1. **现象**：亮度条拖起来一顿一顿的，松手后的亮度是对的。拖动期间 `LightsService` 反复打 `Excessive delay setting light`。每次手势开头还有一条 `Light requested not available on this device. 2`。
2. **原因**：这块屏的背光是 DCS 命令。`CMD_REQ_DCS` 让每次写入都拿着 DSI 的 `cmd_mutex` 去等下一次 TE，双口再等一次。30 次 sysfs 写入用了 1041 ms。帧提交排在这把锁后面，拖动时 SystemUI 帧时间中位数 61 ms、90 分位 97 ms，93% 的帧算 jank。类型 2 是 BUTTONS。这台机器没有按键灯，`lights.msm8996` 没实现，PowerManager 每次用户活动都会写一次。
3. **修复**：`mdss_fb_set_bl_brightness` 只记下最新亮度就返回。工作队列在锁外面等 TE，然后发一次命令。广播只从 trigger 口发，不再两个口各等一遍。背光命令去掉 `CMD_REQ_DCS`，避免在 `cmd_mutex` 里再等一次。`liblight/lights.c` 给 BUTTONS 一个空实现。32 位和 64 位 `lights.msm8996.so` 已推到手机。没有刷整镜像。
4. **实机**：30 次 sysfs 写入 18 ms，读回来的是最后一次写入的值。拖动时 `LightsService` 没有新日志。亮度条帧时间中位数约 23 ms，普通下拉列表是 21 ms。90 分位大约 57 ms，原来是 97 ms。

同日第二十三轮：相机打开时两侧触摸键不振动。boot 换成 `boot-cam6.img`（内核 `#34`），已刷。细节见 7J 的“相机打开时两侧键不振”。
1. **现象**：系统相机预览时，底部两个电容键按下没有振动。关掉相机就恢复。
2. **原因**：传感器 `power_up` 成功后把 DRV2605 的 `disable_refcnt` 加一，`vibrator_enable` 在这期间直接返回。预览一直占着传感器。框架仍把按键记成 `Virtual Key - Press`。
3. **修复**：去掉 `msm_sensor.c` 里对 `drv2604_disable_haptics` / `drv2604_enable_haptics` 的调用。
4. **实机**：预览中 BACK 和 MENU 都会让 `enable` 读到非 0，和关掉相机时同一段大约 10 ms 的点击。相机开着时写 800 ms 也能倒计时。

同日第二十二轮：CPU 约 25%、内存少了约 1 GB。没有刷内核。
1. **现象**：四个核里有一个长期满载，整机大约 25%，两簇频率都顶在最高。`MemAvailable` 从今天下午的 2200 MB 左右掉到约 1600 MB。`/cache` 248 MB 用了 98%。
2. **原因**：`init.gree.rc` 的 `on post-fs` 每次开机执行 `start bootlog`，`logcat` 无限制地写 `/cache/boot-logcat.txt`。文件到 221 MB 后分区满了，进程还在跑，RSS 约 550 MB，占满一个核。频率锁死是另一件事：内核 `CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE=y`，没有 `schedutil`，开机后两簇一直是 `performance`。
3. **修复**：去掉自动 `start bootlog`，服务仍留着，要查日志时手动 `start bootlog`。`on boot` 把 `policy0` 和 `policy2` 的 governor 写成 `interactive`。删掉 `/cache/boot-logcat.txt`。`init.gree.rc` 已推到手机，18.1 树里那份也同步了。
4. **实机**：停掉之后 `logcat` 不在了，`/cache` 剩 226 MB，`MemAvailable` 回到 2168 MB，大核降到 307 MHz。重启后再确认：`bootlog` 没有起来，`MemAvailable` 2244 MB，`interactive` 还在，小核降到 422 MHz。Wi-Fi 仍连着，地址 `10.0.0.110`。

同日第二十一轮：Wi-Fi 开关弹回。细节见 7B 的“开关弹回”。
1. **现象**：设置里打开 Wi-Fi，大约 1 秒回到关闭。`wlan0` 能起来，固件版本还在。
2. **原因**：`ISupplicant` 在主清单和 fragment 里都不在。框架退回 1.0，列不出接口。
3. **修复**：把 `wpa_supplicant` 自带的 VINTF fragment 推回 `/vendor/etc/vintf/manifest/manifest.xml`，重启。
4. **实机**：自动连上 `Not 6GHz`，5765 MHz，433 Mbps，地址 `10.0.0.108`。没有改设备树，没有动内核。

同日第二十轮：7L 补记，系统相机预览冻结和无法连接。boot 换成 `boot-cam5.img`（内核 `#33`），已刷。细节见 7L 的“预览冻结”。
1. **现象**：后摄预览两秒定住，切前摄几秒后定住，之后再开相机报无法连接。三种都从 VFE 的 `Drop frame no reg update` 开始。
2. **原因**：内核 2017 年的 `a9b5f6afbbea` 把错过 reg update 的缓冲区留给下一个 SOF，并在每次 `request_frame` 后拒收同一 SOF 的请求。2016 年的原厂 daemon 不配合，缓冲区卡死，后面的会话 `CFG_STREAM` 超时，daemon 收尾崩溃。
3. **修复**：`msm_isp_drop_frame` 退回只报丢帧，`msm_isp_request_frame` 不再清 `accept_frame`。
4. **实机**：后摄 25 秒、前后摄切 6 次、冷启动 6 次、压满 CPU 时后摄 40 秒，预览一直在动，没有丢帧、`OUTPUT_ERROR` 或 daemon 崩溃。前摄停流有时多等 3 秒，重试后能停。没有改用户态文件，整镜像不用重编。内核改动还没提交。

同日第十九轮：7L 相机通过。前后摄都能预览、拍照、录短视频，系统相机冷启动后能拍照。boot 换成 `boot-cam4.img`，已刷。细节见 7L。
1. **ioctl 尺寸**：原厂库和内核只差两条。`ISP_CFG_STREAM` 是 8 路 handle、不带 `dummy` 的 44 字节，`boot-cam3` 的翻译读错了 `cmd` 的位置。`ISPIF_CFG` 是 368 字节，缺小米加的 `reserved_param`。两条都在内核里翻成现有结构。
2. **`openCamera` 崩溃**：HAL 在栈上放 Android 6 大小的 `Parcel`，给 `display.qservice` 发消息时写越界。`libgu2.so` 补了 `IQService::asInterface` 和 `Parcel` 的空实现。
3. **原厂库**：补 18 个 32 位库，有 JPEG 编码链、3A 核心、tintless、faceproc。拍照不再报 `OMX_GetHandle`，AEC/AWB/AF 不再是 dummy。
4. **gralloc 句柄**：新旧 `private_handle_t` 字段顺序不同，HAL 读到的大小是 `width` 或 0。`camera.msm8996.so` 改两条 `ldr` 的偏移，拍照不再在 `OMX_ImgEnc` 里崩溃。
5. **录像**：UBWC 缓冲区和新 gralloc 对不上，CPP 访问 IOVA 0 后 daemon 退出。`persist.camera.{preview,video}.ubwc=0` 之后不再有 page fault。
6. **系统相机**：补 `/vendor/etc/media_profiles_V1_0.xml`，重启后系统相机能打开并拍照。有一次冷启动 provider 报 0 个设备，原因没找到。
7. **整镜像**：`system-7l.img` 编出来了，`sha256 205516952e2dd68c8d42e8cd5008be2f80bd7a25eae6aed49a0ee114dc138191`，没有刷。18.1 树里漏的 CPP 固件和两个旧 rc 已经补上。内核改动还没提交。

同日第十八轮：7L 仍未出图。两颗相机已经登记（后摄 90 度，前摄 270 度）。vsync 事件长度和 `display.qservice` 所在的 binder 已经对上。ISP 的 `CFG_STREAM` 从 44 字节翻成内核的 48 字节，boot 换成 `boot-cam3.img`，已刷。打开后摄仍在 `openCamera` 里崩溃，没有预览、照片或短视频。整镜像没编。细节见 7L。

同日第十七轮：7L 相机还没出图。两颗传感器能 probe，会话能建起来，静态参数不再是空指针，provider 停在 vsync 线程的 `Looper::pollInner` 崩溃。细节见 7L。boot 换成 `boot-cam2.img`，已刷。整镜像没编。

同日第十六轮：7K 硬件视频与音频编解码，Venus H.264 硬件解码/编码与 ADSP AAC 硬件解码全部通过，细节见 7K。没有动内核和 boot。
1. **Venus 视频编解码**：补齐 OMX 组件、`media_codecs.xml` 与 `mediacodec.policy`，并在 `MediaCodecList.cpp` 保留 `sOmxInfoBuilder`，解除软件 Codec2 输入 surface 对 OMX 硬件编码器的屏蔽。
2. **ADSP AAC 解码根因**：MSM8996 的 `adsp.b08` 仅内置 MP3，AAC 需在打开 `/dev/msm_aac` 时经 `adsprpcd` 从 `/dsp`（`/vendor/dsp`）动态加载 `HeaacDecoderModule.so.1`；而原厂 Android 6 的 `libadsprpc.so` 打开 `/dev/adsprpc-smd` 后未调 4.4 内核要求的 `FASTRPC_IOCTL_GETINFO`（域 0），导致 `FASTRPC_IOCTL_INIT` 失败。
3. **修复**：新增 32/64 位 `libfrp.so` 并在 `libadsprpc.so` 中替换未使用的 `libc++.so` 依赖，在打开 `/dev/adsprpc-smd` 时自动完成域 0 初始化；补上 `/dsp -> /vendor/dsp` 根符号链接、`adsprpcd` 服务、`libOmxAacDec.so` 及 `vendor.media.omx` 的 `audio` 组权限。
4. **实机与整镜像**：冷启动后 `adsprpcd` 稳定运行，`OMX.qcom.audio.decoder.aac`（解码 `92160` 字节 PCM）、`OMX.qcom.video.decoder.avc` 与 `OMX.qcom.video.encoder.avc` 均验证通过。`system-7k.img` 已编出，`sha256 6f62d3e714f6ddf05820003783777c255202916af1e8cfa563d71d50332479b4`，没有刷。

## 步骤 8：收口

推荐：7I 到 7M 都有一次通过的记录，这一阶段就停。下一步才是阶段 4：从 userdata 划出 vendor，再把板级目录接回小米 `lineage-22.2` 的 `msm8996-common`。

硬件编解码、相机出图或指纹解锁还没有记录时，不改分区表。

### 实现笔记

（尚无）

### 事件

（尚无）

## 本阶段不做

- 不把本仓库现有的 `BoardConfig.mk` 改去继承 18.1，阶段 4 还要用现在这份对 `msm8996-common` 的留白
- 不重编内核，除非步骤 6 退回来。例外：7H 的两侧电容键需要新驱动，内核重编为 `#19`；7C 的声卡要改 DTS 和两处驱动崩溃，镜像为 `boot-audio9.img`。7J 的 DRV2605 没有绑定，内核重编为 `#27`，镜像为 `boot-vibe.img`。7L 的相机设备树和 ioctl 尺寸要对上 Android 6 HAL，镜像先后是 `boot-cam2.img`、`boot-cam3.img`、`boot-cam4.img`、`boot-cam5.img`、`boot-cam6.img`、`boot-cam7.img`、`boot-keys.img`。7M 的 GF816M 要把图像帧交给 `gx_fpd`，镜像先后是 `boot-fp4.img`、`boot-fp5.img`、`boot-fp6.img`、`boot-fp7.img`、`boot-fp8.img`，当前 `uname` 是 `#43`
- 不另编一版新 TWRP，也不格式化 data。步骤 1 只把 recovery 刷回 2016 年那份能读 footer 的镜像
- 不动 aboot、xbl、tz、rpm、hyp、cmnlib、keymaster、modemst、fsg、persist、dsp
- 不刷 `third_party/` 里的卡刷包
- 不同步 20、21、22.2 的整份用户态来替代 18.1
- 不把一加 3 的面板、Synaptics、FPC 指纹和 IMX 相机配置写进格力
- 不把 4 KB 页改成 16 KB
