#pragma once

#include <stdlib.h>
#include <string.h>

#ifndef NDEBUG

void flush_memory_leaks(void);

void *track_malloc(const size_t size, const char *const file, const int line, const char *const function);

void *track_calloc(const size_t count, const size_t size, const char *const file, const int line, const char *const function);

void *track_realloc(void *const pointer, const size_t size, const char *const file, const int line, const char *const function);

char *track_strdup(const char *const string, const char *const file, const int line, const char *const function);

void  track_free(void *const pointer, const char *const file, const int line, const char *const function);

#define xmalloc(size)           track_malloc((size),              __FILE__, __LINE__, __func__)
#define xcalloc(count, size)    track_calloc((count), (size),     __FILE__, __LINE__, __func__)
#define xrealloc(pointer, size) track_realloc((pointer), (size),  __FILE__, __LINE__, __func__)
#define xstrdup(string)         track_strdup((string),            __FILE__, __LINE__, __func__)
#define xfree(pointer)          track_free((pointer),             __FILE__, __LINE__, __func__)

#else

#ifdef _WIN32
#define STRDUP _strdup
#else
#define STRDUP strdup
#endif

static inline void flush_memory_leaks(void) {
        return;
}

static inline void *xmalloc(const size_t size) {
        void *const allocated = malloc(size);
        if (allocated == NULL) {
                abort();
        }

        return allocated;
}

static inline void *xcalloc(const size_t count, const size_t size) {
        void *const allocated = calloc(count, size);
        if (allocated == NULL) {
                abort();
        }

        return allocated;
}

static inline void *xrealloc(void *const pointer, const size_t size) {
        void *const reallocated = realloc(pointer, size);
        if (reallocated == NULL) {
                abort();
        }

        return reallocated;
}

static inline char *xstrdup(const char *const string) {
        void *const duplicated = STRDUP(string);
        if (duplicated == NULL) {
                abort();
        }

        return duplicated;
}

static inline void xfree(void *const pointer) {
        free(pointer);
}

#endif