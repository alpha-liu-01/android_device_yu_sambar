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
