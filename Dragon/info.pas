//------------------------------------------------------------------------------
//
//  DelphiDoom: A modified and improved DOOM engine for Windows
//  based on original Linux Doom as published by "id Software"
//  Copyright (C) 2004-2011 by Jim Valavanis
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
//  E-Mail: jimmyvalavanis@yahoo.gr
//  Site  : http://delphidoom.sitesled.com/
//------------------------------------------------------------------------------

{$I Doom32.inc}

unit info;

interface

uses
  d_delphi,
  d_think,
  info_h;

type
  statesArray_t = packed array[0..$FFFF] of state_t;
  PstatesArray_t = ^statesArray_t;

  sprnamesArray_t = packed array[0..Ord(DO_NUMSPRITES) - 1] of string[4];
  PsprnamesArray_t = ^sprnamesArray_t;

  mobjinfoArray_t = packed array[0..Ord(DO_NUMMOBJTYPES) - 1] of mobjinfo_t;
  PmobjinfoArray_t = ^mobjinfoArray_t;

var
  states: PstatesArray_t = nil;
  numstates: integer = Ord(DO_NUMSTATES);
  sprnames: PIntegerArray = nil;
  numsprites: integer = Ord(DO_NUMSPRITES);
  mobjinfo: PmobjinfoArray_t = nil;
  nummobjtypes: integer = Ord(DO_NUMMOBJTYPES);

procedure Info_Init(const usethinkers: boolean);

function Info_GetNewState: integer;
function Info_GetNewMobjInfo: integer;
function Info_GetSpriteNumForName(const name: string): integer;
function Info_CheckSpriteNumForName(const name: string): integer;
function Info_GetMobjNumForName(const name: string): integer;
procedure Info_SetMobjName(const mobj_no: integer; const name: string);
function Info_GetMobjName(const mobj_no: integer): string;

procedure Info_ShutDown;

function Info_GetInheritance(const imo: Pmobjinfo_t): integer;

implementation

uses
  i_system,
  m_fixed,
  p_enemy,
  p_pspr,
  p_mobj_h,
  p_extra,
  sounds;

var
  DO_states: array[0..Ord(DO_NUMSTATES) - 1] of state_t;

const // Doom Original Sprite Names
  DO_sprnames: array[0..Ord(DO_NUMSPRITES)] of string[4] = (
    'TROO', 'SHTG', 'PUNG', 'PISG', 'PISF', 'SHTF', 'SHT2', 'CHGG', 'CHGF', 'MISG',
    'MISF', 'SAWG', 'PLSG', 'PLSF', 'BFGG', 'BFGF', 'BLUD', 'PUFF', 'BAL1', 'BAL2',
    'PLSS', 'PLSE', 'MISL', 'BFS1', 'BFE1', 'BFE2', 'TFOG', 'IFOG', 'PLAY', 'POSS',
    'SPOS', 'VILE', 'FIRE', 'FATB', 'FBXP', 'SKEL', 'MANF', 'FATT', 'CPOS', 'SARG',
    'HEAD', 'BAL7', 'BOSS', 'BOS2', 'SKUL', 'SPID', 'BSPI', 'APLS', 'APBX', 'CYBR',
    'PAIN', 'SSWV', 'KEEN', 'BBRN', 'BOSF', 'ARM1', 'ARM2', 'BAR1', 'BEXP', 'FCAN',
    'BON1', 'BON2', 'BKEY', 'RKEY', 'YKEY', 'BSKU', 'RSKU', 'YSKU', 'STIM', 'MEDI',
    'SOUL', 'PINV', 'PSTR', 'PINS', 'MEGA', 'SUIT', 'PMAP', 'PVIS', 'CLIP', 'AMMO',
    'ROCK', 'BROK', 'CELL', 'CELP', 'SHEL', 'SBOX', 'BPAK', 'BFUG', 'MGUN', 'CSAW',
    'LAUN', 'PLAS', 'SHOT', 'SGN2', 'COLU', 'SMT2', 'GOR1', 'POL2', 'POL5', 'POL4',
    'POL3', 'POL1', 'POL6', 'GOR2', 'GOR3', 'GOR4', 'GOR5', 'SMIT', 'COL1', 'COL2',
    'COL3', 'COL4', 'CAND', 'CBRA', 'COL6', 'TRE1', 'TRE2', 'ELEC', 'CEYE', 'FSKU',
    'COL5', 'TBLU', 'TGRN', 'TRED', 'SMBT', 'SMGT', 'SMRT', 'HDB1', 'HDB2', 'HDB3',
    'HDB4', 'HDB5', 'HDB6', 'POB1', 'POB2', 'BRS1', 'TLMP', 'TLP2',
    'SPSH', 'LVAS', 'SLDG', 'SLDN', 'DD01', 'DD02', 'TNT1', ''
  );

var // Doom Original mobjinfo
  DO_mobjinfo: array[0..Ord(DO_NUMMOBJTYPES) - 1] of mobjinfo_t;

procedure Info_Init(const usethinkers: boolean);
var
  i: integer;
begin
  if states = nil then
  begin
    states := malloc(Ord(DO_NUMSTATES) * SizeOf(state_t));
    memcpy(states, @DO_states, Ord(DO_NUMSTATES) * SizeOf(state_t));
  end;

  if sprnames = nil then
  begin
    sprnames := malloc(Ord(DO_NUMSPRITES) * 4 + 4);
    for i := 0 to Ord(DO_NUMSPRITES) - 1 do
      sprnames[i] := Ord(DO_sprnames[i][1]) +
                     Ord(DO_sprnames[i][2]) shl 8 +
                     Ord(DO_sprnames[i][3]) shl 16 +
                     Ord(DO_sprnames[i][4]) shl 24;
    sprnames[Ord(DO_NUMSPRITES)] := 0;
  end;

  if mobjinfo = nil then
  begin
    mobjinfo := malloc(Ord(DO_NUMMOBJTYPES) * SizeOf(mobjinfo_t));
    memcpy(mobjinfo, @DO_mobjinfo, Ord(DO_NUMMOBJTYPES) * SizeOf(mobjinfo_t));
  end;

  if not usethinkers then
  begin
    for i := 0 to Ord(DO_NUMSTATES) - 1 do
      states[i].action.acp1 := nil;
    exit;
  end;
end;

function Info_GetNewState: integer;
begin
  realloc(pointer(states), numstates * SizeOf(state_t), (numstates + 1) * SizeOf(state_t));
  ZeroMemory(@states[numstates], SizeOf(state_t));
  result := numstates;
  inc(numstates);
end;

function Info_GetNewMobjInfo: integer;
begin
  realloc(pointer(mobjinfo), nummobjtypes * SizeOf(mobjinfo_t), (nummobjtypes + 1) * SizeOf(mobjinfo_t));
  ZeroMemory(@mobjinfo[nummobjtypes], SizeOf(mobjinfo_t));
  mobjinfo[nummobjtypes].inheritsfrom := -1; // Set to -1
  mobjinfo[nummobjtypes].doomednum := -1; // Set to -1
  result := nummobjtypes;
  inc(nummobjtypes);
end;

function Info_GetSpriteNumForName(const name: string): integer;
var
  spr_name: string;
  i: integer;
  check: integer;
begin
  result := atoi(name, -1);

  if (result >= 0) and (result < numsprites) and (itoa(result) = name) then
    exit;


  if Length(name) <> 4 then
    I_Error('Info_GetSpriteNumForName(): Sprite name "%s" must have 4 characters', [name]);

  spr_name := strupper(name);

  check := Ord(spr_name[1]) +
           Ord(spr_name[2]) shl 8 +
           Ord(spr_name[3]) shl 16 +
           Ord(spr_name[4]) shl 24;

  for i := 0 to numsprites - 1 do
    if sprnames[i] = check then
    begin
      result := i;
      exit;
    end;

  result := numsprites;

  sprnames[numsprites] := check;
  inc(numsprites);
  realloc(pointer(sprnames), numsprites * 4, (numsprites + 1) * 4);
  sprnames[numsprites] := 0;
end;

function Info_CheckSpriteNumForName(const name: string): integer;
var
  spr_name: string;
  i: integer;
  check: integer;
begin
  result := atoi(name, -1);

  if (result >= 0) and (result < numsprites) and (itoa(result) = name) then
    exit;


  if Length(name) <> 4 then
    I_Error('Info_CheckSpriteNumForName(): Sprite name "%s" must have 4 characters', [name]);

  spr_name := strupper(name);

  check := Ord(spr_name[1]) +
           Ord(spr_name[2]) shl 8 +
           Ord(spr_name[3]) shl 16 +
           Ord(spr_name[4]) shl 24;

  for i := 0 to numsprites - 1 do
    if sprnames[i] = check then
    begin
      result := i;
      exit;
    end;

  result := -1;
end;

function Info_GetMobjNumForName(const name: string): integer;
var
  mobj_name: string;
  check: string;
  i: integer;
begin
  if name = '' then
  begin
    result := -1;
    exit;
  end;

  result := atoi(name, -1);

  if (result >= 0) and (result < nummobjtypes) and (itoa(result) = name) then
    exit;

  mobj_name := strupper(strtrim(name));
  if Length(mobj_name) > MOBJINFONAMESIZE then
    SetLength(mobj_name, MOBJINFONAMESIZE);
  for i := 0 to nummobjtypes - 1 do
  begin
    check := Info_GetMobjName(i);
    check := strupper(strtrim(check));
    if check = mobj_name then
    begin
      result := i;
      exit;
    end;
  end;

  mobj_name := strremovespaces(strupper(strtrim(name)));
  if Length(mobj_name) > MOBJINFONAMESIZE then
    SetLength(mobj_name, MOBJINFONAMESIZE);
  for i := 0 to nummobjtypes - 1 do
  begin
    check := Info_GetMobjName(i);
    check := strremovespaces(strupper(strtrim(check)));
    if check = mobj_name then
    begin
      result := i;
      exit;
    end;
  end;

  result := -1;
end;

procedure Info_SetMobjName(const mobj_no: integer; const name: string);
var
  i: integer;
  len: integer;
begin
  len := Length(name);
  if len > MOBJINFONAMESIZE then
    len := MOBJINFONAMESIZE;
  for i := 0 to len - 1 do
    mobjinfo[mobj_no].name[i] := name[i + 1];
  for i := len to MOBJINFONAMESIZE - 1 do
    mobjinfo[mobj_no].name[i] := #0;
end;

function Info_GetMobjName(const mobj_no: integer): string;
var
  i: integer;
  p: PChar;
begin
  result := '';
  p := @mobjinfo[mobj_no].name[0];
  for i := 0 to MOBJINFONAMESIZE - 1 do
    if p^ = #0 then
      exit
    else
    begin
      result := result + p^;
      inc(p);
    end;
end;

procedure Info_ShutDown;
var
  i: integer;
begin
  for i := 0 to numstates - 1 do
  begin
    if states[i].params <> nil then
      FreeAndNil(states[i].params);
{$IFDEF OPENGL}
    if states[i].dlights <> nil then
      FreeAndNil(states[i].dlights);
    if states[i].models <> nil then
      FreeAndNil(states[i].models);
{$ENDIF}
  end;

  memfree(pointer(states), numstates * SizeOf(state_t));
  memfree(pointer(mobjinfo), nummobjtypes * SizeOf(mobjinfo_t));
  memfree(pointer(sprnames), numsprites * 4);
end;

function Info_GetInheritance(const imo: Pmobjinfo_t): integer;
var
  mo: Pmobjinfo_t;
  loops: integer;
begin
  mo := imo;
  result := mo.inheritsfrom;

  if result <> -1 then
  begin
    loops := 0;
    while true do
    begin
      mo := @mobjinfo[mo.inheritsfrom];
      if mo.inheritsfrom = -1 then
        exit
      else
        result := mo.inheritsfrom;
    // JVAL: Prevent wrong inheritances of decorate lumps
      inc(loops);
      if loops > nummobjtypes then
      begin
        result := -1;
        break;
      end;
    end;
  end;

  if result = -1 then
    result :=  (integer(imo) - integer(@mobjinfo[0])) div SizeOf(mobjinfo_t);

end;

end.

