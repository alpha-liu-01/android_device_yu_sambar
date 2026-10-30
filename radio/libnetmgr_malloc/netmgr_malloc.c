/*
 * Allocator for this phone's Android 6 netmgrd.
 *
 * netmgrd frees the same chunk twice while it brings rmnet_data up.
 * Android 11 Scudo aborts the process, init restarts it, and the data
 * call is torn down before an address is installed. This allocator is
 * loaded only into netmgrd. A second free of a block it owns is ignored.
 * A pointer it does not own is passed to the libc allocator.
 */
#define _GNU_SOURCE

#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#define MAGIC_LIVE 0x4e314c49564531ULL
#define MAGIC_DEAD 0x4e314445414431ULL
#define HDR 32
#define MAX_SMALL 8192
#define NCLASS ((MAX_SMALL / 16) + 1)

struct blk {
    uint64_t magic;
    uint64_t size;
    struct blk *next;
    uint64_t reserved;
};

static int held;
static int announced;
static struct blk *small_free[NCLASS];
static struct blk *large_free;
static char *slab;
static size_t slab_used;
static size_t slab_size;

static void enter(void) {
    while (__sync_lock_test_and_set(&held, 1)) {
        while (held) {
        }
    }
}

static void leave(void) {
    __sync_lock_release(&held);
}

static void announce(void) {
    int fd;

    if (announced) {
        return;
    }
    announced = 1;
    fd = open("/dev/kmsg", O_WRONLY | O_CLOEXEC);
    if (fd < 0) {
        return;
    }
    {
        static const char msg[] = "sambar: netmgr malloc shim loaded\n";
        write(fd, msg, sizeof(msg) - 1);
    }
    close(fd);
}

static void *map_pages(size_t bytes) {
    void *p;

    p = mmap(NULL, bytes, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (p == MAP_FAILED) {
        return NULL;
    }
    return p;
}

static size_t round_up(size_t size) {
    if (size < 16) {
        size = 16;
    }
    return (size + 15) & ~(size_t)15;
}

static struct blk *hdr_of(void *ptr) {
    return (struct blk *)((char *)ptr - HDR);
}

static int owned(struct blk *b) {
    return b->magic == MAGIC_LIVE || b->magic == MAGIC_DEAD;
}

static void *fresh_small(size_t cap) {
    struct blk *b;
    size_t need;

    need = HDR + cap;
    if (slab == NULL || slab_used + need > slab_size) {
        slab_size = 1024 * 1024;
        slab = map_pages(slab_size);
        slab_used = 0;
        if (slab == NULL) {
            return NULL;
        }
    }
    b = (struct blk *)(slab + slab_used);
    slab_used += need;
    b->magic = MAGIC_LIVE;
    b->size = cap;
    b->next = NULL;
    return (char *)b + HDR;
}

static void *fresh_large(size_t cap) {
    size_t bytes;
    struct blk *b;

    bytes = (HDR + cap + 4095) & ~(size_t)4095;
    b = map_pages(bytes);
    if (b == NULL) {
        return NULL;
    }
    b->magic = MAGIC_LIVE;
    b->size = bytes - HDR;
    b->next = NULL;
    return (char *)b + HDR;
}

static void *alloc_unlocked(size_t size) {
    size_t cap;
    int cls;
    struct blk *b;
    struct blk **prev;

    announce();
    if (size > (SIZE_MAX / 2)) {
        errno = ENOMEM;
        return NULL;
    }
    cap = round_up(size);
    if (cap <= MAX_SMALL) {
        cls = (int)(cap / 16);
        b = small_free[cls];
        if (b != NULL) {
            small_free[cls] = b->next;
            b->next = NULL;
            b->magic = MAGIC_LIVE;
            return (char *)b + HDR;
        }
        return fresh_small(cap);
    }
    prev = &large_free;
    for (b = large_free; b != NULL; b = b->next) {
        if (b->size >= cap) {
            *prev = b->next;
            b->next = NULL;
            b->magic = MAGIC_LIVE;
            return (char *)b + HDR;
        }
        prev = &b->next;
    }
    return fresh_large(cap);
}

void *malloc(size_t size) {
    void *p;

    enter();
    p = alloc_unlocked(size);
    leave();
    return p;
}

void *calloc(size_t n, size_t size) {
    void *p;
    size_t bytes;

    if (n != 0 && size > (SIZE_MAX / n)) {
        errno = ENOMEM;
        return NULL;
    }
    bytes = n * size;
    p = malloc(bytes);
    if (p != NULL && bytes != 0) {
        memset(p, 0, bytes);
    }
    return p;
}

void free(void *ptr) {
    struct blk *b;
    int cls;
    static void (*real_free)(void *) = NULL;

    if (ptr == NULL) {
        return;
    }
    b = hdr_of(ptr);
    if (!owned(b)) {
        if (real_free == NULL) {
            real_free = (void (*)(void *))dlsym(RTLD_NEXT, "free");
        }
        if (real_free != NULL) {
            real_free(ptr);
        }
        return;
    }
    if (b->magic == MAGIC_DEAD) {
        return;
    }
    enter();
    if (b->magic == MAGIC_LIVE) {
        b->magic = MAGIC_DEAD;
        if (b->size <= MAX_SMALL) {
            cls = (int)(b->size / 16);
            b->next = small_free[cls];
            small_free[cls] = b;
        } else {
            b->next = large_free;
            large_free = b;
        }
    }
    leave();
}

void *realloc(void *ptr, size_t size) {
    struct blk *b;
    void *p;
    size_t keep;

    if (ptr == NULL) {
        return malloc(size);
    }
    if (size == 0) {
        free(ptr);
        return NULL;
    }
    b = hdr_of(ptr);
    if (!owned(b) || b->magic != MAGIC_LIVE) {
        errno = EINVAL;
        return NULL;
    }
    if (size <= b->size) {
        return ptr;
    }
    p = malloc(size);
    if (p == NULL) {
        return NULL;
    }
    keep = b->size;
    if (keep > size) {
        keep = size;
    }
    memcpy(p, ptr, keep);
    free(ptr);
    return p;
}

void *memalign(size_t align, size_t size) {
    size_t cap;
    size_t bytes;
    char *base;
    uintptr_t aligned;
    struct blk *b;

    if (align < 32) {
        align = 32;
    }
    if ((align & (align - 1)) != 0) {
        errno = EINVAL;
        return NULL;
    }
    if (align == 32) {
        return malloc(size);
    }
    cap = round_up(size);
    bytes = HDR + cap + align + 4096;
    bytes = (bytes + 4095) & ~(size_t)4095;
    enter();
    announce();
    base = map_pages(bytes);
    if (base == NULL) {
        leave();
        errno = ENOMEM;
        return NULL;
    }
    aligned = ((uintptr_t)base + HDR + align - 1) & ~(uintptr_t)(align - 1);
    b = (struct blk *)(aligned - HDR);
    b->magic = MAGIC_LIVE;
    b->size = cap;
    b->next = NULL;
    leave();
    return (void *)aligned;
}

int posix_memalign(void **memptr, size_t align, size_t size) {
    void *p;

    if (memptr == NULL) {
        return EINVAL;
    }
    p = memalign(align, size);
    if (p == NULL) {
        return errno ? errno : ENOMEM;
    }
    *memptr = p;
    return 0;
}

void *aligned_alloc(size_t align, size_t size) {
    return memalign(align, size);
}

size_t malloc_usable_size(const void *ptr) {
    struct blk *b;

    if (ptr == NULL) {
        return 0;
    }
    b = hdr_of((void *)ptr);
    if (b->magic != MAGIC_LIVE) {
        return 0;
    }
    return (size_t)b->size;
}

void *valloc(size_t size) {
    return memalign(4096, size);
}

void *pvalloc(size_t size) {
    size_t page = 4096;
    size_t rounded = (size + page - 1) & ~(page - 1);
    return memalign(page, rounded ? rounded : page);
}
