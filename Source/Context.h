#pragma once

#include <stdbool.h>

#include "SDL_render.h"

#define MISSING_TEXTURE_WIDTH  64
#define MISSING_TEXTURE_HEIGHT 64

SDL_Window *get_context_window(void);

SDL_Renderer *get_context_renderer(void);

SDL_Texture *get_mising_texture(void);

bool initialize_context(void);

void terminate_context(void);

bool apply_missing_texture(SDL_Texture *const texture);