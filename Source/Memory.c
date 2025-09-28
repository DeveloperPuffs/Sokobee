#include "Memory.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "Debug.h"
#include "Defines.h"

#ifndef NDEBUG

struct AllocationInformation {
        void *pointer;
        size_t size;
        const char *file;
        int line;
        const char *function;
        struct AllocationInformation *next;
};

static struct AllocationInformation *allocation_informations = NULL;
static size_t active_allocations = 0ULL;
static size_t active_bytes = 0ULL;
static size_t peak_bytes = 0ULL;

void flush_memory_leaks(void) {
        if (allocation_informations == NULL) {
                send_message(MESSAGE_INFORMATION, "flush_memory_leaks(): No leaked memory");
                return;
        }

        send_message(MESSAGE_ERROR, "flush_memory_leaks(): %zu active allocations (totalling %zu bytes) leaked", active_allocations, active_bytes);
        for (struct AllocationInformation *current_allocation_information = allocation_informations; current_allocation_information != NULL; current_allocation_information = current_allocation_information->next) {
                send_message(
                        MESSAGE_ERROR, 
                        "flush_memory_leaks(): %p (%zu bytes) allocated at %s:%d in %s()",
                        current_allocation_information->pointer,
                        current_allocation_information->size,
                        current_allocation_information->file,
                        current_allocation_information->line,
                        current_allocation_information->function
                );
        }
}

static void track_allocation(void *const pointer, const size_t size, const char *const file, const int line, const char *const function) {
        struct AllocationInformation *const allocation_information = (struct AllocationInformation *)malloc(sizeof(struct AllocationInformation));
        if (allocation_information == NULL) {
                send_message(MESSAGE_ERROR, "Failed to track allocation for %p (%zu bytes) allocated at %s:%d in %s()", pointer, size, file, line, function);
                abort();
        }

        allocation_information->pointer = pointer;
        allocation_information->size = size;
        allocation_information->file = file;
        allocation_information->line = line;
        allocation_information->function = function;
        allocation_information->next = allocation_informations;
        allocation_informations = allocation_information;

        ++active_allocations;
        active_bytes += size;

        if (active_bytes > peak_bytes) {
                peak_bytes = active_bytes;
                if (peak_bytes > SAFE_MEMORY_LIMIT_BYTES) {
                        send_message(
                                MESSAGE_WARNING,
                                "Tracked memory peaked at %zu bytes due to allocation for %p (%zu bytes) allocated at %s:%d in %s()",
                                peak_bytes, pointer, size, file, line, function
                        );
                }
        }
}

static void remove_allocation(void *const pointer, const char *const file, const int line, const char *const function) {
        struct AllocationInformation **current_allocation_information = &allocation_informations;

        while (*current_allocation_information != NULL) {
                if ((*current_allocation_information)->pointer == pointer) {
                        struct AllocationInformation *removed_allocation_information = *current_allocation_information;

                        active_bytes -= removed_allocation_information->size;
                        --active_allocations;

                        *current_allocation_information = removed_allocation_information->next;
                        free(removed_allocation_information);
                        return;
                }

                current_allocation_information = &(*current_allocation_information)->next;
        }

        send_message(MESSAGE_WARNING, "xfree(%p): Pointer is unrecognized at %s:%d in %s()", pointer, file, line, function);
}

void *track_malloc(const size_t size, const char *const file, const int line, const char *const function) {
        void *const allocated = malloc(size);
        if (allocated == NULL) {
                send_message(MESSAGE_ERROR, "xmalloc(%zu): Allocation failed at %s:%d in %s()", size, file, line, function);
                abort();
        }

        track_allocation(allocated, size, file, line, function);
        return allocated;
}

void *track_calloc(const size_t count, const size_t size, const char *const file, const int line, const char *const function) {
        void *const allocated = calloc(count, size);
        if (allocated == NULL) {
                send_message(MESSAGE_ERROR, "xcalloc(%zu, %zu): Allocation failed at %s:%d in %s()", count, size, file, line, function);
                abort();
        }

        track_allocation(allocated, size, file, line, function);
        return allocated;
}

void *track_realloc(void *const pointer, const size_t size, const char *const file, const int line, const char *const function) {
        if (pointer != NULL) {
                remove_allocation(pointer, file, line, function);
        }

        void *const reallocated = realloc(pointer, size);
        if (reallocated == NULL) {
                send_message(MESSAGE_ERROR, "xrealloc(%p, %zu): Allocation failed at %s:%d in %s()", pointer, size, file, line, function);
                abort();
        }

        track_allocation(reallocated, size, file, line, function);
        return reallocated;
}

char *track_strdup(const char *const string, const char *const file, const int line, const char *const function) {
        char *const duplicated = strdup(string);
        if (duplicated == NULL) {
                send_message(MESSAGE_ERROR, "xstrdup(%s): Allocation failed at %s:%d in %s()", string, file, line, function);
                abort();
        }

        // NOTE: The size here is just the size of the pointer, but it should be fine
        track_allocation(duplicated, sizeof(duplicated), file, line, function);
        return duplicated;
}

void track_free(void *const pointer, const char *const file, const int line, const char *const function) {
        if (pointer == NULL) {
                return;
        }

        remove_allocation(pointer, file, line, function);
        free(pointer);
}

#endif