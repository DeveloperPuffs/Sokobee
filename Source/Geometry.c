#include "Geometry.h"

#include <limits.h>
#include <math.h>
#include <float.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <errno.h>

#include "SDL_render.h"

#include "Debug.h"
#include "Defines.h"
#include "Renderer.h"

static void populate_composite_vertices(void *const data, const GeometryRequester request_geometry, const VertexPopulator populate_vertex);

static void populate_triangle_vertices(void *const data, const GeometryRequester request_geometry, const VertexPopulator populate_vertex);

static void populate_quadrilateral_vertices(void *const data, const GeometryRequester request_geometry, const VertexPopulator populate_vertex);

static void populate_hexagon_vertices(void *const data, const GeometryRequester request_geometry, const VertexPopulator populate_vertex);

static void populate_round_vertices(void *const data, const GeometryRequester request_geometry, const VertexPopulator populate_vertex);

static void populate_rectangle_vertices(void *const data, const GeometryRequester request_geometry, const VertexPopulator populate_vertex);

static void populate_line_vertices(void *const data, const GeometryRequester request_geometry, const VertexPopulator populate_vertex);

static void populate_bezier_curve_vertices(void *const data, const GeometryRequester request_geometry, const VertexPopulator populate_vertex);

static const DrawableCallback shape_vertex_populators[] = {
        [SHAPE_COMPOSITE]     = populate_composite_vertices,
        [SHAPE_TRIANGLE]      = populate_triangle_vertices,
        [SHAPE_QUADRILATERAL] = populate_quadrilateral_vertices,
        [SHAPE_HEXAGON]       = populate_hexagon_vertices,
        [SHAPE_ROUND]         = populate_round_vertices,
        [SHAPE_RECTANGLE]     = populate_rectangle_vertices,
        [SHAPE_LINE]          = populate_line_vertices,
        [SHAPE_BEZIER_CURVE]  = populate_bezier_curve_vertices
};

void initialize_shape(struct Shape *const shape, const enum ShapeType type) {
        ASSERT_ALL(shape != NULL, type != SHAPE_COMPOSITE);

        shape->type = type;
        shape->on_calibration = NULL;
        shape->callibration_data = (void *)shape;
        shape->drawable = create_drawable((void *)shape, shape_vertex_populators[type]);

        switch (type) {
                case SHAPE_TRIANGLE: case SHAPE_QUADRILATERAL: {
                        struct Polygon *const polygon = &shape->as.polygon;
                        polygon->rounded_radius       =
                        polygon->x1 = polygon->y1     =
                        polygon->x2 = polygon->y2     =
                        polygon->x3 = polygon->y3     =
                        polygon->x4 = polygon->y4     = 0.0f;
                        SET_SHAPE_COLOR_MACROS(polygon,, COLOR_WHITE, COLOR_OPAQUE);
                        break;
                }

                case SHAPE_HEXAGON: {
                        struct Hexagon *const hexagon = &shape->as.hexagon;
                        hexagon->line_width           =
                        hexagon->rotation             =
                        hexagon->radius               = 0.0f;
                        hexagon->line_and_fill        = false;
                        hexagon->thickness_mask       = HEXAGON_THICKNESS_MASK_NONE;
                        hexagon->thickness            = 0.0f;
                        SET_SHAPE_COLOR_MACROS(hexagon, _fill,  COLOR_WHITE, COLOR_OPAQUE);
                        SET_SHAPE_COLOR_MACROS(hexagon, _line,  COLOR_WHITE, COLOR_OPAQUE);
                        SET_SHAPE_COLOR_MACROS(hexagon, _thick, COLOR_WHITE, COLOR_OPAQUE);
                        break;
                }

                case SHAPE_ROUND: {
                        struct Round *const round = &shape->as.round;
                        round->line_width    =
                        round->rotation      =
                        round->radius_x      =
                        round->radius_y      =
                        round->x = round->y  =
                        round->start_angle   = 0.0f;
                        round->end_angle     = 2.0f * (float)M_PI; 
                        round->clockwise     =
                        round->line_and_fill = false;
                        round->line_cap      = LINE_CAP_NONE;
                        SET_SHAPE_COLOR_MACROS(round, _fill, COLOR_WHITE, COLOR_OPAQUE);
                        SET_SHAPE_COLOR_MACROS(round, _line, COLOR_WHITE, COLOR_OPAQUE);
                        break;
                }

                case SHAPE_RECTANGLE: {
                        struct Rectangle *const rectangle = &shape->as.rectangle;
                        rectangle->line_width     =
                        rectangle->rotation       =
                        rectangle->rounded_radius =
                        rectangle->width          =
                        rectangle->height         =
                        rectangle->x              =
                        rectangle->y              = 0.0f;
                        SET_SHAPE_COLOR_MACROS(rectangle,, COLOR_WHITE, COLOR_OPAQUE);
                        break;
                }

                case SHAPE_LINE: SHAPE_BEZIER_CURVE: {
                        struct Path *const path = &shape->as.path;
                        path->line_cap      = LINE_CAP_NONE;
                        path->line_width    =
                        path->x1 = path->y1 =
                        path->x2 = path->y2 =
                        path->control_x1    =
                        path->control_y1    =
                        path->control_x2    =
                        path->control_y2    = 0.0f;
                        SET_SHAPE_COLOR_MACROS(path,, COLOR_WHITE, COLOR_OPAQUE);
                        break;
                }

                default: {
                        break;
                }
        }
}

void initialize_composite_shape(struct Shape *const shape, const size_t shape_count) {
        ASSERT_ALL(shape != NULL, shape_count != 0ULL);

        shape->type = SHAPE_COMPOSITE;
        shape->on_calibration = NULL;
        shape->callibration_data = (void *)shape;
        shape->drawable = create_drawable((void *)shape, populate_composite_vertices);

        struct Group *const group = &shape->as.group;
        shape->as.group.shape_count = shape_count;
        shape->as.group.shapes = (struct Shape *)xmalloc(shape_count * sizeof(struct Shape));
}

void deinitialize_shape(struct Shape *const shape) {
        ASSERT_ALL(shape != NULL);

        if (shape->type == SHAPE_COMPOSITE) {
                for (size_t shape_index = 0ULL; shape_index < shape->as.group.shape_count; ++shape_index) {
                        deinitialize_shape(&shape->as.group.shapes[shape_index]);
                        xfree(shape->as.group.shapes);
                }
        }
}

#ifndef NDEBUG

#define MAXIMUM_MAGNITUDE (1e6f)

#define CHECK_FINITE_FLOAT(number, name)                                                                            \
        do {                                                                                                        \
                if (!isfinite((float)(number)) || fabsf((float)(number)) > MAXIMUM_MAGNITUDE) {                     \
                        send_message(MESSAGE_ERROR,                                                                 \
                                "Float that is nonfinite or greater than maximum maginute of (%E) found: %s (%E)",  \
                                (double)MAXIMUM_MAGNITUDE, name, (double)(number));                                 \
                        return;                                                                                     \
                }                                                                                                   \
        } while (0)

#define CHECK_FINITE_POINT(x, y, name)                                                                                                                  \
        do {                                                                                                                                            \
                if (!isfinite((float)(x)) || fabsf((float)(x)) > MAXIMUM_MAGNITUDE || !isfinite((float)(y)) || fabsf((float)(y)) > MAXIMUM_MAGNITUDE) { \
                        send_message(MESSAGE_ERROR,                                                                                                     \
                                "Point that is nonfinite or greater than maximum maginute of (%E) found: %s (%E, %E)",                                  \
                                (double)MAXIMUM_MAGNITUDE, name, (double)(x), (double)(y));                                                             \
                        return;                                                                                                                         \
                }                                                                                                                                       \
        } while (0)

#else

#define CHECK_FINITE_FLOAT(number, name) ((void)0)

#define CHECK_FINITE_POINT(x, y, name) ((void)0)

#endif

// Use 'FLT_MAX' for the texture coordinates to use the texture part for the geometry shapes
#define VERTEX_INDEX(vertex_populator, x, y, r, g, b, a) \
        (vertex_populator)((x), (y), FLT_MAX, FLT_MAX, (r), (g), (b), (a))

static void populate_composite_vertices(void *const data, const GeometryRequester request_geometry, const VertexPopulator populate_vertex) {
        struct Shape *const shape = (struct Shape *)data;
        ASSERT_ALL(shape != NULL, shape->type == SHAPE_COMPOSITE);

        if (shape->on_calibration != NULL) {
                shape->on_calibration(shape->callibration_data);
        }

        struct Group *const group = &shape->as.group;
        for (size_t shape_index = 0ULL; shape_index < group->shape_count; ++shape_index) {
                struct Shape *const child_shape = &group->shapes[shape_index];
                shape_vertex_populators[child_shape->type]((void *)child_shape, request_geometry, populate_vertex);
        }
}

static void populate_triangle_vertices(void *const data, const GeometryRequester request_geometry, const VertexPopulator populate_vertex) {
        struct Shape *const shape = (struct Shape *)data;
        ASSERT_ALL(shape != NULL, shape->type == SHAPE_TRIANGLE);

        if (shape->on_calibration != NULL) {
                shape->on_calibration(shape->callibration_data);
        }

        struct Polygon *const triangle = &shape->as.polygon;
        CHECK_FINITE_POINT(triangle->x1, triangle->y1, "Triangle Point A");
        CHECK_FINITE_POINT(triangle->x2, triangle->y2, "Triangle Point B");
        CHECK_FINITE_POINT(triangle->x3, triangle->y3, "Triangle Point C");
        CHECK_FINITE_FLOAT(triangle->rounded_radius,   "Triangle Rounded Radius");

        if (triangle->rounded_radius == 0.0f) {
                int *const indices = request_geometry(3ULL, 3ULL); // 3 Vertices, 3 Indices
                indices[0] = VERTEX_INDEX(populate_vertex, triangle->x1, triangle->y1, triangle->r, triangle->g, triangle->b, triangle->a);
                indices[1] = VERTEX_INDEX(populate_vertex, triangle->x2, triangle->y2, triangle->r, triangle->g, triangle->b, triangle->a);
                indices[2] = VERTEX_INDEX(populate_vertex, triangle->x3, triangle->y3, triangle->r, triangle->g, triangle->b, triangle->a);
                return;
        }

        const float vx[3] = {triangle->x1, triangle->x2, triangle->x3};
        const float vy[3] = {triangle->y1, triangle->y2, triangle->y3};

        const float double_signed_area = (vx[1] - vx[0]) * (vy[2] - vy[0]) - (vy[1] - vy[0]) * (vx[2] - vx[0]);
        const bool counterclockwise = double_signed_area > 0.0f;

        float maximum_radius = FLT_MAX;
        for (uint8_t index = 0; index < 3; ++index) {
                float edge1_x = vx[(index + 1) % 3] - vx[index];
                float edge1_y = vy[(index + 1) % 3] - vy[index];
                float edge2_x = vx[(index + 2) % 3] - vx[index];
                float edge2_y = vy[(index + 2) % 3] - vy[index];

                const float length1 = sqrtf(edge1_x * edge1_x + edge1_y * edge1_y);
                const float length2 = sqrtf(edge2_x * edge2_x + edge2_y * edge2_y);
                if (length1 == 0.0f || length2 == 0.0f) {
                        continue;
                }

                edge1_x /= length1;
                edge1_y /= length1;
                edge2_x /= length2;
                edge2_y /= length2;

                const float dot12 = fmaxf(-1.0f, fminf(1.0f, edge1_x * edge2_x + edge1_y * edge2_y));
                const float maximum_side_radius = fminf(length1, length2) * tanf(acosf(dot12) / 2.0f);
                if (maximum_side_radius < maximum_radius) {
                        maximum_radius = maximum_side_radius;
                }
        }

        const float clamped_rounded_radius = fminf(triangle->rounded_radius, maximum_radius);

        float   center_x[3],   center_y[3];
        float tangent1_x[3], tangent1_y[3];
        float tangent2_x[3], tangent2_y[3];

        for (uint8_t index = 0; index < 3; ++index) {
                float edge1_x = vx[(index + 1) % 3] - vx[index];
                float edge1_y = vy[(index + 1) % 3] - vy[index];
                float edge2_x = vx[(index + 2) % 3] - vx[index];
                float edge2_y = vy[(index + 2) % 3] - vy[index];

                const float length1 = sqrtf(edge1_x * edge1_x + edge1_y * edge1_y);
                const float length2 = sqrtf(edge2_x * edge2_x + edge2_y * edge2_y);
                if (length1 == 0.0f || length2 == 0.0f) {
                        continue;
                }

                edge1_x /= length1;
                edge1_y /= length1;
                edge2_x /= length2;
                edge2_y /= length2;

                const float theta = acosf(fmaxf(-1.0f, fminf(1.0f, edge1_x * edge2_x + edge1_y * edge2_y)));
                const float tangent = tanf(theta / 2.0f);
                if (tangent == 0.0f) {
                        continue;
                }

                float distance = clamped_rounded_radius / tangent;
                if (distance > length1) {
                        distance = length1;
                }

                if (distance > length2) {
                        distance = length2;
                }

                tangent1_x[index] = vx[index] + edge1_x * distance;
                tangent1_y[index] = vy[index] + edge1_y * distance;
                tangent2_x[index] = vx[index] + edge2_x * distance;
                tangent2_y[index] = vy[index] + edge2_y * distance;

                const float bisector_x = edge1_x + edge2_x;
                const float bisector_y = edge1_y + edge2_y;
                const float bisector_length = sqrtf(bisector_x * bisector_x + bisector_y * bisector_y);
                if (bisector_length == 0.0f) {
                        continue;
                }

                const float sine = sinf(theta / 2.0f);
                if (sine == 0.0f) {
                        continue;
                }

                center_x[index] = vx[index] + (bisector_x / bisector_length) * clamped_rounded_radius / sine;
                center_y[index] = vy[index] + (bisector_y / bisector_length) * clamped_rounded_radius / sine;

                const float angle1 = atan2f(tangent1_y[index] - center_y[index], tangent1_x[index] - center_x[index]);
                const float angle2 = atan2f(tangent2_y[index] - center_y[index], tangent2_x[index] - center_x[index]);
                float delta = angle2 - angle1;

                while (delta <= -M_PI) {
                        delta += 2.0f * (float)M_PI;
                }

                while (delta > M_PI) {
                        delta -= 2.0f * (float)M_PI;
                }

                struct Shape rounded_arc;
                initialize_shape(&rounded_arc, SHAPE_ROUND);
                struct Round *const rounded_arc_round = &rounded_arc.as.round;
                SET_SHAPE_COLOR_SHAPE(rounded_arc_round, _fill, triangle,);
                rounded_arc_round->x                  = center_x[index];
                rounded_arc_round->y                  = center_y[index];
                rounded_arc_round->radius_x           = clamped_rounded_radius;
                rounded_arc_round->radius_y           = clamped_rounded_radius;
                rounded_arc_round->start_angle        = angle1;
                rounded_arc_round->end_angle          = angle2;
                rounded_arc_round->clockwise          = delta < 0.0f;
                shape_vertex_populators[SHAPE_ROUND]((void *)&rounded_arc, request_geometry, populate_vertex);
        }

        for (uint8_t index = 0; index < 3; ++index) {
                const float x1 = tangent1_x[index];
                const float y1 = tangent1_y[index];
                const float x2 = tangent2_x[(index + 1) % 3];
                const float y2 = tangent2_y[(index + 1) % 3];

                const float distance_x = x2 - x1;
                const float distance_y = y2 - y1;
                const float length = sqrtf(distance_x * distance_x + distance_y * distance_y);
                if (length == 0.0f) {
                        continue;
                }

                const float offset_x = (clamped_rounded_radius / 2.0f) * (counterclockwise ? -distance_y : distance_y) / length;
                const float offset_y = (clamped_rounded_radius / 2.0f) * (counterclockwise ? distance_x : -distance_x) / length;

                struct Shape side_strip;
                initialize_shape(&side_strip, SHAPE_LINE);
                struct Path *const side_strip_line = &side_strip.as.path;
                SET_SHAPE_COLOR_SHAPE(side_strip_line,, triangle,);
                side_strip_line->line_width        = clamped_rounded_radius;
                side_strip_line->x1                = x1 + offset_x;
                side_strip_line->y1                = y1 + offset_y;
                side_strip_line->x2                = x2 + offset_x;
                side_strip_line->y2                = y2 + offset_y;
                shape_vertex_populators[SHAPE_LINE]((void *)&side_strip, request_geometry, populate_vertex);
        }

        struct Shape center_polygon;
        initialize_shape(&center_polygon, SHAPE_TRIANGLE);
        struct Polygon *const center_triangle = &center_polygon.as.polygon;
        SET_SHAPE_COLOR_SHAPE(center_triangle,, triangle,);
        center_triangle->x1                   = center_x[0];
        center_triangle->y1                   = center_y[0];
        center_triangle->x2                   = center_x[1];
        center_triangle->y2                   = center_y[1];
        center_triangle->x3                   = center_x[2];
        center_triangle->y3                   = center_y[2];
        shape_vertex_populators[SHAPE_TRIANGLE]((void *)&center_polygon, request_geometry, populate_vertex);
}

static void populate_quadrilateral_vertices(void *const data, const GeometryRequester request_geometry, const VertexPopulator populate_vertex) {
        struct Shape *const shape = (struct Shape *)data;
        ASSERT_ALL(shape != NULL, shape->type == SHAPE_QUADRILATERAL);

        if (shape->on_calibration != NULL) {
                shape->on_calibration(shape->callibration_data);
        }

        struct Polygon *const quadrilateral = &shape->as.polygon;
        CHECK_FINITE_POINT(quadrilateral->x1, quadrilateral->y1, "Quadrilateral Point A");
        CHECK_FINITE_POINT(quadrilateral->x2, quadrilateral->y2, "Quadrilateral Point B");
        CHECK_FINITE_POINT(quadrilateral->x3, quadrilateral->y3, "Quadrilateral Point C");
        CHECK_FINITE_POINT(quadrilateral->x4, quadrilateral->y4, "Quadrilateral Point D");
        CHECK_FINITE_FLOAT(quadrilateral->rounded_radius,        "Quadrilateral Rounded Radius");

        if (quadrilateral->rounded_radius == 0.0f) {
                int *const indices = request_geometry(4ULL, 6ULL); // 4 Vertices, 6 Indices
                const int index1 = VERTEX_INDEX(populate_vertex, quadrilateral->x1, quadrilateral->y1, quadrilateral->r, quadrilateral->g, quadrilateral->b, quadrilateral->a);
                const int index2 = VERTEX_INDEX(populate_vertex, quadrilateral->x2, quadrilateral->y2, quadrilateral->r, quadrilateral->g, quadrilateral->b, quadrilateral->a);
                const int index3 = VERTEX_INDEX(populate_vertex, quadrilateral->x3, quadrilateral->y3, quadrilateral->r, quadrilateral->g, quadrilateral->b, quadrilateral->a);
                const int index4 = VERTEX_INDEX(populate_vertex, quadrilateral->x4, quadrilateral->y4, quadrilateral->r, quadrilateral->g, quadrilateral->b, quadrilateral->a);
                indices[0] = index1; indices[1] = index2; indices[2] = index3;
                indices[3] = index1; indices[4] = index3; indices[5] = index4;
                return;
        }

        const float vx[4] = {quadrilateral->x1, quadrilateral->x2, quadrilateral->x3, quadrilateral->x4};
        const float vy[4] = {quadrilateral->y1, quadrilateral->y2, quadrilateral->y3, quadrilateral->y4};

        const float double_signed_area = (vx[1] - vx[0]) * (vy[2] - vy[0]) - (vy[1] - vy[0]) * (vx[2] - vx[0]);
        const bool counterclockwise = double_signed_area > 0.0f;

        float maximum_radius = FLT_MAX;
        for (uint8_t index = 0; index < 4; ++index) {
                float edge1_x = vx[(index + 1) % 4] - vx[index];
                float edge1_y = vy[(index + 1) % 4] - vy[index];
                float edge2_x = vx[(index + 3) % 4] - vx[index];
                float edge2_y = vy[(index + 3) % 4] - vy[index];

                float length1 = sqrtf(edge1_x * edge1_x + edge1_y * edge1_y);
                float length2 = sqrtf(edge2_x * edge2_x + edge2_y * edge2_y);
                if (length1 == 0.0f || length2 == 0.0f) {
                        continue;
                }

                edge1_x /= length1;
                edge1_y /= length1;
                edge2_x /= length2;
                edge2_y /= length2;

                const float dot12 = fmaxf(-1.0f, fminf(1.0f, edge1_x * edge2_x + edge1_y * edge2_y));
                const float maximum_side_radius = fminf(length1, length2) * tanf(acosf(dot12) / 2.0f);
                if (maximum_side_radius < maximum_radius) {
                        maximum_radius = maximum_side_radius;
                }
        }

        const float clamped_rounded_radius = fminf(quadrilateral->rounded_radius, maximum_radius);

        float   center_x[4],   center_y[4];
        float tangent1_x[4], tangent1_y[4];
        float tangent2_x[4], tangent2_y[4];

        for (uint8_t index = 0; index < 4; ++index) {
                float edge1_x = vx[(index + 1) % 4] - vx[index];
                float edge1_y = vy[(index + 1) % 4] - vy[index];
                float edge2_x = vx[(index + 3) % 4] - vx[index];
                float edge2_y = vy[(index + 3) % 4] - vy[index];

                const float length1 = sqrtf(edge1_x * edge1_x + edge1_y * edge1_y);
                const float length2 = sqrtf(edge2_x * edge2_x + edge2_y * edge2_y);
                if (length1 == 0.0f || length2 == 0.0f) {
                        continue;
                }

                edge1_x /= length1;
                edge1_y /= length1;
                edge2_x /= length2;
                edge2_y /= length2;

                const float theta = acosf(fmaxf(-1.0f, fminf(1.0f, edge1_x * edge2_x + edge1_y * edge2_y)));
                const float tangent = tanf(theta / 2.0f);
                if (tangent == 0.0f) {
                        continue;
                }

                float distance = clamped_rounded_radius / tangent;

                if (distance > length1) {
                        distance = length1;
                }

                if (distance > length2) {
                        distance = length2;
                }

                tangent1_x[index] = vx[index] + edge1_x * distance;
                tangent1_y[index] = vy[index] + edge1_y * distance;
                tangent2_x[index] = vx[index] + edge2_x * distance;
                tangent2_y[index] = vy[index] + edge2_y * distance;

                const float bisector_x = edge1_x + edge2_x;
                const float bisector_y = edge1_y + edge2_y;
                const float bisector_length = sqrtf(bisector_x * bisector_x + bisector_y * bisector_y);
                if (bisector_length == 0.0f) {
                        continue;
                }

                const float sine = sinf(theta / 2.0f);
                if (sine == 0.0f) {
                        continue;
                }

                center_x[index] = vx[index] + (bisector_x / bisector_length) * clamped_rounded_radius / sine;
                center_y[index] = vy[index] + (bisector_y / bisector_length) * clamped_rounded_radius / sine;

                float angle1 = atan2f(tangent1_y[index] - center_y[index], tangent1_x[index] - center_x[index]);
                float angle2 = atan2f(tangent2_y[index] - center_y[index], tangent2_x[index] - center_x[index]);
                float delta = angle2 - angle1;

                while (delta <= -M_PI) {
                        delta += 2.0f * (float)M_PI;
                }

                while (delta > M_PI) {
                        delta -= 2.0f * (float)M_PI;
                }

                struct Shape rounded_arc;
                initialize_shape(&rounded_arc, SHAPE_ROUND);
                struct Round *const rounded_arc_round = &rounded_arc.as.round;
                SET_SHAPE_COLOR_SHAPE(rounded_arc_round, _fill, quadrilateral,);
                rounded_arc_round->x                  = center_x[index];
                rounded_arc_round->y                  = center_y[index];
                rounded_arc_round->radius_x           = clamped_rounded_radius;
                rounded_arc_round->radius_y           = clamped_rounded_radius;
                rounded_arc_round->start_angle        = angle1;
                rounded_arc_round->end_angle          = angle2;
                rounded_arc_round->clockwise          = delta < 0.0f;
                shape_vertex_populators[SHAPE_ROUND]((void *)&rounded_arc, request_geometry, populate_vertex);
        }

        for (uint8_t index = 0; index < 4; ++index) {
                const float x1 = tangent1_x[index];
                const float y1 = tangent1_y[index];
                const float x2 = tangent2_x[(index + 1) % 4];
                const float y2 = tangent2_y[(index + 1) % 4];

                const float distance_x = x2 - x1;
                const float distance_y = y2 - y1;
                const float length = sqrtf(distance_x * distance_x + distance_y * distance_y);
                if (length == 0.0f) {
                        continue;
                }

                const float offset_x = (clamped_rounded_radius / 2.0f) * (counterclockwise ? -distance_y : distance_y) / length;
                const float offset_y = (clamped_rounded_radius / 2.0f) * (counterclockwise ? distance_x : -distance_x) / length;

                struct Shape side_strip;
                initialize_shape(&side_strip, SHAPE_LINE);
                struct Path *const side_strip_line = &side_strip.as.path;
                SET_SHAPE_COLOR_SHAPE(side_strip_line,, quadrilateral,);
                side_strip_line->line_width        = clamped_rounded_radius;
                side_strip_line->x1                = x1 + offset_x;
                side_strip_line->y1                = y1 + offset_y;
                side_strip_line->x2                = x2 + offset_x;
                side_strip_line->y2                = y2 + offset_y;
                shape_vertex_populators[SHAPE_LINE]((void *)&side_strip, request_geometry, populate_vertex);
        }

        // NOTE: Using two lines (quads) and one large quad in the center instead of one line (quad) for each edge with one quad in the center
        // would be more efficient as it uses two less quads, but I couldn't make that work when it comes to quads that aren't rectangular.
        struct Shape center_polygon;
        initialize_shape(&center_polygon, SHAPE_QUADRILATERAL);
        struct Polygon *const center_quadrilateral = &center_polygon.as.polygon;
        SET_SHAPE_COLOR_SHAPE(center_quadrilateral,, quadrilateral,);
        center_quadrilateral->rounded_radius       = 0.0f;
        center_quadrilateral->x1                   = center_x[0];
        center_quadrilateral->y1                   = center_y[0];
        center_quadrilateral->x2                   = center_x[1];
        center_quadrilateral->y2                   = center_y[1];
        center_quadrilateral->x3                   = center_x[2];
        center_quadrilateral->y3                   = center_y[2];
        center_quadrilateral->x4                   = center_x[3];
        center_quadrilateral->y4                   = center_y[3];
        shape_vertex_populators[SHAPE_QUADRILATERAL]((void *)&center_polygon, request_geometry, populate_vertex);
}

static void populate_hexagon_vertices(void *const data, const GeometryRequester request_geometry, const VertexPopulator populate_vertex) {
        struct Shape *const shape = (struct Shape *)data;
        ASSERT_ALL(shape != NULL, shape->type == SHAPE_HEXAGON);

        if (shape->on_calibration != NULL) {
                shape->on_calibration(shape->callibration_data);
        }

        struct Hexagon *const hexagon = &shape->as.hexagon;
        CHECK_FINITE_POINT(hexagon->x, hexagon->y, "Hexagon Position");
        CHECK_FINITE_FLOAT(hexagon->radius,        "Hexagon Radius");
        CHECK_FINITE_FLOAT(hexagon->rotation,      "Hexagon Rotation");
        CHECK_FINITE_FLOAT(hexagon->thickness,     "Hexagon Thicknes");

        if (hexagon->line_and_fill && hexagon->line_width > 0.0f) {
                struct Shape stacked_shape;
                initialize_shape(&stacked_shape, SHAPE_HEXAGON);
                struct Hexagon *const stacked_hexagon = &stacked_shape.as.hexagon;
                stacked_hexagon->rotation           = hexagon->rotation;
                stacked_hexagon->x                  = hexagon->x;
                stacked_hexagon->y                  = hexagon->y;

                SET_SHAPE_COLOR_SHAPE(stacked_hexagon, _fill, hexagon, _line);
                stacked_hexagon->thickness      = hexagon->thickness;
                stacked_hexagon->thickness_mask = hexagon->thickness_mask;
                stacked_hexagon->radius         = hexagon->radius + hexagon->line_width / 2.0f;
                shape_vertex_populators[SHAPE_ROUND]((void *)&stacked_shape, request_geometry, populate_vertex);

                stacked_hexagon->radius = hexagon->radius - hexagon->line_width / 2.0f;
                if (stacked_hexagon->radius <= 0.0f) {
                        return;
                }

                SET_SHAPE_COLOR_SHAPE(stacked_hexagon, _fill, hexagon, _fill);
                stacked_hexagon->thickness      = 0.0f;
                stacked_hexagon->thickness_mask = HEXAGON_THICKNESS_MASK_NONE;
                shape_vertex_populators[SHAPE_ROUND]((void *)&stacked_shape, request_geometry, populate_vertex);
                return;
        }

        if (hexagon->thickness_mask != HEXAGON_THICKNESS_MASK_NONE && hexagon->thickness > 0.0f) {
                const float ax1 = hexagon->x - hexagon->radius;
                const float ay1 = hexagon->y;
                const float ax2 = hexagon->x - hexagon->radius / 2.0f;
                const float ay2 = hexagon->y + hexagon->radius * sqrtf(3.0f) / 2.0f;
                const float ax3 = hexagon->x + hexagon->radius / 2.0f;
                const float ay3 = hexagon->y + hexagon->radius * sqrtf(3.0f) / 2.0f;
                const float ax4 = hexagon->x + hexagon->radius;
                const float ay4 = hexagon->y;

#define THICKER + hexagon->thickness

                struct Shape thickness_polygon;
                initialize_shape(&thickness_polygon, SHAPE_QUADRILATERAL);
                struct Polygon *const thickness_quadrilateral = &thickness_polygon.as.polygon;
                SET_SHAPE_COLOR_SHAPE(thickness_quadrilateral,, hexagon, _thick);

                if ((hexagon->thickness_mask & HEXAGON_THICKNESS_MASK_LEFT) == HEXAGON_THICKNESS_MASK_LEFT) {
                        thickness_quadrilateral->x1 = ax1;
                        thickness_quadrilateral->y1 = ay1;
                        thickness_quadrilateral->x2 = ax2;
                        thickness_quadrilateral->y2 = ay2;
                        thickness_quadrilateral->x3 = ax2;
                        thickness_quadrilateral->y3 = ay2 THICKER;
                        thickness_quadrilateral->x3 = ax1;
                        thickness_quadrilateral->y3 = ay1 THICKER;
                        shape_vertex_populators[SHAPE_QUADRILATERAL]((void *)&thickness_polygon, request_geometry, populate_vertex);
                }

                if ((hexagon->thickness_mask & HEXAGON_THICKNESS_MASK_BOTTOM) == HEXAGON_THICKNESS_MASK_BOTTOM) {
                        thickness_quadrilateral->x1 = ax2;
                        thickness_quadrilateral->y1 = ay2;
                        thickness_quadrilateral->x2 = ax3;
                        thickness_quadrilateral->y2 = ay3;
                        thickness_quadrilateral->x3 = ax3;
                        thickness_quadrilateral->y3 = ay3 THICKER;
                        thickness_quadrilateral->x3 = ax2;
                        thickness_quadrilateral->y3 = ay2 THICKER;
                        shape_vertex_populators[SHAPE_QUADRILATERAL]((void *)&thickness_polygon, request_geometry, populate_vertex);
                }

                if ((hexagon->thickness_mask & HEXAGON_THICKNESS_MASK_RIGHT) == HEXAGON_THICKNESS_MASK_RIGHT) {
                        thickness_quadrilateral->x1 = ax3;
                        thickness_quadrilateral->y1 = ay3;
                        thickness_quadrilateral->x2 = ax4;
                        thickness_quadrilateral->y2 = ay4;
                        thickness_quadrilateral->x3 = ax4;
                        thickness_quadrilateral->y3 = ay4 THICKER;
                        thickness_quadrilateral->x3 = ax3;
                        thickness_quadrilateral->y3 = ay3 THICKER;
                        shape_vertex_populators[SHAPE_QUADRILATERAL]((void *)&thickness_polygon, request_geometry, populate_vertex);
                }

#undef THICKER
        }

        if (hexagon->line_width <= 0.0f) {
                int *const indices = request_geometry(6ULL, 12ULL); // 6 Vertices, 12 Indices

                uint16_t ordered_indices[6];
                static const float step = (float)M_PI / 3.0f;
                for (uint8_t index = 0; index < 6; index++) {
                        const float angle = hexagon->rotation + step * (float)index;
                        const float x = hexagon->x + cosf(angle) * hexagon->radius;
                        const float y = hexagon->y + sinf(angle) * hexagon->radius;
                        ordered_indices[index] = VERTEX_INDEX(populate_vertex, x, y, hexagon->r_fill, hexagon->g_fill, hexagon->b_fill, hexagon->a_fill);
                }

                indices[ 0] = ordered_indices[1];
                indices[ 1] = ordered_indices[2];
                indices[ 2] = ordered_indices[3];

                indices[ 3] = ordered_indices[1];
                indices[ 4] = ordered_indices[3];
                indices[ 5] = ordered_indices[4];

                indices[ 6] = ordered_indices[1];
                indices[ 7] = ordered_indices[4];
                indices[ 8] = ordered_indices[5];

                indices[ 9] = ordered_indices[1];
                indices[10] = ordered_indices[5];
                indices[11] = ordered_indices[0];
        }

        // TODO: Hexagon outlines?
}

static void populate_round_vertices(void *const data, const GeometryRequester request_geometry, const VertexPopulator populate_vertex) {
        struct Shape *const shape = (struct Shape *)data;
        ASSERT_ALL(shape != NULL, shape->type == SHAPE_ROUND);

        if (shape->on_calibration != NULL) {
                shape->on_calibration(shape->callibration_data);
        }

        struct Round *const round = &shape->as.round;
        CHECK_FINITE_POINT(round->x, round->y,               "Round Position");
        CHECK_FINITE_POINT(round->radius_x, round->radius_y, "Round Radii");
        CHECK_FINITE_FLOAT(round->rotation,                  "Round Rotation");
        CHECK_FINITE_FLOAT(round->start_angle,               "Round Start Angle");
        CHECK_FINITE_FLOAT(round->end_angle,                 "Round End Angle");

        if (round->radius_x <= 0.0f || round->radius_y <= 0.0f || round->start_angle == round->end_angle) {
                return;
        }

        if (round->line_and_fill && round->line_width >= 0.0f) {
                struct Shape stacked_shape;
                initialize_shape(&stacked_shape, SHAPE_ROUND);
                struct Round *const stacked_round = &stacked_shape.as.round;
                stacked_round->x                  = round->x;
                stacked_round->y                  = round->y;
                stacked_round->start_angle        = round->start_angle;
                stacked_round->end_angle          = round->end_angle;
                stacked_round->clockwise          = round->clockwise;

                SET_SHAPE_COLOR_SHAPE(stacked_round, _fill, round, _line);
                stacked_round->radius_x = round->radius_x + round->line_width / 2.0f;
                stacked_round->radius_y = round->radius_y + round->line_width / 2.0f;
                shape_vertex_populators[SHAPE_ROUND]((void *)&stacked_shape, request_geometry, populate_vertex);

                stacked_round->radius_x = round->radius_x - round->line_width / 2.0f;
                stacked_round->radius_x = round->radius_y - round->line_width / 2.0f;
                if (stacked_round->radius_x > 0.0f &&  stacked_round->radius_y > 0.0f) {
                        return;
                }

                SET_SHAPE_COLOR_SHAPE(stacked_round, _fill, round, _fill);
                shape_vertex_populators[SHAPE_ROUND]((void *)&stacked_shape, request_geometry, populate_vertex);
                return;
        }

        float angle_span = round->end_angle - round->start_angle;
        if (round->clockwise && angle_span > 0.0f) {
                angle_span -= 2.0f * (float)M_PI;
        } else if (!round->clockwise && angle_span < 0.0f) {
                angle_span += 2.0f * (float)M_PI;
        }

        const float circumference = M_PI * (3.0f * (round->radius_x + round->radius_y) - sqrtf((3.0f * round->radius_x + round->radius_y) * (round->radius_x + 3.0f * round->radius_y)));
        const float arc_length = circumference * fabsf(angle_span) / (2.0f * (float)M_PI);

        size_t resolution = (size_t)ceilf(arc_length / GEOMETRY_SEGMENT_LENGTH);
        if (resolution < 3ULL) {
                resolution = 3ULL;
        }

        if (round->line_width <= 0.0f) {
                int *const indices = request_geometry(resolution + 2ULL, (resolution + 1ULL) * 3ULL);

                const int center_index = VERTEX_INDEX(populate_vertex, round->x, round->y, round->r_fill, round->g_fill, round->b_fill, round->a_fill);
                for (size_t index = 0ULL; index <= resolution; ++index) {
                        const float interpolation = (float)index / (float)resolution;
                        const float angle = round->start_angle + interpolation * angle_span;

                        float x = round->radius_x * cosf(angle);
                        float y = round->radius_y * sinf(angle);

                        if (round->rotation != 0.0f) {
                                const float sin_r = sinf(round->rotation);
                                const float cos_r = cosf(round->rotation);
                                const float vx = x;
                                x = vx * cos_r - y * sin_r;
                                y = vx * sin_r + y * cos_r;
                        }

                        VERTEX_INDEX(populate_vertex, x, y, round->r_fill, round->g_fill, round->b_fill, round->a_fill);
                }

                for (size_t index = 0ULL; index < resolution; ++index) {
                        indices[index * 3ULL + 0ULL] = center_index;
                        indices[index * 3ULL + 1ULL] = center_index + (int)index + 1;
                        indices[index * 3ULL + 2ULL] = center_index + (int)index + 2;
                }
        }

        int *const indices = request_geometry((resolution + 1ULL) * 2ULL, resolution * 6ULL);

        float inner_radius_x = round->radius_x - round->line_width / 2.0f;
        float inner_radius_y = round->radius_y - round->line_width / 2.0f;

        if (inner_radius_x < 0.0f) {
                inner_radius_x = 0.0f;
        }

        if (inner_radius_y < 0.0f) {
                inner_radius_y = 0.0f;
        }

        const float outer_radius_x = round->radius_x + round->line_width / 2.0f;
        const float outer_radius_y = round->radius_y + round->line_width / 2.0f;

        const float cos = cosf(round->rotation);
        const float sin = sinf(round->rotation);

        // HACK: Keeping track of the triangle vertices at the start and end of the triangle strip to accurately calculate the
        // positions (centers) of the line cap arcs since I can't get it to look aligned visually.
        float inner_x1, inner_y1, inner_x2, inner_y2;
        float outer_x1, outer_y1, outer_x2, outer_y2;

        int start_index = INT_MAX;
        for (size_t index = 0ULL; index <= resolution; ++index) {
                const float angle = round->start_angle + angle_span * (float)index / (float)resolution;

                const float x_outer = outer_radius_x * cosf(angle);
                const float y_outer = outer_radius_y * sinf(angle);

                const float x_inner = inner_radius_x * cosf(angle);
                const float y_inner = inner_radius_y * sinf(angle);

                const float rx_outer = x_outer * cos - y_outer * sin;
                const float ry_outer = x_outer * sin + y_outer * cos;

                const float rx_inner = x_inner * cos - y_inner * sin;
                const float ry_inner = x_inner * sin + y_inner * cos;

                if (index == 0LL) {
                        inner_x1 = round->x + rx_inner;
                        inner_y1 = round->y + ry_inner;
                        outer_x1 = round->x + rx_outer;
                        outer_y1 = round->y + ry_outer;
                }

                if (index == resolution) {
                        inner_x2 = round->x + rx_inner;
                        inner_y2 = round->y + ry_inner;
                        outer_x2 = round->x + rx_outer;
                        outer_y2 = round->y + ry_outer;
                }

                if (start_index == INT_MAX) {
                        start_index =
                        VERTEX_INDEX(populate_vertex, round->x + rx_outer, round->y + ry_outer, round->r_line, round->g_line, round->b_line, round->a_line);
                        VERTEX_INDEX(populate_vertex, round->x + rx_inner, round->y + ry_inner, round->r_line, round->g_line, round->b_line, round->a_line);
                } else {
                        VERTEX_INDEX(populate_vertex, round->x + rx_outer, round->y + ry_outer, round->r_line, round->g_line, round->b_line, round->a_line);
                        VERTEX_INDEX(populate_vertex, round->x + rx_inner, round->y + ry_inner, round->r_line, round->g_line, round->b_line, round->a_line);
                }

                if (index < resolution) {
                        const int vertex_index = start_index + 2 * (int)index;

                        indices[index * 6ULL + 0ULL] = vertex_index + 0;
                        indices[index * 6ULL + 1ULL] = vertex_index + 1;
                        indices[index * 6ULL + 2ULL] = vertex_index + 2;

                        indices[index * 6ULL + 3ULL] = vertex_index + 1;
                        indices[index * 6ULL + 4ULL] = vertex_index + 3;
                        indices[index * 6ULL + 5ULL] = vertex_index + 2;
                }
        }

        if (round->line_cap == LINE_CAP_NONE) {
                return;
        }

        // HACK: Using an arbitrary offset to add to the angle to the arcs since the angle of both arcs are just slightly off for some reason.
        static const float angle_offset = M_PI_4 / 4.0f;

        struct Shape line_cap;
        initialize_shape(&line_cap, SHAPE_ROUND);
        struct Round *const line_cap_round = &line_cap.as.round;
        SET_SHAPE_COLOR_SHAPE(line_cap_round, _fill, round, _line);
        line_cap_round->radius_x           = round->line_width / 2.0f;
        line_cap_round->radius_y           = round->line_width / 2.0f;

        if ((round->line_cap & LINE_CAP_START) == LINE_CAP_START) {
                const float dx0 = -outer_radius_x * sinf(round->start_angle);
                const float dy0 =  outer_radius_y * cosf(round->start_angle);
                const float tangent_angle = atan2f(dx0 * sin + dy0 * cos, dx0 * cos - dy0 * sin);

                line_cap_round->x                  = (inner_x1 + outer_x1) / 2.0f;
                line_cap_round->y                  = (inner_y1 + outer_y1) / 2.0f;
                line_cap_round->start_angle        = tangent_angle - M_PI_2 - angle_offset;
                line_cap_round->end_angle          = tangent_angle + M_PI_2 + angle_offset;
                line_cap_round->clockwise          = false;
                shape_vertex_populators[SHAPE_ROUND]((void *)&line_cap, request_geometry, populate_vertex);
        }

        if ((round->line_cap & LINE_CAP_END) == LINE_CAP_END) {
                const float dx0 = -outer_radius_x * sinf(round->end_angle);
                const float dy0 =  outer_radius_y * cosf(round->end_angle);
                const float tangent_angle = atan2f(dx0 * sin + dy0 * cos, dx0 * cos - dy0 * sin);

                line_cap_round->x                  = (inner_x2 + outer_x2) / 2.0f;
                line_cap_round->y                  = (inner_y2 + outer_y2) / 2.0f;
                line_cap_round->start_angle        = tangent_angle - M_PI_2 - angle_offset;
                line_cap_round->end_angle          = tangent_angle + M_PI_2 + angle_offset;
                line_cap_round->clockwise          = true;
                shape_vertex_populators[SHAPE_ROUND]((void *)&line_cap, request_geometry, populate_vertex);
        }
}

static void populate_rectangle_vertices(void *const data, const GeometryRequester request_geometry, const VertexPopulator populate_vertex) {
        struct Shape *const shape = (struct Shape *)data;
        ASSERT_ALL(shape != NULL, shape->type == SHAPE_RECTANGLE);

        if (shape->on_calibration != NULL) {
                shape->on_calibration(shape->callibration_data);
        }

        struct Rectangle *const rectangle = &shape->as.rectangle;
        CHECK_FINITE_POINT(rectangle->x, rectangle->y,          "Rectangle Position");
        CHECK_FINITE_POINT(rectangle->width, rectangle->height, "Rectangle Size");
        CHECK_FINITE_FLOAT(rectangle->line_width,               "Rectangle Line Width");
        CHECK_FINITE_FLOAT(rectangle->rotation,                 "Rectangle Rotation");
        CHECK_FINITE_FLOAT(rectangle->rounded_radius,           "Rectangle Rounded Radius");

        const float half_width  = rectangle->width  / 2.0f;
        const float half_height = rectangle->height / 2.0f;

        struct Shape rectangle_shape;
        initialize_shape(&rectangle_shape, SHAPE_QUADRILATERAL);
        struct Polygon *const rectangle_quadrilateral = &rectangle_shape.as.polygon;
        SET_SHAPE_COLOR_SHAPE(rectangle_quadrilateral,, rectangle,);
        rectangle_quadrilateral->rounded_radius = rectangle->rounded_radius;

        // Top Left
        rectangle_quadrilateral->x1 = rectangle->x - half_width;
        rectangle_quadrilateral->y1 = rectangle->y - half_height;
        ROTATE_POINT(rectangle_quadrilateral->x1, rectangle_quadrilateral->y1, rectangle->x, rectangle->y, rectangle->rotation);

        // Top Right
        rectangle_quadrilateral->x2 = rectangle->x + half_width;
        rectangle_quadrilateral->y2 = rectangle->y - half_height;
        ROTATE_POINT(rectangle_quadrilateral->x2, rectangle_quadrilateral->y2, rectangle->x, rectangle->y, rectangle->rotation);

        // Bottom Right
        rectangle_quadrilateral->x3 = rectangle->x + half_width;
        rectangle_quadrilateral->y3 = rectangle->y + half_height;
        ROTATE_POINT(rectangle_quadrilateral->x3, rectangle_quadrilateral->y3, rectangle->x, rectangle->y, rectangle->rotation);

        // Bottom Left
        rectangle_quadrilateral->x4 = rectangle->x - half_width;
        rectangle_quadrilateral->y4 = rectangle->y + half_height;
        ROTATE_POINT(rectangle_quadrilateral->x4, rectangle_quadrilateral->y4, rectangle->x, rectangle->y, rectangle->rotation);

        shape_vertex_populators[SHAPE_QUADRILATERAL]((void *)&rectangle_quadrilateral, request_geometry, populate_vertex);
}

static void populate_line_vertices(void *const data, const GeometryRequester request_geometry, const VertexPopulator populate_vertex) {
        struct Shape *const shape = (struct Shape *)data;
        ASSERT_ALL(shape != NULL, shape->type == SHAPE_LINE);

        if (shape->on_calibration != NULL) {
                shape->on_calibration(shape->callibration_data);
        }

        struct Path *const line = &shape->as.path;
        CHECK_FINITE_POINT(line->x1, line->y1, "Line Point A");
        CHECK_FINITE_POINT(line->x2, line->y2, "Line Point B");
        CHECK_FINITE_FLOAT(line->line_width,   "Line Line Width");

        const float dx = line->x2 - line->x1;
        const float dy = line->y2 - line->y1;
        const float length = sqrtf(dx * dx + dy * dy);
        if (length == 0.0f) {
                return;
        }

        const float nx = -(dy / length) * line->line_width / 2.0f;
        const float ny =  (dx / length) * line->line_width / 2.0f;

        struct Shape line_shape;
        initialize_shape(&line_shape, SHAPE_QUADRILATERAL);
        struct Polygon *const line_quadrilateral = &line_shape.as.polygon;
        SET_SHAPE_COLOR_SHAPE(line_quadrilateral,, line,);
        line_quadrilateral->x1                   = line->x1 + nx;
        line_quadrilateral->y1                   = line->y1 + ny;
        line_quadrilateral->x2                   = line->x2 + nx;
        line_quadrilateral->y2                   = line->y2 + ny;
        line_quadrilateral->x3                   = line->x2 - nx;
        line_quadrilateral->y3                   = line->y2 - ny;
        line_quadrilateral->x4                   = line->x1 - nx;
        line_quadrilateral->y4                   = line->y1 - ny;
        shape_vertex_populators[SHAPE_QUADRILATERAL]((void *)&line_quadrilateral, request_geometry, populate_vertex);

        if (line->line_cap == LINE_CAP_NONE) {
                return;
        }

        struct Shape line_cap;
        initialize_shape(&line_cap, SHAPE_ROUND);
        struct Round *const line_cap_round = &line_cap.as.round;
        SET_SHAPE_COLOR_SHAPE(line_cap_round, _fill, line,);
        line_cap_round->radius_x           = line->line_width / 2.0f;
        line_cap_round->radius_y           = line->line_width / 2.0f;
        line_cap_round->start_angle        = atan2f(line->y2 - line->y1, line->x2 - line->x1) + (float)M_PI_2;
        line_cap_round->end_angle          = atan2f(line->y2 - line->y1, line->x2 - line->x1) - (float)M_PI_2;

        if ((line->line_cap & LINE_CAP_START) == LINE_CAP_START) {
                line_cap_round->x         = line->x1;
                line_cap_round->y         = line->y1;
                line_cap_round->clockwise = false;
                shape_vertex_populators[SHAPE_ROUND]((void *)&line_cap, request_geometry, populate_vertex);
        }

        if ((line->line_cap & LINE_CAP_END) == LINE_CAP_END) {
                line_cap_round->x         = line->x2;
                line_cap_round->y         = line->y2;
                line_cap_round->clockwise = true;
                shape_vertex_populators[SHAPE_ROUND]((void *)&line_cap, request_geometry, populate_vertex);
        }
}

static inline void compute_bezier_point(
        const float interpolation,
        const float px1, const float py1, // Endpoint A
        const float cx1, const float cy1, // Control Point A
        const float cx2, const float cy2, // Control Point B
        const float px2, const float py2, // Endpoint B
        float *const out_x, float *const out_y
) {
        const float t = interpolation;
        const float u = 1.0f - t;
        const float tt = t * t;
        const float uu = u * u;
        const float uuu = uu * u;
        const float ttt = tt * t;

        *out_x = uuu * px1 + 3.0f * uu * t * cx1 + 3.0f * u * tt * cx2 + ttt * px2;
        *out_y = uuu * py1 + 3.0f * uu * t * cy1 + 3.0f * u * tt * cy2 + ttt * py2;
}

static inline void compute_bezier_tangent(
        const float interpolation,
        const float px1, const float py1, // Endpoint A
        const float cx1, const float cy1, // Control Point A
        const float cx2, const float cy2, // Control Point B
        const float px2, const float py2, // Endpoint B
        float *const out_dx, float *const out_dy
) {
        const float t = interpolation;
        const float u = 1.0f - t;
        *out_dx = 3.0f * u * u * (cx1 - px1)
                + 6.0f * u * t * (cx2 - cx1)
                + 3.0f * t * t * (px2 - cx2);
        *out_dy = 3.0f * u * u * (cy1 - py1)
                + 6.0f * u * t * (cy2 - cy1)
                + 3.0f * t * t * (py2 - cy2);
}

static void populate_bezier_curve_vertices(void *const data, const GeometryRequester request_geometry, const VertexPopulator populate_vertex) {
        struct Shape *const shape = (struct Shape *)data;
        ASSERT_ALL(shape != NULL, shape->type == SHAPE_BEZIER_CURVE);

        if (shape->on_calibration != NULL) {
                shape->on_calibration(shape->callibration_data);
        }

        struct Path *const bezier_curve = &shape->as.path;
        CHECK_FINITE_POINT(bezier_curve->x1,         bezier_curve->y1,         "Bezier Curve Endpoint A");
        CHECK_FINITE_POINT(bezier_curve->control_x1, bezier_curve->control_y1, "Bezier Curve Control Point A");
        CHECK_FINITE_POINT(bezier_curve->x2,         bezier_curve->y2,         "Bezier Curve Control Point B");
        CHECK_FINITE_POINT(bezier_curve->control_x2, bezier_curve->control_y2, "Bezier Curve Endpoint B");
        CHECK_FINITE_FLOAT(bezier_curve->line_width,                           "Bezier Curve Line Width");

        const float px1 = bezier_curve->x1;
        const float py1 = bezier_curve->y1;
        const float px2 = bezier_curve->x2;
        const float py2 = bezier_curve->y2;

        const float cx1 = bezier_curve->control_x1;
        const float cy1 = bezier_curve->control_y1;
        const float cx2 = bezier_curve->control_x2;
        const float cy2 = bezier_curve->control_y2;

#define DISTANCE(x1, y1, x2, y2) (sqrtf(((x2) - (x1)) * ((x2) - (x1)) + ((y2) - (y1)) * ((y2) - (y1))))

        const float curvature = (DISTANCE(px1, py1, cx1, cy1) + DISTANCE(cx1, cy1, cx2, cy2) + DISTANCE(cx2, cy2, px2, py2)) / DISTANCE(px1, py1, px2, py2);
        const size_t samples = curvature < 1.0f ? 5ULL : (size_t)(curvature * 5.0f);

        float x1 = px1, y1 = py1;
        float estimated_length = 0.0f;
        for (size_t index = 1ULL; index <= samples; ++index) {
                const float interpolation = (float)index / (float)samples;

                float x2, y2;
                compute_bezier_point(interpolation, px1, py1, cx1, cy1, cx2, cy2, px2, py2, &x2, &y2);
                estimated_length += DISTANCE(x1, y1, x2, y2);
                x1 = x2;
                y1 = y2;
        }

#undef DISTANCE

        const size_t resolution = (size_t)ceilf(estimated_length / GEOMETRY_SEGMENT_LENGTH);
        if (resolution == 0ULL) {
                return;
        }

        int *const indices = request_geometry((resolution + 1ULL) * 2ULL, resolution * 6ULL);

        float tx, ty;
        compute_bezier_tangent(0.0f, px1, py1, cx1, cy1, cx2, cy2, px2, py2, &tx, &ty);
        compute_bezier_point(0.0f, px1, py1, cx1, cy1, cx2, cy2, px2, py2, &x1, &y1);

        const float half_width = bezier_curve->line_width / 2.0f;

        float length = sqrtf(tx * tx + ty * ty);
        float nx = (length > 0.0f) ? (-ty / length) * half_width : 0.0f;
        float ny = (length > 0.0f) ? ( tx / length) * half_width : 0.0f;

        int l1 = VERTEX_INDEX(populate_vertex, x1 - nx, y1 - ny, bezier_curve->r, bezier_curve->g, bezier_curve->b, bezier_curve->a);
        int r1 = VERTEX_INDEX(populate_vertex, x1 + nx, y1 + ny, bezier_curve->r, bezier_curve->g, bezier_curve->b, bezier_curve->a);

        for (size_t index = 1ULL; index <= resolution; ++index) {
                const float interpolation = (float)index / (float)resolution;

                float x2, y2;
                compute_bezier_point(interpolation, px1, py1, cx1, cy1, cx2, cy2, px2, py2, &x2, &y2);
                compute_bezier_tangent(interpolation, px1, py1, cx1, cy1, cx2, cy2, px2, py2, &tx, &ty);

                length = sqrtf(tx * tx + ty * ty);
                nx = (length > 0.0f) ? (-ty / length) * half_width : 0.0f;
                ny = (length > 0.0f) ? ( tx / length) * half_width : 0.0f;

                const int l2 = VERTEX_INDEX(populate_vertex, x2 - nx, y2 - ny, bezier_curve->r, bezier_curve->g, bezier_curve->b, bezier_curve->a);
                const int r2 = VERTEX_INDEX(populate_vertex, x2 + nx, y2 + ny, bezier_curve->r, bezier_curve->g, bezier_curve->b, bezier_curve->a);

                indices[index * 6ULL + 0ULL] = l1;
                indices[index * 6ULL + 1ULL] = r1;
                indices[index * 6ULL + 2ULL] = l2;

                indices[index * 6ULL + 3ULL] = l2;
                indices[index * 6ULL + 4ULL] = r1;
                indices[index * 6ULL + 5ULL] = r2;

                l1 = l2;
                r1 = r2;
        }

        // TODO: Add support for line caps?
}