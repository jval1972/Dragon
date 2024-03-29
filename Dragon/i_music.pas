//
//  Dragon
//  A game for Windows based on a modified and improved version of the
//  DelphiDoom engine
//
//  Copyright (C) 1993-1996 by id Software, Inc.
//  Copyright (C) 2004-2022 by Jim Valavanis
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
//  02111-1307, USA.
//
//------------------------------------------------------------------------------
//  Site  : https://sourceforge.net/projects/dragon-game/
//------------------------------------------------------------------------------

{$I dragon.inc}

unit i_music;

interface

uses
  d_delphi;

//==============================================================================
// I_InitMusic
//
//  MUSIC I/O
//
//==============================================================================
procedure I_InitMusic;

//==============================================================================
//
// I_ShutDownMusic
//
//==============================================================================
procedure I_ShutDownMusic;

//==============================================================================
// I_SetMusicVolume
//
// Volume.
//
//==============================================================================
procedure I_SetMusicVolume(volume: integer);

//==============================================================================
// I_PauseSong
//
// PAUSE game handling.
//
//==============================================================================
procedure I_PauseSong(handle: integer);

//==============================================================================
//
// I_ResumeSong
//
//==============================================================================
procedure I_ResumeSong(handle: integer);

//==============================================================================
// I_RegisterSong
//
// Registers a song handle to song data.
//
//==============================================================================
function I_RegisterSong(data: pointer; size: integer): integer;

//==============================================================================
// I_PlaySong
//
// Called by anything that wishes to start music.
//  plays a song, and when the song is done,
//  starts playing it again in an endless loop.
// Horrible thing to do, considering.
//
//==============================================================================
procedure I_PlaySong(handle: integer; looping: boolean);

//==============================================================================
// I_UnRegisterSong
//
// See above (register), then think backwards
//
//==============================================================================
procedure I_UnRegisterSong(handle: integer);

//==============================================================================
//
// I_ProcessMusic
//
//==============================================================================
procedure I_ProcessMusic;

const
  MP3MAGIC = $1A33504D; //"MP3"<EOF>

type
  mp3header_t = packed record
    ID: LongWord; // MP3MAGIC "MP3" 0x1A
    Stream: TStream;
    foo: array[0..1] of LongWord;
  end;
  Pmp3header_t = ^mp3header_t;

var
  miditempo: integer = 128;

implementation

uses
  Windows,
  MMSystem,
  m_argv,
  i_system,
  i_midi,
  i_mp3,
  i_tmp,
  s_sound,
  
  z_zone;

type
  music_t = (m_none, m_mus, m_midi, m_mp3);

const
  MAX_MIDI_EVENTS = 512;
  MUSMAGIC = $1A53554D; //"MUS"<EOF>

var
  hMidiStream: HMIDISTRM = 0;
  MidiDevice: LongWord;
  midicaps: MIDIOUTCAPS;
  m_type: music_t = m_none;
  MidiFileName: string;

type
  MidiEvent_t = packed record
    time: LongWord;                  { Ticks since last event }
    ID: LongWord;                    { Reserved, must be zero }
    case integer of
      1: (data: packed array[0..2] of byte;
         _type: byte);
      2: (mevent: LongWord);
  end;
  PMidiEvent_t = ^MidiEvent_t;
  MidiEvent_tArray = array[0..$FFFF] of MidiEvent_t;
  PMidiEvent_tArray = ^MidiEvent_tArray;

  Pmidiheader_t = ^midiheader_t;
  midiheader_t = record
    lpData: pointer;             { pointer to locked data block }
    dwBufferLength: LongWord;    { length of data in data block }
    dwBytesRecorded: LongWord;   { used for input only }
    dwUser: LongWord;            { for client's use }
    dwFlags: LongWord;           { assorted flags (see defines) }
    lpNext: Pmidiheader_t;       { reserved for driver }
    reserved: LongWord;          { reserved for driver }
    dwOffset: LongWord;          { Callback offset into buffer }
    dwReserved: array[0..7] of LongWord; { Reserved for MMSYSTEM }
  end;

  musheader_t = packed record
    ID: LongWord;       // identifier "MUS" 0x1A
    scoreLen: word;
    scoreStart: word;
    channels: word;     // count of primary channels
    sec_channels: word; // count of secondary channels
    instrCnt: word;
    dummy: word;
  end;
  Pmusheader_t = ^musheader_t;

const
  NUMMIDIHEADERS = 2;

type
  songinfo_t = record
    numevents: integer;
    nextevent: integer;
    midievents: PMidiEvent_tArray;
    header: array[0..NUMMIDIHEADERS - 1] of midiheader_t;
  end;
  Psonginfo_t = ^songinfo_t;

const
  MidiControlers: packed array[0..9] of byte =
    (0, 0, 1, 7, 10, 11, 91, 93, 64, 67);

var
  musicstarted: boolean = false;
  CurrentSong: Psonginfo_t = nil;

//==============================================================================
//
// XLateMUSControl
//
//==============================================================================
function XLateMUSControl(control: byte): byte;
begin
  case control of
    10: result := 120;
    11: result := 123;
    12: result := 126;
    13: result := 127;
    14: result := 121;
  else
    begin
      I_Error('XLateMUSControl(): Unknown control %d', [control]);
      result := 0;
    end;
  end;
end;

const
  NUMTEMPOEVENTS = 2;

//==============================================================================
//
// GetSongLength
//
//==============================================================================
function GetSongLength(data: PByteArray): integer;
var
  done: boolean;
  events: integer;
  header: Pmusheader_t;
  time: boolean;
  i: integer;
begin
  header := Pmusheader_t(data);
  i := header.scoreStart;
  events := 0;
  done := header.ID <> MUSMAGIC;
  time := false;
  while not done do
  begin
    if data[i] and $80 <> 0 then
      time := true;
    inc(i);
    case _SHR(data[i - 1], 4) and 7 of
      1:
        begin
          if data[i] and $80 <> 0 then
            inc(i);
          inc(i);
        end;
      0,
      2,
      3: inc(i);
      4: inc(i, 2);
    else
      done := true;
    end;
    inc(events);
    if time then
    begin
      while data[i] and $80 <> 0 do
        inc(i);
      inc(i);
      time := false;
    end;
  end;
  result := events + NUMTEMPOEVENTS;
end;

//==============================================================================
//
// I_MusToMidi
//
//==============================================================================
function I_MusToMidi(MusData: PByteArray; MidiEvents: PMidiEvent_tArray): boolean;
var
  header: Pmusheader_t;
  score: PByteArray;
  spos: integer;
  event: PMidiEvent_t;
  channel: byte;
  etype: integer;
  delta: integer;
  finished: boolean;
  channelvol: array[0..15] of byte;
  count: integer;
  i: integer;
begin
  header := Pmusheader_t(MusData);
  result := header.ID = MUSMAGIC;
  if not result then
  begin
    I_Warning('I_MusToMidi(): Not a MUS file'#13#10);
    exit;
  end;

  count := GetSongLength(MusData);
  score := PByteArray(@MusData[header.scoreStart]);
  event := @MidiEvents[0];

  i := 0;
  while i < NUMTEMPOEVENTS do
  begin
    event.time := 0;
    event.ID := 0;
    event._type := MEVT_TEMPO;
    event.data[0] := $00;
    event.data[1] := miditempo;
    event.data[2] := $02;
    inc(i);
    inc(event);
  end;

  delta := 0;
  spos := 0;
  ZeroMemory(@channelvol, SizeOf(channelvol));

  finished := false;
  while true do
  begin
    event.time := delta;
    delta := 0;
    event.ID := 0;
    etype := _SHR(score[spos], 4) and 7;
    event._type := MEVT_SHORTMSG;
    channel := score[spos] and 15;
    if channel = 9 then
      channel := 15
    else if channel = 15 then
      channel := 9;
    if score[spos] and $80 <> 0 then
      delta := -1;
    inc(spos);
    case etype of
      0:
        begin
          event.data[0] := channel or $80;
          event.data[1] := score[spos];
          inc(spos);
          event.data[2] := channelvol[channel];
        end;
      1:
        begin
          event.data[0] := channel or $90;
          event.data[1] := score[spos] and 127;
          if score[spos] and 128 <> 0 then
          begin
            inc(spos);
            channelvol[channel] := score[spos];
          end;
          inc(spos);
          event.data[2] := channelvol[channel];
        end;
      2:
        begin
          event.data[0] := channel or $e0;
          event.data[1] := _SHL(score[spos], 7) and $7f;
          event.data[2] := _SHR(score[spos], 7);
          inc(spos);
        end;
      3:
        begin
          event.data[0] := channel or $b0;
          event.data[1] := XLateMUSControl(score[spos]);
          inc(spos);
          event.data[2] := 0;
        end;
      4:
        begin
          if score[spos] <> 0 then
          begin
            event.data[0] := channel or $b0;
            event.data[1] := MidiControlers[score[spos]];
            inc(spos);
            event.data[2] := score[spos];
            inc(spos);
          end
          else
          begin
            event.data[0] := channel or $c0;
            inc(spos);
            event.data[1] := score[spos];
            inc(spos);
            event.data[2] := 64;
          end;
        end;
    else
      finished := true;
    end;
    if finished then
      break;
    inc(event);
    dec(count);
    if count < 3 then
      I_Error('I_MusToMidi(): Overflow');
    if delta = -1 then
    begin
      delta := 0;
      while (score[spos] and 128) <> 0 do
      begin
        delta := _SHL(delta, 7);
        delta := delta + score[spos] and 127;
        inc(spos);
      end;
      delta := delta + score[spos];
      inc(spos);
    end;
  end;
end;

//==============================================================================
// I_InitMus
//
// MUSIC API.
//
//==============================================================================
procedure I_InitMus;
var
  rc: MMRESULT;
  numdev: LongWord;
  i: integer;
begin
  if M_CheckParm('-nomusic') <> 0 then
    exit;

  if hMidiStream <> 0 then
    exit;

  ZeroMemory(@midicaps, SizeOf(midicaps));
  MidiDevice := MIDI_MAPPER;

  // First try midi mapper
  rc := midiOutGetDevCaps(MidiDevice, @midicaps, SizeOf(midicaps));
  if rc <> MMSYSERR_NOERROR then
    I_Error('I_InitMusic(): midiOutGetDevCaps failed, return value = %d', [rc]);

  // midiStreamOut not supported (should not happen with MIDI MAPPER...)
  // Try to enumurate all midi devices
  if (midicaps.dwSupport and MIDICAPS_STREAM) = 0 then
  begin
    numdev := midiOutGetNumDevs;
    if numdev = 0 then // fatal
      exit;

    for i := -1 to numdev - 1 do
    begin
      rc := midiOutGetDevCaps(i, @midicaps, SizeOf(midicaps));
      if rc <> MMSYSERR_NOERROR then
        I_Error('I_InitMusic(): midiOutGetDevCaps failed, return value = %d', [rc]);

      if midicaps.dwSupport and MIDICAPS_STREAM <> 0 then
      begin
        MidiDevice := i;
        break;
      end;
    end;
  end;

  if MidiDevice = MIDI_MAPPER then
    printf(' Using midi mapper'#13#10)
  else
    printf(' Using midi device %d'#13#10, [MidiDevice]);

  rc := midiStreamOpen(@hMidiStream, @MidiDevice, 1, 0, 0, CALLBACK_NULL);
  if rc <> MMSYSERR_NOERROR then
  begin
    hMidiStream := 0;
    I_Warning('I_InitMusic(): midiStreamOpen failed, result = %d'#13#10, [rc]);
  end;

  musicstarted := false;
end;

//==============================================================================
//
// I_InitMusic
//
//==============================================================================
procedure I_InitMusic;
begin
  I_InitMus;
  I_InitMidi;
  I_InitMP3;
end;

//==============================================================================
// I_StopMusicMus
//
// I_StopMusic
//
//==============================================================================
procedure I_StopMusicMus(song: Psonginfo_t);
var
  i: integer;
  rc: MMRESULT;
begin
  if not ((song <> nil) and (hMidiStream <> 0)) then
    exit;

  rc := midiOutReset(HMIDIOUT(hMidiStream));
  if rc <> MMSYSERR_NOERROR then
    I_Warning('I_StopMusic(): midiOutReset failed, result = %d'#13#10, [rc]);

  musicstarted := false;

  for i := 0 to NUMMIDIHEADERS - 1 do
  begin
    if song.header[i].lpData <> nil then
    begin
      rc := midiOutUnprepareHeader(HMIDIOUT(hMidiStream), @song.header[i], SizeOf(midiheader_t));
      if rc <> MMSYSERR_NOERROR then
        I_Warning('I_StopMusic(): midiOutUnprepareHeader failed, result = %d'#13#10, [rc]);

      song.header[i].lpData := nil;
      song.header[i].dwFlags := MHDR_DONE or MHDR_ISSTRM;
    end;
  end;
  song.nextevent := 0;

{  rc := midiOutClose(HMIDIOUT(hMidiStream));
  if rc <> MMSYSERR_NOERROR then
    printf('I_StopMusic(): midiOutReset failed, result = %d'#13#10, [rc]);

  hMidiStream := 0;}
end;

//==============================================================================
//
// I_StopMusic
//
//==============================================================================
procedure I_StopMusic(song: Psonginfo_t);
begin
  case m_type of
    m_midi: I_StopMidi;
    m_mus: I_StopMusicMus(song);
    m_mp3: I_StopMP3;
  end;
end;

//==============================================================================
//
// I_StopMus
//
//==============================================================================
procedure I_StopMus;
var
  rc: MMRESULT;
begin
  if hMidiStream <> 0 then
  begin
    rc := midiStreamStop(hMidiStream);
    if rc <> MMSYSERR_NOERROR then
      I_Warning('I_ShutDownMusic(): midiStreamStop failed, result = %d'#13#10, [rc]);

    musicstarted := false;
    rc := midiStreamClose(hMidiStream);
    if rc <> MMSYSERR_NOERROR then
      I_Warning('I_ShutDownMusic(): midiStreamClose failed, result = %d'#13#10, [rc]);

    hMidiStream := 0;
  end;

end;

//==============================================================================
//
// I_ShutDownMusic
//
//==============================================================================
procedure I_ShutDownMusic;
begin
  I_StopMus;
  I_StopMidi;
  I_ShutDownMidi;
  I_ShutDownMP3;
end;

//==============================================================================
//
// I_PlaySong
//
//==============================================================================
procedure I_PlaySong(handle: integer; looping: boolean);
begin
  if (handle <> 0) and (hMidiStream <> 0) then
  begin
    CurrentSong := Psonginfo_t(handle);
  end;
end;

//==============================================================================
// I_PauseSongMus
//
// I_PauseSong
//
//==============================================================================
procedure I_PauseSongMus(handle: integer);
var
  rc: MMRESULT;
begin
  if hMidiStream = 0 then
    exit;

  rc := midiStreamPause(hMidiStream);
  if rc <> MMSYSERR_NOERROR then
    I_Error('I_PauseSong(): midiStreamRestart failed, return value = %d', [rc]);
end;

//==============================================================================
//
// I_PauseSong
//
//==============================================================================
procedure I_PauseSong(handle: integer);
begin
  case m_type of
    m_midi: I_PauseMidi;
    m_mus: I_PauseSongMus(handle);
  end;
end;

//==============================================================================
// I_ResumeSongMus
//
// I_ResumeSong
//
//==============================================================================
procedure I_ResumeSongMus(handle: integer);
var
  rc: MMRESULT;
begin
  if hMidiStream = 0 then
    exit;

  rc := midiStreamRestart(hMidiStream);
  if rc <> MMSYSERR_NOERROR then
    I_Error('I_ResumeSong(): midiStreamRestart failed, return value = %d', [rc]);
end;

//==============================================================================
//
// I_ResumeSong
//
//==============================================================================
procedure I_ResumeSong(handle: integer);
begin
  case m_type of
    m_midi: I_ResumeMidi;
    m_mus: I_ResumeSongMus(handle);
  end;
end;

//==============================================================================
// I_StopSong
//
// Stops a song over 3 seconds.
//
//==============================================================================
procedure I_StopSong(handle: integer);
var
  song: Psonginfo_t;
begin
  if (handle <> 0) and (hMidiStream <> 0) then
  begin

    song := Psonginfo_t(handle);

    I_StopMusic(song);

    if song = CurrentSong then
      CurrentSong := nil;
  end;
end;

//==============================================================================
//
// I_UnRegisterSong
//
//==============================================================================
procedure I_UnRegisterSong(handle: integer);
var
  song: Psonginfo_t;
begin
  if (handle <> 0) and (hMidiStream <> 0) then
  begin

    I_StopSong(handle);

    song := Psonginfo_t(handle);
    Z_Free(song.midievents);
    Z_Free(song);
  end;
end;

//==============================================================================
//
// I_RegisterSong
//
//==============================================================================
function I_RegisterSong(data: pointer; size: integer): integer;
var
  song: Psonginfo_t;
  i: integer;
  f: file;
  b: boolean;
begin
  song := Z_Malloc(SizeOf(songinfo_t), PU_STATIC, nil);
  song.numevents := GetSongLength(PByteArray(data));
  song.nextevent := 0;
  song.midievents := Z_Malloc(song.numevents * SizeOf(MidiEvent_t), PU_STATIC, nil);

  if m_type = m_midi then
    I_StopMidi
  else if m_type = m_mp3 then
    I_StopMP3;

  if Pmp3header_t(data).ID = MP3MAGIC then
  begin
    m_type := m_mp3;
    I_PlayMP3(Pmp3header_t(data).Stream);
  end
  else if I_MusToMidi(PByteArray(data), song.midievents) then
  begin
    I_InitMus;
    m_type := m_mus;

    if hMidiStream = 0 then
    begin
      I_Warning('I_RegisterSong(): Could not initialize midi stream'#13#10);
      m_type := m_none;
      result := 0;
      exit;
    end;

    for i := 0 to NUMMIDIHEADERS - 1 do
    begin
      song.header[i].lpData := nil;
      song.header[i].dwFlags := MHDR_ISSTRM or MHDR_DONE;
    end;
  end
  else
  begin
    if m_type <> m_midi then
    begin
      I_StopMus;
      m_type := m_midi;
    end;

    MidiFileName := I_NewTempFile('doom32.mid');

    b := fopen(f, MidiFileName, fCreate);
    if b then
    begin
      {$I-}
      BlockWrite(f, data^, size);
      close(f);
      {$I+}
      b := IOResult = 0;
    end;

    if not b then
    begin
      I_Warning('I_RegisterSong(): Could not initialize MCI'#13#10);
      m_type := m_none;
      result := 0;
      exit;
    end;

    ClearMidiFilePlayList;
    AddMidiFileToPlayList(MidiFileName);
    I_PlayMidi(0);
  end;
  result := integer(song);
end;

//==============================================================================
// I_QrySongPlaying
//
// Is the song playing?
//
//==============================================================================
function I_QrySongPlaying(handle: integer): boolean;
begin
  result := CurrentSong <> nil;
end;

//==============================================================================
// I_SetMusicVolumeMus
//
// I_SetMusicVolume
//
//==============================================================================
procedure I_SetMusicVolumeMus(volume: integer);
var
  rc: MMRESULT;
begin
  snd_MusicVolume := volume;
// Set volume on output device.
  if (CurrentSong <> nil) and (snd_MusicVolume = 0) and musicstarted then
    I_StopMusic(CurrentSong);

  if midicaps.dwSupport and MIDICAPS_VOLUME <> 0 then
  begin
    rc := midiOutSetVolume(hMidiStream,
      _SHLW($FFFF * snd_MusicVolume div 16, 16) or _SHLW(($FFFF * snd_MusicVolume div 16), 0));
    if rc <> MMSYSERR_NOERROR then
      I_Warning('I_SetMusicVolume(): midiOutSetVolume failed, return value = %d'#13#10, [rc]);
  end
  else
    I_Warning('I_SetMusicVolume(): Midi device dos not support volume control'#13#10);
end;

//==============================================================================
//
// I_SetMusicVolume
//
//==============================================================================
procedure I_SetMusicVolume(volume: integer);
begin
  case m_type of
    m_mus: I_SetMusicVolumeMus(volume);
    m_midi: ; // unsupported
    m_mp3: ; // unsupported
  end;
end;

//==============================================================================
//
// I_ProcessMusic
//
//==============================================================================
procedure I_ProcessMusic;
var
  header: Pmidiheader_t;
  length: integer;
  i: integer;
  rc: MMRESULT;
begin
  if m_type <> m_mus then
    exit;

  if (snd_MusicVolume = 0) or (CurrentSong = nil) then
    exit;

  for i := 0 to NUMMIDIHEADERS - 1 do
  begin
    header := @CurrentSong.header[i];
    if header.dwFlags and MHDR_DONE <> 0 then
    begin
      if header.lpData <> nil then
      begin
        rc := midiOutUnprepareHeader(HMIDIOUT(hMidiStream), PMidiHdr(header), SizeOf(midiheader_t));
        if rc <> MMSYSERR_NOERROR then
          I_Warning('I_ProcessMusic(): midiOutUnprepareHeader failed, result = %d'#13#10, [rc]);
      end;
      header.lpData := @CurrentSong.midievents[CurrentSong.nextevent];
      length := CurrentSong.numevents - CurrentSong.nextevent;
      if length > MAX_MIDI_EVENTS then
      begin
        length := MAX_MIDI_EVENTS;
        CurrentSong.nextevent := CurrentSong.nextevent + MAX_MIDI_EVENTS;
      end
      else
        CurrentSong.nextevent := 0;
      length := length * SizeOf(MidiEvent_t);
      header.dwBufferLength := length;
      header.dwBytesRecorded := length;
      header.dwFlags := MHDR_ISSTRM;
      rc := midiOutPrepareHeader(HMIDIOUT(hMidiStream), PMidiHdr(header), SizeOf(midiheader_t));
      if rc <> MMSYSERR_NOERROR then
        I_Error('I_ProcessMusic(): midiOutPrepareHeader failed, return value = %d', [rc]);
      if not musicstarted then
      begin
        rc := midiStreamRestart(hMidiStream);
        if rc <> MMSYSERR_NOERROR then
          I_Error('I_ProcessMusic(): midiStreamRestart failed, return value = %d', [rc]);
        musicstarted := true;
      end;
      rc := midiStreamOut(hMidiStream, PMidiHdr(header), SizeOf(midiheader_t));
      if rc <> MMSYSERR_NOERROR then
        I_Error('I_ProcessMusic(): midiStreamOut failed, return value = %d', [rc]);
    end;
  end;
end;

end.
