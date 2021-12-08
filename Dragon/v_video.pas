//
//  Dragon
//  A game for Windows based on a modified and improved version of the
//  DelphiDoom engine
//
//  Copyright (C) 1993-1996 by id Software, Inc.
//  Copyright (C) 2004-2021 by Jim Valavanis
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

unit v_video;

interface

uses
  d_delphi,
  doomtype,
  doomdef,
  m_fixed,
// Needed because we are refering to patches.
  r_defs,
  v_data;

function V_GetScreenWidth(scrn: integer): integer;

function V_GetScreenHeight(scrn: integer): integer;

procedure V_SetPalette(const palette: PByteArray);

// Allocates buffer screens, call before R_Init.
procedure V_Init;
procedure V_ReInit;

procedure V_ShutDown;

function V_ScreensSize(const scrn: integer = -1): integer;

procedure V_CopyRect(
  srcx: integer;
  srcy: integer;
  srcscrn: integer;
  width: integer;
  height: integer;
  destx: integer;
  desty: integer;
  destscrn: integer;
  preserve: boolean);

procedure V_CopyRectTransparent(
  srcx: integer;
  srcy: integer;
  srcscrn: integer;
  width: integer;
  height: integer;
  destx: integer;
  desty: integer;
  destscrn: integer;
  preserve: boolean);

procedure V_ShadeBackground(const ofs: integer = 0;
  const count: integer = -1);

procedure V_DrawPatch(x, y: integer; scrn: integer; patch: Ppatch_t; preserve: boolean); overload;

procedure V_DrawPatch(x, y: integer; scrn: integer; const patchname: string; preserve: boolean); overload;

procedure V_DrawPatch(x, y: integer; scrn: integer; const lump: integer; preserve: boolean); overload;

procedure V_DrawPatchZoomed(x, y: integer; scrn: integer; patch: Ppatch_t; preserve: boolean; fraczoom: fixed_t);

procedure V_DrawPatchFlipped(x, y: integer; scrn: integer; patch: Ppatch_t);

procedure V_PageDrawer(const pagename: string);

// Draw a linear block of pixels into the view buffer.
procedure V_DrawBlock(x, y: integer; scrn: integer; width, height: integer; src: PByteArray);

procedure V_DrawLongBlock(x, y: integer; width, height: integer; src: PLongWordArray);

// Reads a linear block of pixels into the view buffer.
procedure V_GetBlock(x, y: integer; scrn: integer; width, height: integer; dest: PByteArray);

function V_PreserveX(const x: integer): integer;

function V_PreserveY(const y: integer): integer;

function V_PreserveW(const x: integer; const w: integer): integer;

function V_PreserveH(const y: integer; const h: integer): integer;

function V_NeedsPreserve(const destscrn, srcscrn: integer): boolean; overload;

function V_NeedsPreserve(const destscrn, srcscrn: integer; preserve: boolean): boolean; overload;

procedure V_CalcPreserveTables;

const
  GAMMASIZE = 5;

// Now where did these came from?
  gammatable: array[0..GAMMASIZE - 1, 0..255] of byte = (
    (  1,   2,   3,   4,   5,   6,   7,   8,   9,  10,  11,  12,  13,  14,  15,  16,
      17,  18,  19,  20,  21,  22,  23,  24,  25,  26,  27,  28,  29,  30,  31,  32,
      33,  34,  35,  36,  37,  38,  39,  40,  41,  42,  43,  44,  45,  46,  47,  48,
      49,  50,  51,  52,  53,  54,  55,  56,  57,  58,  59,  60,  61,  62,  63,  64,
      65,  66,  67,  68,  69,  70,  71,  72,  73,  74,  75,  76,  77,  78,  79,  80,
      81,  82,  83,  84,  85,  86,  87,  88,  89,  90,  91,  92,  93,  94,  95,  96,
      97,  98,  99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112,
     113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128,
     128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143,
     144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159,
     160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175,
     176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191,
     192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207,
     208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223,
     224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239,
     240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255),

    (  2,   4,   5,   7,   8,  10,  11,  12,  14,  15,  16,  18,  19,  20,  21,  23,
      24,  25,  26,  27,  29,  30,  31,  32,  33,  34,  36,  37,  38,  39,  40,  41,
      42,  44,  45,  46,  47,  48,  49,  50,  51,  52,  54,  55,  56,  57,  58,  59,
      60,  61,  62,  63,  64,  65,  66,  67,  69,  70,  71,  72,  73,  74,  75,  76,
      77,  78,  79,  80,  81,  82,  83,  84,  85,  86,  87,  88,  89,  90,  91,  92,
      93,  94,  95,  96,  97,  98,  99, 100, 101, 102, 103, 104, 105, 106, 107, 108,
     109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124,
     125, 126, 127, 128, 129, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139,
     140, 141, 142, 143, 144, 145, 146, 147, 148, 148, 149, 150, 151, 152, 153, 154,
     155, 156, 157, 158, 159, 160, 161, 162, 163, 163, 164, 165, 166, 167, 168, 169,
     170, 171, 172, 173, 174, 175, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184,
     185, 186, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 196, 197, 198,
     199, 200, 201, 202, 203, 204, 205, 205, 206, 207, 208, 209, 210, 211, 212, 213,
     214, 214, 215, 216, 217, 218, 219, 220, 221, 222, 222, 223, 224, 225, 226, 227,
     228, 229, 230, 230, 231, 232, 233, 234, 235, 236, 237, 237, 238, 239, 240, 241,
     242, 243, 244, 245, 245, 246, 247, 248, 249, 250, 251, 252, 252, 253, 254, 255),

    (  4,   7,   9,  11,  13,  15,  17,  19,  21,  22,  24,  26,  27,  29,  30,  32,
      33,  35,  36,  38,  39,  40,  42,  43,  45,  46,  47,  48,  50,  51,  52,  54,
      55,  56,  57,  59,  60,  61,  62,  63,  65,  66,  67,  68,  69,  70,  72,  73,
      74,  75,  76,  77,  78,  79,  80,  82,  83,  84,  85,  86,  87,  88,  89,  90,
      91,  92,  93,  94,  95,  96,  97,  98, 100, 101, 102, 103, 104, 105, 106, 107,
     108, 109, 110, 111, 112, 113, 114, 114, 115, 116, 117, 118, 119, 120, 121, 122,
     123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 133, 134, 135, 136, 137,
     138, 139, 140, 141, 142, 143, 144, 144, 145, 146, 147, 148, 149, 150, 151, 152,
     153, 153, 154, 155, 156, 157, 158, 159, 160, 160, 161, 162, 163, 164, 165, 166,
     166, 167, 168, 169, 170, 171, 172, 172, 173, 174, 175, 176, 177, 178, 178, 179,
     180, 181, 182, 183, 183, 184, 185, 186, 187, 188, 188, 189, 190, 191, 192, 193,
     193, 194, 195, 196, 197, 197, 198, 199, 200, 201, 201, 202, 203, 204, 205, 206,
     206, 207, 208, 209, 210, 210, 211, 212, 213, 213, 214, 215, 216, 217, 217, 218,
     219, 220, 221, 221, 222, 223, 224, 224, 225, 226, 227, 228, 228, 229, 230, 231,
     231, 232, 233, 234, 235, 235, 236, 237, 238, 238, 239, 240, 241, 241, 242, 243,
     244, 244, 245, 246, 247, 247, 248, 249, 250, 251, 251, 252, 253, 254, 254, 255),

    (  8,  12,  16,  19,  22,  24,  27,  29,  31,  34,  36,  38,  40,  41,  43,  45,
      47,  49,  50,  52,  53,  55,  57,  58,  60,  61,  63,  64,  65,  67,  68,  70,
      71,  72,  74,  75,  76,  77,  79,  80,  81,  82,  84,  85,  86,  87,  88,  90,
      91,  92,  93,  94,  95,  96,  98,  99, 100, 101, 102, 103, 104, 105, 106, 107,
     108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123,
     124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 135, 136, 137, 138,
     139, 140, 141, 142, 143, 143, 144, 145, 146, 147, 148, 149, 150, 150, 151, 152,
     153, 154, 155, 155, 156, 157, 158, 159, 160, 160, 161, 162, 163, 164, 165, 165,
     166, 167, 168, 169, 169, 170, 171, 172, 173, 173, 174, 175, 176, 176, 177, 178,
     179, 180, 180, 181, 182, 183, 183, 184, 185, 186, 186, 187, 188, 189, 189, 190,
     191, 192, 192, 193, 194, 195, 195, 196, 197, 197, 198, 199, 200, 200, 201, 202,
     202, 203, 204, 205, 205, 206, 207, 207, 208, 209, 210, 210, 211, 212, 212, 213,
     214, 214, 215, 216, 216, 217, 218, 219, 219, 220, 221, 221, 222, 223, 223, 224,
     225, 225, 226, 227, 227, 228, 229, 229, 230, 231, 231, 232, 233, 233, 234, 235,
     235, 236, 237, 237, 238, 238, 239, 240, 240, 241, 242, 242, 243, 244, 244, 245,
     246, 246, 247, 247, 248, 249, 249, 250, 251, 251, 252, 253, 253, 254, 254, 255),

    ( 16,  23,  28,  32,  36,  39,  42,  45,  48,  50,  53,  55,  57,  60,  62,  64,
      66,  68,  69,  71,  73,  75,  76,  78,  80,  81,  83,  84,  86,  87,  89,  90,
      92,  93,  94,  96,  97,  98, 100, 101, 102, 103, 105, 106, 107, 108, 109, 110,
     112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 128,
     128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143,
     143, 144, 145, 146, 147, 148, 149, 150, 150, 151, 152, 153, 154, 155, 155, 156,
     157, 158, 159, 159, 160, 161, 162, 163, 163, 164, 165, 166, 166, 167, 168, 169,
     169, 170, 171, 172, 172, 173, 174, 175, 175, 176, 177, 177, 178, 179, 180, 180,
     181, 182, 182, 183, 184, 184, 185, 186, 187, 187, 188, 189, 189, 190, 191, 191,
     192, 193, 193, 194, 195, 195, 196, 196, 197, 198, 198, 199, 200, 200, 201, 202,
     202, 203, 203, 204, 205, 205, 206, 207, 207, 208, 208, 209, 210, 210, 211, 211,
     212, 213, 213, 214, 214, 215, 216, 216, 217, 217, 218, 219, 219, 220, 220, 221,
     221, 222, 223, 223, 224, 224, 225, 225, 226, 227, 227, 228, 228, 229, 229, 230,
     230, 231, 232, 232, 233, 233, 234, 234, 235, 235, 236, 236, 237, 237, 238, 239,
     239, 240, 240, 241, 241, 242, 242, 243, 243, 244, 244, 245, 245, 246, 246, 247,
     247, 248, 248, 249, 249, 250, 250, 251, 251, 252, 252, 253, 254, 254, 255, 255)
  );

var
  usegamma: byte;

  curpal: array[0..255] of LongWord;
  videopal: array[0..255] of LongWord;

function V_FindAproxColorIndex(const pal: PLongWordArray; const c: LongWord;
  const start: integer = 0; const finish: integer = 255): integer;

var
  v_translation: PByteArray;

implementation

uses
  m_bbox,
  r_hires,
  r_data,
  r_mmx,
  t_draw,
  w_wad,
  z_zone;

// x and y translation tables for stretcing
var
  preserveX: array[0..319] of integer;
  preserveY: array[0..199] of integer;

function V_NeedsPreserve(const destscrn, srcscrn: integer): boolean; overload;
begin
  result := (V_GetScreenWidth(srcscrn) <> V_GetScreenWidth(destscrn)) or
            (V_GetScreenHeight(srcscrn) <> V_GetScreenHeight(destscrn));
end;

function V_NeedsPreserve(const destscrn, srcscrn: integer; preserve: boolean): boolean; overload;
begin
  result := preserve and V_NeedsPreserve(destscrn, srcscrn);
end;

// preserve x coordinates
function V_PreserveX(const x: integer): integer;
begin
  if x <= 0 then
    result := 0
  else if x >= 320 then
    result := V_GetScreenWidth(SCN_FG)
  else
    result := preserveX[x];
end;

// preserve y coordinates
function V_PreserveY(const y: integer): integer;
begin
  if y <= 0 then
    result := 0
  else if y >= 200 then
    result := V_GetScreenHeight(SCN_FG)
  else
    result := preserveY[y];
end;

// preserve width coordinates
function V_PreserveW(const x: integer; const w: integer): integer;
begin
  result := V_PreserveX(x + w) - V_PreserveX(x);
end;

// preserve height coordinates
function V_PreserveH(const y: integer; const h: integer): integer;
begin
  result := V_PreserveY(y + h) - V_PreserveY(y);
end;

//
// V_CopyRect
//
procedure V_CopyRect8(
  srcx: integer;
  srcy: integer;
  srcscrn: integer;
  width: integer;
  height: integer;
  destx: integer;
  desty: integer;
  destscrn: integer;
  preserve: boolean);
var
  src: PByteArray;
  dest: PByte;
  destA: PByteArray;
  destw: integer;
  desth: integer;
  fracxstep: fixed_t;
  fracystep: fixed_t;
  fracx: fixed_t;
  fracy: fixed_t;
  col: integer;
  row: integer;
  swidth: integer;
  dwidth: integer;
begin
  swidth := V_GetScreenWidth(srcscrn);
  dwidth := V_GetScreenWidth(destscrn);
  if V_NeedsPreserve(destscrn, srcscrn, preserve) then
  begin
    destw := V_PreserveW(destx, width);

    desth := V_PreserveH(desty, height);

    if (destw <> 0) and (desth <> 0) then
    begin
      destx := V_PreserveX(destx);

      desty := V_PreserveY(desty);

      fracy := srcy * FRACUNIT;
      fracxstep := FRACUNIT * width div destw;
      fracystep := FRACUNIT * height div desth;

      for row := desty to desty + desth - 1 do
      begin
        fracx := 0;
        dest := PByte(integer(screens[destscrn]) + dwidth * row + destx);
        src := PByteArray(integer(screens[srcscrn]) + swidth * (fracy div FRACUNIT) + srcx);
        for col := 0 to destw - 1 do
        begin
          dest^ := src[LongWord(fracx) shr FRACBITS];
          inc(dest);
          fracx := fracx + fracxstep;
        end;
        fracy := fracy + fracystep;
      end;
    end;
  end
  else
  begin

    src := PByteArray(integer(screens[srcscrn]) + swidth * srcy + srcx);
    destA := PByteArray(integer(screens[destscrn]) + dwidth * desty + destx);

    while height > 0 do
    begin
      memcpy(destA, src, width);
      src := PByteArray(integer(src) + swidth);
      destA := PByteArray(integer(destA) + dwidth);
      dec(height);
    end;
  end;
end;

procedure V_CopyRect32(
  srcx: integer;
  srcy: integer;
  srcscrn: integer;
  width: integer;
  height: integer;
  destx: integer;
  desty: integer;
  preserve: boolean);
var
  src: PByteArray;
  dest: PLongWord;
  destw: integer;
  desth: integer;
  fracxstep: fixed_t;
  fracystep: fixed_t;
  fracx: fixed_t;
  fracy: fixed_t;
  col: integer;
  row: integer;
  swidth: integer;
  dwidth: integer;
begin
  swidth := V_GetScreenWidth(srcscrn);
  dwidth := V_GetScreenWidth(SCN_FG);

  if V_NeedsPreserve(SCN_FG, srcscrn, preserve) then
  begin
    destw := V_PreserveW(destx, width);
    desth := V_PreserveH(desty, height);
  end
  else
  begin
    destw := width;
    desth := height;
  end;

  if (destw <> 0) and (desth <> 0) then
  begin
    if V_NeedsPreserve(SCN_FG, srcscrn, preserve) then
    begin
      destx := V_PreserveX(destx);
      desty := V_PreserveY(desty);
      fracxstep := FRACUNIT * width div destw;
      fracystep := FRACUNIT * height div desth;
    end
    else
    begin
      fracxstep := FRACUNIT;
      fracystep := FRACUNIT;
    end;

    fracy := srcy * FRACUNIT;

    for row := desty to desty + desth - 1 do
    begin
      fracx := 0;
      dest := @screen32[dwidth * row + destx];
      src := PByteArray(integer(screens[srcscrn]) + swidth * (fracy div FRACUNIT) + srcx);
      for col := 0 to destw - 1 do
      begin
        dest^ := videopal[src[LongWord(fracx) shr FRACBITS]];
        inc(dest);
        fracx := fracx + fracxstep;
      end;
      fracy := fracy + fracystep;
    end;
  end;
end;

procedure V_CopyRect(
  srcx: integer;
  srcy: integer;
  srcscrn: integer;
  width: integer;
  height: integer;
  destx: integer;
  desty: integer;
  destscrn: integer;
  preserve: boolean);
begin
  if (destscrn = SCN_FG) then
    V_CopyRect32(srcx, srcy, srcscrn, width, height, destx, desty, preserve)
  else
    V_CopyRect8(srcx, srcy, srcscrn, width, height, destx, desty, destscrn, preserve);
end;

//
// V_CopyRectTransparent
//
procedure V_CopyRectTransparent8(
  srcx: integer;
  srcy: integer;
  srcscrn: integer;
  width: integer;
  height: integer;
  destx: integer;
  desty: integer;
  destscrn: integer;
  preserve: boolean);
var
  src: PByteArray;
  dest: PByteArray;
  destw: integer;
  desth: integer;
  fracxstep: fixed_t;
  fracystep: fixed_t;
  fracx: fixed_t;
  fracy: fixed_t;
  col: integer;
  row: integer;
  srcb: byte;
  swidth: integer;
  dwidth: integer;
begin
  swidth := V_GetScreenWidth(srcscrn);
  dwidth := V_GetScreenWidth(destscrn);
  if V_NeedsPreserve(destscrn, srcscrn, preserve) then
  begin
    destw := V_PreserveW(destx, width);

    desth := V_PreserveH(desty, height);

    if (destw <> 0) and (desth <> 0) then
    begin
      destx := V_PreserveX(destx);

      desty := V_PreserveY(desty);

      fracy := srcy * FRACUNIT;
      fracxstep := FRACUNIT * width div destw;
      fracystep := FRACUNIT * height div desth;

      for row := desty to desty + desth - 1 do
      begin
        fracx := 0;
        dest := PByteArray(integer(screens[destscrn]) + dwidth * row + destx);
        // Source is a 320 width screen
        src := PByteArray(integer(screens[srcscrn]) + swidth * (fracy div FRACUNIT) + srcx);
        for col := 0 to destw - 1 do
        begin
          srcb := src[LongWord(fracx) shr FRACBITS];
          if srcb <> 0 then
            dest[col] := srcb;
          fracx := fracx + fracxstep;
        end;
        fracy := fracy + fracystep;
      end;
    end;
  end
  else
  begin

    src := PByteArray(integer(screens[srcscrn]) + swidth * srcy + srcx);
    dest := PByteArray(integer(screens[destscrn]) + dwidth * desty + destx);

    while height > 0 do
    begin
      for col := 0 to width - 1 do
      begin
        srcb := src[col];
        if srcb <> 0 then
          dest[col] := srcb;
      end;
      src := PByteArray(integer(src) + swidth);
      dest := PByteArray(integer(dest) + dwidth);
      dec(height);
    end;
  end;
end;

procedure V_CopyRectTransparent32(
  srcx: integer;
  srcy: integer;
  srcscrn: integer;
  width: integer;
  height: integer;
  destx: integer;
  desty: integer;
  preserve: boolean);
var
  src: PByteArray;
  dest: PLongWordArray;
  destw: integer;
  destw1: integer;
  desth: integer;
  fracxstep: fixed_t;
  fracxstep4: fixed_t;
  fracystep: fixed_t;
  fracx: fixed_t;
  fracy: fixed_t;
  col: integer;
  row: integer;
  swidth: integer;
  dwidth: integer;
  srcb: byte;
  psrcl: PLongWord;
begin
  swidth := V_GetScreenWidth(srcscrn);
  dwidth := V_GetScreenWidth(SCN_FG);

  if V_NeedsPreserve(SCN_FG, srcscrn, preserve) then
  begin
    destw := V_PreserveW(destx, width);
    desth := V_PreserveH(desty, height);
  end
  else
  begin
    destw := width;
    desth := height;
  end;
  destw1 := destw and $3;
  destw := destw - destw1;

  if (destw <> 0) and (desth <> 0) then
  begin
    if V_NeedsPreserve(SCN_FG, srcscrn, preserve) then
    begin
      destx := V_PreserveX(destx);
      desty := V_PreserveY(desty);
      fracxstep := FRACUNIT * width div destw;
      fracystep := FRACUNIT * height div desth;
      fracxstep4 := 4 * fracxstep;
    end
    else
    begin
      fracxstep := FRACUNIT;
      fracystep := FRACUNIT;
      fracxstep4 := 4 * FRACUNIT;
    end;

    fracy := srcy * FRACUNIT;

    for row := desty to desty + desth - 1 do
    begin
      fracx := 0;
      dest := @screen32[dwidth * row + destx];
      src := PByteArray(integer(screens[srcscrn]) + swidth * (fracy div FRACUNIT) + srcx);
      col := 0;
      while col < destw do
      begin
        psrcl := @src[LongWord(fracx) shr FRACBITS];
        if psrcl^ = 0 then
        begin
          inc(col, 4);
          fracx := fracx + fracxstep4;
        end
        else
        begin
          srcb := PByte(psrcl)^;
          if srcb <> 0 then
            dest[col] := videopal[srcb];
          inc(col);
          fracx := fracx + fracxstep;
        end;
      end;

      for col := destw to destw + destw1 - 1 do
      begin
        srcb := src[LongWord(fracx) shr FRACBITS];
        if srcb <> 0 then
          dest[col] := videopal[srcb];
        fracx := fracx + fracxstep;
      end;

      fracy := fracy + fracystep;
    end;
  end;
end;

procedure V_CopyRectTransparent(
  srcx: integer;
  srcy: integer;
  srcscrn: integer;
  width: integer;
  height: integer;
  destx: integer;
  desty: integer;
  destscrn: integer;
  preserve: boolean);
begin
  if (destscrn = SCN_FG) then
    V_CopyRectTransparent32(srcx, srcy, srcscrn, width, height, destx, desty, preserve)
  else
    V_CopyRectTransparent8(srcx, srcy, srcscrn, width, height, destx, desty, destscrn, preserve);
end;

procedure V_ShadeBackground(const ofs: integer = 0;
  const count: integer = -1);
var
  src: PByte;
  cnt: integer;
begin
  if count = -1 then
    cnt := V_GetScreenWidth(SCN_FG) * V_GetScreenHeight(SCN_FG)
  else
    cnt := count;
  src := PByte(@screen32[ofs]);
  while cnt > 0 do
  begin
    src^ := src^ shr 1;
    inc(src);
    src^ := src^ shr 1;
    inc(src);
    src^ := src^ shr 1;
    inc(src);
    src^ := $80;
    inc(src);
    dec(cnt);
  end;
end;

function V_GetScreenWidth(scrn: integer): integer;
begin
  result := screendimentions[scrn].width;
end;

function V_GetScreenHeight(scrn: integer): integer;
begin
  result := screendimentions[scrn].height;
end;

procedure V_DrawPatch8(x, y: integer; scrn: integer; patch: Ppatch_t; preserve: boolean);
var
  count: integer;
  col: integer;
  column: Pcolumn_t;
  desttop: PByte;
  dest: PByte;
  vs: byte;
  source: PByte;
  w: integer;
  pw: integer;
  ph: integer;
  fracx: fixed_t;
  fracy: fixed_t;
  fracxstep: fixed_t;
  fracystep: fixed_t;
  lasty: integer;
  cury: integer;
  swidth: integer;
  sheight: integer;
begin
  swidth := V_GetScreenWidth(scrn);
  if not V_NeedsPreserve(scrn, SCN_320x200, preserve) then
  begin
    y := y - patch.topoffset;
    x := x - patch.leftoffset;

    col := 0;

    desttop := PByte(integer(screens[scrn]) + y * swidth + x);

    w := patch.width;

    while col < w do
    begin
      column := Pcolumn_t(integer(patch) + patch.columnofs[col]);

    // step through the posts in a column
      while column.topdelta <> $ff do
      begin
        source := PByte(integer(column) + 3);
        dest := PByte(integer(desttop) + column.topdelta * swidth);
        count := column.length;

        while count > 0 do
        begin
          dest^ := v_translation[source^];
          inc(source);
          inc(dest, swidth);
          dec(count);
        end;
        column := Pcolumn_t(integer(column) + column.length + 4);
      end;
      inc(col);
      inc(desttop);
    end;

  end
////////////////////////////////////////////////////
// Streching Draw, preserving original dimentions
////////////////////////////////////////////////////
  else
  begin

    y := y - patch.topoffset;
    x := x - patch.leftoffset;

    pw := V_PreserveW(x, patch.width);
    ph := V_PreserveH(y, patch.height);

    if (pw > 0) and (ph > 0) then
    begin

      x := V_PreserveX(x);
      y := V_PreserveY(y);

      fracx := 0;
      fracxstep := FRACUNIT * patch.width div pw;
      fracystep := FRACUNIT * patch.height div ph;

      col := 0;
      desttop := PByte(integer(screens[scrn]) + y * swidth + x);

      sheight := V_GetScreenHeight(scrn);

      while col < pw do
      begin
        column := Pcolumn_t(integer(patch) + patch.columnofs[LongWord(fracx) shr FRACBITS]);

      // step through the posts in a column
        while column.topdelta <> $ff do
        begin
          source := PByte(integer(column) + 3);
          vs := v_translation[source^];
          dest := PByte(integer(desttop) + ((column.topdelta * sheight) div 200) * swidth);
          count := column.length;
          fracy := 0;
          lasty := 0;

          while count > 0 do
          begin
            dest^ := vs;
            inc(dest, swidth);
            fracy := fracy + fracystep;
            cury := LongWord(fracy) shr FRACBITS;
            if cury > lasty then
            begin
              lasty := cury;
              inc(source);
              vs := v_translation[source^];
              dec(count);
            end;
          end;
          column := Pcolumn_t(integer(column) + column.length + 4);
        end;
        inc(col);
        inc(desttop);

        fracx := fracx + fracxstep;
      end;
    end;
  end;
end;

procedure V_DrawPatch32(x, y: integer; patch: Ppatch_t; preserve: boolean);
var
  count: integer;
  col: integer;
  column: Pcolumn_t;
  desttop: PLongWordArray;
  dest: PLongWord;
  source: PByte;
  w: integer;
  pw: integer;
  ph: integer;
  fracx: fixed_t;
  fracy: fixed_t;
  fracxstep: fixed_t;
  fracystep: fixed_t;
  lasty: integer;
  cury: integer;
  swidth: integer;
  sheight: integer;
  vs: LongWord;
begin
  swidth := V_GetScreenWidth(SCN_FG);
  x := x - patch.leftoffset;
  y := y - patch.topoffset;

  if not V_NeedsPreserve(SCN_FG, SCN_320x200, preserve) then
  begin

    col := 0;

    desttop := @screen32[y * swidth + x];

    w := patch.width;

    while col < w do
    begin
      column := Pcolumn_t(integer(patch) + patch.columnofs[col]);

    // step through the posts in a column
      while column.topdelta <> $ff do
      begin
        source := PByte(integer(column) + 3);
        dest := @desttop[column.topdelta * swidth];
        count := column.length;

        while count > 0 do
        begin
          dest^ := videopal[source^];
          inc(source);
          inc(dest, swidth);
          dec(count);
        end;
        column := Pcolumn_t(integer(column) + column.length + 4);
      end;
      inc(col);
      desttop := @desttop[1];
    end;

  end
////////////////////////////////////////////////////
// Streching Draw, preserving original dimentions
////////////////////////////////////////////////////
  else
  begin

    pw := V_PreserveW(x, patch.width);
    ph := V_PreserveH(y, patch.height);

    if (pw > 0) and (ph > 0) then
    begin

      x := V_PreserveX(x);
      y := V_PreserveY(y);

      fracx := 0;
      fracxstep := FRACUNIT * patch.width div pw;
      fracystep := FRACUNIT * patch.height div ph;

      col := 0;
      desttop := @screen32[y * swidth + x];

      sheight := SCREENHEIGHT;

      while col < pw do
      begin
        column := Pcolumn_t(integer(patch) + patch.columnofs[fracx div FRACUNIT]);

      // step through the posts in a column
        while column.topdelta <> $ff do
        begin
          source := PByte(integer(column) + 3);
          vs := videopal[source^];
          dest := @desttop[((column.topdelta * sheight div 200) * swidth)];
          count := column.length;
          fracy := 0;
          lasty := 0;

          while count > 0 do
          begin
            dest^ := vs;
            inc(dest, swidth);
            fracy := fracy + fracystep;
            cury := LongWord(fracy) shr FRACBITS;
            if cury > lasty then
            begin
              lasty := cury;
              inc(source);
              vs := videopal[source^];
              dec(count);
            end;
          end;
          column := Pcolumn_t(integer(column) + column.length + 4);
        end;
        inc(col);
        desttop := @desttop[1];

        fracx := fracx + fracxstep;
      end;
    end;
  end;
end;

//
// V_DrawPatch
//
procedure V_DrawPatch(x, y: integer; scrn: integer; patch: Ppatch_t; preserve: boolean);
begin
  if (scrn = SCN_FG) then
    V_DrawPatch32(x, y, patch, preserve)
  else
    V_DrawPatch8(x, y, scrn, patch, preserve);
end;

procedure V_DrawPatch(x, y: integer; scrn: integer; const patchname: string; preserve: boolean);
var
  patch: Ppatch_t;
begin
  patch := W_CacheLumpName(patchname, PU_STATIC);
  V_DrawPatch(x, y, scrn, patch, preserve);
  Z_ChangeTag(patch, PU_CACHE);
end;

procedure V_DrawPatch(x, y: integer; scrn: integer; const lump: integer; preserve: boolean); overload;
var
  patch: Ppatch_t;
begin
  patch := W_CacheLumpNum(lump, PU_STATIC);
  V_DrawPatch(x, y, scrn, patch, preserve);
  Z_ChangeTag(patch, PU_CACHE);
end;

//
// V_DrawPatchZoomed
//
procedure V_DrawPatchZoomed8(x, y: integer; scrn: integer; patch: Ppatch_t; preserve: boolean; fraczoom: fixed_t);
var
  count: integer;
  col: integer;
  column: Pcolumn_t;
  desttop: PByte;
  dest: PByte;
  source: PByte;
  pw: integer;
  ph: integer;
  fracx: fixed_t;
  fracy: fixed_t;
  fracxstep: fixed_t;
  fracystep: fixed_t;
  lasty: integer;
  cury: integer;
  swidth: integer;
  sheight: integer;
begin
  if fraczoom = FRACUNIT then
  begin
    V_DrawPatch(x, y, scrn, patch, preserve);
    exit;
  end;

  y := y - patch.topoffset;
  x := x - patch.leftoffset;

  if V_NeedsPreserve(scrn, SCN_320x200, preserve) then
  begin
    pw := V_PreserveW(x, patch.width) * fraczoom div FRACUNIT;
    ph := V_PreserveH(y, patch.height) * fraczoom div FRACUNIT;
    x := V_PreserveX(x);
    y := V_PreserveY(y);
  end
  else
  begin
    pw := patch.width * fraczoom div FRACUNIT;
    ph := patch.height * fraczoom div FRACUNIT;
  end;

  if (pw > 0) and (ph > 0) then
  begin

    fracx := 0;
    fracxstep := FRACUNIT * patch.width div pw;
    fracystep := FRACUNIT * patch.height div ph;

    swidth := V_GetScreenWidth(scrn);
    sheight := V_GetScreenHeight(scrn);

    desttop := PByte(integer(screens[scrn]) + y * swidth + x);

    col := 0;

    while col < pw do
    begin
      column := Pcolumn_t(integer(patch) + patch.columnofs[fracx shr FRACBITS]);

      // step through the posts in a column
      while column.topdelta <> $ff do
      begin
        source := PByte(integer(column) + 3);
        dest := PByte(integer(desttop) + ((column.topdelta * sheight) * fraczoom div FRACUNIT div 200) * swidth);
        count := column.length;
        fracy := 0;
        lasty := 0;

        while count > 0 do
        begin
          dest^ := v_translation[source^];
          inc(dest, swidth);
          fracy := fracy + fracystep;
          cury := LongWord(fracy) shr FRACBITS;
          if cury > lasty then
          begin
            lasty := cury;
            inc(source);
            dec(count);
          end;
        end;
        column := Pcolumn_t(integer(column) + column.length + 4);
      end;
      inc(desttop);
      inc(col);

      fracx := fracx + fracxstep;
    end;
  end;

end;

procedure V_DrawPatchZoomed32(x, y: integer; patch: Ppatch_t; preserve: boolean; fraczoom: fixed_t);
var
  count: integer;
  col: integer;
  column: Pcolumn_t;
  desttop: PLongWordArray;
  dest: PLongWord;
  source: PByte;
  pw: integer;
  ph: integer;
  fracx: fixed_t;
  fracy: fixed_t;
  fracxstep: fixed_t;
  fracystep: fixed_t;
  lasty: integer;
  cury: integer;
  swidth: integer;
  sheight: integer;
begin
  if fraczoom = FRACUNIT then
  begin
    V_DrawPatch32(x, y, patch, preserve);
    exit;
  end;

  y := y - patch.topoffset;
  x := x - patch.leftoffset;

  if V_NeedsPreserve(SCN_FG, SCN_320x200, preserve) then
  begin
    pw := V_PreserveW(x, patch.width) * fraczoom div FRACUNIT;
    ph := V_PreserveH(y, patch.height) * fraczoom div FRACUNIT;
  end
  else
  begin
    pw := patch.width * fraczoom div FRACUNIT;
    ph := patch.height * fraczoom div FRACUNIT;
  end;

  if (pw > 0) and (ph > 0) then
  begin

    x := V_PreserveX(x);
    y := V_PreserveY(y);

    fracx := 0;
    fracxstep := FRACUNIT * patch.width div pw;
    fracystep := FRACUNIT * patch.height div ph;

    swidth := V_GetScreenWidth(SCN_FG);
    sheight := V_GetScreenHeight(SCN_FG);

    desttop := @screen32[y * swidth + x];

    col := 0;

    while col < pw do
    begin
      column := Pcolumn_t(integer(patch) + patch.columnofs[fracx div FRACUNIT]);

      // step through the posts in a column
      while column.topdelta <> $ff do
      begin
        source := PByte(integer(column) + 3);
        dest := @desttop[((column.topdelta * sheight) * fraczoom div FRACUNIT div 200) * swidth];
//        dest := @desttop[((column.topdelta * sheight) * fraczoom div FRACUNIT) * swidth div 200];
        count := column.length;
        fracy := 0;
        lasty := 0;

        while count > 0 do
        begin
          dest^ := videopal[source^];
          inc(dest, swidth);
          fracy := fracy + fracystep;
          cury := LongWord(fracy) shr FRACBITS;
          if cury > lasty then
          begin
            lasty := cury;
            inc(source);
            dec(count);
          end;
        end;
        column := Pcolumn_t(integer(column) + column.length + 4);
      end;
      desttop := @desttop[1];
      inc(col);

      fracx := fracx + fracxstep;
    end;
  end;

end;

procedure V_DrawPatchZoomed(x, y: integer; scrn: integer; patch: Ppatch_t; preserve: boolean; fraczoom: fixed_t);
begin
  if (scrn = SCN_FG) then
    V_DrawPatchZoomed32(x, y, patch, preserve, fraczoom)
  else
    V_DrawPatchZoomed8(x, y, scrn, patch, preserve, fraczoom);
end;

//
// V_DrawPatchFlipped
// Masks a column based masked pic to the screen.
// Flips horizontally, e.g. to mirror face.
//
procedure V_DrawPatchFlipped(x, y: integer; scrn: integer; patch: Ppatch_t);
var
  count: integer;
  col: integer;
  column: Pcolumn_t;
  desttop: PByte;
  dest: PByte;
  source: PByte;
  w: integer;
begin
  y := y - patch.topoffset;
  x := x - patch.leftoffset;

  col := 0;

  desttop := PByte(integer(screens[scrn]) + y * 320 + x);

  w := patch.width;

  while col < w do
  begin
    column := Pcolumn_t(integer(patch) + patch.columnofs[w - 1 - col]);

  // step through the posts in a column
    while column.topdelta <> $ff do
    begin
      source := PByte(integer(column) + 3);
      dest := PByte(integer(desttop) + column.topdelta * 320);
      count := column.length;

      while count > 0 do
      begin
        dest^ := v_translation[source^];
        inc(source);
        inc(dest, 320);
        dec(count);
      end;
      column := Pcolumn_t(integer(column) + column.length + 4);
    end;
    inc(col);
    inc(desttop);
  end;
end;

procedure V_PageDrawer(const pagename: string);
begin
  if useexternaltextures then
    if T_DrawFullScreenPatch(pagename, screen32) then
      exit;
  V_DrawPatch(0, 0, SCN_TMP, pagename, false);
  V_CopyRect(0, 0, SCN_TMP, 320, 200, 0, 0, SCN_FG, true);
end;

//
// V_DrawBlock
// Draw a linear block of pixels into the view buffer.
//
procedure V_DrawBlock8(x, y: integer; scrn: integer; width, height: integer; src: PByteArray);
var
  dest: PByteArray;
  swidth: integer;
begin
  swidth := V_GetScreenWidth(scrn);
  dest := PByteArray(integer(screens[scrn]) + y * swidth + x);

  while height <> 0 do
  begin
    memcpy(dest, src, width);
    src := PByteArray(integer(src) + width);
    dest := PByteArray(integer(dest) + swidth);
    dec(height);
  end;
end;

procedure V_DrawBlock32(x, y: integer; width, height: integer; src: PByteArray);
var
  dest: PLongWordArray;
  swidth: integer;
  i: integer;
begin
  swidth := V_GetScreenWidth(SCN_FG);
  dest := @screen32[y * swidth + x];

  while height <> 0 do
  begin
    for i := 0 to width - 1 do
      dest[i] := videopal[src[i]];
    src := PByteArray(integer(src) + width);
    dest := @dest[swidth];
    dec(height);
  end;
end;

procedure V_DrawBlock(x, y: integer; scrn: integer; width, height: integer; src: PByteArray);
begin
  if (scrn = SCN_FG) then
    V_DrawBlock32(x, y, width, height, src)
  else
    V_DrawBlock8(x, y, scrn, width, height, src)
end;

procedure V_DrawLongBlock(x, y: integer; width, height: integer; src: PLongWordArray);
var
  dest: PLongWordArray;
  swidth: integer;
begin
  swidth := V_GetScreenWidth(SCN_FG);
  dest := PLongWordArray(@screen32[y * swidth + x]);

  while height <> 0 do
  begin
    memcpy(dest, src, width * SizeOf(LongWord));
    src := PLongWordArray(@src[width]);
    dest := PLongWordArray(@dest[swidth]);
    dec(height);
  end;
end;

//
// V_GetBlock
// Gets a linear block of pixels from the view buffer.
//
procedure V_GetBlock(x, y: integer; scrn: integer; width, height: integer; dest: PByteArray);
var
  src: PByteArray;
  swidth: integer;
begin
  swidth := V_GetScreenWidth(scrn);

  src := PByteArray(integer(screens[scrn]) + y * swidth + x);

  while height <> 0 do
  begin
    memcpy(dest, src, width);
    src := PByteArray(integer(src) + swidth);
    dest := PByteArray(integer(dest) + width);
    dec(height);
  end;
end;

procedure V_CalcPreserveTables;
var
  i: integer;
begin
  // initialize translation tables
  for i := 0 to 319 do
    preserveX[i] := trunc(i * V_GetScreenWidth(SCN_FG) / 320);

  for i := 0 to 199 do
    preserveY[i] := trunc(i * V_GetScreenHeight(SCN_FG) / 200);
end;

//
// V_Init
//

//
// V_SetPalette
//
procedure V_SetPalette(const palette: PByteArray);
var
  dest: PLongWord;
  src: PByteArray;
  curgamma: PByteArray;
begin
  dest := @videopal[0];
  src := palette;
  curgamma := @gammatable[usegamma];
  while integer(src) < integer(@palette[256 * 3]) do
  begin
    dest^ := (LongWord(curgamma[src[0]]) shl 16) or
             (LongWord(curgamma[src[1]]) shl 8) or
             (LongWord(curgamma[src[2]])) or $FF000000;
    inc(dest);
    src := PByteArray(integer(src) + 3);
  end;
  videopal[0] := videopal[0] and $FFFFFF;
  recalctablesneeded := true;
  needsbackscreen := true; // force background redraw
end;

var
  vsize: integer = 0;

procedure V_Init;
var
  i: integer;
  base: PByteArray;
  st: integer;
  pal: PByteArray;
begin
  SCREENWIDTH32PITCH := SCREENWIDTH * SizeOf(LongWord);
  pal := V_ReadPalette(PU_STATIC);
  V_SetPalette(pal);
  Z_ChangeTag(pal, PU_CACHE);
  for i := SCN_FG to SCN_ST do
  begin
    if FIXED_DIMENTIONS[i].width = -1 then
      screendimentions[i].width := SCREENWIDTH
    else
      screendimentions[i].width := FIXED_DIMENTIONS[i].width;
    if FIXED_DIMENTIONS[i].height = -1 then
      screendimentions[i].height := SCREENHEIGHT
    else
      screendimentions[i].height := FIXED_DIMENTIONS[i].height;
  end;
  // stick these in low dos memory on PCs
  vsize := V_ScreensSize;
  base := malloc(vsize);

  st := 0;
  for i := SCN_FG to SCN_ST do
  begin
    screens[i] := @base[st];
    st := st + screendimentions[i].width * screendimentions[i].height;
  end;

  V_CalcPreserveTables;
end;

procedure V_ReInit;
begin
  V_ShutDown;
  V_Init;
end;

procedure V_ShutDown;
var
  base: pointer;
begin
  base := screens[SCN_FG];
  memfree(base, vsize);
end;

function V_ScreensSize(const scrn: integer = -1): integer;
var
  i: integer;
  w, h: integer;
  il, ih: integer;
begin
  if scrn = -1 then
  begin
    il := SCN_FG;
    ih := SCN_ST;
  end
  else
  begin
    il := scrn;
    ih := scrn;
  end;

  result := 0;
  for i := il to ih do
  begin
    w := FIXED_DIMENTIONS[i].width;
    if w = -1 then
      w := SCREENWIDTH;
    h := FIXED_DIMENTIONS[i].height;
    if h = -1 then
      h := SCREENHEIGHT;
    result := result + w * h * FIXED_DIMENTIONS[i].depth;
  end;
end;


//
// V_FindAproxColorIndex
//
// JVAL: Calculates the euclidian square distance of a given color from all
//       pal items and return the nearest
function V_FindAproxColorIndex(const pal: PLongWordArray; const c: LongWord;
  const start: integer = 0; const finish: integer = 255): integer;
var
  r, g, b: integer;
  rc, gc, bc: integer;
  dr, dg, db: integer;
  i: integer;
  cc: LongWord;
  dist: LongWord;
  mindist: LongWord;
begin
  r := c and $FF;
  g := (c shr 8) and $FF;
  b := (c shr 16) and $FF;
  result := start;
  mindist := LongWord($ffffffff);
  for i := start to finish do
  begin
    cc := pal[i];
    rc := cc and $FF;
    gc := (cc shr 8) and $FF;
    bc := (cc shr 16) and $FF;
    dr := r - rc;
    dg := g - gc;
    db := b - bc;
    dist := dr * dr + dg * dg + db * db;
    if dist < mindist then
    begin
      result := i;
      mindist := dist;
    end;
  end;
end;

end.
