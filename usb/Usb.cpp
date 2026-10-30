#include "Usb.h"

#include <android-base/file.h>
#include <log/log.h>

#include <unistd.h>

namespace android {
namespace hardware {
namespace usb {
namespace V1_0 {
namespace implementation {

namespace {

// This phone has no dual_role_usb, typec, or extcon node. VBUS on the
// USB charger supply stays up while the cable is in, including while the
// gadget is briefly disabled to switch functions. The android_usb state
// is only a fallback: charging turns the gadget off, so that file alone
// would look unplugged and Settings would grey the modes back out.
bool cableConnected() {
    std::string online;
    if (android::base::ReadFileToString("/sys/class/power_supply/usb/online", &online)) {
        return online.find('1') != std::string::npos;
    }
    std::string state;
    if (!android::base::ReadFileToString("/sys/class/android_usb/android0/state", &state)) {
        return false;
    }
    return state.find("CONFIGURED") != std::string::npos ||
            state.find("CONNECTED") != std::string::npos;
}

PortStatus portStatus() {
    PortStatus status;
    status.portName = "port0";
    // supportedModes must equal currentMode. UsbPortManager drops the
    // connection when a non-DRP port reports a mode outside supportedModes.
    status.supportedModes = PortMode::UFP;
    status.canChangeMode = false;
    status.canChangeDataRole = false;
    status.canChangePowerRole = false;
    if (cableConnected()) {
        status.currentMode = PortMode::UFP;
        status.currentDataRole = PortDataRole::DEVICE;
        status.currentPowerRole = PortPowerRole::SINK;
    } else {
        status.currentMode = PortMode::NONE;
        status.currentDataRole = PortDataRole::NONE;
        status.currentPowerRole = PortPowerRole::NONE;
    }
    return status;
}

}  // namespace

void Usb::publishLocked() {
    if (mCallback == nullptr) return;
    hidl_vec<PortStatus> status;
    status.resize(1);
    status[0] = portStatus();
    Return<void> ret = mCallback->notifyPortStatusChange(status, Status::SUCCESS);
    if (!ret.isOk()) {
        ALOGE("notifyPortStatusChange: %s", ret.description().c_str());
    }
}

void* pollCable(void* param) {
    Usb* usb = static_cast<Usb*>(param);
    bool last = !cableConnected();
    while (!usb->mStop.load()) {
        bool now = cableConnected();
        if (now != last) {
            last = now;
            pthread_mutex_lock(&usb->mLock);
            usb->publishLocked();
            pthread_mutex_unlock(&usb->mLock);
        }
        usleep(500000);
    }
    return nullptr;
}

Return<void> Usb::switchRole(const hidl_string& portName, const PortRole& role) {
    // Device-only port. There is no role-swap controller to program.
    if (mCallback != nullptr) {
        Return<void> ret = mCallback->notifyRoleSwitchStatus(portName, role, Status::ERROR);
        if (!ret.isOk()) {
            ALOGE("notifyRoleSwitchStatus: %s", ret.description().c_str());
        }
    }
    return Void();
}

Return<void> Usb::queryPortStatus() {
    pthread_mutex_lock(&mLock);
    publishLocked();
    pthread_mutex_unlock(&mLock);
    return Void();
}

Return<void> Usb::setCallback(const sp<IUsbCallback>& callback) {
    pthread_mutex_lock(&mLock);
    if ((mCallback == nullptr && callback == nullptr) ||
            (mCallback != nullptr && callback != nullptr)) {
        mCallback = callback;
        pthread_mutex_unlock(&mLock);
        return Void();
    }

    mCallback = callback;
    if (mCallback == nullptr) {
        mStop.store(true);
        pthread_mutex_unlock(&mLock);
        pthread_join(mPoll, nullptr);
        return Void();
    }

    mStop.store(false);
    if (pthread_create(&mPoll, nullptr, pollCable, this) != 0) {
        ALOGE("pthread_create failed");
        mCallback = nullptr;
    }
    pthread_mutex_unlock(&mLock);
    return Void();
}

Usb::Usb() {}

}  // namespace implementation
}  // namespace V1_0
}  // namespace usb
}  // namespace hardware
}  // namespace android
