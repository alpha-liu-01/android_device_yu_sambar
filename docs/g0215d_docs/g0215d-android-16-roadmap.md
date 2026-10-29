# 格力手机 2（G0215D）到 Android 16 的路线图

日期：2026-10-26。依据是仓库里的三份旧设备树，以及当天通过 adb 对这台仍在运行的 G0215D 做的检查。手机没有重启到 fastboot，也没有写入任何分区。后半段检查使用了机内 SuperSU 2.82 的 root：读了 cmdline、运行中的设备树、`/proc/config.gz` 和 boot 镜像。boot 镜像只在内存里拆开看过，没有放进本仓库。

终极目标不变：Android 16 在这台机器上启动，并且屏幕、触控、音频、蜂窝、Wi-Fi、蓝牙、相机、指纹、传感器、NFC、充电和红外都能工作。到达那里的路径是先把格力自己的板级事实固定下来，再站到已经维护到 Android 15 的 MSM8996 公共树上，最后再跨 Android 16。

## 结论

旧设备树值得留，但它们的角色是 2016–2017 年的板级档案，不是 Android 16 的构建树。CM13 和 CM14.1 几乎是同一份树的两个快照。里面真正稀缺的是分区表、cmdline、显示方向、专有文件清单、音频路由、Goodix 节点、灯、红外 HAL，以及一份已经能在当时编译通过的高通 BSP 选项列表。占仓库体积大部分的 GPS、IPA、doze 翻译和 `kernel/user` 头文件，是当时从高通工程里整份抄进来的，现在应当丢掉。

一加 3 的参考价值是真实的，而且比“同 SoC”这个理由更具体：格力这份 CM 树就是从一加 3 的 CyanogenMod 树改出来的。`init_g0215d.cpp` 里还留着 `ONEPLUS A3000` / `A3003` 的型号选择，只是被注释掉了。Synaptics 的按键布局也还在树里，但这台实机的触摸屏是 Atmel maXTouch。一加 3 官方 LineageOS 停在 18.1（Android 11），仓库默认分支仍是 `lineage-18.1`。它把 MSM8996 从 Android 7 抬到 Android 11 的平台经验已经沉淀下来，却没有把 Android 12 到 16 这段路走完。

2026 年初仍在 LineageOS 里更新的 MSM8996 公共树是小米那套：`android_device_xiaomi_msm8996-common` 和 `android_kernel_xiaomi_msm8996` 的默认相关分支是 `lineage-22.2`（Android 15）。小米 5（gemini）还有 Atmel maXTouch 键位和 Consumer IR 服务这种结构上的巧合，内存也有 4 GB 版本。面板、指纹方案、相机模组和这台格力仍然不同。后续平台层以小米 22.2 为底，一加 3 用来对照“格力树当初从哪里 fork、哪些文件是误带进来的”。

内核 git 仍然不在这三份树里，公开检索也没有 `cyanogenmod_g0215d_defconfig`。`kernel/AndroidKernel.mk` 只拷贝 `kernel/user` 头文件，TWRP 树引用的 `prebuilt/kernel` 是空的。能工作的内核在 boot 分区里，版本 `3.18.20-perf`，2017-04-12 编译。这次已经从运行中的内核导出了完整 ikconfig，见 `docs/reference/g0215d-3.18.20-perf.config`，并从 `/sys/firmware/devicetree/base` 读出了当前选中的那份板级树。它的 model 是 `Qualcomm Technologies, Inc. MSM 8996 v3 + PMI8996 MTP`，compatible 是 `qcom,msm8996-mtp`。格力的触摸、指纹、红外、功放都挂在这棵 MTP 树上，而不是挂在一份额外命名的 Gree DTB 上。

因此第一阶段的产出不是 Android 16，而是三件事：用已经可用的 root 把 boot、recovery、modem、persist、EFS 备份到电脑上；按 CM14.1 清单加上本文的固件文件名，从这套 HALO / MIUI 8 系统里抽出 blob；内核基线用小米 `lineage-22.2` 的 3.18 树，再把这份 MTP 设备树里的格力节点和 `CONFIG_TOUCHSCREEN_ATMEL_MXTS`、`CONFIG_FINGERPRINT_GOODIX_GF816M_GF`、`CONFIG_RAON_REMOTE_CTRL_SOC`、`CONFIG_RADIO_SILABS` 这些格力 defconfig 开关移植上去。boot 镜像里的内核和 DTB 是 2017 年原厂的，ramdisk 已经被 MIUI patchrom 和 systemless SuperSU 改过。

## 实机快照

adb 上的设备状态是 `device`。普通 shell 是 `uid=2000`，`adb root` 无效，因为这是 `user` 构建且 `ro.debuggable=0`。root 走机内的 systemless SuperSU，见下一节。下面的硬件项来自 getprop、sysfs 和 `/system`；cmdline、设备树和内核配置是用 root 读的。

| 项目 | 实机 |
| --- | --- |
| 型号 | Gree G0215D，板名 `msm8996`，`ro.hardware=qcom` |
| 系统 | 原厂 Android 6.0.1（`MMB29M`）上的 MIUI 8 patchrom，显示名 `HALO 1.2.1 D1`。不是 CyanogenMod |
| 构建指纹 | `GREE/G0215D/G0215D:6.0.1/MMB29M/a310e98:user/release-keys` |
| 构建日期 | 2017-04-12，与内核编译时间同一天 |
| 安全补丁 | 2016-06-01 |
| SoC | `family=Snapdragon`，`machine=MSM8996`，`soc_id=246`，`revision=3.1`，`vendor=Qualcomm` |
| CPU | 4 核。cpu0/1 最高 1.5936 GHz，cpu2/3 最高 2.1504 GHz。实现者 `0x51`，part `0x211` 与 `0x205` |
| 内存 | `MemTotal` 约 3781 MB，对应 4 GB 规格 |
| 存储 | UFS `KLUCG4J1CB-B0B1`（三星 64 GB 料号）。userdata 可用约 54 GB |
| 显示 | 1440x2560，dpi 640，framebuffer `mdssfb_90000`，MIPI DSI command mode |
| 面板 | `Dual nt35597 cmd mode dsi panel without DSC`，partial update 打开 |
| 面板方向 | `persist.panel.inversemounted=180` |
| GPU 声明 | 设备树写 Adreno 530；`ro.opengles.version=196609`（OpenGL ES 3.1）。kgsl sysfs 对 shell 不可读 |
| 设备树 | model `MSM 8996 v3 + PMI8996 MTP`；`qcom,msm-id = <0xf6 0x30001>`（0xf6 = 246）；`qcom,board-id = <8 0>`；`qcom,pmic-id = <0x20009 0x10013 0 0>` |
| 内核 | `Linux version 3.18.20-perf`，`#1 SMP PREEMPT Wed Apr 12 10:54:40 CST 2017`，aarch64，gcc 4.9。`CONFIG_LOCALVERSION="-perf"`，`CONFIG_IKCONFIG` 打开 |
| 启动链 | `ro.boot.verifiedbootstate=orange`，`ro.boot.veritymode=enforcing`，`ro.boot.selinux=permissive`，运行时 `getenforce` 为 Permissive |
| 加密 | 全盘加密，footer。没有锁屏口令，密钥是 Android 的 default password。TWRP 3.0.2 会自动解到 `/dev/block/dm-0` |
| 基带 | `MPSS.TH.2.0.c1.9-00050-M8996FAAAANAZM-1.83425.1`，`ro.boot.baseband=msm` |
| 蜂窝 | `persist.radio.multisim.config=dsds`，`ro.telephony.default_network=22,22`。`rmnet_data*` 与 `rmnet_ipa0` 已存在 |
| 分区 | 与 2016 年 `partitions.txt` 一致。没有 vendor、odm、product、super |

`soc_id=246` 加上 2.15 GHz / 1.59 GHz 的频率，对应骁龙 820，不是骁龙 821（821 的 soc id 和金核频率都不同）。XBL 侧版本字符串是 `10:MMB29M:7.4.28`，`image_variant=G0215D-user`。

分区大小用 sysfs 的 512 字节扇区数核对过，和 CM 树里的 `BOARD_*_PARTITION_SIZE` 一致：

| 分区 | 大小 | 说明 |
| --- | --- | --- |
| boot / recovery | 各 64 MiB | `sde17` / `sde19` |
| system | 3 GiB（df 可见约 2.9 GiB，已用约 1.4 GiB） | `sde18`，ext4 |
| cache | 256 MiB | `sda3` |
| persist | 32 MiB | `sda2`，传感器校准和 DRM 通常在这里 |
| modem | 约 95 MiB | `sde11`，vfat，挂在 `/firmware` |
| dsp | 16 MiB | `sde12` |
| bluetooth | 1 MiB | `sde21` |
| userdata | `59212771328` 字节 | `sda9`，FDE，footer 加密 |
| 其他 | aboot、tz、rpm、hyp、cmnlib、keymaster、xbl、modemst1/2、fsg、fsc、frp | 启动链和基带校准，不能拿来扩容 |

启动链是经典 MSM8996 A-only：XBL + ABL/aboot + boot + recovery，外加 tz/rpm/hyp/cmnlib/keymaster 的主备分区。没有 A/B，也没有动态分区。

## 正在运行的系统是 HALO MIUI 8，不是 CM

构建指纹仍然是格力原厂的 `GREE/G0215D/G0215D:6.0.1/MMB29M/a310e98:user/release-keys`，安全补丁停在 2016-06-01。包在外面的是一套 MIUI 8 patchrom：

- `ro.miui.ui.version.name=V8`，`ro.miui.ui.version.code=5`
- `ro.build.display.id` 和 `ro.fota.version` 都是 `HALO 1.2.1 D1`
- `ro.fota.platform=MSM8996_6.0`，`ro.fota.oem=GREE8996_6.0`，`ro.fota.device=G0215D`
- `ro.product.mod_device=G0215D_wxl`。`wxl` 与 CM 设备树作者吴宪林的仓库前缀一致，这份 patchrom 和仓库里的 CM 树是同一批人基于原厂 BSP 做的两套用户态，手机现在跑的是其中的 MIUI 版
- 已安装 `com.miui.*`、`com.gree.irremote`、`com.hartec.miuitweaks8`、`eu.chainfire.supersu`
- boot ramdisk 里有 `init.miui.rc`、`init.miui8.rc`，也有原厂的 `init.target.rc`、`init.qcom.rc`

CM13 / CM14.1 设备树没有装在这台手机上。它们仍然是板级档案。抽 blob 和对照行为时，以这套 HALO 系统里的文件为准，不要假设 `/system` 是一份未改过的原厂镜像，也不要假设它是 CyanogenMod。

### adb 上的 root

`adb root` 不会成功。可用的是 `/su/bin/su`，SuperSU v2.82（arm64），systemless：`/data/su.img` 经 loop 挂到 `/su`。ramdisk 里的 `init.supersu.rc` 调用 `/sbin/launch_daemonsu.sh`。`init.miui.rc` 里还有一条指向 `/system/xbin/su` 的旧服务，实际放行 adb 的是 `/su/bin/su`。

本次验证：

```text
adb shell su -c id
adb shell su 0 id
```

第一次 `su -c id` 大约 10 秒后以退出码 1 结束，没有输出，对应 SuperSU 的授权超时。紧接着的一次请求返回 `uid=0(root) gid=0(root) context=u:r:init:s0`。授权框出现在手机上，点允许之后，同一台电脑上的后续 `su` 可以直接用。引号容易被 adb 吃掉，多参数命令用 `adb shell su 0 <命令> <参数>` 这种形式更稳。SELinux 是 permissive，所以这个 root 的 domain 是 `init`。

清掉 `/data` 会一起清掉 `/data/su.img`，systemless root 就没了。备份时把 `su.img` 算进数据分区，不要把它当成系统分区的一部分。

### boot 镜像里什么是原厂、什么是后加的

boot 分区 64 MiB，头是标准 `ANDROID!`，page size 4096，kernel 约 39 MiB 且以 gzip 开头，后面串着多份 DTB，ramdisk 约 7.5 MiB。kernel load address `0x80008000`，ramdisk `0x81000000`，tags `0x80000100`，与 CM / TWRP 树一致。

boot 镜像头里的 cmdline 是 `androidboot.selinux=permissive`、console、`cma=32M@0-0xffffffff` 这一串。CM14.1 的 `BoardConfig.mk` 写的是 `cma=16M`，和正在运行的系统内核不一致。recovery 分区里的是 TWRP，不是原厂 recovery；它自带的内核 cmdline 用 `cma=16M`，和系统 boot 的 32M 不是同一颗镜像。细节见下面的 TWRP 一节。

运行时的完整 cmdline 比 boot 头更长。bootloader 还会接上 HMP 开关、`androidboot.bootdevice=624000.ufshc`、verified boot 状态，以及面板选择：

```text
mdss_mdp.panel=1:dsi:0:qcom,mdss_dsi_nt35597_wqxga_cmd:config0:1:qcom,mdss_dsi_nt35597_wqxga_cmd:config0:cfg:split_dsi
```

换 boot 镜像时，bootloader 仍会追加这串面板参数。新内核要保留对 `qcom,mdss_dsi_nt35597_wqxga_cmd` 和 `split_dsi` 的支持。cmdline 里还有序列号，本文不记录。

## 已经放在移动硬盘上的大文件

内置盘不放这些。路径都在 `/run/media/alpha/YMTC/`（btrfs，能放 Android 源码）。不要再下一份完整的 LineageOS 树。

| 路径 | 状态 | 用途 |
| --- | --- | --- |
| `lineage-23.2/` | 已完成，约 260 GB，`repo sync` 成功。清单停在 `android-security-16.0.0_r8`。本地清单只有 gru 的 mainline 项目 | Android 16 用户态。里面没有 MSM8996 的内核和设备树 |
| `g0215d/donor/android_device_xiaomi_msm8996-common` | 已克隆，`lineage-22.2` | 平台设备树。依赖内核和 `hardware/xiaomi` |
| `g0215d/donor/android_kernel_xiaomi_msm8996` | 已克隆，`lineage-22.2`，`535079d2`，约 2.0 GB | 要移植的 3.18 内核。公开分支最远到 22.2，没有 23.2 |
| `g0215d/donor/android_kernel_oneplus_msm8996` | 已克隆，`lineage-18.1`，`b2a6b3b`，约 1.8 GB | 一加 3 对照。官方内核也停在 18.1 |
| `g0215d/donor/android_hardware_xiaomi` | 已克隆，`lineage-22.2`，`f5b2022`，约 1.3 MB | common 树写明的依赖 |
| `g0215d/donor/android_device_xiaomi_gemini` | 已克隆，`lineage-22.2`，`8b36b5e`，约 246 MB | 小米 5 板级对照 |
| `g0215d/donor/android_device_oneplus_oneplus3` | 已克隆，`lineage-18.1`，`e975bda`，约 14 MB | 一加 3 设备树对照 |
| `g0215d/device-backup/` | 已抽出。含 boot、recovery、persist、modem、bluetooth、dsp、fsg、modemst1、modemst2、fsc、system，旁有 `SHA256SUMS`。没有 userdata | 分区原样镜像。`fsc` 是 4096 字节全 0。手机上的临时文件已删 |
| `third_party/2026-10-26--07-27-02_HALO_1.2.1_D1/` | TWRP 的 Data 备份，1408 MB，3916 个文件，md5 通过。含 `/su.img`（96 MB）和 SuperSU 留下的刷机前 boot | 解密后的应用数据。不含内部存储 `/data/media` |
| `third_party/2026-10-26--07-28-01_HALO_1.2.1_D1/` | TWRP 的 System 备份，1410 MB，3832 个文件，md5 通过。触摸固件 `A4_2F_4.0_05.fw` 和 `Gree2_4005_V2.06_20170223.raw` 在里面 | `/system` 的文件级副本，和上面的 `system.img` 是同一套 HALO |

23.2 树里已经有 `hardware/qcom-caf/common` 和 `device/qcom/sepolicy-legacy-um`，msm8996-common 直接引用这两处。小米的专有 `vendor/xiaomi/msm8996-common` 没有公开 git，不下载；格力 blob 从 `device-backup/system.img` 抽。

ramdisk 是 SuperSU 改过的。里面有 `su`、`init.supersu.rc`、`sbin/launch_daemonsu.sh`，以及 `.subackup/`，里面是打补丁前的 `fstab.qcom`、`init.rc`、`init.environ.rc`、`sepolicy`、`verity_key`。内核和附加 DTB 仍是 2017-04-12 那颗原厂 `Image.gz-dtb`。以后说“stock boot”时要分开：内核/DTB 可以当原厂，ramdisk 要当 HALO + SuperSU。

## 旧设备树各自还剩多少价值

### CM13 与 CM14.1

来源是吴宪林的 `android_device_gree_g0215d`，本地目录是 `third_party/android_device_gree_g0215d-cm-13.0` 和 `cm-14.1`。去掉 `.git` 和 `kernel/user` 之后，大约 475 和 522 个文件。两边 diff 主要落在 GPS、doze、media codec、`device.mk` 和少量 `BoardConfig.mk` 开关上，板级事实是同一套。

CM14.1 比 CM13 多的、以后还会用到的开关：

- `TARGET_HAS_LEGACY_CAMERA_HAL1 := true`，与实机 `persist.camera.HAL3.enabled=0` 一致
- `BOARD_USES_ADRENO`、VSYNC phase offset，`TARGET_USES_HWC2` 仍被注释
- `BOARD_SUPPORTS_SOUND_TRIGGER := false`（CM13 是 true）

以 CM14.1 为档案，CM13 只在对差异有疑问时再翻。不要为了“先复现 CM”去同步一份 Android 6/7 整树来编译，除非后面某颗 blob 的行为必须用原版系统对照。

按用途分级：

| 内容 | 价值 | 用法 |
| --- | --- | --- |
| `BoardConfig.mk` 里的平台、页大小、cmdline、分区大小、Wi-Fi/BT/NFC/RIL 开关 | 高 | 翻译成现代 `BoardConfig`，不要逐行保留变量名 |
| `partitions.txt`、`fstab.qcom` | 高 | 已与实机分区节点和大小对上 |
| `system.prop` 里的双卡、面板翻转、dpi、Rome 蓝牙、`persist.qfp=false` | 高 | 面板翻转和 dpi 已在实机上复现 |
| `proprietary-files.txt` | 高 | 抽取清单。实机 `/system` 比这份清单更杂，以 G0215D 相机 XML 为准裁剪 |
| `audio/mixer_paths_tasha.xml`、`audio_platform_info.xml`、ACDB 路径 `MTP_*` | 高 | 声卡拓扑是板级的，公共音频 HAL 替换不了这些文件 |
| `liblight/lights.c` | 高 | 节点与实机 LED 一致：`red` / `green` / `blue`、`lcd-backlight`、`button-backlight` |
| `sepolicy` 里的 Goodix 设备节点 | 中 | 只有 8 个策略文件，Android 16 用不上整份，节点路径有用：`/dev/goodix_fp`、`/dev/gf66xx-spi` |
| `libirda/`、`patches/frameworks/base/0001-add-remoteir.patch` | 中 | HAL 和 `/dev/remote_ctrl_dev` 要留。那份 1500 行的 `frameworks/base` 补丁不要带进 Android 16 |
| `init/init_g0215d.cpp` | 低 | 主体是一加 3 的射频版本选择，格力型号分支是空的 |
| `keylayout/synaptics_dsx.kl` | 低 | 实机触摸屏是 `atmel_mxt_ts`。这个文件是 fork 残留 |
| `keylayout/gpio-keys.kl`、`tiny4412-key.kl`、`qpnp_pon.kl` | 中 | 三个输入设备在实机上都存在 |
| `gps/`、`data-ipa-cfg-mgr/`、大量 doze 翻译 | 低 | 当时的高通源码副本。用 msm8996-common 里的现成实现 |
| `kernel/user` 与 `AndroidKernel.mk` | 低 | 只是已导出的 UAPI 头，没有 defconfig，没有 DTS，没有可编译的内核 |
| `cm.dependencies` 里的 NXP NFC 开源仓库 | 中 | 说明 NFC 走的是 NXP 开源栈，芯片是 PN547 |

`proprietary-files.txt` 把显示校准 `qdcm_calib_data_Dual_nt35597_cmd_mode_dsi_panel_without_DSC.xml` 以减号排除了。实机面板名正是这颗 NT35597。后面抽 blob 时把这个文件从排除名单里拿回来检查，它可能是色彩校准，也可能只是高通参考文件。

### 机上的 TWRP 3.0.2

2026-10-26 这台手机进了 recovery，adb 状态是 `recovery`，shell 直接是 `uid=0`，context `u:r:su:s0`。`ro.twrp.version=3.0.2-0`，启动日志是 `Starting TWRP 3.0.2-0-d3ec0593`。

| 项目 | 机上的 TWRP | 正在运行的 HALO 系统 |
| --- | --- | --- |
| 构建 | `omni_G0215D-userdebug 6.0.1 M4B30X`，`test-keys` | `GREE/G0215D` `user` `release-keys` |
| 指纹 | `Android/omni_G0215D/G0215D:6.0.1/M4B30X/ubuntu10312340:userdebug/test-keys` | `GREE/G0215D/G0215D:6.0.1/MMB29M/a310e98:user/release-keys` |
| 编译时间 | 2016-10-31 23:41 CST，用户 `ubuntu` | 2017-04-12 |
| 内核 | `3.18.20-perf`，`#1 SMP PREEMPT Fri Oct 7 15:28:14 CST 2016`，同一台 `android@buildserver`、gcc 4.9 | 同一版本号，编译于 2017-04-12 |
| cmdline 里的 cma | `16M` | boot 镜像头是 `32M` |
| 密度 | `ro.sf.lcd_density=560` | 640 |
| 数据 | 用 default password 解开 FDE，`/data` 和 `/sdcard` 都挂在 `dm-0` 上 | 系统启动后同样挂着已解密的 `/data` |

两颗内核都会按 bootloader 追加的同一串 `mdss_mdp.panel=...qcom,mdss_dsi_nt35597_wqxga_cmd...split_dsi` 找到面板。recovery 的 dmesg 写明 `Panel Name = Dual nt35597 cmd mode dsi panel without DSC`。这块屏在 2016-10 的内核上已经能点亮，不依赖 2017-04 那次内核更新。

数据分区是 footer 加密，但没有用户锁屏口令。TWRP 日志原文是 `Device is encrypted with the default password` 和 `Successfully decrypted with default password`。新 recovery 只要还认 Android 6 的 cryptfs footer，就能自己挂上 `/data`。换成只支持文件加密的 recovery，或者在 TWRP 里格式化 data，现有数据就没了。2026-10-26 已经用这块 TWRP 各做了一份 Data 和 System 的文件备份，md5 通过，拷在 `third_party/` 里。Data 备份含 `/su.img`，不含内部存储里的照片和下载。

当前生效的 `/etc/recovery.fstab` 只列出 boot、cache、data、recovery、system、system_image，外加一个并不存在的 `mmcblk1` 外置卡和 USB-OTG。图形界面的备份因此覆盖不到 persist、modem、modemst、fsg。这些仍然要用 `dd`。ramdisk 里的 `/etc/recovery.fstab.bak` 才是完整的原厂 fstab，含 persist、dsp、modem、bluetooth。`/system` 可以从 TWRP 以只读方式挂上，dm-verity 没有拦住这次挂载。

recovery 的 `default.prop` 是从格力原厂属性改出来的，里面有 `ro.build.software.version=EV23-16 V1.8 SD`、`qemu.hw.mainkeys=1`、`persist.qfp=false`。同一条软件版本字符串也写在 HALO 的 `/system/build.prop` 里，所以 2017 年的 patchrom 没有改掉这个版本号。`qemu.hw.mainkeys=1` 表示使用实体导航键，系统里也有 `button-backlight`。

### 仓库里的 TWRP 树

`third_party/android_device_Gree_G0215D-Twrp-6.0` 大约 29 个文件，对应 lbule 的树，lunch 名是 `lineage_G0215D`。机上这块 recovery 的指纹是 `omni_G0215D`，编译于 2016-10-31。两者是同一类 Omni/TWRP 移植，不是同一个二进制：

- 仓库 `BoardConfig.mk` 的 cmdline 写 `cma=32M`，机上 TWRP 是 `16M`
- 仓库 `twrp.fstab` 包含 modem、modemst、fsg、persist；机上生效的 fstab 没有这些项
- 仓库 `TARGET_PREBUILT_KERNEL` 指向空的 `prebuilt/kernel`，现在编不出镜像
- 仓库记录了进 fastboot 的组合键（电源 + 音量减 + 指纹键）和 `BOARD_HAS_FLIPPED_SCREEN`

保留仓库当按键和分区说明。复现或替换 recovery 时，以机上这块 3.0.2 的 cmdline、内核日期和 fstab 为准，不要假定编出来的 `lineage_G0215D` 会和现在这块一样。在新内核能点亮这块倒装屏之前，不要覆盖这个 recovery 分区。

## 这台机器的板级硬件

下面是实机 I2C/SPI，加上运行中设备树的 compatible，以及 `/system/etc/camera/msm8996_camera_G0215D.xml`。CM 树里的同名信息若与实机冲突，以实机为准。控制器地址是 DTB 里的物理地址，Linux 总线号是 `i2c-6/7/8/12`。

| 功能 | 运行中的节点 | 和一加 3 的关系 |
| --- | --- | --- |
| 触摸 | `i2c@75ba000/atmel_mxt_ts@4a`，compatible `atmel,atmel_mxt_ts`，驱动开关 `CONFIG_TOUCHSCREEN_ATMEL_MXTS`。固件 `A4_2F_4.0_05.fw`，配置 `Gree2_4005_V2.06_20170223.raw`，由 ramdisk 的 `init.atmel_ts.sh` 写到 `12-004a` | 一加 3 是 Synaptics。主线的 `CONFIG_TOUCHSCREEN_ATMEL_MXT` 在这颗内核里是关掉的，要移植的是 `ATMEL_MXTS` 这份驱动和格力配置 |
| 面板 | `qcom,mdss_dsi_nt35597_wqxga_cmd`，面板名 `Dual nt35597 cmd mode dsi panel without DSC`。同级还有 video / DSC 节点，bootloader 选中的是 cmd + `split_dsi`。1440x2560，倒装 | 一加 3 是 1080p 三星 AMOLED |
| 声卡 | ALSA `msm8996-tasha-mtp-snd-card`；DT 节点 `sound-9335`，compatible `qcom,msm8996-asoc-snd-tasha`，`CONFIG_WCD9335_CODEC` | 机器驱动是 MTP 的 Tasha，不是一加 3 自己的声卡 |
| 功放 | `i2c@757a000/tfa98xx@34`，compatible `nxp,tfa98xx`，`CONFIG_SND_SOC_TFA`。固件 `tfa98xx.cnt`，ACDB 在 `acdbdata/MTP` | 公共 Tasha HAL 可借，校准文件用格力这份 |
| 充电 | `smb1351-charger@1d`，compatible `qcom,smb1351-charger`，`CONFIG_SMB1351_USB_CHARGER` | 板级 GPIO 和温度策略跟这份 DTS 走 |
| USB-C | `tusb320@67`，compatible `my,tusb320`，`CONFIG_TUSB320` | compatible 字符串是 `my,tusb320`，不是常见的 `ti,tusb320`。驱动要认这个字符串 |
| NFC | `nfc@28`，compatible `nxp,pn547`，`CONFIG_NFC_PN547_I2C`，节点 `/dev/pn547` | NXP 开源栈可以接 |
| NFC eSE | `spi@7575000/nxp_p61@0`，compatible `nxp,p61` | 读卡可以先做，eSE 放在后期 |
| 指纹 | `spi@7579000/goodix_touchfinger@0`，compatible `goodix,gf`，`CONFIG_FINGERPRINT_GOODIX_GF816M_GF`。节点 `/dev/goodix_fp`，守护进程 `gx_fpd` | 芯片配置名是 GF816M。一加 3 的 FPC HIDL 对不上 |
| 指纹按键 | `qcom,qbt1000`，`CONFIG_MSM_QBT1000`，输入设备 `qbt1000_key_input` | 高通侧按键，和 Goodix SPI 同时存在 |
| 红外 | `raon_remote_ctrl@50`，compatible `raon,remote-ctrl`，`CONFIG_RAON_REMOTE_CTRL_SOC`，节点 `/dev/remote_ctrl_dev`。系统里有 `com.gree.irremote` | 芯片是 Raon，不是通用 Consumer IR。小米 5 只有服务框架可参考 |
| 马达 | `haptics-dev2605@5a`，compatible `qcom,haptics-drv2605`，`CONFIG_INPUT_DRV2605_HAPTICS` | 节点名把 drv 写成了 dev，compatible 是对的 |
| FM | `silabs4705@11`，compatible `silabs,si4705`，`CONFIG_RADIO_SILABS`。上游 `CONFIG_RADIO_SI470X` 是关掉的 | 要移植的是这份 Silabs 驱动，不是主线 SI470X |
| EEPROM | `at24@51`，compatible `atmel,24c32`，`CONFIG_EEPROM_AT24` | 板级 EEPROM，不是相机 EEPROM |
| Wi-Fi | `CONFIG_CLD_LL_CORE`，模块 `wlan.ko` → `qca_cld_wlan.ko`，`wlan0` 与 `p2p0` 已起来 | qcacld。ini 里的 1x1 还要用扫描结果核实。`CONFIG_WIL6210=m` 编进了 defconfig，但当时没有加载，运行中的设备树也没有对应节点 |
| 蓝牙 | 根节点 `bt_qca6174`，compatible `qca,qca6174`；属性 `qcom.bluetooth.soc=rome` | QCA6174 / Rome，与一加 3、小米 5 同代 |
| 传感器 | Bosch BMI160（加速度、陀螺）、AKM AK09915（磁力）、Rohm RPR0521（距离、光）、ST LPS22HB（气压）、Sensirion SHTC1（湿度、温度），经高通 SSC | 名单以实机 `dumpsys sensorservice` 为准。SSC 注册表和 ADSP 固件必须来自格力 persist/firmware |
| 后摄 | Samsung S5K3P3，马达 DW9800，EEPROM `sunny_a16s05e`，闪光灯 `pmic`，f/1.8，安装角 90°，CSI0 四 lane | 一加 3 / 小米 5 是 Sony IMX 系 |
| 前摄 | OmniVision OV8858，EEPROM `sunny_d8v03c`，无独立马达项，f/2.4，安装角 270°，CSI2 两 lane | 同上 |
| 相机栈 | `/system/lib/hw/camera.msm8996.so` 是 32 位，HAL1 | 这是后面最大的用户态包袱之一 |
| 指示灯 / 闪光灯 | 三色灯、实体键背光、双闪光灯 `led:flash_0/1` 与 torch | `lights.c` 能对上三色灯和背光 |

`/system/etc/camera/` 里还躺着 `msm8996_camera_G0245D.xml`（IMX258 + OV8856）以及一大包 IMX/OV 的 chromatix。那是同一套 system 镜像里的兄弟机或高通参考残留。G0215D 的有效配置只有上面两颗传感器。抽 blob 时以 `msm8996_camera_G0215D.xml` 点名的 `s5k3p3`、`ov8858`、`dw9800`、`sunny_a16s05e` 为准。XML 没有 OIS 节点；专有文件列表里的 `libois_lc898122.so` 先视为随包带上的库，等打开相机确认有没有被加载。

前摄 EEPROM 名是 `sunny_d8v03c`，CM 的抽取列表只写了 `sunny_a16s05e`。正式抽取脚本要把 XML 里出现的库名再对一次 `/system/vendor/lib`。

`gpio_keys` 的 compatible 是 `gpio-keys`，子节点是 `vol_up`、`cam_focus`、`cam_snapshot`。recovery 的 `default.prop` 里有 `qemu.hw.mainkeys=1`，配合系统里的 `button-backlight`，导航键是实体键。输入设备 `tiny4412-key` 仍然存在，但运行中的设备树里没有这个名字。它来自某个驱动里写死的 input name，移植内核时直接搜这个字符串。

相机在 DTB 里是 `qcom,cci` 下的 `qcom,camera@0` 和 `qcom,camera@2`，和用户态 XML 的 CameraId 0 / 2 对齐。传感器名字不在这两个节点的 compatible 里，仍以 `msm8996_camera_G0215D.xml` 为准。

## Donor 怎么用

### 一加 3 / 3T（oneplus3）

公开事实，2026-10 核对过 LineageOS wiki 与 `LineageOS/android_device_oneplus_oneplus3`：

- 官方支持到 18.1，也就是 Android 11。之前还有 14.1、15.1、16.0、17.1
- 内核 `android_kernel_oneplus_msm8996`，3.18，源码仍在
- 下载页已不再把 oneplus3 当作在维设备
- 屏幕 1080x1920 AMOLED，6 GB 内存，指纹是 FPC 路线

适合从一加 3 拿走的：

- 2016 年的 CM 树和 2021 年的 18.1 树之间，`BoardConfig`、init、fstab、sepolicy、manifest 各长什么样。格力树和一加 3 CM 树的同源关系，用这份 diff 最容易看出来
- 3.18 内核上 Adreno 530、MDSS、IPA、QMI、WCNSS/qcacld、Tasha 音频框架怎么活过 Android 8 到 11
- boot 镜像打包参数：`Image.gz-dtb`、base `0x80000000`、pagesize 4096、ramdisk offset `0x01000000`、tags offset `0x100`。格力 CM 树与 TWRP 树已经使用同一组数字

不从一加 3 拿的：

- 面板时序和 DSI 面板驱动绑定
- Synaptics 触摸
- FPC 指纹 HAL
- IMX298 / IMX179 相机库和 chromatix
- 针对 6 GB 内存和 1080p 的 overlay、dalvik heap

### 小米 MSM8996（gemini、natrium 等）

`LineageOS/android_device_xiaomi_msm8996-common` 与 gemini 设备树在 `lineage-22.2` 上仍能看到 2026-01 的评审。hudson 的设备依赖把 gemini、natrium 指到这份 common 和 `android_kernel_xiaomi_msm8996`。这是目前公开、仍在维护、而且已经走到 Android 15 的 MSM8996 平台树。

common 里已经按现代 Lineage 拆开的部分，正是格力树里那些不该再手写的东西：GPS、显示/媒体/音频的构建方式、VINTF、sepolicy、电量与热、Wi-Fi、抽 blob 的脚本、以及 3.18 内核为了 Android 12–15 补上的接口。

gemini 的 `lineage-22.2` `device.mk` 还有两处和格力同形：`atmel-maxtouch.kl`，以及 `android.hardware.ir-service.lineage`。小米 5 的触控芯片和红外协议仍要单独核对，不能把键位文件直接拷过来。它的意义是：Atmel 触摸和 Consumer IR 在这份 Android 15 树里已经有放置位置。

小米 5 有 3 GB / 4 GB 内存版本，比一加 3 的 6 GB 更接近这台格力。屏幕仍是 1080p，所以显示带宽、heap 和 1440p 的 framebuffer 不能照抄。

### 其他 MSM8996

- 乐视 Le Max 2、中兴 Axon 7 做过 1440p + Adreno 530，用来估计 2K 屏在这个 GPU 上的内存和合成开销。面板驱动不是 NT35597，DTS 不能混用
- 正在运行的设备树把自己标成 MSM8996 v3 + PMI8996 MTP，声卡 compatible 是 `qcom,msm8996-asoc-snd-tasha`。移植时以这棵树为板级底稿，在 CAF / 小米 / 一加内核里搜 `mdss_dsi_nt35597_wqxga_cmd`、`msm8996-asoc-snd-tasha`、`atmel_mxts`、`goodix_touchfinger`、`raon,remote-ctrl`。面板驱动和 Tasha 机器驱动多半已经在 CAF 里，差的是这张板的接线和那几个格力私有驱动
- 主线内核和 postmarketOS 上的一加 3 对“Linux 能点亮”有参考价值。要全部闭源硬件（基带、相机、指纹、SSC）工作，仍走 3.18 CAF 衍生树

### 价值怎么分配

粗分到“能进 Android 16 桌面且主要硬件可用”这件工程上：

| 来源 | 大约能覆盖的部分 |
| --- | --- |
| 格力 CM14.1 + 这台实机 | 板级事实、分区、blob、音频/相机/指纹/红外/灯的校准与节点。大约是整机差异的全部。对平台代码几乎为零 |
| 一加 3，停在 18.1 | 同源树对照，以及 Android 11 以前的 3.18 平台路径。大约覆盖平台层里“2016 到 2021”这一段 |
| 小米 msm8996-common + 内核 `lineage-22.2` | Android 11 到 15 的平台、HAL、VINTF、sepolicy、内核后向移植。这是现在最值钱的 donor |
| 仍要自己做的 | 把 MTP 设备树上的格力节点迁走；`ATMEL_MXTS`、GF816M、Raon、`RADIO_SILABS`、`my,tusb320`；3 GiB 分区；S5K3P3/OV8858 的 32 位 HAL1；倒装的 NT35597；Android 15 到 16 的下一次升级 |

一加 3 单独看，平台层可以借到大约六到八成的“高通 BSP 概念”，整机完成度大约四成，因为屏幕、触摸、指纹、相机、内存和声卡机器驱动都已经对不上。把 donor 换成小米 22.2 之后，平台层能借的比例更高，整机完成度仍然卡在上面那张板级表上。

## 和 Android 16 之间真正的缺口

页大小保持 4 KB。这台机器的 bootloader 和现有内核都是 4 KB。Android 16 对老设备仍然接受 4 KB 页，不要为了新设备的 16 KB 页去改这颗 SoC。

system 只有 3 GiB，而且没有 vendor 分区。Android 15 的 msm8996 镜像加上 vendor、product、system_ext，放不进这个 system。cache 只有 256 MiB，腾不出足够空间。可用的办法是在备份之后，从 userdata 划出 vendor（以及必要时扩大 system），做法跟小米这批机器的公开重分区记录走，并在 fastboot 里先只启动、不刷写地验证。全盘加密用的是 default password，现有 TWRP 能解开。重分区、格式化 data，或换上不认 Android 6 cryptfs footer 的 recovery，仍会让这 7.5 GB 数据消失。备份要在这块 TWRP 还在的时候做。

内核要补的是 Android 12 之后用户态依赖的接口，而不是换一套主线驱动。小米 `lineage-22.2` 内核已经带了大量这类补丁。格力侧要移植的是当前 MTP 设备树里的板级节点，以及 ikconfig 里这些 donor 树不一定同名的开关：`CONFIG_TOUCHSCREEN_ATMEL_MXTS`、`CONFIG_FINGERPRINT_GOODIX_GF816M_GF`、`CONFIG_RAON_REMOTE_CTRL_SOC`、`CONFIG_RADIO_SILABS`、`CONFIG_TUSB320`（匹配 `my,tusb320`）、`CONFIG_SND_SOC_TFA`、`CONFIG_SMB1351_USB_CHARGER`、`CONFIG_NFC_PN547_I2C`、`CONFIG_INPUT_DRV2605_HAPTICS`、`CONFIG_MSM_QBT1000`。NT35597 WQXGA command 面板和 `qcom,msm8996-asoc-snd-tasha` 在 CAF 里通常已经有，差在 GPIO、电源时序和倒装。

用户态按难度排：

1. 显示倒装、Atmel 触摸、USB 网络 adb。这是内核和 DTS 的验收标准。
2. 音频。HAL 用 common，路由和 ACDB 用格力。
3. Wi-Fi / 蓝牙 Rome / 传感器 SSC。固件和 `persist` 来自 stock。
4. 双卡 RIL 与数据。基带版本是 `MPSS.TH.2.0.c1`，blob 用格力的，HIDL/AIDL 包装用 msm8996-common 已经走过的路。
5. Keymaster / Gatekeeper。分区里有 `keymaster`。Android 16 的 KeyMint 在这代 SoC 上用 HIDL keymaster 3 加软件回退，跟小米 22.2 的做法对齐。全盘加密迁移到文件加密放在系统能稳定启动之后。
6. 相机。32 位 HAL1、`camera.msm8996.so`、`mm-qcamera-daemon`，传感器库是格力私有的。donor 提供的是 provider、shim、命名空间和 sepolicy，不提供能出图的 chromatix。
7. Goodix GF816M 的 `gx_fpd`。要找 Goodix HIDL 2.1 的包装，而不是 FPC。
8. NFC 读卡。PN547 开源栈。eSE（`nxp,p61`）单独列，失败不阻塞其他硬件。
9. 红外。内核节点是 `raon,remote-ctrl`。Android 侧改成 vendor 服务，不再把 `RemoteIrManager` 打进 `frameworks/base`。`com.gree.irremote` 如果走的是 Raon 私有学习协议，标准 Consumer IR 不够。
10. Silabs SI4705 FM（`CONFIG_RADIO_SILABS`）。可以晚于“能打电话、能拍照”。

SELinux 现在是 permissive。早期启动可以继续 permissive，把 denial 记下来。最终目标是 enforcing。CM 那 8 个 te 文件只当设备节点备忘。

## 路线图

每个阶段都有可以在这台手机上观察的结果。没有这个结果就不进入下一阶段。刷写一律先 `fastboot boot`，确认画面和 adb 之后再 `fastboot flash`。启动链分区（aboot、xbl、tz、rpm、hyp、cmnlib、keymaster、modemst、fsg）不在实验范围内。

### 阶段 0：把现在这台还能用的机器封存

手机已经解锁。系统是 HALO 1.2.1 D1。recovery 分区里已经是能用的 TWRP 3.0.2-0，并且会用 default password 解开 data。图形界面可以备份 boot、system、data；persist、modem、modemst、fsg 不在它的 fstab 里，这几项在 TWRP 的 adb（本身就是 root）里用 `dd`。镜像不要提交进 git。

在 TWRP 的 adb 里执行。这里的 shell 已经是 root，不要再加 `su`：

```text
adb shell dd if=/dev/block/bootdevice/by-name/boot of=/tmp/boot.img bs=1048576
adb pull /tmp/boot.img
adb shell rm /tmp/boot.img
```

同样备份 recovery 本身、persist、modem、bluetooth、dsp、modemst1、modemst2、fsg、fsc。system 用 TWRP 备份或只读挂载后拷贝。data 用 TWRP 备份解密后的文件，不要只依赖一份未解密的 userdata 原样镜像。SSC 校准在 persist 里。`/data/su.img` 是 systemless root，清 data 会一起丢掉。系统里如果还要用 SuperSU，命令是 `adb shell su 0 ...`，那个包装只存在于 HALO，不在这块 recovery 里。

2026-10-26 的进度：阶段 0 的机器封存已经齐。分区 `dd` 覆盖 boot、recovery、persist、modem、bluetooth、dsp、fsg、modemst1、modemst2、fsc、system，放在移动硬盘。`fsc` 只有 4096 字节，内容全是 0。TWRP 文件备份覆盖 Data 和 System，md5 都通过，放在 `third_party/`（这个目录被 gitignore，里面还有应用私有数据，不要提交）。Data 备份里有 96 MB 的 `/su.img`，还有 SuperSU 刷入前保存的 boot。TWRP 的 Data 备份不包含内部存储 `/data/media`。没有更多现成文件可补这一项，照片和下载仍只在手机上。阶段 1 的过程记在 `docs/g0215d-phase-1.md`。

抽取 blob 时以这套 HALO 的 `/system` 为准。除了 `proprietary-files.txt` 和相机 XML 点名的库，还要带上触摸固件 `A4_2F_4.0_05.fw` 与 `Gree2_4005_V2.06_20170223.raw`。这两份固件已经在 System 的 TWRP 备份里。CM 列表里的 `A4_35_1.0_AA.fw` / `A4_35.raw` 在这台手机的 `/system/etc/firmware` 里不存在。高通二进制不要提交到公开仓库，本地留一份带校验和的清单。

本次检查已经读过 boot 分区，也进过这块 TWRP：系统内核是 2017-04-12 的原厂 `Image.gz-dtb`，ramdisk 含 MIUI 和 SuperSU；recovery 内核是 2016-10-07 的另一颗 `3.18.20-perf`，`cma=16M`。本阶段不刷写，也不要替换这块已经能解密 data 的 recovery。

### 手头的刷机包

`third_party/` 里另外有三份卡刷包，加上一份底层包。它们是档案，不是下一阶段的构建树。脚本里写了启动链分区的，不要刷。

| 包 | 实际内容 | 价值 |
| --- | --- | --- |
| `莫英新优化终结版-MIUI8_7.4.28.zip` | 2017-12 重新打包的 HALO / MIUI 8。`boot.img` 的内核与现在正在运行的 boot 字节相同（SHA256 前 12 位 `c26c077bb6f5`），ramdisk 与 SuperSU 保存的刷机前 boot 字节相同。包内有 `system/` 文件树、`supersu/supersu.zip`，以及 `firmware-update/` 里的 xbl、aboot、tz、rpm、modem 等。脚本末尾还试图写入 `system.new.dat` 和 `recovery.img`，这两个文件不在包里 | 高。这就是现在这套系统的来源，版本名 `7.4.28` 和机上 XBL 的版本字符串一致。TWRP 不在包里，recovery 是后来单独放进去的。脚本在缺文件之前就会改写启动链，只留档 |
| `RR-N-v5.8.5-20200727-g0215d-Unofficial.zip` | Resurrection Remix 5.8.5 非官方，Android 7.1.2，2020-07-28 由 CirnoSalt 编译，`ro.build.flavor=cm_g0215d-userdebug`。只刷 boot 和 system。boot 内核与机上 TWRP 字节相同（`2da13e56d874`），`cma=16M` | 中。说明 2020 年这套 CM 设备树的 Android 7.1 用户态能在这台机器上启动。不能调亮度不是面板驱动缺失：同一颗内核在 TWRP 里能写 `lcd-backlight`。问题在这份用户态的灯 HAL。不要拿它当内核基线 |
| `G0215D_lineage_181021.zip` | 2018-10-21 的自用包，脚本自称 lineage13。刷入一整份 3 GiB 的 `system.img`、一颗内核与原厂相同但 ramdisk 已替换的 `boot.img`，并把 `adspso.mbn` 写入 dsp，然后装 Magisk | 低到中。CyanogenMod 倒闭后的命名，不是 LineageOS 官方构建。它证明有人用原厂内核跑过一套 Android 6 的改版用户态。会改 dsp，不要当平台基线 |
| `1.2.2 h4-底层.zip` | 几乎只有 `firmware-update/`。脚本会格式化 data 和 system，再写 xbl、aboot、tz、modem 和它们的 bak | 只作 2015–2018 年底层文件的另一份副本。刷它会清掉现在的 data |

这三份卡刷包的 boot 里都没有一份新编译的、带完整格力 DTS 源码的内核。原厂内核只有 `c26c077bb6f5` 这一份，被 MIUI 包、正在运行的 boot、Lineage 13 包和 SuperSU 的 stock boot 共用。另一份是 `2da13e56d874`，被 TWRP 和 Resurrection Remix 共用。下一阶段的内核基线仍然是小米 `lineage-22.2`。

### 阶段 1：板级档案，不编译 Android

过程、命令结果和当时发生的事记在 `docs/g0215d-phase-1.md`。实机 DTS 在 `docs/reference/g0215d-msm8996-mtp.dts`，blob 校验和在 `docs/reference/g0215d-halo-blobs.sha256`。

这一阶段已经完成。DTS、I2C 核对、面板时序、驱动对照、blob 清单和 `device/gree/g0215d` 骨架都记在阶段 1 文档里。2017-08-14 的 `android_vendor_Gree_G0215D-Marshmallow` 是用户态专有文件，触摸固件和相机配置与 blob 清单一致，里面没有内核源码。`ATMEL_MXTS`、`GOODIX_GF816M_GF`、`RAON_REMOTE_CTRL_SOC`、`NFC_PN547_I2C` 在原厂配置里是编进内核的，小米和一加的内核里没有同名符号，留到阶段 2 再找源码。

完成标准：一份和实机 I2C 地址、compatible 一致的 DTS，以及一份可复现的 blob 清单。两份都在 `docs/reference/`。

### 阶段 2：内核启动到显示和 adb

过程记在 `docs/g0215d-phase-2.md`。内核在 `alpha-liu-01/android_kernel_gree_g0215d` 的 `g0215d` 分支，基线是小米 `lineage-22.2` 的 `535079d2fa36`。触摸驱动是乐视的 `atmel_mxt_ts_letv.c`。

这一阶段已经完成。当前内核是 `#17`（4.4.302，Mon Oct 26 15:43:24 EDT 2026）。`fastboot boot` 在这台 bootloader 上不可用，验证走的是 recovery 分区，boot 分区没有写。

- 基线是 `LineageOS/android_kernel_xiaomi_msm8996` 的 `lineage-22.2`，私有仓库只推了 `g0215d`。没有用一加 3 的 defconfig 覆盖
- defconfig 从 donor 的 MSM8996 配置长出来。`CONFIG_WIL6210` 没有打开
- 镜像是只带格力 DTB 的 `Image.gz-dtb`，4 KB 页，内核 `0x80008000`，ramdisk `0x81000000`，tags `0x80000100`。页对齐后内核落在 `0x80c36000`
- recovery 里 1440×2560 的 TWRP 连续三次重启没有横纹，Atmel 触摸可用，adb 状态是 `recovery`，USB 能保持到读完日志
- 用户态仍是原来的 TWRP ramdisk，加上 `phase2-debug.sh`。还不是 Android 16

完成标准：自编译内核在不刷写 boot 分区的前提下，能点亮这块倒装屏并完成一次触摸和 adb。`#17` 已超过“一次”。

留到阶段 3 再看、不再为它们编 recovery 的四件事：启动日志里仍有 `0x34`/`0x28` 的 DMA 超时；电源键熄屏再亮屏要等用户态自己管 blank；触摸配置仍是芯片 NVM 的 `53a963`，原厂 raw 要等 `/system` 挂上；系统 boot 仍是原厂 3.18。

### 阶段 3：第一套可交互系统（Lineage 18.1）

过程记在 `docs/g0215d-phase-3.md`。步骤 1 到 6 已结束，当前处于步骤 7（桌面硬件逐项验收与修复）。18.1 的 system 已写入，boot 分区保持原厂 `boot-debug4.img`，recovery 是 `#17`。清空 `sda9` 末尾 16 KB FDE footer 并格式化为未加密 ext4 后，系统已于 2026-10-27 首次走完 `LineageSetupWizard` 进入 `Launcher3` 桌面与 `Settings`，180 度倒装方向与 Atmel 触摸均正常。

针对首次进桌面暴露的四个问题（~2 FPS 帧率与滚动时双 DSI 半屏变黑闪烁、391 次 `hwservicemanager` 1 秒超时、USB 仅充电无 ADB、Wi-Fi 未启动），已完成根因定位并将修复推入 `/system`：
1. `gralloc.default` 改为单帧 `ashmem` 缓存后台缓冲 + `memcpy` + `FB_ACTIVATE_NOW | FB_ACTIVATE_FORCE` 同步提交，消除 Write-Combine 显存直绘慢与双 DSI 扫描清黑撕裂；
2. 补齐 `/vendor/etc/vintf/manifest.xml`，消除 391 次 `waitForHwService` 1 秒阻塞；
3. `init.gree.rc` 接好 `6a00000.dwc3` USB ConfigFS `ffs.adb` 并设 `ro.adb.secure=0`；
4. 实现 `lights.msm8996` + `light@2.0-service` 接管背光与 `fb0/blank` 休眠唤醒；
5. 提取 `modem`/`persist` 分区中的 QCA6174 固件（含 `otp30.bin`、`qwlan30.bin`、`bdwlan30.bin`、`wlan_mac.bin`）并推入 `android.hardware.wifi@1.0-service` 与 `wpa_supplicant`（已在 `#17` 内核下实测生成 `wlan0`）。
2026-10-27：交互项已经通过（显示、触摸、按键、Wi-Fi、音频、蓝牙、传感器、第一张卡的驻网和通话、休眠唤醒）。目标改为先把 18.1 做成日常可交付的系统，再进入阶段 4。7I USB 功能切换已通过（文件传输双向，PTP、MIDI、网络共享能枚举）。7J 振动已通过（DRV2605 v1.1 绑定，系统定时振动已下发；TWRP 本身以后再说）。剩余顺序是 7K 硬件视频和音频编解码 → 7L 相机出图 → 7M 指纹解锁。7K 没有记录之前不开始 7L。原来的 7G「相机和指纹只要求进程还在」作废。细节和验收标准在 `docs/g0215d-phase-3.md` 的步骤 7。

完成标准：18.1 可以日常使用。在交互项之外，USB 文件传输、振动、硬件编解码、前后摄拍照和短视频、指纹录入与解锁都通过。短信、VoLTE、第二张卡、NFC、红外、FM、SELinux enforcing 不挡住收口。SELinux 保持 permissive，denial 有记录。

### 阶段 4：分区改造，然后对齐小米 lineage-22.2

- 在桌面和蜂窝已经可用、并且备份仍然有效之后，再改分区
- 目标是能放下 Android 15 的 system + vendor（+ product/system_ext）。具体切割照小米 MSM8996 当时的公开方案核对自己的扇区，不在 userdata 仍加密时直接覆盖
- 把阶段 3 的板级目录改接到 `device/xiaomi/msm8996-common` 那种继承方式上：格力仓库只留 init、overlay、键位、音频校准、相机配置、灯、指纹、红外和 DTS
- 用户态换到与内核同一代的 22.2 接口：VINTF、AIDL/HIDL 版本、sepolicy、bpf

完成标准：Android 15 桌面，Wi-Fi、显示、触控、音频、蜂窝与阶段 3 等价。

### 阶段 5：Android 16

22.2 到 Android 16（Lineage 23 这一代，若届时 msm8996-common 已有人先升，就跟随那次升级）是一次平台跟随，不再是一次板级考古。跟随内容主要是 HAL 版本、sepolicy、bpf 和启动脚本。内核仍是这颗 3.18，只吸收 Android 16 新增加的、而且小米或一加树还没带上的补丁。

相机出图和指纹解锁在阶段 3 的 18.1 上就要能用。这一阶段在新平台上复查它们，并收口阶段 3 故意留下的硬件：

- 相机前后摄、对焦、闪光灯、方向（复查）
- Goodix 录入与解锁（复查）
- NFC 读写；eSE 单独记录结果
- 红外，包括格力遥控需要的原始码发送
- SI4705 FM
- 充电电流、休眠后基带唤醒、热、三色灯
- SELinux enforcing
- 文件加密可启动，且恢复出厂后仍能加密开机

### 阶段完成前不要做的事

- 不要从 CM13 的 `BoardConfig.mk` 逐项改名，试图直接喂给 Android 16 的构建系统
- 不要把一加 3 的 1080p AMOLED DTS、FPC 指纹和 IMX 相机配置写进格力
- 不要在没有备份时 `fastboot flash` boot、recovery 或 system
- 不要动 aboot、xbl、tz、rpm、modemst、fsg
- 不要把 `0001-add-remoteir.patch` 打进 Android 16 的 framework
- 不要把 4 KB 页改成 16 KB
- 不要并行维护 CM13 和 CM14.1 两套可编译树

## 建议的仓库形状

等阶段 1 开始写代码时，设备仓库保持这样，而不是把 `third_party` 里的 CM 树改到能编：

```text
device/gree/g0215d/          板级：init、overlay、音频 XML、相机 XML、键位、灯、红外、指纹、fstab
kernel/gree/msm8996/         fork 自小米 lineage-22.2，另加格力 DTS 与缺的驱动
vendor/gree/g0215d/          从这台 Android 6 抽出的 blob，本地保存
device/xiaomi/msm8996-common 或以后抽出的 common
                             显示、媒体、GPS、RIL 包装、电源、Wi-Fi、VINTF、sepolicy
```

`third_party` 三份树留在原地当档案，不作为 lunch 的目标。

## 风险

| 风险 | 依据 | 影响 |
| --- | --- | --- |
| 没有格力内核 git | 源码路径被注释，公开仓库不存在。ikconfig 和运行中的设备树已经导出 | 还要反编译完整 DTS 才能拿到时序和 GPIO。`ATMEL_MXTS`、GF816M、Raon、`RADIO_SILABS` 这些驱动若 donor 树里没有同名实现，就得从原厂内核或相近 CAF 树里把源文件找出来 |
| 3 GiB system 且无 vendor | 实机分区 | Android 15/16 镜像在重分区之前刷不进去 |
| 全盘加密但口令是默认值 | TWRP 日志写明 default password，数据约 7.5 GB | 现有 TWRP 能解开。格式化 data、重分区，或不认 footer cryptfs 的新 recovery 会毁掉它。图形备份不含 persist 和 modem |
| 32 位相机 HAL1 | `camera.msm8996.so` 在 `system/lib`，属性关闭 HAL3 | Android 16 上需要 provider 兼容层。出图依赖格力 chromatix，donor 不能替代 |
| Goodix 闭源守护进程 | `gx_fpd`，内核开关是 GF816M，64 位指纹 HAL | 能做 shim，不能换成一加 3 的 FPC |
| 传感器走 SSC | BMI160、AK09915、RPR0521、LPS22HB、SHTC1 都由 QTI SSC 上报 | `persist` 和 ADSP 固件损坏会让传感器整表消失。湿度传感器是这台机器的额外项 |
| 红外是 Raon 芯片加私有框架 API | compatible `raon,remote-ctrl`；`0001-add-remoteir.patch` 改的是 Android 7 的 framework；系统里有 `com.gree.irremote` | 内核驱动和用户态服务都要单独移植，标准 Consumer IR 不一定够用 |
| 4 GB 内存 + 1440p | 可见内存约 3.7 GB，framebuffer 1440x2560 | 比 1080p 的小米 5 更紧。日常使用要控制后台，GApps 不是这个目标的一部分 |
| 底包很旧，外面是 MIUI patchrom | 安全补丁 2016-06-01，SELinux permissive，显示名 HALO 1.2.1 D1 | 它仍是 blob、固件和 DTB 的来源。`/system` 已经叠了 MIUI 文件。备份完成之前，它也是这台手机唯一确认能用的系统。清数据会丢掉 systemless SuperSU |

## 参考位置

本地：

- `third_party/android_device_gree_g0215d-cm-14.1/BoardConfig.mk`
- `third_party/android_device_gree_g0215d-cm-14.1/proprietary-files.txt`
- `third_party/android_device_gree_g0215d-cm-14.1/partitions.txt`
- `third_party/android_device_gree_g0215d-cm-14.1/system.prop`
- `third_party/android_device_gree_g0215d-cm-14.1/init/init_g0215d.cpp`
- `third_party/android_device_gree_g0215d-cm-14.1/patches/frameworks/base/0001-add-remoteir.patch`
- `third_party/android_device_Gree_G0215D-Twrp-6.0/BoardConfig.mk`
- `third_party/android_device_Gree_G0215D-Twrp-6.0/twrp.fstab`
- `third_party/third_party_suggestions.md`（先前的判断；系统身份、面板、触摸、指纹和 donor 版本以本文实机结果为准）
- `docs/reference/g0215d-3.18.20-perf.config`（从这台手机的 `/proc/config.gz` 导出的 `3.18.20-perf` 配置）

实机上的相机配置：`/system/etc/camera/msm8996_camera_G0215D.xml`

上游：

- LineageOS oneplus3 wiki：官方版本停在 18.1
- `LineageOS/android_device_oneplus_oneplus3` 分支 `lineage-18.1`
- `LineageOS/android_kernel_oneplus_msm8996`
- `LineageOS/android_device_xiaomi_msm8996-common` 分支 `lineage-22.2`
- `LineageOS/android_device_xiaomi_gemini` 分支 `lineage-22.2`
- `LineageOS/android_kernel_xiaomi_msm8996` 分支 `lineage-22.2`
- 格力原树：`wuxianlin/android_device_gree_g0215d`，TWRP：`lbule/android_device_Gree_G0215D`
