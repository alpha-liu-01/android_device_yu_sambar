#ifndef ANDROID_HARDWARE_USB_V1_0_USB_H
#define ANDROID_HARDWARE_USB_V1_0_USB_H

#include <android/hardware/usb/1.0/IUsb.h>
#include <hidl/Status.h>

#include <atomic>
#include <pthread.h>

namespace android {
namespace hardware {
namespace usb {
namespace V1_0 {
namespace implementation {

using ::android::hardware::Return;
using ::android::hardware::Void;
using ::android::hardware::usb::V1_0::IUsb;
using ::android::hardware::usb::V1_0::IUsbCallback;
using ::android::hardware::usb::V1_0::PortRole;
using ::android::hardware::usb::V1_0::PortStatus;
using ::android::sp;

struct Usb : public IUsb {
    Usb();
    Return<void> switchRole(const hidl_string& portName, const PortRole& role) override;
    Return<void> setCallback(const sp<IUsbCallback>& callback) override;
    Return<void> queryPortStatus() override;

    void publishLocked();

    sp<IUsbCallback> mCallback;
    pthread_mutex_t mLock = PTHREAD_MUTEX_INITIALIZER;
    std::atomic<bool> mStop{false};

private:
    pthread_t mPoll;
};

}  // namespace implementation
}  // namespace V1_0
}  // namespace usb
}  // namespace hardware
}  // namespace android

#endif
