#include "Level.h"

#include <SDL_keycode.h>
#include <SDL_mixer.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <sys/types.h>

#include "SDL_render.h"
#include "SDL_timer.h"

#include "Audio.h"
#include "cJSON.h"
#include "Context.h"
#include "Utilities.h"
#include "Memory.h"
#include "Entity.h"
#include "Geometry.h"
#include "Debug.h"

#define LEVEL_DIMENSION_LIMIT 20

#define STEP_HISTORY_INITIAL_CAPACITY (64ULL)

struct StepHistory {
        struct Change *changes;
        size_t change_capacity;
        size_t change_count;

        size_t *step_offsets;
        size_t step_capacity;
        size_t step_count;
};

static inline void initialize_step_history(struct StepHistory *const step_history) {
        step_history->changes = (struct Change *)xmalloc(STEP_HISTORY_INITIAL_CAPACITY * sizeof(struct Change));
        step_history->change_capacity = STEP_HISTORY_INITIAL_CAPACITY;
        step_history->change_count = 0ULL;

        step_history->step_offsets = (size_t *)xmalloc(STEP_HISTORY_INITIAL_CAPACITY * sizeof(size_t));
        step_history->step_capacity = STEP_HISTORY_INITIAL_CAPACITY;
        step_history->step_count = 0ULL;
}

static inline void destroy_step_history(struct StepHistory *const step_history) {
        xfree(step_history->changes);
        step_history->changes = NULL;
        step_history->change_capacity = 0ULL;
        step_history->change_count = 0ULL;

        xfree(step_history->step_offsets);
        step_history->step_offsets = NULL;
        step_history->step_capacity = 0ULL;
        step_history->step_count = 0ULL;
}

static inline void empty_step_history(struct StepHistory *const step_history) {
        step_history->change_count = 0ULL;
        step_history->step_count = 0ULL;
}

static inline void step_history_pop_step(struct StepHistory *const step_history, const size_t offset) {
        if (offset >= step_history->step_count) {
                return;
        }

        const size_t step_index = step_history->step_count - offset - 1ULL;
        const size_t step_start = step_index == 0ULL ? 0ULL : step_history->step_offsets[step_index - 1ULL];
        const size_t step_end   = step_history->step_offsets[step_index];
        const size_t step_size  = step_end - step_start;

        if (step_end < step_history->change_count) {
                memmove(&step_history->changes[step_start],
                        &step_history->changes[step_end],
                        (step_history->change_count - step_end) * sizeof(struct Change));
        }

        step_history->change_count -= step_size;

        if (step_index + 1 < step_history->step_count) {
                memmove(&step_history->step_offsets[step_index],
                        &step_history->step_offsets[step_index + 1],
                        (step_history->step_count - step_index - 1) * sizeof(size_t));
        }

        for (size_t i = step_index; i < step_history->step_count - 1; ++i) {
                step_history->step_offsets[i] -= step_size;
        }

        --step_history->step_count;
}

static inline void step_history_swap_step(struct StepHistory *const source, struct StepHistory *const destination) {
        if (source->step_count == 0ULL) {
                return;
        }

        const size_t step_end     = source->step_offsets[source->step_count - 1ULL];
        const size_t step_start   = source->step_count > 1ULL ? source->step_offsets[source->step_count - 2ULL] : 0ULL;
        const size_t step_changes = step_end - step_start;

        for (size_t change_index = 0ULL; change_index < step_changes; ++change_index) {
                const struct Change *change = &source->changes[step_start + change_index];

                struct Change reversed = *change;

                switch (change->type) {
                        case CHANGE_WALK: case CHANGE_PUSH: case CHANGE_PUSHED: {
                                if (change->type == CHANGE_WALK) {
                                        play_sound(SOUND_MOVE);
                                }

                                if (change->type == CHANGE_PUSH) {
                                        play_sound(SOUND_PUSH);
                                }

                                reversed.input = reversed.input == INPUT_FORWARD ? INPUT_BACKWARD : INPUT_FORWARD;

                                uint16_t tile_index = reversed.move.last_tile_index;
                                reversed.move.last_tile_index = reversed.move.next_tile_index;
                                reversed.move.next_tile_index = tile_index;
                                break;
                        }

                        case CHANGE_TURN: {
                                play_sound(SOUND_TURN);

                                reversed.input = reversed.input == INPUT_LEFT ? INPUT_RIGHT : INPUT_LEFT;

                                enum Orientation orientation = reversed.turn.last_orientation;
                                reversed.turn.last_orientation = reversed.turn.next_orientation;
                                reversed.turn.next_orientation = orientation;
                                break;
                        }

                        case CHANGE_TOGGLE: {
                                reversed.toggle.focused = !reversed.toggle.focused;
                                break;
                        }

                        case CHANGE_BLOCKED: case CHANGE_INVALID: {
                                continue;
                        }
                }

                entity_handle_change(reversed.entity, &reversed);

                if (destination->change_count >= destination->change_capacity) {
                        destination->change_capacity *= 2ULL;
                        destination->changes = (struct Change *)xrealloc(destination->changes, destination->change_capacity * sizeof(struct Change));
                }

                destination->changes[destination->change_count++] = reversed;
        }

        if (destination->step_count >= destination->step_capacity) {
                destination->step_capacity *= 2ULL;
                destination->step_offsets = (size_t *)xrealloc(destination->step_offsets, destination->step_capacity * sizeof(size_t));
        }

        destination->step_offsets[destination->step_count++] = destination->change_count;

        source->change_count = step_start;
        --source->step_count;
}

static inline struct Change *get_next_change_slot(struct StepHistory *const step_history) {
        if (step_history->change_count >= step_history->change_capacity) {
                step_history->change_capacity *= 2ULL;
                step_history->changes = (struct Change *)xrealloc(step_history->changes, step_history->change_capacity * sizeof(struct Change));
        }

        return &step_history->changes[step_history->change_count++];
}

static inline void commit_pending_step(struct StepHistory *const step_history) {
        const size_t last_offset = step_history->step_count ? step_history->step_offsets[step_history->step_count - 1ULL] : 0ULL;
        const size_t step_changes = step_history->change_count - last_offset;
        if (step_changes == 0ULL) {
                return;
        }

        if (step_history->step_count >= step_history->step_capacity) {
                step_history->step_capacity *= 2ULL;
                step_history->step_offsets = (size_t *)xrealloc(step_history->step_offsets, step_history->step_capacity * sizeof(size_t));
        }

        step_history->step_offsets[step_history->step_count++] = step_history->change_count;

        for (size_t index = 0ULL; index < step_changes; ++index) {
                struct Change *const change = &step_history->changes[step_history->change_count - 1ULL - index];
                entity_handle_change(change->entity, change);
        }
}

static inline void discard_pending_step(struct StepHistory *const step_history, const enum Orientation direction) {
        const size_t last_offset = step_history->step_count ? step_history->step_offsets[step_history->step_count - 1ULL] : 0ULL;
        const size_t step_changes = step_history->change_count - last_offset;
        if (step_changes == 0ULL) {
                return;
        }

        for (size_t index = 0ULL; index < step_changes; ++index) {
                struct Change *const change = &step_history->changes[step_history->change_count - 1ULL - index];
                change->type = index == step_changes - 1ULL ? CHANGE_BLOCKED : CHANGE_INVALID;
                change->face.direction = direction;

                entity_handle_change(change->entity, change);
        }

        step_history->change_count -= step_changes;
}

#define TAP_TIME_THRESHOLD       (300)
#define SWIPE_DISTANCE_THRESHOLD (0.15f)
#define SWIPE_TIME_THRESHOLD     (500)
#define TAP_DISTANCE_THRESHOLD   (0.05f)

#ifndef NDEBUG
#define EVENT_IS_GESTURE_DOWN(event)   ((event)->type == SDL_FINGERDOWN   || (event)->type == SDL_MOUSEBUTTONDOWN)
#define EVENT_IS_GESTURE_UP(event)     ((event)->type == SDL_FINGERUP     || (event)->type == SDL_MOUSEBUTTONUP)
#define EVENT_IS_GESTURE_MOTION(event) ((event)->type == SDL_FINGERMOTION || (event)->type == SDL_MOUSEMOTION)
#else
#define EVENT_IS_GESTURE_DOWN(event)   ((event)->type == SDL_FINGERDOWN)
#define EVENT_IS_GESTURE_UP(event)     ((event)->type == SDL_FINGERUP)
#define EVENT_IS_GESTURE_MOTION(event) ((event)->type == SDL_FINGERMOTION)
#endif

struct LevelImplementation {
        char *title;
        enum TileType *tiles;
        uint16_t tile_count;
        struct Entity **entities;
        uint16_t entity_count;
        uint16_t player_count;
        uint16_t current_player_index;
        struct Entity *switch_anchor_player;
        struct GridMetrics grid_metrics;
        struct Geometry *grid_geometry;
        struct StepHistory step_history;
        struct StepHistory undo_history;
        bool has_buffered_input;
        enum Input buffered_input;
        void *buffered_input_data;
        uint32_t gesture_start_time;
        float gesture_swipe_x;
        float gesture_swipe_y;
};

static inline void level_process_move(struct Level *const level, const enum Input input) {
        struct Entity *const current_player = level->implementation->entities[level->implementation->current_player_index];

        if (!entity_can_change(current_player)) {
                if (!level->implementation->has_buffered_input) {
                        level->implementation->has_buffered_input = true;
                        level->implementation->buffered_input = input;
                }

                return;
        }

        level->implementation->switch_anchor_player = NULL;

        uint16_t tile_index = get_entity_tile_index(current_player);
        enum Orientation direction = get_entity_orientation(current_player);
        if (input == INPUT_BACKWARD) {
                direction = orientation_reverse(direction);
        }

        struct Entity *next_entity = current_player;
        while (true) {
                const bool first_change = next_entity == current_player;

                struct Change *const change = get_next_change_slot(&level->implementation->step_history);
                change->input = input;
                change->type = first_change ? CHANGE_PUSH : CHANGE_PUSHED;
                change->entity = next_entity;
                change->move.last_tile_index = tile_index;

                if (!orientation_advance_index(direction, level->columns, level->rows, &tile_index)) {
                        discard_pending_step(&level->implementation->step_history, direction);
                        return;
                }

                change->move.next_tile_index = tile_index;

                enum TileType tile_type;
                query_level_tile(level, tile_index, &tile_type, &next_entity, NULL, NULL);

                if (tile_type == TILE_EMPTY) {
                        discard_pending_step(&level->implementation->step_history, direction);
                        play_sound(SOUND_HIT);
                        return;
                }

                // Players can walk on slab tiles but blocks can't get pushed onto them
                if (tile_type == TILE_SLAB && get_entity_type(change->entity) == ENTITY_BLOCK) {
                        discard_pending_step(&level->implementation->step_history, direction);
                        play_sound(SOUND_HIT);
                        return;
                }

                if (next_entity == NULL) {
                        empty_step_history(&level->implementation->undo_history);

                        if (first_change) {
                                // This means that the next tile is valid but nothing will be pushed
                                change->type = CHANGE_WALK;
                                commit_pending_step(&level->implementation->step_history);
                                play_sound(SOUND_MOVE);
                                return;
                        }

                        commit_pending_step(&level->implementation->step_history);

                        bool did_win = true;
                        for (uint16_t tile_index = 0; tile_index < level->implementation->tile_count; ++tile_index) {
                                enum TileType tile_type;
                                struct Entity *entity;
                                query_level_tile(level, tile_index, &tile_type, &entity, NULL, NULL);

                                if (tile_type == TILE_SPOT) {
                                        if (entity == NULL) {
                                                did_win = false;
                                                break;
                                        }

                                        if (get_entity_type(entity) != ENTITY_BLOCK) {
                                                did_win = false;
                                                break;
                                        }
                                }
                        }

                        if (did_win) {
                                level->completion_callback(level->completion_callback_data);
                                play_sound(SOUND_WIN);
                                return;
                        }

                        play_sound(SOUND_PUSH);
                        return;
                }
        }
}

static inline void level_process_turn(struct Level *const level, const enum Input input) {
        struct Entity *const current_player = level->implementation->entities[level->implementation->current_player_index];

        if (!entity_can_change(current_player)) {
                if (!level->implementation->has_buffered_input) {
                        level->implementation->has_buffered_input = true;
                        level->implementation->buffered_input = input;
                }

                return;
        }

        level->implementation->switch_anchor_player = NULL;

        struct Change *const change = get_next_change_slot(&level->implementation->step_history);
        change->input = input;
        change->type = CHANGE_TURN;
        change->entity = current_player;
        change->turn.last_orientation = get_entity_orientation(current_player);
        change->turn.next_orientation = input == INPUT_RIGHT
                ? orientation_turn_right(change->turn.last_orientation)
                : orientation_turn_left(change->turn.last_orientation);

        commit_pending_step(&level->implementation->step_history);
        empty_step_history(&level->implementation->undo_history);
        play_sound(SOUND_TURN);
}

static inline void level_sync_current_player(struct Level *level) {
        for (uint16_t entity_index = 0; entity_index < level->implementation->entity_count; ++entity_index) {
                if (entity_is_focused(level->implementation->entities[entity_index])) {
                        level->implementation->current_player_index = entity_index;
                        return;
                }
        }
}

static inline void level_process_undo(struct Level *const level) {
        struct Entity *const current_player = level->implementation->entities[level->implementation->current_player_index];

        if (!entity_can_change(current_player)) {
                if (!level->implementation->has_buffered_input) {
                        level->implementation->has_buffered_input = true;
                        level->implementation->buffered_input = INPUT_UNDO;
                }

                return;
        }

        step_history_swap_step(&level->implementation->step_history, &level->implementation->undo_history);
        level_sync_current_player(level);
}

static inline void level_process_redo(struct Level *const level) {
        struct Entity *const current_player = level->implementation->entities[level->implementation->current_player_index];

        if (!entity_can_change(current_player)) {
                if (!level->implementation->has_buffered_input) {
                        level->implementation->has_buffered_input = true;
                        level->implementation->buffered_input = INPUT_REDO;
                }

                return;
        }

        step_history_swap_step(&level->implementation->undo_history, &level->implementation->step_history);
        level_sync_current_player(level);
}

static inline void level_process_switch(struct Level *const level, struct Entity *const optional_player) {
        if (level->implementation->player_count == 1) {
                return;
        }

        struct Entity *const current_player = level->implementation->entities[level->implementation->current_player_index];

        if (!entity_can_change(current_player)) {
                if (!level->implementation->has_buffered_input) {
                        level->implementation->has_buffered_input = true;
                        level->implementation->buffered_input = INPUT_SWITCH;
                        level->implementation->buffered_input_data = (void *)optional_player;
                }

                return;
        }

        struct Change *const current_player_change = get_next_change_slot(&level->implementation->step_history);
        current_player_change->input = INPUT_SWITCH;
        current_player_change->type = CHANGE_TOGGLE;
        current_player_change->entity = current_player;
        current_player_change->toggle.focused = false;

        for (uint16_t index = 0; index < level->implementation->entity_count; ++index) {
                if (optional_player != NULL) {
                        if (level->implementation->entities[index] == optional_player) {
                                level->implementation->current_player_index = index;
                                break;
                        }

                        continue;
                }

                // If no player is given, cycle through entities to find the next player to switch to
                const uint16_t entity_index = (level->implementation->current_player_index + index + 1) % level->implementation->entity_count;
                if (get_entity_type(level->implementation->entities[entity_index]) == ENTITY_PLAYER) {
                        level->implementation->current_player_index = entity_index;
                        break;
                }
        }

        struct Entity *const next_player = level->implementation->entities[level->implementation->current_player_index];

        struct Change *const next_player_change = get_next_change_slot(&level->implementation->step_history);
        next_player_change->input = INPUT_SWITCH;
        next_player_change->type = CHANGE_TOGGLE;
        next_player_change->entity = next_player;
        next_player_change->toggle.focused = true;

        commit_pending_step(&level->implementation->step_history);
        empty_step_history(&level->implementation->undo_history);

        if (level->implementation->switch_anchor_player == NULL) {
                level->implementation->switch_anchor_player = current_player;
                return;
        }

        if (level->implementation->switch_anchor_player == next_player) {
                step_history_pop_step(&level->implementation->step_history, 0ULL);
                step_history_pop_step(&level->implementation->step_history, 0ULL);
                level->implementation->switch_anchor_player = NULL;
                return;
        }

        current_player_change->entity = level->implementation->switch_anchor_player;

        // Remove the penultimate step to essentially replace the last switch with this new one
        step_history_pop_step(&level->implementation->step_history, 1ULL);
}

static bool parse_level(const cJSON *const json, struct Level *const level);

static void resize_level(struct Level *const level);

struct Level *load_level(const size_t number) {
        struct Level *const level = (struct Level *)xcalloc(1ULL, sizeof(struct Level));
        if (!initialize_level(level, number)) {
                send_message(MESSAGE_ERROR, "Failed to load level: Failed to initialize level");
                destroy_level(level);
                return NULL;
        }

        return level;
}

void destroy_level(struct Level *const level) {
        if (!level) {
                send_message(MESSAGE_WARNING, "Level given to destroy is NULL");
                return;
        }

        deinitialize_level(level);
        xfree(level);
}

bool initialize_level(struct Level *const level, const size_t number) {
        level->columns = 0;
        level->rows = 0;
        level->move_count = 0ULL;
        level->completion_callback = NULL;
        level->completion_callback_data = NULL;

        level->implementation = (struct LevelImplementation *)xmalloc(sizeof(struct LevelImplementation));
        level->implementation->grid_geometry = create_geometry();
        level->implementation->current_player_index = UINT16_MAX;
        level->implementation->switch_anchor_player = NULL;
        level->implementation->gesture_start_time = 0;

        initialize_step_history(&level->implementation->step_history);
        initialize_step_history(&level->implementation->undo_history);

        char level_path_buffer[32ULL];
        snprintf(level_path_buffer, sizeof(level_path_buffer), "Assets/Levels/Level%zu.json", number);

        char *const json_string = load_text_file(level_path_buffer);
        if (!json_string) {
                send_message(MESSAGE_ERROR, "Failed to initialize level %zu: Failed to load level data file", level_path_buffer);
                deinitialize_level(level);
                return false;
        }

        cJSON *const json = cJSON_Parse(json_string);
        xfree(json_string);

        if (!json) {
                send_message(MESSAGE_ERROR, "Failed to initialize level %zu: Failed to parse level data file: %s", level_path_buffer, cJSON_GetErrorPtr());
                deinitialize_level(level);
                return false;
        }

        if (!parse_level(json, level)) {
                send_message(MESSAGE_ERROR, "Failed to initialize level %zu: Failed to parse level from level data file", level_path_buffer);
                deinitialize_level(level);
                cJSON_Delete(json);
                return NULL;
        }

        cJSON_Delete(json);

        struct GridMetrics *const grid_metrics = &level->implementation->grid_metrics;
        grid_metrics->columns = (size_t)level->columns;
        grid_metrics->rows = (size_t)level->rows;

        struct Change selected_player_focus = {0};
        selected_player_focus.type = CHANGE_TOGGLE;
        selected_player_focus.toggle.focused = true;
        selected_player_focus.input = INPUT_SWITCH;
        selected_player_focus.entity = level->implementation->entities[level->implementation->current_player_index];
        entity_handle_change(selected_player_focus.entity, &selected_player_focus);

        resize_level(level);
        return true;
}

void deinitialize_level(struct Level *const level) {
        if (!level) {
                send_message(MESSAGE_WARNING, "Level given to deinitialize is NULL");
                return;
        }

        if (level->implementation == NULL) {
                return;
        }

        destroy_step_history(&level->implementation->step_history);
        destroy_step_history(&level->implementation->undo_history);

        destroy_geometry(level->implementation->grid_geometry);

        if (level->implementation->entities) {
                for (size_t entity_index = 0ULL; entity_index < level->implementation->entity_count; ++entity_index) {
                        destroy_entity(level->implementation->entities[entity_index]);
                }

                xfree(level->implementation->entities);
        }

        if (level->implementation->tiles) {
                xfree(level->implementation->tiles);
        }

        if (level->implementation->title) {
                xfree(level->implementation->title);
        }

        xfree(level->implementation);
        level->implementation = NULL;
}

char *get_level_title(struct Level *const level) {
        return level->implementation->title;
}

bool query_level_tile(
        const struct Level *const level,
        const uint16_t tile_index,
        enum TileType *const out_tile_type,
        struct Entity **const out_entity,
        float *const out_x,
        float *const out_y
) {
        if (tile_index >= level->implementation->tile_count) {
                return false;
        }

        const enum TileType tile_type = level->implementation->tiles[tile_index];
        if (out_tile_type) {
                *out_tile_type = tile_type;
        }

        const struct GridMetrics *const grid_metrics = &level->implementation->grid_metrics;
        const uint16_t columns = (uint16_t)grid_metrics->columns;

        float x, y;
        get_grid_tile_position(grid_metrics, (size_t)(tile_index % columns), (size_t)(tile_index / columns), &x, &y);

        if (out_x) {
                *out_x = x;
        }

        if (out_y) {
                *out_y = tile_type == TILE_SLAB ? y - grid_metrics->tile_radius / 4.0f : y;
        }

        if (out_entity) {
                *out_entity = NULL;

                for (uint16_t entity_index = 0; entity_index < level->implementation->entity_count; ++entity_index) {
                        struct Entity *const entity = level->implementation->entities[entity_index];
                        if (get_entity_tile_index(entity) == tile_index) {
                                *out_entity = entity;
                                break;
                        }
                }
        }

        return true;
}

static inline void get_event_position(const SDL_Event *const event, const int screen_width, const int screen_height, float *const x, float *const y) {
#ifndef NDEBUG
        if (event->type == SDL_MOUSEBUTTONDOWN || event->type == SDL_MOUSEBUTTONUP || event->type == SDL_MOUSEMOTION) {
                *x = (float)event->button.x / (float)screen_width;
                *y = (float)event->button.y / (float)screen_height;
                return;
        }
#endif

        if (event->type == SDL_FINGERDOWN || event->type == SDL_FINGERUP || event->type == SDL_FINGERMOTION) {
                *x = event->tfinger.x;
                *y = event->tfinger.y;
        }
}

bool level_receive_event(struct Level *const level, const SDL_Event *const event) {
        if (event->type == SDL_WINDOWEVENT) {
                const Uint8 window_event = event->window.event;
                if (window_event == SDL_WINDOWEVENT_RESIZED || window_event == SDL_WINDOWEVENT_MAXIMIZED || window_event == SDL_WINDOWEVENT_SIZE_CHANGED) {
                        resize_level(level);
                }

                return false;
        }

        // TODO: On non-touch devices, LMB click for left turn and RMB click for right turn?

        if (event->type == SDL_KEYDOWN && event->key.repeat == 0) {
                const SDL_Keycode key = event->key.keysym.sym;

                if (key == SDLK_LEFT || key == SDLK_a) {
                        level_process_turn(level, INPUT_LEFT);
                        return true;
                }

                if (key == SDLK_RIGHT || key == SDLK_d) {
                        level_process_turn(level, INPUT_RIGHT);
                        return true;
                }

                if (key == SDLK_UP || key == SDLK_w) {
                        level_process_move(level, INPUT_FORWARD);
                        return true;
                }

                if (key == SDLK_DOWN || key == SDLK_s) {
                        level_process_move(level, INPUT_BACKWARD);
                        return true;
                }

                if (key == SDLK_z) {
                        level_process_undo(level);
                        return true;
                }

                if (key == SDLK_x || key == SDLK_y) {
                        level_process_redo(level);
                        return true;
                }

                if (key == SDLK_LSHIFT || key == SDLK_RSHIFT) {
                        // Pass 'NULL' to cycle through other players
                        level_process_switch(level, NULL);
                        return true;
                }
        }

        int screen_width, screen_height;
        SDL_GetWindowSize(get_context_window(), &screen_width, &screen_height);

        if (EVENT_IS_GESTURE_DOWN(event)) {
                get_event_position(event, screen_width, screen_height, &level->implementation->gesture_swipe_x, &level->implementation->gesture_swipe_y);
                level->implementation->gesture_start_time = (uint32_t)SDL_GetTicks();
                return true;
        }

        if (EVENT_IS_GESTURE_UP(event) && level->implementation->gesture_start_time != 0) {
                if (!level->implementation->has_buffered_input) {
                        const uint32_t delta_time = (uint32_t)SDL_GetTicks() - level->implementation->gesture_start_time;

                        float swiped_x, swiped_y;
                        get_event_position(event, screen_width, screen_height, &swiped_x, &swiped_y);

                        const float dx = swiped_x - level->implementation->gesture_swipe_x;
                        const float dy = swiped_y - level->implementation->gesture_swipe_y;
                        const float distance = sqrtf(dx * dx + dy * dy);

                        if (distance < TAP_DISTANCE_THRESHOLD && delta_time < TAP_TIME_THRESHOLD) {
                                int drawable_width, drawable_height;
                                SDL_GetRendererOutputSize(get_context_renderer(), &drawable_width, &drawable_height);

                                const float denormalized_x = swiped_x * (float)drawable_width;
                                const float denormalized_y = swiped_y * (float)drawable_height;

                                size_t tapped_column, tapped_row;
                                if (get_grid_tile_at_position(&level->implementation->grid_metrics, denormalized_x, denormalized_y, &tapped_column, &tapped_row)) {
                                        struct Entity *tapped_entity;
                                        const uint16_t tapped_tile_index = (uint16_t)(tapped_row * level->implementation->grid_metrics.columns + tapped_column);
                                        if (query_level_tile(level, tapped_tile_index, NULL, &tapped_entity, NULL, NULL)) {
                                                struct Entity *const current_player = level->implementation->entities[level->implementation->current_player_index];
                                                if (tapped_entity != NULL && get_entity_type(tapped_entity) == ENTITY_PLAYER && tapped_entity != current_player) {
                                                        level_process_switch(level, tapped_entity);
                                                }
                                        }
                                }
                        }

                        if (distance > SWIPE_DISTANCE_THRESHOLD && delta_time < SWIPE_TIME_THRESHOLD) {
                                if (fabsf(dx) > fabsf(dy)) {
                                        level_process_turn(level, dx > 0.0f ? INPUT_RIGHT : INPUT_LEFT);
                                } else {
                                        level_process_move(level, dy > 0.0f ? INPUT_BACKWARD : INPUT_FORWARD);
                                }
                        }
                }

                level->implementation->gesture_start_time = 0;
                return true;
        }

        return false;
}

void update_level(struct Level *const level, const double delta_time) {
        struct Entity *const current_player = level->implementation->entities[level->implementation->current_player_index];
        if (level->implementation->has_buffered_input && entity_can_change(current_player)) {
                level->implementation->has_buffered_input = false;

                switch (level->implementation->buffered_input) {
                        case INPUT_BACKWARD: case INPUT_FORWARD: {
                                level_process_move(level, level->implementation->buffered_input);
                                break;
                        }

                        case INPUT_LEFT: case INPUT_RIGHT: {
                                level_process_turn(level, level->implementation->buffered_input);
                                break;
                        }

                        case INPUT_UNDO: {
                                level_process_undo(level);
                                break;
                        }

                        case INPUT_REDO: {
                                level_process_redo(level);
                                break;
                        }

                        case INPUT_SWITCH: {
                                level_process_switch(level, (struct Entity *)level->implementation->buffered_input_data);
                                break;
                        }

                        default: {
                                break;
                        }
                }
        }

        render_geometry(level->implementation->grid_geometry);

        for (size_t entity_index = 0ULL; entity_index < level->implementation->entity_count; ++entity_index) {
                struct Entity *const entity = level->implementation->entities[entity_index];
                if (get_entity_type(entity) != ENTITY_PLAYER) {
                        update_entity(entity, delta_time);
                }
        }

        // Add another pass to update players last (I forgot why though)
        for (size_t entity_index = 0ULL; entity_index < level->implementation->entity_count; ++entity_index) {
                struct Entity *const entity = level->implementation->entities[entity_index];
                if (get_entity_type(entity) == ENTITY_PLAYER) {
                        update_entity(entity, delta_time);
                }
        }
}

static bool parse_level(const cJSON *const json, struct Level *const level) {
        if (!cJSON_IsObject(json)) {
                send_message(MESSAGE_ERROR, "Failed to parse level: JSON data is invalid");
                return false;
        }

        const cJSON *const title_json    = cJSON_GetObjectItemCaseSensitive(json, "title");
        const cJSON *const columns_json  = cJSON_GetObjectItemCaseSensitive(json, "columns");
        const cJSON *const rows_json     = cJSON_GetObjectItemCaseSensitive(json, "rows");
        const cJSON *const tiles_json    = cJSON_GetObjectItemCaseSensitive(json, "tiles");
        const cJSON *const entities_json = cJSON_GetObjectItemCaseSensitive(json, "entities");

        if (
                !cJSON_IsString(title_json) ||
                !cJSON_IsNumber(columns_json) ||
                !cJSON_IsNumber(rows_json) ||
                !cJSON_IsArray(tiles_json) ||
                !cJSON_IsArray(entities_json)
        ) {
                send_message(MESSAGE_ERROR, "Failed to parse level: JSON data is invalid");
                return false;
        }

        level->implementation->title = xstrdup(title_json->valuestring);

        const double columns = columns_json->valuedouble;
        if (floor(columns) != columns || columns <= 0.0 || columns > (double)LEVEL_DIMENSION_LIMIT) {
                send_message(MESSAGE_ERROR, "Failed to parse level: The grid columns %lf is invalid, it should be an integer between 0 and %u", columns, LEVEL_DIMENSION_LIMIT);
                return false;
        }

        const double rows = rows_json->valuedouble;
        if (floor(rows) != rows || rows <= 0.0 || rows > (double)LEVEL_DIMENSION_LIMIT) {
                send_message(MESSAGE_ERROR, "Failed to parse level: The grid rows %lf is invalid, it should be an integer between 0 and %u", rows, LEVEL_DIMENSION_LIMIT);
                return false;
        }

        struct LevelImplementation *const implementation = level->implementation;
        level->columns = (uint8_t)columns;
        level->rows = (uint8_t)rows;

        const size_t tile_count = (size_t)cJSON_GetArraySize(tiles_json);
        implementation->tile_count = (size_t)level->columns * (size_t)level->rows;
        if (tile_count != implementation->tile_count) {
                send_message(MESSAGE_ERROR, "Failed to parse level: The tile count of %zu does not match the expected tile count of %zu (%u * %u)", tile_count, implementation->tile_count, level->columns, level->rows);
                return false;
        }

        implementation->tiles = (enum TileType *)xmalloc(implementation->tile_count * sizeof(enum TileType));

        size_t tile_index = 0ULL;
        const cJSON *tile_json = NULL;
        cJSON_ArrayForEach(tile_json, tiles_json) {
                if (!cJSON_IsNumber(tile_json)) {
                        send_message(MESSAGE_ERROR, "Failed to parse level: JSON data is invalid");
                        return false;
                }

                const double tile = tile_json->valuedouble;
                if (floor(tile) != tile || tile < 0.0 || (size_t)tile > (size_t)TILE_COUNT) {
                        send_message(MESSAGE_ERROR, "Failed to parse level: The tile #%zu of %lf is invalid, it should be an integer between 0 and %d", tile_index, tile, (int)TILE_COUNT);
                        return false;
                }

                implementation->tiles[tile_index++] = (enum TileType)(uint8_t)tile;
        }

        const int entities_length = cJSON_GetArraySize(entities_json);
        if (entities_length % 4) {
                send_message(MESSAGE_ERROR, "Failed to parse level: Entities array length of %d is not a multiple of 4", entities_length);
                return false;
        }

        implementation->entity_count = (uint16_t)entities_length / 4;
        implementation->entities = (struct Entity **)xcalloc(implementation->entity_count, sizeof(struct Entity *));

        uint16_t player_count = 0;
        const cJSON *entity_part_json = entities_json->child;
        for (uint16_t entity_index = 0; entity_index < implementation->entity_count; ++entity_index) {
                const cJSON *const entity_type_json = entity_part_json;
                const cJSON *const entity_column_json = entity_type_json->next;
                const cJSON *const entity_row_json = entity_column_json->next;
                const cJSON *const entity_orientation_json = entity_row_json->next;
                entity_part_json = entity_orientation_json->next;

                const uint8_t entity_type_value = (uint8_t)entity_type_json->valuedouble;
                enum EntityType entity_type;
                switch (entity_type_value) {
                        case 0: {
                                entity_type = ENTITY_PLAYER;
                                if (level->implementation->current_player_index != UINT16_MAX) {
                                        send_message(MESSAGE_ERROR, "Failed to parse level: Mutliple initially selected player entities found");
                                        return false;
                                }

                                level->implementation->current_player_index = entity_index;
                                ++player_count;
                                break;
                        }

                        case 1: {
                                entity_type = ENTITY_PLAYER;
                                ++player_count;
                                break;
                        }

                        case 2: {
                                entity_type = ENTITY_BLOCK;
                                break;
                        }

                        default: {
                                send_message(MESSAGE_ERROR, "Unrecognized entity type of %d found when parsing level", entity_type_value);
                                continue;
                        }
                }

                const uint8_t entity_column = (uint8_t)entity_column_json->valuedouble;
                const uint8_t entity_row = (uint8_t)entity_row_json->valuedouble;
                const uint16_t entity_tile_index = (uint16_t)entity_row * (uint16_t)level->columns + (uint16_t)entity_column;
                const enum Orientation entity_orientation = (enum Orientation)(uint8_t)entity_orientation_json->valuedouble;
                implementation->entities[entity_index] = create_entity(level, entity_type, entity_tile_index, entity_orientation);
        }

        if (implementation->current_player_index == UINT16_MAX) {
                send_message(MESSAGE_ERROR, "Failed to parse level: No initially selected player found");
                return false;
        }

        implementation->player_count = player_count;
        return true;
}

static void resize_level(struct Level *const level) {
        struct LevelImplementation *const implementation = level->implementation;
        clear_geometry(implementation->grid_geometry);

        int drawable_width, drawable_height;
        SDL_GetRendererOutputSize(get_context_renderer(), &drawable_width, &drawable_height);

        const float grid_padding = fminf((float)drawable_width, (float)drawable_height) / 10.0f;

        struct GridMetrics *const grid_metrics = &implementation->grid_metrics;
        grid_metrics->bounding_x = grid_padding;
        grid_metrics->bounding_y = grid_padding;
        grid_metrics->bounding_width  = (float)drawable_width  - grid_padding * 2.0f;
        grid_metrics->bounding_height = (float)drawable_height - grid_padding * 2.0f;
        populate_grid_metrics_from_size(grid_metrics);

        const float tile_radius = grid_metrics->tile_radius;
        const float thickness = tile_radius / 2.0f;
        const float line_width = tile_radius / 5.0f;
        grid_metrics->bounding_y -= thickness / 2.0f;
        grid_metrics->grid_y -= thickness / 2.0f;

        set_geometry_color(implementation->grid_geometry, COLOR_GOLD, COLOR_OPAQUE);
        for (uint8_t row = 0; row < level->rows; ++row) {
                for (uint8_t column = 0; column < level->columns; ++column) {
                        const enum TileType tile_type = implementation->tiles[(size_t)row * (size_t)level->columns + (size_t)column];
                        if (tile_type == TILE_EMPTY || tile_type == TILE_SLAB) {
                                continue;
                        }

                        float x, y;
                        get_grid_tile_position(grid_metrics, (size_t)column, (size_t)row, &x, &y);

                        enum HexagonThicknessMask thickness_mask = HEXAGON_THICKNESS_MASK_ALL;
                        size_t neighbor_column;
                        size_t neighbor_row;

                        if (get_hexagon_neighbor(&implementation->grid_metrics, (size_t)column, (size_t)row, HEXAGON_NEIGHBOR_BOTTOM, &neighbor_column, &neighbor_row)) {
                                const size_t neighbor_index = neighbor_row * implementation->grid_metrics.columns + neighbor_column;
                                const enum TileType neighbor_tile_type = implementation->tiles[neighbor_index];
                                if (neighbor_tile_type != TILE_EMPTY) {
                                        thickness_mask &= ~HEXAGON_THICKNESS_MASK_BOTTOM;
                                }
                        }

                        if (get_hexagon_neighbor(&level->implementation->grid_metrics, (size_t)column, (size_t)row, HEXAGON_NEIGHBOR_BOTTOM_LEFT, &neighbor_column, &neighbor_row)) {
                                const size_t neighbor_index = neighbor_row * implementation->grid_metrics.columns + neighbor_column;
                                const enum TileType neighbor_tile_type = implementation->tiles[neighbor_index];
                                if (neighbor_tile_type != TILE_EMPTY) {
                                        thickness_mask &= ~HEXAGON_THICKNESS_MASK_LEFT;
                                }
                        }

                        if (get_hexagon_neighbor(&level->implementation->grid_metrics, (size_t)column, (size_t)row, HEXAGON_NEIGHBOR_BOTTOM_RIGHT, &neighbor_column, &neighbor_row)) {
                                const size_t neighbor_index = neighbor_row * implementation->grid_metrics.columns + neighbor_column;
                                const enum TileType neighbor_tile_type = implementation->tiles[neighbor_index];
                                if (neighbor_tile_type != TILE_EMPTY) {
                                        thickness_mask &= ~HEXAGON_THICKNESS_MASK_RIGHT;
                                }
                        }

                        write_hexagon_thickness_geometry(implementation->grid_geometry, x, y, tile_radius + line_width / 2.0f, thickness, thickness_mask);
                }
        }

        for (uint8_t row = 0; row < level->rows; ++row) {
                for (uint8_t column = 0; column < level->columns; ++column) {
                        const enum TileType tile_type = implementation->tiles[(size_t)row * (size_t)level->columns + (size_t)column];
                        if (tile_type == TILE_EMPTY || tile_type == TILE_SLAB) {
                                continue;
                        }

                        float x, y;
                        get_grid_tile_position(grid_metrics, (size_t)column, (size_t)row, &x, &y);

                        set_geometry_color(implementation->grid_geometry, COLOR_LIGHT_YELLOW, COLOR_OPAQUE);
                        write_hexagon_geometry(implementation->grid_geometry, x, y, tile_radius + line_width / 2.0f, 0.0f);

                        // Don't use the color macros in expressions
                        if (tile_type == TILE_SPOT) {
                                set_geometry_color(implementation->grid_geometry, COLOR_GOLD, COLOR_OPAQUE);
                        } else {
                                set_geometry_color(implementation->grid_geometry, COLOR_YELLOW, COLOR_OPAQUE);
                        }

                        write_hexagon_geometry(implementation->grid_geometry, x, y, tile_radius - line_width / 2.0f, 0.0f);
                }
        }

        const float slab_thickness = thickness / 2.0f;
        const float slab_radius = tile_radius - line_width;

        for (uint8_t row = 0; row < level->rows; ++row) {
                for (uint8_t column = 0; column < level->columns; ++column) {
                        const enum TileType tile_type = implementation->tiles[(size_t)row * (size_t)level->columns + (size_t)column];
                        if (tile_type != TILE_SLAB) {
                                continue;
                        }

                        float x, y;
                        get_grid_tile_position(grid_metrics, (size_t)column, (size_t)row, &x, &y);

                        y -= slab_thickness;

                        set_geometry_color(implementation->grid_geometry, COLOR_GOLD, COLOR_OPAQUE);
                        write_hexagon_thickness_geometry(implementation->grid_geometry, x, y, slab_radius + line_width / 2.0f, slab_thickness, HEXAGON_THICKNESS_MASK_ALL);

                        set_geometry_color(implementation->grid_geometry, COLOR_LIGHT_YELLOW, COLOR_OPAQUE);
                        write_hexagon_geometry(implementation->grid_geometry, x, y, slab_radius + line_width / 2.0f, 0.0f);

                        set_geometry_color(implementation->grid_geometry, COLOR_YELLOW, COLOR_OPAQUE);
                        write_hexagon_geometry(implementation->grid_geometry, x, y, slab_radius - line_width / 2.0f, 0.0f);
                }
        }

        for (uint16_t entity_index = 0; entity_index < implementation->entity_count; ++entity_index) {
                resize_entity(implementation->entities[entity_index], implementation->grid_metrics.tile_radius);
        }
}