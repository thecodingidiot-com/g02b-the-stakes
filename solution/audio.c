#include "audio.h"

int audio_init(t_audio *audio)
{
    if (Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, 2, 1024) != 0)
        return (0);
    Mix_AllocateChannels(8);
    audio->sfx_jump = Mix_LoadWAV("assets/sfx_jump.wav");
    audio->sfx_land = Mix_LoadWAV("assets/sfx_land.wav");
    audio->sfx_collect = Mix_LoadWAV("assets/sfx_collect.wav");
    audio->sfx_death = Mix_LoadWAV("assets/sfx_death.wav");
    audio->sfx_win = Mix_LoadWAV("assets/sfx_win.wav");
    audio->music = Mix_LoadMUS("assets/music.wav");
    if (!audio->sfx_jump || !audio->sfx_land || !audio->sfx_collect
            || !audio->sfx_death || !audio->sfx_win || !audio->music)
        return (0);
    return (1);
}

void audio_play_sfx(t_audio const *audio, t_event event)
{
    if (event == EVENT_JUMPED)
        Mix_PlayChannel(-1, audio->sfx_jump, 0);
    else if (event == EVENT_LANDED)
        Mix_PlayChannel(-1, audio->sfx_land, 0);
    else if (event == EVENT_COLLECTED)
        Mix_PlayChannel(-1, audio->sfx_collect, 0);
    else if (event == EVENT_DIED)
        Mix_PlayChannel(-1, audio->sfx_death, 0);
    else if (event == EVENT_WON)
        Mix_PlayChannel(-1, audio->sfx_win, 0);
}

void audio_play_music(t_audio const *audio)
{
    Mix_PlayMusic(audio->music, -1);
}

void audio_free(t_audio *audio)
{
    Mix_HaltMusic();
    Mix_FreeMusic(audio->music);
    Mix_FreeChunk(audio->sfx_jump);
    Mix_FreeChunk(audio->sfx_land);
    Mix_FreeChunk(audio->sfx_collect);
    Mix_FreeChunk(audio->sfx_death);
    Mix_FreeChunk(audio->sfx_win);
    Mix_CloseAudio();
}
