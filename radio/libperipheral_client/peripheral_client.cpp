/*
 * Replacement for this phone's Android 6 libperipheral_client.
 *
 * QCRIL registers for the "modem" peripheral. The stock pm-service does
 * that by opening /dev/subsys_<name>, which makes the kernel load the
 * firmware on the first open and drop it on the last close. pm-service
 * itself is an Android 6 Binder service and is not started. The fd stays
 * open for the life of the process, so the modem is not powered off.
 */
#define LOG_TAG "libperipheral_client"

#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <log/log.h>

enum pm_event {
    EVENT_PERIPH_GOING_OFFLINE = 0,
    EVENT_PERIPH_IS_OFFLINE,
    EVENT_PERIPH_GOING_ONLINE,
    EVENT_PERIPH_IS_ONLINE,
    EVENT_PERIPH_NOT_SUPPORTED,
};

typedef void (*pm_client_notifier)(void* client_data, enum pm_event event);

struct pm_client {
    pm_client_notifier notifier;
    void* client_data;
    char peripheral[32];
    char client[32];
    int fd;
    bool connected;
};

static void* connect_thread(void* arg) {
    pm_client* c = static_cast<pm_client*>(arg);
    char path[64];
    snprintf(path, sizeof(path), "/dev/subsys_%s", c->peripheral);

    if (c->notifier) c->notifier(c->client_data, EVENT_PERIPH_GOING_ONLINE);

    c->fd = open(path, O_RDONLY);
    if (c->fd < 0) {
        ALOGE("%s: open(%s) failed: %s", c->client, path, strerror(errno));
        if (c->notifier) c->notifier(c->client_data, EVENT_PERIPH_IS_OFFLINE);
        return nullptr;
    }
    ALOGI("%s: %s is online", c->client, c->peripheral);
    if (c->notifier) c->notifier(c->client_data, EVENT_PERIPH_IS_ONLINE);
    return nullptr;
}

extern "C" {

int pm_client_register(pm_client_notifier notifier, void* client_data, const char* peripheral,
                       const char* client, enum pm_event* state, void** handle) {
    if (!peripheral || !client || !handle) return -1;
    pm_client* c = static_cast<pm_client*>(calloc(1, sizeof(*c)));
    if (!c) return -1;
    c->notifier = notifier;
    c->client_data = client_data;
    c->fd = -1;
    strlcpy(c->peripheral, peripheral, sizeof(c->peripheral));
    strlcpy(c->client, client, sizeof(c->client));
    if (state) *state = EVENT_PERIPH_IS_OFFLINE;
    *handle = c;
    ALOGI("%s registered for %s", c->client, c->peripheral);
    return 0;
}

int pm_client_connect(void* handle) {
    pm_client* c = static_cast<pm_client*>(handle);
    if (!c) return -1;
    if (c->connected) return 0;
    c->connected = true;
    pthread_t t;
    if (pthread_create(&t, nullptr, connect_thread, c) != 0) {
        c->connected = false;
        return -1;
    }
    pthread_detach(t);
    return 0;
}

int pm_client_disconnect(void* /*handle*/) {
    return 0;
}

int pm_client_unregister(void* /*handle*/) {
    return 0;
}

int pm_client_event_acknowledge(void* /*handle*/, enum pm_event /*event*/) {
    return 0;
}

}  // extern "C"

/*
 * libril-qc-qmi-1.so still imports this Android 6 libmedia symbol.
 * libaudioclient has setParameters/getParameters; this callback does not.
 */
namespace android {
class AudioSystem {
public:
    static void setErrorCallback(void (*cb)(int));
};
void AudioSystem::setErrorCallback(void (*)(int)) {}
}  // namespace android
