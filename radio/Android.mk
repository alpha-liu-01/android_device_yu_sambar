LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := libperipheral_client
LOCAL_VENDOR_MODULE := true
LOCAL_MULTILIB := 64
LOCAL_SRC_FILES := libperipheral_client/peripheral_client.cpp
LOCAL_SHARED_LIBRARIES := liblog
LOCAL_CFLAGS := -Wall -Wno-unused-parameter
include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)
LOCAL_MODULE := libnetmgr_malloc
LOCAL_VENDOR_MODULE := true
LOCAL_MULTILIB := 64
LOCAL_SRC_FILES := libnetmgr_malloc/netmgr_malloc.c
LOCAL_SHARED_LIBRARIES := libdl
LOCAL_CFLAGS := -Wall -fno-builtin
include $(BUILD_SHARED_LIBRARY)
