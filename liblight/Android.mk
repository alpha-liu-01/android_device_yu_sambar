# Copyright (C) 2014 The CyanogenMod Project
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

# hardware/qcom-caf/msm8994/display/liblight defines lights.msm8994.
# This CM13 HAL keeps the Yutopia LED map. Set BOARD_USE_SAMBAR_LIBLIGHT
# to build it, and stop the CAF module from defining the same name.

LOCAL_PATH:= $(call my-dir)

ifeq ($(BOARD_USE_SAMBAR_LIBLIGHT),true)

include $(CLEAR_VARS)

LOCAL_SRC_FILES := lights.c
LOCAL_MODULE_RELATIVE_PATH    := hw
LOCAL_SHARED_LIBRARIES := liblog libcutils

LOCAL_MODULE := lights.msm8994
LOCAL_MODULE_TAGS := optional

include $(BUILD_SHARED_LIBRARY)

endif
