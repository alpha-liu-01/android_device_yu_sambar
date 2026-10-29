/*
 * Non-A/B boot control. This phone has one slot and the misc partition
 * is not an A/B bootloader message. Do not write it: the kernel bootlog
 * lives there, and this LK does not understand slot metadata.
 *
 * vold's first fstrim calls IBootControl::getService() while holding the
 * volume lock. The 1.0 service is already in the image and waits until
 * this module loads. isSlotMarkedSuccessful() must be true so checkpoint
 * stays off.
 */

#include <errno.h>
#include <hardware/boot_control.h>
#include <hardware/hardware.h>

static void boot_init(struct boot_control_module *module) {
    (void)module;
}

static unsigned boot_get_number_slots(struct boot_control_module *module) {
    (void)module;
    return 1;
}

static unsigned boot_get_current_slot(struct boot_control_module *module) {
    (void)module;
    return 0;
}

static int boot_mark_successful(struct boot_control_module *module) {
    (void)module;
    return 0;
}

static int boot_set_active(struct boot_control_module *module, unsigned slot) {
    (void)module;
    (void)slot;
    return -EINVAL;
}

static int boot_set_unbootable(struct boot_control_module *module, unsigned slot) {
    (void)module;
    (void)slot;
    return -EINVAL;
}

static int boot_is_bootable(struct boot_control_module *module, unsigned slot) {
    (void)module;
    return slot == 0 ? 1 : -EINVAL;
}

static const char *boot_get_suffix(struct boot_control_module *module, unsigned slot) {
    (void)module;
    return slot == 0 ? "" : NULL;
}

static int boot_is_successful(struct boot_control_module *module, unsigned slot) {
    (void)module;
    return slot == 0 ? 1 : -EINVAL;
}

static struct hw_module_methods_t boot_module_methods = {
    .open = NULL,
};

boot_control_module_t HAL_MODULE_INFO_SYM = {
    .common = {
        .tag = HARDWARE_MODULE_TAG,
        .module_api_version = BOOT_CONTROL_MODULE_API_VERSION_0_1,
        .hal_api_version = HARDWARE_HAL_API_VERSION,
        .id = BOOT_CONTROL_HARDWARE_MODULE_ID,
        .name = "sambar non-A/B bootctrl",
        .author = "sambar",
        .methods = &boot_module_methods,
    },
    .init = boot_init,
    .getNumberSlots = boot_get_number_slots,
    .getCurrentSlot = boot_get_current_slot,
    .markBootSuccessful = boot_mark_successful,
    .setActiveBootSlot = boot_set_active,
    .setSlotAsUnbootable = boot_set_unbootable,
    .isSlotBootable = boot_is_bootable,
    .getSuffix = boot_get_suffix,
    .isSlotMarkedSuccessful = boot_is_successful,
};
