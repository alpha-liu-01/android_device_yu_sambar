#
# Copyright (C) 2015 The CyanogenMod Project
# Copyright (C) 2017-2018 The LineageOS Project
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

DEVICE_PATH := device/yu/sambar

TARGET_OTA_ASSERT_DEVICE := sambar,YU5050

# Bootloader
TARGET_BOOTLOADER_BOARD_NAME := MSM8994
TARGET_NO_BOOTLOADER := true

# Platform
TARGET_BOARD_PLATFORM := msm8994
TARGET_BOARD_PLATFORM_GPU := qcom-adreno430
TARGET_BOARD_INFO_FILE := $(DEVICE_PATH)/board-info.txt

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a53

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a53

TARGET_USES_64_BIT_BINDER := true

# Kernel
# aboot sambar-12 reads a separate QCDT. Do not append the DTB to Image.gz.
BOARD_KERNEL_CMDLINE := console=ttyHSL0,115200,n8 androidboot.console=ttyHSL0 androidboot.hardware=qcom user_debug=31 msm_rtb.filter=0x37 ehci-hcd.park=3 lpm_levels.sleep_disabled=1 boot_cpus=0-5 loop.max_part=7 androidboot.selinux=permissive ignore_loglevel loglevel=8 sambar.bootlog=1
BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_TAGS_OFFSET := 0x00000100
# Decompressed Image ends near 0x12558d0 and overwrites a ramdisk at 0x01000000.
# This tree's boot recipe does not pass BOARD_RAMDISK_OFFSET to mkbootimg.
BOARD_RAMDISK_OFFSET := 0x02000000
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_KERNEL_IMAGE_NAME := Image.gz
BOARD_KERNEL_SEPARATED_DT := true
BOARD_DTBTOOL_ARGS := -2
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
TARGET_KERNEL_SOURCE := kernel/oneplus/msm8994
TARGET_KERNEL_CONFIG := sambar_defconfig
# wlan.ko must stay a module. The 2016 board does not boot with it built in.
NEED_KERNEL_MODULE_SYSTEM := true

# Display
TARGET_SCREEN_DENSITY := 560
TARGET_ADDITIONAL_GRALLOC_10_USAGE_BITS := 0x02000000U
TARGET_USES_ION := true
TARGET_USES_C2D_COMPOSITION := true
TARGET_USES_HWC2 := true
TARGET_DISABLE_POSTRENDER_CLEANUP := true

# HIDL
DEVICE_MANIFEST_FILE := $(DEVICE_PATH)/manifest.xml
DEVICE_MATRIX_FILE := $(DEVICE_PATH)/compatibility_matrix.xml

# Partitions (phase 0: system 6291456 sectors, userdata 51600416 sectors)
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 67108864
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := f2fs
BOARD_CACHEIMAGE_PARTITION_SIZE := 268435456
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 3221225472
BOARD_USERDATAIMAGE_PARTITION_SIZE := 26419412992
BOARD_FLASH_BLOCK_SIZE := 131072
BOARD_ROOT_EXTRA_FOLDERS := firmware bt_firmware persist
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# Legacy 3.10 kernel on Android 11
TARGET_HAS_MEMFD_BACKPORT := true

# QCOM
BOARD_USES_QCOM_HARDWARE := true
# Builds audio.primary.msm8994 from hardware/qcom-caf/msm8994.
BOARD_USES_ALSA_AUDIO := true
# QCRIL starts the voice session with vsid 0x11C05000. Without this the
# HAL ignores call_state and opens the old CS-Voice device instead.
AUDIO_FEATURE_ENABLED_MULTI_VOICE_SESSIONS := true

# SELinux
include device/qcom/sepolicy-legacy/sepolicy.mk
# Only the label for /bt_firmware. The CM13 .te files next to this are
# not Android 11 vendor policy, and the system image will not build
# without this path in file_contexts.
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# Recovery sources in this tree are TWRP. Phase 1 does not build a new recovery
# image; Soong still configures the theme while generating build.ninja.
TW_THEME := portrait_hdpi
SOONG_CONFIG_NAMESPACES += makeVarsPlugin
SOONG_CONFIG_makeVarsPlugin += TW_THEME
SOONG_CONFIG_makeVarsPlugin_TW_THEME := portrait_hdpi
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.qcom

# wlan.ko stays a module. Built-in CONFIG_QCA_CLD_WLAN=y does not boot
# this board. The qcwcn HAL loads the module and the HIDL supplicant
# associates. Firmware is this phone's /firmware/image, not a copy.
BOARD_HAS_QCOM_WLAN := true
BOARD_HAS_QCOM_WLAN_SDK := true
BOARD_WLAN_DEVICE := qcwcn
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_$(BOARD_WLAN_DEVICE)
BOARD_HOSTAPD_DRIVER := NL80211
BOARD_HOSTAPD_PRIVATE_LIB := lib_driver_cmd_$(BOARD_WLAN_DEVICE)
WPA_SUPPLICANT_VERSION := VER_0_8_X
HOSTAPD_VERSION := VER_0_8_X
WIFI_DRIVER_MODULE_PATH := "/system/lib/modules/wlan.ko"
WIFI_DRIVER_MODULE_NAME := "wlan"
# fwpath is 0644 root. The HAL runs as wifi and cannot write it.
# insmod already brings up wlan0 in STA, so do not set WIFI_DRIVER_FW_PATH_*.
WIFI_HIDL_UNIFIED_SUPPLICANT_SERVICE_RC_ENTRY := true
WIFI_AVOID_IFACE_RESET_MAC_CHANGE := true

# QCA Rome on /dev/ttyHS0. libbt-vendor reads the chip version and picks
# btfw30.tlv or btfw32.tlv from this phone's /bt_firmware. That partition
# is already mounted; nothing here writes it. This phone's wcnss_filter
# watches the unprefixed wc_transport.* properties.
BOARD_HAVE_BLUETOOTH := true
BOARD_HAVE_BLUETOOTH_QCOM := true
BOARD_HAS_QCA_BT_ROME := true
QCOM_BT_USE_OLD_WCNSS_FILTER := true

TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop
