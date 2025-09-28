#pragma once

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

void _assert_all_implementation(
        const char *const file,
        const int line,
        const char *const function,
        const char *const expressions,
        const bool values[],
        const size_t assertion_count
);

#define ASSERT_ALL(...)                                                                                                             \
        do {                                                                                                                        \
                const bool values[] = {__VA_ARGS__};                                                                                \
                _assert_all_implementation(__FILE__, __LINE__, __func__, #__VA_ARGS__, values, sizeof(values) / sizeof(values[0])); \
        } while (0)

void send_message(const enum MessageSeverity message_severity, const char *const message, ...);

void start_debug_frame_profiling(void);

void finish_debug_frame_profiling(void);

void initialize_debug_panel(void);

void terminate_debug_panel(void);

bool debug_panel_receive_event(const SDL_Event *const event);

void update_debug_panel(const double delta_time);

#else

#define ASSERT_ALL(...) ((void)0)

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