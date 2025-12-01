#include "Entity.h"

#include <assert.h>
#include <stddef.h>
#include <stdlib.h>
#include <errno.h>
#include <stdbool.h>

#include "Hexagons.h"
#include "Level.h"
#include "Animation.h"
#include "Geometry.h"
#include "Debug.h"
#include "Defines.h"
#include "Memory.h"
#include "Renderer.h"

struct Entity {
        struct Level *level;
        enum EntityType type;
        uint8_t last_column, last_row;
        uint8_t next_column, next_row;
        enum Orientation last_orientation;
        enum Orientation next_orientation;
        struct Animation recoiling;
        struct Animation moving;
        struct Animation turning;
        struct Animation scaling;
        struct Animation shaking;
        SDL_FPoint position;
        float angle;
        float scale;
        float radius;
        union {
                struct Player {
                        struct Shape shape;
                        struct Round *back_body_arc;
                        struct Round *front_body_arc;
                        struct Rectangle *center_body_strip;
                        struct Polygon *stinger;
                        struct Path *left_antenna_curve;
                        struct Path *right_antenna_curve;
                        struct Round *left_antenna_tip;
                        struct Round *right_antenna_tip;
                        struct Round *left_wing;
                        struct Round *right_wing;
                        float wings_angle;
                        struct Animation flapping;
                        struct Animation bouncing;
                        struct Animation focusing;
                        SDL_FPoint antenna_offset;
                        float float_time;
                        bool focused;
                        float focus;
                } player;
                struct Block {
                        struct Shape shape;
                        struct Hexagon *hexagon;
                } block;
        } as;
};

#define SETUP_ENTITY_SHAPE(entity_field, shape, shape_type, shape_field) \
        do {                                                             \
                initialize_shape(&(shape), (shape_type));                \
                (entity_field) = &(shape).as.shape_field;                 \
        } while (0)

#define PLAYER_CLOSED_WINGS_ANGLE (-(float)M_PI * 5.0f / 6.0f)
#define PLAYER_OPEN_WINGS_ANGLE   (-(float)M_PI * 4.0f / 6.0f)

#define PLAYER_FOCUSED_SCALE   (1.0f)
#define PLAYER_UNFOCUSED_SCALE (0.85f)

#define PULSE_ENTITY_SCALE(entity, scale)                                   \
        do {                                                                \
                (entity)->scaling.actions[0].keyframes.floats[1] = (scale); \
                restart_animation(&(entity)->scaling, 0ULL);                \
        } while (0);                                                        \

static void callibrate_player_entity(void *const data);

static void callibrate_block_entity(void *const data);

struct Entity *create_entity(struct Level *const level, const enum EntityType type, const uint8_t column, const uint8_t row, const enum Orientation orientation) {
        struct Entity *const entity = (struct Entity *)xmalloc(sizeof(struct Entity));
        entity->type = type;
        entity->level = level;
        entity->last_column = entity->next_column = column;
        entity->last_row = entity->next_row = row;
        entity->last_orientation = orientation;
        entity->next_orientation = orientation;
        entity->angle = orientation_angle(orientation);
        entity->scale = 1.0f;
        entity->radius = 0.0f;

        initialize_animation(&entity->recoiling, 2ULL);

        struct Action *const move_away = &entity->recoiling.actions[0];
        move_away->target.point_pointer = &entity->position;
        move_away->type = ACTION_POINT;
        move_away->easing = QUAD_OUT;
        move_away->lazy_start = true;
        move_away->duration = 150.0f;

        struct Action *const move_back = &entity->recoiling.actions[1];
        move_back->target.point_pointer = &entity->position;
        move_back->type = ACTION_POINT;
        move_back->easing = QUAD_IN;
        move_back->lazy_start = true;
        move_back->duration = 150.0f;

        initialize_animation(&entity->moving, 1ULL);
        struct Action *const moving_action = &entity->moving.actions[0];
        moving_action->target.point_pointer = &entity->position;
        moving_action->type = ACTION_POINT;
        moving_action->lazy_start = true;
        moving_action->duration = 100.0f;

        initialize_animation(&entity->turning, 1ULL);
        struct Action *const turning_action = &entity->turning.actions[0];
        turning_action->target.float_pointer = &entity->angle;
        turning_action->type = ACTION_FLOAT;
        turning_action->easing = SINE_OUT;
        turning_action->lazy_start = true;
        turning_action->duration = 100.0f;
        turning_action->offset = true;

        initialize_animation(&entity->scaling, 2ULL);

        struct Action *const scale_up = &entity->scaling.actions[0];
        scale_up->target.float_pointer = &entity->scale;
        scale_up->type = ACTION_FLOAT;
        scale_up->easing = QUAD_OUT;
        scale_up->lazy_start = true;
        scale_up->duration = 50.0f;

        struct Action *const scale_down = &entity->scaling.actions[1];
        scale_down->target.float_pointer = &entity->scale;
        scale_down->keyframes.floats[1] = 1.0f;
        scale_down->type = ACTION_FLOAT;
        scale_down->easing = SINE_IN;
        scale_down->lazy_start = true;
        scale_down->duration = 200.0f;

        if (entity->type == ENTITY_PLAYER) {
                struct Player *const player = &entity->as.player;
                player->wings_angle = PLAYER_CLOSED_WINGS_ANGLE;
                player->antenna_offset.x = 0.0f;
                player->antenna_offset.y = 0.0f;
                player->focus = PLAYER_UNFOCUSED_SCALE;
                player->focused = false;

                initialize_composite_shape(&player->shape, 10ULL);
                set_drawable_z_index(player->shape.drawable, Z_INDEX_PLAYER);
                player->shape.on_calibration = callibrate_player_entity;
                player->shape.callibration_data = (void *)entity;

                struct Shape *const shapes = player->shape.as.group.shapes;

                SETUP_ENTITY_SHAPE(player->back_body_arc, shapes[0], SHAPE_ROUND, round);
                SET_SHAPE_COLOR_MACROS(player->back_body_arc, _line, COLOR_BROWN, COLOR_OPAQUE);
                SET_SHAPE_COLOR_MACROS(player->back_body_arc, _fill, COLOR_YELLOW, COLOR_OPAQUE);
                player->back_body_arc->line_and_fill  = true;

                SETUP_ENTITY_SHAPE(player->front_body_arc, shapes[1], SHAPE_ROUND, round);
                SET_SHAPE_COLOR_MACROS(player->front_body_arc, _line, COLOR_BROWN, COLOR_OPAQUE);
                SET_SHAPE_COLOR_MACROS(player->front_body_arc, _fill, COLOR_YELLOW, COLOR_OPAQUE);
                player->front_body_arc->line_and_fill = true;

                SETUP_ENTITY_SHAPE(player->center_body_strip, shapes[2], SHAPE_RECTANGLE, rectangle);
                SET_SHAPE_COLOR_MACROS(player->center_body_strip,,          COLOR_BROWN,        COLOR_OPAQUE);

                SETUP_ENTITY_SHAPE(player->stinger, shapes[3], SHAPE_TRIANGLE, polygon);
                SET_SHAPE_COLOR_MACROS(player->stinger,, COLOR_BROWN, COLOR_OPAQUE);

                SETUP_ENTITY_SHAPE(player->left_antenna_curve, shapes[4], SHAPE_BEZIER_CURVE, path);
                SET_SHAPE_COLOR_MACROS(player->left_antenna_curve,, COLOR_BROWN, COLOR_OPAQUE);

                SETUP_ENTITY_SHAPE(player->right_antenna_curve, shapes[5], SHAPE_BEZIER_CURVE, path);
                SET_SHAPE_COLOR_MACROS(player->right_antenna_curve,, COLOR_BROWN, COLOR_OPAQUE);

                SETUP_ENTITY_SHAPE(player->left_antenna_tip, shapes[6], SHAPE_ROUND, round);
                SET_SHAPE_COLOR_MACROS(player->left_antenna_tip, _fill, COLOR_BROWN, COLOR_OPAQUE);

                SETUP_ENTITY_SHAPE(player->right_antenna_tip, shapes[7], SHAPE_ROUND, round);
                SET_SHAPE_COLOR_MACROS(player->right_antenna_tip, _fill, COLOR_BROWN, COLOR_OPAQUE);

                SETUP_ENTITY_SHAPE(player->left_wing, shapes[8], SHAPE_ROUND, round);
                SET_SHAPE_COLOR_MACROS(player->left_wing, _line, COLOR_BROWN, COLOR_OPAQUE);
                SET_SHAPE_COLOR_MACROS(player->left_wing, _fill, COLOR_LIGHT_YELLOW, COLOR_OPAQUE);
                player->left_wing->line_and_fill = true;

                SETUP_ENTITY_SHAPE(player->right_wing, shapes[9], SHAPE_ROUND, round);
                SET_SHAPE_COLOR_MACROS(player->right_wing, _line, COLOR_BROWN,COLOR_OPAQUE);
                SET_SHAPE_COLOR_MACROS(player->right_wing, _fill, COLOR_LIGHT_YELLOW, COLOR_OPAQUE);
                player->right_wing->line_and_fill = true;

                initialize_animation(&player->flapping, 2ULL);

                struct Action *const wings_opening = &player->flapping.actions[0];
                wings_opening->target.float_pointer = &player->wings_angle;
                wings_opening->keyframes.floats[0] = PLAYER_CLOSED_WINGS_ANGLE;
                wings_opening->keyframes.floats[1] = PLAYER_OPEN_WINGS_ANGLE;
                wings_opening->type = ACTION_FLOAT;
                wings_opening->easing = SINE_IN;
                wings_opening->duration = 60.0f;

                struct Action *const wings_closing = &player->flapping.actions[1];
                wings_closing->target.float_pointer = &player->wings_angle;
                wings_closing->keyframes.floats[0] = PLAYER_OPEN_WINGS_ANGLE;
                wings_closing->keyframes.floats[1] = PLAYER_CLOSED_WINGS_ANGLE;
                wings_closing->type = ACTION_FLOAT;
                wings_closing->easing = SINE_OUT;
                wings_closing->duration = 60.0f;
                wings_closing->delay = 30.0f;

                initialize_animation(&player->bouncing, 2ULL);

                struct Action *const bounce_away = &player->bouncing.actions[0];
                bounce_away->target.point_pointer = &player->antenna_offset;
                bounce_away->type = ACTION_POINT;
                bounce_away->easing = SINE_OUT;
                bounce_away->lazy_start = true;
                bounce_away->duration = 100.0f;

                struct Action *const bounce_back = &player->bouncing.actions[1];
                bounce_back->target.point_pointer = &player->antenna_offset;
                bounce_back->keyframes.points[1].x = 0.0f;
                bounce_back->keyframes.points[1].y = 0.0f;
                bounce_back->type = ACTION_POINT;
                bounce_back->easing = SINE_IN_OUT;
                bounce_back->lazy_start = true;
                bounce_back->duration = 100.0f;

                initialize_animation(&player->focusing, 1ULL);
                struct Action *const focusing_action = &player->focusing.actions[0];
                focusing_action->target.float_pointer = &player->focus;
                focusing_action->type = ACTION_FLOAT;
                focusing_action->easing = BACK_OUT;
                focusing_action->lazy_start = true;
                focusing_action->duration = 200.0f;
        }

        if (entity->type == ENTITY_BLOCK) {
                struct Block *const block = &entity->as.block;

                initialize_shape(&block->shape, SHAPE_HEXAGON);
                set_drawable_z_index(block->shape.drawable, Z_INDEX_BLOCK);
                block->shape.on_calibration = callibrate_block_entity;
                block->shape.callibration_data = (void *)entity;

                block->hexagon = &block->shape.as.hexagon;
                block->hexagon->thickness_mask = HEXAGON_THICKNESS_MASK_ALL;
                SET_SHAPE_COLOR_MACROS(block->hexagon, _thick, COLOR_GOLD,   COLOR_OPAQUE);
                SET_SHAPE_COLOR_MACROS(block->hexagon, _fill,  COLOR_YELLOW, COLOR_OPAQUE);
        }

        return entity;
}

void destroy_entity(struct Entity *const entity) {
        if (!entity) {
                send_message(MESSAGE_WARNING, "Given entity to destroy is NULL");
                return;
        }

        if (entity->type == ENTITY_PLAYER) {
                struct Player *const player = &entity->as.player;
                deinitialize_animation(&player->flapping);
                deinitialize_animation(&player->bouncing);
                deinitialize_animation(&player->focusing);
                deinitialize_shape(&player->shape);
        }

        if (entity->type == ENTITY_BLOCK) {
                struct Block *const block = &entity->as.block;
                deinitialize_shape(&block->shape);
        }

        deinitialize_animation(&entity->moving);
        deinitialize_animation(&entity->turning);
        deinitialize_animation(&entity->scaling);
        deinitialize_animation(&entity->recoiling);
        xfree(entity);
}

void update_entity(struct Entity *const entity, const double delta_time) {
        update_animation(&entity->moving, delta_time);
        update_animation(&entity->turning, delta_time);
        update_animation(&entity->scaling, delta_time);
        update_animation(&entity->recoiling, delta_time);

        if (entity->type == ENTITY_PLAYER) {
                struct Player *const player = &entity->as.player;

                update_animation(&player->flapping, delta_time);
                update_animation(&player->bouncing, delta_time);
                update_animation(&player->focusing, delta_time);

                player->float_time += delta_time / 500.0f;
                while (player->float_time >= 2.0f * (float)M_PI) {
                        player->float_time -= 2.0f * (float)M_PI;
                }
        }
}

void resize_entity(struct Entity *const entity, const float radius) {
        entity->radius = radius;

        if (entity->moving.active) {
                // If there is a moving animation, update the positions of the animation's start and end keyframes
                struct Action *const moving_action = &entity->moving.actions[0];
                query_level_tile(entity->level, entity->last_column, entity->last_row, NULL_X2, &moving_action->keyframes.points[0].x, &moving_action->keyframes.points[0].y);
                query_level_tile(entity->level, entity->next_column, entity->next_row, NULL_X2, &moving_action->keyframes.points[1].x, &moving_action->keyframes.points[1].y);
                return;
        }

        query_level_tile(entity->level, entity->next_column, entity->next_row, NULL_X2, &entity->position.x, &entity->position.y);
}

void query_entity(
        struct Entity *const entity,
        enum EntityType *const out_type,
        uint8_t *const out_column,
        uint8_t *const out_row,
        enum Orientation *const out_orientation,
        float *const out_x,
        float *const out_y
) {
        ASSERT_ALL(entity != NULL, out_type != NULL || out_column != NULL || out_row != NULL || out_orientation != NULL || out_x != NULL || out_y != NULL);
        SAFE_ASSIGNMENT(out_type, entity->type);
        SAFE_ASSIGNMENT(out_column, entity->next_column);
        SAFE_ASSIGNMENT(out_row, entity->next_row);
        SAFE_ASSIGNMENT(out_orientation, entity->next_orientation);
        SAFE_ASSIGNMENT(out_x, entity->position.x);
        SAFE_ASSIGNMENT(out_y, entity->position.y);
}

bool entity_can_change(const struct Entity *const entity) {
        if (entity->moving.active || entity->turning.active || entity->recoiling.active) {
                return false;
        }

        if (entity->type == ENTITY_PLAYER && entity->as.player.focusing.active) {
                return false;
        }

        return true;
}

void entity_handle_change(struct Entity *const entity, const struct Change *const change) {
        if (change->type == CHANGE_TURN) {
                entity->last_orientation = change->turn.last_orientation;
                entity->next_orientation = change->turn.next_orientation;

                entity->turning.actions[0].keyframes.floats[1] = (change->input == INPUT_RIGHT ? -1.0f : 1.0f) * (float)M_PI * 2.0f / 6.0f;
                start_animation(&entity->turning, 0ULL);
                PULSE_ENTITY_SCALE(entity, 1.1f);

                if (entity->type == ENTITY_PLAYER) {
                        struct Player *const player = &entity->as.player;

                        struct Action *const bounce_away = &player->bouncing.actions[0];
                        bounce_away->keyframes.points[1].x = 0.125f;
                        bounce_away->keyframes.points[1].y = change->input == INPUT_RIGHT ? 0.125f : -0.125f;
                        start_animation(&player->bouncing, 0ULL);
                }

                return;
        }

        if (change->type == CHANGE_BLOCKED || change->type == CHANGE_INVALID) {
                float x, y;
                query_level_tile(entity->level, entity->next_column, entity->next_row, NULL_X2, &x, &y);

                const float angle = -orientation_angle(change->face.direction);

                struct Action *const move_away = &entity->recoiling.actions[0];
                move_away->keyframes.points[1].x = x + cosf(angle) * entity->radius / 5.0f;
                move_away->keyframes.points[1].y = y + sinf(angle) * entity->radius / 5.0f;

                struct Action *const move_back = &entity->recoiling.actions[1];
                move_back->keyframes.points[1].x = x;
                move_back->keyframes.points[1].y = y;

                start_animation(&entity->recoiling, 0ULL);
                PULSE_ENTITY_SCALE(entity, 1.1f);

                if (entity->type == ENTITY_PLAYER && change->type != CHANGE_INVALID) {
                        struct Player *const player = &entity->as.player;
                        start_animation(&player->flapping, 0ULL);

                        struct Action *const bounce_away = &player->bouncing.actions[0];
                        bounce_away->keyframes.points[1].x = change->input == INPUT_FORWARD ? -0.125f : 0.125f;
                        bounce_away->keyframes.points[1].y = 0.0f;
                        start_animation(&player->bouncing, 0ULL);
                }

                return;
        }

        if (change->type == CHANGE_WALK || change->type == CHANGE_PUSH || change->type == CHANGE_PUSHED) {
                entity->last_column = change->move.last_column;
                entity->last_row    = change->move.last_row;
                entity->next_column = change->move.next_column;
                entity->next_row    = change->move.next_row;

                struct Action *const moving_action = &entity->moving.actions[0];
                query_level_tile(entity->level, entity->next_column, entity->next_row, NULL_X2, &moving_action->keyframes.points[1].x, &moving_action->keyframes.points[1].y);

                switch (change->type) {
                        case CHANGE_WALK: {
                                moving_action->easing = QUAD_IN_OUT;
                                break;
                        }

                        case CHANGE_PUSH: {
                                moving_action->easing = QUAD_OUT;
                                break;
                        }

                        case CHANGE_PUSHED: {
                                moving_action->easing = QUAD_IN;
                                break;
                        }

                        default: {
                                break;
                        }
                }

                start_animation(&entity->moving, 0ULL);
                PULSE_ENTITY_SCALE(entity, 1.2f);

                if (entity->type == ENTITY_PLAYER && change->type != CHANGE_PUSHED) {
                        struct Player *const player = &entity->as.player;
                        start_animation(&player->flapping, 0ULL);

                        struct Action *const bounce_away = &player->bouncing.actions[0];
                        bounce_away->keyframes.points[1].x = change->input == INPUT_FORWARD ? -0.25f : 0.25f;
                        bounce_away->keyframes.points[1].y = 0.0f;
                        start_animation(&player->bouncing, 0ULL);
                }
        }

        if (change->type == CHANGE_TOGGLE) {
                if (entity->type != ENTITY_PLAYER) {
                        send_message(MESSAGE_ERROR, "The toggle change can only be applied to player entities");
                        return;
                }

                struct Player *const player = &entity->as.player;
                player->focused = change->toggle.focused;

                player->focusing.actions[0].keyframes.floats[1] = player->focused ? PLAYER_FOCUSED_SCALE : PLAYER_UNFOCUSED_SCALE;
                start_animation(&player->focusing, 0ULL);
        }
}

static void callibrate_player_entity(void *const data) {
        struct Entity *const entity = (struct Entity *)data;
        ASSERT_ALL(entity != NULL && entity->type == ENTITY_PLAYER);

        struct Player *const player = &entity->as.player;
        ASSERT_ALL(player != NULL);

        const float float_fade = CLAMPED_VALUE((player->focus - PLAYER_UNFOCUSED_SCALE) / (PLAYER_FOCUSED_SCALE - PLAYER_UNFOCUSED_SCALE), 0.0f, 1.0f);
        const float float_x = float_fade * cosf(player->float_time) / 5.0f;
        const float float_y = float_fade * sinf(player->float_time) / 5.0f;
        const float float_angle = (float_x + float_y) / 2.5f;

        const float wings_angle = player->wings_angle + float_angle;
        const float rotation = entity->angle + float_angle;

        const float radius = entity->radius * entity->scale * player->focus;
        const float x = entity->position.x + (float_x * radius / 5.0f);
        const float y = entity->position.y + (float_y * radius / 5.0f);

        const float body_length = radius * 1.25f;
        const float body_thickness = radius / 1.5f;
        const float line_width = radius / 10.0f;

        player->back_body_arc->x           = x - body_length / 2.0f + body_thickness / 2.0f;
        player->back_body_arc->y           = y;
        player->front_body_arc->x          = x + body_length / 2.0f - body_thickness / 2.0f;
        player->front_body_arc->y          = y;
        player->back_body_arc->radius_x    =
        player->back_body_arc->radius_y    =
        player->front_body_arc->radius_x   =
        player->front_body_arc->radius_y   = body_thickness / 2.0f;
        player->back_body_arc->line_width  =
        player->front_body_arc->line_width = line_width;

        player->center_body_strip->x      = x;
        player->center_body_strip->y      = y;
        player->center_body_strip->width  = body_length - body_thickness;
        player->center_body_strip->height = body_thickness + line_width;

        player->stinger->x1 = x - body_length / 2.0f;
        player->stinger->y1 = y + line_width * 1.5f;
        player->stinger->x2 = x - body_length / 2.0f;
        player->stinger->y2 = y - line_width * 1.5f;
        player->stinger->x3 = x - body_length / 2.0f - line_width * 1.25f;
        player->stinger->y3 = y;

        player->left_antenna_curve->x1          = player->front_body_arc->x + body_thickness / 3.0f;
        player->left_antenna_curve->y1          = y - body_thickness / 3.0f;
        player->left_antenna_curve->x2          =
        player->left_antenna_tip->x             = player->front_body_arc->x + radius / 1.5f + radius * player->antenna_offset.x;
        player->left_antenna_curve->y2          =
        player->left_antenna_tip->y             = y - radius / 1.5f + radius * player->antenna_offset.y;
        player->left_antenna_curve->control_x1  = player->left_antenna_tip->x - line_width * 1.5f;
        player->left_antenna_curve->control_y1  = player->left_antenna_tip->y + body_thickness / 1.5f;
        player->left_antenna_curve->control_x2  = player->left_antenna_tip->x;
        player->left_antenna_curve->control_y2  = player->left_antenna_tip->y + body_thickness / 2.5f;
        player->right_antenna_curve->x1         = player->front_body_arc->x + body_thickness / 3.0f;
        player->right_antenna_curve->y1         = y + body_thickness / 3.0f;
        player->right_antenna_curve->x2         =
        player->right_antenna_tip->x            = player->front_body_arc->x + radius / 1.5f + radius * player->antenna_offset.x;
        player->right_antenna_curve->y2         =
        player->left_antenna_tip->y             = y - radius / 1.5f + radius * player->antenna_offset.y;
        player->right_antenna_curve->control_x1 = player->right_antenna_tip->x - line_width * 1.5f;
        player->right_antenna_curve->control_y1 = player->right_antenna_tip->y - body_thickness / 1.5f;
        player->right_antenna_curve->control_x2 = player->right_antenna_tip->x - line_width * 0.0f;
        player->right_antenna_curve->control_y2 = player->right_antenna_tip->y - body_thickness / 2.5f;

        const float wings_length = body_thickness - line_width;
        const float wings_thickness = (wings_length - line_width) / 2.0f;

        player->left_wing->radius_x = wings_length;
        player->left_wing->radius_y = wings_thickness;
        player->right_wing->radius_x = wings_length;
        player->right_wing->radius_y = wings_thickness;
        player->left_wing->line_width =
        player->right_wing->line_width = line_width;

        const float wings_anchor_x = player->front_body_arc->x - line_width * 1.5f;
        const float wings_anchor_y = y;

        player->left_wing->x =
        player->right_wing->x = wings_anchor_x + wings_length / 1.5f;
        player->left_wing->y =
        player->right_wing->y = wings_anchor_y;

        ROTATE_POINT(player->left_wing->x, player->left_wing->y, wings_anchor_x, wings_anchor_y, wings_angle);
        player->left_wing->y -= line_width;

        ROTATE_POINT(player->right_wing->x, player->right_wing->y, wings_anchor_x, wings_anchor_y, 2.0f * (float)M_PI - wings_angle);
        player->right_wing->y += line_width;

        // TODO: Store this in the struct?
        float *const vertex_pointers[][2] = {
                {&player->back_body_arc->x, &player->back_body_arc->y},
                {&player->front_body_arc->x, &player->front_body_arc->y},
                {&player->center_body_strip->x, &player->center_body_strip->y},
                {&player->stinger->x1, &player->stinger->y1},
                {&player->stinger->x2, &player->stinger->y2},
                {&player->stinger->x3, &player->stinger->y3},
                {&player->left_antenna_curve->x1, &player->left_antenna_curve->y1},
                {&player->left_antenna_curve->x2, &player->left_antenna_curve->y2},
                {&player->left_antenna_curve->control_x1, &player->left_antenna_curve->control_y1},
                {&player->left_antenna_curve->control_x2, &player->left_antenna_curve->control_y2},
                {&player->left_antenna_tip->x, &player->left_antenna_tip->y},
                {&player->right_antenna_curve->x1, &player->right_antenna_curve->y1},
                {&player->right_antenna_curve->x2, &player->right_antenna_curve->y2},
                {&player->right_antenna_curve->control_x1, &player->right_antenna_curve->control_y1},
                {&player->right_antenna_curve->control_x2, &player->right_antenna_curve->control_y2},
                {&player->right_antenna_tip->x, &player->right_antenna_tip->y},
                {&player->left_wing->x, &player->left_wing->y},
                {&player->right_wing->x, &player->right_wing->y},
        };

        for (size_t vertex_pointer_index = 0ULL; vertex_pointer_index < sizeof(vertex_pointers) / sizeof(vertex_pointers[0]); ++vertex_pointer_index) {
                ROTATE_POINT(*vertex_pointers[vertex_pointer_index][0], *vertex_pointers[vertex_pointer_index][1], x, y, -rotation);
        }
}

static void callibrate_block_entity(void *const data) {
        struct Entity *const entity = (struct Entity *)data;
        ASSERT_ALL(entity != NULL && entity->type == ENTITY_BLOCK);

        struct Block *const block = &entity->as.block;
        ASSERT_ALL(block != NULL);

        const float radius = entity->radius * entity->scale;
        const float thickness = radius / 5.0f;
        const float x = entity->position.x;
        const float y = entity->position.y - thickness / 2.0f;

        block->hexagon->x = x;
        block->hexagon->y = y;
        block->hexagon->radius = radius;
}