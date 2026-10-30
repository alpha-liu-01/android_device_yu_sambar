#/******************************************************************************
#*@file Android.mk
#*brief Rules for compiling the source files
#*******************************************************************************/

src_java_ims := src/org/codeaurora/ims
src_java_ims += src/com/qualcomm/ims/vt
src_java_ims += src/com/qualcomm/ims/utils
src_proto := src

LOCAL_PATH:= $(call my-dir)

# ==========================================================================
# Build the service
include $(CLEAR_VARS)

LOCAL_MODULE_TAGS := optional

# Not "ims": device/gree/g0215d already owns that Soong module name.
# The manifest package stays org.codeaurora.ims. Privileged and platform-signed
# so it can share android.uid.phone with the dialer process.
LOCAL_PACKAGE_NAME := SambarIms
LOCAL_PRIVILEGED_MODULE := true
LOCAL_CERTIFICATE := platform
LOCAL_PROGUARD_ENABLED := disabled
LOCAL_MODULE_OWNER := qti
LOCAL_JAVA_LIBRARIES := telephony-common ims-common voip-common
LOCAL_STATIC_JAVA_LIBRARIES := ims-ext-common
LOCAL_DEX_PREOPT := false
LOCAL_JNI_SHARED_LIBRARIES := libimsmedia_jni libimscamera_jni
LOCAL_REQUIRED_MODULES := libimsmedia_jni libimscamera_jni

LOCAL_PRIVATE_PLATFORM_APIS := true

LOCAL_PROTOC_OPTIMIZE_TYPE := micro

LOCAL_SRC_FILES := $(call all-java-files-under, $(src_java_ims)) \
    $(call all-proto-files-under, $(src_proto))

include $(BUILD_PACKAGE)

# Settings and the qti gid map are not needed for registration.
include $(LOCAL_PATH)/jni/Android.mk

# ==========================================================================

