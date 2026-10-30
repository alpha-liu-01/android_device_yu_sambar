# YU Yutopia（sambar）可行性与路线图

日期：2026-10-29。依据是这份 cm-13.0 设备树、`/home/alpha/Documents/GitHub/android_kernel_cyanogen_msm8994`、`third_party/` 里的包，以及当天通过 adb 对这台正在运行的 YUTOPIA 做的只读检查。手机没有重启到 fastboot，没有写入任何分区，也没有新建 git 分支。

## 结论

值得做。第一目标是 Android 11（LineageOS 18.1）。同一颗 MSM8994 上，一加 2 的官方维护停在 Android 10，公开的非官方移植已经用 Linux 3.10 启动过 Android 11、12.1 和 13。Yutopia 的板级和一加 2 不同，所以那些 ROM 不能直接刷，但平台路径是有人走过的。

Android 16 和 17 不作为目标。硬盘上的 `lineage-23.2` 是 Android 16 用户态，里面没有一份还能编译的 MSM8994 内核。公开范围内没有 MSM8994 设备把 3.10 内核抬到 Android 14 以后。system 分区只有 3 GiB，Android 14 及以后的完整系统镜像也放不进去。

当前这份 cm-13.0 树留在原地，角色是 2015–2016 年的板级档案。移植开始时另开分支，不把现有历史挪走。内核仓库就是该用的那一份，见下一节。

## 实机快照

adb 状态是 `device`，序列号 `012345ABCDE`（这个字符串本身像 bootloader 的占位序列号）。`adb root` 没有把 adbd 提权，shell 仍是 `uid=2000`。`/sbin/su` 和 `/sbin/magisk` 都在，`su -c id` 约 11 秒后返回 Permission denied，这次会话没有拿到 Magisk 授权。因此 cmdline、运行中的设备树 model、`/proc/config.gz` 都没读到。下面的硬件项来自 getprop、sysfs 和输入设备名。

| 项目 | 实机 |
| --- | --- |
| 型号 | YU YUTOPIA / YU5050，`ro.cm.device=sambar`，`ro.hardware=qcom` |
| 系统 | 非官方 LineageOS 13.0，`13.0-20171020-UNOFFICIAL-sambar`。构建者 `kutep0v@normandy`，`userdebug` / `test-keys`，`ro.debuggable=1` |
| 构建指纹 | `YU/YUTOPIA/YUTOPIA:6.0.1/MOI10E/bda6cc43b0:userdebug/test-keys` |
| 构建日期 | 2017-10-20，安全补丁 2017-10-01 |
| 与仓库的关系 | 与 `third_party/lineage-13.0-20171020-UNOFFICIAL-sambar.zip` 的版本号一致。不是 CyanogenOS。CyanogenOS 停在 12.1 |
| SoC | `machine=MSM8994`，`family=Snapdragon`，`soc_id=207`，`revision=2.1`，`vendor=Qualcomm`，`hw_platform=MTP` |
| CPU | 可能 0–7。检查时只有 0–3 在线，都是 Cortex-A53（part `0xd03`），最高 1.5552 GHz。`/proc/cpuinfo` 里出现过一颗 Cortex-A57（part `0xd07`）。`core_ctl.ko` 已加载 |
| 内存 | `MemTotal` 3809172 kB，对应 4 GB 规格 |
| 存储 | eMMC，`ro.boot.bootdevice=f9824900.sdhci`，整盘约 29.1 GiB |
| 显示 | 1440x2560，dpi 560，framebuffer `mdssfb_90000` |
| 面板 | sysfs：`dual 0 sharp cmd mode dsi panel`。设备树专有文件里有同名校准 `pp_calib_data_dual_0_sharp_cmd_mode_dsi_panel.xml` |
| GPU 声明 | 设备树写 Adreno 430。`ro.opengles.version=196609`（OpenGL ES 3.1） |
| 触控 | `atmel_mxt_ts_T100_touchscreen`。专有文件里有 `A4_15_2.2_AA.fw` |
| 指纹 | Silead。输入设备 `silead-vinput-keypad`，`fingerprintd` 与 `fpsvcd` 在跑 |
| 传感器 | ST LSM6DS3 加速度计和陀螺仪，`yas537_mag`，`alps_pressure`，光感，距离，霍尔 |
| 音频 | 声卡名 `msm8994-tomtom-mtp-snd-card`。tomtom 是这颗 SoC 上 WCD9330 在 CAF 里的代号。喇叭功放是 NXP TFA9887 |
| 无线 | Wi-Fi 驱动是模块 `wlan.ko`。蓝牙是 QCA Rome，固件单独分区 |
| 相机声明 | 设备树写 `imx230` 与 `ov8865`，`BOARD_QTI_CAMERA_32BIT_ONLY`。`persist.camera.HAL3.enabled=0` |
| 启动链 | bootloader `sambar-12-g5c5fdd4`。没有 A/B，没有 vendor / odm / product / super |
| 加密 | `ro.crypto.state=unencrypted` |
| 解锁相关 | `sys.oem_unlock_allowed=1`。已经在跑第三方系统和 Magisk，bootloader 应当已经解锁。fastboot 里的 `device-info` 还没读，这次没有重复执行 `oem unlock` |
| Root | Magisk，systemless，挂在 `/sbin`。清掉 `/data` 会一起清掉这份 root |

分区大小用 sysfs 的 512 字节扇区数核对过。system、boot、recovery、cache 与 `BoardConfig.mk` 一致。

| 分区 | 大小 | 说明 |
| --- | --- | --- |
| boot / recovery | 各 64 MiB | `mmcblk0p35` / `mmcblk0p36` |
| system | 3 GiB（df 可见约 2.9 GiB，已用约 853 MiB） | `mmcblk0p37`，ext4 |
| cache | 256 MiB | `mmcblk0p38`，f2fs |
| persist / persistbak | 各 32 MiB | `mmcblk0p32` / `mmcblk0p33` |
| modem | 80 MiB | `mmcblk0p34`，vfat，挂在 `/firmware` |
| bluetooth | 1 MiB | `mmcblk0p12`。df 把它显示成 1.0G，那是 vfat 的错误容量，扇区数是 1 MiB |
| modemst1 / modemst2 / fsg | 各 4 MiB | 基带校准，相当于高通机上的 EFS |
| userdata | 51600416 扇区，约 24.6 GiB | `mmcblk0p39`，f2fs，未加密 |
| append | 约 956 MiB | `mmcblk0p40`，未挂载。名字如此，先当作保留空间，不拿来扩 system |
| 启动链 | sbl1、tz、rpm、hyp、aboot 及各自的 bak，另有 keymaster 所在的 keystore、config（FRP） | 不能拿来扩容，也不要用一加 2 的对应镜像覆盖 |

## 内核树是这一份

`/home/alpha/Documents/GitHub/android_kernel_cyanogen_msm8994` 就是 `BoardConfig.mk` 和 `cm.dependencies` 点名的树。

- `Makefile` 是 3.10.84，与实机 `uname` 的版本号一致
- 当前分支 `cm-13.0`，tip `aa1ca16`（2016-07-08）
- `arch/arm64/configs/cyanogenmod_sambar_defconfig` 存在，里面打开了 `CONFIG_ARCH_MSM8994`、`CONFIG_TOUCHSCREEN_ATMEL_MXT_PM9X`、`CONFIG_SILEAD_DEVICE`
- 板级 DTB 不叫 sambar。64 位树里是 `msm8994-v2.1-pm9x-dvt3.dts` 和 `msm8994-v2.1-pm9x-pvt.dts`，model 都写着 Compal PM9X，`compatible` 是 `qcom,msm8994-mtp`。DVT3 的 `qcom,board-id` 是 `<25 0x04>` 一组，PVT 是 `<25 0x05>` 一组。实机 `revision=2.1`，与这两份 DTS 的 v2.1 一致。具体落到哪一份，要等 root 读到运行中的 `qcom,board-id`
- 远端的 `cm-14.1` 和 `cm-13.0` 是同一个 commit。官方内核没有在 14.1 上再往前走
- 实机内核是 `3.10.84-lineageos-gc7efee3`，2017-10-20 由 kutep0v 编译。defconfig 里的 `CONFIG_LOCALVERSION` 是 `-cyanogenmod`，所以这不是 `aa1ca16` 的原样产物。短哈希 `c7efee3` 不在这份克隆里

因此：板级事实以这份 Cyanogen 树和实机 sysfs 为准；2017 年那颗 boot 里的内核多出来的提交，等备份出 boot 镜像后再对照。Android 10 以后不要直接拿 2016 年的 defconfig 当编译目标，把 sambar 的 DTS 和 defconfig 差额移到一加 2 那份已经背过多年补丁的 3.10 上。

`BoardConfig.mk` 写明 Wi-Fi 必须编成模块，否则设备起不来。换内核时保留这一点。

## fastboot 和 `-i 0x2A96`

指南把两件 2015 年的问题写在了一起。这台电脑上只剩下一件还可能碰到，而且现在还没碰到。

YU 的 USB 厂商号是 `0x2A96`（Micromax / YU）。2015 年的 fastboot 只认一份写死的厂商号名单，名单里没有 `0x2A96`，所以要 `fastboot -i 0x2A96`。同一份指南里的“驱动”是 Windows 的 WinUSB：Google 的驱动包不包含这个厂商号，设备管理器里会显示未知设备。

这台电脑是 Linux，fastboot 是 platform-tools 37.0.1，装在 `/home/alpha/Android/Sdk/platform-tools/fastboot`。它的 `--help` 里已经没有 `-i`。这个版本按 USB 接口类认 fastboot 设备：class `0xFF`、subclass `0x42`、protocol `0x03`。高通 LK 的 fastboot gadget 使用的就是这个接口类，厂商号不再参与匹配。

Android 里 `lsusb` 是 `2a96:3014`。2026-10-29 进 bootloader 后重新枚举成 `2a96:301c`，接口类 `ff/42/03`，`fastboot devices` 不带 `-i` 就能列出。细节在 `docs/sambar-phase-0.md`。

`/etc/udev/rules.d/` 里没有 Android 规则。进 bootloader 之后如果 `fastboot devices` 为空，按这个顺序看：

1. `dmesg` 里有没有新的 `2a96:` 设备。
2. `lsusb -v -d 2a96:` 里接口是不是 `ff/42/03`。是的话，现代 fastboot 认得出它，空列表是权限问题。给当前用户加一条规则后重新插拔：

```
SUBSYSTEM=="usb", ATTR{idVendor}=="2a96", MODE="0660", GROUP="plugdev", TAG+="uaccess"
```

3. 接口类不是 `ff/42/03` 时，37.0.1 确实看不见这台设备，而 `-i` 已经没了。这时用仍保留 `-i` 的旧 platform-tools（25.0.x 那一代），只拿它做 `devices`、`oem device-info`、`flash`、`reboot`。不要把旧 fastboot 的行为修回现在这份 37.0.1。

`oem unlock` 先不要跑。这台机器已经在跑 2017 年的非官方系统，解锁这一步应当早就做过。旧 bootloader 上重复 `oem unlock` 常常会清 data。等备份完成、进了 fastboot，用 `fastboot oem device-info` 或 `fastboot getvar unlocked` 看状态。只有明确仍是 locked 时才解锁，并且先接受 data 会被清掉。

XDA 那套原厂恢复工具不用碰。回退点是下面的分区备份，加上 `third_party/` 里已经有的包。

## 版本怎么选

同一颗 SoC 上已经有人走到哪一步，是这台手机的上限。一加 2（codename `oneplus2`）官方 LineageOS 到 17.1（Android 10），内核仓库是 `android_kernel_oneplus_msm8994`，版本 3.10。维护者 mukul2259 的设备和内核仓库在 2026-10-29 还有 `lineage-18.1` 直到 `lineage-23.2` 的分支名。官方内核仓库停在 `lineage-18.0`。分支名不等于这台 Yutopia 能启动那个版本。阶段 1 仍从 18.1 开始。

| Android | LineageOS | 这颗 SoC 上的公开状态 | 对 Yutopia |
| --- | --- | --- | --- |
| 6.0.1 | 13.0 | 正在运行，本仓库当前分支 | 板级档案和 blob 来源 |
| 7.1 | 14.1 | `LineageOS/android_device_yu_sambar` 的默认分支是 cm-14.1，最后推送 2021-12-11。本克隆的 upstream 是 CyanogenMod 仓库，没有这个分支。内核 cm-14.1 与 cm-13.0 同 commit | 下一次要抓的参考树，仍然是 Android 7 |
| 8.1–10 | 15.1–17.1 | 一加 2 官方。17.1 是官方终点 | 平台对照。17.1 可以作为 18.1 起不来时的退路 |
| 11 | 18.1 | 一加 2 非官方，3.10 | 第一目标。硬盘上已有完整用户态树 |
| 12.1 | 19.1 | 一加 2 非官方，3.10，SELinux permissive | 18.1 稳定之后的可选台阶 |
| 13 | 20 | 一加 2 非官方，公开文章到 2023 年，3.10 | 拉伸目标。3 GiB 的 system 会很紧 |
| 14–17 | 21 及以后 | mukul2259 的仓库有同名分支，尚未在这台手机上验证 | 不作为阶段 1。硬盘上的 `lineage-23.2` 先不用 |

和格力 G0215D 的差别在内核捐赠者。那台骁龙 820 可以站到小米一直维护到 Android 15 的 3.18 树上。Yutopia 没有对应的东西：MSM8994 的公共内核停在 3.10，最远的实测用户态是 Android 13。触控芯片是同一类 Atmel maXTouch，这一点可以从格力那次移植里直接借用经验；面板、指纹、功放、相机和分区不能借用。

一加 2 和 Yutopia 不能混刷的部分：

- 面板。一加 2 是 1080p，这台是 Sharp 双 DSI command mode 的 1440x2560
- 指纹。这台是 Silead，专有库在 `proprietary-files.txt` 里，一加 2 的 vendor 没有
- 喇叭功放 TFA9887
- 相机 `imx230` / `ov8865`，而且现有 HAL 把 Camera2 关掉了
- 基带、tz、rpm、hyp、aboot。固件留在 Yutopia 自己的分区里

可以共用的部分是 SoC 级的：Adreno 430 的显示合成、同一代 CAF 音频机器驱动、WCNSS Wi-Fi、QCA Rome 蓝牙、RIL 的框架，以及一加 2 内核里为了 Android 10–13 补上的 bpf、binder、cgroup 一类补丁。

system 分区决定了后半段。df 上可用空间约 2.0 GiB，分区本身 3 GiB。Android 11 的精简 Lineage 镜像放得下。Android 13 的完整镜像会顶到边缘，GApps 很可能放不下。`append` 那 956 MiB 看起来像盘尾保留，改 GPT 去吃它或去切 userdata，留到 18.1 已经能日常使用、并且确认镜像尺寸不够的时候再单独做。

boot 64 MiB 对 3.10 的 Image 加 ramdisk 足够。一加 2 的 18.1/20 boot 镜像远小于这个上限。

## 硬盘上的树

路径在 `/run/media/alpha/YMTC/`。不要再同步一份完整的 LineageOS。

| 路径 | 用途 |
| --- | --- |
| `lineage-18.1/` | Android 11 用户态。清单默认分支 `lineage-18.1`，AOSP remote 指向 `android-11.0.0_r46`。里面还没有一加 2 和 sambar |
| `lineage-23.2/` | Android 16 用户态。这次不用 |
| 本仓库 `cm-13.0` | 板级档案。分区、cmdline 偏移、专有文件清单、音频路由、Silead、灯、按键 |
| 内核仓库 `cm-13.0` | sambar DTS、defconfig、Atmel 和 Silead 驱动。编译 Android 11 时作为差额来源，不作为唯一内核 |

一加 2 的设备树和内核还没克隆。开始写分支时再取：官方 `lineage-17.1` 的 `android_device_oneplus_oneplus2` 与 `android_kernel_oneplus_msm8994`，以及已经公开走到 18.1/20 的 `mukul2259/kernel_oneplus_msm8994` 与对应 device/vendor。vendor 只作 HAL 结构对照，不覆盖到 Yutopia 的镜像里。

本克隆的设备树 upstream 是 `CyanogenMod/android_device_yu_sambar`，最新分支是 cm-13.0。`LineageOS/android_device_yu_sambar` 的 cm-14.1 需要另加 remote 之后再 fetch。那是 Android 7 的参考，不是新分支的底。

## 路线

### 阶段 0：备份和 fastboot 实测

2026-10-29 完成。步骤和结果在 `docs/sambar-phase-0.md`。

boot、recovery 和基带校准已在 `/run/media/alpha/YMTC/sambar/device-backup/`，`SHA256SUMS` 复核通过。不带 `-i` 的 `fastboot devices` 能看见 bootloader，`oem device-info` 为 unlocked 且 tampered。没有刷分区，没有执行 `oem unlock`。手机里的 recovery 是 TWRP 2.8.7。正在运行的 boot 使用 ramdisk 地址 `0x01000000`、tags `0x100`，和 `BoardConfig.mk` 里的 `0x02000000` / `0x01E00000` 不同。

### 阶段 1：Android 11 能亮屏、有 adb

2026-10-29 完成。记录在 `docs/sambar-phase-1.md`。

完成标准已经达到：LineageOS 18.1 点亮 Sharp 面板，Atmel 触控有反应，adb 开机大约 10 秒能进，`/data` 可写。Wi-Fi 仍是模块。SELinux 仍是 permissive。boot 仍是内核 `#27`。最新 system SHA256 `35b42a50154cd6b995ee5bf089c9302dfcbec735746edd7f467fd5be859ee75e`。

带到阶段 2 的缺口：壁纸有横向扫描线，GLES 仍是 SwiftShader，gralloc 报 `Unknown Chip ID 0`。USB 被 init 钉成只有 adb。没有 Gatekeeper，锁屏凭证校验不了。manifest 里的 `radio@1.1` 没有进程注册，开机一直在要这个服务。

### 阶段 2：18.1 做到能日常使用

格力阶段 3 把「能进桌面」从收口标准里拿掉，改成一套可以天天用的系统，然后才谈下一版 Android。这边同样。阶段 0 探到的硬件都进下表。表里没有的 NFC、红外、FM 不排：`ueventd.qcom.rc` 里的 `nfc-nci` 是高通模板，阶段 0 没有对应的输入设备或芯片。定位用捐赠树的 HIDL gnss，只留 sambar 的 `gps.conf`。阶段 0 没有定位成功的记录，蜂窝通了再看，不单独挡住。

完成标准：下面 1 到 14 都有实机记录。第 1 项显示、第 2 项导航、第 3 项触控和第 10 项振动已经通过。SELinux 保持 permissive，每次开机的 denial 存下来。短信、第二张卡、VoLTE、通话回声消除、蓝牙耳机通话、加密、可刷的安装包、新 TWRP 都不挡住这 14 项。前一项没有记录，先不跳到下一项。步骤写进 `docs/sambar-phase-2.md`，本文只留顺序。

启动链分区、modem、bluetooth、modemst1、modemst2、fsg、persist、persistbak、config 继续不写。不跑 `oem unlock`。不用一加 2 的 system、vendor 或固件镜像。一加 2 只提供 SoC 级的 HAL 结构。

#### 开始前先清 userdata

用户确认这块盘上没有要留的文件。CM13 的应用数据在 Android 11 上会闪退，留着只会干扰后面的验收。`/data/adb` 已有 `device-backup/data-adb.tar`（Magisk 27）。清掉之后没有那份 root。18.1 是 userdebug，root 走开发者选项里的 Rooted debugging。

只格式化 `mmcblk0p39`。用现在这份能挂上 f2fs 的 recovery（内核 `#16`）在分区上做 `mkfs.f2fs`。不用 `fastboot -w`：这颗 LK 的 format 不保证还是 f2fs，fstab 写的是 f2fs。`fstab.qcom` 的 userdata 只有 `formattable`，没有 `forceencrypt`，也没有 `fileencryption`。新盘不会进 CryptKeeper。格力那次会，是因为 userdata 带加密 footer。

清完第一次开机走设置向导。Gatekeeper 装上之前不要设锁屏密码。阶段 1 的图案就是旧 Gatekeeper 的句柄，新系统校验不过。

#### 阶段 0 的硬件落到哪一项

| 阶段 0 看到的 | 阶段 2 |
| --- | --- |
| Sharp 双 DSI command mode，1440x2560，dpi 560 | 第 1 项。已通过 |
| Adreno 430，`ro.opengles.version=196609`（OpenGL ES 3.1） | 第 1 项。已通过，GLES 是 Adreno 430 |
| Atmel `atmel_mxt_ts_T100_touchscreen`，固件 `A4_15_2.2_AA.fw` | 第 3 项。用户确认已经能用 |
| 声卡 `msm8994-tomtom-mtp-snd-card`（WCD9330），功放 NXP TFA9887 | 第 6 项。`libtfa9887` 和 acdb 用现有专有文件 |
| Wi-Fi 模块 `wlan.ko` | 第 5 项。继续编成模块 |
| 蓝牙 QCA Rome，固件分区 `mmcblk0p12`（1 MiB，df 显示的 1.0G 是错的） | 第 7 项 |
| ST LSM6DS3 加速度计和陀螺仪，`yas537_mag`，`alps_pressure`，光感，距离，霍尔 | 第 8 项。不刷 persist |
| modem 分区 80 MiB，modemst1 / modemst2 / fsg 各 4 MiB | 第 9 项。继续用这台机器自己的分区 |
| 相机 `imx230` 与 `ov8865`，`BOARD_QTI_CAMERA_32BIT_ONLY`，`persist.camera.HAL3.enabled=0` | 第 12 项。维持 HAL1 |
| Silead，`silead-vinput-keypad`，`fingerprintd` 与 `fpsvcd` | 第 13 项。不换成一加 2 的指纹 |
| USB 在 Android 里是 `2a96:3014`，bootloader 是 `2a96:301c` | 第 4 项 |
| eMMC，无 A/B，无 vendor 分区 | 不单列。system 仍是 3 GiB |

阶段 0 的表没有单独写振动马达。阶段 1 为了让 `system_server` 过阶段 480，已经装了 `vibrator.default`。用户确认马达是好的，第 10 项已通过。也没有实体导航键：`gpio-keys.kl` 只有音量加，`qpnp_pon.kl` 只有电源和音量减。虚拟导航键和全面屏手势是第 2 项，已通过。编解码不是阶段 0 的探针。格力把它算进日用收口，这边放在第 11 项。

#### 验收顺序

1. 显示能看。已通过。Adreno 430，OpenGL ES 3.1，桌面没有横条，背光能灭能亮。记录在 `docs/sambar-phase-2.md`。
2. 系统导航。已通过。三键导航栏和全面屏手势都能返回、回桌面、打开最近任务。记录在 `docs/sambar-phase-2.md`。
3. 触控。已通过。用户确认能用。固件仍是 `A4_15_2.2_AA.fw`。清盘或换 GPU 之后如果触摸没了，再回到这项。
4. USB。文件传输两个方向都能拷文件。充电、MTP、PTP 能切换。现在 `init.sambar.rc` 把 `sys.usb.config` 钉成 `adb`，这只是阶段 1 的调试口。这颗内核是传统 `android_usb`，不是 ConfigFS。adb 继续用阻塞读写（`ro.adb.nonblocking_ffs=0`，`sys.usb.ffs.aio_compat=true`）。插了 U 盘时按 fstab 的 `usbdisk` 挂上；阶段 0 没有插过 U 盘，挂不上不挡这一项。
5. Wi-Fi。`wlan.ko` 加载，固件来自这台机器，能扫描、连接、拿到地址，`ping` 通。supplicant 用 HIDL。内核继续 `CONFIG_QCA_CLD_WLAN=m`。
6. 音频。喇叭、听筒、有线耳机三个出口都有声音，麦克风能录。TFA9887 走现有 `libtfa9887` 和 acdb。通话拓扑如果必须先关掉回声消除才能响，先记下，回声消除不挡收口。
7. 蓝牙。开关、扫描、配对、A2DP 播放。固件读 `mmcblk0p12`，不另刷这个分区。耳机上的通话留到收口之后。
8. 传感器。加速度计、陀螺仪、磁力计、气压、光感、距离、霍尔都有事件。persist 里的校准不动。
9. 蜂窝。第一张卡识别、驻网、数据能上网，听筒和免提各打通一次。RIL 用这台机器的 modem 分区和现有 blob，不换一加 2 的。短信要能收发。第二张卡和 VoLTE 不挡。阶段 0 没有读卡槽数量。
10. 振动。已通过。用户确认马达是好的。
11. 硬件编解码。视频能播能录一段，音频解码不走软解兜底。Venus 和 ADSP 用现有固件路径。编解码进程崩溃先修这个，再进相机。
12. 相机。后摄 `imx230`、前摄 `ov8865` 都能预览、拍照、录短视频。32 位 HAL1，不在这一阶段打开 HAL3。
13. 指纹。先有 Gatekeeper，再录入一枚，锁屏能解开，另一根手指被拒绝。用户态继续是 Silead 的 `fpsvcd`，校准留在 persist。没有 Gatekeeper 时不要设密码。
14. 休眠唤醒再确认一次。第 1 项的电源键之后，Wi-Fi、蜂窝和传感器都开着时再睡一次、再亮一次。背光必须灭。阶段 1 里 `cont_splash` 期间 `lcd-backlight` 不写硬件，电流在 WLED 上。

#### 不挡住这次收口

日用的 14 项过了之后，到一套可以交给别人刷的包为止，按这个顺序。格力阶段 3 的「距离成品 ROM」是同一张单子，去掉这台机器没有的红外、FM、NFC。

1. 通话能听清。听筒和免提先响了再收，回声消除和降噪可以后补。
2. 蓝牙耳机上的通话。
3. 第二张卡和 VoLTE。第一张卡的短信、数据和普通通话已经在第 9 项里。
4. 定位。gnss HIDL，配置只用 sambar 的 `gps.conf`。不把 CM13 的 `loc_api` 整棵树搬进 18.1。
5. 可刷的安装包。只含 boot 和 system。recovery 不放进同一包，除非下面一项已经能刷它。
6. 能挂这块 f2fs、也能刷 system-as-root 包的 recovery。现在的 TWRP 2.8.7 能挂 `/data`，不保证能刷 18.1 的包。换 recovery 之前，现在这份镜像留在 `device-backup/` 的恢复路径上。
7. 加密。这次不做。fstab 不写 `fileencryption`。3.10 上的文件加密单独开一轮，不和清盘绑在一起。
8. SELinux enforcing。放在最后。每加一个 HAL 都会多一批 denial，现在切只会反复改策略。

### 阶段 3：视镜像大小决定要不要上 Android 12.1 或 13

18.1 的日常功能齐了之后，用一加 2 的 19.1 和 20 树评估下一级。先量 system 镜像。放得进 3 GiB 再做。放不进就停在 18.1，或者单独开一轮 GPT 调整，不把扩容和升级绑在同一次刷写里。这一级预期 SELinux 会停留在 permissive，和捐赠 ROM 的公开状态一致。

Android 14、15、16、17 不排进这条路线。出现一份别人维护到那些版本的 MSM8994 内核之后再重估。

## 一加 2 那台实机

它现在的 Android 5 原厂系统可以留着。升到 13 或 15 对 Yutopia 的移植没有前置作用：捐赠的是公开源码树，不是那台手机里的系统分区。原厂 5.0 还留着 msm8994 早期 bootloader 和分区现场，以后要对 cmdline 或固件布局时比一部已经刷过新系统的机器更有用。需要读它的 sysfs 时再插上。

## 路线图初稿时没有做的事

下面三条是 2026-10-29 写这份路线图时的状态，不是现在的状态。阶段 1 已经完成，recovery 是内核 `#16`，设备分支 `lineage-18.1` 已建。下一步是阶段 2，步骤记在 `docs/sambar-phase-2.md`。

- 没有刷 recovery，没有 `oem unlock`。bootloader 已经是 unlocked
- 没有把 cm-13.0 挪到新分支。板级档案留在原分支，移植分支等阶段 1 再开
- 没有把 `third_party/` 里的包，或硬盘上的分区镜像和 blob，加进 git
