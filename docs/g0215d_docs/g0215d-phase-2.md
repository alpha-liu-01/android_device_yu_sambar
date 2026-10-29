# 阶段 2：内核启动到显示和 adb

日期：2026-10-26。阶段 1 已收口。本文件只记阶段 2 的步骤和当时发生的事。路线图仍是 `docs/g0215d-android-16-roadmap.md`。

完成标准：自编译内核在不刷写 boot 分区的前提下，能点亮这块倒装屏并完成一次触摸和 adb。`#17` 已达到：连续三次重启无横纹、触摸可用、adb 为 `recovery`、`uname` 含 `4.4.302`，boot 分区未写。

## 步骤 1：bootloader 会选哪一份 DTB

实机根节点是 `qcom,msm-id = <0xf6 0x30001>`、`qcom,board-id = <0x8 0x0>`、`qcom,pmic-id = <0x20009 0x10013 0x0 0x0>`。`0xf6` 就是 246。正在运行的 cmdline 里，bootloader 追加的面板选择是 `qcom,mdss_dsi_nt35597_wqxga_cmd` 的 `config0` 加 `split_dsi`。

小米 `lineage-22.2` 内核里，`arch/arm/boot/dts/qcom/msm8996-v3-pmi8996-mtp.dts` 的三组 ID 与实机一致。`msm8996-v3.dtsi` 写 msm-id，`msm-pmi8996.dtsi` 写 pmic-id，这份 dts 自己写 `board-id = <8 0>`。NT35597 命令模式面板已经编进 `msm8996-mdss-panels.dtsi`，节点名就是 `qcom,mdss_dsi_nt35597_wqxga_cmd`。`config0` 是 `dualctl-split`，`config1` 是 `pingpong-split`，和实机一样。22.2 的面板驱动读的是 `qcom,mdss-dsi-panel-timings-phy-v2`，`msm8996-mdss-panels.dtsi` 已经给这个节点补了和实机 `panel-timings-8996` 相同的字节。

还要对这块屏改两处：背光上限在 CAF dtsi 里是 4095，实机是 248；实机开了 `qcom,partial-update-enabled`，CAF 的 cmd dtsi 没写。小米机型的 `a4-msm8996-v3-pmi8996-mtp.dts` 型号字符串相同，但 `board-id` 是 34，bootloader 不会选它。

`vendor/xiaomi/mi8996_defconfig` 没有打开 `CONFIG_WIL6210`，也没有打开小米的 `CONFIG_MACH_XIAOMI_*`。默认 DTB 列表里包含上面那份 MTP。Atmel、Goodix 指纹、Raon、PN547 的源码仍然不在这棵树里，这一步的 DTS 没有加这四个节点。

镜像参数沿用 common：`Image.gz-dtb`、页大小 4096、`BOARD_KERNEL_BASE` `0x80000000`、tags offset `0x100`、ramdisk offset `0x01000000`。common 的 cmdline 已经是 `cma=32M`。bootloader 还会追加 HMP、`androidboot.bootdevice`、verified boot 和面板选择，这些不写进内核 cmdline。

## 步骤 2：格力 DTB

donor 克隆留在 `lineage-22.2`，没有改它的工作区。用 `git worktree` 在 `/run/media/alpha/YMTC/g0215d/kernel-g0215d` 开了分支 `g0215d`，HEAD 是 `535079d2fa36`。

新增 `arch/arm/boot/dts/qcom/g0215d-msm8996-v3-pmi8996-mtp.dts`。它包含同一套 v3、PMI8996 和 MTP，再覆盖 NT35597 命令模式节点：背光最小 1、最大 248、`bl_ctrl_dcs`、打开 partial update。`arch/arm/boot/dts/qcom/Makefile` 里，默认列表中的 `msm8996-v3-pmi8996-mtp.dtb` 换成了 `g0215d-msm8996-v3-pmi8996-mtp.dtb`，避免 bootloader 在同一组 ID 上碰到两份 DTB。

`make O=out vendor/xiaomi/mi8996_defconfig` 已写好配置。接着编这份 DTB 时停了：

- Lineage 23.2 里的 `aarch64-linux-android-gcc` 是 Python 包装，shebang 为 `/usr/bin/python`，这台机器上没有这个解释器。直接调用旁边的 `real-aarch64-linux-android-gcc` 可以运行，版本是 GCC 4.9.x 20150123。
- 这棵 22.2 内核的 `include/linux/compiler-gcc.h` 拒绝 5.1 以前的 GCC。`scripts/mod/devicetable-offsets.c` 因此没编过，kbuild 没有产出 DTB。
- `clang-3289846` 启动时缺少 `libtinfo.so.5`。

DTB 改用主机 `cpp` 预处理，再用这次 kbuild 已经编出来的 `out/scripts/dtc/dtc` 编译。产物是 `out/g0215d-msm8996-v3-pmi8996-mtp.dtb`，385402 字节。反编译确认：msm-id `0xf6 0x30001`，board-id `0x8 0x0`，pmic-id `0x20009 0x10013 0x0 0x0`，`qcom,mdss_dsi_nt35597_wqxga_cmd` 的背光上限是 `0xf8`，并且带有 `qcom,partial-update-enabled`。`unit_address_vs_reg` 警告是高通节点原有写法。

## 步骤 3：编出 Image.gz-dtb

这棵内核是 4.4.302。`build.config.aarch64` 指定用 Clang 编译，`aarch64-linux-androidkernel-` 只提供汇编器和链接器。主机上没有 aarch64 GCC。Lineage 23.2 里能启动的编译器是 `prebuilts/clang/host/linux-x86/clang-r547379`，版本 Android clang 20.0.0。`clang-3289846` 仍然缺 `libtinfo.so.5`。主机工具用 gcc-13。

第一次编译停在 `arch/arm64/kernel/vdso/vgettimeofday.o`。Clang 20 写出的汇编带引号，GCC 4.9 自带的 binutils 2.27 报 `junk at end of line`。加上 `LLVM_IAS=1` 后改用 Clang 自己的汇编器，链接器仍是 `aarch64-linux-androidkernel-ld`。内核编过，版本字符串是 `Linux version 4.4.302-perf+`。

DTB 列表里有一份编不过：`apq8096-v3-pmi8996-mdm9x55-i2s-mtp.dts` 第 154 行写了 `clk_audio_lpass_mclk2`，`include/dt-bindings/clock/audio-ext-clk.h` 没有这个宏，dtc 报语法错误。这份是 APQ8096 参考板，从 `arch/arm/boot/dts/qcom/Makefile` 的默认列表里去掉。其余 DTB 编过。

kbuild 产物在工作树的 `out/arch/arm64/boot/Image.gz-dtb`，56169878 字节。gzip 后的内核是 12362841 字节，后面拼了 116 份 DTB。格力那份是 kbuild 编的 `out/arch/arm64/boot/dts/qcom/g0215d-msm8996-v3-pmi8996-mtp.dtb`，385402 字节，并且完整包含在 `Image.gz-dtb` 里。反编译结果：model `Gree G0215D MSM8996 v3 + PMI8996`，msm-id `0xf6 0x30001`，board-id `0x8 0x0`，pmic-id `0x20009 0x10013 0x0 0x0`。`qcom,mdss_dsi_nt35597_wqxga_cmd` 的背光上限是 `0xf8`，带 `qcom,partial-update-enabled`。

现有 boot 分区是 64MB。备份镜像里的内核占 39337947 字节，ramdisk 占 7888060 字节，页大小 4096。把内核换成这份 `Image.gz-dtb`、ramdisk 保持不变，页对齐后一共 64065536 字节，分区里大约还剩 2.9MB。

这次使用的命令：

```
PATH=clang-r547379/bin:aarch64-linux-android-4.9/bin:arm-linux-androideabi-4.9/bin:$PATH
make O=out ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu- \
  CROSS_COMPILE=aarch64-linux-androidkernel- \
  CROSS_COMPILE_ARM32=arm-linux-androideabi- \
  HOSTCC=gcc-13 HOSTCXX=g++-13 LLVM_IAS=1 -j56 Image.gz-dtb
```

## 步骤 4：Atmel 触摸驱动在哪

原厂 boot 解出来的 `Image` 里，`__FILE__` 指向：

`/home/diaoll/G0215D_MP/AndroidM_1031/kernel/drivers/input/touchscreen/atmel_stand/atmel_mxt_ts.c`

同目录还有 `io/io.h`、`io/msm/legacy/io.c`、`io/msm/legacy/io.h`。版本字符串是 `Linux version 3.18.20-perf (android@buildserver)`，编译时间 Wed Apr 12 10:54:40 CST 2017。recovery 里那颗 2016-10-07 的内核带着同一套文件，路径是 `/home/diaoll/G0215/AndroidM_1008/kernel/drivers/input/touchscreen/atmel_stand/`。两颗都是 `android@buildserver` 用 GCC 4.9 编的，源码树放在 `diaoll` 的目录下。

实机节点是 `i2c@75ba000/atmel_mxt_ts@4a`，compatible `atmel,atmel_mxt_ts`。ramdisk 的 `init.atmel_ts.sh` 等 2 秒后进入 `/sys/bus/i2c/devices/12-004a`，把 `A4_2F_4.0_05.fw` 写到 `update_fw`，把 `Gree2_4005_V2.06_20170223.raw` 写到 `update_cfg`，再写 `plugin`。原厂内核字符串里有 `update_fw`、`update_cfg`、`plugin`、`atmel,suspend-power-off`、`atmel,common-vdd-supply`、`touch_vdd`。

小米 `lineage-22.2` 和一加 `lineage-18.1` 都没有 `atmel_stand`，也没有 `CONFIG_TOUCHSCREEN_ATMEL_MXTS`。小米树上的 `atmel_mxt_ts.c` 认 `atmel,mxt-ts`，`atmel_maxtouch_ts.c` 认 `atmel,maxtouch-ts`。主线驱动认 `atmel,atmel_mxt_ts`，但没有 `update_cfg` 和 `plugin` 这两个 sysfs，对不上这份 init 脚本。Marshmallow vendor 树只有固件，没有 `.c`。GitHub 上搜 `atmel_stand` 没有结果。

MIUI、LOS13、HALO 和 SuperSU 的 stock boot 用的是 2017-04-12 这颗已经编进 `atmel_stand` 的内核。TWRP 和 2020 年的 CirnoSalt RR 用的是 2016-10-07 那颗，里面同样有 `atmel_stand`。这些包的触摸能用，是因为内核二进制里已经有这份驱动。打包的人没有重新编译它，也不需要拿到 `atmel_stand` 的源码。

这一步没有把驱动放进 `g0215d` 工作树。公开位置里没有这份源码。

## 步骤 5：在其他 2K MSM8996 树上找触摸驱动

优先看乐视 Le Max 2，因为它公开的内核里有一份乐视自己的 Atmel 驱动。夏普 AQUOS Xx3 的原厂内核包也下了，用来确认是不是另一份 `atmel_stand`。中兴 Axon 7、HTC 10、Pixel XL 的板级 defconfig 直接写了 Synaptics，排在后面核对。

乐视 `LineageOS/android_kernel_leeco_msm8996` 的 `lineage-18.1` 有 `drivers/input/touchscreen/atmel_mxt_ts_letv.c`，Kconfig 是 `TOUCHSCREEN_ATMEL_MXT_LETV`，说明文字写的是 mXT640T。compatible 是 `atmel,atmel_mxt_ts`。sysfs 有 `update_fw` 和 `update_cfg`，对象表里有 T15、T81、T93、T115。代码里 `family_id == 0xA4 && variant_id == 0x2F` 会走到 `le_x5` 这条分支。板级节点在 `arch/arm/boot/dts/qcom/leeco/letv-tp-atmel_mxt_ts.dtsi`：`i2c@75ba000`、地址 `0x4a`、中断 GPIO 125、`atmel,reset-gpio` 是 GPIO 89。这和实机的 `interrupts = <0x7d 0x2008>`、`gpios` 里的 `0x7d` 与 `0x59` 是同一组引脚。Le Max 2 自己的 dts 写的 variant 是 `0x02`，配置嵌在 `atmel,config` 里，固件名是 `maxtouch.cfg`。这份驱动没有 `plugin`，也没有 `atmel_stand` 目录，不读实机那种 `touch_keyevent` 子节点。

中兴 `lineageos_axon7_defconfig` 打开的是 `TOUCHSCREEN_SYNAPTICS_DSX_ZTE`。树里的 `atmel_mxt_ts.c` 是 CAF 自带文件，板级配置没有打开它。

HTC 10 的 `pme_defconfig` 打开 `TOUCHSCREEN_SYNAPTICS_DSX_HTC`，`TOUCHSCREEN_ATMEL_MXT` 和 `TOUCHSCREEN_ATMEL_MAXTOUCH_TS` 都关掉了。Pixel XL 的 `marlin_defconfig` 打开 `TOUCHSCREEN_SYNAPTICS_DSX_CORE_HTC_v26`，和 HTC 10 是同一路 Synaptics。

夏普 AQUOS Xx3（506SH / pa32）的屏幕是 1080p，不是 2K。2016-06-13 的 Build S0018 内核包下到了 `/run/media/alpha/YMTC/g0215d/donor-search/aquos-xx3-s0018-kernel.tar.gz`，131MB。`pa32_defconfig` 打开 `CONFIG_TOUCHSCREEN_SHTPS`，驱动在 `drivers/sharp/shtps/sy3000/`，固件控制是 Synaptics S3400。包里没有 `atmel_stand`。

五台里只有乐视这份 `atmel_mxt_ts_letv.c` 和实机的 compatible、I2C、中断脚、复位脚对得上。它还不是 `atmel_stand`。

## 步骤 6：把乐视驱动放进 g0215d 工作树

驱动来自 `LineageOS/android_kernel_leeco_msm8996` 的 `lineage-18.1`。放进工作树的是 `drivers/input/touchscreen/atmel_mxt_ts_letv.c`、`letv_clss.c`，以及 `include/linux/i2c/atmel_mxt_ts_letv.h`、`include/linux/letvs.h`。Kconfig 符号是 `TOUCHSCREEN_ATMEL_MXT_LETV`，`vendor/xiaomi/mi8996_defconfig` 里写成 `=y`。小米原有的 `TOUCHSCREEN_ATMEL_MXT` 和 `TOUCHSCREEN_ATMEL_MAXTOUCH_TS` 仍是关掉的，它们的 compatible 分别是 `atmel,mxt-ts` 和 `atmel,maxtouch-ts`。

为了能在这块板上 probe，改了三处：

- 乐视 probe 要求 cmdline 里有 `sharp` 或 `samsung`，否则返回 `-EPERM`。格力面板是 NT35597，这段检查去掉了。
- `mxt_update_fw_and_cfg` 在没有 `atmel,fw_version` 时直接返回。这样 probe 不会去找 `mXT640T_V16AA.fw`，也不会套用 Le Max 2 嵌在 dts 里的 variant `0x02` 配置。固件和配置留给 `init.atmel_ts.sh`。
- 这棵 4.4 内核的 `kernfs_path` 返回长度，乐视代码把它当成指针。proc 符号链接改成使用缓冲区里的路径。

`plugin` 是后加的写节点，权限 `S_IWUSR`。脚本写 `ac enable 1` 和 `pl enable 20` 时，驱动记下这条命令并返回写入长度。原厂 `atmel_stand` 的 plugin 引擎没有搬过来，这两条命令不会在芯片上执行。`update_fw` 和 `update_cfg` 仍是乐视原来的节点，写入的文件名交给 `request_firmware`。

格力的 `A4_2F_4.0_05.fw` 是 188908 字节。按驱动的帧长算法（前两字节再加 2 字节 CRC）走完是 1207 帧，正好用完，没有剩余。文件里有非十六进制字节，`mxt_check_firmware_format` 会把它当二进制固件。`Gree2_4005_V2.06_20170223.raw` 是 8285 字节，开头是 `OBP_RAW V1`，信息块是 `A4 2F 40 05`，和 `mxt_update_cfg` 认的魔数一致。两个文件都在 vendor 树的 `proprietary/etc/firmware/`，没有打进内核镜像。脚本写的是纯文件名，启动时它们要出现在 `request_firmware` 的搜索路径里。

板级节点加在 `g0215d-msm8996-v3-pmi8996-mtp.dts` 的 `&i2c_12` 上。编出来的 DTB 里，`i2c12` 别名指向 `/soc/i2c@75ba000`，子节点是 `atmel_mxt_ts@4a`：`reg = <0x4a>`，`interrupts = <0x7d 0x2008>`，`atmel,reset-gpio` 是 GPIO 89，`atmel,cap-button-codes` 是 `<139 172 158>`，对应实机 `touch_keyevent` 的 T15。`avdd` 接到 `pm8994_l22`（3.3V），这就是实机 `touch_vdd`。`vdd_io` 接到 `pm8994_l14`（1.8V）。实机那个 `atmel,common-vdd-supply` 的 phandle 指向 `i2c_12_sleep`，不是稳压器，这里没有照搬。同一条总线上原来的 `synaptics@20` 删了，避免它占用 GPIO 125 和 89。

`CONFIG_TOUCHSCREEN_HIDEEP_TP_LETV` 没有打开。驱动里对 hideep 压力的调用在这个配置下是空函数。`letv_clss.c` 编进内核，probe 会注册一个名为 `touchpanel` 的 letv class 设备。格力的 init 脚本不使用它。

`atmel_mxt_ts_letv.o` 里能看到字符串 `atmel,atmel_mxt_ts`、`update_fw`、`update_cfg`、`plugin`。重新编出的 `out/arch/arm64/boot/Image.gz-dtb` 是 56190111 字节，格力 DTB 仍嵌在里面。用现有 ramdisk（7888060 字节）和 4096 页对齐后，boot 镜像是 64086016 字节，64MB 分区里还剩 3022848 字节。

这一步还没有上机。probe 要先和芯片完成 `mxt_initialize`，`12-004a` 下的三个节点才会出现。

## 步骤 7：只换内核的 boot 镜像

备份 `boot.img` 的头是 `ANDROID!`，`dt_size` 为 0，页大小 4096。内核加载地址 `0x80008000`，ramdisk `0x81000000`，tags `0x80000100`，second 大小为 0。ramdisk 是 7888060 字节的 gzip cpio，这一步按原字节放回去，没有重打包。

第一份镜像是 `/run/media/alpha/YMTC/g0215d/boot-test/boot-phase2.img`，64086016 字节，当时的 SHA256 是 `985e7e918bbd7b1467ecb4af0ff9eaee0db2ae5f532beca7250d634af3fa7951`。内核是工作树里的 `Image.gz-dtb`，56190111 字节，gzip 头 `1f8b0800`。页对齐后 64MB 分区还剩 3022848 字节。ramdisk 地址沿用了 `0x81000000`。

`fastboot boot` 这第一份时，传输和 `Booting` 都返回 OKAY。接着 adb 连上的系统是 `Linux version 3.18.20-perf`，编译时间 Wed Apr 12 10:54:40 CST 2017，也就是 boot 分区里的原厂内核。`/proc/uptime` 只有几分钟，说明手机确实重启了，但跑起来的不是 4.4.302。boot 分区没有被写入。`Booting OKAY` 只表示 bootloader 收下了这次下载。

内核加载地址 `0x80008000` 到 ramdisk 地址 `0x81000000` 之间只有 16744448 字节。这份 `Image.gz-dtb` 页对齐后落到 `0x8359f000`，把 `0x81000000` 盖住。从分区启动时，这个 bootloader 会把 ramdisk 挪开；`fastboot boot` 按头里的地址直接摆放，两块重叠，测试内核没有留在内存里，bootloader 又从分区把 3.18 拉起来。

同一路径上的镜像曾换成第二份。ramdisk 地址改成 `0x84000000`，在内核结尾之后，中间空 10883072 字节。SHA256 是 `0c8dcadfc45ead899555d354551f5e7f5dd10c327c725cb9c5c445be8546fc73`。

第二份的现象和第一份一样。`Booting OKAY` 之后，机器还停在 fastboot 画面十几秒，然后自己重启。起来后 `uname` 仍是 `3.18.20-perf`，编译时间 Wed Apr 12 10:54:40 CST 2017，`ro.boot.verifiedbootstate` 是 `orange`。这次开机的 uptime 只有几分钟。ramdisk 挪开之后现象没变，所以不只是 `0x81000000` 被盖住。

`fastboot boot` 走的是内存启动。recovery 分区里的 TWRP 是另一颗 3.18.20，和 boot 分区不是同一份镜像。把新内核打进一份新的 TWRP 再 `fastboot boot`，还是这条内存路径。刷进 recovery 分区会换掉现在这块能解密 data 的 TWRP，这一步不这么做。

前两份 `Image.gz-dtb` 是 56190111 字节，因为 `CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE_NAMES` 为空，116 份 DTB 全拼在后面。`vendor/xiaomi/mi8996_defconfig` 现在写成 `qcom/g0215d-msm8996-v3-pmi8996-mtp`。重新编出的 `Image.gz-dtb` 是 12768505 字节，gzip 后面只剩一份 DTB，385156 字节，model 仍是 `Gree G0215D MSM8996 v3 + PMI8996`。页对齐后内核落到 `0x80c36000`，和 `0x81000000` 之间还空 3973120 字节。

第三份仍写在 `/run/media/alpha/YMTC/g0215d/boot-test/boot-phase2.img`。ramdisk 地址改回 `0x81000000`，字节仍是备份里的那一份。镜像 20664320 字节，SHA256 `b2468762cb312e976218aecd32d02875c518de6bbf5126cfb6d52fed6d498f65`。64MB 分区里还剩 46444544 字节。

对照文件是 `/run/media/alpha/YMTC/g0215d/boot-test/boot-stock-trimmed.img`，47230976 字节，SHA256 `1c4ba650228a52cc1d0a988902724e1c413ad3b3958bd112ff47e02e0ec9e4ce`。它是备份 `boot.img` 的前 47230976 字节，和头里的内核、ramdisk 页对齐范围一致。内核 39337947 字节，ramdisk 7888060 字节，地址仍是 `0x80008000` 和 `0x81000000`。这段之后备份里还有约 1058 字节的 SuperSU 证书，CN 是 `SuperSU`，头里的 `second_size` 和 `dt_size` 都是 0，不计入内核和 ramdisk。`fastboot boot` 没有把这份文件写入 boot 分区。

因此 trimmed 镜像跑起来和从分区启动是同一颗 `3.18.20-perf`。`uname` 不能区分这次内存启动有没有成功。成功的标志是 fastboot 画面马上离开、直接进系统。若仍停在 fastboot 画面十几秒再自己重启，起来的 3.18 还是分区里的原厂镜像。

cmdline 沿用备份里的那一行，末尾加了 `firmware_class.path=/system/etc/firmware`。这棵内核的 `request_firmware` 默认搜 `/lib/firmware`，而 `init.atmel_ts.sh` 写的是纯文件名。`atmel_tp_init` 属于 `class main`，在 `on nonencrypted` 里启动，晚于 `on fs` 的 `mount_all`。实机上这两个文件已经在 `/system/etc/firmware/`：`A4_2F_4.0_05.fw` 188908 字节，`Gree2_4005_V2.06_20170223.raw` 8285 字节。当前系统是 Android 6.0.1。

boot 分区没有写。要试的时候：

```
adb reboot bootloader
fastboot boot /run/media/alpha/YMTC/g0215d/boot-test/boot-phase2.img
```

`fastboot boot` 只在这一次启动用这份镜像。进不去的话，再执行 `fastboot reboot` 会回到分区里原来的 boot。

第三份和 trimmed 原厂镜像都是 `Booting OKAY` 之后在 fastboot 画面停十几秒，然后自己重启，起来仍是分区里的 3.18。trimmed 镜像的内核就是原厂内核，所以这条临时启动路径对能从分区启动的镜像也失败。这个 bootloader 的 `fastboot boot` 不拿来测内核。

下一条路径是刷 recovery，不刷 boot。镜像是 `/run/media/alpha/YMTC/g0215d/boot-test/recovery-phase2.img`，23625728 字节，SHA256 `bfecff4d14f6d1816cdd29edd7a7ccb0fcf2c379eed8706998c76a8f991103f8`。内核是只带格力 DTB 的 `Image.gz-dtb`，12768505 字节，页对齐后落到 `0x80c36000`。ramdisk 是现有 recovery 里的 10849233 字节，地址 `0x81000000`。cmdline 沿用 recovery 头里的那一行，含 `cma=16M`。还没有刷入。刷完要用原来进 TWRP 的按键进 recovery。进不去就刷回备份：

```
fastboot flash recovery /run/media/alpha/YMTC/g0215d/boot-test/recovery-phase2.img
fastboot flash recovery /run/media/alpha/YMTC/g0215d/device-backup/recovery.img
```

`recovery-phase2.img` 第一份已写入 recovery 分区。`Writing 'recovery' OKAY`。fastboot 那行 AVB footer 警告是这台 bootloader 不报分区大小，写操作本身完成了。随后进 recovery：黑屏，红灯亮，当时 USB 上没有这台手机。面板和 adb 都没有出现。这次不算阶段 2 的成功。boot 分区没有写。

后来 adb 再次连上时，跑的是原来的 TWRP：`Linux version 3.18.20-perf`，编译时间 Fri Oct 7 15:28:14 CST 2016，`ro.twrp.version=3.0.2-0`。`/sys/class/udc` 是 `6a00000.dwc3`，`/sys/class/android_usb/android0` 存在，`fb0` 是 `mdssfb_90000`，模式 `1440x2560p-196`。

这颗 4.4 内核打开的是 `CONFIG_USB_CONFIGFS`，没有 `CONFIG_USB_G_ANDROID`。TWRP 3.0.2 的 `init.recovery.usb.rc` 只写 `/sys/class/android_usb/android0`。那条 sysfs 不存在时，主机上看不到 adb。黑屏仍可能是面板没起来，但没有 adb 就读不到 dmesg。

第二份 `recovery-phase2.img` 换了 ramdisk，内核没变。`on fs` 挂上 functionfs 之后启动 `/sbin/phase2-debug.sh`：先把红灯关掉并让绿灯亮灭 6 次，再写 `lcd-backlight`，用 configfs 把 `ffs.adb` 绑到 `6a00000.dwc3` 这种 UDC 上，并拉起 `/sbin/adbd`。dmesg 写到 `/cache/phase2-dmesg.txt`。镜像 23592960 字节，SHA256 `220757486d1d6623d6a27ee36a93a2365b9d65b9d4e2dc46a11eb100821122c8`。

阶段 2 的 recovery 算起来，是这三件同时成立：屏幕上出现 TWRP 界面，adb 状态是 `recovery`，`uname -a` 含 `4.4.302`。绿灯闪、红灯灭，只说明脚本已经在用户态跑了。屏幕仍黑但 adb 是 4.4.302，说明内核和 USB 过了，剩下的是面板。红灯一直亮、绿灯不闪、adb 也不出现，说明没进到这个脚本。

第二份已经刷过并进了 recovery。绿灯按脚本亮灭了 6 次，红灯被脚本关掉。屏幕一直是黑的。从绿灯闪完再等约一分钟，主机 `lsusb` 没有新设备，`adb` 和 `fastboot` 都是空的。脚本已经跑到用户态，USB gadget 没有在主机上枚举出来。

回到原来的 3.18 系统后读了 `/cache/phase2-dmesg.txt`，94791 字节。脚本日志里的 `uname` 是 `4.4.302-perf+`，编译时间 Mon Oct 26 10:46:08 EDT 2026。`mdss_mdp_probe` 写着 bootloader 的画面还亮着，`fb0` 登记成功，1440x2560，`split_mode:2`，左右各 720。`Panel Name = Dual nt35597 cmd mode dsi panel without DSC`，continuous splash 打开。`splash mem child node is not present` 紧跟在 `fb1`（640x480，writeback）后面，主屏那份 DTB 里 `qcom,cont-splash-memory` 还在。DSI PLL 1 在 probe 时报过一次没锁定，时钟仍然注册成功。

USB 失败在脚本日志末尾：`configfs 0`，没有 `ffs ready`，`UDC=6a00000.dwc3`，写 UDC 得到 `No such device`。内核同一时刻是 `configfs-gadget 6a00000.dwc3: failed to start g1: -19`。这份 ramdisk 里的 `adbd` 只走 FunctionFS；`ep0` 要等 `functions/ffs.adb` 建好之后再挂 functionfs 才会出现。init 在 `on fs` 里先挂了 functionfs，脚本后建的 function 对不上这次挂载，`adbd` 找不到 ep，打出 `cannot bind 'tcp:5037': Address already in use`，退回 TCP。脚本没等到 `ep1` 仍写了 UDC。`/cache` 当时已经挂着，脚本再挂一次返回 busy，文件还是写进了 cache 分区。

第三份仍写在 `/run/media/alpha/YMTC/g0215d/boot-test/recovery-phase2.img`，内核没变，还是 12768505 字节那份 `Image.gz-dtb`。ramdisk 里的 `/sbin/phase2-debug.sh` 改了顺序：先建 configfs 的 `ffs.adb`，卸掉再挂 functionfs，停掉已经退回 TCP 的 `adbd`，等 `ep1` 出现才把 function 链进 config 并写 UDC。`ep1` 没出现就不写 UDC。开头仍是绿灯 6 次。UDC 写成功之后再慢闪绿灯 3 次。同时读 `fb0` 的 blank，并写 0 把 framebuffer 解开，背光写成 200。镜像 23592960 字节，SHA256 `5ed8ab1f5a927fbe2ab0418854cb31032fbcc0714e9c9d8e4cc7dcc4aa58de49`。

第三份已经刷过并进了 recovery。adb 状态是 `recovery`，`uname` 是 `4.4.302-perf+`。脚本日志里 `ffs before adbd` 已经有 `ep0`，随后出现 `ep1`，`udc write 0`。主机上看到的是 configfs gadget 的 high-speed config。USB 这一步过了。屏幕仍然全黑。

这次黑屏时，`fb0` 的名字是 `mdssfb_90000`，`modes` 是 `U:1440x2560p-60`，32 bpp，`pan` 停在 `0,2560`。`msm_fb_panel_status` 是 `suspend`，背光节点上还有 162。TWRP 的 `/tmp/recovery.log` 写着 `Using fbdev graphics`，并且编译进 recovery 的是 `TW_SCREEN_BLANK_ON_BOOT := true`。界面加载之后它把背光写成 5，再写成 0。framebuffer 里不是全 0，开头是重复的 `000000c2`。手动 `echo 0 > blank` 之后，panel status 变成 `alive`，`pan` 回到 `0,0`，往 `fb0` 写进去的 `0xff` 也能读回来。同一次 `pan` 在 dmesg 里留下 `mdss_mdp_pipe_init: no 2 type pipes available`。type 2 是 DMA pipe。开机画面的 handoff 把两根 DMA pipe 的 refcount 设成 1，split 屏正好占满，第一帧提交分配不到 pipe，像素留在内存里，面板不刷新。`atmel_mxt_ts 12-004a` 在这次启动里处理过一条 T6 消息，触摸芯片有应答。

`mdss_mdp_pipe_init` 在某种类型的 pipe 全部被 handoff 占住时，先把这些 `is_handed_off` 的 pipe 从 `pipes_used` 上摘下来，refcount 清零，再分配一次。重新编出的 `Image.gz-dtb` 是 12769783 字节，页对齐后仍落到 `0x80c36000`。第四份 recovery 用这份内核，ramdisk 在 USB 绑定成功之后等 `Using fbdev graphics`，打开 `msm_cmd_autorefresh_en`，并把背光从 0 拉回到 180，持续约三分钟。镜像 23597056 字节，SHA256 `c6a94590f487aaff695ca68edfbf9591ab99bf5386b45c2bdcc1bd3c0040a95e`。

第四份已经刷过。`uname` 是 `4.4.302-perf+`，编译时间 Mon Oct 26 11:53:28 EDT 2026。adb 仍是 `recovery`。屏幕还是全黑。`msm_fb_panel_status` 这次是 `alive`，背光是 162，`pan` 是 `0,2560`，`measured_fps` 只有 0.1。`fb0` 两块缓冲的中间都有像素，不是空的。dmesg 里没有 `released handed-off`。每次翻页只有一条 `no 2 type pipes available`：左半屏拿走 DMA pipe 0，右半屏按偏移 2 去找，这颗 8996 的 DMA pipe 只有两根、每根一个 rect，偏移 2 已经越界。handoff 并没有把 pipe 占死。

右半屏的偏移改成 `rects_per_sspp`，8996 上是 1，右半屏用 DMA pipe 1。面板的 `qcom,mdss-dsi-on-command` 换成实机 DTB 里那串。原厂序列在 `29` 之后还有 `53 2c` 和 `55 01`，DCS 背光要等 `0x53` 打开才起作用。中间还有 `3b` 和 page `0x24` 的时序，CAF 那串没有。新的 `Image.gz-dtb` 是 12769741 字节，页对齐后仍是 `0x80c36000`。第五份镜像 23597056 字节，SHA256 `a648a75050ec0c28e656edf115b3d60c1ef8a892e150c25be06aad948f79764f`。

第五份已经刷过并进了 recovery。屏幕点亮了。`uname` 是 `4.4.302-perf+`，`#5`，编译时间 Mon Oct 26 12:04:18 EDT 2026。adb 仍是 `recovery`。dmesg 里没有 `no 2 type pipes available`。`/sys/kernel/debug/mdp/stat` 里 DMA0 和 DMA1 都记了 18 次。两路 DSI 的 stream total 都是 `0x0a0002d0`，也就是 2560 行、720 列，stride 是 `0x871`（720×3 再加 1 字节 DCS）。左右时钟都是 804948480。`partial_update_enabled` 是 0，因为板级覆盖把 MTP 的 `"single_roi"` 换成了没有字符串的属性，4.4 的解析只认 `"single_roi"`。背光是 180。`msm_cmd_autorefresh_en` 在脚本的保持循环结束之后读回来是 0。`measured_fps` 大约 0.7。DSI PLL 1 在 probe 时仍有一次没锁定，时钟还是注册上了。

上下两块区域有在动的细横纹，中间一块没有。可见帧是 1440×2560、stride 5760。状态栏和按钮的像素是实的，中间大块是平的，缓冲里没有横纹。隔 0.4 秒再抓一帧，2560 行全部相同。横纹是送上面板之后才有的。原厂那串命令里，page `0x24` 的 `74/75/7e/7f` 和长写 `3b` 的 wait 字节是 0。命令模式这条路径上，wait 为 0 时 `usleep` 也是 0，4.4 的 DSI DMA 会把这一串紧挨着送出去。这些命令写的是面板上下沿的栅极时序。`11` 的 0x65 和 `29` 的 0x29 有等待，背光命令在它们后面，所以屏能亮。

第六份只加这段等待。短命令和 `3b` 的 wait 改成 `0x10`（16ms），载荷不变，`11` 仍是 `0x65`，`29` 仍是 `0x29`。ramdisk 沿用第五份。`Image.gz-dtb` 是 12769742 字节，页对齐后仍落到 `0x80c36000`，和 ramdisk 之间还空 3973120 字节。镜像仍是 23597056 字节，SHA256 `91baf8f2fd3b52c3795a8f5b0f08b7996663bef5bc338e60c13ec8f73b9e3a15`。内核版本是 `#6`，编译时间 Mon Oct 26 12:20:13 EDT 2026。

第六份已经刷过并进了 recovery。`uname` 是 `#6`，编译时间 Mon Oct 26 12:20:13 EDT 2026。adb 仍是 `recovery`。当时看到过一次主界面没有横纹、只有加载页有，后来没能再复现。16ms 等待没有去掉横纹。

第七份在这串命令最前面加了 DCS `28`（显示关闭），等待 `0x20`（32ms）。`Image.gz-dtb` 是 12769749 字节。镜像 23597056 字节，SHA256 `fbb08550cca92c9a377bff767b909ab433bc4dc8fda5d9a305e22326e40d204a`。内核版本是 `#7`，编译时间 Mon Oct 26 12:28:23 EDT 2026。刷过之后横纹在主界面上也一直在。dmesg 没有新的 DSI 传输错误。原厂序列本身没有开头的 `28`。第八份把 `28` 去掉，回到第六份的命令。

第八份已经刷过，当前就在这次启动上。`uname` 是 `#8`，编译时间 Mon Oct 26 12:35:13 EDT 2026。镜像 23597056 字节，SHA256 `d24a017ceaa511bba7c30c49d63b0364af86625e984872b3887d4c39e643a1f8`。横纹仍在。从上到下大约 0–5% 和 95–100% 没有，5–30% 和 70–95% 有在动的细横纹，中间没有。framebuffer 两页都是干净的 TWRP 主界面，横纹不在缓冲里。

同一轮把面板寄存器读了回来。page `0x24` 的 `74/75/7e/7f/c6` 是 `0c 14 0c 14 07`，`3B` 是 `03 08 08 64 9a`，`53` 是 `2c`，`55` 是 `01`，page `0xe0` 的 `36/3f/08` 是 `79 0c c0`。这些都是原厂载荷，16ms 等待并没有改掉它们，横纹是在这些值已经写进面板的情况下出现的。`0x0A` 是 `0x9c`，显示开着、正常模式。DSI 在链路时钟打开时，`0x44` 是 `0x00013c2c`（每行插入 `2C/3C`），stream 是 `0x08710039` / `0x0a0002d0`（720×2560，stride 2161）。时钟和帧缓冲都对，横纹出在送进 GRAM 之后的扫描上。

`2A` 读回来是 `00 00 05 9f`，列窗口是 0–1439，也就是整屏 1440 列。分屏每边只有 720 列，每边的窗口应该是 0–719（`02 cf`）。`2B` 是 `00 00 09 ff`，行窗口 0–2559，这个是对的。4.4 只有 `partial_update_enabled` 为真时才会在每帧前送 `2A/2B`。板级覆盖写的是没有字符串的 `qcom,partial-update-enabled`，4.4 只认 `"single_roi"`，所以一直是 0，列窗口留在面板默认的 1440。原厂 3.18 把这个空属性当成打开，每帧都会送 `2A/2B`。

这次启动里已经用 debugfs 把 `2A` 写成 `00 00 02 cf`、`2B` 写成 `00 00 09 ff`，并推了一帧。读回是 0–719 和 0–2559。横纹还在，样子没变：对比度不高，很细，界面认得出，线条一直在动。列窗口不是原因。

同一轮又对过一遍原厂载荷。page `0x10` 的 `BA/E5/35/BB`、page `0x20` 的 `6D`、page `0x24` 的 `C8/CF/D0`、page `0xE0` 的 `35/37` 都和写出的值一致。`B0` 写成 `03`，读回一直是 `01`。page `0xE0` 的 `6B`–`6F` 写成 `3D`，读回一直是 `14`。睡眠退出之后用 `0x15` 再写一次，仍然写不进去。这两处面板不接受改写，下一份镜像不动它们。

4.4 在 DSI 版本 104 上会把命令模式的 burst 打开（`0x1b8` bit 16）。没有 idle 时，每一行像素是首尾相接送出去的。上下两段栅极带正好是现在看到横纹的位置。第九份给每行 720 列后面加 64 个 DSI byte clock 的空隙，并关掉 burst。`qcom,mdss-dsi-hor-line-idle = <0 720 64>`。控制器复位之后会把这个空隙再写回去。on-command 没变。ramdisk 没变。

`Image.gz-dtb` 是 12769173 字节，页对齐后仍是 `0x80c36000`，和 ramdisk 之间还空 3973120 字节。镜像 23597056 字节，SHA256 `a2ed3113e88b89c0cadb8eacc158716135b84d9bc1562bf276d8c679c9011141`。内核版本是 `#9`，编译时间 Mon Oct 26 13:11:49 EDT 2026。

第九份已经刷过。横纹不是稳定消失。多次重启里，它只在 TWRP 加载页走到一半时消失，消失之后能一直保持，直到下次熄屏再亮屏。也有整次启动都不消失的，那种情况再进一次 TWRP 才有机会碰上。亮屏之后横纹每次都回来。

一次留在无横纹状态的启动上读了寄存器，没有改 blank、背光或面板命令。`uname` 仍是 `#9`。左侧 pingpong `0x71030` 是 `0x80000001`，自动刷新开着，间隔是 1 帧。右侧 `0x71830` 是 0。这就是 ramdisk 脚本在看到 `Using fbdev graphics` 之后写的那一次 `msm_cmd_autorefresh_en=1`，硬件要等到下一次 commit 才真正置上 bit 31，所以落在加载页已经画出来之后。DSI 两侧 `0x44` 仍是 `0x00013c2c`，stream 仍是 `0x08710039` / `0x0a0002d0`。`0x194` 和 `0x1b8` 在 debugfs 的 0x100 窗口外面，设备上也没有 `/dev/mem`，这次读不到。

自动刷新写不写得进去是碰运气。`TW_SCREEN_BLANK_ON_BOOT` 会把接口停掉。脚本如果赶在接口已经停的时候写，`mdss_mdp_cmd_set_autorefresh` 发现 `intf_stopped` 就返回，bit 31 不会置上，这次启动横纹就一直在。写进去并且后面没有再被清掉，横纹就在加载页中途消失。

下次真正的 blank/unblank 会进 `mdss_mdp_cmd_tearcheck_setup`。它看到 bit 31 就先把自动刷新关掉，注释写的是避免 splash 花屏。脚本的那一次写入不会再执行。亮屏后的帧是没有自动刷新的，横纹就固定回来。第八份用的是同一个脚本，没有行空隙，自动刷新开着横纹也不走。所以无横纹要两件事同时在：第九份的行空隙还留着，而且这次启动的自动刷新没被清掉。

超时后先黑、背光马上又亮，是熄屏把亮度写成 0。脚本开头有一段大约 3 分钟的循环，发现亮度低于 20 就写回 180，并且写 `blank 0`。`blank 0` 就是一次 unblank，会把自动刷新清掉。界面要等电源键再画，画出来的是没有自动刷新的一帧。这次读日志时循环已经打出 `panel hold done`，所以这段循环当时不在跑。

自动刷新开着的时候，BTA 大约每 6 秒超时一次，dmesg 是 `DSI BTA error: 0`，内核把 `panel_dead` 置上并发 `PANEL_ALIVE=0`。TWRP 不处理这个 uevent，所以画面可以停在无横纹。同一次启动里还有 `cannot disable clks while autorefresh is not off`，以及 ctl0 等自动刷新完成超时。这些都是自动刷新还开着的伴生现象。

触摸从屏幕点亮以来一直能用。`#8` 的 dmesg 里 `atmel_mxt_ts 12-004a` 报了 Family 164 Variant 47 Firmware V4.0.05，T100 尺寸 X1439 Y2559，输入设备是 `input1`。

```
fastboot flash recovery /run/media/alpha/YMTC/g0215d/device-backup/recovery.img
```

第十份在每次送帧前，如果自动刷新是关的，就重新请求每帧一次。行空隙和 on-command 没变，ramdisk 没变。

`Image.gz-dtb` 是 12770147 字节，页对齐后仍是 `0x80c36000`，和 ramdisk 之间还空 3973120 字节。镜像 23597056 字节，SHA256 `528efae03455b34715a41b482e64acfedf96be22e46a93ed8b4066dfe34e5d81`。内核版本是 `#10`，编译时间 Mon Oct 26 13:37:28 EDT 2026。

第十份刷过。十多次重启里大约两次没有横纹，熄屏再亮屏之后没有一次能保持。横纹的样子也变了：还是横贯整屏宽度，但高度不固定，也不连成上下两块。

这次有横纹的 `#10` 和之前无横纹的 `#9` 对过同一组寄存器。两边的自动刷新是一样的：左侧 pingpong `0x71030` 都是 `0x80000001`，右侧都是 0。tear check、`0x44`、stream `720×2560` 也一样。自动刷新开着并不能区分这两种画面。

有横纹这一次，左侧传输停住了。连续几次读，`0x7102c` 的行计数都是 1595，DSI0 的 `0x08` 一直是 `0x17`（命令 DMA 忙），`0xc0` 超时状态是 1，lane `0xa8` 是 `0x1f00`。右侧已经停完：DSI1 的 `0x08` 是 0，FIFO `0x0c` 是 `0x11111000`（空），lane `0xa8` 是 `0x1f1f`（各 lane 都在 stop），行计数停在 2560。无横纹那次两侧 `0x08` 都是 `0x05`，`0xc0` 都是 0，lane 都是 `0x1f00`。

dmesg 里等自动刷新完成的超时给出的行号是 494、1198、696、339、2110、1595。这些行散在一帧里面，对得上高度不固定、又不连成一块。无横纹的 `#9` 也有这种超时日志，所以单是超时日志还不够。两边的差别是这次左侧命令引擎停在某一行上，右侧链路已经空闲。

绿灯 6 次再慢闪 3 次只说明脚本和 USB 起来了。阶段 2 的 recovery 仍要三件同时成立：屏幕上出现没有横纹的 TWRP 界面，adb 状态是 `recovery`，`uname -a` 含 `4.4.302`。无横纹还要在熄屏再亮屏之后保持。boot 分区不动。

第十一份针对这次对比。读指针的高度从默认 `0xfff0` 改成一帧的 2576（`2560+7+8+1`）。`0xfff0` 要大约 25 帧才绕回来，自动刷新完成中断等不到，下一次送帧就叠在还没写完的那一行上。分屏的右侧 pingpong 以前不会被写上自动刷新，所以右侧链路先停、左侧停在半帧。现在两侧一起打开，关掉的时候也一起清掉。行空隙和 on-command 没变，ramdisk 没变。

`Image.gz-dtb` 是 12771671 字节，页对齐后是 `0x80c37000`，和 ramdisk 之间还空 3969024 字节。镜像 23601152 字节，SHA256 `98504e7ce309fe9cbd58b03d9f2430e958b77ff1681984c4649516b019bc2257`。内核版本是 `#11`，编译时间 Mon Oct 26 14:00:40 EDT 2026。boot 分区不动。

第十一份已经刷过。这次启动停在无横纹上。`uname` 是 `#11`。大约 136 秒时读了寄存器，没有改 blank、背光或面板命令。两侧 pingpong 的 `0x71030` 和 `0x71830` 都是 `0x80000001`，`0x71008` 和 `0x71808` 都是 `0xa10`（2576）。隔一次再读，左右行计数都变了，并且绕回过，这一帧两侧都扫完了。

同一时刻 DSI0 的 `0x08` 是 `0x17`：bit1 是 `CMD_MODE_DMA_BUSY`，bit4 是 BTA 触发之后要清掉的那位。`0xc0` 超时状态是 1。DSI1 的 `0x08` 是 0，`0xc0` 是 0，lane `0xa8` 是 `0x1f1f`。dmesg 从大约 11 秒起每 6 秒一条 `DSI BTA error: 0`，接着 `PANEL_ALIVE=0`。中间还有 ctl0 等自动刷新完成超时，行号是 528、341、2109、625、385，ctl1 的 `wait4pingpong` 超时，以及命令 `0x51` 的 DMA 失败。当时画面是干净的。`0xc0` 写 1 之后会留着，单看这个位不能说明此刻还停着。有横纹的时候，左侧行计数会停在半帧不再走。

从 fastboot reboot 进 recovery，无横纹的次数多很多。从 recovery 里直接重启，次数少很多。两条路径用的是同一份内核。差别在 bootloader 交出来的面板。

dmesg 里 continuous splash 是 enabled。复位函数看到这个标志就跳过 GPIO 脉冲。off 命令的 link state 是 `dsi_hs_mode`，splash 开始时先送 `28`/`10`，结束时只做 DSI sw reset，不送 `11`/`29`。fastboot 里 LK 刚刚做过完整初始化，跳过复位通常还能接上。从 recovery 热重启时，上一轮可能停在半帧，供电没有掉，splash 又把复位跳过，左右栅极的相位就留在上一次的状态里。

BTA 是另一条。命令模式正在扫描时把总线要回去，驱动注释写着这之后 FIFO 清不掉。`0x51` 的 DMA 失败跟在 BTA 超时后面。

第十二份把 continuous splash 关掉，每次启动都走 GPIO 复位和 on-command。这块面板的 `qcom,esd-check-enabled` 和 `bta_check` 删了，状态检查不再跑。行空隙、两侧自动刷新、读指针高度、on-command、ramdisk 都没变。

`Image.gz-dtb` 是 12769542 字节，页对齐后是 `0x80c36000`，和 ramdisk 之间还空 3973120 字节。镜像 23597056 字节，SHA256 `c4d3c923ea732efd091d359681ffcde483ea5ea794665ac791a244b9a2a93fd7`。内核版本是 `#12`，编译时间 Mon Oct 26 14:19:45 EDT 2026。boot 分区不动。

第十二份已经刷过。屏幕全程不亮。`uname` 是 `#12`，uptime 约 52 秒。`msm_fb_panel_status` 是 `suspend`，背光节点上是 162，`msm_cmd_autorefresh_en` 是 0。dmesg 里两路都写了 `Continuous splash disabled`，没有 `DSI BTA error`。从 4 秒起每一帧都是 `fb0: commit while splash handoff pending`，提交直接返回，面板初始化没有开始。

bootloader 把显示接口留在开的状态。MDP probe 读到 `DISP_INTF_SEL` 之后把 `handoff_pending` 置上，并握住一份 footswitch。这个标志和面板上的 continuous splash 是分开的。splash 关掉之后，`mdss_mdp_overlay_start` 走到 `handoff_pending` 就返回 `-EPERM`，清掉这个标志的 `splash_cleanup` 排在这次返回之后，所以永远走不到。

第十三份在这个分支上，面板已经声明不要 splash 时，先放下这份 footswitch，再继续完整的面板初始化。splash 仍由面板节点关掉，BTA 仍关掉。行空隙、两侧自动刷新、读指针高度、on-command、ramdisk 没变。

`Image.gz-dtb` 是 12769550 字节，页对齐后仍是 `0x80c36000`，和 ramdisk 之间还空 3973120 字节。镜像 23597056 字节，SHA256 `c5f19db519645281db7ef75d884d29f49a15af4091c76c4e1a158106a1ee5457`。内核版本是 `#13`，编译时间 Mon Oct 26 14:46:29 EDT 2026。boot 分区不动。

```
fastboot flash recovery /run/media/alpha/YMTC/g0215d/boot-test/recovery-phase2.img
fastboot flash recovery /run/media/alpha/YMTC/g0215d/device-backup/recovery.img
```

刷完用原来进 TWRP 的按键进 recovery。`uname` 应是 `#13`。dmesg 应有 `release splash handoff for full panel init`。看屏幕是否点亮，再看有没有横纹。分别从 fastboot reboot 和从 recovery 里重启各看几次，再熄屏后按电源键点亮。

第十三份已经刷过。这一次屏幕有横纹，触摸是好的。从这一份开始，画面干净的时候触摸是坏的，有横纹的时候触摸是好的。`uname` 是 `#13`。dmesg 里有一次 `release splash handoff for full panel init`，没有 `commit while splash handoff pending`，也没有 `DSI BTA error`。面板后来是 `alive`，自动刷新是 1，背光是 162。

触摸在 1.59 秒完成 probe，T6 依次是 `0x80`、`0x10`、`0x0`。4.037 秒放下 splash footswitch 之后，5.370 秒和 5.861 秒又各来了一组同样的 T6。日志里没有 `Resetting chip`，这两组不是 `mxt_soft_reset()`。Family 164 Variant 47 走 `is_support_ups`，framebuffer 熄屏只写 T7 深睡眠，不会切稳压器。ESD 线程在 probe 结束时排上，周期 4 秒。它看到 T6 RESET 之后会把 `avdd` 和 `vdd_io` 都关掉再打开。`vdd_io` 是 `pm8994_l14`，两路 DSI 的 `vddio-supply` 也是这一路。面板供电项里 `vddio` 的 disable-load 是 80。完整初始化把这一路的负载请求打到 80µA，LDO 进 LPM，触摸数字部分复位，同时 DSI 命令 DMA 停在忙。

停住的命令是 `0x34` 和 `0x28`。`0x34` 是 blank 里的 tear off，`0x28` 是 off-command 的 display off。off-command 的 link state 当时是 `dsi_hs_mode`，自动刷新还占着命令引擎，DMA 按 200ms 超时。同一段日志里这两条各失败两次，随后 `mdss_dsi_controller_cfg: DSI status=7`。`0x7` 含 `CMD_MODE_DMA_BUSY`。命令没送完，画面留在横纹上；触摸芯片刚做完 CAL，对得上这个停住的扫描，所以触摸是好的。命令顺利送完的时候，画面是内核 on-command 之后的扫描，probe 时对着 bootloader 画面做的校准对不上，触摸没有上报。recovery 没有挂 `/system`，`Gree2_4005_V2.06_20170223.raw` 这次没有写进去。`config_csum` 是 `53a963`，这是复位之后芯片里的配置。

第十四份改三处。off-command 改成 `dsi_lp_mode`，`0x34`/`0x28` 改到接口停掉之后再送。`dsi_panel_pwr_supply` 里 `vddio` 的 disable-load 改成 62000，和 enable-load 一样，`pm8994_l14` 在熄屏时保持正常功率模式。触摸这边，`mxt_start` 在 T7 唤醒之后补一次 T6 CALIBRATE；ESD 只拉 GPIO 89 的复位脚，不再关 `avdd` 和 `vdd_io`。行空隙、两侧自动刷新、读指针高度、on-command、splash 关闭、BTA 关闭、ramdisk 都没变。

`Image.gz-dtb` 是 12769022 字节，页对齐后是 `0x80c36000`，和 ramdisk 之间还空 3973120 字节。镜像 23597056 字节，SHA256 `054712e0001a7d8f2dfbd496fe21d7b7cab42a0487cbe8c90649b8ed52b0b46c`。内核版本是 `#14`，编译时间 Mon Oct 26 15:05:38 EDT 2026。boot 分区不动。

```
fastboot flash recovery /run/media/alpha/YMTC/g0215d/boot-test/recovery-phase2.img
fastboot flash recovery /run/media/alpha/YMTC/g0215d/device-backup/recovery.img
```

刷完用原来进 TWRP 的按键进 recovery。`uname` 应是 `#14`。看画面是否干净，再看触摸。分别从 fastboot reboot 和从 recovery 里重启各看几次，再熄屏后按电源键点亮，确认横纹和触摸是否还绑在一起。dmesg 里若出现 `esd gpio reset`，说明 ESD 仍在拉复位脚。

第十四份已经刷过。这一次画面是干净的，同一份内核并不是每次都干净。`uname` 是 `#14`，uptime 约 157 秒时面板是 `alive`，自动刷新是 1，背光是 162，`config_csum` 仍是 `53a963`。读寄存器时没有改 blank，也没有送面板命令。两侧 pingpong `0x71030` 和 `0x71830` 都是 `0x80000001`，`0x71008` 和 `0x71808` 都是 `0xa10`。隔 0.3 秒再读，左侧行计数从 `0x6b` 走到 `0x306`，右侧从 `0x4e9` 走到 `0x780`。两路 DSI 的 `0x08` 都是 `0x05`，`0xc0` 是 0。

和第十三份有横纹的那次比，初始化窗口不一样。第十三份在 5.370 秒和 5.861 秒各有一组 T6 `0x80` 复位，5.820 秒起 `0x34` 和 `0x28` 的 DMA 各失败两次，6.437 秒 `DSI status=7`。第十四份这一次从 probe 之后没有 T6 `0x80`，没有 `esd gpio reset`，没有 `cmd_dma_tx` 失败，也没有 `DSI status=7`。4.032 秒放下 footswitch 之后，一直到 8 秒，显示路径没有再打错误。画面干净是因为这次 tear-off 和 display-off 没有把命令引擎停在忙状态，两侧都扫完了。

绿灯闪的那几秒里，触摸有额外的 T6 `0x10`。`phase2debug` 在 3.695 秒启动，先以 1 秒亮、1 秒灭闪 6 次，大约到 15.7 秒。这段里 4.875、7.295、9.097、9.529 秒各有一次校准，间隔不均匀。15.832 秒的下一次对准脚本第一次写 `blank 0`（6 次闪完刚好约 12 秒）。24 秒之后变成每 2 秒一次 `0x10` 然后 `0x0`，和脚本后半段 `sleep 2` 再写 `blank 0` 的循环一致。第十四份在 `mxt_start` 里加了 T6 CALIBRATE，所以每次 unblank 都会校准。这些校准走的是触摸 I2C，不写 DSI 命令。第十三份的横纹出在 5.8 到 6.4 秒的 DMA 失败上，那次日志里没有这些额外的 `0x10`。手指可以让芯片自己报一次校准，但这次干净画面的差别是那组 DMA 失败没有发生。

第十四份干净的那一次，只说明 tear-off 和 display-off 没有把命令引擎停在忙状态。`0x34` 和 `0x35` 当时仍按高速命令送，标志只有 `CMD_REQ_COMMIT`。自动刷新占着命令引擎时，这一条会超时，超时路径不复位控制器。`mdss_dsi_controller_cfg` 只在 `VIDEO_MODE_ENGINE_BUSY`（`0x08` 的 bit3）上做 sw reset。第十三份看到的 `DSI status=7` 含 `CMD_MODE_DMA_BUSY`（bit1），不含 bit3，所以引擎留在忙，下一帧从半行接上，横纹就固定下来。同一份内核有时赶在引擎空闲时送完，画面就是干净的。

送帧时还有第二处不对称。自动刷新已经打开时，`pre_programming` 只关掉主 pingpong 的 TE 监听，分屏的右侧 pingpong 继续扫。双栅面板左右各管一半行，一侧多走一帧，横纹就横贯整屏。高度落在哪一行，取决于这一次提交赶上扫描的位置，所以每次不一样。

第十五份改这三处。`0x35` 和 `0x34` 加上 `CMD_REQ_LP_MODE`，不再占用自动刷新那条高速 DMA。命令 DMA 在 `controller_cfg` 里等不完时，和视频引擎忙一样做 sw reset，再把 burst 和行空隙写回去。自动刷新已经打开时，左右两个 pingpong 一起关掉 TE 监听，等这一帧的 flush 完成再一起打开。第十四份的 LP off-command、vddio disable-load、触摸校准和只拉 GPIO 的 ESD 都留着。行空隙、两侧自动刷新、读指针高度、on-command、splash 关闭、BTA 关闭、ramdisk 没变。

`Image.gz-dtb` 是 12770972 字节，页对齐后是 `0x80c36000`，和 ramdisk 之间还空 3973120 字节。镜像 23597056 字节，SHA256 `cf231efa9f4fa3cc426088321cba2b5dc1f7845f5e58bb1afcbc2be46c717234`。内核版本是 `#15`，编译时间 Mon Oct 26 15:26:59 EDT 2026。boot 分区不动。

```
fastboot flash recovery /run/media/alpha/YMTC/g0215d/boot-test/recovery-phase2.img
fastboot flash recovery /run/media/alpha/YMTC/g0215d/device-backup/recovery.img
```

第十五份已经刷过。这一次画面有横纹。`uname` 是 `#15`，uptime 约 100 秒。读寄存器时没有改 blank，也没有送面板命令。面板是 `alive`，自动刷新是 1，背光是 162，`config_csum` 仍是 `53a963`。

这次和以前卡住的那几次不是同一种横纹。两侧 pingpong 的 `0x71030` 和 `0x71830` 都是 `0x80000001`，高度都是 `0xa10`，TE 监听都开着（`0x71004` 和 `0x71804` 都是 `0x0018007c`）。两路 DSI 的 `0x08` 都是 `0x05`，`0xc0` 是 0，lane `0xa8` 是 `0x1f00`，stream 都是 `0x08710039` / `0x0a0002d0`。dmesg 里没有 `cmd_dma_tx` 失败，没有 `DSI status=7`，也没有 `resetting cmd dma`。左右行计数都在走。命令引擎没有停在半行上，画面仍然有横纹。

4.016 秒放下 splash footswitch。5.356 秒触摸报了一次 T6 `0x80`，5.600 秒 ESD 看到 `reset_sum:1` 之后拉了 GPIO 89。这组和显示 DMA 无关，显示路径从 4 秒到 7 秒没有错误。

横纹留在面板的双栅相位上。on-command 由左控制器先整表送完，包括 `0x11` 后面的 101ms，右控制器再送一遍。右边出睡眠时左边已经锁在另一行。自动刷新接着各自写两个 pingpong 的 `PP_AUTOREFRESH_CONFIG`，不走主 ctl 的 `CTL_START`。分屏硬件只在 `CTL_START` 上把两路接口一起触发。所以两边扫描都是健康的，栅极相位却每次不一样。

第十六份把 `qcom,mdss-dsi-cmd-autorefresh` 拿掉，送帧回到 `CTL_START`。面板加上 `qcom,cmd-sync-wait-broadcast`，同一条 DCS 由右控制器触发，左右端口一起收到，包括 `0x3B`、`0x11` 和 `0x29`。ramdisk 里的 `phase2-debug.sh` 不再写 `msm_cmd_autorefresh_en`，避免脚本把自动刷新重新打开。行空隙、读指针高度、LP off-command、vddio disable-load、splash 关闭、BTA 关闭、触摸校准和只拉 GPIO 的 ESD 都留着。

`Image.gz-dtb` 是 12771012 字节，页对齐后是 `0x80c36000`，和 ramdisk 之间还空 3973120 字节。ramdisk 10815243 字节。镜像 23592960 字节，SHA256 `c23bc89dca35e13eb3bdfc1e957f46a54ca441de7f31bfcb1e35492141607b67`。内核版本是 `#16`，编译时间 Mon Oct 26 15:36:12 EDT 2026。boot 分区不动。

```
fastboot flash recovery /run/media/alpha/YMTC/g0215d/boot-test/recovery-phase2.img
fastboot flash recovery /run/media/alpha/YMTC/g0215d/device-backup/recovery.img
```

第十六份已经刷过。这一次画面没有横纹，触摸没有反应。`uname` 是 `#16`，uptime 约 90 秒。读寄存器时没有改 blank，也没有送面板命令。面板是 `alive`，自动刷新是 0，背光是 162，`config_csum` 仍是 `53a963`。DSI0 是 `cmd_sync_wait_enable=1 trigger=0`，DSI1 是 `enable=1 trigger=1`。

两侧 pingpong 的行计数都停在 `0xa00`（2560），自动刷新寄存器是 0。两路 DSI 的 `0x08` 是 0，FIFO `0x0c` 是 `0x11111000`。这一帧已经送完，命令模式把画面留在面板上，没有停在半行。

触摸芯片还活着。`atmel_mxt_ts` 的中断已经到 1123 次，输入设备还在。probe 时 T6 是 `0x80`、`0x10`、`0x0`，配置被接受。4.020 秒放下 footswitch 之后，5.080 秒 `0x34` 的 DMA 失败，5.280 秒 `0x28` 失败，5.296 秒 `DSI status=3` 并做了 sw reset。5.340 秒 `mxt_config_ctrl_clear` 读 T100 时 I2C 返回 -107，函数没有就此返回，接着把读失败后的值写回 T100。5.352 秒 T6 `0x80`，5.353 秒 `0x10`。从 6.204 秒起每约 195ms 一条 T6 `0x8`，一直到日志结束，没有再出现 `0x0`。`0x8` 是 `MXT_T6_STATUS_CFGERR`。配置错误期间芯片不上报触摸。

第十七份修触摸，并让关屏命令不再占着命令引擎空等。`mxt_config_ctrl_set` 和 `mxt_config_ctrl_clear` 在 I2C 读失败时直接返回，不再把未读到的值写进 T100。T6 出现 `CFGERR` 时，最多做两次 GPIO 复位，把 NVM 里的配置重新装上来；T6 回到 `0x0` 之后这次计数清零。关屏前如果 `CMD_MODE_DMA_BUSY` 还在，先 sw reset，再写回 burst 和行空隙，然后才送 `0x34` 和 `0x28`。广播、`CTL_START`、自动刷新关闭、ramdisk 都沿用第十六份。

`Image.gz-dtb` 是 12769992 字节，页对齐后是 `0x80c36000`，和 ramdisk 之间还空 3973120 字节。ramdisk 10815243 字节。镜像 23592960 字节，SHA256 `812587ce00c675126f07ec0ef08ba43c5749202e9f8ebe043a8f505f206a0ad2`。内核版本是 `#17`，编译时间 Mon Oct 26 15:43:24 EDT 2026。boot 分区不动。

```
fastboot flash recovery /run/media/alpha/YMTC/g0215d/boot-test/recovery-phase2.img
fastboot flash recovery /run/media/alpha/YMTC/g0215d/device-backup/recovery.img
```

刷完用原来进 TWRP 的按键进 recovery。`uname` 应是 `#17`。分别从 fastboot reboot 和从 recovery 里重启各看几次，再熄屏后按电源键点亮。画面应保持没有横纹，触摸应能跟上手指。dmesg 里 T6 在 probe 之后应回到 `0x0`。若出现 `idle before panel cmd`，说明关屏前清过一次命令 DMA。若出现 `esd gpio reset` 且后面跟着 T6 `0x0`，说明 CFGERR 被 GPIO 复位拉回来了。

第十七份已经刷过。连续三次重启都是没有横纹，而且触摸能用。这一次留在设备上的是第三次。`uname` 是 `#17`，uptime 约 297 秒。面板是 `alive`，自动刷新是 0，背光是 162，`config_csum` 是 `53a963`。读寄存器时没有改 blank，也没有送面板命令。

probe 时 T6 是 `0x80`、`0x10`、`0x0`。5.080 秒和 6.550 秒各有一次 `0x34` 然后 `0x28` 的 DMA 失败，接着 `DSI status=3` 并做了 sw reset。5.341 秒 `mxt_config_ctrl_clear` 读 T100 失败，日志是 `i2c read failed`，没有再写 T100。5.360 秒 T6 `0x80`、`0x10`，6.230 秒回到 `0x0`。8.189 秒又有一次 `0x80`、`0x10`，8.230 秒回到 `0x0`。整段日志里没有 T6 `0x8`。配置错误没有留住，触摸继续上报。

关屏前的 `idle before panel cmd` 这次没有出现，`0x34`/`0x28` 的超时日志还在。画面和触摸没有被这两次超时带走。boot 分区没有写。

## 收口

阶段 2 停在这里。完成标准是自编译内核、不写 boot 分区、点亮倒装屏、触摸和 adb 各通一次。`#17` 连续三次重启都满足：1440×2560 的 TWRP 没有横纹，触摸能用，adb 是 `recovery`，`uname` 含 `4.4.302`。boot 分区仍是原厂 3.18。

下面四条留在日志里，不再为它们编下一份 recovery：

1. 电源键熄屏再亮屏没有单独按过。启动里 TWRP 的 blank 已经跑过，`0x34`/`0x28` 超时之后画面仍干净，T6 回到 `0x0`。recovery 脚本还在每 2 秒写 `blank 0` 并把背光托住，这份环境看不出用户态自己的熄屏。
2. `0x34`/`0x28` 的 DMA 超时日志还在。三次启动都没有因此出横纹，也没有停在 CFGERR。
3. 触摸用的是芯片里的 NVM 配置 `53a963`。原厂 `Gree2_4005_V2.06_20170223.raw` 在 `/system/etc/firmware/`，要等用户态挂上 `/system` 再写。`atmel_stand` 的 plugin 引擎没有搬进这棵树。
4. 系统 boot 还没换成这颗内核。阶段 2 要求不刷 boot。下一阶段才把它打进要启动的系统。
