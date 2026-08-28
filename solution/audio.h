#ifndef AUDIO_H
# define AUDIO_H

# include <SDL2/SDL_mixer.h>
# include "event.h"

typedef struct s_audio
{
    Mix_Chunk   *sfx_jump;
    Mix_Chunk   *sfx_land;
    Mix_Chunk   *sfx_collect;
    Mix_Chunk   *sfx_death;
    Mix_Chunk   *sfx_win;
    Mix_Music   *music;
}   t_audio;

int     audio_init(t_audio *audio);
void    audio_play_sfx(t_audio const *audio, t_event event);
void    audio_play_music(t_audio const *audio);
void    audio_free(t_audio *audio);

#endif
