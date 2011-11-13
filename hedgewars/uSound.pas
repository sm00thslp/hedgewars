(*
 * Hedgewars, a free turn based strategy game
 * Copyright (c) 2004-2011 Andrey Korotaev <unC0Rr@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 2 of the License
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
 *)

{$INCLUDE "options.inc"}

unit uSound;
(*
 * This unit controls the sounds and music of the game.
 * Doesn't really do anything if isSoundEnabled = false.
 *
 * There are three basic types of sound controls:
 *    Music        - The background music of the game:
 *                   * will only be played if isMusicEnabled = true
 *                   * can be started, changed, paused and resumed
 *    Sound        - Can be started and stopped
 *    Looped Sound - Subtype of sound: plays in a loop using a
 *                   "channel", of which the id is returned on start.
 *                   The channel id can be used to stop a specific sound loop.
 *)
interface
uses SDLh, uConsts, uTypes, sysutils;

var MusicFN: shortstring; // music file name

procedure initModule;
procedure freeModule;

procedure InitSound; // Initiates sound-system if isSoundEnabled.
procedure ReleaseSound(complete: boolean); // Releases sound-system and used resources.
procedure SoundLoad; // Preloads some sounds for performance reasons.


// MUSIC

// Obvious music commands for music track specified in MusicFN.
procedure PlayMusic;
procedure PauseMusic;
procedure ResumeMusic;
procedure ChangeMusic; // Replaces music track with current MusicFN and plays it.


// SOUNDS

// Plays the sound snd [from a given voicepack],
// if keepPlaying is given and true,
// then the sound's playback won't be interrupted if asked to play again.
procedure PlaySound(snd: TSound);
procedure PlaySound(snd: TSound; keepPlaying: boolean);
procedure PlaySound(snd: TSound; voicepack: PVoicepack);
procedure PlaySound(snd: TSound; voicepack: PVoicepack; keepPlaying: boolean);

// Plays sound snd [of voicepack] in a loop, but starts with fadems milliseconds of fade-in.
// Returns sound channel of the looped sound.
function  LoopSound(snd: TSound): LongInt;
function  LoopSound(snd: TSound; fadems: LongInt): LongInt;
function  LoopSound(snd: TSound; voicepack: PVoicepack): LongInt; // WTF?
function  LoopSound(snd: TSound; voicepack: PVoicepack; fadems: LongInt): LongInt;

// Stops the normal/looped sound of the given type/in the given channel
// [with a fade-out effect for fadems milliseconds].
procedure StopSound(snd: TSound);
procedure StopSound(chn: LongInt);
procedure StopSound(chn, fadems: LongInt);

procedure AddVoice(snd: TSound; voicepack: PVoicepack);
procedure PlayNextVoice;


// MISC

// Modifies the sound volume of the game by voldelta and returns the new volume level.
function  ChangeVolume(voldelta: LongInt): LongInt;

// Returns a pointer to the voicepack with the given name.
function  AskForVoicepack(name: shortstring): Pointer;


implementation
uses uVariables, uConsole, uUtils, uCommands, uDebug;

const chanTPU = 32;
var Volume: LongInt;
    lastChan: array [TSound] of LongInt;
    voicepacks: array[0..cMaxTeams] of TVoicepack;
    defVoicepack: PVoicepack;
    Mus: PMixMusic = nil;

function  AskForVoicepack(name: shortstring): Pointer;
var i: Longword;
    locName, path: shortstring;
begin
i:= 0;
    // First, attempt to locate a localised version of the voice
    if cLocale <> 'en' then
        begin
        locName:= name+'_'+cLocale;
        path:= UserPathz[ptVoices] + '/' + locName;
        if DirectoryExists(path) then name:= locName
        else
            begin
            path:= Pathz[ptVoices] + '/' + locName;
            if DirectoryExists(path) then name:= locName
            else if Length(cLocale) > 2 then
                begin
                locName:= name+'_'+Copy(cLocale,1,2);
                path:= UserPathz[ptVoices] + '/' + locName;
                if DirectoryExists(path) then name:= locName
                else
                    begin
                    path:= Pathz[ptVoices] + '/' + locName;
                    if DirectoryExists(path) then name:= locName
                    end
                end
            end
        end;

    // If that fails, use the unmodified one
    while (voicepacks[i].name <> name) and (voicepacks[i].name <> '') do
        begin
        inc(i);
        TryDo(i <= cMaxTeams, 'Engine bug: AskForVoicepack i > cMaxTeams', true)
        end;

    voicepacks[i].name:= name;
    AskForVoicepack:= @voicepacks[i]
end;

procedure InitSound;
var i: TSound;
    channels: LongInt;
begin
    if not isSoundEnabled then exit;
    WriteToConsole('Init sound...');
    isSoundEnabled:= SDL_InitSubSystem(SDL_INIT_AUDIO) >= 0;

{$IFDEF IPHONEOS}
    channels:= 1;
{$ELSE}
    channels:= 2;
{$ENDIF}

    if isSoundEnabled then
        isSoundEnabled:= Mix_OpenAudio(44100, $8010, channels, 1024) = 0;

    WriteToConsole('Init SDL_mixer... ');
    SDLTry(Mix_Init(MIX_INIT_OGG) <> 0, true);
    WriteLnToConsole(msgOK);

    if isSoundEnabled then
        WriteLnToConsole(msgOK)
    else
        WriteLnToConsole(msgFailed);

    Mix_AllocateChannels(Succ(chanTPU));
    if isMusicEnabled then
        Mix_VolumeMusic(50);
    for i:= Low(TSound) to High(TSound) do
        lastChan[i]:= -1;

    Volume:= 0;
    ChangeVolume(cInitVolume)
end;

// when complete is false, this procedure just releases some of the chucks on inactive channels
// this way music is not stopped, nor are chucks currently being plauyed
procedure ReleaseSound(complete: boolean);
var i: TSound;
    t: Longword;
begin
    // release and nil all sounds
    for t:= 0 to cMaxTeams do
        if voicepacks[t].name <> '' then
            for i:= Low(TSound) to High(TSound) do
                if voicepacks[t].chunks[i] <> nil then
                    if complete or (Mix_Playing(lastChan[i]) = 0) then
                        begin
                        Mix_HaltChannel(lastChan[i]);
                        lastChan[i]:= -1;
                        Mix_FreeChunk(voicepacks[t].chunks[i]);
                        voicepacks[t].chunks[i]:= nil;
                        end;

    // stop music
    if complete then
        begin
        if Mus <> nil then
            begin
            Mix_HaltMusic();
            Mix_FreeMusic(Mus);
            Mus:= nil;
            end;

        // make sure all instances of sdl_mixer are unloaded before continuing
        while Mix_Init(0) <> 0 do
            Mix_Quit();

        Mix_CloseAudio();
        end;
end;

procedure SoundLoad;
var i: TSound;
    t: Longword;
    s:shortstring;
begin
    if not isSoundEnabled then exit;

    defVoicepack:= AskForVoicepack('Default');

    // initialize all voices to nil so that they can be loaded when needed
    for t:= 0 to cMaxTeams do
        if voicepacks[t].name <> '' then
            for i:= Low(TSound) to High(TSound) do
                voicepacks[t].chunks[i]:= nil;

    // preload all the big sound files (>32k) that would otherwise lockup the game
    for i:= Low(TSound) to High(TSound) do
    begin
        defVoicepack^.chunks[i]:= nil;
        if (i in [sndBeeWater, sndBee, sndCake, sndHellishImpact1, sndHellish, sndHomerun,
                  sndMolotov, sndMortar, sndRideOfTheValkyries, sndYoohoo])
            and (Soundz[i].Path <> ptVoices) and (Soundz[i].FileName <> '') then
        begin
            s:= UserPathz[Soundz[i].Path] + '/' + Soundz[i].FileName;
            if not FileExists(s) then s:= Pathz[Soundz[i].Path] + '/' + Soundz[i].FileName;
            WriteToConsole(msgLoading + s + ' ');
            defVoicepack^.chunks[i]:= Mix_LoadWAV_RW(SDL_RWFromFile(Str2PChar(s), 'rb'), 1);
            TryDo(defVoicepack^.chunks[i] <> nil, msgFailed, true);
            WriteLnToConsole(msgOK);
        end;
    end;

end;

procedure PlaySound(snd: TSound);
begin
    PlaySound(snd, nil, false);
end;

procedure PlaySound(snd: TSound; keepPlaying: boolean);
begin
    PlaySound(snd, nil, keepPlaying);
end;

procedure PlaySound(snd: TSound; voicepack: PVoicepack);
begin
    PlaySound(snd, voicepack, false);
end;

procedure PlaySound(snd: TSound; voicepack: PVoicepack; keepPlaying: boolean);
var s:shortstring;
begin
    if (not isSoundEnabled) or fastUntilLag then
        exit;

    if keepPlaying and (lastChan[snd] <> -1) and (Mix_Playing(lastChan[snd]) <> 0) then
        exit;

    if (voicepack <> nil) then
        begin
        if (voicepack^.chunks[snd] = nil) and (Soundz[snd].Path = ptVoices) and (Soundz[snd].FileName <> '') then
            begin
            s:= UserPathz[Soundz[snd].Path] + '/' + voicepack^.name + '/' + Soundz[snd].FileName;
            if not FileExists(s) then s:= Pathz[Soundz[snd].Path] + '/' + voicepack^.name + '/' + Soundz[snd].FileName;
            WriteToConsole(msgLoading + s + ' ');
            voicepack^.chunks[snd]:= Mix_LoadWAV_RW(SDL_RWFromFile(Str2PChar(s), 'rb'), 1);
            if voicepack^.chunks[snd] = nil then
                WriteLnToConsole(msgFailed)
            else
                WriteLnToConsole(msgOK)
            end;
        lastChan[snd]:= Mix_PlayChannelTimed(-1, voicepack^.chunks[snd], 0, -1)
        end
    else
        begin
        if (defVoicepack^.chunks[snd] = nil) and (Soundz[snd].Path <> ptVoices) and (Soundz[snd].FileName <> '') then
            begin
            s:= UserPathz[Soundz[snd].Path] + '/' + Soundz[snd].FileName;
            if not FileExists(s) then s:= Pathz[Soundz[snd].Path] + '/' + Soundz[snd].FileName;
            WriteToConsole(msgLoading + s + ' ');
            defVoicepack^.chunks[snd]:= Mix_LoadWAV_RW(SDL_RWFromFile(Str2PChar(s), 'rb'), 1);
            TryDo(defVoicepack^.chunks[snd] <> nil, msgFailed, true);
            WriteLnToConsole(msgOK);
            end;
        lastChan[snd]:= Mix_PlayChannelTimed(-1, defVoicepack^.chunks[snd], 0, -1)
        end;
end;

procedure AddVoice(snd: TSound; voicepack: PVoicepack);
var i : LongInt;
begin
    if (not isSoundEnabled) or fastUntilLag or ((LastVoice.snd = snd) and  (LastVoice.voicepack = voicepack)) then exit;
    if (snd = sndVictory) or (snd = sndFlawless) then
        begin
        for i:= 1 to Succ(chanTPU) do StopSound(i);
        for i:= 0 to 7 do VoiceList[i].snd:= sndNone;
        LastVoice.snd:= sndNone;
        end;

    i:= 0;
    while (i<8) and (VoiceList[i].snd <> sndNone) do inc(i);

    // skip playing same sound for same hog twice
    if (i>0) and (VoiceList[i-1].snd = snd) and (VoiceList[i-1].voicepack = voicepack) then exit;
    VoiceList[i].snd:= snd;
    VoiceList[i].voicepack:= voicepack;
end;

procedure PlayNextVoice;
var i : LongInt;
begin
    if (not isSoundEnabled) or fastUntilLag or ((LastVoice.snd <> sndNone) and (lastChan[LastVoice.snd] <> -1) and (Mix_Playing(lastChan[LastVoice.snd]) <> 0)) then exit;
    i:= 0;
    while (i<8) and (VoiceList[i].snd = sndNone) do inc(i);
    
    if (VoiceList[i].snd <> sndNone) then
        begin
        LastVoice.snd:= VoiceList[i].snd;
        LastVoice.voicepack:= VoiceList[i].voicepack;
        VoiceList[i].snd:= sndNone;
        PlaySound(LastVoice.snd, LastVoice.voicepack)
        end
    else LastVoice.snd:= sndNone;
end;

function LoopSound(snd: TSound): LongInt;
begin
    LoopSound:= LoopSound(snd, nil)
end;

function LoopSound(snd: TSound; fadems: LongInt): LongInt;
begin
    LoopSound:= LoopSound(snd, nil, fadems)
end;

function LoopSound(snd: TSound; voicepack: PVoicepack): LongInt;
begin
    voicepack:= voicepack;    // avoid compiler hint
    LoopSound:= LoopSound(snd, nil, 0)
end;

function LoopSound(snd: TSound; voicepack: PVoicepack; fadems: LongInt): LongInt;
var s: shortstring;
begin
    if (not isSoundEnabled) or fastUntilLag then
    begin
        LoopSound:= -1;
        exit
    end;

    if (voicepack <> nil) then
    begin
        if (voicepack^.chunks[snd] = nil) and (Soundz[snd].Path = ptVoices) and (Soundz[snd].FileName <> '') then
        begin
            s:= UserPathz[Soundz[snd].Path] + '/' + voicepack^.name + '/' + Soundz[snd].FileName;
            if not FileExists(s) then s:= Pathz[Soundz[snd].Path] + '/' + voicepack^.name + '/' + Soundz[snd].FileName;
            WriteToConsole(msgLoading + s + ' ');
            voicepack^.chunks[snd]:= Mix_LoadWAV_RW(SDL_RWFromFile(Str2PChar(s), 'rb'), 1);
            if voicepack^.chunks[snd] = nil then
                WriteLnToConsole(msgFailed)
            else
                WriteLnToConsole(msgOK)
        end;
        LoopSound:= Mix_PlayChannelTimed(-1, voicepack^.chunks[snd], -1, -1)
    end
    else
    begin
        if (defVoicepack^.chunks[snd] = nil) and (Soundz[snd].Path <> ptVoices) and (Soundz[snd].FileName <> '') then
        begin
            s:= UserPathz[Soundz[snd].Path] + '/' + Soundz[snd].FileName;
            if not FileExists(s) then s:= Pathz[Soundz[snd].Path] + '/' + Soundz[snd].FileName;
            WriteToConsole(msgLoading + s + ' ');
            defVoicepack^.chunks[snd]:= Mix_LoadWAV_RW(SDL_RWFromFile(Str2PChar(s), 'rb'), 1);
            TryDo(defVoicepack^.chunks[snd] <> nil, msgFailed, true);
            WriteLnToConsole(msgOK);
        end;
        if fadems > 0 then
            LoopSound:= Mix_FadeInChannelTimed(-1, defVoicepack^.chunks[snd], -1, fadems, -1)
        else
            LoopSound:= Mix_PlayChannelTimed(-1, defVoicepack^.chunks[snd], -1, -1);
    end;
end;

procedure StopSound(snd: TSound);
begin
    if not isSoundEnabled then exit;

    if (lastChan[snd] <> -1) and (Mix_Playing(lastChan[snd]) <> 0) then
    begin
        Mix_HaltChannel(lastChan[snd]);
        lastChan[snd]:= -1;
    end;
end;

procedure StopSound(chn: LongInt);
begin
    if not isSoundEnabled then exit;

    if (chn <> -1) and (Mix_Playing(chn) <> 0) then
        Mix_HaltChannel(chn);
end;

procedure StopSound(chn, fadems: LongInt);
begin
    if not isSoundEnabled then exit;

    if (chn <> -1) and (Mix_Playing(chn) <> 0) then
        Mix_FadeOutChannel(chn, fadems);
end;

procedure PlayMusic;
var s: shortstring;
begin
    if (not isSoundEnabled) or (MusicFN = '') or (not isMusicEnabled) then
        exit;

    s:= UserPathPrefix + '/Data/Music/' + MusicFN;
    if not FileExists(s) then s:= PathPrefix + '/Music/' + MusicFN;
    WriteToConsole(msgLoading + s + ' ');

    Mus:= Mix_LoadMUS(Str2PChar(s));
    TryDo(Mus <> nil, msgFailed, false);
    WriteLnToConsole(msgOK);

    SDLTry(Mix_FadeInMusic(Mus, -1, 3000) <> -1, false)
end;

function ChangeVolume(voldelta: LongInt): LongInt;
begin
    if not isSoundEnabled then
        exit(0);

    inc(Volume, voldelta);
    if Volume < 0 then Volume:= 0;
    Mix_Volume(-1, Volume);
    Volume:= Mix_Volume(-1, -1);
    if isMusicEnabled then Mix_VolumeMusic(Volume * 4 div 8);
    ChangeVolume:= Volume * 100 div MIX_MAX_VOLUME
end;

procedure PauseMusic;
begin
    if (MusicFN = '') or (not isMusicEnabled) then
        exit;

    Mix_PauseMusic(Mus);
end;

procedure ResumeMusic;
begin
    if (MusicFN = '') or (not isMusicEnabled) then
        exit;

    Mix_ResumeMusic(Mus);
end;

procedure ChangeMusic;
begin
    if (MusicFN = '') or (not isMusicEnabled) then
        exit;

    // get rid of current music
    if Mus <> nil then
        Mix_FreeMusic(Mus);

    PlayMusic;
end;

procedure chVoicepack(var s: shortstring);
begin
    if CurrentTeam = nil then OutError(errmsgIncorrectUse + ' "/voicepack"', true);
    if s[1]='"' then Delete(s, 1, 1);
    if s[byte(s[0])]='"' then Delete(s, byte(s[0]), 1);
    CurrentTeam^.voicepack:= AskForVoicepack(s)
end;

procedure initModule;
begin
    RegisterVariable('voicepack', vtCommand, @chVoicepack, false);
    MusicFN:='';
end;

procedure freeModule;
begin
    if isSoundEnabled then
        ReleaseSound(true);
end;

end.

