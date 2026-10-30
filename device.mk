#
# Copyright (C) 2015 The CyanogenMod Project
# Copyright (C) 2017 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Phase 1 skeleton: panel, touch keymaps, fstab, lights.
# Fingerprint, doze, IMS, camera and RIL stay out until a later phase.

LOCAL_PATH := device/yu/sambar

PRODUCT_SOONG_NAMESPACES += \
    device/yu/sambar

PRODUCT_CHARACTERISTICS := nosdcard

# 1440x2560, 560 dpi
TARGET_SCREEN_HEIGHT := 2560
TARGET_SCREEN_WIDTH := 1440
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := xxxhdpi

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.opengles.aep.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.opengles.aep.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/handheld_core_hardware.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/handheld_core_hardware.xml

# Keymaps from the cm-13.0 tree. Not the OnePlus touch panel layout.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/keylayout/gpio-keys.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/gpio-keys.kl \
    $(LOCAL_PATH)/keylayout/qpnp_pon.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/qpnp_pon.kl \
    $(LOCAL_PATH)/keylayout/silead-vinput-keypad.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/silead-vinput-keypad.kl

# Audio XML is present for later phases. Phase 1 does not require sound.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/audio/audio_effects.conf:$(TARGET_COPY_OUT_VENDOR)/etc/audio_effects.conf \
    $(LOCAL_PATH)/audio/audio_platform_info.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_platform_info.xml \
    $(LOCAL_PATH)/audio/audio_policy.conf:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy.conf \
    $(LOCAL_PATH)/audio/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/a2dp_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/a2dp_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/usb_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/usb_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/r_submix_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/r_submix_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/audio_policy_volumes.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_volumes.xml \
    frameworks/av/services/audiopolicy/config/default_volume_tables.xml:$(TARGET_COPY_OUT_VENDOR)/etc/default_volume_tables.xml \
    $(LOCAL_PATH)/audio/media_codecs.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_audio.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_audio.xml \
    $(LOCAL_PATH)/audio/mixer_paths.xml:$(TARGET_COPY_OUT_VENDOR)/etc/mixer_paths.xml

PRODUCT_PACKAGES += \
    fstab.qcom \
    fstab.qcom_ramdisk

# Second-stage init looks for /init.${ro.hardware}.rc on the system image.
# The boot ramdisk is freed after the system partition becomes /.
# host_init_verifier will not open this through the device-tree symlink.
PRODUCT_COPY_FILES += \
    /home/alpha/Documents/GitHub/android_device_yu_sambar/rootdir/etc/init.sambar.rc:$(TARGET_COPY_OUT_ROOT)/init.qcom.rc

# Without these rules /dev/ion and /dev/kgsl-3d0 stay 0600 root, and the
# graphics allocator cannot allocate any buffer.
PRODUCT_COPY_FILES += \
    /home/alpha/Documents/GitHub/android_device_yu_sambar/rootdir/etc/ueventd.qcom.rc:$(TARGET_COPY_OUT_VENDOR)/ueventd.rc

# Display
PRODUCT_PACKAGES += \
    android.hardware.graphics.allocator@2.0-impl \
    android.hardware.graphics.allocator@2.0-service \
    android.hardware.graphics.composer@2.1-impl \
    android.hardware.graphics.composer@2.1-service \
    android.hardware.graphics.mapper@2.0-impl-2.1 \
    android.hardware.memtrack@1.0-impl \
    android.hardware.memtrack@1.0-service \
    copybit.msm8994 \
    gralloc.msm8994 \
    hwcomposer.msm8994 \
    memtrack.msm8994 \
    liboverlay \
    libtinyxml

# Android 6 Adreno userspace from this phone. The filename is
# libEGL_${ro.hardware.egl}.so. eglInitialize used to fail while
# /dev/kgsl-3d0 was 0600 root; ueventd now opens it, and the kernel
# loads a420_pm4.fw / a420_pfp.fw from /vendor/firmware. SwiftShader
# stays installed so the property can be switched back.
SAMBAR_BLOB_VENDOR := /run/media/alpha/YMTC/sambar/blobs/system/vendor
PRODUCT_COPY_FILES += \
    $(SAMBAR_BLOB_VENDOR)/lib/egl/libEGL_adreno.so:$(TARGET_COPY_OUT_VENDOR)/lib/egl/libEGL_adreno.so \
    $(SAMBAR_BLOB_VENDOR)/lib/egl/libGLESv1_CM_adreno.so:$(TARGET_COPY_OUT_VENDOR)/lib/egl/libGLESv1_CM_adreno.so \
    $(SAMBAR_BLOB_VENDOR)/lib/egl/libGLESv2_adreno.so:$(TARGET_COPY_OUT_VENDOR)/lib/egl/libGLESv2_adreno.so \
    $(SAMBAR_BLOB_VENDOR)/lib/egl/eglSubDriverAndroid.so:$(TARGET_COPY_OUT_VENDOR)/lib/egl/eglSubDriverAndroid.so \
    $(SAMBAR_BLOB_VENDOR)/lib/libadreno_utils.so:$(TARGET_COPY_OUT_VENDOR)/lib/libadreno_utils.so \
    $(SAMBAR_BLOB_VENDOR)/lib/libgsl.so:$(TARGET_COPY_OUT_VENDOR)/lib/libgsl.so \
    $(SAMBAR_BLOB_VENDOR)/lib/libllvm-glnext.so:$(TARGET_COPY_OUT_VENDOR)/lib/libllvm-glnext.so \
    $(SAMBAR_BLOB_VENDOR)/lib64/egl/libEGL_adreno.so:$(TARGET_COPY_OUT_VENDOR)/lib64/egl/libEGL_adreno.so \
    $(SAMBAR_BLOB_VENDOR)/lib64/egl/libGLESv1_CM_adreno.so:$(TARGET_COPY_OUT_VENDOR)/lib64/egl/libGLESv1_CM_adreno.so \
    $(SAMBAR_BLOB_VENDOR)/lib64/egl/libGLESv2_adreno.so:$(TARGET_COPY_OUT_VENDOR)/lib64/egl/libGLESv2_adreno.so \
    $(SAMBAR_BLOB_VENDOR)/lib64/egl/eglSubDriverAndroid.so:$(TARGET_COPY_OUT_VENDOR)/lib64/egl/eglSubDriverAndroid.so \
    $(SAMBAR_BLOB_VENDOR)/lib64/libadreno_utils.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libadreno_utils.so \
    $(SAMBAR_BLOB_VENDOR)/lib64/libgsl.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libgsl.so \
    $(SAMBAR_BLOB_VENDOR)/lib64/libllvm-glnext.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libllvm-glnext.so \
    /run/media/alpha/YMTC/sambar/blobs/system/etc/firmware/a420_pfp.fw:$(TARGET_COPY_OUT_VENDOR)/firmware/a420_pfp.fw \
    /run/media/alpha/YMTC/sambar/blobs/system/etc/firmware/a420_pm4.fw:$(TARGET_COPY_OUT_VENDOR)/firmware/a420_pm4.fw

PRODUCT_PACKAGES += \
    libEGL_swiftshader \
    libGLESv1_CM_swiftshader \
    libGLESv2_swiftshader

PRODUCT_PROPERTY_OVERRIDES += \
    ro.hardware.egl=adreno \
    ro.surface_flinger.has_wide_color_display=false \
    ro.surface_flinger.has_HDR_display=false \
    debug.sf.nobootanimation=1

# system_server blocks in VibratorService.vibratorInit until
# IVibrator/default registers. The legacy module is already
# vibrator.default, which writes the timed_output sysfs node.
PRODUCT_PACKAGES += \
    android.hardware.vibrator@1.0-impl \
    android.hardware.vibrator@1.0-service \
    vibrator.default

# audioserver does not publish media.audio_policy until IDevicesFactory
# getService() returns. That call waits forever while the HAL is declared
# and no process has registered it, and AudioService then waits forever
# on the policy service. The default primary module is already installed.
PRODUCT_PACKAGES += \
    android.hardware.audio@2.0-service \
    android.hardware.audio@2.0-impl \
    android.hardware.audio.effect@2.0-impl \
    android.hardware.keymaster@4.0-service \
    android.hardware.soundtrigger@2.0-impl

# The 2.1 service is already in the image and aborts without this impl.
PRODUCT_PACKAGES += \
    android.hardware.health@2.1-impl

# Lights HAL from hardware/qcom-caf/msm8994. The CM13 lights.c stays in
# liblight/ and is built only if BOARD_USE_SAMBAR_LIBLIGHT is set.
# DisplayManagerService waits on ILight while holding its lock. Without
# the HIDL service, system_server never leaves bootstrap.
PRODUCT_PACKAGES += \
    android.hardware.light@2.0-service \
    android.hardware.light@2.0-impl \
    lights.msm8994

# TWRP pulls android.hardware.boot@1.0-service and the 1.1 VINTF fragment
# into vendor, but not the passthrough impl. After a userdata wipe,
# StorageManagerService runs fstrim immediately. That calls
# vold.needsCheckpoint(), which calls IBootControl::getService() while
# holding the volume lock. The declared HAL never registers, so the wait
# never ends and system_server never leaves setListener. The splash stays
# up. This phone is not A/B: one slot, already successful, and nothing
# is written to misc. The module name follows androidboot.hardware=qcom.
# AOSP bootctrl.default rewrites misc and is not used.
PRODUCT_PACKAGES += \
    android.hardware.boot@1.0-impl \
    bootctrl.qcom

# No dual_role_usb or type-c class. The AOSP USB HAL is not packaged.
# Settings greys out every function until some service reports one port
# in device mode. This one reads the USB charger supply. Declared in the
# main manifest only; a second VINTF fragment is refused by hwservicemanager.
PRODUCT_PACKAGES += \
    android.hardware.usb@1.0-service.sambar

# host_init_verifier opens rc files with O_NOFOLLOW, so this cannot be the
# device-tree symlink. The absolute path is the real file.
PRODUCT_COPY_FILES += \
    /home/alpha/Documents/GitHub/android_device_yu_sambar/usb/android.hardware.usb@1.0-service.sambar.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/android.hardware.usb@1.0-service.sambar.rc

# Wi-Fi. The HAL's own VINTF fragment declares android.hardware.wifi.
# Do not also add it to manifest.xml. qwlan30.bin, bdwlan30.bin, otp30.bin
# and utf30.bin stay on this phone's firmware partition. The cfg is the
# file already in this tree. The existing symlink is
# /system/etc/firmware/wlan/qca_cld/WCNSS_qcom_cfg.ini.
PRODUCT_PACKAGES += \
    android.hardware.wifi@1.0-service \
    libwifi-hal-ctrl \
    libcld80211 \
    libwpa_client \
    hostapd \
    wpa_supplicant \
    wpa_supplicant.conf

PRODUCT_COPY_FILES += \
    /home/alpha/Documents/GitHub/android_device_yu_sambar/wifi/WCNSS_qcom_cfg.ini:$(TARGET_COPY_OUT_SYSTEM)/etc/wifi/WCNSS_qcom_cfg.ini \
    /home/alpha/Documents/GitHub/android_device_yu_sambar/wifi/wpa_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant_overlay.conf \
    /home/alpha/Documents/GitHub/android_device_yu_sambar/wifi/p2p_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/p2p_supplicant_overlay.conf

# Audio. The machine driver in kernel #27 asks for a codec named
# tfa98xx.5-0036. This phone's TFA9887 answers at i2c-6 address 0x34 and
# is programmed by libtfa9887, which opens /dev/i2c-6 and reads
# /system/etc/tfa9887.cnt. tfa_stub.ko only registers that codec name and
# the three pinctrl states the machine driver looks up. The acdb files
# are this phone's. The loader reads /etc/acdbdata/MTP/.
PRODUCT_PACKAGES += \
    audio.primary.msm8994 \
    audio_amplifier.msm8994

SAMBAR_BLOB := /run/media/alpha/YMTC/sambar/blobs/system
PRODUCT_COPY_FILES += \
    $(SAMBAR_BLOB)/lib/libtfa9887.so:$(TARGET_COPY_OUT_VENDOR)/lib/libtfa9887.so \
    $(SAMBAR_BLOB)/vendor/lib/libacdbloader.so:$(TARGET_COPY_OUT_VENDOR)/lib/libacdbloader.so \
    $(SAMBAR_BLOB)/vendor/lib/libacdb-fts.so:$(TARGET_COPY_OUT_VENDOR)/lib/libacdb-fts.so \
    $(SAMBAR_BLOB)/vendor/lib/libacdbrtac.so:$(TARGET_COPY_OUT_VENDOR)/lib/libacdbrtac.so \
    $(SAMBAR_BLOB)/vendor/lib/libaudcal.so:$(TARGET_COPY_OUT_VENDOR)/lib/libaudcal.so \
    $(SAMBAR_BLOB)/vendor/lib/libadiertac.so:$(TARGET_COPY_OUT_VENDOR)/lib/libadiertac.so \
    $(SAMBAR_BLOB)/vendor/lib/libdiag.so:$(TARGET_COPY_OUT_VENDOR)/lib/libdiag.so \
    /home/alpha/Documents/GitHub/android_device_yu_sambar/audio/tfa9887.cnt:$(TARGET_COPY_OUT_SYSTEM)/etc/tfa9887.cnt \
    /home/alpha/Documents/GitHub/android_device_yu_sambar/audio/acdb/Bluetooth_cal.acdb:$(TARGET_COPY_OUT_SYSTEM)/etc/acdbdata/MTP/Bluetooth_cal.acdb \
    /home/alpha/Documents/GitHub/android_device_yu_sambar/audio/acdb/General_cal.acdb:$(TARGET_COPY_OUT_SYSTEM)/etc/acdbdata/MTP/General_cal.acdb \
    /home/alpha/Documents/GitHub/android_device_yu_sambar/audio/acdb/Global_cal.acdb:$(TARGET_COPY_OUT_SYSTEM)/etc/acdbdata/MTP/Global_cal.acdb \
    /home/alpha/Documents/GitHub/android_device_yu_sambar/audio/acdb/Handset_cal.acdb:$(TARGET_COPY_OUT_SYSTEM)/etc/acdbdata/MTP/Handset_cal.acdb \
    /home/alpha/Documents/GitHub/android_device_yu_sambar/audio/acdb/Hdmi_cal.acdb:$(TARGET_COPY_OUT_SYSTEM)/etc/acdbdata/MTP/Hdmi_cal.acdb \
    /home/alpha/Documents/GitHub/android_device_yu_sambar/audio/acdb/Headset_cal.acdb:$(TARGET_COPY_OUT_SYSTEM)/etc/acdbdata/MTP/Headset_cal.acdb \
    /home/alpha/Documents/GitHub/android_device_yu_sambar/audio/acdb/Speaker_cal.acdb:$(TARGET_COPY_OUT_SYSTEM)/etc/acdbdata/MTP/Speaker_cal.acdb \
    /home/alpha/Documents/GitHub/android_device_yu_sambar/kernel-modules/tfa-stub/tfa_stub.ko:$(TARGET_COPY_OUT_VENDOR)/lib/modules/tfa_stub.ko \
    /home/alpha/Documents/GitHub/android_device_yu_sambar/audio/sambar-audio-card:$(TARGET_COPY_OUT_VENDOR)/bin/sambar-audio-card

# Bluetooth. The HIDL service is the one already declared in manifest.xml.
# A2DP stays on the legacy audio.a2dp.default module that the policy
# already loads. Headset calls are not this item. wcnss_filter and the
# 64-bit libdiag it needs are this phone's. btfw*.tlv and btnv*.bin stay
# on mmcblk0p12.
PRODUCT_PACKAGES += \
    android.hardware.bluetooth@1.0-impl \
    android.hardware.bluetooth@1.0-service \
    libbt-vendor \
    audio.a2dp.default

PRODUCT_COPY_FILES += \
    $(SAMBAR_BLOB)/bin/wcnss_filter:$(TARGET_COPY_OUT_VENDOR)/bin/wcnss_filter \
    $(SAMBAR_BLOB)/vendor/lib64/libdiag.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libdiag.so \
    /home/alpha/Documents/GitHub/android_device_yu_sambar/bluetooth/bdaddr:$(TARGET_COPY_OUT_VENDOR)/etc/bluetooth/bdaddr
