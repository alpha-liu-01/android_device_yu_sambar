# 阶段 2：18.1 做到能日常使用

日期：2026-10-29。路线图是 `docs/sambar-roadmap.md`。阶段 1 已完成，记录在 `docs/sambar-phase-1.md`。本文记阶段 2 的顺序和约束。实现笔记和事件先空着，做的时候再补。

完成标准：验收顺序 1 到 14 都有实机记录。第 1 项显示、第 2 项导航、第 3 项触控和第 10 项振动已经通过。SELinux 保持 permissive，每次开机的 denial 存下来。短信、第二张卡、VoLTE、通话回声消除、蓝牙耳机通话、加密、可刷的安装包、新 TWRP 都不挡住这 14 项。前一项没有记录，先不跳到下一项。

当前 system SHA256 `64075779f342065245803419a616466eed36235701248775b18c8f466d2688b8`。boot 仍是内核 `#27`。recovery 是内核 `#16`，能挂上 userdata 的 f2fs。

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

2026-10-29 已清。recovery 里 `/sbin/mkfs.f2fs` 是 1.4.0（2014-10-18），没有 `-f`。先卸掉 `/data` 和 `/sdcard`，再对 `/dev/block/mmcblk0p39` 执行 `mkfs.f2fs -l userdata -t 1`。扇区数 51600416，和阶段 0 的 userdata 一致。挂回去是空目录，24.6 GB，元数据占 171.5 MB。没有动 persist、modem、bluetooth、modemst、fsg、config。然后重启了一次。这次开机停在 YU 第一屏，原因和修法在「实现笔记」，不是再清一次盘。

清完第一次开机走设置向导。授权过的 adb 公钥在 `/data/misc/adb/adb_keys`，一起没了，主机上会显示 `unauthorized`，要点一次允许。Gatekeeper 装上之前不要设锁屏密码。阶段 1 的图案就是旧 Gatekeeper 的句柄，新系统校验不过。

## 已经通过

这两项是用户在阶段 2 开始前确认的，不重做。清盘或换 GPU 之后如果丢了，再回到对应项。

- 触控。Atmel `atmel_mxt_ts_T100_touchscreen` 能用。固件仍是 `A4_15_2.2_AA.fw`。芯片停在引导模式时，按格力那次的做法把这份固件写回去，不换别的型号的 raw。
- 振动。马达是好的。阶段 1 为了让 `system_server` 过阶段 480 装的 `vibrator.default` 留着。

## 验收顺序

1. 显示能看。已通过。Adreno 430，OpenGL ES 3.1，桌面壁纸没有横条。亮度条和电源键都能改背光。细节在「实现笔记」。
2. 系统导航。已通过。三键导航栏和全面屏手势都能返回、回桌面、打开最近任务。这台手机没有实体导航键。细节在「实现笔记」。
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

2026-10-29 清盘后的第一次开机停在 YU 第一屏。不是显示退回。`system_server` 的主线程停在 `StorageManagerService.connectVold` 的 `IVold.setListener`，`android.fg` 停在 `IVold.monitor`。两边都在等 `vold` 的同一把锁。拿着锁的是 `needsCheckpoint()`：空的 userdata 没有上次 fstrim 的记录，`PerformFstrimIfNeeded` 立刻跑，`vold` 去 `IBootControl::getService()`。TWRP 把 `android.hardware.boot@1.0-service` 和 `android.hardware.boot@1.1.xml` 装进了 vendor，没有装 passthrough 实现。manifest 里写了这个 HAL，进程起来就退出（`Could not get passthrough implementation`），`getService(true)` 一直重试。锁不放，`setListener` 不返回，开机动画交不出去。旧 userdata 上一次 fstrim 还没到期，所以之前能进桌面。这台机器不是 A/B，不能往 misc 写 slot 数据，内核开机日志在 misc 的 +1 MiB。

`device.mk` 加上 `android.hardware.boot@1.0-impl` 和 `bootctrl.qcom`。内核命令行是 `androidboot.hardware=qcom`，`hw_get_module` 先找这个名字。AOSP 自己的 `bootctrl.default` 会改 misc，不用它。这个模块报告一个槽、已经启动成功，`markBootSuccessful` 是空操作，`setActiveBootSlot` 返回错误。不读不写 misc。稀疏文件 SHA256 `e16e89dd37ca9d88b1e62a8d6de849be1754b4f67144e69f82a721ce4b11d251`，展开后正好 3221225472。只刷了 system，三段 Writing 都是 OKAY，总时间 71.5 秒。这次开机进了系统。

2026-10-29 进系统之后几乎每个应用过几秒就闪退，设置也打不开。锁屏上的 “Serial console enabled / Performance is impacted” 是 userdebug 在 `on init` 里执行了 `start console`，`init.svc.console=running` 时 `ActivityManagerService` 会挂这条常驻通知。它不是闪退的原因。闪退是 `system_server` 自己 abort：`TaskSnapshotLoader.loadTask` 把磁盘上的 JPEG 用 `Bitmap.copy(HARDWARE)` 转成硬件位图，再调 `createGraphicBufferHandle`。SwiftShader 时期 `Bitmap.copy` 把 `HARDWARE` 偷偷改成了 `ARGB_8888`，返回的仍是软件位图，JNI 里 `LOG_ALWAYS_FATAL`（`Hardware config is only supported config in Bitmap_getHardwareBuffer`）。`system_server` 一死，前台应用收到 `DeadSystemException`，看起来像应用闪退。快照写进 userdata 之后，下一次开机一加载就再次 abort，所以关机再开就停在外面。tombstone 在 `phase1/step9c/`。相机另有 `ArrayIndexOutOfBoundsException`（还没有相机 HAL），蓝牙 `startup_timer_expired`，这两项不是这次的闪退。

`Bitmap.java` 恢复成原来的硬件位图路径。`TaskSnapshotLoader` 在结果不是 `Config.HARDWARE` 时直接返回，不再把 `system_server` 打死。`init.sambar.rc` 在 `on boot` 里 `stop console`，锁屏不再挂那条串口通知。没有改内核命令行，boot 仍是 `#27`。稀疏文件 SHA256 `165d579930970b4633c5c90feb1837740dd593deed41ea6f4035890048733b60`，展开后正好 3221225472。只刷了 system，三段 Writing 都是 OKAY，总时间 71.6 秒。没有格式化 userdata。重启后 `sys.boot_completed=1`，`init.svc.console=stopped`，没有那条串口通知。设置保持在前台，`system_server` 的 pid 没变，日志里没有再出现 `Hardware config is only supported`。

2026-10-29 第 2 项。开机后没有导航栏窗口。`overlay/frameworks/base/core/res/res/values/config.xml` 里 `config_showNavigationBar` 是 true，但这棵 overlay 没有进 product overlay，跑起来的框架值仍是 false。`qemu.hw.mainkeys` 是空的。`gpio-keys.kl` 只有音量加，`qpnp_pon.kl` 只有电源和音量减，没有实体返回、主页、最近任务。

`system.prop` 写上 `qemu.hw.mainkeys=0`。`DisplayPolicy` 看到 0 就强制打开软件导航栏。手势沿用系统里已有的 `com.android.internal.systemui.navbar.gestural`，三键是 `config_navBarInteractionMode=0`。Quickstep 已经在 `TrebuchetQuickStep` 里，没有另装导航包。

稀疏文件 1593160212 字节，SHA256 `64075779f342065245803419a616466eed36235701248775b18c8f466d2688b8`，展开后正好 3221225472。三段 Writing 都是 OKAY，总时间 71.8 秒。只刷了 system，boot 仍是 `#27`。没有格式化 userdata。

重启后 `qemu.hw.mainkeys=0`，出现 `NavigationBar0`，范围 `[0,2392][1440,2560]`。三键是左边返回、中间主页、右边最近任务。用户在设置里改成全面屏手势之后，返回、回桌面、最近任务也能用，再切回三键同样可以。脚本点按发生在已经切到手势之后，点在三键坐标上，那一次不算失败。

## 事件

- 2026-10-29：第 1 项。`ro.hardware.egl=adreno`，用的是这台机器自己的 Adreno 用户态和 `a420_pm4.fw`、`a420_pfp.fw`。system SHA256 `977197292482f6e18bd0647307bb3e42e30848d60fb3a20880433d9aef5c20b0`。只刷了 system，重启一次。Adreno 430，OpenGL ES 3.1，横条没有了，背光能灭能亮。细节在「实现笔记」。
- 2026-10-29：第 2 项之前清 userdata。recovery 里 `mkfs.f2fs -l userdata -t 1 /dev/block/mmcblk0p39`，24.6 GB，挂上是空的。其它分区没写。重启后 adb 是 `unauthorized`，旧的 `adb_keys` 在这块盘上。细节在「开始前先清 userdata」。
- 2026-10-29：清盘后的那次开机停在第一屏。`vold` 在 `needsCheckpoint()` 里等 `IBootControl`，锁不放，`setListener` 不返回。装上 `bootctrl.qcom` 和 `android.hardware.boot@1.0-impl`。不写 misc。细节在「实现笔记」。
- 2026-10-29：开机后应用过几秒闪退，再重启进不了系统。`system_server` 在任务快照上 abort，因为 `Bitmap.copy(HARDWARE)` 被改成了软件位图。已改回硬件位图，并在 `on boot` 停掉 serial console。system SHA256 `165d579930970b4633c5c90feb1837740dd593deed41ea6f4035890048733b60`。只刷了 system。重启后进了系统，设置不再被系统拖死，串口通知没有了。细节在「实现笔记」。
- 2026-10-29：第 2 项。`qemu.hw.mainkeys=0`，软件导航栏出现。三键和全面屏手势都能返回、回桌面、打开最近任务。system SHA256 `64075779f342065245803419a616466eed36235701248775b18c8f466d2688b8`。只刷了 system。细节在「实现笔记」。
