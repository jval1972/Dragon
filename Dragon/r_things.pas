//
//  Dragon
//  A game for Windows based on a modified and improved version of the
//  DelphiDoom engine
//
//  Copyright (C) 1993-1996 by id Software, Inc.
//  Copyright (C) 2004-2020 by Jim Valavanis
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
//  Rendering of moving objects, sprites.
//  Refresh of things, i.e. objects represented by sprites.
//
//------------------------------------------------------------------------------
//  Site  : https://sourceforge.net/projects/dragon-game/
//------------------------------------------------------------------------------

{$I dragon.inc}

unit r_things;

interface

uses
  d_delphi,
  doomdef,
  info,
  m_fixed,
  r_defs;

//-----------------------------------------------------------------------------

const
// JVAL Note about visprites
// Now visprites allocated dinamycally using Zone memory
// (Original MAXVISSPRITES was 128
  MAXVISSPRITES = 1024;

var
  maxvissprite: integer;

procedure R_AddSprites(sec: Psector_t);
procedure R_InitSprites(namelist: PIntegerArray);
procedure R_ClearSprites;
procedure R_DrawPlayer;

var
  pspritescale: fixed_t;
  pspriteiscale: fixed_t;
  pspriteyscale: fixed_t;

var
  mfloorclip: PSmallIntArray;
  mceilingclip: PSmallIntArray;
  spryscale: fixed_t;
  sprtopscreen: fixed_t;

// constant arrays             
//  used for psprite clipping and initializing clipping
  negonearray: packed array[0..MAXWIDTH - 1] of smallint;
  screenheightarray: packed array[0..MAXWIDTH - 1] of smallint;

// variables used to look up
//  and range check thing_t sprites patches
  sprites: Pspritedef_tArray;
  numspritespresent: integer;

implementation

uses
  tables,
  g_game,
  info_h,
  i_system,
{$IFDEF OPENGL}
  gl_render, // JVAL OPENGL
{$ENDIF}
  p_mobj_h,
  p_pspr,
  p_pspr_h,
  r_data,
  r_draw,
  r_main,
  r_bsp,
  r_hires,
  r_lights,
  z_zone,
  w_wad,
  doomstat;

const
  MINZ = FRACUNIT * 4;
  BASEYCENTER = 100;

type
  maskdraw_t = record
    x1: integer;
    x2: integer;

    column: integer;
    topclip: integer;
    bottomclip: integer;
  end;
  Pmaskdraw_t = ^maskdraw_t;

//
// Sprite rotation 0 is facing the viewer,
//  rotation 1 is one angle turn CLOCKWISE around the axis.
// This is not the same as the angle,
//  which increases counter clockwise (protractor).
// There was a lot of stuff grabbed wrong, so I changed it...
//
var
  spritelights: PBytePArray;

//
// INITIALIZATION FUNCTIONS
//
const
  MAXFRAMES = 29; // Maximun number of frames in sprite

var
  sprtemp: array[0..MAXFRAMES - 1] of spriteframe_t;
  maxframe: integer;
  spritename: string;

//
// R_InstallSpriteLump
// Local function for R_InitSprites.
//
procedure R_InstallSpriteLump(lump: integer;
  frame: LongWord; rotation: LongWord; flipped: boolean);
var
  r: integer;
begin
  if (frame >= MAXFRAMES) or (rotation > 8) then
    I_DevError('R_InstallSpriteLump(): Bad frame characters in lump %d (frame = %d, rotation = %d)'#13#10, [lump, frame, rotation]);

  if integer(frame) > maxframe then
    maxframe := frame;

  if rotation = 0 then
  begin
    // the lump should be used for all rotations
    sprtemp[frame].rotate := 0;
    for r := 0 to 7 do
    begin
      sprtemp[frame].lump[r] := lump - firstspritelump;
      sprtemp[frame].flip[r] := flipped;
    end;
    exit;
  end;

  // the lump is only used for one rotation
  if sprtemp[frame].rotate = 0 then
    I_Warning('R_InitSprites(): Sprite %s frame %s has rotations and a rot=0 lump'#13#10,
      [spritename, Chr(Ord('A') + frame)]);

  sprtemp[frame].rotate := 1;

  // make 0 based
  dec(rotation);
  if sprtemp[frame].lump[rotation] <> -1 then
    I_DevWarning('R_InitSprites(): Sprite %s : %s : %s has two lumps mapped to it'#13#10,
      [spritename, Chr(Ord('A') + frame), Chr(Ord('1') + rotation)]);

  sprtemp[frame].lump[rotation] := lump - firstspritelump;
  sprtemp[frame].flip[rotation] := flipped;
end;

//
// R_InitSpriteDefs
// Pass a null terminated list of sprite names
//  (4 chars exactly) to be used.
// Builds the sprite rotation matrixes to account
//  for horizontally flipped sprites.
// Will report an error if the lumps are inconsistant.
// Only called at startup.
//
// Sprite lump names are 4 characters for the actor,
//  a letter for the frame, and a number for the rotation.
// A sprite that is flippable will have an additional
//  letter/number appended.
// The rotation character can be 0 to signify no rotations.
//
procedure R_InitSpriteDefs(namelist: PIntegerArray);

  procedure sprtempreset;
  var
    i: integer;
    j: integer;
  begin
    for i := 0 to MAXFRAMES - 1 do
    begin
      sprtemp[i].rotate := -1;
      for j := 0 to 7 do
      begin
        sprtemp[i].lump[j] := -1;
        sprtemp[i].flip[j] := false;
      end;
    end;
  end;

var
  i: integer;
  l: integer;
  intname: integer;
  frame: integer;
  rotation: integer;
  start: integer;
  finish: integer;
  patched: integer;
begin
  // count the number of sprite names

  numspritespresent := 0;
  while namelist[numspritespresent] <> 0 do
    inc(numspritespresent);

  if numspritespresent = 0 then
    exit;

  sprites := Z_Malloc(numspritespresent * SizeOf(spritedef_t), PU_STATIC, nil);
  ZeroMemory(sprites, numspritespresent * SizeOf(spritedef_t));

  start := firstspritelump - 1;
  finish := lastspritelump + 1;

  // scan all the lump names for each of the names,
  //  noting the highest frame letter.
  // Just compare 4 characters as ints
  for i := 0 to numspritespresent - 1 do
  begin
    spritename := Chr(namelist[i]) + Chr(namelist[i] shr 8) + Chr(namelist[i] shr 16) + Chr(namelist[i] shr 24);

    sprtempreset;

    maxframe := -1;
    intname := namelist[i];

    // scan the lumps,
    //  filling in the frames for whatever is found
    for l := start + 1 to finish - 1 do
    begin
      if spritepresent[l - firstspritelump] then

      if lumpinfo[l].v1 = intname then // JVAL
      begin
        frame := Ord(lumpinfo[l].name[4]) - Ord('A');
        rotation := Ord(lumpinfo[l].name[5]) - Ord('0');

        if modifiedgame then
          patched := W_GetNumForName(lumpinfo[l].name)
        else
          patched := l;

        R_InstallSpriteLump(patched, frame, rotation, false);

        if lumpinfo[l].name[6] <> #0 then
        begin
          frame := Ord(lumpinfo[l].name[6]) - Ord('A');
          rotation := Ord(lumpinfo[l].name[7]) - Ord('0');
          R_InstallSpriteLump(l, frame, rotation, true);
        end;
      end;
    end;

    // check the frames that were found for completeness
    if maxframe = -1 then
    begin
      sprites[i].numframes := 0;
      continue;
    end;

    inc(maxframe);

    for frame := 0 to maxframe - 1 do
    begin
      case sprtemp[frame].rotate of
        -1:
          begin
            // no rotations were found for that frame at all
            // JVAL: Changed from I_Error to I_Warning
            I_Warning('R_InitSprites(): No patches found for %s frame %s'#13#10,
              [spritename, Chr(frame + Ord('A'))]);
          end;
         0:
          begin
            // only the first rotation is needed
          end;
         1:
          begin
            // must have all 8 frames
            for rotation := 0 to 7 do
              if sprtemp[frame].lump[rotation] = -1 then
                I_Error('R_InitSprites(): Sprite %s frame %s is missing rotations',
                  [spritename, Chr(frame + Ord('A'))]);
          end;
      end;
    end;

    // allocate space for the frames present and copy sprtemp to it
    sprites[i].numframes := maxframe;
    sprites[i].spriteframes :=
      Z_Malloc(maxframe * SizeOf(spriteframe_t), PU_STATIC, nil);
    memcpy(sprites[i].spriteframes, @sprtemp, maxframe * SizeOf(spriteframe_t));
  end;
end;

//
// GAME FUNCTIONS
//
var
  vissprites: array[0..MAXVISSPRITES - 1] of Pvissprite_t;
  vissprite_p: integer;

//
// R_InitSprites
// Called at program start.
//
procedure R_InitSprites(namelist: PIntegerArray);
var
  i: integer;
begin
  for i := 0 to SCREENWIDTH - 1 do
    negonearray[i] := -1;

  R_InitSpriteDefs(namelist);
end;

//
// R_ClearSprites
// Called at frame start.
//
procedure R_ClearSprites;
begin
  vissprite_p := 0;
end;

//
// R_NewVisSprite
//
// JVAL Now we allocate a new visprite dynamically
//
var
  overflowsprite: vissprite_t;

function R_NewVisSprite: Pvissprite_t;
begin
  if vissprite_p = MAXVISSPRITES then
    result := @overflowsprite
  else
  begin
    if vissprite_p > maxvissprite then
    begin
      maxvissprite := vissprite_p;
      vissprites[vissprite_p] := Z_Malloc(SizeOf(vissprite_t), PU_LEVEL, nil);
    end;
    result := vissprites[vissprite_p];
    inc(vissprite_p);
  end;
end;

//
//
// R_ProjectSprite
// Generates a vissprite for a thing
//  if it might be visible.
//
procedure R_ProjectSprite(thing: Pmobj_t);
var
  tr_x: fixed_t;
  tr_y: fixed_t;
  gxt: fixed_t;
  gyt: fixed_t;
  tx: fixed_t;
  tz: fixed_t;
  xscale: fixed_t;
  x1: integer;
  x2: integer;
  sprdef: Pspritedef_t;
  sprframe: Pspriteframe_t;
  lump: integer;
  rot: LongWord;
  flip: boolean;
  index: integer;
  vis: Pvissprite_t;
  ang: angle_t;
  checksides: boolean;
begin
  // Never make a vissprite when MF2_DONTDRAW is flagged.
  if thing.flags2_ex and MF2_EX_DONTDRAW <> 0 then
    exit;

  // transform the origin point
  tr_x := thing.x - viewx;
  tr_y := thing.y - viewy;

  gxt := FixedMul(tr_x, viewcos);
  gyt := -FixedMul(tr_y, viewsin);

  tz := gxt - gyt;

  // thing is behind view plane?
  checksides := (absviewpitch < 35) and (thing.state.dlights = nil) and (thing.state.models = nil);

  if checksides then
    if tz < MINZ then
      exit;

  xscale := FixedDiv(projection, tz);
  if xscale <= 0 then
    exit;

  gxt := -FixedMul(tr_x, viewsin);
  gyt := FixedMul(tr_y, viewcos);
  tx := -(gyt + gxt);

  // too far off the side?
  if checksides then
    if abs(tx) > 4 * tz then
      exit;

  // decide which patch to use for sprite relative to player
  sprdef := @sprites[thing.sprite];
  sprframe := @sprdef.spriteframes[thing.frame and FF_FRAMEMASK];

  if sprframe = nil then
  begin
    I_DevError('R_ProjectSprite(): Sprite for "%s" is NULL.'#13#10, [thing.info.name]);
    exit;
  end;

  if sprframe.rotate <> 0 then
  begin
    // choose a different rotation based on player view
    ang := R_PointToAngle(thing.x, thing.y);
    rot := (ang - thing.angle + LongWord(ANG45 div 2) * 9) shr 29;
    lump := sprframe.lump[rot];
    flip := sprframe.flip[rot];
  end
  else
  begin
    // use single rotation for all views
    lump := sprframe.lump[0];
    flip := sprframe.flip[0];
  end;

  // calculate edges of the shape
  tx := tx - spriteoffset[lump];
  x1 := FixedInt(centerxfrac + FixedMul(tx, xscale));

  // off the right side?
  if checksides then
    if x1 > viewwidth then
      exit;

  tx := tx + spritewidth[lump];
  x2 := FixedInt(centerxfrac + FixedMul(tx, xscale)) - 1;

  // off the left side
  if checksides then
    if x2 < 0 then
      exit;

  // store information in a vissprite
  vis := R_NewVisSprite;
  vis.mobjflags := thing.flags;
  vis.mobjflags_ex := thing.flags_ex or thing.state.flags_ex; // JVAL: extended flags passed to vis
  vis.mobjflags2_ex := thing.flags2_ex; // JVAL: extended flags passed to vis
  vis.mo := thing;
  vis._type := thing._type;
  vis.scale := FixedDiv(projectiony, tz); // JVAL For correct aspect
  vis.flip := flip;

  vis.patch := lump;

  // get light level
  if thing.flags and MF_SHADOW <> 0 then
  begin
    // shadow draw
    vis.colormap := nil;
  end
  else if fixedcolormap <> nil then
  begin
    // fixed map
    vis.colormap := fixedcolormap;
  end
  else if thing.frame and FF_FULLBRIGHT <> 0 then
  begin
    // full bright
    vis.colormap := colormaps;
  end
  else
  begin
    // diminished light
    index := _SHR(xscale, LIGHTSCALESHIFT);

    if index >= MAXLIGHTSCALE then
      index := MAXLIGHTSCALE - 1;

     vis.colormap := spritelights[index];
  end;

  gld_AddSprite(vis); // JVAL: OPENGL
end;

//
// R_AddSprites
// During BSP traversal, this adds sprites by sector.
//
procedure R_AddSprites(sec: Psector_t);
var
  thing: Pmobj_t;
  lightnum: integer;
begin
  // BSP is traversed by subsector.
  // A sector might have been split into several
  // subsectors during BSP building.
  // Thus we check whether its already added.
  if sec.validcount = validcount then
    exit;

  // Well, now it will be done.
  sec.validcount := validcount;

  lightnum := _SHR(sec.lightlevel, LIGHTSEGSHIFT) + extralight;

  if lightnum <= 0 then
    spritelights := @scalelight[0]
  else if lightnum >= LIGHTLEVELS then
    spritelights := @scalelight[LIGHTLEVELS - 1]
  else
    spritelights := @scalelight[lightnum];

  // Handle all things in sector.
  thing := sec.thinglist;
  while thing <> nil do
  begin
    R_ProjectSprite(thing);
    thing := thing.snext;
  end;
end;

//
// R_DrawPSprite
//
procedure R_DrawPSprite(psp: Ppspdef_t);
var
  tx: fixed_t;
  x1: integer;
  x2: integer;
  sprdef: Pspritedef_t;
  sprframe: Pspriteframe_t;
  lump: integer;
  vis: Pvissprite_t;
  avis: vissprite_t;
  lightlevel: integer; // JVAL OPENGL
begin
  // decide which patch to use

  sprdef := @sprites[Ord(psp.state.sprite)];

  sprframe := @sprdef.spriteframes[psp.state.frame and FF_FRAMEMASK];
                              
  lump := sprframe.lump[0];
  // calculate edges of the shape
  tx := psp.sx - 160 * FRACUNIT;

  tx := tx - spriteoffset[lump];
  x1 := FixedInt(centerxfrac + centerxshift + FixedMul(tx, pspritescale));

  // off the right side
  if x1 > viewwidth then
    exit;

  tx := tx + spritewidth[lump];
  x2 := FixedInt(centerxfrac + centerxshift + FixedMul(tx, pspritescale)) - 1;

  // off the left side
  if x2 < 0 then
    exit;

  // store information in a vissprite
  vis := @avis;
  vis.mobjflags := 0;
  vis.mobjflags_ex := 0;
  vis.mobjflags2_ex := 0;
  vis.mo := viewplayer.mo;
  vis._type := Ord(MT_PLAYER);

  vis.texturemid := (BASEYCENTER * FRACUNIT) + FRACUNIT div 2 - (psp.sy - spritetopoffset[lump]);
  if x1 < 0 then
    vis.x1 := 0
  else
    vis.x1 := x1;
  if x2 >= viewwidth then
    vis.x2 := viewwidth - 1
  else
    vis.x2 := x2;

  vis.scale := pspriteyscale;

  vis.patch := lump;

  if fixedcolormap <> nil then
  begin
    // fixed color
    vis.colormap := fixedcolormap;
    lightlevel := 255;
  end
  else if psp.state.frame and FF_FULLBRIGHT <> 0 then
  begin
    // full bright
    vis.colormap := colormaps;
    lightlevel := 255;
  end
  else
  begin
    // local light
    vis.colormap := spritelights[MAXLIGHTSCALE - 1];
    lightlevel := Psubsector_t(vis.mo.subsector).sector.lightlevel + extralight shl LIGHTSEGSHIFT
  end;

  gld_DrawWeapon(lump, vis, lightlevel); // JVAL OPENGL
end;

//
// R_DrawPlayerSprites
//
procedure R_DrawPlayerSprites;
var
  i: integer;
  lightnum: integer;
begin
  // get light level
  lightnum :=
    _SHR(Psubsector_t(viewplayer.mo.subsector).sector.lightlevel, LIGHTSEGSHIFT) +
      extralight;

  if lightnum <= 0 then
    spritelights := @scalelight[0]
  else if lightnum >= LIGHTLEVELS then
    spritelights := @scalelight[LIGHTLEVELS - 1]
  else
    spritelights := @scalelight[lightnum];

  // clip to screen bounds
  mfloorclip := @screenheightarray;
  mceilingclip := @negonearray;

  // add all active psprites
  if shiftangle < 128 then
    centerxshift := shiftangle * FRACUNIT div 40 * viewwidth
  else
    centerxshift := - (255 - shiftangle) * FRACUNIT div 40 * viewwidth;
  for i := 0 to Ord(NUMPSPRITES) - 1 do
  begin
    if viewplayer.psprites[i].state <> nil then
      R_DrawPSprite(@viewplayer.psprites[i]);
  end;
end;

procedure R_DrawPlayer;
var
  old_centery: fixed_t;
  old_centeryfrac: fixed_t;
begin
  // draw the psprites on top of everything
  //  but does not draw on side views
  if (viewangleoffset = 0) and not chasecamera then
  begin
    // Restore z-axis shift
    if zaxisshift then
    begin
      old_centery := centery;
      old_centeryfrac := centeryfrac;
      centery := viewheight div 2;
      centeryfrac := centery * FRACUNIT;
      R_DrawPlayerSprites;
      centery := old_centery;
      centeryfrac := old_centeryfrac;
    end
    else
      R_DrawPlayerSprites;
  end;
end;

end.
