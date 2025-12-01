#include "Renderer.h"

#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>

#include "SDL_error.h"
#include "SDL_render.h"
#include "SDL_video.h"

#include "Memory.h"
#include "Defines.h"
#include "Debug.h"
#include "Text.h"

static SDL_Renderer *renderer = NULL;
static SDL_Texture *texture_atlas = NULL;

static size_t drawable_count = 0ULL;
static size_t drawable_pool_capacity = 0ULL;
static struct Drawable **drawable_pool = NULL;
static bool should_sort_drawable_pool = false;

struct Drawable {
        void *data;
        DrawableCallback callback;
        float z_index;
        bool active;
};

struct Drawable *create_drawable(void *const data, const DrawableCallback callback) {
        struct Drawable *const drawable = (struct Drawable *)xmalloc(sizeof(struct Drawable));
        drawable->data = data;
        drawable->callback = callback;
        drawable->z_index = 0.0f;
        drawable->active = true;

        if (drawable_count >= drawable_pool_capacity) {
                drawable_pool_capacity *= 2ULL;
                drawable_pool = (struct Drawable **)xrealloc(drawable_pool, drawable_pool_capacity * sizeof(struct Drawable *));
        }

        drawable_pool[drawable_count++] = drawable;
        should_sort_drawable_pool = true;

        return drawable;
}

void destroy_drawable(struct Drawable *const drawable) {
        if (drawable == NULL) {
                send_message(MESSAGE_WARNING, "Drawable given to destroy is NULL");
                return;
        }

        bool found_drawable = false;
        for (size_t drawable_index = 0ULL; drawable_index < drawable_count; ++drawable_index) {
                if (drawable_pool[drawable_index] == drawable) {
                        found_drawable = true;
                        --drawable_count;

                        for (size_t other_drawable_index = drawable_index; other_drawable_index < drawable_count; ++other_drawable_index) {
                                drawable_pool[other_drawable_index] = drawable_pool[other_drawable_index + 1ULL];
                        }

                        break;
                }
        }

        xfree(drawable);

        if (!found_drawable) {
                send_message(MESSAGE_WARNING, "Couldn't find drawable %p in drawable pool while destroying drawable", drawable);
                return;
        }

        if (drawable_count < drawable_pool_capacity / 4ULL) {
                drawable_pool_capacity /= 2ULL;
                drawable_pool = xrealloc(drawable_pool, drawable_pool_capacity * sizeof(struct Drawable *));
        }
}

void set_drawable_z_index(struct Drawable *const drawable, const float z_index) {
        ASSERT_ALL(drawable != NULL);

        if (drawable->z_index == z_index) {
                return;
        }

        drawable->z_index = z_index;
        should_sort_drawable_pool = true;
}

void set_drawable_active(struct Drawable *const drawable, const bool active) {
        ASSERT_ALL(drawable != NULL);
        drawable->active = active;
}

static size_t vertex_buffer_capacity = 0ULL;
static SDL_Vertex *vertex_buffer = NULL;
static size_t index_buffer_capacity = 0ULL;
static int *index_buffer = NULL;

// This should be per-frame data, but they are global variables only because of 'request_vertices()' and 'request_indices()'
static size_t vertex_count = 0ULL;
static size_t index_count = 0ULL;

static int *request_geometry(const size_t vertices, const size_t indices) {
        ASSERT_ALL(vertex_buffer_capacity != 0ULL, vertex_buffer != NULL, index_buffer_capacity != 0ULL, index_buffer != NULL, vertices != 0ULL, indices != 0ULL);

        vertex_count += vertices;

        bool resized_vertex_buffer = false;
        while (vertex_count > vertex_buffer_capacity) {
                vertex_buffer_capacity *= 2ULL;
                resized_vertex_buffer = true;
        }

        if (resized_vertex_buffer) {
                vertex_buffer = (struct SDL_Vertex *)xrealloc(vertex_buffer, vertex_buffer_capacity * sizeof(struct SDL_Vertex));
        }

        const size_t requested_indices_index = index_count;
        index_count += indices;

        bool resized_index_buffer = false;
        while (index_count > vertex_buffer_capacity) {
                vertex_buffer_capacity *= 2ULL;
                resized_index_buffer = true;
        }

        if (resized_index_buffer) {
                index_buffer = (int *)xrealloc(index_buffer, index_buffer_capacity * sizeof(int));
        }

        return &index_buffer[requested_indices_index];
}

static int populate_vertex(const float x, const float y, const float u, const float v, const uint8_t r, const uint8_t g, const uint8_t b, const uint8_t a) {
        vertex_buffer[vertex_count].position.x = x;
        vertex_buffer[vertex_count].position.y = y;
        vertex_buffer[vertex_count].tex_coord.x = u;
        vertex_buffer[vertex_count].tex_coord.y = v;
        vertex_buffer[vertex_count].color.r = r;
        vertex_buffer[vertex_count].color.g = g;
        vertex_buffer[vertex_count].color.b = b;
        vertex_buffer[vertex_count].color.a = a;
        return (uint16_t)vertex_count++;
}

bool initialize_renderer(SDL_Window *const window) {
        ASSERT_ALL(window != NULL);

        renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
        if (renderer == NULL) {
                send_message(MESSAGE_ERROR, "Failed to initialize renderer: Failed to create renderer: %s", SDL_GetError());
                terminate_renderer();
                return false;
        }

        SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);

        // Create a 1x1 white surface for the texture coordinates of the geometries
        SDL_Surface *const surface = SDL_CreateRGBSurfaceWithFormat(0, 1, 1, 32, SDL_PIXELFORMAT_RGBA32);
        if (surface == NULL) {
                send_message(MESSAGE_ERROR, "Failed to initialize renderer: Failed to create texture atlas surface");
                terminate_renderer();
                return false;
        }

        *(Uint32 *)surface->pixels = SDL_MapRGBA(surface->format, 255, 255, 255, 255);
        texture_atlas = SDL_CreateTextureFromSurface(renderer, surface);
        SDL_FreeSurface(surface);

        if (texture_atlas == NULL) {
                send_message(MESSAGE_ERROR, "Failed to initialize renderer: Failed to create texture from texture atlas surface");
                terminate_renderer();
                return false;
        }

        vertex_buffer_capacity = (size_t)INITIAL_VERTEX_BUFFER_CAPACITY;
        vertex_buffer = (struct SDL_Vertex *)xmalloc(vertex_buffer_capacity * sizeof(struct SDL_Vertex));

        index_buffer_capacity = (size_t)INITIAL_INDEX_BUFFER_CAPACITY;
        index_buffer = (int *)xmalloc(index_buffer_capacity * sizeof(int));

        return true;
}

static int compare_drawables(const void *const lhs, const void *const rhs) {
        return ((const struct Drawable *)lhs)->z_index - ((const struct Drawable *)rhs)->z_index;
}

bool renderer_render(void) {
        ASSERT_ALL(renderer != NULL, texture_atlas != NULL, drawable_pool != NULL, vertex_buffer != NULL, index_buffer != NULL);

        if (SDL_SetRenderDrawColor(renderer, RENDERER_BACKGROUND_COLOR) != 0) {
                send_message(MESSAGE_ERROR, "Failed to render: Failed to set renderer clear color: %s", SDL_GetError());
                return false;
        }

        if (SDL_RenderClear(renderer) != 0) {
                send_message(MESSAGE_ERROR, "Failed to render: Failed to clear renderer: %s", SDL_GetError());
                return false;
        }

        if (drawable_count != 0ULL) {
                if (should_sort_drawable_pool) {
                        qsort((void *)drawable_pool, drawable_count, sizeof(struct Drawable *), compare_drawables);
                        should_sort_drawable_pool = false;
                }

                for (size_t drawable_index = 0ULL; drawable_index < drawable_count; ++drawable_index) {
                        struct Drawable *const drawable = drawable_pool[drawable_index];
                        if (!drawable->active) {
                                continue;
                        }

                        drawable->callback(drawable->data, request_geometry, populate_vertex);
                }

                if (SDL_RenderGeometry(renderer, texture_atlas, vertex_buffer, (int)vertex_count, index_buffer, (int)index_count) != 0) {
                        send_message(MESSAGE_ERROR, "Failed to render: %s", SDL_GetError());
                        return false;
                }
        }

        SDL_RenderPresent(renderer);
        return true;
}

void terminate_renderer(void) {
        if (index_buffer != NULL) {
                xfree(index_buffer);
                index_buffer = NULL;
        }

        index_buffer_capacity = 0ULL;

        if (vertex_buffer != NULL) {
                xfree(vertex_buffer);
                vertex_buffer = NULL;
        }

        vertex_buffer_capacity = 0ULL;

        if (texture_atlas != NULL) {
                SDL_DestroyTexture(texture_atlas);
                texture_atlas = NULL;
        }

        if (renderer != NULL) {
                SDL_DestroyRenderer(renderer);
                renderer = NULL;
        }
}