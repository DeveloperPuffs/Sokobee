#include <SDL_video.h>
#include <time.h>
#include <stdlib.h>

#include "SDL_video.h"

#include "Audio.h"
#include "Debug.h"
#include "Cursor.h"
#include "Layers.h"
#include "Renderer.h"
#include "Persistent.h"
#include "Defines.h"
#include "Memory.h"
#include "Scenes.h"
#include "Text.h"

static void initialize(void);

static void update(const double delta_time);

static void terminate(const int exit_code);

static SDL_Window *window = NULL;

int main(int, char *[]) {
        srand((unsigned int)time(NULL));
        initialize();

        scene_manager_present_scene(SCENE_MAIN_MENU);

        Uint64 previous_time = SDL_GetPerformanceCounter();
        while (true) {
                const Uint64 current_time = SDL_GetPerformanceCounter();
                const double delta_time = 1000.0 * (double)(current_time - previous_time) / (double)SDL_GetPerformanceFrequency();
                previous_time = current_time;
                update(delta_time);
        }

        return EXIT_FAILURE;
}

static void initialize(void) {
        send_message(MESSAGE_INFORMATION, "Initializing program...");

        if (SDL_Init(SDL_INIT_EVERYTHING) < 0) {
                send_message(MESSAGE_FATAL, "Failed to initialize program: Failed to initialize SDL: %s", SDL_GetError());
                terminate(EXIT_FAILURE);
        }

        if (!load_persistent_data()) {
                send_message(MESSAGE_FATAL, "Failed to initialize program: Failed to load persistent data");
                terminate(EXIT_FAILURE);
        }

        if (!initialize_audio()) {
                send_message(MESSAGE_FATAL, "Failed to initialize program: Failed to initialize audio");
                terminate(EXIT_FAILURE);
        }

        window = SDL_CreateWindow(WINDOW_TITLE, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, INITIAL_WINDOW_WIDTH, INITIAL_WINDOW_HEIGHT, SDL_WINDOW_RESIZABLE | SDL_WINDOW_ALLOW_HIGHDPI);
        if (window == NULL) {
                send_message(MESSAGE_FATAL, "Failed to initalize program: Failed to open window");
                terminate(EXIT_FAILURE);
        }

        if (!initialize_renderer(window)) {
                send_message(MESSAGE_FATAL, "Failed to initialize program: Failed to intialize renderer");
                terminate(EXIT_FAILURE);
        }

        if (!load_fonts()) {
                send_message(MESSAGE_FATAL, "Failed to initialize program: Failed to load fonts");
                terminate(EXIT_FAILURE);
        }

        if (!initialize_cursor()) {
                send_message(MESSAGE_FATAL, "Failed to initialize program: Failed to initialize cursor");
                terminate(EXIT_FAILURE);
        }

        if (!initialize_scene_manager()) {
                send_message(MESSAGE_FATAL, "Failed to initialize program: Failed to intialize scene manager");
                terminate(EXIT_FAILURE);
        }

        initialize_layers();
        initialize_debug_panel();

        play_music(MUSIC_BGM);

        send_message(MESSAGE_INFORMATION, "Program initialized successfully");
}

static void update(const double delta_time) {
        // I need to start profiling when the frame starts because the true FPS gets capped on some environments
        start_debug_frame_profiling();

        SDL_Event event;
        while (SDL_PollEvent(&event)) {
                if (event.type == SDL_QUIT) {
                        terminate(EXIT_SUCCESS);
                }

                if (event.type == SDL_WINDOW_MINIMIZED) {
                        SDL_Delay(WINDOW_MINIMIZED_THROTTLE);
                        return;
                }

                if (scene_manager_receive_event(&event)) {
                        continue;
                }

                if (layers_receive_event(&event)) {
                        continue;
                }

                if (debug_panel_receive_event(&event)) {
                        continue;
                }
        }

        update_layers(delta_time);
        render_background_layer();
        update_scene_manager(delta_time);
        render_transition_layer();

        update_debug_panel(delta_time);

        update_cursor(delta_time);
        request_cursor(CURSOR_ARROW);
        request_tooltip(false);

        if (!renderer_render()) {
                send_message(MESSAGE_FATAL, "Failed to render frame");
                terminate(EXIT_FAILURE);
        }

        finish_debug_frame_profiling();
}

static void terminate(const int exit_code) {
        send_message(MESSAGE_INFORMATION, "Terminating program...");

        terminate_scene_manager();
        terminate_debug_panel();
        terminate_layers();
        terminate_cursor();

        SDL_DestroyWindow(window);
        terminate_audio();
        unload_fonts();

        SDL_Quit();

        send_message(MESSAGE_INFORMATION, "Exiting program with code \"EXIT_%s\"...", exit_code == EXIT_SUCCESS ? "SUCCESS" : "FAILURE");
        flush_memory_leaks();
        exit(exit_code);
}