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
// DESCRIPTION:
//  Refresh module, data I/O, caching, retrieval of graphics
//  by name.
//  Preparation of data for rendering,
//  generation of lookups, caching, retrieval by name.
//
//------------------------------------------------------------------------------
//  Site  : https://sourceforge.net/projects/dragon-game/
//------------------------------------------------------------------------------

{$I dragon.inc}

unit r_data;

interface

uses
  d_delphi,
  m_fixed,
  r_defs;

//==============================================================================
// R_GetColumn
//
//-----------------------------------------------------------------------------
// Retrieve column data for span blitting.
//
//==============================================================================
function R_GetColumn(const tex: integer; col: integer): PByteArray;

//==============================================================================
//
// R_GetLumpForFlat
//
//==============================================================================
function R_GetLumpForFlat(const flat: integer): integer;

//==============================================================================
// R_InitData
//
// I/O, setting up the stuff.
//
//==============================================================================
procedure R_InitData;

//==============================================================================
//
// R_FreeMemory
//
//==============================================================================
procedure R_FreeMemory;

//==============================================================================
//
// R_PrecacheLevel
//
//==============================================================================
procedure R_PrecacheLevel;

//==============================================================================
// R_FlatNumForName
//
// Retrieval.
// Floor/ceiling opaque texture tiles,
// lookup by name. For animation?
//
//==============================================================================
function R_FlatNumForName(const name: string): integer;

//==============================================================================
//
// R_FlatNumForLump
//
//==============================================================================
function R_FlatNumForLump(const lump: integer): integer;

//==============================================================================
//
// R_CacheFlat
//
//==============================================================================
function R_CacheFlat(const lump: integer; const tag: integer): pointer;

//==============================================================================
// R_CheckTextureNumForName
//
// Called by P_Ticker for switches and animations,
// returns the texture number for the texture name.
//
//==============================================================================
function R_CheckTextureNumForName(const name: string): integer;

//==============================================================================
//
// R_SafeTextureNumForName
//
//==============================================================================
function R_SafeTextureNumForName(const name: string): integer;

//==============================================================================
//
// R_TextureNumForName
//
//==============================================================================
function R_TextureNumForName(const name: string): integer;

var
// for global animation
  texturetranslation: PIntegerArray;

// needed for texture pegging
  textureheight: Pfixed_tArray;
  texturecompositesize: PIntegerArray;

  firstspritelump: integer;
  lastspritelump: integer;

// needed for pre rendering
  spritewidth: Pfixed_tArray;
  spriteoffset: Pfixed_tArray;
  spritetopoffset: Pfixed_tArray;
  spritepresent: PBooleanArray;

  colormaps: PByteArray;
  colormaps32: PLongWordArray;

var
  firstflat: integer;
  lastflat: integer;
  numflats: integer;
  maxvisplane: integer;

//==============================================================================
//
// R_SetupLevel
//
//==============================================================================
procedure R_SetupLevel;

var
  numtextures: integer;
  textures: Ptexture_tPArray;
  flats: PflatPArray;
  aprox_black: byte = 247;

implementation

uses
  doomdef,
  doomstat,
{$IFDEF FPC}
  d_fpc,
{$ENDIF}
  d_think,
  g_game,
  i_system,
  p_local,
  p_setup,
  p_tick,
  p_mobj_h,
  p_mobj,
  p_terrain,
  r_sky,
  r_things,
  r_bsp,
  r_hires,
  r_main,
  v_data,
  v_video,
  w_wad,
  z_zone,
  sc_engine;

//==============================================================================
//
// Graphics.
// DOOM graphics for walls and sprites
// is stored in vertical runs of opaque pixels (posts).
// A column is composed of zero or more posts,
// a patch or sprite is composed of zero or more columns.
//
// R_DrawColumnInCache
// Clip and draw a column
//  from a patch into a cached post.
//
//==============================================================================
procedure R_DrawColumnInCache(patch: Pcolumn_t; cache: PByteArray;
  originy: integer; cacheheight: integer);
var
  count: integer;
  position: integer;
begin
  while patch.topdelta <> $ff do
  begin
    count := patch.length;
    position := originy + patch.topdelta;

    if position < 0 then
    begin
      count := count + position;
      position := 0;
    end;

    if position + count > cacheheight then
      count := cacheheight - position;

    if count > 0 then
      memcpy(@cache[position], PByteArray(integer(patch) + 3), count);

    patch := Pcolumn_t(integer(patch) + patch.length + 4);
  end;
end;

//==============================================================================
//
// R_DrawColumnInCacheMultipatch
//
//==============================================================================
procedure R_DrawColumnInCacheMultipatch(patch: Pcolumn_t; cache: PByteArray;
  originy: integer; cacheheight: integer; marks: PByteArray);
var
  count: integer;
  position: integer;
begin
  while patch.topdelta <> $ff do
  begin
    count := patch.length;
    position := originy + patch.topdelta;

    if position < 0 then
    begin
      count := count + position;
      position := 0;
    end;

    if position + count > cacheheight then
      count := cacheheight - position;

    if count > 0 then
    begin
      memcpy(@cache[position], PByteArray(integer(patch) + 3), count);
      memset(@marks[position], $ff, count);
    end;

    patch := Pcolumn_t(integer(patch) + patch.length + 4);
  end;
end;

//==============================================================================
//
// R_GenerateComposite
// Using the texture definition,
//  the composite texture is created from the patches,
//  and each column is cached.
//
//==============================================================================
procedure R_GenerateComposite(const texnum: integer);
var
  block: PByteArray;
  texture: Ptexture_t;
  patch: Ptexpatch_t;
  realpatch: Ppatch_t;
  x1: integer;
  x2: integer;
  i, j: integer;
  cofs: PIntegerArray;
  col, patchcol: Pcolumn_t;
  collump: PSmallIntArray;
  colofs: PIntegerArray; //PWordArray; // 64k
  twidth: integer;
  theight: integer;
  theight4: integer;
  source, mark1, marks: PByteArray;
  marksize: integer;
begin
  texture := textures[texnum];
  twidth := texture.width;
  theight := texture.height;
  marksize := twidth * theight;

  block := Z_Malloc(texturecompositesize[texnum], PU_STATIC, @texturecomposite[texnum]);

  collump := texturecolumnlump[texnum];
  colofs := texturecolumnofs[texnum];

  // Composite the columns together.
  patch := @(texture.patches[0]);

  if texture.patchcount = 1 then
  begin

    realpatch := W_CacheLumpNum(patch.patch, PU_STATIC);
    x1 := patch.originx;
    x2 := x1 + realpatch.width;

    cofs := PIntegerArray(integer(@realpatch.columnofs) - x1 * SizeOf(integer));

    if x1 < 0 then
      x1 := 0;

    if x2 > twidth then
      x2 := twidth;

    while x1 < x2 do
    begin
      // Column does not have multiple patches?
      if collump[x1] < 0 then
      begin
        patchcol := Pcolumn_t(integer(realpatch) + cofs[x1]);
        R_DrawColumnInCache(
          patchcol, @block[colofs[x1]], patch.originy, theight);
      end;
      inc(x1);
    end;
    Z_ChangeTag(realpatch, PU_CACHE);

  end
  else
  begin
    marks := mallocz(marksize);

    for i := 0 to texture.patchcount - 1 do
    begin
      realpatch := W_CacheLumpNum(patch.patch, PU_STATIC);
      x1 := patch.originx;
      x2 := x1 + realpatch.width;

      cofs := PIntegerArray(integer(@realpatch.columnofs) - x1 * SizeOf(integer));

      if x1 < 0 then
        x1 := 0;

      if x2 > twidth then
        x2 := twidth;

      while x1 < x2 do
      begin
        // Column does not have multiple patches?
        if collump[x1] < 0 then
        begin
          patchcol := Pcolumn_t(integer(realpatch) + cofs[x1]);
          R_DrawColumnInCacheMultipatch(
            patchcol, @block[colofs[x1]], patch.originy, theight, @marks[x1 * theight]);
        end;
        inc(x1);
      end;
      Z_ChangeTag(realpatch, PU_CACHE);
      inc(patch);
    end;

    source := malloc(theight);  // temporary column
    for i := 0 to twidth - 1 do
      if collump[i] < 0  then // process only multipatched columns
      begin
        col := Pcolumn_t(@block[colofs[i] - 3]);  // cached column
        mark1 := @marks[i * theight];
        j := 0;

        // save column in temporary so we can shuffle it around
        memcpy(source, PByteArray(integer(col) + 3), theight);

        while true do  // reconstruct the column by scanning transparency marks
        begin
          // skip transparent cells
          // JVAL: Fast skip, check 4 bytes at first
          theight4 := theight - 4;
          while (j < theight4) and (PInteger(@mark1[j])^ = 0) do
            j := j + 4;
          // JVAL: Finally check each of the remaining bytes
          while (j < theight) and (mark1[j] = 0) do
            inc(j);
          if j >= theight then    // if at end of column
          begin
            col.topdelta := $FF;  // end-of-column marker
            break;
          end;
          col.topdelta := j;      // starting offset of post
          while (j < theight) and (mark1[j] <> 0) do
            inc(j);
          col.length := j - col.topdelta;
          // copy opaque cells from the temporary back into the column
          memcpy(PByteArray(integer(col) + 3), @source[col.topdelta], col.length);
          col := Pcolumn_t(integer(col) + col.length + 4); // next post
        end;
      end;

    memfree(pointer(source), theight);         // free temporary column
    memfree(pointer(marks), marksize);          // free transparency marks
  end;

  // Now that the texture has been built in column cache,
  //  it is purgable from zone memory.
  Z_ChangeTag(block, PU_CACHE);
end;

//==============================================================================
//
// R_GenerateLookup
//
//==============================================================================
procedure R_GenerateLookup(const texnum: integer);
var
  texture: Ptexture_t;
  patchcount: PIntegerArray; // patchcount[texture->width]
  postcount: PIntegerArray; // postcount[texture->width]
  patch: Ptexpatch_t;
  realpatch: Ppatch_t;
  x: integer;
  x1: integer;
  x2: integer;
  i: integer;
  collump: PSmallIntArray;
  colofs: PIntegerArray;  //PWordArray; // 64k
  col: Pcolumn_t;
  cofs: PIntegerArray;
  csize: integer;
  pat: integer;
begin
  texture := textures[texnum];

  // Composited texture not created yet.
  texturecomposite[texnum] := nil;

  texturecompositesize[texnum] := 0;
  collump := texturecolumnlump[texnum];
  colofs := texturecolumnofs[texnum];

  // Now count the number of columns
  //  that are covered by more than one patch.
  // Fill in the lump / offset, so columns
  //  with only a single patch are all done.
  patchcount := mallocz(texture.width * SizeOf(integer));
  postcount := mallocz(texture.width * SizeOf(integer));
  patch := @texture.patches[0];

  for i := 0 to texture.patchcount - 1 do
  begin
    pat := patch.patch;
    realpatch := W_CacheLumpNum(pat, PU_STATIC);
    x1 := patch.originx;
    x2 := x1 + realpatch.width;
    cofs := PIntegerArray(@realpatch.columnofs[-x1]);

    if x1 < 0 then
      x := 0
    else
      x := x1;

    if x2 > texture.width then
      x2 := texture.width;

    while x < x2 do
    begin
      col := Pcolumn_t(integer(realpatch) + cofs[x]);
      while col.topdelta <> $ff do
      begin
        postcount[x] := postcount[x] + 1;
        col := Pcolumn_t(integer(col) + col.length + 4);
      end;
      patchcount[x] := patchcount[x] + 1;
      collump[x] := pat;
      colofs[x] := cofs[x] + 3;
      inc(x);
    end;
    Z_ChangeTag(realpatch, PU_CACHE);
    inc(patch);
  end;

  if texture.patchcount > 1 then
  begin

    csize := 0;
    for x := 0 to texture.width - 1 do
    begin
      if patchcount[x] <= 0 then
        I_DevWarning('R_GenerateLookup(): column without a patch (%s, column=%d)'#13#10, [char8tostring(texture.name), x])
      else
      begin
        // Use the cached block.
        collump[x] := -1;
        colofs[x] := csize + 3;
        csize := csize + 4 * postcount[x] + 1;
      end;
      csize := csize + texture.height;
    end;
    texturecompositesize[texnum] := csize;

  end
  else
  begin

    for x := 0 to texture.width - 1 do
    begin
      if patchcount[x] = 0 then
        I_DevWarning('R_GenerateLookup(): column without a patch (%s)'#13#10, [char8tostring(texture.name)])
      else if patchcount[x] > 1 then
      begin
        // Use the cached block.
        collump[x] := -1;
        colofs[x] := texturecompositesize[texnum];

        if texturecompositesize[texnum] > $10000 - texture.height then
          I_DevWarning('R_GenerateLookup(): texture %d is > 64k'#13#10, [texnum]);

        texturecompositesize[texnum] := texturecompositesize[texnum] + texture.height;
      end;
    end;

  end;

  if texturecompositesize[texnum] > $10000 - texture.height then
    I_DevWarning('R_GenerateLookup(): texture %d is > 64k'#13#10, [texnum]);

  memfree(pointer(patchcount), texture.width * SizeOf(integer));
  memfree(pointer(postcount), texture.width * SizeOf(integer));
end;

//==============================================================================
//
// R_GetColumn
//
//==============================================================================
function R_GetColumn(const tex: integer; col: integer): PByteArray;
var
  lump: integer;
  ofs: integer;
begin
  col := col and texturewidthmask[tex];
  lump := texturecolumnlump[tex][col];
  ofs := texturecolumnofs[tex][col];

  if lump > 0 then
  begin
    result := PByteArray(integer(W_CacheLumpNum(lump, PU_LEVEL)) + ofs);
    exit;
  end;

  if texturecomposite[tex] = nil then
    R_GenerateComposite(tex);

  result := PByteArray(integer(texturecomposite[tex]) + ofs);
end;

//==============================================================================
//
// R_GetLumpForFlat
//
//==============================================================================
function R_GetLumpForFlat(const flat: integer): integer;
begin
  result := flats[flats[flat].translation].lump;
end;

//==============================================================================
//
// R_InitTextures
// Initializes the texture list
//  with the textures from the world map.
//
//==============================================================================
procedure R_InitTextures;
var
  mtexture: Pmaptexture_t;
  texture: Ptexture_t;
  mpatch: Pmappatch_t;
  patch: Ptexpatch_t;
  i: integer;
  j: integer;
  maptex: PIntegerArray;
  maptex2: PIntegerArray;
  maptex1: PIntegerArray;
  name: char8_t;
  names: PByteArray;
  name_p: PByteArray;
  patchlookup: PIntegerArray;
  nummappatches: integer;
  offset: integer;
  maxoff: integer;
  maxoff2: integer;
  numtextures1: integer;
  numtextures2: integer;
  directory: PIntegerArray;
 { list: TDStringList;
  sc: TScriptEngine;   }
begin
  // Load the patch names from pnames.lmp.
  ZeroMemory(@name, SizeOf(char8_t));
  names := W_CacheLumpName('PNAMES', PU_STATIC);
  nummappatches := PInteger(names)^;
  name_p := PByteArray(integer(names) + 4);

  patchlookup := malloc(nummappatches * SizeOf(integer));

  for i := 0 to nummappatches - 1 do
  begin
    j := 0;
    while j < 8 do
    begin
      name[j] := toupper(Chr(name_p[i * 8 + j]));
      if name[j] = #0 then
      begin
        inc(j);
        break;
      end;
      inc(j);
    end;
    while j < 8 do
    begin
      name[j] := #0;
      inc(j);
    end;
    patchlookup[i] := W_CheckNumForName(char8tostring(name));
  end;
  Z_Free(names);

  // Load the map texture definitions from textures.lmp.
  // The data is contained in one or two lumps,
  //  TEXTURE1 for shareware, plus TEXTURE2 for commercial.
  maptex1 := W_CacheLumpName('TEXTURE1', PU_STATIC);
  maptex := maptex1;
  numtextures1 := maptex[0];
  maxoff := W_LumpLength(W_GetNumForName('TEXTURE1'));
  directory := PintegerArray(integer(maptex) + SizeOf(integer));

  if W_CheckNumForName('TEXTURE2') <> -1 then
  begin
    maptex2 := W_CacheLumpName('TEXTURE2', PU_STATIC);
    numtextures2 := maptex2[0];
    maxoff2 := W_LumpLength(W_GetNumForName('TEXTURE2'));
  end
  else
  begin
    maptex2 := nil;
    numtextures2 := 0;
    maxoff2 := 0;
  end;
  numtextures := numtextures1 + numtextures2;

  textures := mallocz(numtextures * SizeOf(Ptexture_t));
  texturecolumnlump := mallocz(numtextures * SizeOf(PSmallIntArray));
  texturecolumnofs := mallocz(numtextures * SizeOf(PIntegerArray));
  texturecomposite := mallocz(numtextures * SizeOf(PByteArray));
  texturecompositesize := mallocz(numtextures * SizeOf(integer));
  texturewidthmask := mallocz(numtextures * SizeOf(integer));
  textureheight := mallocz(numtextures * SizeOf(fixed_t));

  for i := 0 to numtextures - 1 do
  begin
    if i = numtextures1 then
    begin
      // Start looking in second texture file.
      maptex := maptex2;
      maxoff := maxoff2;
      directory := PIntegerArray(integer(maptex) + SizeOf(integer));
    end;

    offset := directory[0];

    if offset > maxoff then
      I_Error('R_InitTextures(): bad texture directory');

    mtexture := Pmaptexture_t(integer(maptex) + offset);

    textures[i] := malloc(SizeOf(texture_t) + SizeOf(texpatch_t) * (mtexture.patchcount - 1));
    texture := textures[i];

    texture.width := mtexture.width;
    texture.height := mtexture.height;
    texture.patchcount := mtexture.patchcount;

    j := 0;
    while j < 8 do
    begin
      if mtexture.name[j] in [#0, ' '] then
        break;
      texture.name[j] := toupper(mtexture.name[j]);
      inc(j);
    end;
    while j < 8 do
    begin
      texture.name[j] := #0;
      inc(j);
    end;

    mpatch := @mtexture.patches[0];
    patch := @texture.patches[0];

    for j := 0 to texture.patchcount - 1 do
    begin
      patch.originx := mpatch.originx;
      patch.originy := mpatch.originy;
      patch.patch := patchlookup[mpatch.patch];
      if patch.patch = -1 then
        I_Error('R_InitTextures(): Missing patch in texture %s', [char8tostring(texture.name)]);
      inc(mpatch);
      inc(patch);
    end;
    texturecolumnlump[i] := malloc(texture.width * SizeOf(texturecolumnlump[0][0]));
    texturecolumnofs[i] := malloc(texture.width * SizeOf(texturecolumnofs[0][0]));

    j := 1;
    while j * 2 <= texture.width do
      j := j * 2;

    texturewidthmask[i] := j - 1;
    textureheight[i] := texture.height * FRACUNIT;

    incp(pointer(directory), SizeOf(integer));
  end;

  memfree(pointer(patchlookup), nummappatches * SizeOf(integer));

  Z_Free(maptex1);
  if maptex2 <> nil then
    Z_Free(maptex2);

  // Precalculate whatever possible.
  for i := 0 to numtextures - 1 do
    R_GenerateLookup(i);

  // Create translation table for global animation.
  texturetranslation := malloc((numtextures + 1) * SizeOf(integer));

  for i := 0 to numtextures - 1 do
    texturetranslation[i] := i;

end;

//==============================================================================
//
// R_InitFlats
//
//==============================================================================
procedure R_InitFlats;
var
  i: integer;
  lump: integer;
  flat: Pflat_t;
begin
  firstflat := W_GetFirstNumForName('F_START') + 1;
  lastflat := W_GetNumForName('F_END') - 1;
  lump := W_CheckNumForName('FF_END');
  if lump > lastflat then
    lastflat := lump;
  numflats := lastflat - firstflat + 1;

  // Create translation table for global animation.
  flats := malloc(numflats * SizeOf(pointer));

  for i := 0 to numflats - 1 do
  begin
    flat := malloc(SizeOf(flat_t));
    flat.name := W_GetNameForNum(firstflat + i);
    flat.translation := i;
    flat.lump := W_GetNumForName(flat.name);
    // JVAL: 9 December 2007, Added terrain types
    flat.terraintype := P_TerrainTypeForName(flat.name);
    flats[i] := flat;
  end;
end;

//==============================================================================
//
// R_InitSpriteLumps
// Finds the width and hoffset of all sprites in the wad,
//  so the sprite does not need to be cached completely
//  just for having the header info ready during rendering.
//
//==============================================================================
procedure R_InitSpriteLumps;
var
  i: integer;
  in_loop: boolean;
  patch: Ppatch_t;
  tmp: integer;
  lumpname: string;
begin

  firstspritelump := 0;
  for i := 0 to W_NumLumps - 1 do
  begin
    lumpname := char8tostring(W_GetNameForNum(i));
    if (lumpname = 'S_START') or (lumpname = 'SS_START') then
    begin
      firstspritelump := i + 1;
      break;
    end;
  end;

  lastspritelump := W_GetNumForName('S_END') - 1;
  tmp := W_CheckNumForName('SS_END');
  if tmp > 0 then
  begin
    dec(tmp);
    if lastspritelump < tmp then
      lastspritelump := tmp;
  end;

  if lastspritelump < firstspritelump then
  begin
    I_Warning('R_InitSpriteLumps(): WAD files have missplaced sprite markers (start=%d, end=%d)'#13#10, [firstspritelump, lastspritelump]);
    lastspritelump := W_NumLumps;
  end;
  numspritelumps := lastspritelump - firstspritelump + 1;
  spritewidth := malloc(numspritelumps * SizeOf(fixed_t));
  spriteoffset := malloc(numspritelumps * SizeOf(fixed_t));
  spritetopoffset := malloc(numspritelumps * SizeOf(fixed_t));
  spritepresent := malloc(numspritelumps * SizeOf(boolean));

  in_loop := true;

  for i := 0 to numspritelumps - 1 do
  begin
    spritewidth[i] := 0;
    spriteoffset[i] := 0;
    spritetopoffset[i] := 0;
    spritepresent[i] := false;
    lumpname := char8tostring(W_GetNameForNum(firstspritelump + i));
    if (lumpname = 'SS_START') or (lumpname = 'S_START') then
      in_loop := true
    else if (lumpname = 'SS_END') or (lumpname = 'S_END') then
      in_loop := false
    else if in_loop then
    begin
      patch := W_CacheLumpNum(firstspritelump + i, PU_STATIC);
      spritewidth[i] := patch.width * FRACUNIT;
      spriteoffset[i] := patch.leftoffset * FRACUNIT;
      spritetopoffset[i] := patch.topoffset * FRACUNIT;
      spritepresent[i] := true;
      Z_ChangeTag(patch, PU_CACHE);
    end;
  end;
end;

//==============================================================================
// R_SafeFreeMemory
//
// R_FreeMemory
// JVAL: Free memory allocated without using zone
//
//==============================================================================
procedure R_SafeFreeMemory;
var
  i: integer;
begin
// textures
  for i := 0 to numtextures - 1 do
    if textures[i] <> nil then
    begin
      memfree(pointer(texturecolumnlump[i]), textures[i].width * SizeOf(texturecolumnlump[0][0]));
      memfree(pointer(texturecolumnofs[i]), textures[i].width * SizeOf(texturecolumnofs[0][0]));
      memfree(pointer(textures[i]), SizeOf(texture_t) + SizeOf(texpatch_t) * (textures[i].patchcount - 1));
    end;

  memfree(pointer(textures), numtextures * SizeOf(Ptexture_t));
  memfree(pointer(texturecolumnlump), numtextures * SizeOf(PSmallIntArray));
  memfree(pointer(texturecolumnofs), numtextures * SizeOf(PIntegerArray));
  memfree(pointer(texturecomposite), numtextures * SizeOf(PByteArray));
  memfree(pointer(texturecompositesize), numtextures * SizeOf(integer));
  memfree(pointer(texturewidthmask), numtextures * SizeOf(integer));
  memfree(pointer(textureheight), numtextures * SizeOf(fixed_t));
  memfree(pointer(texturetranslation), (numtextures + 1) * SizeOf(integer));

// flats
  if flats <> nil then
    for i := 0 to numflats - 1 do
      memfree(pointer(flats[i]), SizeOf(flat_t));
  memfree(pointer(flats), numflats * SizeOf(pointer));

// sprites
  memfree(pointer(spritewidth), numspritelumps * SizeOf(fixed_t));
  memfree(pointer(spriteoffset), numspritelumps * SizeOf(fixed_t));
  memfree(pointer(spritetopoffset), numspritelumps * SizeOf(fixed_t));
  memfree(pointer(spritepresent), numspritelumps * SizeOf(boolean));

end;

//==============================================================================
//
// R_FreeMemory
//
//==============================================================================
procedure R_FreeMemory;
var
  i: integer;
begin
  if in_i_error then
  begin
    R_SafeFreeMemory;
    exit;
  end;
// textures
  for i := 0 to numtextures - 1 do
  begin
    memfree(pointer(texturecolumnlump[i]), textures[i].width * SizeOf(texturecolumnlump[0][0]));
    memfree(pointer(texturecolumnofs[i]), textures[i].width * SizeOf(texturecolumnofs[0][0]));
    memfree(pointer(textures[i]), SizeOf(texture_t) + SizeOf(texpatch_t) * (textures[i].patchcount - 1));
  end;

  memfree(pointer(textures), numtextures * SizeOf(Ptexture_t));
  memfree(pointer(texturecolumnlump), numtextures * SizeOf(PSmallIntArray));
  memfree(pointer(texturecolumnofs), numtextures * SizeOf(PIntegerArray));
  memfree(pointer(texturecomposite), numtextures * SizeOf(PByteArray));
  memfree(pointer(texturecompositesize), numtextures * SizeOf(integer));
  memfree(pointer(texturewidthmask), numtextures * SizeOf(integer));
  memfree(pointer(textureheight), numtextures * SizeOf(fixed_t));
  memfree(pointer(texturetranslation), (numtextures + 1) * SizeOf(integer));

// flats
  for i := 0 to numflats - 1 do
    memfree(pointer(flats[i]), SizeOf(flat_t));
  memfree(pointer(flats), numflats * SizeOf(pointer));

// sprites
  memfree(pointer(spritewidth), numspritelumps * SizeOf(fixed_t));
  memfree(pointer(spriteoffset), numspritelumps * SizeOf(fixed_t));
  memfree(pointer(spritetopoffset), numspritelumps * SizeOf(fixed_t));
  memfree(pointer(spritepresent), numspritelumps * SizeOf(boolean));

end;

//==============================================================================
//
// R_InitColormaps
//
//==============================================================================
procedure R_InitColormaps;
var
  lump: integer;
  length: integer;
  i: integer;
  palette: PByteArray;
  cpal: array[0..255] of LongWord;
  src: PByteArray;
  dest: PLongWord;
begin
  palette := V_ReadPalette(PU_STATIC);

  dest := @cpal[0];
  src := palette;
  while integer(src) < integer(@palette[256 * 3]) do
  begin
    dest^ := (LongWord(src[0]) shl 16) or
             (LongWord(src[1]) shl 8) or
             (LongWord(src[2]));
    inc(dest);
    src := PByteArray(integer(src) + 3);
  end;
  Z_ChangeTag(palette, PU_CACHE);
  aprox_black := V_FindAproxColorIndex(@cpal, $0, 1, 255);

  // Load in the light tables,
  //  256 byte align tables.
  lump := W_GetNumForName('COLORMAP');
  length := W_LumpLength(lump);
  colormaps := Z_Malloc(length, PU_STATIC, nil);
  colormaps32 := Z_Malloc(length * SizeOf(LongWord), PU_STATIC, nil);
  W_ReadLump(lump, colormaps);
  for i := 0 to length - 1 do
    if colormaps[i] = 0 then
      colormaps[i] := aprox_black;
  v_translation := colormaps;
end;

//==============================================================================
//
// R_InitData
// Locates all the lumps
//  that will be used by all views
// Must be called after W_Init.
//
//==============================================================================
procedure R_InitData;
begin
  R_InitHiRes;
  R_InitTextures;
  R_InitFlats;
  R_InitSpriteLumps;
  R_InitColormaps;
end;

//==============================================================================
//
// R_FlatNumForName
// Retrieval, get a flat number for a flat name.
//
//==============================================================================
function R_FlatNumForName(const name: string): integer;
var
  i: integer;
begin
  i := W_CheckNumForName2(name, firstflat, lastflat);
  if i > -1 then
    result := i - firstflat
  else
  begin
    i := W_CheckNumForName(name);
    if i = -1 then
      I_Error('R_FlatNumForName(): %s not found', [name]);

    // JVAL: Found a flat outside F_START, F_END
    result := numflats;
    inc(numflats);
    flats := Z_ReAlloc(flats, numflats * SizeOf(pointer), PU_STATIC, nil);

    flats[result] := Z_Malloc(SizeOf(flat_t), PU_STATIC, nil);
    flats[result].name := W_GetNameForNum(i);
    flats[result].translation := result;
    flats[result].lump := i;
    // JVAL: 9 December 2007, Added terrain types
    flats[result].terraintype := P_TerrainTypeForName(flats[result].name);
  end
end;

//==============================================================================
//
// R_FlatNumForLump
//
//==============================================================================
function R_FlatNumForLump(const lump: integer): integer;
begin
  if (lump >= firstflat) and (lump <= lastflat) then
    result := lump - firstflat
  else
  begin
    if (lump < 0) or (lump >= W_NumLumps) then
      I_Error('R_FlatNumForLump(): Invalid lump = %d', [lump]);

    // JVAL: Found a flat outside F_START, F_END
    result := numflats;
    inc(numflats);
    flats := Z_ReAlloc(flats, numflats * SizeOf(pointer), PU_STATIC, nil);

    flats[result] := Z_Malloc(SizeOf(flat_t), PU_STATIC, nil);
    flats[result].name := W_GetNameForNum(lump);
    flats[result].translation := result;
    flats[result].lump := lump;
    // JVAL: 9 December 2007, Added terrain types
    flats[result].terraintype := P_TerrainTypeForName(flats[result].name);
  end
end;

//==============================================================================
//
// R_CheckTextureNumForName
// Check whether texture is available.
// Filter out NoTexture indicator.
//
//==============================================================================
function R_CheckTextureNumForName(const name: string): integer;
var
  i: integer;
  check: name8_t;
begin
  // "NoTexture" marker.
  if name[1] = '-' then
  begin
    result := 0;
    exit;
  end;

  check.s := stringtochar8(strupper(name));
  for i := 0 to numtextures - 1 do
    if name8_t(textures[i].name).x[0] = check.x[0] then
      if name8_t(textures[i].name).x[1] = check.x[1] then
      begin
        result := i;
        exit;
      end;

  result := -1;
end;

//==============================================================================
//
// R_SafeTextureNumForName
//
//==============================================================================
function R_SafeTextureNumForName(const name: string): integer;
var
  i: integer;
  check: name8_t;
begin
  if name = '' then
  begin
    result := 0;
    exit;
  end;

  // "NoTexture" marker.
  if name[1] = '-' then
  begin
    result := 0;
    exit;
  end;

  check.s := stringtochar8(strupper(name));
  for i := 0 to numtextures - 1 do
    if name8_t(textures[i].name).x[0] = check.x[0] then
      if name8_t(textures[i].name).x[1] = check.x[1] then
      begin
        result := i;
        exit;
      end;

  result := 0;
end;

//==============================================================================
//
// R_TextureNumForName
// Calls R_CheckTextureNumForName,
//  aborts with error message.
//
//==============================================================================
function R_TextureNumForName(const name: string): integer;
begin
  result := R_CheckTextureNumForName(name);

  if result = -1 then
    I_Error('R_TextureNumForName(): %s not found', [name]);
end;

//==============================================================================
//
// R_CacheFlat
//
//==============================================================================
function R_CacheFlat(const lump: integer; const tag: integer): pointer;
begin
  result := W_CacheLumpNum(lump, tag);
end;

//==============================================================================
//
// R_PrecacheLevel
// Preloads all relevant graphics for the level.
//
//==============================================================================
procedure R_PrecacheLevel;
var
  flatpresent: PByteArray;
  texturepresent: PByteArray;
  sprpresent: PByteArray;
  i: integer;
  j: integer;
  k: integer;
  lump: integer;
  texture: Ptexture_t;
  th: Pthinker_t;
  sf: Pspriteframe_t;
  flatmemory: integer;
  texturememory: integer;
  spritememory: integer;
  allocmemory: integer;
  sd: Pside_t;
begin
  printf('R_PrecacheLevel()'#13#10);

  // Precache flats.
  flatpresent := mallocz(numflats);

  for i := 0 to numsectors - 1 do
  begin
    flatpresent[sectors[i].floorpic] := 1;
    flatpresent[sectors[i].ceilingpic] := 1;
  end;

  flatmemory := 0;
  allocmemory := AllocMemSize;

  printf(' Precaching flats'#13#10);
  for i := 0 to numflats - 1 do
  begin
    if flatpresent[i] <> 0 then
    begin
      lump := R_GetLumpForFlat(i);
      W_CacheLumpNum(lump, PU_CACHE);
      flatmemory := flatmemory + lumpinfo[lump].size;
    end;
  end;
  allocmemory := AllocMemSize - allocmemory;
  printf('%6d KB memory usage for flats'#13#10, [(flatmemory + allocmemory) div 1024]);

  // Precache textures.
  texturepresent := mallocz(numtextures);

  sd := @sides[numsides];
  while sd <> @sides[0] do
  begin
    dec(sd);
    texturepresent[sd.toptexture] := 1;
    texturepresent[sd.midtexture] := 1;
    texturepresent[sd.bottomtexture] := 1;
  end;

  // Sky texture is always present.
  // Note that F_SKY1 is the name used to
  //  indicate a sky floor/ceiling as a flat,
  //  while the sky texture is stored like
  //  a wall texture, with an episode dependend
  //  name.
  texturepresent[skytexture] := 1;

  texturememory := 0;
  allocmemory := AllocMemSize;

  printf(' Precaching textures'#13#10);
  for i := 0 to numtextures - 1 do
  begin
    if texturepresent[i] = 0 then
      continue;

    texture := textures[i];

    for j := 0 to texture.patchcount - 1 do
    begin
      lump := texture.patches[j].patch;
      texturememory := texturememory + lumpinfo[lump].size;
      W_CacheLumpNum(lump, PU_CACHE);
    end;
  end;
  allocmemory := AllocMemSize - allocmemory;
  printf('%6d KB memory usage for textures'#13#10, [(texturememory + allocmemory) div 1024]);

  // Precache sprites.
  sprpresent := mallocz(numspritespresent);

  th := thinkercap.next;
  while th <> @thinkercap do
  begin
    if @th._function.acp1 = @P_MobjThinker then
      sprpresent[Pmobj_t(th).sprite] := 1;
    th := th.next;
  end;

  spritememory := 0;
  allocmemory := AllocMemSize;

  printf(' Precaching sprites'#13#10);
  for i := 0 to numspritespresent - 1 do
  begin
    if sprpresent[i] <> 0 then
    begin
      for j := 0 to sprites[i].numframes - 1 do
      begin
        sf := @sprites[i].spriteframes[j];
        for k := 0 to 7 do
        begin
          lump := firstspritelump + sf.lump[k];
          spritememory := spritememory + lumpinfo[lump].size;
          W_CacheLumpNum(lump, PU_CACHE);
        end;
      end;
    end;
  end;
  allocmemory := AllocMemSize - allocmemory;
  printf('%6d KB memory usage for sprites'#13#10, [(spritememory + allocmemory) div 1024]);

  memfree(pointer(flatpresent), numflats);
  memfree(pointer(texturepresent), numtextures);
  memfree(pointer(sprpresent), numspritespresent);
end;

//==============================================================================
//
// R_SetupLevel
//
//==============================================================================
procedure R_SetupLevel;
begin
  maxvisplane := -1;
  max_ds_p := -1;
  maxvissprite := -1;
  qz.Clear; // JVAL: WOLF
end;

end.
