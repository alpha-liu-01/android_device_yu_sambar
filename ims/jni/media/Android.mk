LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_PRELINK_MODULE := false

LOCAL_SRC_FILES:= \
    jni_main.cpp \
    ims_media_jni.cpp \


LOCAL_C_INCLUDES += \
    $(JNI_H_INCLUDE) \

LOCAL_SHARED_LIBRARIES := \
    libnativehelper \
    libcutils \
    libutils  \
    libdl \
    libgui \
    libbinder \


LOCAL_CFLAGS += -O0 -g -Wno-unused-variable -Wno-unused-parameter
LOCAL_SHARED_LIBRARIES += liblog

LOCAL_MODULE := libimsmedia_jni
LOCAL_MULTILIB := 64
LOCAL_MODULE_OWNER := qti
LOCAL_MODULE_TAGS := optional
LOCAL_PROGUARD_ENABLED := disabled

include $(BUILD_SHARED_LIBRARY)

