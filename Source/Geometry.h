#pragma once

#include <stddef.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>

#include "Debug.h"
#include "Defines.h"

#define EXPAND_MACRO(...) __VA_ARGS__
#define CONCATENATE_TOKEN(a, b) a##b
#define EVALUATE_TOKEN_CONCATENATION(a, b) CONCATENATE_TOKEN(a, b)

#define SET_SHAPE_COLOR_VALUES(shape, color_suffix, red, green, blue, alpha)      \
        do {                                                                      \
                (shape)->EVALUATE_TOKEN_CONCATENATION(r, color_suffix) = (red);   \
                (shape)->EVALUATE_TOKEN_CONCATENATION(g, color_suffix) = (green); \
                (shape)->EVALUATE_TOKEN_CONCATENATION(b, color_suffix) = (blue);  \
                (shape)->EVALUATE_TOKEN_CONCATENATION(a, color_suffix) = (alpha); \
        } while (0)

#define SET_SHAPE_COLOR_MACROS(shape, color_suffix, COLOR_MACRO, OPACITY_MACRO)         \
        do {                                                                            \
                (shape)->EVALUATE_TOKEN_CONCATENATION(r, color_suffix)                  \
                        = COLOR_COMPONENT(EXPAND_MACRO(COLOR_MACRO), OPACITY_MACRO, 0); \
                (shape)->EVALUATE_TOKEN_CONCATENATION(g, color_suffix)                  \
                        = COLOR_COMPONENT(EXPAND_MACRO(COLOR_MACRO), OPACITY_MACRO, 1); \
                (shape)->EVALUATE_TOKEN_CONCATENATION(b, color_suffix)                  \
                        = COLOR_COMPONENT(EXPAND_MACRO(COLOR_MACRO), OPACITY_MACRO, 2); \
                (shape)->EVALUATE_TOKEN_CONCATENATION(a, color_suffix)                  \
                        = COLOR_COMPONENT(EXPAND_MACRO(COLOR_MACRO), OPACITY_MACRO, 3); \
        } while (0)

#define SET_SHAPE_COLOR_SHAPE(destination_shape, destination_color_suffix, source_shape, source_color_suffix) \
        do {                                                                                                  \
                (destination_shape)->EVALUATE_TOKEN_CONCATENATION(r, destination_color_suffix)                \
                        = (source_shape)->EVALUATE_TOKEN_CONCATENATION(r, source_color_suffix);               \
                (destination_shape)->EVALUATE_TOKEN_CONCATENATION(g, destination_color_suffix)                \
                        = (source_shape)->EVALUATE_TOKEN_CONCATENATION(g, source_color_suffix);               \
                (destination_shape)->EVALUATE_TOKEN_CONCATENATION(b, destination_color_suffix)                \
                        = (source_shape)->EVALUATE_TOKEN_CONCATENATION(b, source_color_suffix);               \
                (destination_shape)->EVALUATE_TOKEN_CONCATENATION(a, destination_color_suffix)                \
                        = (source_shape)->EVALUATE_TOKEN_CONCATENATION(a, source_color_suffix);               \
        } while (0)

enum ShapeType {
        SHAPE_COMPOSITE = 0,
        SHAPE_TRIANGLE,
        SHAPE_QUADRILATERAL,
        SHAPE_HEXAGON,
        SHAPE_ROUND,
        SHAPE_RECTANGLE,
        SHAPE_LINE,
        SHAPE_BEZIER_CURVE
};

enum LineCap {
        LINE_CAP_NONE  = 0,
        LINE_CAP_START = 1 << 0,
        LINE_CAP_END   = 1 << 1,
        LINE_CAP_BOTH  =
                LINE_CAP_START |
                LINE_CAP_END
};

enum HexagonThicknessMask {
        HEXAGON_THICKNESS_MASK_NONE   = 0,
        HEXAGON_THICKNESS_MASK_LEFT   = 1 << 0,
        HEXAGON_THICKNESS_MASK_BOTTOM = 1 << 1,
        HEXAGON_THICKNESS_MASK_RIGHT  = 1 << 2,
        HEXAGON_THICKNESS_MASK_ALL    =
                HEXAGON_THICKNESS_MASK_LEFT   |
                HEXAGON_THICKNESS_MASK_BOTTOM |
                HEXAGON_THICKNESS_MASK_RIGHT
};

struct Drawable;
struct Shape {
        enum ShapeType type;
        struct Drawable *drawable;
        void *callibration_data;
        void (*on_calibration)(void *);
        union {
                struct Group { // SHAPE_COMPOSITE
                        struct Shape *shapes;
                        size_t shape_count;
                } group;
                struct Polygon { // SHAPE_TRIANGLE, SHAPE_QUADRILATERAL
                        uint8_t r, g, b, a;
                        float rounded_radius;
                        float x1, y1;
                        float x2, y2;
                        float x3, y3;
                        float x4, y4;
                } polygon;
                struct Rectangle { // SHAPE_RECTANGLE
                        uint8_t r, g, b, a;
                        float line_width;
                        float rounded_radius;
                        float rotation;
                        float width, height;
                        float x, y;
                } rectangle;
                struct Hexagon { // SHAPE_HEXAGON
                        bool line_and_fill;
                        float line_width;
                        float rotation;
                        float radius;
                        float x, y;
                        float thickness;
                        enum HexagonThicknessMask thickness_mask;
                        uint8_t r_fill, g_fill, b_fill, a_fill;
                        uint8_t r_line, g_line, b_line, a_line;
                        uint8_t r_thick, g_thick, b_thick, a_thick; 
                } hexagon;
                struct Round { // SHAPE_ROUND
                        uint8_t r_fill, g_fill, b_fill, a_fill;
                        uint8_t r_line, g_line, b_line, a_line;
                        bool line_and_fill;
                        float line_width;
                        float rotation;
                        float radius_x;
                        float radius_y;
                        float start_angle;
                        float end_angle;
                        bool clockwise;
                        float x, y;
                        enum LineCap line_cap;
                } round;
                struct Path { // SHAPE_LINE, SHAPE_BEZIER_CURVE
                        uint8_t r, g, b, a;
                        float line_width;
                        float x1, y1;
                        float x2, y2;
                        float control_x1;
                        float control_y1;
                        float control_x2;
                        float control_y2;
                        enum LineCap line_cap;
                } path;
        } as;
};

void initialize_shape(struct Shape *const shape, const enum ShapeType type);

void initialize_composite_shape(struct Shape *const shape, const size_t shape_count);

void deinitialize_shape(struct Shape *const shape);

static inline void *get_shape_data_pointer(struct Shape *const shape) {
        ASSERT_ALL(shape != NULL);

        switch (shape->type) {
                case SHAPE_COMPOSITE:     return (void *)&shape->as.group;
                case SHAPE_TRIANGLE:
                case SHAPE_QUADRILATERAL: return (void *)&shape->as.polygon;
                case SHAPE_HEXAGON:       return (void *)&shape->as.hexagon;
                case SHAPE_ROUND:         return (void *)&shape->as.round;
                case SHAPE_RECTANGLE:     return (void *)&shape->as.rectangle;
                case SHAPE_LINE:
                case SHAPE_BEZIER_CURVE:  return (void *)&shape->as.path;
        }
}