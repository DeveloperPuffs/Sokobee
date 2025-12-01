#pragma once

#include <stdint.h>
#include <stdbool.h>

#include "Hexagons.h"

enum EntityType {
        ENTITY_PLAYER = 0,
        ENTITY_BLOCK,
        ENTITY_COUNT
};

struct Level;
struct Entity;

struct Entity *create_entity(
        struct Level *const level,
        const enum EntityType type,
        const uint8_t column,
        const uint8_t row,
        const enum Orientation orientation
);

void destroy_entity(struct Entity *const entity);

void update_entity(struct Entity *const entity, const double delta_time);

void resize_entity(struct Entity *const entity, const float radius);

void query_entity(
        struct Entity *const entity,
        enum EntityType *const out_type,
        uint8_t *const out_column,
        uint8_t *const out_row,
        enum Orientation *const out_orientation,
        float *const out_x,
        float *const out_y
);

struct Change;

bool entity_can_change(const struct Entity *const entity);

void entity_handle_change(struct Entity *const entity, const struct Change *const change);