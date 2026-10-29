# 阶段 1：Android 11 能亮屏、有 adb

日期：2026-10-29。路线图是 `docs/sambar-roadmap.md`，阶段 0 是 `docs/sambar-phase-0.md`。本文只记阶段 1。设备仓库在 `lineage-18.1` 分支上，捐赠内核在本地分支 `sambar-18.1`。`boot.img` 已编出，头已核对。步骤 6 证明 aboot 接受 `fastboot boot`。步骤 8 已经把这份 boot 和 Android 11 的 system 写进分区并重启了一次。adb 没有回来，手机也没有回到 fastboot。recovery 分区仍是 TWRP 2.8.7 加上内核 `#16`，见文末「Recovery 亮屏」和「步骤 8 记录」。

完成标准：一台从 LineageOS 18.1 编出来的系统能在 Yutopia 上点亮 Sharp 面板，Atmel 触控有反应，`adb` 能进去，`/data` 可写。Wi-Fi 驱动仍是模块。SELinux 允许 permissive。相机、指纹、IMS、蜂窝、蓝牙、音频留到后面的阶段。

不需要把一加 2 实机接上。它现在的系统是 Android 5 原厂，里面没有这份 18.1 内核。捐赠的是公开源码。fstab 里的 eMMC 控制器地址 `f9824900.sdhci` 和这台 Yutopia 的 `ro.boot.bootdevice` 已经相同，对不上的地方用阶段 0 的实机记录，不用再读那台一加。

## 从阶段 0 带过来的约束

bootloader 已解锁（`oem device-info`：unlocked、tampered）。fastboot 37.0.1 不带 `-i` 就能看见 `2a96:301c`。`max-download-size` 是 512 MiB。回退用的 boot 在 `/run/media/alpha/YMTC/sambar/device-backup/boot.img`，SHA256 `3ba6b7b5c4509d4ad6cc0d20bf40a75a03255c63d860b395d581dc1445a0f977`。

步骤 8 之前，正在运行的 boot 头是下面这份。boot 分区现在已经换成新镜像，这组数字只描述备份：

| 项 | 值 |
| --- | --- |
| page size | 4096 |
| kernel addr | `0x8000` |
| ramdisk addr | `0x01000000` |
| tags addr | `0x100` |
| kernel | gzip，8136468 字节 |
| ramdisk | gzip，1830727 字节 |
| DT | 单独的 QCDT 版本 2，11190272 字节，55 个 DTB |

cm-13.0 的 `BoardConfig.mk` 把 ramdisk 写成 `0x02000000`、tags 写成 `0x01E00000`。那一套和手机里的 TWRP 2.8.7 一致，和正在启动的 boot 不一致。一加 2 的 lineage-18.1 `BoardConfig.mk` 写的是 `BOARD_RAMDISK_OFFSET := 0x01000000`、`BOARD_KERNEL_TAGS_OFFSET := 0x00000100`，和实机 boot 一致。`BoardConfig.mk` 里的 `BOARD_RAMDISK_OFFSET` 已经改成 `0x02000000`，tags 仍是 `0x100`。这棵 Android 11 树的 boot 打包规则不读 `BOARD_RAMDISK_OFFSET`，`mkbootimg` 的默认值还是 `0x01000000`，所以同一行还写了 `BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)`。tags 在内核加载地址 `0x8000` 下面，解压不会盖住。

bootloader 会在镜像 cmdline 后面接上面板参数，不要写进 `BOARD_KERNEL_CMDLINE`：

```text
mdss_mdp.panel=1:dsi:0:qcom,mdss_dsi_sharp_qhd_cmd_0:1:qcom,mdss_dsi_sharp_qhd_cmd_1
```

对应内核源码 `arch/arm64/boot/dts/qcom/pm9x/dsi-panel-sharp-dual0qhd-cmd.dtsi` 和 `dsi-panel-sharp-dual1qhd-cmd.dtsi`。QCDT 里 soc id `0xcf`、variant `0x19` 的 v2.1 Compal 条目同时有 DVT3（`0x4`）和 PVT（`0x5`）。aboot 自己选。实机没有 `/proc/device-tree`，两份都留在镜像里。

手机里的 recovery 用户态仍是 TWRP 2.8.7，刷不了 Android 11 的包。安装 system 仍走 fastboot 的原始镜像。recovery 分区已经换成内核 `#16` 加原来的 TWRP ramdisk，用来确认这块屏能亮；回退镜像是 `/run/media/alpha/YMTC/sambar/device-backup/recovery.img`，SHA256 `5ee3d12aecfc966087003006ee92ec1b06dc01bc606528d9e1c4e10963c1f8e3`。boot 分区还是原来那份，坏掉的 boot 仍可从 fastboot 把 `device-backup/boot.img` 写回去。

`/data/media` 没有备份。格式化 userdata 会清掉照片和下载。Magisk 只备份了 `/data/adb`。第一次启动不格式化 userdata。system 和 boot 一起刷，不再用新内核单独启动 CM13。

## 捐赠树

2026-10-29 用 `git ls-remote` 看过这些仓库。一加 2 的设备树只做了一次 depth-1 克隆来读 `BoardConfig.mk`，放在临时目录，没有放进构建树。

| 仓库 | 阶段 1 用的分支 | 放到 |
| --- | --- | --- |
| `mukul2259/kernel_oneplus_msm8994` | `lineage-18.1` | `kernel/oneplus/msm8994` |
| `mukul2259/device_oneplus_oneplus2` | `lineage-18.1` | 只作对照，不参加 `lunch` |
| `mukul2259/device_oppo_common` | `lineage-18.1` | `device/oppo/common`。依赖文件点了它。最高只到 19.1 |
| `LineageOS/android_hardware_sony_timekeep` | 与 18.1 清单匹配的分支 | `hardware/sony/timekeep`。依赖文件点了它，第一版亮屏可以先不编进产品 |
| 硬盘上的 `lineage-18.1/` | 已有 | Android 11 用户态。里面已有 `device/qcom/sepolicy-legacy` |
| 本仓库 `cm-13.0` | 不动 | 分区、fstab、按键、音频、专有文件清单、Sharp/Atmel/Silead 的来源 |
| `/run/media/alpha/YMTC/sambar/blobs/` | 阶段 0 | Yutopia 自己的 blob。不用一加 2 的 vendor 仓库覆盖 |

`mukul2259` 的内核和设备仓库还有 `lineage-19.1` 到 `lineage-23.2` 这些分支名。官方 `LineageOS/android_kernel_oneplus_msm8994` 停在 `lineage-18.0`，没有 18.1。阶段 1 的内核底是 mukul 的 `lineage-18.1`，不是 23.2，也不是官方 18.0。那些更高的分支名不证明这台手机能启动 Android 16。

一加 2 的 18.1 `BoardConfig.mk` 里，下面这些值不能抄：

| 项 | 一加 2 | Yutopia |
| --- | --- | --- |
| system | 2684354560（2.5 GiB） | 3221225472（3 GiB） |
| userdata | 59047394304 | 26419412992 左右，以阶段 0 的扇区数为准 |
| `BOARD_FLASH_BLOCK_SIZE` | 262144 | cm-13.0 是 131072，先保持 131072 |
| 密度 | 480 | 560，1440x2560 |
| cmdline 的 `boot_cpus` | `0-3` | 实机是 `0-5` |
| 内核配置 | `oneplus2_defconfig` | 新的 sambar 配置 |
| 双击唤醒 | `/proc/touchpanel/double_tap` | 删掉。触控是 Atmel maXTouch |
| 指纹 | `android.hardware.biometrics.fingerprint@2.0-service.oneplus2` | 阶段 1 不编 |
| 内核镜像名 | `Image.gz-dtb` | 见下节。aboot 吃的是分离的 QCDT |

可以沿用的：`TARGET_BOARD_PLATFORM := msm8994`，Adreno 430，`BOARD_USES_HWC2`，`TARGET_HAS_MEMFD_BACKPORT`，`product_launched_with_l_mr1`，`sepolicy-legacy`，`BOARD_ROOT_EXTRA_FOLDERS := firmware bt_firmware persist`，HIDL manifest 的骨架，fstab 里 `f9824900.sdhci` 这条控制器路径。

## 实现笔记

aboot `sambar-12-g5c5fdd4` 读的是 boot 镜像里单独的 QCDT（魔数 `QCDT`，版本 2），不是把 DTB 粘在 gzip 内核尾巴上的 `Image.gz-dtb`。一加 2 的 18.1 把 `BOARD_KERNEL_IMAGE_NAME` 设成 `Image.gz-dtb`。直接照抄的话，旧 aboot 可能找不到面板的 DTB。阶段 1 的 boot 镜像：header 里 kernel 是 gzip，ramdisk 另放，dt 字段指向 `dtbTool -2` 生成的 QCDT。page、kernel 地址、gzip 魔数、QCDT 魔数和版本跟实机 boot 对齐。ramdisk 地址不跟实机 boot，见步骤 7。`second_size` 保持 0，`second_addr` 写成实机的 `0xf00000`；`mkbootimg` 写不进这个字段，打包后改头里偏移 28。对不上就不碰手机。

cmdline 从实机 boot 头那条起头，保留 `boot_cpus=0-5`、console 和 `androidboot.hardware=qcom`。第一版加上 `androidboot.selinux=permissive`。一加 2 的 `loop.max_part=7` 可以留下。面板那串由 bootloader 追加。

Wi-Fi 在 cm-13.0 的 `BoardConfig.mk` 里写明必须是模块，否则这台机器起不来。移植 defconfig 时 `wlan` 保持 `=m`，不要收进内核。阶段 1 不要求连上网络。

设备树新分支从 `cm-13.0` 拉出来，但构建用的内容是薄的一层。cm-13.0 里整棵搬进来的 QCamera、GPS loc_api、IPA 源码不进第一版。那些留在 `cm-13.0` 上当档案。指纹 HAL、Silead 的 `fpsvcd` 也不进第一版。

system 没有独立的 vendor 分区。和一加 2 一样，vendor 文件放在 `/system/vendor`。阶段 0 的 blob 清单路径相对 `/system`。`libjni_livedisplay.so` 在 `/system/lib` 和 `/system/lib64`，不在 `vendor/lib64`。

userdata 现在是未加密的 f2fs。Android 11 的 f2fs 和 2017 年的不一定兼容。第一次能进系统时，如果 `/data` 挂不上，再格式化，并在刷之前把这件事写进事件节。格式化是单独的一步，不和第一次刷 boot 绑在一起。

不要刷的分区：aboot、tz、rpm、hyp、sbl1、pmic 以及它们的 bak，modem、bluetooth、persist、modemst、fsg、fsc。这些的只读副本已经在 `device-backup/`。

`fastboot boot` 能把一份镜像交出去，但这颗 LK 留不住新内核，手机会回到 fastboot。新内核不再拿去启动 CM13。第一次进 Android 11 用 `fastboot flash boot` 加 `fastboot flash system`，见步骤 8。回退 boot：

```bash
fastboot flash boot /run/media/alpha/YMTC/sambar/device-backup/boot.img
fastboot reboot
```

回退 system 只能靠阶段 0 没抽的整分区，或者重新刷回 `third_party/lineage-13.0-20171020-UNOFFICIAL-sambar.zip`。TWRP 2.8.7 能刷这个 2017 年的 zip。所以 system 一旦被 Android 11 镜像盖掉，回到今天这个系统要靠 TWRP 和那份 zip，不靠 fastboot 里的 system 备份。刷 system 之前把这件事再确认一遍。

## 目录

```text
/run/media/alpha/YMTC/lineage-18.1/                 已有的 Android 11 树
/run/media/alpha/YMTC/sambar/donor/                 阶段 1 要克隆的捐赠仓库
/run/media/alpha/YMTC/lineage-18.1/kernel/oneplus/msm8994
/run/media/alpha/YMTC/lineage-18.1/device/yu/sambar 指向本仓库的新分支
/run/media/alpha/YMTC/lineage-18.1/device/oppo/common
/run/media/alpha/YMTC/lineage-18.1/vendor/yu/sambar 从阶段 0 的 blobs 生成，不进设备仓库的 git
```

本仓库继续放在 `~/Documents/GitHub/android_device_yu_sambar`。用符号链接放进 Android 树，不要再克隆一份。

## 进度

步骤 1 到 6 已完成，见事件节。Recovery 亮屏也完成了，但那不是本阶段的完成标准：当时跑的是 TWRP 用户态，不是 Android 11。步骤 8 做了第一次启动，没有进到 adb。

| 步骤 | 状态 |
| --- | --- |
| 1–4 | 已完成。`lineage-18.1` 分支、捐赠树、`sambar_defconfig`、设备树骨架都在 |
| 5 | 已完成。`mka bootimage` 能编过 |
| 6 | 已完成。`fastboot boot` 备份的 boot 镜像会进原来的 Lineage 13 |
| Recovery 亮屏 | 已完成。内核 `#16` 只写在 recovery。背光修复在内核 DTS 里，后面的 boot 镜像带着它 |
| 7 | 已结束，不再继续。新内核不启动 CM13。ramdisk 地址的修改留下，给步骤 8 的 boot 镜像用。见「步骤 7 记录」 |
| 8 | 卡在第一屏，不会自己重启。第一次的内核日志被 recovery 的 bootlog 盖掉了。分区路径不能改成没有 `soc.0` 的那条。见「步骤 8 记录」 |
| 9–10 | 还没做。完成标准要等 adb 回来 |

## 步骤 1：建分支

在本仓库：

```bash
git status
git checkout cm-13.0
git checkout -b lineage-18.1
```

`cm-13.0` 留在原地。这一步不推远程。工作区里的 `third_party/` 和 `docs/` 是未跟踪或已跟踪的文档，跟到新分支上没有关系；不要把 `third_party/` 加进 git。

然后删掉不参加 18.1 构建的大块源码：`camera/`、`gps/`、`data-ipa-cfg-mgr/`，以及只为 CM13 服务的 `configpanel/`、`keyhandler/`。删之前确认 `cm-13.0` 上还有它们。音频 XML、按键布局、`rootdir/`、两份 proprietary 清单、`liblight` 先留着，后面按 18.1 的安装路径改。

## 步骤 2：克隆捐赠并接上构建树

```bash
mkdir -p /run/media/alpha/YMTC/sambar/donor
git clone --depth 1 -b lineage-18.1 \
  https://github.com/mukul2259/kernel_oneplus_msm8994.git \
  /run/media/alpha/YMTC/sambar/donor/android_kernel_oneplus_msm8994
git clone --depth 1 -b lineage-18.1 \
  https://github.com/mukul2259/device_oneplus_oneplus2.git \
  /run/media/alpha/YMTC/sambar/donor/android_device_oneplus_oneplus2
git clone --depth 1 -b lineage-18.1 \
  https://github.com/mukul2259/device_oppo_common.git \
  /run/media/alpha/YMTC/sambar/donor/android_device_oppo_common
```

内核克隆进 Android 树时用链接，避免两份 3.10 源码：

```bash
mkdir -p /run/media/alpha/YMTC/lineage-18.1/kernel/oneplus \
         /run/media/alpha/YMTC/lineage-18.1/device/yu \
         /run/media/alpha/YMTC/lineage-18.1/device/oppo
ln -s /run/media/alpha/YMTC/sambar/donor/android_kernel_oneplus_msm8994 \
  /run/media/alpha/YMTC/lineage-18.1/kernel/oneplus/msm8994
ln -s /home/alpha/Documents/GitHub/android_device_yu_sambar \
  /run/media/alpha/YMTC/lineage-18.1/device/yu/sambar
ln -s /run/media/alpha/YMTC/sambar/donor/android_device_oppo_common \
  /run/media/alpha/YMTC/lineage-18.1/device/oppo/common
```

内核仓库自己的改动用它自己的分支，例如 `sambar-18.1`，不要提交回一加 2 的 defconfig 里。设备仓库的分支是 `lineage-18.1`。

## 步骤 3：内核差额

以一加 2 的 `oneplus2_defconfig` 为底，做成 `sambar_defconfig`。必须从本仓库对应的 Cyanogen 内核和阶段 0 的 `boot.ikconfig` 对过去的开关：

- `CONFIG_TOUCHSCREEN_ATMEL_MXT_PM9X`
- `CONFIG_SILEAD_DEVICE`
- Sharp 双 DSI 面板的 dtsi 被某份 DTB 引用
- `wlan` 为模块
- `CONFIG_LOCALVERSION` 设成能看出来是 sambar 的字符串，打开 `CONFIG_IKCONFIG`，方便下次从 boot 里再抽配置

把这些源文件从 `/home/alpha/Documents/GitHub/android_kernel_cyanogen_msm8994` 补进一加 2 内核，如果那边没有同名驱动：

- `arch/arm64/boot/dts/qcom/msm8994-v2.1-pm9x-dvt3.dts`
- `arch/arm64/boot/dts/qcom/msm8994-v2.1-pm9x-pvt.dts`
- `arch/arm64/boot/dts/qcom/pm9x/` 里 Sharp 面板、Silead 和 PM9X 的 dtsi
- Atmel `MXT_PM9X` 驱动、Silead 驱动、TFA9887 相关的机器驱动差额

DTB 列表用 dtbTool 版本 2 打成 QCDT，里面至少要有 variant `0x19` 的 DVT3 和 PVT。一加 2 自己的 DTB 可以留在同一个 QCDT 里，aboot 按板号选，不会拿 1080p 的板去配这台机器。不要只留下一加 2 的 MTP DTB。

Android 11 会从 DTB 的 `firmware/android/fstab/system` 提前挂 system。一加 2 的 fstab 注释写了这件事。sambar 的 2016 年 DTS 没有这个节点。从一加 2 的 DTS 把这个节点的写法搬过来，分区改成这台机器的 `system`，控制器仍是 `f9824900.sdhci`。没有这个节点就不要刷 system，先把 boot 卡在挂载上的日志存下来。

第一版内核不必开 enforcing，也不必为了相机或指纹加驱动。Silead 驱动可以编进去，用户态先不装。

## 步骤 4：设备树骨架

在 `lineage-18.1` 分支上放这些文件。路径按 `device/yu/sambar` 写，因为链接进去之后 Android 树看到的是这个路径。

- `AndroidProducts.mk` 注册 `lineage_sambar`
- `lineage_sambar.mk` 继承 `core_64_bit`、`full_base_telephony`、`product_launched_with_l_mr1`、本机 `device.mk`、`vendor/lineage/config/common_full_phone.mk`。品牌 YU，型号 YU5050，设备名 `sambar`
- `BoardConfig.mk` 用上一节的偏移和分区大小。`TARGET_KERNEL_SOURCE := kernel/oneplus/msm8994`，`TARGET_KERNEL_CONFIG := sambar_defconfig`。包含 `device/qcom/sepolicy-legacy/sepolicy.mk`。cmdline 含 `androidboot.selinux=permissive`
- `device.mk` 只放亮屏和 adb 需要的东西：显示密度、按键、fstab、init、firmware/bt_firmware/persist 的挂载、阶段 0 已经在的 lights。不继承一加 2 的指纹、doze、IMS
- `rootdir/etc/fstab.qcom` 从一加 2 那份改分区大小和加密：userdata 现在未加密。system 行如果交给 DTB 提前挂载，fstab 里保留 recovery 用的那条
- 按键用 cm-13.0 的 `gpio-keys.kl`、`qpnp_pon.kl`。不拷一加 2 的触控键位
- 音频 XML 先从 cm-13.0 的 `audio/` 拷进骨架，但阶段 1 不把声音当作完成条件
- `manifest.xml` 从一加 2 的 HIDL 清单减到第一版能编过的集合。指纹和 IMS 的 HAL 条目去掉

专有文件先不要全部塞进第一版镜像。亮屏需要的显示和固件如果缺了，从 `blobs/manifest.tsv` 里按路径补，缺了再记 `missing`，不要用一加 2 的同名库顶上。

## 步骤 5：只编 boot

在 `/run/media/alpha/YMTC/lineage-18.1`：

```bash
source build/envsetup.sh
lunch lineage_sambar-userdebug
mka bootimage
```

`lunch` 失败就停，把缺的依赖写进事件节，不要改用一加 2 的 lunch 名称来绕过。

编出的 `boot.img` 解头：page 4096，kernel `0x8000`，tags `0x100`，kernel 以 `1f 8b` 开头，dt 以 `QCDT` 开头且版本是 2。有一条 variant `0x19` 的 DTB。ramdisk 地址按步骤 7 处理，不要为了和实机旧 boot 对齐而留在 `0x01000000`。对不上就不碰手机。

## 步骤 6：用现有 boot 试 `fastboot boot`

手机进 bootloader。先证明命令本身可用，用的是今天正在运行的那份镜像：

```bash
fastboot boot /run/media/alpha/YMTC/sambar/device-backup/boot.img
```

回到原来的 Lineage 13，并且 `uname` 仍是 `3.10.84-lineageos-gc7efee3`，就说明 `fastboot boot` 可用。aboot 拒绝这条命令的话，记下文案，步骤 7 改为 `fastboot flash boot`，刷之前再次核对备份文件的 SHA256。

## 步骤 7：不再用新内核启动 CM13

这一步结束了，不要再做。当时想留下 Lineage 13 的 system，只换 boot，用面板亮不亮把内核和用户态拆开。recovery `#16` 已经证明这块屏能亮。`fastboot boot` 新镜像会回到 fastboot，而且停在内核自己的初始化里，CM13 的 `/init` 没有跑到。继续这个组合，失败了也分不清是内核还是 Android 6 的用户态。

留下的只有 boot 镜像布局：ramdisk `0x02000000`，tags `0x100`，`second_addr` `0xf00000`。过程在「步骤 7 记录」。

## 步骤 8：Android 11 的第一次启动

和格力阶段 3 一样：新 boot 和新 system 一起刷。不先用新内核启动 CM13。

在 `/run/media/alpha/YMTC/lineage-18.1`：

```bash
mka systemimage
```

`mka systemimage` 失败就停，把缺的依赖写进事件节。阶段 1 已经拿掉 qcwcn HAL，不要为了编过再把 Wi-Fi 用户态加回来。

`out/target/product/sambar/system.img` 是稀疏镜像。展开后的字节数必须不超过 3221225472。大于就停，先减包，不改分区表。

boot 用同一棵树编出来的 `boot.img`。刷之前解头：ramdisk 地址是 `0x02000000`，解压末端仍在这个地址下面，头里偏移 28 的 `second_addr` 是 `0xf00000`。`mka bootimage` 会把 `second_addr` 写成 0，打包后要再改。cmdline 保留 `sambar.bootlog=1`，失败时日志在 misc 偏移 1 MiB。

刷之前再对一次 boot 备份的 SHA256 `3ba6b7b5c4509d4ad6cc0d20bf40a75a03255c63d860b395d581dc1445a0f977`。回退 system 的 zip `third_party/lineage-13.0-20171020-UNOFFICIAL-sambar.zip` 要还在。阶段 0 没有 system 整分区备份。

BCB 必须是空的。留着 `boot-recovery` 的话，重启进的是 recovery，不是新系统。recovery 分区保持 `#16`，不要刷回 stock。起不来时从 fastboot 写 BCB，或者按键进这块 recovery，读 misc 里的 bootlog。

只刷这两个分区，然后重启一次。不格式化 userdata，不刷 cache，不刷 recovery，不做 `fastboot -w`。

```bash
fastboot flash boot out/target/product/sambar/boot.img
fastboot flash system out/target/product/sambar/system.img
fastboot reboot
```

回退 boot：

```bash
fastboot flash boot /run/media/alpha/YMTC/sambar/device-backup/boot.img
```

回退 system 进 recovery `#16`，刷 `third_party/lineage-13.0-20171020-UNOFFICIAL-sambar.zip`。TWRP 2.8.7 能刷这个 2017 年的包。

第一次启动只看到它离开 bootloader 为止。卡在加密或 `/data` 挂载时，不在这一轮格式化 userdata，也不擦 persist 或 modem。格式化要单独做，并且先把「照片不在备份里」写进事件节。

## 步骤 9：验收

adb 回来之后记这些：

```bash
adb shell getprop ro.build.version.release
adb shell getprop ro.build.version.sdk
adb shell uname -a
adb shell getenforce
adb shell cat /proc/cmdline
adb exec-out su -c "cat /sys/class/graphics/fb0/msm_fb_panel_info" 
adb shell getevent -lp
adb shell touch /data/local/tmp/phase1-write && adb shell rm /data/local/tmp/phase1-write
```

完成时应当同时满足：`ro.build.version.release` 为 11，面板名仍是 Sharp 那条，`getevent` 里有 `atmel_mxt_ts`，`/data/local/tmp` 能创建文件。`getenforce` 是 Permissive 可以接受。Wi-Fi 接口可以不存在。

## 步骤 10：写回本文

补进事件节：捐赠仓库的 commit、`sambar_defconfig` 和一加 2 defconfig 的差额摘要、boot 镜像解头结果、`fastboot boot` 是否被 aboot 接受、第一次亮屏或失败时的 last kmsg 路径、有没有格式化 userdata。镜像和 last kmsg 留在硬盘上，不进 git。

## 本阶段禁止

- 不刷 aboot、tz、rpm、hyp、modem、persist、modemst、fsg
- 不执行 `oem unlock` 或 `flashing unlock`
- 不刷 `third_party/` 里任何 TWRP，包括标成 BROKEN 的那份
- 不用一加 2 的 system、vendor 或固件镜像
- 不在新 boot 失败时格式化 userdata
- 不把 `lineage-23.2` 当成这一阶段的用户态
- 不把 cm-13.0 分支重置或删掉

## Recovery 亮屏

2026-10-29，内核 `3.10.108-sambar+ #16`（Thu Oct 29 12:41:46 EDT 2026）加上原来的 TWRP 2.8.7 ramdisk，用户确认 recovery 里能看到 TWRP 画面，背光也在。在此之前 `#10` 到 `#15` 都是 adb 进得去、触摸有振动、通知灯能闪绿，玻璃全黑，背光也没有。boot 分区没有写。

镜像是 `/run/media/alpha/YMTC/sambar/phase1/recovery-fet.img`，18640896 字节。kernel 是 gzip，放在 `0x8000`；ramdisk 是原来的 TWRP cpio，6741280 字节，放在 `0x02000000`；tags 是 `0x01e00000`。`mkbootimg` 不理会 second 偏移，头里偏移 28 的 `second_addr` 是事后写成 `0xf00000` 的。只写了 `mmcblk0p36`。重启前把 misc 开头 2048 字节写成 `boot-recovery`，没有动 misc 偏移 1 MiB 处的 bootlog。TWRP 起来之后会自己把 BCB 清掉，下一次从系统里重启之前要再写一次，否则这颗 LK 会去启动 boot 分区里的 Android 6。

写这份记录的时候，boot 镜像的 ramdisk 还在 `0x01000000`，解压后的 Image 会盖住它。后来挪到了 `0x02000000`，见「步骤 7 记录」。recovery 用的就是这个地址。

原因是背光电流的开关被捐赠树关掉了，不是 WLED 寄存器本身。

Yutopia 的板级把 PMI8994 的 MPP 4 标成 WLED 的外部 FET。`pm9x/msm8994-pm9x.dtsi` 里 `&pmi8994_mpps` 的 `mpp@a300` 注释就是 `WLED FET`，配成数字输出、`master-en` 打开。一加 2 的 `msm-pmi8994.dtsi` 在同一地址上又放了一个 `qcom,leds@a300`，注释是 2015-03-25 为按键背光加的，`linux,name` 是 `button-backlight`，`qcom,id = <6>`，`qcom,default-state = "off"`，`qcom,mode-ctrl = <0x60>`。stock recovery 的 PVT DTB 没有这个节点。这个 LED 驱动 probe 时把 MPP 4 配成电流沉并保持关闭，板级那条数字输出被盖掉，WLED 后面的 FET 不导通。

`#15` 全黑时的读数：WLED 模块使能 `0x3D846 = 0x80`，灯串掩码和亮度与 stock recovery、以及 Android 亮屏时一致；LAB/IBB 已是 VREG_OK。同一时刻 PMI8994 MPP 4 的 `0x2A340` 起是 0，也就是 mode 和 `0x2A346` 的 master enable 都是 0。`/sys/class/leds/button-backlight/brightness` 是 0。

`#16` 启动后约 9 秒、TWRP 还没熄屏时的读数：`0x2A340 = 0x18`，`0x2A346 = 0x80`，`0x3D846 = 0x80`，`lcd-backlight` 是 255。`qpnp-pin.c` 里 mode 寄存器的 [6:4] 是 mode、[3:1] 是 source。`0x18` 的 mode 是数字输出，source 字段是 4。板级节点没有写 `qcom,src-sel`，这个 4 是原来留在寄存器里的值。`/sys/class/leds` 里不再有 `button-backlight`。

改动：

- `arch/arm/boot/dts/qcom/msm-pmi8994.dtsi`：给 `qcom,leds@a300` 加标签 `pmi8994_mpp4_led`。64 位 DTS 用的是这份文件。
- `arch/arm/boot/dts/qcom/pm9x/msm8994-pm9x.dtsi`：`&pmi8994_mpp4_led { status = "disabled"; };`。`mpp@a300` 的数字输出配置不动。

编出来的 PVT DTB 里，`qcom,leds@a300` 的 `status` 是 `disabled`，PMI8994 的 `mpp@a300` 仍是 `status = "okay"`、`qcom,mode = <1>`、`qcom,master-en = <1>`。

下面这些在 `#16` 之前已经看过，都不是这块屏不亮的原因，不要再当成修复去改：

- `qcom,en-cabc`。stock 的 DTB 没有它。`#13` 删掉之后 CABC 位已经是 0，屏幕仍黑。这个删除留着。
- DCS `0x51` / `0x53`。stock recovery 和亮着的 Android 都读回 0。`#14` 把它们写成 `0x24` 和 `0xFF` 之后仍然全黑。这两字节还在 `#16` 的 on-command 里，亮屏不靠它们。
- WLED 的 `MODULE_RDY`（`0xD845`）。Android 亮屏时也是 0。
- LAB/IBB、TPS65132、KTD 闪光灯 GPIO。偏置已经 VREG_OK。TPS65132 这条机器不用。KTD 是相机闪光灯。
- 命令模式自动刷新。`#15` 打开后左右 pingpong 的行计数都在走，玻璃仍黑。dmesg 里是 `mdss_dsi_fifo_status` 的 `status=99991080`、`88881080`，以及 `ctl0 reset timedout`。`#16` 已把 `mdss_mdp_intf_cmd.c` 的这段退回。stock TWRP 不打开自动刷新。
- `qcom,cont-splash-enabled` 还在两块 Sharp 面板上。`#11` 拿掉它之后提交返回 EPERM（splash handoff pending）。要拿掉就必须同时做 `mdss_mdp_footswitch_ctrl_splash(false)`。

和 stock recovery 的 PVT DTB 仍有差别、这次没有改的：PM8994 的 MPP 4、5、8 在捐赠树里是模拟输入，stock 里是 disabled；WLED 节点少了 stock 的 `qcom,dim-method = "linear"` 和 `qcom,ibb-pwrup-dly = <8>`。`#16` 没有这些也能亮，先不动。

## 步骤 7 记录

2026-10-29 做了这一步。面板没有被确认点亮。boot 分区和 system 都没写。做完之后手机回到原来的 Android 6，`uname` 是 `3.10.84-lineageos-gc7efee3`。

`BoardConfig.mk` 把 `BOARD_RAMDISK_OFFSET` 改成 `0x02000000`。第一次重新打包，头里的 ramdisk 地址仍是 `0x01000000`。`build/make/core/Makefile` 的 `INTERNAL_BOOTIMAGE_ARGS` 只传 `--base`、`--pagesize`、`--cmdline` 和 `--dt`，不传 `BOARD_RAMDISK_OFFSET`。`mkbootimg.py` 的默认值就是 `0x01000000`，所以步骤 5 的镜像碰巧和实机旧 boot 一致。补上 `BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)` 之后，地址才变成 `0x02000000`。tags 保持 `0x100`。

`mkbootimg` 在没有 second bootloader 时把 `second_addr` 写成 0，`--second_offset` 不生效。打包后把头里偏移 28 改成 `0xf00000`，`second_size` 仍是 0。下次 `mka bootimage` 会把这个字段盖回 0，要再改一次。

用来 `fastboot boot` 的镜像是 `/run/media/alpha/YMTC/sambar/phase1/boot-ramdisk-02000000.img`，也写在 `out/target/product/sambar/boot.img`。12738560 字节，SHA256 `f4c7d49002cbd0db440b5c98a601981be62206af36ab6ba6f6c4281bce157db1`。解头：kernel gzip `0x7f28bf` 在 `0x8000`，解压后 `0x124d8d0` 字节，末端 `0x12558d0`；ramdisk `0xcc7a7` 在 `0x02000000`；中间空隙 `0xdaa730`，约 13.7 MiB；tags `0x100`；dt 是 QCDT 版本 2。cmdline 在原来的基础上加了 `ignore_loglevel loglevel=8 sambar.bootlog=1`。构建系统还会接上 `buildvariant=userdebug`。

第一次 `fastboot boot` 没有 bootlog 参数。命令返回 Sending OKAY、Booting OKAY，手机几秒内回到 fastboot。这颗 LK 复位时清 DRAM，pstore 是空的，没有日志。

第二次用上面那份带 bootlog 的镜像，同样 Sending OKAY、Booting OKAY，又回到 fastboot。misc 偏移 1 MiB 的记录留下来了，在 `/run/media/alpha/YMTC/sambar/phase1/bootlog-step7.txt`，81436 字节。内核是 `3.10.108-sambar+ #19`，编译时间 Thu Oct 29 12:58:35 EDT 2026。机器字符串是 `MSM8994v2.1 Compal PM9X PVT`。`Trying to unpack rootfs image as initramfs` 之后 `Freeing initrd memory: 816K`，所以 ramdisk 放在 `0x02000000` 没有被解压内核盖住。Sharp 两块面板都 probe 了，`FrameBuffer[0] 1440x2560` 注册成功，`fb0/cabc` 重复文件名的警告还在，和 recovery 一样，不是这次复位的原因。日志停在 1.64 秒的 `load`，没有 panic 行，也没有 `Freeing unused kernel memory`。用户态没起来。

boot 分区头没变：kernel 8136468 字节，ramdisk 在 `0x01000000`，`second_addr` `0xf00000`。从 fastboot 直接重启回到 Android 6，BCB 是空的。没有刷回备份，因为分区没被写过。

`fastboot boot` 在这颗 LK 上能把镜像交出去，但不能让这颗内核留在系统里。同一颗内核从 recovery 分区启动可以留下来。不再用它启动 CM13。Android 11 的第一次启动改为 boot 和 system 一起刷，见步骤 8。不要再对这份镜像做一次没有新日志的 `fastboot boot`。

## 步骤 8 记录

2026-10-29 做了第一次启动。没有格式化 userdata，没有刷 cache，没有刷 recovery。做完之后手机不在 adb，也不在 fastboot，USB 上没有 `2a96`。没有再重启第二次。

`mka systemimage` 中途停过三次，都不是缺包：

- `board-info.txt` 只有注释。`grep -v '#'` 没有匹配就返回 1，`android-info.txt` 编不出来。补了一行 `require board=MSM8994`，和 `TARGET_BOOTLOADER_BOARD_NAME`、fastboot 的 `product` 一致。没有写 baseband 或 bootloader 版本。
- system 镜像要把 ramdisk 根并进去。`/bt_firmware` 没有标签。`sepolicy/` 里的 CM13 `.te` 没有编进 Android 11。新增 `sepolicy/vendor/file_contexts`，`BoardConfig.mk` 用 `BOARD_VENDOR_SEPOLICY_DIRS` 只加这个目录。构建树是按文件做的符号链接，这个新文件要单独链到 `device/yu/sambar/sepolicy/vendor/file_contexts`。
- 下一轮缺的是 `/file_contexts.bin`，补了 `file_contexts_file`。`/firmware` 和 `/persist` 在 qcom 策略里已经有标签。

第四次 `mka systemimage` 成功，54 秒。`system.img` 是稀疏镜像，文件 1499435504 字节，SHA256 `ea6cc732cc5f314d544f21cb28376546991bb990b4fa78ce182e3bd1e5777535`。展开后 3221225472 字节，正好等于分区，没有超过。树本身大约 1419 MiB。

刷进去的 boot 仍是步骤 7 那份，没有重新打包。12738560 字节，SHA256 `f4c7d49002cbd0db440b5c98a601981be62206af36ab6ba6f6c4281bce157db1`。ramdisk `0x02000000`，`second_addr` `0xf00000`，tags `0x100`，解压末端 `0x12558d0`，空隙 `0xdaa730`。内核 `3.10.108-sambar+ #19`。cmdline 含 `sambar.bootlog=1`。

刷之前 BCB 是空的。boot 备份 SHA256 仍是 `3ba6b7b5c4509d4ad6cc0d20bf40a75a03255c63d860b395d581dc1445a0f977`。回退 system 的 zip 还在。

`fastboot flash boot`：Sending OKAY，Writing OKAY。主机 fastboot 报 `boot partition size: 0`，这颗 LK 的 `getvar` 不回报分区大小，写命令本身是 OKAY。`fastboot flash system` 分成 3 段稀疏数据，三段 Writing 都是 OKAY，一共 64.8 秒。然后 `fastboot reboot` 一次。

重启后大约三分钟：`adb devices` 是空的，`fastboot devices` 是空的，`lsusb` 里没有这台手机。用户看到的是第一屏，机器不自己重启。强制重启进了 recovery。

进 recovery 之后 misc 里的记录已经不是这次启动。recovery `#16` 的 cmdline 也有 `sambar.bootlog=1`，它自己的日志把 Android 启动记录盖掉了。这份 recovery 日志在 `phase1/bootlog-recovery-after-step8.txt`，内核是 `#16`，里面是 TWRP 的 `service recovery`。`/data` 上没有这次 Android 11 留下的新 tombstone 或 dropbox。

当时误以为块设备路径不该带 `soc.0`，因为 TWRP 里实际节点是 `/dev/block/platform/f9824900.sdhci/by-name/system`。改了 DTB 和 `fstab.qcom` 之后刷了内核 `#26`。它在 1.67 秒进了 first stage init，随后 `inotify_add_watch` 对这个目录返回 ENOENT，大约 21 秒后手机回到 fastboot。日志是 `phase1/bootlog-step8b.txt`。Android 11 的 init 按 sysfs 路径建链接，sysfs 是 `/devices/soc.0/f9824900.sdhci`，所以 by-name 是 `/dev/block/platform/soc.0/f9824900.sdhci/by-name/system`。TWRP 2.8.7 的 ueventd 会省掉 `soc.0`。这条路径改回去了。

recovery 分区换成了 `phase1/recovery-nolog.img`。内核仍是 `#16`，cmdline 去掉了 `sambar.bootlog=1`，之后进 recovery 不会再盖 misc 里的启动日志。boot 和 system 随后刷回带 `soc.0` 的内核 `#27`（boot SHA256 `58534ebb7830adc873c3d16da47dc704c8fedf3edb2843bfdb569953b9812197`，system SHA256 `84c2006b4e1c9dedb532972a1d5bd2588aa287f93b317baff0484193b5172057`）。重启后大约一分半，USB 上仍然没有 adb，也没有回到 fastboot。这次的 bootlog 还在 misc 里，要读它就再强制进 recovery。不要对这份镜像做 `fastboot boot`。

## 振动和发热

2026-10-29 读了卡在第一屏、机身发热那次的记录。misc 窗口在 `phase1/bootlog-step8f.txt`，内核 `#27`，大约 85 秒到 121 秒，更早的被环覆盖。`/data/anr/anr_1975-02-20-01-08-00-046` 里 `system_server` 主线程停在 `VibratorService.vibratorInit`。manifest 声明了 `android.hardware.vibrator` 1.0 hwbinder，镜像里只有 `vibrator.default.so`，没有服务进程。`IVibrator::getService()` 对这种 HAL 一秒钟重试一次，不返回。窗口管理器排在它后面，所以开机动画不会被要求退出。

发热不是这次等待。watchdog 的全核栈里 CPU 0、2、3、4 都在 `BootAnimation` 用户态，寄存器是像素填充。SwiftShader 在软件渲染 1440x2560 的开机动画，`msm_thermal` 把 CPU5 压到 960 MHz。healthd 电流大约 1 A，电量计温度停在 25.0。用户看到的仍是第一屏，这些帧没有换掉 LK 的 splash。recovery 里 `/sys/class/timed_output/vibrator/enable` 存在。

这次 system 镜像装了 `android.hardware.vibrator@1.0-service`、`android.hardware.vibrator@1.0-impl` 和 `vibrator.default`。`debug.sf.nobootanimation=1`，开机动画不再占核。`ro.surface_flinger.has_wide_color_display=false`、`ro.surface_flinger.has_HDR_display=false`，窗口管理器不会再等 configstore。稀疏文件 1590174228 字节，SHA256 `aba9be54acf634238af00cdbf1cfa380c303ef76298a1af742db15ab64ddacbd`，展开后正好 3221225472。三段 Writing 都是 OKAY。只刷了 system，boot 仍是 `#27`。没有格式化 userdata。然后重启了一次。

## 音频策略和背光

2026-10-29 振动服务那次之后仍然卡第一屏，机身还是热。misc 记录是 `phase1/bootlog-step8g.txt`，内核仍是 `#27`。`/data/anr/anr_2026-10-29-15-49-56-618` 里 `system_server` 主线程已经过了振动，停在 `AudioService` 构造函数。`AudioSystem::get_audio_policy_service()` 在 `media.audio_policy` 没注册时每 0.5 秒重试，不返回。audioserver 要先拿到 `IDevicesFactory` 才会把这个服务注册出去，而 manifest 里的 audio 2.0 没有进程，`getService()` 同样不返回。watchdog 大约一分钟后杀掉 system_server，zygote 跟着重启，再卡在同一个地方。`/data/system/dropbox` 里有 `system_server_watchdog`。

这次全核栈里其他 CPU 在 idle，没有开机动画线程。发热是 1440p 面板停在 LK 留下的全亮度 splash 上。日志末尾电流大约 0.89 A，电量计温度仍是 25.0。

这次 system 镜像：

- 装上 `android.hardware.audio.service`、`android.hardware.audio@2.0-impl`、`android.hardware.audio.effect@2.0-impl`。`audio.primary.default.so` 本来就在。
- keymaster 从 3.0 改成软件实现的 4.0 服务。keystore 对清单里有、进程没有的 3.0 会一直等，等不到就不会注册自己。
- gatekeeper 从清单去掉。`gatekeeperd` 找不到 HAL 会记一条错误然后继续，不再每秒重试。
- `init.qcom.rc` 在 `on fs` 和 `on boot` 把 `lcd-backlight` 写成 40。

稀疏文件 1592848916 字节，SHA256 `6b9cb50be8e4429c40982d5bcdfacd17e9809f461dfe59a594487a506497d7e9`，展开后正好 3221225472。三段 Writing 都是 OKAY。只刷了 system。没有格式化 userdata。然后重启了一次。

## 语音触发和背光电流

2026-10-29 上一份镜像仍然卡第一屏。机身发热，背光没有暗下来。misc 记录是 `phase1/bootlog-step8h.txt`，内核仍是 `#27`，窗口大约 85 秒到 121 秒。`/data/anr/anr_2026-10-29-15-59-51-541` 里 `system_server` 主线程已经过了音频，停在 `ISoundTriggerHw.getService`，调用链是 `SoundTriggerMiddlewareService`。manifest 声明了 soundtrigger 2.0 hwbinder，镜像里没有实现。`vendor.audio-hal` 已经在跑，但可选接口注册失败，框架这边每秒重试一次，不返回。watchdog 仍然在杀 system_server。

`lcd-backlight` 写成 40 没有作用。连续 splash 还在时，`mdss_fb_set_backlight()` 只把亮度存进 `unset_bl_level` 就返回，不写硬件。面板电流走 PMI8994 的 WLED，sysfs 节点是 `/sys/class/leds/wled/brightness`，满量程 4095。这条路径直接写 sink 寄存器，不看 splash。recovery 里把这个节点写成 200，读回就是 200，然后恢复成 4095。日志末尾电流大约 0.93 A。全核栈里其他 CPU 在 idle，不是开机动画占核。

这次 system 镜像：

- 装上 `android.hardware.soundtrigger@2.0-impl`（32 位）。已经在跑的音频服务会按 2.3、2.2、2.1、2.0 试可选接口，2.0 能注册之后，`getService()` 才返回。没有 primary 模块时 `getProperties` 回 `-ENODEV`，中间件把这个模块丢掉，服务仍然发布。不能从清单删掉这一项，否则 `getService()` 抛异常，`system_server` 直接退出。
- `init.qcom.rc` 在 `on fs` 和 `on boot` 把 `wled` 写成 512，`lcd-backlight` 仍是 40。后者留给 splash 交接之后用。

稀疏文件 1593012756 字节，SHA256 `ef3aca65b1d12c70374942811a4003776107482d41b8fa07af99b922851cb6c3`，展开后正好 3221225472。三段 Writing 都是 OKAY，总时间 71.7 秒。只刷了 system，boot 仍是 `#27`。没有格式化 userdata。然后重启了一次。

## FRP 路径

2026-10-29 上一份镜像背光已经暗下来，仍然卡第一屏，机身还在发热。misc 记录是 `phase1/bootlog-step8i.txt`。没有新的 ANR。`/data/system/dropbox/system_server_crash@1793304664003.txt` 里 `system_server` 在阶段 500 崩溃：`TestHarnessModeService` 读持久分区，`PersistentDataBlockService` 抛 `invalid checksum`。zygote 大约每 5 秒拉起一次，同样崩溃。语音触发已经过了。日志里电流大约 0.60 A，比全亮时的 0.93 A 低。splash 还在，所以机身继续热。

`config` 分区（`mmcblk0p25`，1 MiB）上的 SHA-256 和分区内容是对得上的，末尾的 OEM unlock 字节仍是 1。抛异常是因为文件打不开。`ro.frp.pst` 指向 `/dev/block/bootdevice/by-name/config`。这份 `init.qcom.rc` 没有一加 2 那条符号链接，Android 11 的 ueventd 只建 `/dev/block/platform/soc.0/f9824900.sdhci`。打不开时摘要算出来是空，服务把它当成校验失败。没有去改这个分区。

这次 `on fs` 在挂载之前加上：

```
wait /dev/block/platform/soc.0/${ro.boot.bootdevice}
symlink /dev/block/platform/soc.0/${ro.boot.bootdevice} /dev/block/bootdevice
```

稀疏文件仍是 1593012756 字节，SHA256 `315f3a87c55e49a35ad3c56c443a13e0d7ece1519c7d4c730903f3621e821ffe`，展开后正好 3221225472。三段 Writing 都是 OKAY，总时间 71.8 秒。只刷了 system，boot 仍是 `#27`。没有格式化 userdata，也没有写 `config`。然后重启了一次。

## 关掉 FRP 服务

2026-10-29 符号链接那次背光和上次一样，仍然卡第一屏，机身还在发热。misc 记录是 `phase1/bootlog-step8j.txt`。崩溃还是阶段 500 的 `invalid checksum`，`phase1/system_server_crash-step8j.txt`。`config` 分区头 40 字节和末尾的 OEM unlock 字节都没变，服务没有写进去。ueventd 建节点时只看它自己创建的链接。权限规则写的是 `/dev/block/bootdevice/by-name/config`，对不上 `/dev/block/platform/soc.0/f9824900.sdhci/by-name/config`，节点保持默认的 `0600 root`。`system_server` 打不开，`FileInputStream` 变成摘要为空，再被当成校验失败。

`ro.frp.pst` 从 `system.prop` 去掉。属性为空时 `PersistentDataBlockService` 不启动。`TestHarnessModeService` 拿不到这个服务就返回，不再抛异常。`config` 分区不动。

稀疏文件 1593012756 字节，SHA256 `3d73760ed94d08e6c529db672bf44289273aed1a999270c76f012751570846c6`，展开后正好 3221225472。三段 Writing 都是 OKAY，总时间 71.9 秒。只刷了 system，boot 仍是 `#27`。没有格式化 userdata，没有写 `config`。然后重启了一次。

## 情景模式

2026-10-29 去掉 `ro.frp.pst` 之后仍然卡第一屏，背光和上次一样，机身还在发热。misc 记录是 `phase1/bootlog-step8k.txt`。`system_server` 过了阶段 500，在阶段 550 崩溃。记录是 `phase1/system_server_crash-step8k.txt`。`ProfileManagerService.initialize` 构造 `ProfileTriggerHelper`，`WifiManager` 是空的，`getActiveSSID()` 直接调用 `getConnectionInfo()`。Wi-Fi 服务还没发布，这是阶段 2 的事。dropbox 里另有 `No service published for: wifi` 和找不到 `/proc/wakelocks` 的 WTF，都不是这次退出的原因。

`lineage-sdk` 里的 `ProfileTriggerHelper.getActiveSSID()` 在 `WifiManager`、`WifiInfo` 或 SSID 为空时返回 null。这个改动在构建树 `lineage-sdk/lineage/lib/main/java/org/lineageos/platform/internal/ProfileTriggerHelper.java`，不在设备仓库。

稀疏文件 1593016852 字节，SHA256 `2d8c3bec5582ffbf48c39c1842f8c40107214d9a8d464aa1b950a33bc709a0c3`，展开后正好 3221225472。三段 Writing 都是 OKAY，总时间 71.7 秒。只刷了 system，boot 仍是 `#27`。没有格式化 userdata。然后重启了一次。

## 黑屏有背光

2026-10-29 情景模式那次之后，用户看到已经离开第一屏，变成有背光、没有画面。misc 记录是 `phase1/bootlog-step8l.txt`，窗口大约 6 秒到 31 秒。7.45 秒和 7.82 秒各有一次 `blank on`，SurfaceFlinger 在 7.82 秒拉起 `bootanim`，149 毫秒后以状态 0 退出。`debug.sf.nobootanimation=1` 还在，开机动画不会画帧。splash 交出去之后缓冲区是黑的，背光仍由 WLED 512 维持。当时电流大约 0.86 A。

`system_server` 没有再崩。`com.android.systemui` 在循环崩溃，记录是 `phase1/systemui-crash-step8l.txt`。`SystemServicesModule.provideWifiManager()` 不是 `@Nullable`，`WifiManager` 为空时 Dagger 直接抛异常，状态栏和锁屏都起不来。镜像里没有 `android.hardware.wifi`，`SystemServer` 因此不启动 `WifiService`。`wificond` 已经在跑。

`device.mk` 增加 `frameworks/native/data/etc/android.hardware.wifi.xml`。有这个 feature 之后 `WifiService` 会注册 `wifi` 服务。驱动和 supplicant 仍是阶段 2 的事，`checkAndStartWifi()` 在自己的线程里跑，不挡主线程。

稀疏文件 1593020948 字节，SHA256 `914afb9c23568875b3df30637d35a28962969ccee2e0f09d11276bf9cfc6f204`，展开后正好 3221225472。三段 Writing 都是 OKAY，总时间 72.0 秒。只刷了 system，boot 仍是 `#27`。没有格式化 userdata。然后重启了一次。

## 关屏动画

2026-10-29 声明 Wi-Fi 之后又回到第一屏。misc 记录是 `phase1/bootlog-step8m.txt`，窗口大约 88 秒到 121 秒。没有新的 SystemUI 崩溃。`system_server` 崩了 14 次，记录是 `phase1/system_server_crash-step8m.txt`。显示线程在 `ColorFade.captureScreenshotTextureAndSetViewport` 里调用 `SurfaceTexture.updateTexImage()`，SwiftShader 抛 `Error during updateTexImage`。这个异常没有接住，显示线程一死，整个 `system_server` 退出，splash 又留在面板上。98 秒时 `bootanim` 仍是拉起后大约 0.13 秒就退出。另有一条 WTF 说 `SystemServer` 初始化用了 306 秒，那是同一次启动里反复重启累计的。

`ColorFade` 在 `updateTexImage()` 抛异常时记一条错误并返回 false，关屏动画改走跳过的分支。改动在构建树 `frameworks/base/services/core/java/com/android/server/display/ColorFade.java`，不在设备仓库。

稀疏文件 1593025044 字节，SHA256 `3182d8653405ba5fd960bf84318bb2f0a764e32863dd3588b2d038b2f2c8b31c`，展开后正好 3221225472。三段 Writing 都是 OKAY，总时间 71.9 秒。只刷了 system，boot 仍是 `#27`。没有格式化 userdata。然后重启了一次。

## LiveDisplay

2026-10-29 关屏动画接住之后仍然卡第一屏。misc 记录是 `phase1/bootlog-step8n.txt`。没有新的 `system_server` 崩溃。watchdog 记录是 `phase1/watchdog-step8n.txt`，主题是显示线程堵住。`WindowManagerService.performEnableScreen` 要等开机动画结束，接着 `LiveDisplayService` 构造 `DisplayHardwareController`，`IAdaptiveBacklight.getService(true)` 不返回。manifest 里声明了 `vendor.lineage.livedisplay` 2.0 的 `IAdaptiveBacklight`、`IDisplayColorCalibration` 和 `IPictureAdjustment`，没有进程注册。`getService(true)` 对这种接口一秒钟重试一次。亮屏停在这一步，splash 不交接。SystemUI 已经在跑。当时电流大约 0.06 A。

这三项从 `manifest.xml` 去掉。不在清单里时 `getService(true)` 立刻抛 `NoSuchElementException`，`LineageHardwareManager` 接住后当作不支持。后面真有实现再加回来。

稀疏文件 1593020948 字节，SHA256 `233665f16e705c0319ac7a8cd6bc01e2e03bd831382535e38cf5af5b2dcfc82a`，展开后正好 3221225472。三段 Writing 都是 OKAY，总时间 71.8 秒。只刷了 system，boot 仍是 `#27`。没有格式化 userdata。然后重启了一次。

2026-10-29 按当时的源码重新打包了一次。核对过：manifest 里没有 `vendor.lineage.livedisplay`，`android.hardware.wifi.xml` 在，`wled` 仍是 512，`ro.frp.pst` 没有，`ColorFade` 仍接住截屏失败。稀疏文件 1593016852 字节，SHA256 `5d9ec32432c9153415e4780cd81a6ddadae2f201d740b86f97a1864450304848`，展开后正好 3221225472。三段 Writing 都是 OKAY，总时间 71.8 秒。只刷了 system，boot 仍是 `#27`。没有格式化 userdata。然后重启了一次。

## 持久日志和 adb

2026-10-29 去掉 LiveDisplay 之后仍是 YU 标志，不再循环。这次没有 `system_server` 崩溃，也没有 watchdog。dropbox 里是 `com.android.phone` 处理 `BOOT_COMPLETED` 的 ANR，记录是 `phase1/step8o/appanr-prev-boot.txt`，CPU 列表里 Launcher3、Settings、SystemUI 都在。也就是 Android 已经开完机。misc 记录是 `phase1/bootlog-step8n2.txt`，窗口从 38 秒开始，显示相关的行都已滚掉。38 秒以后电流在 0.04 到 0.09 A，splash 亮着时是 0.6 到 0.9 A，背光基本是关的。设置里 `screen_off_timeout` 是 30000，开机向导已标记完成。

先让下一次能看清：`system.prop` 打开 `persist.logd.logpersistd=logcatd`，16 个 2 MiB 文件写进 `/data/misc/logd`。`init.sambar.rc` 在 `sys.boot_completed=1` 时用 `settings` 写 `stay_on_while_plugged_in`。后一项没有生效，读回仍是 0，后来改用 adb 写。system SHA256 `e65453ecae5632ef32df127dd839ad8aa41c092025c0e789a418c4752a2cc9fd`。只刷了 system，重启一次。主机这边 USB 上出现 `18d1:4ee7`，接口是 ff/42/01，adb 却一直是 `offline`。用户说之后手机自己重启过，再手动进了 recovery。

`/data/misc/logd` 里有四次启动，拼起来是 `phase1/step8o/lc.txt`。每次都是日志写到半行就断，没有关机流程，是硬复位，原因看不到。最后几秒没落盘。三处结论：

- 图形分配器打不开 `/dev/ion` 和 `/dev/kgsl-3d0`，errno 13。`qdgralloc: gralloc failed err=Permission denied`，RenderEngine 的占位缓冲、壁纸、通知栏和 1440x2560 的缓冲全部分配失败。SurfaceFlinger 没有东西可画，命令模式面板里留着的还是 LK 的 YU 标志。SELinux 是 permissive，所以是 DAC。ueventd 只读到 `/system/etc/ueventd.rc`，`/vendor/ueventd.rc` 和 `/ueventd.qcom.rc` 都不存在，AOSP 那份没有 ion 和 kgsl 的规则，两个节点都是 `0600 root`。仓库里的 `rootdir/etc/ueventd.qcom.rc`（CM13 原样）从没装过。`device.mk` 把它按绝对路径装成 `$(TARGET_COPY_OUT_VENDOR)/ueventd.rc`。
- adbd 两条 USB 路径默认都用 AIO。非阻塞路径打出 `failed to submit first read, AIO on FFS not supported`，退到旧路径后又是 `aio: got error submitting read: Invalid argument`，每几毫秒重绑一次 functionfs，dwc3 报 `request ... was not queued to ep0out`。3.10 的 f_fs 没有 AIO。`system.prop` 加 `ro.adb.nonblocking_ffs=0` 和 `sys.usb.ffs.aio_compat=true`，后者让旧路径改用阻塞读写。
- 硬复位是否和 adbd 的重绑循环有关，日志证明不了。

稀疏文件 1593029140 字节，SHA256 `35b42a50154cd6b995ee5bf089c9302dfcbec735746edd7f467fd5be859ee75e`，展开后正好 3221225472。三段 Writing 都是 OKAY，总时间 71.6 秒。只刷了 system，boot 仍是 `#27`。没有格式化 userdata。然后重启了一次。

开机后大约 10 秒 adb 就是 `device`，不用再进 recovery 取日志。`sys.boot_completed=1`。`/dev/ion` 是 `0664 system system`，`/dev/kgsl-3d0` 是 `0666 system system`，日志里没有分配失败。SurfaceFlinger 用 HWC overlay 合成三层，`powerMode=On`。面板 9.3 秒解除 blank。抓图时手机已按 30 秒超时睡下，`lcd-backlight` 和 `wled` 都是 0。用 adb 写了 `stay_on_while_plugged_in 7` 和 `screen_off_timeout 1800000`，再发 `KEYCODE_WAKEUP`，读回 `lcd-backlight` 102、`wled` 1638，灯 HAL 在工作。截图是锁屏，「没有通知」。第一次截图里有人画过两个点，提示「图案错误」，触控进了框架。壁纸上有横向黑色扫描线，SurfaceFlinger 的截图里就有，不是面板问题。gralloc 打 `AdrenoUtils: Unknown Chip ID 0`，对齐可能和 SwiftShader 不一致，还没查。现场记录在 `phase1/live-step8p/`。

## 去掉锁屏

2026-10-29 锁屏是 CM13 留下的图案。`dumpsys lock_settings` 里用户 0 的类型是 Pattern，质量 65536，`SP Handle` 是 0，最后修改时间是 0。`/data/system/gatekeeper.pattern.key` 58 字节，`gatekeeper.password.key` 是空文件，没有 `spblob`。`ro.crypto.state` 是 `unsupported`。这份 18.1 没有对应的 Gatekeeper，旧图案校验不过。内部存储当时已挂上，`/storage/emulated/0` 约 2.6 GB，`DCIM` 约 367 MB。没有格式化 userdata。

Android 里的 adb 不是 root。重启进 recovery 后只删了三个文件：`/data/system/locksettings.db`、`gatekeeper.pattern.key`、`gatekeeper.password.key`。`/data/media/0/DCIM` 还在，`/data` 仍是 24.6 GB 的 f2fs，已用 3.4 GB。然后重启回 Android。

开机后凭证类型是 None，质量 0。滑开之后 `isKeyguardShowing=false`，焦点是 Launcher3。应用列表里有拨打电话、短信、AudioFX、计算器。壁纸上的横条还在。

## 事件

- 2026-10-29：阶段 0 已完成，手机在 Android 6 的非官方 Lineage 13 上。本文写好时，`lineage-18.1` 分支还没建，捐赠内核还没克隆进 `sambar/donor/`。
- 2026-10-29：核对了 mukul2259 的一加 2 设备树 `lineage-18.1`。它的 ramdisk/tags 偏移与正在运行的 boot 相同，与本仓库 cm-13.0 的 `BoardConfig.mk` 不同。system 分区大小、密度、`boot_cpus`、指纹和双击唤醒节点不能照抄。
- 2026-10-29：同一作者的内核和设备仓库带有直到 `lineage-23.2` 的分支名。官方一加 2 内核停在 `lineage-18.0`。阶段 1 仍以 mukul 的 `lineage-18.1` 为内核底。
- 2026-10-29：决定不接一加 2 实机。公开树和阶段 0 的实机记录够用。
- 2026-10-29：设备仓库从 `cm-13.0` 拉出 `lineage-18.1`，未推远程。`camera/`、`gps/`、`data-ipa-cfg-mgr/`、`configpanel/`、`keyhandler/` 已从工作区删除，删除还停在暂存区，没有提交。
- 2026-10-29：捐赠仓库 depth-1 克隆到 `/run/media/alpha/YMTC/sambar/donor/`。内核 `3fd1d6d2`，一加 2 设备树 `24ede80`，`device_oppo_common` `6ff6662`。内核本地分支 `sambar-18.1`，没有提交。
- 2026-10-29：Soong 的 finder 不进入符号链接目录。`device/yu/sambar` 改成指向本仓库各文件的链接，这样改本仓库就是在改构建树。内核目录仍是一条指向捐赠克隆的符号链接，`make -C` 会跟着走。
- 2026-10-29：`sambar_defconfig` 从 `oneplus2_defconfig` 改来。`CONFIG_LOCALVERSION="-sambar"`，`CONFIG_IKCONFIG_PROC=y`，`CONFIG_MODULES=y`（一加 2 原配置关掉了模块，`wlan` 会被收成内建），`CONFIG_QCA_CLD_WLAN=m`，`CONFIG_TOUCHSCREEN_ATMEL_MXT_PM9X=y`，`CONFIG_SILEAD_DEVICE=y`。CLD 下面的 bool 功能项先关掉，否则这份 kconfig 会把父项抬回 `=y`。Wi-Fi 功能项留到阶段 2。
- 2026-10-29：PM9X 的 DTS 接到一加 2 的 `msm8994.dtsi` 上。补了 `memory`、`qpnp_leds`、`pmi8994_wled`、`pm8994_poweron` 这些标签。`firmware/android/fstab/system` 已经在一加 2 的 `msm8994.dtsi` 里，路径就是 `f9824900.sdhci` 的 system，没有另写一份。PVT DTB 的 `qcom,board-id` 含 `0x19`，里面有 `qcom,mdss_dsi_sharp_qhd_cmd_0/1` 和 `silead_fp`。Cyanogen 内核里没有 TFA9887 机器驱动，阶段 1 不搬。
- 2026-10-29：主机没有 `/usr/bin/python`。把 aarch64 和 arm 两套 gcc 4.9 包装脚本的 shebang 改成 `python3`，否则内核编不过。这是构建树里的预编译工具，不进设备仓库。
- 2026-10-29：`mka bootimage` 第一次停在 `libwifi-hal-qcom` 缺 `libwpa_client`。阶段 1 不编 supplicant，`BoardConfig.mk` 里的 qcwcn HAL 开关已去掉。内核仍是 `CONFIG_QCA_CLD_WLAN=m`。
- 2026-10-29：qcacld 编 `wlan_hdd_hostapd.c` 失败，因为 `WLAN_HDD_GET_SAP_CTX_PTR` 包在 `WLAN_FEATURE_MBSSID` 里，而 Kbuild 只在 `CONFIG_QCA_WIFI_AUTOMOTIVE_CONC=y` 时加这个宏。打开这一项后 `olddefconfig` 仍是 `CONFIG_QCA_CLD_WLAN=m`，没有抬回内建。`wlan.ko` 装到 `system/lib/modules/wlan.ko`，内核版本 `3.10.108-sambar+`。
- 2026-10-29：`mka bootimage` 成功。`out/target/product/sambar/boot.img` 12734464 字节。解头：page 4096，kernel `0x8000`，ramdisk `0x01000000`，tags `0x100`，kernel `1f 8b`，dt 为 QCDT 版本 2、36 条。chipset `0xcf`、platform `0x19`、subtype `0x4`（DVT3）和 `0x5`（PVT）都在，两份 DTB 都有 Sharp 双面板、`atmel,maxtouch` 和 `silead_fp`。`second_addr` 备份是 `0x00f00000`、新镜像是 0，`second_size` 都是 0，不挡步骤 6。
- 2026-10-29：步骤 6。备份 SHA256 仍是 `3ba6b7b5c4509d4ad6cc0d20bf40a75a03255c63d860b395d581dc1445a0f977`。`fastboot boot` 该文件：Sending OKAY，Booting OKAY。adb 回来后 `uname` 为 `3.10.84-lineageos-gc7efee3`，`ro.build.display.id` 为 `YUTOPIA-userdebug 6.0.1 MOI10E bda6cc43b0 test-keys`。aboot 接受 `fastboot boot`。步骤 7 还没做，system 和 boot 分区都没写。
- 2026-10-29：recovery 亮屏。内核 `#16` 加 TWRP 2.8.7 ramdisk 写进 recovery 分区，用户确认画面和背光都在。原因是一加 2 的 `qcom,leds@a300`（`button-backlight`，默认关闭）占住了 Yutopia 的 WLED FET，也就是 PMI8994 MPP 4。`#15` 上该脚 mode 和 enable 都是 0，WLED 本身已是 `0x3D846=0x80`。`#16` 关掉这个 LED 节点后，MPP 4 读回 `0x2A340=0x18`、`0x2A346=0x80`。镜像是 `phase1/recovery-fet.img`。boot 和 system 没写。细节在「Recovery 亮屏」。
- 2026-10-29：步骤 7 没有通过。`BOARD_RAMDISK_OFFSET` 改成 `0x02000000`，并经 `BOARD_MKBOOTIMG_ARGS` 传给 `mkbootimg`，否则地址仍是默认的 `0x01000000`。`second_addr` 打包后写成 `0xf00000`。`fastboot boot` 两次都回到 fastboot，boot 分区没写。第二次的 misc bootlog 显示内核 `#19` 解开了 initramfs，Sharp 面板和 1440x2560 framebuffer 已注册，然后在 1.64 秒复位，没有 panic 行。日志是 `phase1/bootlog-step7.txt`。手机回到 Android 6。细节在「步骤 7 记录」。
- 2026-10-29：不再用新内核启动 CM13。步骤 7 结束。Android 11 改为 boot 和 system 一起刷。
- 2026-10-29：步骤 8 的第一次启动。`system.img` SHA256 `ea6cc732cc5f314d544f21cb28376546991bb990b4fa78ce182e3bd1e5777535`，展开后正好 3221225472。boot 是步骤 7 那份 `#19`。两个分区都 Writing OKAY，然后重启一次。大约三分钟后 USB 上没有 adb，也没有 fastboot。没有第二次重启，没有格式化 userdata，recovery 没动。细节在「步骤 8 记录」。
- 2026-10-29：用户确认卡在第一屏，不自己重启，并强制进了 recovery。misc 里读到的是 recovery `#16` 自己的 bootlog，Android 那次被盖掉了。去掉 `soc.0` 的路径是错的，内核 `#26` 因此在 first stage 等设备，约 21 秒后回到 fastboot。路径已改回。recovery 换成不写 bootlog 的 `recovery-nolog.img`。boot/system 刷回内核 `#27` 后，USB 仍然既没有 adb 也没有 fastboot。细节在「步骤 8 记录」。
- 2026-10-29：发热的那次仍卡第一屏。`system_server` 卡在振动 HAL，SwiftShader 的开机动画占着四颗核。system 换成带振动服务、关掉开机动画的镜像，SHA256 `aba9be54acf634238af00cdbf1cfa380c303ef76298a1af742db15ab64ddacbd`。只刷了 system，重启一次。细节在「振动和发热」。
- 2026-10-29：振动过了，主线程改卡在音频策略服务。watchdog 在杀 system_server。背光仍是全亮。system 换成带默认音频 HAL、软件 keymaster 4.0、背光 40 的镜像，SHA256 `6b9cb50be8e4429c40982d5bcdfacd17e9809f461dfe59a594487a506497d7e9`。只刷了 system，重启一次。细节在「音频策略和背光」。
- 2026-10-29：音频过了，主线程改卡在 soundtrigger 2.0。`lcd-backlight` 写成 40 没有把 splash 调暗，连续 splash 期间这条节点不写硬件。system 换成带 `soundtrigger@2.0-impl`、并把 `wled` 写成 512 的镜像，SHA256 `ef3aca65b1d12c70374942811a4003776107482d41b8fa07af99b922851cb6c3`。只刷了 system，重启一次。细节在「语音触发和背光电流」。
- 2026-10-29：背光已经暗下来，`system_server` 改为在阶段 500 崩溃。`TestHarnessModeService` 打不开 `/dev/block/bootdevice/by-name/config`。system 换成在 `on fs` 建立 `bootdevice` 符号链接的镜像，SHA256 `315f3a87c55e49a35ad3c56c443a13e0d7ece1519c7d4c730903f3621e821ffe`。只刷了 system，没有写 `config`，重启一次。细节在「FRP 路径」。
- 2026-10-29：符号链接之后崩溃相同，`config` 分区没有被改写。节点权限仍是 `0600 root`。去掉 `ro.frp.pst`，不再启动 `PersistentDataBlockService`。system SHA256 `3d73760ed94d08e6c529db672bf44289273aed1a999270c76f012751570846c6`。只刷了 system，重启一次。细节在「关掉 FRP 服务」。
- 2026-10-29：FRP 过了，阶段 550 在情景模式里空指针。`WifiManager` 还没有。`ProfileTriggerHelper.getActiveSSID()` 改为空则返回。改动在构建树的 `lineage-sdk`，不在设备仓库。system SHA256 `2d8c3bec5582ffbf48c39c1842f8c40107214d9a8d464aa1b950a33bc709a0c3`。只刷了 system，重启一次。细节在「情景模式」。
- 2026-10-29：离开第一屏，变成有背光、没有画面。splash 已交接，开机动画立即退出，SystemUI 因缺少 `WifiManager` 崩溃。补上 `android.hardware.wifi.xml`。system SHA256 `914afb9c23568875b3df30637d35a28962969ccee2e0f09d11276bf9cfc6f204`。只刷了 system，重启一次。细节在「黑屏有背光」。
- 2026-10-29：Wi-Fi 声明之后 SystemUI 不再崩，关屏动画的 `updateTexImage()` 把 `system_server` 打崩，又回到第一屏。`ColorFade` 改为接住这个异常并跳过动画。改动在构建树的 `frameworks/base`，不在设备仓库。system SHA256 `3182d8653405ba5fd960bf84318bb2f0a764e32863dd3588b2d038b2f2c8b31c`。只刷了 system，重启一次。细节在「关屏动画」。
- 2026-10-29：关屏动画不再崩进程，显示线程改卡在 `IAdaptiveBacklight.getService(true)`，亮屏完不成。从 manifest 去掉 `vendor.lineage.livedisplay` 的三项接口。system SHA256 `233665f16e705c0319ac7a8cd6bc01e2e03bd831382535e38cf5af5b2dcfc82a`。只刷了 system，重启一次。细节在「LiveDisplay」。
- 2026-10-29：按去掉 LiveDisplay 三项之后的源码重新打包。system SHA256 `5d9ec32432c9153415e4780cd81a6ddadae2f201d740b86f97a1864450304848`。只刷了 system，重启一次。细节在「LiveDisplay」。
- 2026-10-29：仍是 YU 标志，但 `BOOT_COMPLETED` 已经广播，背光基本是关的。打开持久 logcat，加开机后常亮。system SHA256 `e65453ecae5632ef32df127dd839ad8aa41c092025c0e789a418c4752a2cc9fd`。只刷了 system，重启一次。adb 是 `offline`，手机后来自己硬复位。细节在「持久日志和 adb」。
- 2026-10-29：持久日志显示图形分配器打不开 `/dev/ion` 和 `/dev/kgsl-3d0`，因为没装 vendor 的 ueventd 规则。adbd 因为 f_fs 没有 AIO 一直掉线。装上 `ueventd.qcom.rc`，adb 改用阻塞读写。system SHA256 `35b42a50154cd6b995ee5bf089c9302dfcbec735746edd7f467fd5be859ee75e`。只刷了 system，重启一次。adb 能进，Android 11 显示锁屏，触控有反应。细节在「持久日志和 adb」。
- 2026-10-29：在 recovery 里删了 `locksettings.db` 和两个 `gatekeeper.*.key`。没有格式化 userdata，`DCIM` 还在。重启后锁屏凭证是 None，Launcher3 到了前台。细节在「去掉锁屏」。
