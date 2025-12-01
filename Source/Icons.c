/*
#include "Icons.h"

#include "Debug.h"
#include "Geometry.h"
#include "Defines.h"
#include <stdint.h>

struct Icon {
        enum IconType type;
        float rotation;
        float size;
        float x;
        float y;
        struct Shape shape;
};

// All icons are brown (currently)
#define SETUP_ICON_COLOR(icon_field, color_suffix) \
        SET_SHAPE_COLOR_MACROS(&(icon_field), color_suffix, COLOR_BROWN, COLOR_OPAQUE)

static void calibrate_icon(void *);

struct Icon *create_icon(const enum IconType type) {
        struct Icon *const icon = (struct Icon *)xmalloc(sizeof(struct Icon));
        icon->type             = type;
        icon->rotation         =
        icon->size             =
        icon->x = icon->y      = 0.0f;

        switch (icon->type) {
                case ICON_PLAY: {
                        initialize_shape(&icon->shape, SHAPE_TRIANGLE);
                        SETUP_ICON_COLOR(icon->shape.as.polygon,);
                        break;
                }

                case ICON_UNDO: case ICON_REDO: {
                        initialize_composite_shape(&icon->shape, 2ULL);
                        struct Shape *const shapes = icon->shape.as.group.shapes;

                        initialize_shape(&shapes[0], SHAPE_BEZIER_CURVE);
                        SETUP_ICON_COLOR(shapes[0].as.path,);

                        initialize_shape(&shapes[1], SHAPE_TRIANGLE);
                        SETUP_ICON_COLOR(shapes[1].as.polygon,);
                        break;
                }

                case ICON_RESTART: {
                        initialize_composite_shape(&icon->shape, 2ULL);
                        struct Shape *const shapes = icon->shape.as.group.shapes;

                        initialize_shape(&shapes[0], SHAPE_ROUND);
                        SETUP_ICON_COLOR(shapes[0].as.round, _line);
                        shapes[0].as.round.start_angle = (float)M_PI / -4.0f;
                        shapes[0].as.round.end_angle = (float)M_PI / 8.0f;
                        shapes[0].as.round.clockwise = true;
                        shapes[0].as.round.line_cap = LINE_CAP_END;

                        initialize_shape(&shapes[1], SHAPE_TRIANGLE);
                        SETUP_ICON_COLOR(shapes[1].as.polygon,);
                        break;
                }

                case ICON_EXIT: {
                        initialize_composite_shape(&icon->shape, 11ULL);
                        struct Shape *const shapes = icon->shape.as.group.shapes;

                        // Lines: 0, 1, 2, 3, 4, 5
                        // Arcs: 6, 7, 8, 9
                        // 6----0----7
                        // |         |
                        // |         3
                        // |         |
                        // |
                        // 1    -----5---->
                        // |
                        // |         |
                        // |         4
                        // |         |
                        // 8----2----9

                        for (uint8_t line_index = 0; line_index < 6; ++line_index) {
                                initialize_shape(&shapes[line_index], SHAPE_LINE);
                                SETUP_ICON_COLOR(shapes[line_index].as.path,);
                        }

                        shapes[3].as.path.line_cap = LINE_CAP_END;
                        shapes[4].as.path.line_cap = LINE_CAP_END;
                        shapes[5].as.path.line_cap = LINE_CAP_START;

                        for (uint8_t arc_index = 0; arc_index < 4; ++arc_index) {
                                initialize_shape(&shapes[arc_index + 6], SHAPE_LINE);
                                SETUP_ICON_COLOR(shapes[arc_index + 6].as.round, _fill);
                        }

                        shapes[6].as.round.start_angle = -M_PI_2;
                        shapes[6].as.round.end_angle = M_PI;
                        shapes[6].as.round.clockwise = true;

                        shapes[7].as.round.start_angle = -M_PI;
                        shapes[7].as.round.end_angle = M_PI_2;
                        shapes[7].as.round.clockwise = true;

                        shapes[8].as.round.start_angle = 0.0f;
                        shapes[8].as.round.end_angle = M_PI_2 * 3.0f;
                        shapes[8].as.round.clockwise = true;

                        shapes[9].as.round.start_angle = M_PI_2;
                        shapes[9].as.round.end_angle = M_PI * 2.0f;
                        shapes[9].as.round.clockwise = true;

                        initialize_shape(&shapes[10], SHAPE_TRIANGLE);
                        SETUP_ICON_COLOR(shapes[10].as.polygon,);
                        break;
                }

                case ICON_SOUNDS_ON: {
                        break;
                }

                case ICON_SOUNDS_OFF: {
                        break;
                }

                case ICON_MUSIC_ON: {
                        break;
                }

                case ICON_MUSIC_OFF: {
                        break;
                }

                default: {
                        break;
                }
        }

        icon->shape.callibration_data = (void *)icon;
        icon->shape.on_calibration = calibrate_icon;
        return icon;
}

void destroy_icon(struct Icon *const icon) {
        if (!icon) {
                send_message(MESSAGE_WARNING, "Icon given to destroy is NULL");
                return;
        }

        deinitialize_shape(&icon->shape);
        xfree(icon);
}

void set_icon_type(struct Icon *const icon, const enum IconType type) {
        if (icon->type == type) {
                return;
        }

        icon->type = type;
        icon->shape.on_calibration = calibrate_icon;
}

void set_icon_size(struct Icon *const icon, const float size) {
        if (icon->size == size) {
                return;
        }

        icon->size = size;
        icon->shape.on_calibration = calibrate_icon;
}

void set_icon_position(struct Icon *const icon, const float x, const float y) {
        if (icon->x == x && icon->y == y) {
                return;
        }

        icon->x = x;
        icon->y = y;
        icon->shape.on_calibration = calibrate_icon;
}

void set_icon_rotation(struct Icon *const icon, const float rotation) {
        if (icon->rotation == rotation) {
                return;
        }

        icon->rotation = rotation;
        icon->shape.on_calibration = calibrate_icon;
}

#define SET_ICON_POSITION(value_x, value_y, field_x, field_y)                         \
        do {                                                                          \
                (field_x) = icon->x + icon->size * ((value_x) - 0.5f);                \
                (field_y) = icon->y + icon->size * ((value_y) - 0.5f);                \
                ROTATE_POINT((field_x), (field_y), icon->x, icon->y, icon->rotation); \
        } while (0)

static void calibrate_icon(void *const data) {
        struct Icon *const icon = (struct Icon *)data;
        ASSERT_ALL(icon != NULL && icon->type != ICON_COUNT);

        icon->shape.on_calibration = NULL;

        switch (icon->type) {
                case ICON_PLAY: {
                        SET_ICON_POSITION(0.75f, 0.00f, icon->shape.as.polygon.x1, icon->shape.as.polygon.y1);
                        SET_ICON_POSITION(0.00f, 0.50f, icon->shape.as.polygon.x2, icon->shape.as.polygon.y2);
                        SET_ICON_POSITION(0.75f, 1.00f, icon->shape.as.polygon.x3, icon->shape.as.polygon.y3);
                        icon->shape.as.polygon.rounded_radius = icon->size / 15.0f;
                        break;
                }

                case ICON_UNDO: {
                        // TODO: Bezier curve line cap on end w/o triangle
                        struct Shape *const shapes = icon->shape.as.group.shapes;
                        SET_ICON_POSITION(0.40f, 0.40f, shapes[0].as.path.x1, shapes[0].as.path.y1);
                        SET_ICON_POSITION(0.80f, 0.80f, shapes[0].as.path.x2, shapes[0].as.path.y2);
                        SET_ICON_POSITION(0.65f, 0.40f, shapes[0].as.path.control_x1, shapes[0].as.path.control_y1);
                        SET_ICON_POSITION(0.80f, 0.55f, shapes[0].as.path.control_x2, shapes[0].as.path.control_y2);
                        shapes[0].as.path.line_width = icon->size / 10.0f;
                        SET_ICON_POSITION(0.40f, 0.15f, shapes[1].as.polygon.x1, shapes[1].as.polygon.y1);
                        SET_ICON_POSITION(0.00f, 0.40f, shapes[1].as.polygon.x2, shapes[1].as.polygon.y2);
                        SET_ICON_POSITION(0.40f, 0.65f, shapes[1].as.polygon.x3, shapes[1].as.polygon.y3);
                        shapes[1].as.polygon.rounded_radius = icon->size / 20.0f;
                        break;
                }

                case ICON_REDO: {
#define FLIP 1.0f -
                        // TODO: Bezier curve line cap on end w/o triangle
                        struct Shape *const shapes = icon->shape.as.group.shapes;
                        SET_ICON_POSITION(FLIP 0.40f, 0.40f, shapes[0].as.path.x1, shapes[0].as.path.y1);
                        SET_ICON_POSITION(FLIP 0.80f, 0.80f, shapes[0].as.path.x2, shapes[0].as.path.y2);
                        SET_ICON_POSITION(FLIP 0.65f, 0.40f, shapes[0].as.path.control_x1, shapes[0].as.path.control_y1);
                        SET_ICON_POSITION(FLIP 0.80f, 0.55f, shapes[0].as.path.control_x2, shapes[0].as.path.control_y2);
                        shapes[0].as.path.line_width = icon->size / 10.0f;
                        SET_ICON_POSITION(FLIP 0.40f, 0.15f, shapes[1].as.polygon.x1, shapes[1].as.polygon.y1);
                        SET_ICON_POSITION(FLIP 0.00f, 0.40f, shapes[1].as.polygon.x2, shapes[1].as.polygon.y2);
                        SET_ICON_POSITION(FLIP 0.40f, 0.65f, shapes[1].as.polygon.x3, shapes[1].as.polygon.y3);
                        shapes[1].as.polygon.rounded_radius = icon->size / 20.0f;
                        break;
#undef FLIP
                }

                case ICON_RESTART: {
#define FLIP 1.0f -
                        struct Shape *const shapes = icon->shape.as.group.shapes;
                        shapes[0].as.round.radius_x = icon->size / 3.0f;
                        shapes[0].as.round.radius_y = icon->size / 3.0f;
                        shapes[0].as.round.x = icon->x;
                        shapes[0].as.round.y = icon->y;
                        shapes[0].as.round.line_width = icon->size / 10.0f;
                        SET_ICON_POSITION(FLIP 0.25f, 0.00f, shapes[1].as.polygon.x1, shapes[1].as.polygon.y1);
                        SET_ICON_POSITION(FLIP 0.00f, 0.40f, shapes[1].as.polygon.x2, shapes[1].as.polygon.y2);
                        SET_ICON_POSITION(FLIP 0.40f, 0.45f, shapes[1].as.polygon.x3, shapes[1].as.polygon.y3);
                        shapes[1].as.polygon.rounded_radius = icon->size / 25.0f;
                        break;
#undef FLIP
                }

                case ICON_EXIT: {
                        struct Shape *const shapes = icon->shape.as.group.shapes;

                        // Lines: 0, 1, 2, 3, 4, 5
                        // Arcs: 6, 7, 8, 9
                        // 6----0----7
                        // |         |
                        // |         3
                        // |         |
                        // |
                        // 1    -----5---->
                        // |
                        // |         |
                        // |         4
                        // |         |
                        // 8----2----9

                        const float line_width = icon->size / 10.0f;

                        float tlx, tly; // tl - Top Left
                        float trx, try; // tr - Top Right
                        float blx, bly; // bl - Bottom Left
                        float brx, bry; // br - Bottom Right
                        float tox, toy; // to - Top Opening
                        float box, boy; // bo - Bottom Opening
                        SET_ICON_POSITION(0.15f, 0.15f, tlx, tly);
                        SET_ICON_POSITION(0.60f, 0.15f, trx, try);
                        SET_ICON_POSITION(0.15f, 0.85f, blx, bly);
                        SET_ICON_POSITION(0.60f, 0.85f, brx, bry);
                        SET_ICON_POSITION(0.60f, 0.35f, tox, toy);
                        SET_ICON_POSITION(0.60f, 0.65f, box, boy);

                        float cx, cy; // Center Position
                        SET_ICON_POSITION(0.15f + (0.6f - 0.15f) / 2.0f, 0.15f + (0.85f - 0.15f) / 2.0f, cx, cy);

        write_line_geometry(icon->geometry, tlx, tly + line_width / 2.0f, blx, bly - line_width / 2.0f, line_width, LINE_CAP_NONE);
        write_line_geometry(icon->geometry, tlx + line_width / 2.0f, tly, trx - line_width / 2.0f, try, line_width, LINE_CAP_NONE);
        write_line_geometry(icon->geometry, blx + line_width / 2.0f, bly, brx - line_width / 2.0f, bry, line_width, LINE_CAP_NONE);

        write_line_geometry(icon->geometry, trx, try + line_width / 2.0f, tox, toy - line_width / 2.0f, line_width, LINE_CAP_END);
        write_line_geometry(icon->geometry, brx, bry - line_width / 2.0f, box, boy + line_width / 2.0f, line_width, LINE_CAP_END);

        write_line_geometry(icon->geometry, cx, cy, cx - line_width / 2.0f + (trx - tlx), cy, line_width, LINE_CAP_START);

        write_circular_arc_geometry(icon->geometry, tlx + line_width / 2.0f, tly + line_width / 2.0f, line_width, -M_PI_2, M_PI, true);
        write_circular_arc_geometry(icon->geometry, blx + line_width / 2.0f, bly - line_width / 2.0f, line_width, -M_PI, M_PI_2, true);
        write_circular_arc_geometry(icon->geometry, trx - line_width / 2.0f, try + line_width / 2.0f, line_width, 0.0f, M_PI_2 * 3.0f, true);
        write_circular_arc_geometry(icon->geometry, brx - line_width / 2.0f, bry - line_width / 2.0f, line_width, M_PI_2, M_PI * 2.0f, true);

                        shapes[0].as.path.x1 = tlx;
                        shapes[0].as.path.y1 = tly + line_width / 2.0f;
                        shapes[0].as.path.x2 = blx;
                        shapes[0].as.path.y2 = line_width / 2.0f;

                        shapes[1].as.path.x1 = tlx + line_width / 2.0f;
                        shapes[1].as.path.y1 = tly;
                        shapes[1].as.path.x2 = trx - line_width / 2.0f;
                        shapes[1].as.path.y2 = try;

                        shapes[2].as.path.x1 = trx;
                        shapes[2].as.path.y1 = tly + line_width / 2.0f;
                        shapes[2].as.path.x2 = blx;
                        shapes[2].as.path.y2 = line_width / 2.0f;

                        shapes[3].as.path.x1 = tlx;
                        shapes[3].as.path.y1 = tly + line_width / 2.0f;
                        shapes[3].as.path.x2 = blx;
                        shapes[3].as.path.y2 = line_width / 2.0f;

                        for (uint8_t line_index = 0; line_index < 6; ++line_index) {
                                shapes[line_index].as.path.line_width = line_width;
                        }

                        for (uint8_t arc_index = 0; arc_index < 4; ++arc_index) {
                                shapes[arc_index + 6].as.round.radius_x = line_width;
                                shapes[arc_index + 6].as.round.radius_y = line_width;
                        }

                        SET_ICON_POSITION(0.75f, 0.25f, shapes[10].as.polygon.x1, shapes[10].as.polygon.y1);
                        SET_ICON_POSITION(1.00f, 0.50f, shapes[10].as.polygon.x2, shapes[10].as.polygon.y2);
                        SET_ICON_POSITION(0.75f, 0.75f, shapes[10].as.polygon.x3, shapes[10].as.polygon.y3);
                        shapes[0].as.polygon.rounded_radius = line_width / 2.0f;
                        break;
                }

                case ICON_SOUNDS_ON: {
                        break;
                }

                case ICON_SOUNDS_OFF: {
                        break;
                }

                case ICON_MUSIC_ON: {
                        break;
                }

                case ICON_MUSIC_OFF: {
                        break;
                }

                default: {
                        break;
                }
        }
}

static void write_exit_icon_geometry(struct Icon *const icon) {
        const float line_width = icon->size / 10.0f;

        // tl - Top Left
        // tr - Top Right
        // bl - Bottom Left
        // br - Bottom Right
        // to - Top Opening
        // bo - Bottom Opening

        float tlx = 0.15f, tly = 0.15f;
        float trx = 0.6f,  try = 0.15f;
        float blx = 0.15f, bly = 0.85f;
        float brx = 0.6f,  bry = 0.85f;
        float tox = 0.6f,  toy = 0.35f;
        float box = 0.6f,  boy = 0.65f;
        transform_icon_point(icon, &tlx, &tly);
        transform_icon_point(icon, &trx, &try);
        transform_icon_point(icon, &blx, &bly);
        transform_icon_point(icon, &brx, &bry);
        transform_icon_point(icon, &tox, &toy);
        transform_icon_point(icon, &box, &boy);

        // Center
        float cx = 0.15f + (0.6f - 0.15f) / 2.0f, cy = 0.15f + (0.85f - 0.15f) / 2.0f;
        transform_icon_point(icon, &cx, &cy);

        // Tip Triangle Vertices
        float x1 = 0.75f, y1 = 0.25f, x2 = 1.0f, y2 = 0.5f, x3 = 0.75f, y3 = 0.75f;
        transform_icon_point(icon, &x1, &y1);
        transform_icon_point(icon, &x2, &y2);
        transform_icon_point(icon, &x3, &y3);

        clear_geometry(icon->geometry);

        write_line_geometry(icon->geometry, tlx, tly + line_width / 2.0f, blx, bly - line_width / 2.0f, line_width, LINE_CAP_NONE);
        write_line_geometry(icon->geometry, tlx + line_width / 2.0f, tly, trx - line_width / 2.0f, try, line_width, LINE_CAP_NONE);
        write_line_geometry(icon->geometry, blx + line_width / 2.0f, bly, brx - line_width / 2.0f, bry, line_width, LINE_CAP_NONE);

        write_line_geometry(icon->geometry, trx, try + line_width / 2.0f, tox, toy - line_width / 2.0f, line_width, LINE_CAP_END);
        write_line_geometry(icon->geometry, brx, bry - line_width / 2.0f, box, boy + line_width / 2.0f, line_width, LINE_CAP_END);

        write_line_geometry(icon->geometry, cx, cy, cx - line_width / 2.0f + (trx - tlx), cy, line_width, LINE_CAP_START);

        write_circular_arc_geometry(icon->geometry, tlx + line_width / 2.0f, tly + line_width / 2.0f, line_width, -M_PI_2, M_PI, true);
        write_circular_arc_geometry(icon->geometry, blx + line_width / 2.0f, bly - line_width / 2.0f, line_width, -M_PI, M_PI_2, true);
        write_circular_arc_geometry(icon->geometry, trx - line_width / 2.0f, try + line_width / 2.0f, line_width, 0.0f, M_PI_2 * 3.0f, true);
        write_circular_arc_geometry(icon->geometry, brx - line_width / 2.0f, bry - line_width / 2.0f, line_width, M_PI_2, M_PI * 2.0f, true);

        write_rounded_triangle_geometry(icon->geometry, x1, y1, x2, y2, x3, y3, line_width / 2.0f);
}

static inline void write_speaker_geometry(struct Icon *const icon) {
        float x1 = 0.10, y1 = 0.35;
        float x2 = 0.35, y2 = 0.35;
        float x3 = 0.35, y3 = 0.65;
        float x4 = 0.10, y4 = 0.65;
        transform_icon_point(icon, &x1, &y1);
        transform_icon_point(icon, &x2, &y2);
        transform_icon_point(icon, &x3, &y3);
        transform_icon_point(icon, &x4, &y4);

        float x5 = 0.15, y5 = 0.5;
        float x6 = 0.5,  y6 = 0.1;
        float x7 = 0.5,  y7 = 0.9;
        transform_icon_point(icon, &x5, &y5);
        transform_icon_point(icon, &x6, &y6);
        transform_icon_point(icon, &x7, &y7);

        const float rounded_radius = icon->size / 20.0f;

        write_rounded_quadrilateral_geometry(icon->geometry, x1, y1, x2, y2, x3, y3, x4, y4, rounded_radius);
        write_rounded_triangle_geometry(     icon->geometry, x5, y5, x6, y6, x7, y7,         rounded_radius);
}

static void write_sounds_on_icon_geometry(struct Icon *const icon) {
        float x = 0.5, y = 0.5;
        transform_icon_point(icon, &x, &y);

        clear_geometry(icon->geometry);
        write_speaker_geometry(icon);

        static const float start_angle = M_PI_2 - M_PI_4;
        static const float end_angle   = M_PI + M_PI_2 + M_PI_4;

        const float radius_x   = icon->size / 10.0f;
        const float radius_y   = icon->size /  9.0f;
        const float line_width = icon->size / 10.0f;

        write_elliptical_arc_outline_geometry(icon->geometry, x, y, radius_x * 1.0f, radius_y * 1.0f, 0.0f, line_width, start_angle, end_angle, true, LINE_CAP_BOTH);
        write_elliptical_arc_outline_geometry(icon->geometry, x, y, radius_x * 2.5f, radius_y * 2.5f, 0.0f, line_width, start_angle, end_angle, true, LINE_CAP_BOTH);
        write_elliptical_arc_outline_geometry(icon->geometry, x, y, radius_x * 4.0f, radius_y * 4.0f, 0.0f, line_width, start_angle, end_angle, true, LINE_CAP_BOTH);
}

static void write_sounds_off_icon_geometry(struct Icon *const icon) {
        float x1 = 0.6, y1 = 0.35;
        float x2 = 0.9, y2 = 0.65;
        float x3 = 0.6, y3 = 0.65;
        float x4 = 0.9, y4 = 0.35;
        transform_icon_point(icon, &x1, &y1);
        transform_icon_point(icon, &x2, &y2);
        transform_icon_point(icon, &x3, &y3);
        transform_icon_point(icon, &x4, &y4);

        clear_geometry(icon->geometry);
        write_speaker_geometry(icon);

        const float line_width = icon->size / 10.0f;

        write_line_geometry(icon->geometry, x1, y1, x2, y2, line_width, LINE_CAP_BOTH);
        write_line_geometry(icon->geometry, x3, y3, x4, y4, line_width, LINE_CAP_BOTH);
}

static void write_music_note_geometry(struct Icon *const icon) {
        float x1 = 0.25, y1 = 0.2;
        float x2 = 0.25, y2 = 0.4;
        float x3 = 0.85, y3 = 0.3;
        float x4 = 0.85, y4 = 0.1;
        transform_icon_point(icon, &x1, &y1);
        transform_icon_point(icon, &x2, &y2);
        transform_icon_point(icon, &x3, &y3);
        transform_icon_point(icon, &x4, &y4);

        float x5 = 0.3, y5 = 0.25;
        float x6 = 0.3, y6 = 0.8;
        transform_icon_point(icon, &x5, &y5);
        transform_icon_point(icon, &x6, &y6);

        float x7 = 0.8, y7 = 0.15;
        float x8 = 0.8, y8 = 0.7;
        transform_icon_point(icon, &x7, &y7);
        transform_icon_point(icon, &x8, &y8);

        float x9  = 0.725, y9  = 0.7;
        float x10 = 0.225, y10 = 0.8;
        transform_icon_point(icon,  &x9,  &y9);
        transform_icon_point(icon, &x10, &y10);

        const float line_width     = icon->size / 10.0f;
        const float radius_x       = icon->size /  7.5f;
        const float radius_y       = icon->size / 10.0f;
        const float rounded_radius = icon->size / 20.0f;

        write_rounded_quadrilateral_geometry(icon->geometry, x1, y1, x2, y2, x3, y3, x4, y4, rounded_radius);

        write_line_geometry(icon->geometry, x5, y5, x6, y6, line_width, LINE_CAP_NONE);
        write_line_geometry(icon->geometry, x7, y7, x8, y8, line_width, LINE_CAP_NONE);

        write_ellipse_geometry(icon->geometry,  x9,  y9, radius_x, radius_y, M_PI_4 / -2.0f);
        write_ellipse_geometry(icon->geometry, x10, y10, radius_x, radius_y, M_PI_4 / -2.0f);
}

static void write_music_on_icon_geometry(struct Icon *const icon) {
        clear_geometry(icon->geometry);
        write_music_note_geometry(icon);
}

static void write_music_off_icon_geometry(struct Icon *const icon) {
        float x1 = 0.15, y1 = 0.15;
        float x2 = 0.85, y2 = 0.85;
        transform_icon_point(icon, &x1, &y1);
        transform_icon_point(icon, &x2, &y2);

        clear_geometry(icon->geometry);
        write_music_note_geometry(icon);

        const float line_width = icon->size / 10.0f;

        write_line_geometry(icon->geometry, x1, y1, x2, y2, line_width, LINE_CAP_BOTH);
}
*/