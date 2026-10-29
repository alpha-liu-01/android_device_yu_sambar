# 阶段 2：18.1 做到能日常使用

日期：2026-10-29。路线图是 `docs/sambar-roadmap.md`。阶段 1 已完成，记录在 `docs/sambar-phase-1.md`。本文记阶段 2 的顺序和约束。实现笔记和事件先空着，做的时候再补。

完成标准：验收顺序 1 到 14 都有实机记录。第 1 项显示、第 3 项触控和第 10 项振动已经通过。SELinux 保持 permissive，每次开机的 denial 存下来。短信、第二张卡、VoLTE、通话回声消除、蓝牙耳机通话、加密、可刷的安装包、新 TWRP 都不挡住这 14 项。前一项没有记录，先不跳到下一项。

当前 system SHA256 `977197292482f6e18bd0647307bb3e42e30848d60fb3a20880433d9aef5c20b0`。boot 仍是内核 `#27`。recovery 是内核 `#16`，能挂上 userdata 的 f2fs。

阶段 1 留下、还没做的：USB 被 init 钉成只有 adb。没有 Gatekeeper。manifest 里的 `radio@1.1` 没有进程注册。

## 本阶段禁止

- 不刷 aboot、tz、rpm、hyp、modem、bluetooth、persist、persistbak、modemst、fsg、config
- 不执行 `oem unlock` 或 `flashing unlock`
- 不刷 `third_party/` 里任何 TWRP，包括标成 BROKEN 的那份
- 不用一加 2 的 system、vendor 或固件镜像。一加 2 只提供 SoC 级的 HAL 结构
- 不把 `lineage-23.2` 当成这一阶段的用户态
- 不把 cm-13.0 分支重置或删掉
- userdata 只在下面「开始前先清 userdata」这一步格式化。失败回退时不顺手再清一次
- fstab 不写 `fileencryption`，也不写 `forceencrypt`

## 开始前先清 userdata

用户确认这块盘上没有要留的文件。CM13 的应用数据在 Android 11 上会闪退，留着只会干扰后面的验收。`/data/adb` 已有 `device-backup/data-adb.tar`（Magisk 27）。清掉之后没有那份 root。18.1 是 userdebug，root 走开发者选项里的 Rooted debugging。

只格式化 `mmcblk0p39`。用现在这份能挂上 f2fs 的 recovery 在分区上做 `mkfs.f2fs`。不用 `fastboot -w`：这颗 LK 的 format 不保证还是 f2fs，fstab 写的是 f2fs。`fstab.qcom` 的 userdata 只有 `formattable`，没有 `forceencrypt`，也没有 `fileencryption`。新盘不会进 CryptKeeper。格力那次会，是因为 userdata 带加密 footer。

清完第一次开机走设置向导。Gatekeeper 装上之前不要设锁屏密码。阶段 1 的图案就是旧 Gatekeeper 的句柄，新系统校验不过。

## 已经通过

这两项是用户在阶段 2 开始前确认的，不重做。清盘或换 GPU 之后如果丢了，再回到对应项。

- 触控。Atmel `atmel_mxt_ts_T100_touchscreen` 能用。固件仍是 `A4_15_2.2_AA.fw`。芯片停在引导模式时，按格力那次的做法把这份固件写回去，不换别的型号的 raw。
- 振动。马达是好的。阶段 1 为了让 `system_server` 过阶段 480 装的 `vibrator.default` 留着。

## 验收顺序

1. 显示能看。已通过。Adreno 430，OpenGL ES 3.1，桌面壁纸没有横条。亮度条和电源键都能改背光。细节在「实现笔记」。
2. 系统导航。硬件加速通过之后先做这项，再测后面的设置和返回。这台手机没有实体导航键。`keylayout/gpio-keys.kl` 只有 `VOLUME_UP`，`keylayout/qpnp_pon.kl` 只有 `POWER` 和 `VOLUME_DOWN`。overlay 里 `config_showNavigationBar` 已是 true。三键导航栏和全面屏手势都要能用，各自要能返回、回桌面、打开最近任务。
3. 触控。已通过，见上面。
4. USB。文件传输两个方向都能拷文件。充电、MTP、PTP 能切换。现在 `init.sambar.rc` 把 `sys.usb.config` 钉成 `adb`，这只是阶段 1 的调试口。这颗内核是传统 `android_usb`，不是 ConfigFS。adb 继续用阻塞读写（`ro.adb.nonblocking_ffs=0`，`sys.usb.ffs.aio_compat=true`）。插了 U 盘时按 fstab 的 `usbdisk` 挂上。阶段 0 没有插过 U 盘，挂不上不挡这一项。
5. Wi-Fi。`wlan.ko` 加载，固件来自这台机器，能扫描、连接、拿到地址，`ping` 通。supplicant 用 HIDL。内核继续 `CONFIG_QCA_CLD_WLAN=m`。
6. 音频。喇叭、听筒、有线耳机三个出口都有声音，麦克风能录。TFA9887 走现有 `libtfa9887` 和 acdb。通话拓扑如果必须先关掉回声消除才能响，先记下，回声消除不挡收口。
7. 蓝牙。开关、扫描、配对、A2DP 播放。固件读 `mmcblk0p12`，不另刷这个分区。耳机上的通话留到收口之后。
8. 传感器。加速度计、陀螺仪、磁力计、气压、光感、距离、霍尔都有事件。persist 里的校准不动。阶段 0 探到的是 ST LSM6DS3、`yas537_mag`、`alps_pressure`，加上光感、距离、霍尔。
9. 蜂窝。第一张卡识别、驻网、数据能上网，听筒和免提各打通一次。RIL 用这台机器的 modem 分区和现有 blob。短信要能收发。第二张卡和 VoLTE 不挡。阶段 0 没有读卡槽数量。
10. 振动。已通过，见上面。
11. 硬件编解码。视频能播能录一段，音频解码不走软解兜底。Venus 和 ADSP 用现有固件路径。编解码进程崩溃先修这个，再进相机。
12. 相机。后摄 `imx230`、前摄 `ov8865` 都能预览、拍照、录短视频。32 位 HAL1，不在这一阶段打开 HAL3。
13. 指纹。先有 Gatekeeper，再录入一枚，锁屏能解开，另一根手指被拒绝。用户态继续是 Silead 的 `fpsvcd`，校准留在 persist。没有 Gatekeeper 时不要设密码。
14. 休眠唤醒再确认一次。第 1 项的电源键之后，Wi-Fi、蜂窝和传感器都开着时再睡一次、再亮一次。背光必须灭。阶段 1 里 `cont_splash` 期间 `lcd-backlight` 不写硬件，电流在 WLED 上。

阶段 0 没有探到 NFC、红外、FM。`ueventd.qcom.rc` 里的 `nfc-nci` 是高通模板，不排进验收。定位用捐赠树的 HIDL gnss，只留 sambar 的 `gps.conf`。阶段 0 没有定位成功的记录，放在收口之后。

## 不挡住这次收口

14 项过了之后，到一套可以交给别人刷的包为止，按这个顺序。

1. 通话能听清。听筒和免提先响了再收，回声消除和降噪可以后补。
2. 蓝牙耳机上的通话。
3. 第二张卡和 VoLTE。第一张卡的短信、数据和普通通话已经在第 9 项里。
4. 定位。gnss HIDL，配置只用 sambar 的 `gps.conf`。不把 CM13 的 `loc_api` 整棵树搬进 18.1。
5. 可刷的安装包。只含 boot 和 system。recovery 不放进同一包，除非下面一项已经能刷它。
6. 能挂这块 f2fs、也能刷 system-as-root 包的 recovery。现在的 TWRP 2.8.7 能挂 `/data`，不保证能刷 18.1 的包。换 recovery 之前，现在这份镜像留在 `device-backup/` 的恢复路径上。
7. 加密。这次不做。3.10 上的文件加密单独开一轮，不和清盘绑在一起。
8. SELinux enforcing。放在最后。每加一个 HAL 都会多一批 denial，现在切只会反复改策略。

## 实现笔记

2026-10-29 第 1 项。横条在 SurfaceFlinger 的截图里就有，不是面板扫描。GLES 当时是 SwiftShader。这台机器自己的 `libEGL_adreno.so`、`libGLESv2_adreno.so`、`libgsl.so`、`libllvm-glnext.so` 和 `a420_pm4.fw`、`a420_pfp.fw` 已经在镜像里，`ro.hardware.egl` 选的是 swiftshader。MSM8994 的 Adreno 430 用的就是这两份名叫 a420 的固件。内核在开机大约 9 秒把它们交给 kgsl。`/dev/kgsl-3d0` 在装上 ueventd 之后是 0666。更早一次 `eglInitialize` 失败，是这个节点还是 `0600 root`，SurfaceFlinger 接着在 `eglQueryStringImplementationANDROID` 里退出。

`device.mk` 把 `ro.hardware.egl` 改成 `adreno`。SwiftShader 的包留着，没有选中。没有拿一加 2 的库或固件。面板校准 XML 没动。

稀疏文件 1593029140 字节，SHA256 `977197292482f6e18bd0647307bb3e42e30848d60fb3a20880433d9aef5c20b0`，展开后正好 3221225472。三段 Writing 都是 OKAY，总时间 71.5 秒。只刷了 system，boot 仍是 `#27`。没有格式化 userdata。然后重启了一次。

开机后 `dumpsys SurfaceFlinger` 是 `Qualcomm, Adreno (TM) 430, OpenGL ES 3.1 V@139.0`。日志里没有 `Unknown Chip ID`。桌面壁纸截图没有横条，现场在 `phase1/live-step9a/`。`screen_brightness` 写成 20 时 `lcd-backlight` 是 20、`wled` 是 279；写成 200 时是 200 和 2793。电源键之后两个都是 0，`mWakefulness=Asleep`，再唤醒回到亮。`copybit` 仍打不开 `libC2D2.so`，这次的合成不靠它，没有装。Launcher 壁纸中间还有「正在加载」，那是旧桌面数据，不是这一项。

## 事件

- 2026-10-29：第 1 项。`ro.hardware.egl=adreno`，用的是这台机器自己的 Adreno 用户态和 `a420_pm4.fw`、`a420_pfp.fw`。system SHA256 `977197292482f6e18bd0647307bb3e42e30848d60fb3a20880433d9aef5c20b0`。只刷了 system，重启一次。Adreno 430，OpenGL ES 3.1，横条没有了，背光能灭能亮。细节在「实现笔记」。
