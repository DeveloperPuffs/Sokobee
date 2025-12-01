#pragma once

#include <stdbool.h>

#include "SDL_video.h"
#include "SDL_render.h"

typedef int *(*GeometryRequester)(size_t, size_t);
typedef int  (*VertexPopulator)(float, float, float, float, uint8_t, uint8_t, uint8_t, uint8_t);
typedef void (*DrawableCallback)(void *, GeometryRequester, VertexPopulator);

struct Drawable;

struct Drawable *create_drawable(void *const data, const DrawableCallback callback);

void destroy_drawable(struct Drawable *const drawable);

void set_drawable_z_index(struct Drawable *const drawable, const float z_index);

void set_drawable_active(struct Drawable *const drawable, const bool active);

bool initialize_renderer(SDL_Window *const window);

bool renderer_render(void);

void terminate_renderer(void);