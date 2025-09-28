#pragma once

#define WINDOW_MINIMIZED_THROTTLE 100

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