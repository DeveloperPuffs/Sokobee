#pragma once

#include <stdio.h>
#include <stdbool.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <stdint.h>
#include <errno.h>
#include <math.h>

#include "Memory.h"
#include "Debug.h"

#define WINDOW_TITLE "Sokobee"

#define INITIAL_WINDOW_WIDTH 1280

#define INITIAL_WINDOW_HEIGHT 720

#define MINIMUM_WINDOW_WIDTH 800

#define MINIMUM_WINDOW_HEIGHT 600

#define WINDOW_MINIMIZED_THROTTLE 100

#define RENDERER_BACKGROUND_COLOR 0, 0, 0, 255

#define MISSING_TEXTURE_WIDTH 64

#define MISSING_TEXTURE_HEIGHT 64

#define MISSING_TEXTURE_TILE_SIZE 16

#define MISSING_TEXTURE_COLOR_1 (255 << 24) | (  0 << 16) | (255 << 8) | 255 // Magenta

#define MISSING_TEXTURE_COLOR_2 (  0 << 24) | (  0 << 16) | (  0 << 8) | 255 // Black

#define INITIAL_VERTEX_BUFFER_CAPACITY 1024

#define INITIAL_INDEX_BUFFER_CAPACITY 2048

#define GEOMETRY_SEGMENT_LENGTH (4.0f)

#define LEVEL_DIMENSION_LIMIT 20

#define NULL_X1 NULL

#define NULL_X2 NULL, NULL

#define NULL_X3 NULL, NULL, NULL

#define NULL_X4 NULL, NULL, NULL, NULL

#define NULL_X5 NULL, NULL, NULL, NULL, NULL

#define COLOR_BLACK          0,   0,   0

#define COLOR_WHITE        255, 255, 255

#define COLOR_YELLOW       240, 170,  35

#define COLOR_LIGHT_YELLOW 255, 220, 120

#define COLOR_GOLD         190, 140,  35

#define COLOR_HONEY        255, 140,   0

#define COLOR_BROWN         50,  35,  15

#define COLOR_DARK_BROWN    35,  20,   0

#define COLOR_OPAQUE        255

#define COLOR_TRANSPARENT   0

// If the two macros are actual color macros defined above, the generated expression will most
// likely be constant-folded when compiling, evaluating to a single 'uint8_t'
#define COLOR_COMPONENT(COLOR_MACRO, OPACITY_MACRO, component_index) \
        ((uint8_t[]){COLOR_MACRO, OPACITY_MACRO})[(component_index)]

#define Z_INDEX_BLOCK  0

#define Z_INDEX_PLAYER 1

#define LEVEL_DATA_ENTITY_STRIDE 5

#define LEVEL_DATA_JOINT_STRIDE 3

// 100 MB of tracked memory
#define SAFE_MEMORY_LIMIT_BYTES 1e8

#define SAFE_ASSIGNMENT(pointer, value)     \
        do {                                \
                if ((pointer) != NULL) {    \
                        *(pointer) = value; \
                }                           \
        } while (0)

#define SWAP_VALUES(type, a, b)       \
        do {                          \
                type temporary = (a); \
                (a) = (b);            \
                (b) = temporary;      \
        } while (0)

// ================================================================================================
// File IO
// ================================================================================================

static inline char *load_text_file(const char *const path) {
        FILE *const file = fopen(path, "rb");
        if (file == NULL) {
                send_message(MESSAGE_ERROR, "Failed to load text file \"%s\": %s", path, strerror(errno));
                return NULL;
        }

        fseek(file, 0L, SEEK_END);
        const size_t size = (size_t)ftell(file);
        rewind(file);

        char *const buffer = (char *)xmalloc(size + 1ULL);
        if (fread(buffer, 1ULL, size, file) != size) {
                send_message(MESSAGE_ERROR, "Failed to read text file \"%s\": %s", path, strerror(errno));
                xfree(buffer);
                fclose(file);
                return NULL;
        }

        buffer[size] = '\0';
        fclose(file);

        return buffer;
}

// ================================================================================================
// Math Helpers
// ================================================================================================

#define MINIMUM_VALUE(a, b) \
        (a < b ? a : b)

#define MAXIMUM_VALUE(a, b) \
        (a > b ? a : b)

#define CLAMPED_VALUE(value, minimum, maximum) \
        (value < minimum ? minimum : (value > maximum ? maximum : value))

#define RANDOM_INTEGER(minimum, maximum) \
        ((size_t)minimum + (size_t)rand() % ((size_t)maximum - (size_t)minimum + 1ULL))

#define RANDOM_NUMBER(minimum, maximum) \
        ((size_t)minimum + ((float)rand() / (float)RAND_MAX) * ((size_t)maximum - (size_t)minimum))

#define ROTATE_POINT(field_x, field_y, pivot_x, pivot_y, rotation)                               \
        do {                                                                                     \
                if ((rotation) != 0.0f && !((field_x) == (pivot_x) && (field_y) == (pivot_y))) { \
                        const float sin = sinf(rotation);                                        \
                        const float cos = cosf(rotation);                                        \
                        const float x = (field_x) - (pivot_x);                                   \
                        const float y = (field_y) - (pivot_y);                                   \
                        (field_x) = (pivot_x) + x * cos - y * sin;                               \
                        (field_y) = (pivot_y) + x * sin + y * cos;                               \
                }                                                                                \
        } while (0)