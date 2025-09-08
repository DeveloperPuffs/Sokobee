#pragma once

#include <stdlib.h>
#include <string.h>

#ifndef NDEBUG

void flush_memory_leaks(void);

void *track_malloc(const size_t size, const char *const file, const size_t line);

void *track_calloc(const size_t count, const size_t size, const char *const file, const size_t line);

void *track_realloc(void *const pointer, const size_t size, const char *const file, const size_t line);

char *track_strdup(const char *const string, const char *const file, const size_t line);

void  track_free(void *const pointer, const char *const file, const size_t line);

#define xmalloc(size)           track_malloc((size),              __FILE__, (size_t)__LINE__)
#define xcalloc(count, size)    track_calloc((count), (size),     __FILE__, (size_t)__LINE__)
#define xrealloc(pointer, size) track_realloc((pointer), (size),  __FILE__, (size_t)__LINE__)
#define xstrdup(string)         track_strdup((string),            __FILE__, (size_t)__LINE__)
#define xfree(pointer)          track_free((pointer),             __FILE__, (size_t)__LINE__)

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
                exit(EXIT_FAILURE);
        }

        return allocated;
}

static inline void *xcalloc(const size_t count, const size_t size) {
        void *const allocated = calloc(count, size);
        if (allocated == NULL) {
                exit(EXIT_FAILURE);
        }

        return allocated;
}

static inline void *xrealloc(void *const pointer, const size_t size) {
        void *const reallocated = realloc(pointer, size);
        if (reallocated == NULL) {
                exit(EXIT_FAILURE);
        }

        return reallocated;
}

static inline char *xstrdup(const char *const string) {
        void *const duplicated = STRDUP(string);
        if (duplicated == NULL) {
                exit(EXIT_FAILURE);
        }

        return duplicated;
}

static inline void xfree(void *const pointer) {
        free(pointer);
}

#endif