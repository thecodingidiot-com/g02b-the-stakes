#include <SDL2/SDL.h>
#include <SDL2/SDL_image.h>
#include "libtci.h"
#include "map.h"
#include "player.h"
#include "camera.h"
#include "render.h"
#include "audio.h"

/* map_try_collect/map_check_hazard/map_check_goal only ever return
 * EVENT_NONE, EVENT_COLLECTED, EVENT_DIED, or EVENT_WON -- this
 * handles exactly those three, on top of the sfx every event gets. */
static void handle_terminal_event(t_map const *map, t_player *p,
        t_audio const *audio, t_event event, int *score)
{
    audio_play_sfx(audio, event);
    if (event == EVENT_COLLECTED) {
        *score = *score + 1;
        tci_printf("score: %d\n", *score);
    } else if (event == EVENT_DIED || event == EVENT_WON) {
        Mix_HaltMusic();
        player_init(p, (float)map->start_x, (float)map->start_y);
        audio_play_music(audio);
    }
}

int main(int argc, char **argv)
{
    SDL_Window      *win;
    SDL_Renderer    *ren;
    SDL_Event       ev;
    SDL_Texture     *tileset;
    SDL_Texture     *spritesheet;
    t_map           map;
    t_player        player;
    t_camera        camera;
    t_audio         audio;
    Uint8 const     *keys;
    int             running;
    int             score;

    if (argc < 2) {
        tci_printf("usage: %s <map_file>\n", argv[0]);
        return (1);
    }
    if (!map_load(&map, argv[1])) {
        tci_printf("failed to load map: %s\n", argv[1]);
        return (1);
    }
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) != 0) {
        SDL_Log("SDL_Init: %s", SDL_GetError());
        return (1);
    }
    win = SDL_CreateWindow("g02b", SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED, WINDOW_W, WINDOW_H, 0);
    ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
    IMG_Init(IMG_INIT_PNG);
    tileset = IMG_LoadTexture(ren, "assets/tileset.png");
    spritesheet = IMG_LoadTexture(ren, "assets/spritesheet.png");
    if (!audio_init(&audio)) {
        SDL_Log("audio_init: %s", Mix_GetError());
        return (1);
    }
    player_init(&player, (float)map.start_x, (float)map.start_y);
    camera_init(&camera);
    audio_play_music(&audio);
    score = 0;
    running = 1;
    while (running) {
        while (SDL_PollEvent(&ev)) {
            if (ev.type == SDL_QUIT)
                running = 0;
            if (ev.type == SDL_KEYDOWN && (ev.key.keysym.sym == SDLK_ESCAPE
                    || ev.key.keysym.sym == SDLK_q))
                running = 0;
        }
        keys = SDL_GetKeyboardState(NULL);
        audio_play_sfx(&audio, player_handle_input(&player, keys));
        player_update_physics(&player);
        audio_play_sfx(&audio, player_resolve_collision(&player, &map));
        handle_terminal_event(&map, &player, &audio,
            map_try_collect(&map, &player), &score);
        handle_terminal_event(&map, &player, &audio,
            map_check_hazard(&map, &player), &score);
        handle_terminal_event(&map, &player, &audio,
            map_check_goal(&map, &player), &score);
        player_update_animation(&player);
        camera_update(&camera, player.x, &map);
        SDL_SetRenderDrawColor(ren, 100, 149, 237, 255);
        SDL_RenderClear(ren);
        render_map(&map, ren, tileset, camera.x);
        render_player(&player, ren, spritesheet, camera.x);
        SDL_RenderPresent(ren);
        SDL_Delay(16);
    }
    audio_free(&audio);
    SDL_DestroyTexture(tileset);
    SDL_DestroyTexture(spritesheet);
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    IMG_Quit();
    SDL_Quit();
    map_free(&map);
    return (0);
}
