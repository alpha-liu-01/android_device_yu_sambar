# 阶段 1：板级档案

日期：2026-10-26。阶段 0 的封存已经齐，本文件只记阶段 1 的步骤和当时发生的事。路线图仍是 `docs/g0215d-android-16-roadmap.md`。

完成标准：一份和实机 I2C 地址、compatible 一致的 DTS，以及一份可复现的 blob 清单。这两份已经在 `docs/reference/`。构建骨架在仓库根目录，同步进 Android 树时路径是 `device/gree/g0215d`。整份反编译树有一万六千多行，没有放进骨架。

## 阶段 0 收口

用户确认找不到更多现成文件。阶段 0 点名的分区里，当时只缺 `fsc`。

从仍在 Android 里的手机上执行 `adb shell su 0 dd if=/dev/block/bootdevice/by-name/fsc`。分区是 `sdf3`，sysfs size 为 8 个 512 字节扇区，抽出 4096 字节，内容全是 0。文件在 `/run/media/alpha/YMTC/g0215d/device-backup/fsc.img`，SHA256 `ad7facb2586fc6e966c004d7d1d16b024f5805ff7cb47c7a85dabd8b48892ca7`，已写进同目录的 `SHA256SUMS`。手机上的临时文件已删。

内部存储 `/data/media` 不在 TWRP 的 Data 备份里。没有另外的文件可补。清 data 仍会丢掉照片和下载。构建和还原系统不依赖这部分。

## 步骤 1：反编译正在运行的设备树

`/sys/firmware/fdt` 在这颗内核上不存在，所以不能直接拉一个 FDT blob。选中的树在 `/sys/firmware/devicetree/base`。主机上的 dtc 用的是已有 Lineage 23.2 树里的 `prebuilts/misc/linux-x86/dtc/dtc`，版本 `DTC 1.4.2-Android-build`。

第一次用设备上的 toybox tar，从该目录打包。tar 的 ustar 文件名上限是 100 字节。`find` 列出 13143 个文件，其中 2541 个路径更长，最长 144 字节。这份 tar 不能当完整树用，没有拿去反编译。

接着准备用 cpio。写在 adb 命令里的 `cd /sys/firmware/devicetree/base && find .` 没有停在那个目录，`find` 从手机根目录开始，并把系统文件也打进 `/data/local/tmp/devicetree.cpio`。这个进程已停掉，手机上的临时包已删。拉到电脑上的对应文件是 0 字节，没有把个人文件拷出来。

改成先 `adb push` 一个脚本，再 `adb shell su 0 sh` 执行。脚本自己 `cd` 到 `/sys/firmware/devicetree/base`，用 toybox cpio 的 newc 格式。归档 2.6 MB，解出 13143 个文件，和 `find` 的数量一致。根节点 model 是 `Qualcomm Technologies, Inc. MSM 8996 v3 + PMI8996 MTP`。

`dtc -I fs -O dts` 得到 16918 行。它报了一批 `unit_address_vs_reg` 警告，是高通节点本来的写法，没有中断反编译。`/chosen/bootargs` 里有序列号，写入仓库前改成了 `androidboot.serialno=REDACTED`。成品是 `docs/reference/g0215d-msm8996-mtp.dts`。

别名和实机总线一致：`i2c6` 是 `i2c@757a000`，`i2c7` 是 `i2c@75b5000`，`i2c8` 是 `i2c@75b6000`，`i2c12` 是 `i2c@75ba000`。

| 控制器 | 节点 | compatible |
| --- | --- | --- |
| `i2c@757a000` | `tfa98xx@34`、`at24@51` | `nxp,tfa98xx`、`atmel,24c32` |
| `i2c@75b5000` | `silabs4705@11`、`smb1351-charger@1d`、`tusb320@67` | `silabs,si4705`、`qcom,smb1351-charger`、`my,tusb320` |
| `i2c@75b6000` | `raon_remote_ctrl@50`、`nfc@28`、`haptics-dev2605@5a` | `raon,remote-ctrl`、`nxp,pn547`、`qcom,haptics-drv2605` |
| `i2c@75ba000` | `atmel_mxt_ts@4a` | `atmel,atmel_mxt_ts` |
| `spi@7575000` | `nxp_p61@0` | `nxp,p61` |
| `spi@7579000` | `goodix_touchfinger@0` | `goodix,gf` |

## 步骤 2：面板时序

bootloader 选择的节点是 `qcom,mdss_dsi_nt35597_wqxga_cmd`，在反编译结果的 1695–1765 行。同级还有 video、DSC video、DSC cmd，没有被选中。

节点自己写的宽度是 720（`0x2d0`），高度是 2560（`0xa00`）。这是单路 DSI 的宽度。`config0` 的 `qcom,split-mode` 是 `dualctl-split`，两路拼起来才是 framebuffer 的 1440x2560。bootloader 的 cmdline 选的就是 `config0` 加 `split_dsi`。`config1` 是 `pingpong-split`，不要用。

和两边 donor 内核里的 `arch/arm/boot/dts/qcom/dsi-panel-nt35597-dualmipi-wqxga-cmd.dtsi` 对比：

| 项 | 实机 | 小米 / 一加这份 dtsi |
| --- | --- | --- |
| 名字 | Dual nt35597 cmd mode dsi panel without DSC | 同一类名字 |
| 类型、帧率、bpp | cmd，60，24 | 相同 |
| 宽高、水平和垂直 pulse | 720 x 2560，16，1 | 相同 |
| reset | `<1 10>, <0 10>, <1 10>` | 相同 |
| `panel-timings` | `cd 32 22 00 60 64 26 34 29 03 04 00` | 相同 |
| `panel-timings-8996` | 十个 word，开头 `0x231e0708 0x050304a0` | 这份 cmd dtsi 里没有。小米树里带这个属性的是三星 AMOLED 面板 |
| 背光 | `bl_ctrl_dcs`，最小 1，最大 `0xf8`（248） | 最大写成 4095 |
| 局部刷新 | `qcom,partial-update-enabled` | 这份 dtsi 没写 |

几何和 PHY 时序可以直接用 CAF 那份 cmd 面板。必须改掉的是背光上限 248，并补上 `panel-timings-8996` 和 partial update。Resurrection Remix 不能调亮度，和这颗内核无关：同一颗内核在 TWRP 里能写 `lcd-backlight`。用户态如果按 0–4095 写 DCS 背光，会落在这块屏的 1–248 范围外面。

## 步骤 3：donor 内核里有没有这些驱动

对照的是移动硬盘上的 `android_kernel_xiaomi_msm8996`（`lineage-22.2`）和 `android_kernel_oneplus_msm8996`（`lineage-18.1`）。原厂 ikconfig 的符号名和 donor 的 Kconfig 经常不是同一个字符串。

| 实机需要 | 小米 22.2 | 一加 18.1 |
| --- | --- | --- |
| `qcom,mdss_dsi_nt35597_wqxga_cmd` | 有 CAF dtsi，见上一节 | 有同一份 dtsi |
| `CONFIG_RADIO_SILABS` / `silabs,si4705` | `drivers/media/radio/silabs/`，`msm_defconfig` 打开 | 同样有这份驱动 |
| `CONFIG_SND_SOC_TFA` | 有 `sound/soc/codecs/tfa98xx/`。compatible 是 `tfa,tfa98xx`，另外还有 `tfa,tfa9872` 到 `tfa,tfa9912` 这些型号，不是实机的 `nxp,tfa98xx` | 有头文件，compatible 字符串对不上 |
| `CONFIG_SMB1351_USB_CHARGER` | defconfig 里有 | defconfig 里有 |
| `CONFIG_MSM_QBT1000` | defconfig 里有 | defconfig 里有 |
| `CONFIG_TUSB320` / `my,tusb320` | 没有这个符号。驱动是 `ti_i2c_tusb320.c` | 有 `drivers/misc/type-c-tusb320.c`，compatible 写成 `"tusb320"`，Kconfig 是 `TUSB320_TYPE_C`。不是 `my,tusb320` |
| 触摸 `CONFIG_TOUCHSCREEN_ATMEL_MXTS` | 没有这个符号。最近的是 `TOUCHSCREEN_ATMEL_MAXTOUCH_TS`，`atmel_maxtouch_ts.c` 的 compatible 是 `atmel,maxtouch-ts`，不是 `atmel,atmel_mxt_ts` | 同样只有 `atmel,maxtouch-ts` |
| `CONFIG_FINGERPRINT_GOODIX_GF816M_GF` / `goodix,gf` | 没有。`drivers/input/touchscreen/goodix.c` 是触摸屏 Goodix，不是指纹。指纹 Kconfig 是 `FINGERPRINT_FPC1020_TA` | 没有。指纹是 `FINGERPRINT_FPC1022` |
| `CONFIG_RAON_REMOTE_CTRL_SOC` / `raon,remote-ctrl` | 没有 | 没有 |
| `CONFIG_NFC_PN547` / `nxp,pn547` | 驱动目录里没有 | 驱动目录里没有 |
| `CONFIG_INPUT_DRV2605_HAPTICS` / `qcom,haptics-drv2605` | 没有这个符号。有主线 `drv260x.c` 和 `drv2604.c` | 有 `drv260x.c`，compatible 对不上 |

下一阶段从原厂内核或相近 CAF 树里找源文件的，是 Atmel maXTouch 这份 `ATMEL_MXTS`、Goodix GF816M、Raon、PN547，以及认 `my,tusb320` 和 `nxp,tfa98xx` 的那两处 compatible。面板、Silabs、SMB1351、QBT1000 已经在小米树上。

## 步骤 4：blob 清单

清单以 CM14.1 的 `proprietary-files.txt` 为底，对照 TWRP System 备份 `third_party/2026-10-26--07-28-01_HALO_1.2.1_D1/system.ext4.win` 逐个算 SHA256。二进制没有拷进 git。结果在 `docs/reference/g0215d-halo-blobs.sha256`。

232 个路径在备份里，带大小和 SHA256。CM 列表用减号排除的 `etc/qdcm_calib_data_Dual_nt35597_cmd_mode_dsi_panel_without_DSC.xml` 实际存在，2138594 字节，状态记为 `excluded-but-present`。抽 blob 时要把它加回去，面板名和这份文件一致。

CM 列表里的 `etc/firmware/A4_35_1.0_AA.fw` 和 `etc/firmware/A4_35.raw` 不在备份里。实机触摸固件另加了两行：`A4_2F_4.0_05.fw`（188908 字节）和 `Gree2_4005_V2.06_20170223.raw`（8285 字节）。

## 步骤 5：构建骨架

仓库根目录就是这份设备树。放进 Android 树时对应 `device/gree/g0215d`，所以 makefile 里的路径写成这个名字，而不是 git 仓库名。

新增：

- `AndroidProducts.mk` 注册 `lineage_g0215d.mk`
- `lineage_g0215d.mk` 继承本机 `device.mk` 和 `vendor/lineage/config/common_full_phone.mk`，产品名 `lineage_g0215d`，品牌 Gree，型号 G0215D
- `device.mk` 继承 `device/xiaomi/msm8996-common/msm8996.mk`
- `BoardConfig.mk` 用 `-include` 拉入 `device/xiaomi/msm8996-common/BoardConfigCommon.mk`
- `lineage.dependencies` 只列 `android_device_xiaomi_msm8996-common`。内核和 `hardware/xiaomi` 由 common 自己的依赖再拉
- `board-info.txt`、空的 `Android.bp`

common 是按小米 5 写的。对照实机改了这几项，改在继承之后，所以盖过 common：

| 项 | common | 本机 |
| --- | --- | --- |
| 分辨率 / 密度 | 1080x1920，`xxhdpi` | 1440x2560，`xxxhdpi`（640 dpi） |
| cache | 402653184 | 268435456 |
| userdata | 58846064640 | 59212771328 |
| vendor | 872415232，ext4 | 清空。这台手机现在没有 vendor 分区 |
| 双击唤醒节点 | `/proc/touchpanel/double_tap_enable` | 清空。实机没有这个节点 |

内核源码和 defconfig 留在 common：`kernel/xiaomi/msm8996` 和 `vendor/xiaomi/mi8996_defconfig`。common 的 cmdline 已经是 `cma=32M`，和正在运行的 boot 一致，没有把 CM14.1 里的 `cma=16M` 抄过来。面板的 `split_dsi` 由 bootloader 追加，不写进 cmdline。

没有从 gemini 复制 FPC 指纹、Consumer IR、Atmel 键位和音频 XML。那些是小米 5 的板级文件。也没有把 16918 行实机 DTS 放进骨架。没有写 HALO 的 Android 6 指纹到 `PRODUCT_BUILD_PROP_OVERRIDES`。

这一步不能 `lunch`。common 的 `msm8996.mk` 还会去继承 `vendor/xiaomi/msm8996-common`，而本机还没有自己的 vendor 树。分区覆盖只是让尺寸和实机一致；在划出 vendor 之前，这棵树不能刷进现在的分区表。

## 步骤 6：音频路由

从 TWRP 的 System 备份抽出 HALO 正在用的两份文件，放到 `audio/`，并由 `device.mk` 拷到 `vendor/etc/`：

- `audio/mixer_paths_tasha.xml`，101873 字节
- `audio/audio_platform_info.xml`，4136 字节

它们和 CM14.1 树里的同名文件不是同一份。`speaker-dmic-endfire` 在实机上走 DMIC2/DMIC3，CM 树写的是 AMIC 的 ADC5/ADC6。扬声器加耳机的 backend 在实机上是 `SLIMBUS_0_RX-and-SLIMBUS_6_RX`，CM 树写成 `QUAT_MI2S_RX-and-SLIMBUS_6_RX`，并且多了两条 `quat_mi2s_rx` 扬声器后端。骨架用实机这份。

没有放进骨架的：

- `audio_effects.conf`。HALO 把效果库换成了 `libv4a_fx_ics.so`，这是 MIUI 上的 Viper4Android，不是板级路由
- `audio_policy.conf`。和 CM14.1 字节相同，而且 common 已经用 `audio_policy_configuration.xml`
- `mixer_paths.xml`、sound trigger 两份。sound trigger 和 CM14.1 相同，common 自己有
- `audio_output_policy.conf`。System 备份里没有这个文件

## 步骤 7：键位

从同一份 System 备份抽出两份键位，放到 `keylayout/`，拷到 `vendor/usr/keylayout/`：

- `gpio-keys.kl`，1689 字节。common 已经拷一份小米 5 的同名文件，`device.mk` 先把它从 `PRODUCT_COPY_FILES` 里去掉再放这一份，避免同一个目标路径有两份来源
- `tiny4412-key.kl`，61 字节。common 没有这个文件

实机 `gpio_keys` 只有三颗键：音量加是 Linux code 115，节点 `cam_focus` 标成 `key_home`、code 102，节点 `cam_snapshot` 标成 `key_gree`、code 59。HALO 把 59 映射成 `GREE_KEY`。CM14.1 那份写成 `CAMERA`，common 的小米文件则没有 59 和 68。骨架用 HALO 这份。`GREE_KEY` 不是 AOSP 的键名，后面要补键码，这一行才会生效。

`tiny4412-key.kl` 在实机上是 HOME、MENU、BACK。CM14.1 改成了 BACK 和 APP_SWITCH。设备树里没有叫 tiny4412-key 的节点。Atmel 的 `touch_keyevent` 写出 139、172、158，其中 139 和 158 对得上这份文件。驱动注册的输入设备名还不在现有源码里。

没有放进骨架的：

- `qpnp_pon.kl`。和 common 字节相同，电源和音量减已经由 common 拷贝
- `synaptics_dsx.kl`。和 CM14.1 相同。`gen-vkeys` 的 label 是 `synaptics_dsx`，键码也是 158、139、102、217，但坐标按 1600 宽写，实机面板是 1440x2560，触摸控制器是 Atmel。这是虚拟键残留，不是这台机器的触摸键位
- Generic、qwerty 和一串 Vendor 键位。那些是系统自带的通用文件

## 步骤 8：相机配置

从同一份 System 备份抽出 `camera/msm8996_camera_G0215D.xml`，4997 字节。`device.mk` 把它拷到 `system/etc/camera/msm8996_camera_G0215D.xml`。实机的 `libmmcamera2_sensor_modules.so` 把这个文件名编了进去，打开的目录是 `/system/etc/camera/`，另外也会看 `/data/misc/camera/`。

这份配置只有两个模组：

- 后摄 CameraId 0，Samsung S5K3P3，马达 dw9800，EEPROM sunny_a16s05e，闪光灯 pmic，chromatix `s5k3p3_chromatix`，f/1.8，安装角 90。CSI0，LaneMask `0x1F`，四条数据线加时钟
- 前摄 CameraId 2，OV8858，没有马达，EEPROM sunny_d8v03c，chromatix `ov8858_chromatix`，f/2.4，安装角 270。CSI2，LaneMask `0x07`，两条数据线加时钟

XML 里没有 OIS 节点。System 里有 `libois_lc898122.so`，这份配置没有引用它。

没有放进骨架的：

- `msm8996_camera_G0245D.xml`。那是 IMX258 加 OV8856，另一台机器的配置
- `msm8996_camera.xml`。高通参考列表，模组是 IMX230、OV5645 这一类，不是这台手机
- chromatix XML 和 `libmmcamera_*.so`。CM14.1 把它们算在专有文件里。配置点名的 `s5k3p3_chromatix.xml`、`ov8858_chromatix.xml` 都在备份里，但这一步不把调校和传感器库放进树。备份里另外还有一份 `ov8858_d8v03c_chromatix.xml`，配置写的名字是 `ov8858_chromatix`，没有改

## 步骤 9：灯、指纹、红外

灯没有另做一份 HAL。common 已经打包 `android.hardware.light-service.lineage`。它会打开 `/sys/class/leds/lcd-backlight`、`button-backlight`，以及 `red`、`green`、`blue`，亮度按节点里的 `max_brightness` 缩放。实机设备树里这几个名字都在：按键灯是 PM8994 的 MPP，红绿蓝是三颗状态灯。正在使用的 NT35597 命令模式面板 `qcom,mdss-dsi-bl-max-level` 是 `0xf8`，也就是 248。CM14.1 的 `lights.msm8996` 写的是同一批节点，但不读最大值。两套一起上会抢同一个亮度节点，所以没有把那份 Android 6 模块放进骨架。

指纹是 Goodix GF816M，SPI 节点 `goodix,gf`。`libfphal.so` 打开 `/dev/goodix_fp`。`ueventd.gree.rc` 把这个节点设成 `0660 system system`，装到 `vendor/etc/ueventd.rc`。`init.gree.rc` 建立 `/data/system/fingerprint` 和 `calibration`，这是 `libfpalgorithm.so` 写模板的目录。`vendor.gx_fpd` 指向 `/vendor/bin/gx_fpd`，保持 disabled：这个二进制不在树里，而且它对接的是 Android 6 的 `fingerprint.default.so`，不是现在的指纹服务。common 的 ueventd 里还有 `/dev/fpc1020`，那是一加的指纹，这台机器没有那个节点，没有再加 FPC 的键位或 HIDL。`gx_fpd`、`libfphal.so`、`libfpalgorithm.so`、`fingerprint.default.so` 都没有放进仓库。

红外是 I2C 上的 Raon，`raon,remote-ctrl`，设备节点 `/dev/remote_ctrl_dev`。同一份 ueventd 给它 `0660 system system`。CM14.1 的 `libirda/remoteir.c` 和 `remoteir.h` 放进了 `libirda/`，用 Soong 编成 `remoteir.default`，32 位和 64 位都装到 `vendor/lib*/hw`。源码里打开的就是这个节点。没有应用 `0001-add-remoteir.patch`，也没有加 Consumer IR 权限或 `android.hardware.ir-service.lineage`。那套是小米 5 的消费红外，这台机器的协议走 Raon 自己的读写和 ioctl。HAL 现在没有 Android 16 的上层服务去打开它。

## 步骤 10：Marshmallow vendor 树

`third_party/android_vendor_Gree_G0215D-Marshmallow` 是 2017-08-14 由 `device/Gree/G0215D/setup-makefiles.sh` 生成的专有文件树，731 个文件，约 223 MB。makefile 里的安装路径是 `vendor/Gree/G0215D`。整棵树没有 `.c`、`.h` 或 `.dts`。

和 HALO System 备份对过 SHA256，下面这些文件相同：

- `etc/firmware/A4_2F_4.0_05.fw`，188908 字节，`9ef8974c82b967fe`
- `etc/firmware/Gree2_4005_V2.06_20170223.raw`，8285 字节，`8460144470d0087e`
- `etc/camera/msm8996_camera_G0215D.xml`，4997 字节，`5e5d497ae52aae5b`
- `etc/firmware/tfa98xx.cnt`，`7891a64eedb66675`
- qdcm 的 NT35597 校准 xml，`256971e932617e76`

树里还有 `gx_fpd`、`libfphal.so`、`fingerprint.default.so`、`remoteir.default.so` 和 `vendor/firmware/libpn547_fw.so`。这些是用户态程序和固件。`A4_35_1.0_AA.fw` 和 `A4_35.raw` 这里也没有。

`proprietary/lib/modules/` 里 16 个 `.ko` 的 vermagic 都是 `3.18.20-perf SMP preempt mod_unload modversions aarch64`，和原厂内核的版本字符串一致。里面有 `wil6210.ko` 和 `qca_cld_wlan.ko`。Atmel、Goodix 指纹、Raon、PN547 在原厂 ikconfig 里是编进内核的：`CONFIG_TOUCHSCREEN_ATMEL_MXTS=y`、`CONFIG_FINGERPRINT_GOODIX_GF816M_GF=y`、`CONFIG_RAON_REMOTE_CTRL_SOC=y`、`CONFIG_NFC_PN547_I2C=y`。`CONFIG_NFC_PN547` 没有打开。编进内核的驱动不会出现在这个模块目录里。

## 阶段 1 收口

完成标准的两份文本都在 `docs/reference/`：实机 DTS 的 I2C 地址和 compatible 与运行中的树一致，blob 清单可以从 HALO System 备份复现，这份 vendor 树里的触摸固件、相机配置、TFA 和 qdcm 与清单相同。骨架在仓库根目录。

四份内核驱动的源码不在这份 vendor 树里，小米 `lineage-22.2` 和一加 `lineage-18.1` 里也没有同名符号。阶段 2 要另找原厂内核或相近的 CAF 树。阶段 1 到此结束。
