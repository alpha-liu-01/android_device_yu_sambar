# 阶段 2：18.1 做到能日常使用

日期：2026-10-29。路线图是 `docs/sambar-roadmap.md`。阶段 1 已完成，记录在 `docs/sambar-phase-1.md`。本文记阶段 2 的顺序和约束。实现笔记和事件先空着，做的时候再补。

完成标准：验收顺序 1 到 14 都有实机记录。第 1 项显示、第 2 项导航、第 3 项触控、第 4 项 USB、第 5 项 Wi-Fi、第 7 项蓝牙、第 8 项传感器和第 10 项振动已经通过。SELinux 保持 permissive，每次开机的 denial 存下来。短信、第二张卡、VoLTE、通话回声消除、蓝牙耳机通话、加密、可刷的安装包、新 TWRP 都不挡住这 14 项。前一项没有记录，先不跳到下一项。

当前 system SHA256 `baa659f4a5cf2ba871b62cfa154fe601c90db1301fb73bf1bae6c2f762b077d0`。boot 仍是内核 `#27`，设备树里补了 1 kΩ 的电池 ID，镜像在 `phase1/boot-27-battery-id.img`。recovery 是内核 `#16`，能挂上 userdata 的 f2fs。

阶段 1 留下、还没做的：没有 Gatekeeper。`radio@1.1` 的两个 rild 已经注册，第 9 项还没过。

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
4. USB。已通过。文件两个方向都拷过。充电、MTP、PTP 能切换。内核仍是传统 `android_usb`，不是 ConfigFS。adb 继续用阻塞读写（`ro.adb.nonblocking_ffs=0`，`sys.usb.ffs.aio_compat=true`）。U 盘按 fstab 的 `usbdisk` 挂，这次没插，不挡这一项。细节在「实现笔记」。
5. Wi-Fi。已通过。`wlan.ko` 加载，固件来自这台机器的 `/firmware/image`。扫描后连上 `ZCXYYY0824`，地址 `10.0.0.108`，`ping` 通。supplicant 是 HIDL。内核继续 `CONFIG_QCA_CLD_WLAN=m`。细节在「实现笔记」。
6. 音频。喇叭、听筒、有线耳机三个出口都有声音，麦克风能录。TFA9887 走现有 `libtfa9887` 和 acdb。通话拓扑如果必须先关掉回声消除才能响，先记下，回声消除不挡收口。整首 MP3 卡顿、FLAC 打不开、音量减键没有上报，记在「先记下、后面再修」，不在这一项里改。
7. 蓝牙。已通过。开关、扫描、配对、A2DP 播放都做过。固件读 `mmcblk0p12`，没有另刷这个分区。同一首 MP3 在耳机里不卡，是因为这条路不走压缩直通，喇叭上的卡顿还在。FLAC 仍然打不开。耳机上的通话留到收口之后。细节在「实现笔记」。
8. 传感器。已通过。加速度计、陀螺仪、磁力计、气压、光感、距离、霍尔都有事件。persist 里的两份校准没有改。阶段 0 探到的是 ST LSM6DS3、`yas537_mag`、`alps_pressure`，加上光感、距离、霍尔。细节在「实现笔记」。
9. 蜂窝。第一张卡识别、驻网、数据能上网，听筒和免提各打通一次。RIL 用这台机器的 modem 分区和现有 blob。短信要能收发。第二张卡和 VoLTE 不挡。阶段 0 没有读卡槽数量。
10. 振动。已通过，见上面。
11. 硬件编解码。视频能播能录一段，音频解码不走软解兜底。Venus 和 ADSP 用现有固件路径。编解码进程崩溃先修这个，再进相机。MP3 走喇叭的压缩直通时放几秒就空几秒，在这一项里修，不要改成永久软解。蓝牙耳机里同一首不卡，那是另一条 PCM 再编码的路，不算这一项过了。FLAC 打不开停在提取器，不和 Venus 绑在一起。细节在「先记下、后面再修」。
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

## 先记下、后面再修

2026-10-29 看过日志，三件都先不改。喇叭、听筒、有线耳机和麦克风当时已经有声音，这三件不把第 6 项退回去。

整首 MP3 放大约 4 秒就空几秒。`洛天依 - 东京不太热.mp3` 走喇叭时是 `compress-offload-playback`，44100 Hz，平均码率 128000，不是软解。压缩驱动反复打出 `No space available in compress driver`，`compress_wait` 大约每两秒返回一次。衔接下一段时 `offload_thread_loop: Next track returned error -1`。每次重新出声，`tfa start with volume 0`，喇叭通路被拆掉再接上。2026-10-30 同一首在蓝牙耳机里是连续的。那次日志里没有 `compress-offload-playback`，A2DP 吃的是 PCM，再由 `a2dp_aac_encoder` 编成 AAC。耳机不卡，不表示这条压缩直通好了。放到第 11 项：把这台机器 ADSP 上的压缩直通修通，固件仍用 `/firmware/image` 里现有的。不要为了先能听就把策略里的 `AUDIO_OUTPUT_FLAG_COMPRESS_OFFLOAD` 拿掉、改成永久软解，第 11 项要求音频解码不走软解兜底。

FLAC 完全放不出。`Beyond - 光辉岁月.flac` 文件头是 `fLaC`（`66 4c 61 43`），STREAMINFO 的长度是 34 字节，头是正常的。失败停在 `FLACExtractor: end_of_metadata failed`，然后 `GenericSource: source has no track`。没有解码器日志，也没有声卡打开。日志里没有 `FLACParser::errorCallback`，所以不是帧校验错。MediaProvider 打开它时写了 `Using lower FS`。可能是这份内容 URI 上 `readAt` 提前结束，也可能是后面的图片或注释块让 `process_until_end_of_metadata` 返回失败。再拿另一首 FLAC 区分是这一份文件还是提取器。不放进第 11 项，和 Venus、ADSP 无关。

音量减键在 Android 里没有这个键。`gpio-keys` 只上报 115，对应音量加，设备树里挂在 pm8994 GPIO 3。`qpnp_pon` 只上报 116，对应电源。没有任何输入设备上报 114。`qpnp_pon.kl` 把 114 写成音量减，内核不发这个码，映射不会生效。一加 2 的音量减在 `msm8994-mtp.dtsi` 里是 pm8994 GPIO 2、`linux,code = <114>`。捐赠树 `msm-pm8994.dtsi` 的 `pon_2` 把 114 注释掉了，注释写音量减改由 GPIO 控制。PM9X 的设备树只抄了音量加，没有音量减。进 recovery 是 LK 直接读这个键，不经过 Android 输入设备，所以按键本身没有坏。修的时候先确认这台机器的音量减是 GPIO 2 还是 PMIC resin，再把对应节点补进正在启动的那份 PVT 设备树。沿用电池 ID 那种只改 DTB 的做法，不要直接 `mka bootimage`：整份重编会把 `second_addr` 写成 0，或者丢掉 `soc.0`，开机回到 fastboot。这件事不放进第 11 项，下一次允许改 boot 时做。

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

2026-10-29 第 4 项。设置里 USB 模式是灰的，adb 本身是好的。这台机器没有 `/sys/class/dual_role_usb`、`typec`、`extcon`，没有进程向 `UsbPortManager` 报一个已连接的设备口。另外 `init.sambar.rc` 在 `on boot` 里把 `sys.usb.config` 写成 `adb`。通用的 `configfs=0` 规则没有 MTP 和 PTP。当时仅有的 `mtp,adb` 规则把功能写成 `adb`、产品号写成 `4EE7`，所以就算属性改了，gadget 仍是只有 adb。

`android.hardware.usb@1.0-service.sambar` 报一个口 `port0`。线还插着时读 `/sys/class/power_supply/usb/online`，模式 UFP、数据角色 device、电源角色 sink。`supportedModes` 和当前模式相同，三个 `canChange` 都是 false。这颗内核不是 ConfigFS，`sys.usb.configfs` 保持 0。`init.sambar.rc` 不再改 `sys.usb.config`。`mtp`、`mtp,adb`、`ptp`、`ptp,adb` 按传统 `android_usb` 写功能名和 Google 产品号：`4EE1`、`4EE2`、`4EE5`、`4EE6`。`f_ffs` 的别名仍是 `adb`，读回来是 `ffs`。调试开着时，充电这一项就是只有 adb，产品号 `4EE7`，通用规则已经会写。`rndis` 和 `midi` 也写了对应规则，这次没有单独验收。主 manifest 里声明这个 HAL，没有再放第二份 VINTF 片段。`ro.adb.nonblocking_ffs=0` 和 `sys.usb.ffs.aio_compat=true` 没动。

稀疏文件 1593344532 字节，SHA256 `f54b6630c4524ccce1032d97314e779d7bdad8b79ad299a053594c7aa48fed6e`，展开后正好 3221225472。三段 Writing 都是 OKAY，总时间 71.7 秒。只刷了 system，boot 仍是 `#27`。没有格式化 userdata。然后重启了一次。

开机后 `init.svc.vendor.usb-hal-1-0=running`。`dumpsys usb` 里 `port0` 是 connected，`current_mode=ufp`，`data_role=device`，`power_role=sink`。切到 MTP 后是 `18d1:4ee2`，功能 `mtp,ffs`，`/dev/mtp_usb` 是 `0660 root mtp`。主机把一份文件拷进内部存储，手机上读到的内容和主机一致；再从手机拷回主机，两边一致。测完把这两个文件删了。PTP 是 `18d1:4ee6`，功能 `ptp,ffs`。充电是 `18d1:4ee7`，功能 `ffs`，这时 `usb/online` 仍是 1。最后把解锁后的功能设成 MTP，当前是 `mtp,adb`。没有插 U 盘。

2026-10-29 插进来的充电和电量。电量停在 50% 很久，AIDA64 上看是 4.000V。内核里 `battery_type` 是 `Unknown Battery`，`charge_full_design` 是 0，温度是 250（25.0℃）。电压节点本身在动，大约 3.99V 到 4.06V，AIDA64 把靠近 4000 mV 的数显示成 4.000V。电量计的原始 SOC 大约是 69，驱动因为没配上电池曲线，对外一直报默认的 50。

电池 ID 读数是 980Ω。这颗内核按 kΩ 乘 1000 去对曲线。Compal PM9X 的表里只有 0Ω、10 kΩ、100 kΩ，980Ω 对不上。10 kΩ 那份是 3040 mAh、充满 4.4V 的 `apak-3000mah-10k`。在同一份曲线上加了 ID `1`（1 kΩ，15% 以内含 980Ω）。没有换内核二进制，`uname` 仍是 `3.10.108-sambar+ #27`。只改了 boot 里 PVT 那份 DTB 的这个属性。system 的 fstab 路径仍是 `soc.0`。直接 `mka bootimage` 会把 `second_addr` 写成 0，并且当前源码树编出来的 DTB 会丢掉 `soc.0`，这两种都会回到 fastboot。源码里已经把 `soc.0` 和 1 kΩ 写回去。刷进去的是 `phase1/boot-27-battery-id.img`，SHA256 `32c51bffefad2d9accd8783151afe9d2c86be321c6cb05875710d76c708b40ce`。刷之前的 `#27` 在 `phase1/boot-27-before-battery.img`。

开机后日志是 `apak-3000mah-10k found`，`Battery SOC: 68`。`dumpsys battery` 的 level 是 68，电压 3985 mV，后来电压到 4022 mV。`charge_full_design` 是 3124 mAh，`charge_full` 是 2940 mAh，`voltage_max_design` 是 4.4V。状态是 Charging。接电脑时 USB 类型是 SDP，输入上限 500 mA，这是这颗充电芯片对标准 USB 口的上限，电池电流在大约 ±80 mA 之间，屏幕开着时大部分 500 mA 被系统用掉。插墙充时走的是另一条电流，不按这 500 mA。温度读数仍是 25.0℃。

2026-10-29 第 5 项。`wlan.ko` 在镜像里，没有加载。没有 `wpa_supplicant`，也没有 Wi-Fi HAL。这台机器的固件分区是 2015-11-27 的 `qwlan30.bin`、`bdwlan30.bin`、`otp30.bin`、`utf30.bin`，走 PCIe 上的 QCA6174。`/firmware/image` 里没有 `wcnss.b0*`，那些旧链接用不上。没有把一加 2 或别的板子的固件拷进 system。

`WCNSS_qcom_cfg.ini` 用这棵树里已有的那份，放到 `/system/etc/wifi/`，原来的链接指到这里。没有这份 ini 时，`insmod` 打出 `Failed to probe WLAN`。放上之后驱动起来，`wlan0` 的地址是 `00:a0:c6:eb:5c:6f`。persist 里没有 `wlan_mac.bin`，驱动用芯片上的地址，没有另写一份。`bdwlan30.b00` 不存在，驱动改用分区上的 `bdwlan30.bin`。`evicted30.bin` 是 codeswap，这块板子没有，缺了不影响加载。`/proc/config.gz` 仍是 `CONFIG_QCA_CLD_WLAN=m`。

qcwcn HAL 和 HIDL supplicant 装进 vendor。`android.hardware.wifi@1.4` 和 `android.hardware.wifi.supplicant@1.3` 各有自己的 VINTF 片段，没有再写进主 manifest。HAL 以 `wifi` 用户跑。`/sys/module/wlan/parameters/fwpath` 是 `0644 root`，它写不进去，STA 接口创建失败，Wi-Fi 马上被关掉。`insmod` 本身已经把 `wlan0` 带起来，所以不设 `WIFI_DRIVER_FW_PATH_*`。supplicant 要把配置拷到 `/data/vendor/wifi/wpa/`，这个目录原来没有，拷贝失败后接口也建不起来。`init.sambar.rc` 在 `post-fs-data` 里建这个目录。

稀疏文件 1606476308 字节，SHA256 `1b37e0850b017b006fec6119bf35b13efdd31031d924a3d92610f2da94ffe961`，展开后正好 3221225472。四段 Writing 都是 OKAY，总时间 72.4 秒。只刷了 system，boot 仍是 `#27`。没有格式化 userdata。刷之前删掉手建的 `/data/vendor/wifi`，重启后 init 重新建好。`lshal` 里 `IWifi/default` 和 `ISupplicant/default` 都在。`wlan.ko` 已加载。扫描能看到周围网络。连上 `ZCXYYY0824`，5 GHz，地址 `10.0.0.108/24`，`ping 1.1.1.1` 三包都通。

2026-10-30 第 7 项。蓝牙进程起不来。`com.android.bluetooth` 反复死在 `startup_timer_expired`，`dumpsys bluetooth_manager` 是 OFF，地址是空的。固件分区已经挂在 `/bt_firmware`，只读，文件是 2015-08-30 的 `btfw30.tlv`、`btfw32.tlv`、`btnv30.bin`、`btnv32.bin`。没有 HAL，也没有 `libbt-vendor`。没有往 `mmcblk0p12` 写任何东西，也没有拿别的机器的 TLV 或地址。

`BOARD_HAVE_BLUETOOTH_QCOM` 打开之后，CAF 的 `libbt-vendor` 按芯片版本从 `/bt_firmware/image/` 选 3.0 或 3.2 的固件，串口是写死的 `/dev/ttyHS0`。它读的属性是 `vendor.qcom.bluetooth.soc`，`system.prop` 里的 `vendor.*` 不会进系统。`init.sambar.rc` 在 `on boot` 里把这个属性写成 `rome`，并把 `rfkill0` 和 `/dev/ttyHS0` 交给 `bluetooth`。这台机器的 `wcnss_filter` 看的是不带 `vendor.` 前缀的 `wc_transport.*`，所以 `QCOM_BT_USE_OLD_WCNSS_FILTER` 打开。固件下完之后 `wc_transport.start_hci=true`，init 拉起 `/vendor/bin/wcnss_filter`。这个二进制要 64 位的 `libdiag.so`，用的是这台机器自己的。A2DP 没有装 `bluetooth.audio@2.0`。策略里原来的 `a2dp` 模块还在，协议栈走旧的 `bt_a2dp_hw`，控制套接字是 `/data/misc/bluedroid/.a2dp_ctrl`。耳机通话没做。

HIDL 服务在拿到地址之前会直接退出（`Open: No Bluetooth Address!`）。`persist/.bt_nv.bin` 是 9 字节：`01 00 06` 后面跟着 `a1 a3 17 00 00 00`。这就是这台机器的地址，不是从别的板子抄的。写成 `/vendor/etc/bluetooth/bdaddr`，内容正好是 `a1:a3:17:00:00:00` 十七个字符，没有换行。读地址的代码把多出来的一个字节当成非法。`ro.bt.bdaddr_path` 指到这个文件。

稀疏文件 1608602132 字节，SHA256 `545ddb143e696d8627f99edcd127a975030b13fbdea3764fd579daab08311720`，展开后正好 3221225472。四段 Writing 都是 OKAY，总时间 72.7 秒。只刷了 system，boot 仍是 `#27`。没有格式化 userdata，也没有刷 bluetooth 分区。然后重启了一次。

开机后 `vendor.qcom.bluetooth.soc=rome`。打开蓝牙，`Bluetooth FW and transport layer are initialized`，`wcnss_filter` 在跑。状态 ON，地址 `A1:A3:17:00:00:00`，名字 YU5050。扫描能看到 `LYWSD03MMC`。用户配对之后耳机里有声音。播放 `洛天依 - 东京不太热.mp3` 时，`bt_a2dp_hw` 的 `A2DP_CTRL_CMD_START` 返回 status 0，`a2dp_aac_encoder` 每 23 ms 吃 4057 字节 PCM。日志里没有 `compress-offload-playback`，也没有 `No space available in compress driver`。喇叭那条路把同一首 MP3 交给 ADSP 的压缩直通，驱动空了就把功放拆掉再接上，所以卡。耳机这条路先把 MP3 解成 PCM，再在蓝牙进程里编成 AAC 送出去，根本不进那条压缩直通。耳机不卡，不说明第 11 项已经好了。同一段时间 FLAC 仍是 `FLACExtractor: end_of_metadata failed`，然后 `GenericSource: source has no track`，和有没有连耳机无关。aptX 的编码库不在镜像里，这次走的是 AAC。耳机上的通话没有测。Wi-Fi 刷完之后仍是 `10.0.0.108`。

2026-10-30 第 8 项。`dumpsys sensorservice` 原来是 `No Sensors on the device`。内核 `#27` 没有这些驱动，`CONFIG_IIO` 也没打开。芯片已经在正在跑的设备树里，只是没有驱动绑上：i2c `15-006b` 是 `st,lsm6ds3`，`15-002e` 是 `qcom,yas537`，`15-0048` 是 `hsppad038`，i2c `7-0048` 是 `stk,stk3x1x`，平台设备 `hall.82` 是 `hall-switch`。气压计的 HAL 名字是 `alps_pressure`，芯片是这颗 Alps HSPPAD038，不是另一颗。源码在 Cyanogen 的 msm8994 树里，是输入子系统的驱动，不走 IIO，也不走格力那套 SLPI。编成模块，对着 `#27` 的 `Module.symvers`，没有重刷 boot。`stk3x1x.c` 和 `stk3x1x_pm9x.c` 都声明 `stk,stk3x1x`，只用 pm9x 那份，光感的输入名才是 `lightsensor-level`。YAS 的 `MODULE_DEVICE_TABLE` 写成了 `yas533_of_match`，表的名字是 `yas537_of_match`，模块编不过，改的是这一处。LSM6DS3 的核和 i2c 拆成两个模块之后，核上没有 `MODULE_LICENSE`，GPL 符号加不进去，补了一行 `GPL`。设备树里 LSM6DS3 没有中断脚，探测日志是 `irq = 0`，所以模块按轮询编，`accel/polling_rate` 和 `gyro/polling_rate` 才在。这和 HAL 要写的节点一致。

这台机器的 HAL 是 `sensors.msm8994.so`，还要 `libyasalgo.so`。`ro.hardware` 是 `qcom`，所以装成 `/vendor/lib64/hw/sensors.qcom.so`。HIDL 用 `android.hardware.sensors@1.0-impl` 和 `@1.0-service`。服务自己的 rc 已经声明了 `ISensors/default`，主 manifest 里原来的 passthrough 拿掉，避免同一条接口登记两次。`init.sambar.rc` 在 `on fs` 里加载这六个模块，赶在 `class hal` 之前，免得 SensorService 把空名单缓存下来。

校准没有改。`/persist/accel_cali.conf` 和 `/persist/gyro_cali.conf` 仍是 16 字节，属主 `system`，时间戳还是 1969-12-31。两个文件第 4 个整数都是 `0xAB`。驱动用固件接口要 `lsm6ds3/accel_cali.conf`，不会自己去读 persist。`on fs` 里做两个符号链接，指回 persist 上的原文件，不把内容拷进镜像。加载之后加速度计偏移是 -88、224、-325，陀螺仪是 -43、55、27，和这两个文件一致。

霍尔不在这份 HAL 的传感器名单里。驱动注册的输入设备叫 `hall_sensor`，事件是 `SW_LID`。原驱动只在沿上报告，盖子一直开着就永远没有事件。模块在探测后读一次 GPIO，这次是开（`hall_sensor: far`），`getevent -S` 的开关位是 0。

稀疏文件 1610986004 字节，SHA256 `baa659f4a5cf2ba871b62cfa154fe601c90db1301fb73bf1bae6c2f762b077d0`，展开后正好 3221225472。四段 Writing 都是 OKAY，总时间 72.4 秒。只刷了 system，boot 仍是 `#27`。没有格式化 userdata，没有刷 persist，也没有刷 bluetooth。然后重启了一次。

重启后六个模块都在，`vendor.sensors-hal-1-0` 是 running。`dumpsys sensorservice` 列出 LSM6DS3 加速度计和陀螺仪、YAS537 磁力计、HSPPAD 气压、SenseTek 光感和距离。加速度计已经在往 SensorService 送事件，静止时大约是 -0.01、0.36、9.56。打开之后陀螺仪、磁力计、气压都有输入事件。光感 `ABS_MISC` 是 15，和 `/sys/als` 读到的 14 lux 一致。距离打开时内核打了 `ps input event=1, ps code = 1225`，人离得远，绝对值不重复报，时间戳还在走。Wi-Fi 刷完之后仍是 `10.0.0.108`。

2026-10-30 第 9 项，数据通了。通话和短信还没做，这一项没有过。Fizz 卡在第二槽，`gsm.sim.state=ABSENT,LOADED`。开机后驻在家网 LTE，运营商 Fizz，号码 `302490`（这张卡的等效家网，和 `302500` 一起），漫游是 false。首选网络是 9。`rmnet_data0` 拿到 `10.116.84.133/30`，网关 `10.116.84.134`，APN 仍是 `mobile.bm`。`ping 8.8.8.8` 三包都通，44 到 136 ms。这条网络在 Connectivity 里是 VALIDATED、NOT_ROAMING。

上不了网不是 APN，也不是数据漫游开关。基带的数据会话能起来（`DSI_EVT_WDS_CONNECTED`），`netmgrd` 给 `rmnet_data0` 配地址时把同一块内存释放了两次。Android 11 的 Scudo 把进程打死，init 拉起来之后内核里 IPA 的 WAN 入口已经占着（`EP already allocated`，`failed to configure ingress`），这次呼叫被拆掉，框架看到的原因是 65535。`libnetmgr_malloc` 只预加载给 `netmgrd`，第二次释放直接丢掉。重启后这个进程的 pid 没变，dmesg 里没有 signal 6。没有重刷 system，库和 `zz-sambar-radio.rc` 里的 `LD_PRELOAD` 是写进当前这份 system 的。下一次编 system 会带上。`system.prop` 补了 `persist.data.netmgrd.qos.enable`、`persist.data.mode=concurrent`、`persist.rmnet.data.enable`。没有动 modem、modemst、fsg。

3G 另测了一次。第二张卡的首选网络改成仅 WCDMA（模式 2），大约一分半。语音报的是 `No service Home in UMTS`，WCDMA、GSM、LTE 的信号字段都是无效值，没有测到小区。测完改回模式 9，上面的家网 LTE 和地址是这次重启之后的。基带镜像的 `mcfg_sw` 里没有加拿大运营商，有印度的 Airtel、Reliance 和一份通用 `gen_3gpp`。没有写 NV，没有改 USB。通话没有拨。4G 上语音域是家网 LTE（`REG_HOME`，RAT 14）。用户确认这台机器的 3G 只有 900/2100，当地 3G 是 850/1900，两边对不上。3G 和通话回落不再查。

2026-10-30 换卡之后 4G 又没有网络。当时插着的是 Fizz，第二槽，`simSlotIndex=1`。飞行模式是关的，运营商和制式都是空的。RIL 日志停在 `telephony LPM`：射频被要求关掉。选过 3G 之后 `preferred_network_mode1` 停在 0，LTE 不在允许的制式里，所以换 TELUS 时状态栏没有 LTE 图标。模式 9 要发给这张卡自己的 subId。Fizz 是 1，那张 TELUS 是 2。发给 1 会打到空着的第一槽，那一槽的 modemRaf 是 32768，请求被收成仅 GSM。TELUS 用 subId 2 发过一次模式 9，当时已经驻上家网 LTE `302220`，信号大约 rsrp -91，但 `SETUP_DATA_CALL`（APN `sp.telus.com`）没有返回，`rmnet_data0` 上还留着上一张 Fizz 的地址。接着把 `ril-daemon2` 和 `netmgrd` 停掉再拉起来，新的 rild 里 `dsi_inited` 是 0，`dsi_get_data_srvc_hndl` 不给句柄，数据请求立刻以原因 65535 失败，射频也进了 LPM。

这次没有再停这两个进程，也没有重刷。`setRadioForSubscriber` 对 subId 1，加上 `setRadioPower`，射频打开。几秒内 Fizz 回到家网 LTE，号码 `302490`，`rat=Unknown,LTE`。`rmnet_data0` 是 `10.118.52.138/30`，网关 `10.118.52.137`，DNS `10.208.36.186` 和 `10.208.37.47`，APN 仍是 `mobile.bm`。`ping 8.8.8.8` 三包都通，51 到 149 ms。Connectivity 是 VALIDATED、NOT_ROAMING。首选网络是 9。`netmgrd` 仍预加载 `libnetmgr_malloc`，这次配地址没有再被 Scudo 打死。TELUS 已经拔掉，这次没有再插回去测数据。通话和短信还没做。

## 事件

- 2026-10-29：第 1 项。`ro.hardware.egl=adreno`，用的是这台机器自己的 Adreno 用户态和 `a420_pm4.fw`、`a420_pfp.fw`。system SHA256 `977197292482f6e18bd0647307bb3e42e30848d60fb3a20880433d9aef5c20b0`。只刷了 system，重启一次。Adreno 430，OpenGL ES 3.1，横条没有了，背光能灭能亮。细节在「实现笔记」。
- 2026-10-29：第 2 项之前清 userdata。recovery 里 `mkfs.f2fs -l userdata -t 1 /dev/block/mmcblk0p39`，24.6 GB，挂上是空的。其它分区没写。重启后 adb 是 `unauthorized`，旧的 `adb_keys` 在这块盘上。细节在「开始前先清 userdata」。
- 2026-10-29：清盘后的那次开机停在第一屏。`vold` 在 `needsCheckpoint()` 里等 `IBootControl`，锁不放，`setListener` 不返回。装上 `bootctrl.qcom` 和 `android.hardware.boot@1.0-impl`。不写 misc。细节在「实现笔记」。
- 2026-10-29：开机后应用过几秒闪退，再重启进不了系统。`system_server` 在任务快照上 abort，因为 `Bitmap.copy(HARDWARE)` 被改成了软件位图。已改回硬件位图，并在 `on boot` 停掉 serial console。system SHA256 `165d579930970b4633c5c90feb1837740dd593deed41ea6f4035890048733b60`。只刷了 system。重启后进了系统，设置不再被系统拖死，串口通知没有了。细节在「实现笔记」。
- 2026-10-29：第 2 项。`qemu.hw.mainkeys=0`，软件导航栏出现。三键和全面屏手势都能返回、回桌面、打开最近任务。system SHA256 `64075779f342065245803419a616466eed36235701248775b18c8f466d2688b8`。只刷了 system。细节在「实现笔记」。
- 2026-10-29：第 4 项。USB HAL 报 `port0` 为设备口，`init.sambar.rc` 按传统 `android_usb` 写 MTP 和 PTP。充电、MTP、PTP 都能切换，文件两个方向都拷过。system SHA256 `f54b6630c4524ccce1032d97314e779d7bdad8b79ad299a053594c7aa48fed6e`。只刷了 system。细节在「实现笔记」。
- 2026-10-29：电量停在 50%、AIDA64 显示 4.000V。电池 ID 980Ω 对不上曲线，驱动把电量固定成 50。PVT 设备树给 `apak-3000mah-10k` 加了 1 kΩ。内核仍是 `#27`。开机后电量 68%，电压大约 4.0V，充满容量 3124 mAh。电脑 USB 仍是 500 mA。细节在「实现笔记」。
- 2026-10-29：第 5 项。`wlan.ko` 由 qcwcn HAL 加载，固件是这台机器 `/firmware/image` 上的 `qwlan30.bin` 和 `bdwlan30.bin`。supplicant 是 HIDL。连上 `ZCXYYY0824`，地址 `10.0.0.108`，`ping` 通。内核仍是 `#27`，`CONFIG_QCA_CLD_WLAN=m`。system SHA256 `1b37e0850b017b006fec6119bf35b13efdd31031d924a3d92610f2da94ffe961`。只刷了 system。细节在「实现笔记」。
- 2026-10-29：整首 MP3 走压缩直通时放几秒就空几秒，放到第 11 项修 ADSP，不改成永久软解。FLAC 在提取器读元数据时失败，文件头是正常的 `fLaC`，不和 Venus 绑在一起。音量减没有输入事件，设备树里没有这个键，下一次改 boot 时补。三件都先不改。细节在「先记下、后面再修」。
- 2026-10-30：第 7 项。Rome 固件仍在 `mmcblk0p12`，没有刷这个分区。`libbt-vendor` 从 `/bt_firmware/image` 下载，`wcnss_filter` 用这台机器自己的。地址来自 `persist/.bt_nv.bin`。开关、扫描、配对之后耳机里有声音，编码是 AAC。同一首 MP3 在耳机里不卡，因为这条路吃 PCM，不走喇叭的压缩直通。FLAC 仍停在提取器。system SHA256 `545ddb143e696d8627f99edcd127a975030b13fbdea3764fd579daab08311720`。只刷了 system，boot 仍是 `#27`。细节在「实现笔记」。
- 2026-10-30：第 8 项。内核 `#27` 没有这些驱动，六个模块在开机时加载，没有重刷 boot。HAL 是这台机器的 `sensors.msm8994.so`，装成 `sensors.qcom.so`。加速度计、陀螺仪、磁力计、气压、光感、距离都有事件，霍尔报了一次开盖。`/persist/accel_cali.conf` 和 `gyro_cali.conf` 没有改，驱动通过符号链接读它们。system SHA256 `baa659f4a5cf2ba871b62cfa154fe601c90db1301fb73bf1bae6c2f762b077d0`。只刷了 system。细节在「实现笔记」。
- 2026-10-30：第 9 项还没过。数据通了：家网 Fizz LTE（`302490`），`rmnet_data0` 是 `10.116.84.133`，APN `mobile.bm`，`ping 8.8.8.8` 通。`netmgrd` 配地址时重复释放，Scudo 把进程打死，给它单独换了分配器。没有重刷 system，也没有动 modem。仅 WCDMA 搜了大约一分半，没有测到小区。通话和短信还没做。细节在「实现笔记」。
- 2026-10-30：换卡之后 4G 没有网络。射频停在 telephony LPM，飞行模式开关是关的。`setRadioForSubscriber` 和 `setRadioPower` 打开射频，首选网络回到模式 9。Fizz 再次驻上家网 LTE `302490`，`rmnet_data0` 是 `10.118.52.138`，APN `mobile.bm`，`ping 8.8.8.8` 通。用户确认 3G 频段对不上，不再查。没有重刷，没有动 modem。细节在「实现笔记」。
