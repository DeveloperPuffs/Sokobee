#pragma once

#include "Debug.h"
#include "Defines.h"
#include "Geometry.h"

enum Orientation {
        UPPER_RIGHT,
        UPPER_MIDDLE,
        UPPER_LEFT,
        LOWER_LEFT,
        LOWER_MIDDLE,
        LOWER_RIGHT
};

static inline float orientation_angle(const enum Orientation orientation) {
        switch (orientation) {
                case UPPER_RIGHT:  return (float)M_PI * 1.0f  / 6.0f;
                case UPPER_MIDDLE: return (float)M_PI * 3.0f  / 6.0f;
                case UPPER_LEFT:   return (float)M_PI * 5.0f  / 6.0f;
                case LOWER_LEFT:   return (float)M_PI * 7.0f  / 6.0f;
                case LOWER_MIDDLE: return (float)M_PI * 9.0f  / 6.0f;
                case LOWER_RIGHT:  return (float)M_PI * 11.0f / 6.0f;
        }
}

static inline enum Orientation orientation_turn_left(const enum Orientation orientation) {
        switch (orientation) {
                case UPPER_RIGHT:  return UPPER_MIDDLE;
                case UPPER_MIDDLE: return UPPER_LEFT;
                case UPPER_LEFT:   return LOWER_LEFT;
                case LOWER_LEFT:   return LOWER_MIDDLE;
                case LOWER_MIDDLE: return LOWER_RIGHT;
                case LOWER_RIGHT:  return UPPER_RIGHT;
        }
}

static inline enum Orientation orientation_turn_right(const enum Orientation orientation) {
        switch (orientation) {
                case UPPER_RIGHT:  return LOWER_RIGHT;
                case UPPER_MIDDLE: return UPPER_RIGHT;
                case UPPER_LEFT:   return UPPER_MIDDLE;
                case LOWER_LEFT:   return UPPER_LEFT;
                case LOWER_MIDDLE: return LOWER_LEFT;
                case LOWER_RIGHT:  return LOWER_MIDDLE;
        }
}

static inline enum Orientation orientation_reverse(const enum Orientation orientation) {
        switch (orientation) {
                case UPPER_RIGHT:  return LOWER_LEFT;
                case UPPER_MIDDLE: return LOWER_MIDDLE;
                case UPPER_LEFT:   return LOWER_RIGHT;
                case LOWER_LEFT:   return UPPER_RIGHT;
                case LOWER_MIDDLE: return UPPER_MIDDLE;
                case LOWER_RIGHT:  return UPPER_LEFT;
        }
}

static inline bool orientation_advance(
        const enum Orientation orientation,
        const size_t column,
        const size_t row,
        const size_t columns,
        const size_t rows,
        size_t *const out_column,
        size_t *const out_row
) {
        ASSERT_ALL(out_column != NULL || out_row != NULL);

        intmax_t next_column = (intmax_t)column;
        intmax_t next_row    = (intmax_t)row;

        switch (orientation) {
                case UPPER_RIGHT: {
                        ++next_column;

                        if (!(column & 1)) {
                                --next_row;
                        }

                        break;
                }

                case UPPER_MIDDLE: {
                        --next_row;
                        break;
                }

                case UPPER_LEFT: {
                        --next_column;

                        if (!(column & 1)) {
                                --next_row;
                        }

                        break;
                }

                case LOWER_LEFT: {
                        --next_column;

                        if (column & 1) {
                                ++next_row;
                        }

                        break;
                }

                case LOWER_MIDDLE: {
                        ++next_row;
                        break;
                }

                case LOWER_RIGHT: {
                        ++next_column;

                        if (column & 1) {
                                ++next_row;
                        }

                        break;
                }
        }

        if (next_column < 0 || next_row < 0 || next_column >= (intmax_t)columns || next_row >= (intmax_t)rows) {
                return false;
        }

        if (out_column != NULL) {
                *out_column = (size_t)next_column;
        }

        if (out_row != NULL) {
                *out_row = (size_t)next_row;
        }

        return true;
}

struct GridMetrics {
        size_t columns;
        size_t rows;
        size_t tile_count;
        float tile_radius;
        float bounding_width;
        float bounding_height;
        float bounding_x;
        float bounding_y;
        float grid_width;
        float grid_height;
        float grid_x;
        float grid_y;
        float tile_distance_x;
        float tile_distance_y;
        float first_tile_x;
        float first_tile_y;
};

enum GridAxis {
        GRID_AXIS_HORIZONTAL,
        GRID_AXIS_VERTICAL
};

enum HexagonNeighbor {
        HEXAGON_NEIGHBOR_TOP = 0,
        HEXAGON_NEIGHBOR_BOTTOM,
        HEXAGON_NEIGHBOR_TOP_LEFT,
        HEXAGON_NEIGHBOR_TOP_RIGHT,
        HEXAGON_NEIGHBOR_BOTTOM_LEFT,
        HEXAGON_NEIGHBOR_BOTTOM_RIGHT,
        HEXAGON_NEIGHBOR_COUNT
};

struct HexagonNeighborOffset {
        int8_t column;
        int8_t row;
};

static const struct HexagonNeighborOffset even_hexagon_neighbor_offsets[HEXAGON_NEIGHBOR_COUNT] = {
        (struct HexagonNeighborOffset){.column =  0, .row = -1}, // TOP
        (struct HexagonNeighborOffset){.column =  0, .row = +1}, // BOTTOM
        (struct HexagonNeighborOffset){.column = -1, .row = -1}, // TOP_LEFT
        (struct HexagonNeighborOffset){.column = +1, .row = -1}, // TOP_RIGHT
        (struct HexagonNeighborOffset){.column = -1, .row =  0}, // BOTTOM_LEFT
        (struct HexagonNeighborOffset){.column = +1, .row =  0}, // BOTTOM_RIGHT
};

static const struct HexagonNeighborOffset odd_hexagon_neighbor_offsets[HEXAGON_NEIGHBOR_COUNT] = {
        (struct HexagonNeighborOffset){.column =  0, .row = -1}, // TOP
        (struct HexagonNeighborOffset){.column =  0, .row = +1}, // BOTTOM
        (struct HexagonNeighborOffset){.column = -1, .row =  0}, // TOP_LEFT
        (struct HexagonNeighborOffset){.column = +1, .row =  0}, // TOP_RIGHT
        (struct HexagonNeighborOffset){.column = -1, .row = +1}, // BOTTOM_LEFT
        (struct HexagonNeighborOffset){.column = +1, .row = +1}, // BOTTOM_RIGHT
};

static inline bool get_hexagon_neighbor(
        const size_t column,
        const size_t row,
        const enum HexagonNeighbor neighbor,
        const struct GridMetrics *const optional_grid_metrics,
        size_t *const out_column,
        size_t *const out_row
) {
        const struct HexagonNeighborOffset *const offsets = (column & 1ULL) ? odd_hexagon_neighbor_offsets : even_hexagon_neighbor_offsets;
        const size_t neighbor_row    = row    + (size_t)offsets[neighbor].row;
        const size_t neighbor_column = column + (size_t)offsets[neighbor].column;

        if (neighbor_row < 0ULL || neighbor_column < 0ULL) {
                return false;
        }

        if (optional_grid_metrics != NULL) {
                if (neighbor_column >= optional_grid_metrics->columns || neighbor_row >= optional_grid_metrics->rows) {
                        return false;
                }
        }

        if (out_row != NULL) {
                *out_row = neighbor_row;
        }

        if (out_column != NULL) {
                *out_column = neighbor_column;
        }

        return true;
}

static inline bool get_grid_tile_position(const struct GridMetrics *const grid_metrics, const size_t column, const size_t row, float *const x, float *const y) {
        if (column >= grid_metrics->columns || row >= grid_metrics->rows) {
                return false;
        }

        if (x != NULL) {
                *x = grid_metrics->grid_x + grid_metrics->tile_radius + column * grid_metrics->tile_distance_x;
        }

        if (y != NULL) {
                *y = grid_metrics->grid_y + grid_metrics->tile_distance_y / 2.0f + row * grid_metrics->tile_distance_y + ((column & 1ULL) ? grid_metrics->tile_distance_y / 2.0f : 0.0f);
        }

        return true;
}

static inline bool get_grid_tile_at_position(const struct GridMetrics *grid_metrics, const float x, const float y, size_t *const column, size_t *const row) {
        const int approximate_column = (int)((x - grid_metrics->grid_x) / grid_metrics->tile_distance_x);
        if (approximate_column < 0 || approximate_column >= (int)grid_metrics->columns) {
                return false;
        }

        const int approximate_row = (int)((y - grid_metrics->grid_y - ((approximate_column & 1) ? grid_metrics->tile_distance_y / 2.0f : 0.0f)) / grid_metrics->tile_distance_y);
        if (approximate_row < 0 || approximate_row >= (int)grid_metrics->rows) {
                return false;
        }

        for (int neighbor = 0; neighbor < HEXAGON_NEIGHBOR_COUNT; ++neighbor) {
                size_t neighbor_column, neighbor_row;
                if (get_hexagon_neighbor(approximate_column, approximate_row, (enum HexagonNeighbor)neighbor, grid_metrics, &neighbor_column, &neighbor_row)) {
                        float neighbor_x, neighbor_y;
                        if (get_grid_tile_position(grid_metrics, neighbor_column, neighbor_row, &neighbor_x, &neighbor_y)) {
                                if ((fabsf(x - neighbor_x) * 2.0f / sqrtf(3.0f) + fabsf(y - neighbor_y)) / grid_metrics->tile_radius <= 1.0f) {
                                        if (column != NULL) {
                                                *column = neighbor_column;
                                        }

                                        if (row != NULL) {
                                                *row = neighbor_row;
                                        }

                                        return true;
                                }
                        }
                }
        }

        if (column != NULL) {
                *column = (size_t)approximate_column;
        }

        if (row != NULL) {
                *row = (size_t)approximate_row;
        }

        return true;
}

static inline void populate_grid_metrics_from_radius(struct GridMetrics *const grid_metrics) {
        grid_metrics->tile_distance_x = grid_metrics->tile_radius * 1.5f;
        grid_metrics->tile_distance_y = grid_metrics->tile_radius * sqrtf(3.0f);

        grid_metrics->columns = (size_t)((grid_metrics->bounding_width - grid_metrics->tile_radius * 0.5f) / grid_metrics->tile_distance_x);
        grid_metrics->rows    = (size_t)((grid_metrics->bounding_height - 0.0f) / grid_metrics->tile_distance_y);

        if (grid_metrics->columns == 0ULL) {
                grid_metrics->columns = 1ULL;
        }

        if (grid_metrics->rows == 0ULL) {
                grid_metrics->rows = 1ULL;
        }

        grid_metrics->tile_count = grid_metrics->columns * grid_metrics->rows;

        grid_metrics->grid_width  = grid_metrics->tile_distance_x * (grid_metrics->columns - 1ULL) + grid_metrics->tile_radius * 2.0f;
        grid_metrics->grid_height = grid_metrics->tile_distance_y *  grid_metrics->rows;

        grid_metrics->grid_x = grid_metrics->bounding_x + (grid_metrics->bounding_width  - grid_metrics->grid_width)  / 2.0f;
        grid_metrics->grid_y = grid_metrics->bounding_y + (grid_metrics->bounding_height - grid_metrics->grid_height) / 2.0f;
}

static inline void populate_grid_metrics_from_size(struct GridMetrics *const grid_metrics) {
        const float maximum_tile_radius_from_width  = grid_metrics->bounding_width  / (1.5f * grid_metrics->columns + 0.5f);
        const float maximum_tile_radius_from_height = grid_metrics->bounding_height / (sqrtf(3.0f) * (grid_metrics->rows + 0.5f));

        grid_metrics->tile_radius = fminf(maximum_tile_radius_from_width, maximum_tile_radius_from_height);
        grid_metrics->tile_count = grid_metrics->columns * grid_metrics->rows;
        grid_metrics->tile_distance_x = grid_metrics->tile_radius * 1.5f;
        grid_metrics->tile_distance_y = grid_metrics->tile_radius * sqrt(3.0f);
        grid_metrics->grid_width  = grid_metrics->tile_radius * 2.0f + grid_metrics->tile_distance_x * (grid_metrics->columns - 1ULL);
        grid_metrics->grid_height = grid_metrics->tile_distance_y * grid_metrics->rows + ((grid_metrics->columns > 1ULL) ? grid_metrics->tile_distance_y / 2.0f : 0.0f);
        grid_metrics->grid_x = grid_metrics->bounding_x + (grid_metrics->bounding_width  - grid_metrics->grid_width)  / 2.0f;
        grid_metrics->grid_y = grid_metrics->bounding_y + (grid_metrics->bounding_height - grid_metrics->grid_height) / 2.0f;
}

static inline void populate_scrolling_grid_metrics(struct GridMetrics *const grid_metrics, const enum GridAxis grid_scroll_axis) {
        grid_metrics->tile_distance_x = grid_metrics->tile_radius * 1.5f;
        grid_metrics->tile_distance_y = grid_metrics->tile_radius * sqrtf(3.0f);

        if (grid_scroll_axis == GRID_AXIS_VERTICAL) {
                grid_metrics->columns = (size_t)((grid_metrics->bounding_width - grid_metrics->tile_radius * 0.5f) / grid_metrics->tile_distance_x);
                if (grid_metrics->columns == 0) {
                        grid_metrics->columns = 1ULL;
                }

                grid_metrics->rows = (grid_metrics->tile_count + grid_metrics->columns - 1ULL) / grid_metrics->columns;
                grid_metrics->grid_width  = grid_metrics->tile_distance_x * (grid_metrics->columns - 1ULL) + grid_metrics->tile_radius * 2.0f;
                grid_metrics->grid_height = grid_metrics->tile_distance_y *  grid_metrics->rows;
                grid_metrics->bounding_height = grid_metrics->grid_height;
        }

        if (grid_scroll_axis == GRID_AXIS_HORIZONTAL) {
                grid_metrics->rows = (size_t)((grid_metrics->bounding_height - 0.0f) / grid_metrics->tile_distance_y);
                if (grid_metrics->rows == 0) {
                        grid_metrics->rows = 1ULL;
                }

                grid_metrics->columns = (grid_metrics->tile_count + grid_metrics->rows - 1ULL) / grid_metrics->rows;
                grid_metrics->grid_width  = grid_metrics->tile_distance_x * (grid_metrics->columns - 1ULL) + grid_metrics->tile_radius * 2.0f;
                grid_metrics->grid_height = grid_metrics->tile_distance_y *  grid_metrics->rows;
                grid_metrics->bounding_width = grid_metrics->grid_width;
        }

        grid_metrics->grid_x = grid_metrics->bounding_x + (grid_metrics->bounding_width  - grid_metrics->grid_width)  / 2.0f;
        grid_metrics->grid_y = grid_metrics->bounding_y + (grid_metrics->bounding_height - grid_metrics->grid_height) / 2.0f;
}