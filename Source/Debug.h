#pragma once

#include <time.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <stdbool.h>

#include "SDL_events.h"

enum MessageSeverity {
        MESSAGE_FATAL,
        MESSAGE_ERROR,
        MESSAGE_WARNING,
        MESSAGE_INFORMATION,
        MESSAGE_DEBUG,
        MESSAGE_VERBOSE,
        MESSAGE_COUNT
};

#ifndef NDEBUG

#include "SDL_platform.h"

#include "Memory.h"

#define TIME_STRING_SIZE 64

static const char *const message_severity_strings[MESSAGE_COUNT] = {
        [MESSAGE_FATAL]       = "      \033[37;41mMESSAGE_FATAL\033[m",
        [MESSAGE_ERROR]       = "      \033[31mMESSAGE_ERROR\033[m",
        [MESSAGE_WARNING]     = "    \033[33mMESSAGE_WARNING\033[m",
        [MESSAGE_INFORMATION] = "\033[32mMESSAGE_INFORMATION\033[m",
        [MESSAGE_DEBUG]       = "      \033[36mMESSAGE_DEBUG\033[m",
        [MESSAGE_VERBOSE]     = "    \033[34mMESSAGE_VERBOSE\033[m"
};

static inline void send_message(const enum MessageSeverity message_severity, const char *const message, ...) {
        struct timespec time_specification;
        struct tm local_time;
        char time_string[TIME_STRING_SIZE];

#if defined(__WIN32__)
        timespec_get(&time_specification, TIME_UTC);
        localtime_s(&local_time, &time_specification.tv_sec);
#else
        timespec_get(&time_specification, TIME_UTC);
        localtime_r(&time_specification.tv_sec, &local_time);
#endif

        strftime(time_string, sizeof(time_string), "%Y-%m-%d - %I:%M:%S", &local_time);

        va_list arguments;
        va_start(arguments, message);

#if defined(__WIN32__)
        const size_t size = (size_t)_vscprintf(message, arguments) + 1ULL;
#else
        const size_t size = (size_t)vsnprintf(NULL, 0ULL, message, arguments) + 1ULL;
#endif

        char *const formatted = (char *)xmalloc(size);
        vsnprintf(formatted, size, message, arguments);

        FILE *const stream = message_severity <= MESSAGE_ERROR ? stderr : stdout;
        fprintf(stream, "%s(%s.%09ld %s): %s\n",
                message_severity_strings[message_severity],
                time_string,
                time_specification.tv_nsec,
                local_time.tm_hour >= 12 ? "PM" : "AM",
                formatted
        );

        fflush(stream);
        xfree(formatted);
        va_end(arguments);
}

void start_debug_frame_profiling(void);

void finish_debug_frame_profiling(void);

void initialize_debug_panel(void);

void terminate_debug_panel(void);

bool debug_panel_receive_event(const SDL_Event *const event);

void update_debug_panel(const double delta_time);

#else

#define send_message(...) ((void)0)

void start_debug_frame_profiling(void) {
        return;
}

void finish_debug_frame_profiling(void) {
        return;
}

void initialize_debug_panel(void) {
        return;
}

void terminate_debug_panel(void) {
        return;
}

bool debug_panel_receive_event(const SDL_Event *) {
        return false;
}

void update_debug_panel(double) {
        return;
}

#endif