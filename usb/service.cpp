#include <hidl/HidlTransportSupport.h>
#include <log/log.h>

#include "Usb.h"

using android::hardware::configureRpcThreadpool;
using android::hardware::joinRpcThreadpool;
using android::hardware::usb::V1_0::IUsb;
using android::hardware::usb::V1_0::implementation::Usb;
using android::sp;

int main() {
    sp<IUsb> service = new Usb();

    configureRpcThreadpool(1, true);
    if (service->registerAsService() == android::OK) {
        ALOGI("USB HAL ready");
        joinRpcThreadpool();
    }
    ALOGE("Cannot register USB HAL");
    return 1;
}
