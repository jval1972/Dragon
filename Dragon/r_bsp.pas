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
//  Refresh module, BSP traversal and handling.
//  BSP traversal, handling of LineSegs for rendering.
//
//------------------------------------------------------------------------------
//  Site  : https://sourceforge.net/projects/dragon-game/
//------------------------------------------------------------------------------

{$I dragon.inc}

unit r_bsp;

interface

uses
  d_delphi,
  r_defs;

//-----------------------------------------------------------------------------

// BSP?
procedure R_ClearClipSegs;
procedure R_ClearDrawSegs;


procedure R_RenderBSP;

function R_FakeFlat(sec: Psector_t; tempsec: Psector_t;
  floorlightlevel, ceilinglightlevel: PSmallInt; back: boolean): Psector_t;

type
  drawfunc_t = procedure(start: integer; stop: integer);

var
  ds_p: integer; // JVAL was: Pdrawseg_t
  max_ds_p: integer;

  curline: Pseg_t;
  frontsector: Psector_t;
  backsector: Psector_t;

  sidedef: Pside_t;
  linedef: Pline_t;
  drawsegs: array[0..MAXDRAWSEGS - 1] of Pdrawseg_t;

function R_UnderWater: boolean;


implementation

uses
  doomdata,
  m_fixed,
  tables,
  doomdef,
  m_bbox,
  p_setup,
  gl_defs,
  gl_clipper,
  gl_render,
  r_data,
  doomtype,

  r_main, r_plane, r_things, r_draw, r_sky,

// State.
  doomstat;

//
// killough 3/7/98: Hack floor/ceiling heights for deep water etc.
//
// If player's view height is underneath fake floor, lower the
// drawn ceiling to be just under the floor height, and replace
// the drawn floor and ceiling textures, and light level, with
// the control sector's.
//
// Similar for ceiling, only reflected.
//
// killough 4/11/98, 4/13/98: fix bugs, add 'back' parameter
//

function R_FakeFlat(sec: Psector_t; tempsec: Psector_t;
  floorlightlevel, ceilinglightlevel: PSmallInt; back: boolean): Psector_t;
var
  secheight: Psector_t;

  function notback1: boolean;
  begin
    tempsec.floorheight := sec.floorheight;
    tempsec.ceilingheight := secheight.floorheight - 1;
    result := not back;
  end;

begin
  if floorlightlevel <> nil then
  begin
    if sec.floorlightsec = -1 then
      floorlightlevel^ := sec.lightlevel
    else
      floorlightlevel^ := sectors[sec.floorlightsec].lightlevel;
  end;

  if ceilinglightlevel <> nil then
  begin
    if sec.ceilinglightsec = -1 then
      ceilinglightlevel^ := sec.lightlevel
    else
      ceilinglightlevel^ := sectors[sec.ceilinglightsec].lightlevel;
  end;
  result := sec;
end;

function R_UnderWater: boolean;
begin
  if viewplayer <> nil then
    if viewplayer.mo <> nil then
    begin
      result := (Psubsector_t(viewplayer.mo.subsector).sector.heightsec <> -1) and
                (viewz <= sectors[Psubsector_t(viewplayer.mo.subsector).sector.heightsec].floorheight);
      exit;
    end;
  result := false;
end;

//
// R_ClearDrawSegs
//
procedure R_ClearDrawSegs;
begin
  ds_p := 0;
end;

//
// ClipWallSegment
// Clips the given range of columns
// and includes it in the new clip list.
//
type
  cliprange_t = record
    first: integer;
    last: integer;
  end;
  Pcliprange_t = ^cliprange_t;

// 1/11/98: Lee Killough
//
// This fixes many strange venetian blinds crashes, which occurred when a scan
// line had too many "posts" of alternating non-transparent and transparent
// regions. Using a doubly-linked list to represent the posts is one way to
// do it, but it has increased overhead and poor spatial locality, which hurts
// cache performance on modern machines. Since the maximum number of posts
// theoretically possible is a function of screen width, a static limit is
// okay in this case. It used to be 32, which was way too small.
//
// This limit was frequently mistaken for the visplane limit in some Doom
// editing FAQs, where visplanes were said to "double" if a pillar or other
// object split the view's space into two pieces horizontally. That did not
// have anything to do with visplanes, but it had everything to do with these
// clip posts.

const
  MAXSEGS = MAXWIDTH div 2 + 1;

var
// newend is one past the last valid seg
  newend: Pcliprange_t;
  solidsegs: array[0..MAXSEGS - 1] of cliprange_t;

//
// R_ClearClipSegs
//
procedure R_ClearClipSegs;
begin
  newend := @solidsegs[0];
  newend.first := -$7fffffff;
  newend.last := -1;
  inc(newend);
  newend.first := viewwidth;
  newend.last := $7fffffff;
  inc(newend);
end;

var
  tempsec: sector_t;     // killough 3/8/98: ceiling/water hack

var
  tempsec_back, tempsec_front: sector_t;

function R_CheckClip(seg: Pseg_t; frontsector, backsector: Psector_t): boolean;
begin
  backsector := R_FakeFlat(backsector, @tempsec_back, nil, nil, true);
  frontsector := R_FakeFlat(frontsector, @tempsec_front, nil, nil, false);

  // check for closed sectors!
  if backsector.ceilingheight <= frontsector.floorheight then
  begin
    if seg.sidedef.toptexture = NO_TEXTURE then
      result := false
    else if (backsector.ceilingpic = skyflatnum) and (frontsector.ceilingpic = skyflatnum) then
      result := false
    else
      result := true;
    exit;
  end;

  if frontsector.ceilingheight <= backsector.floorheight then
  begin
    if seg.sidedef.bottomtexture = NO_TEXTURE then
      result := false
    // properly render skies (consider door "open" if both floors are sky):
    else if (backsector.ceilingpic = skyflatnum) and (frontsector.ceilingpic = skyflatnum) then
      result := false
    else
      result := true;
    exit;
  end;

  if backsector.ceilingheight <= backsector.floorheight then
  begin
    // preserve a kind of transparent door/lift special effect:
    if backsector.ceilingheight < frontsector.ceilingheight then
    begin
      if seg.sidedef.toptexture = NO_TEXTURE then
      begin
        result := false;
        exit;
      end;
    end;
    if backsector.floorheight > frontsector.floorheight then
    begin
      if seg.sidedef.bottomtexture = NO_TEXTURE then
      begin
        result := false;
        exit;
      end;
    end;
    if (backsector.ceilingpic = skyflatnum) and (frontsector.ceilingpic = skyflatnum) then
    begin
      result := false;
      exit;
    end;

    if (backsector.floorpic = skyflatnum) and (frontsector.floorpic = skyflatnum) then
    begin
      result := false;
      exit;
    end;

    result := true;
    exit;
  end;
  result := false;
end;

//
// R_AddLine
// Clips the given segment
// and adds any visible pieces to the line list.
//
procedure R_AddLine(line: Pseg_t);
var
  x1: integer;
  x2: integer;
  tspan: angle_t;
  clipangle2: angle_t;
  angle1: angle_t;
  angle2: angle_t;
  span: angle_t;
begin
  curline := line;

  if line.v1.x < 0 then
    if viewplayer.mo.x > 0 then
      exit;

  if line.v1.x > 0 then
    if viewplayer.mo.x < 0 then
      exit;

  // OPTIMIZE: quickly reject orthogonal back sides.
  angle1 := R_PointToAngle(line.v1.x, line.v1.y);
  angle2 := R_PointToAngle(line.v2.x, line.v2.y);

  // Clip to view edges.
  // OPTIMIZE: make constant out of 2*clipangle (FIELDOFVIEW).
  span := angle1 - angle2;

  // Back side? I.e. backface culling?
  if span >= ANG180 then
    exit;

  if not gld_clipper_SafeCheckRange(angle2, angle1) then
    exit;

  if line.backsector = nil then
    gld_clipper_SafeAddClipRange(angle2, angle1)
  else
  begin
    if line.frontsector = line.backsector then
      if texturetranslation[line.sidedef.midtexture] <> NO_TEXTURE then
        exit; //e6y: nothing to do here!
    if R_CheckClip(line, line.frontsector, line.backsector) then
      gld_clipper_SafeAddClipRange(angle2, angle1);
  end;

  if absviewpitch < 10 then
  begin
    angle1 := angle1 - viewangle;
    angle2 := angle2 - viewangle;

    tspan := angle1 + clipangle;
    clipangle2 := 2 * clipangle;
    if tspan > clipangle2 then
    begin
      tspan := tspan - clipangle2;

      // Totally off the left edge?
      if tspan >= span then
        exit;

      angle1 := clipangle;
    end;

    tspan := clipangle - angle2;
    if tspan > clipangle2 then
    begin
      tspan := tspan - clipangle2;

      // Totally off the left edge?
      if tspan >= span then
        exit;

      angle2 := -clipangle;
    end;

    // The seg is in the view range,
    // but not necessarily visible.
    angle1 := (angle1 + ANG90) shr ANGLETOFINESHIFT;
    angle2 := (angle2 + ANG90) shr ANGLETOFINESHIFT;
    x1 := viewangletox[angle1];
    x2 := viewangletox[angle2];

    if x1 >= x2 then
      exit;

  end;

  gld_AddWall(line); // JVAL OPENGL
end;

//
// R_CheckBBox
// Checks BSP node/subtree bounding box.
// Returns true
//  if some part of the bbox might be visible.
//
const
  checkcoord: array[0..11, 0..3] of integer = (
    (3, 0, 2, 1),
    (3, 0, 2, 0),
    (3, 1, 2, 0),
    (0, 0, 0, 0),
    (2, 0, 2, 1),
    (0, 0, 0, 0),
    (3, 1, 3, 0),
    (0, 0, 0, 0),
    (2, 0, 3, 1),
    (2, 1, 3, 1),
    (2, 1, 3, 0),
    (0, 0, 0, 0)
  );

function R_CheckBBox(bspcoordA: Pfixed_tArray; const side: integer): boolean;
var
  bspcoord: Pfixed_tArray;
  boxx: integer;
  boxy: integer;
  boxpos: integer;
  x1: fixed_t;
  y1: fixed_t;
  x2: fixed_t;
  y2: fixed_t;
  angle1: angle_t;
  angle2: angle_t;
  pcoord: PIntegerArray;
begin
  if side = 0 then
    bspcoord := bspcoordA
  else
    bspcoord := @bspcoordA[4];

  // Find the corners of the box
  // that define the edges from current viewpoint.
  if viewx <= bspcoord[BOXLEFT] then
    boxx := 0
  else if viewx < bspcoord[BOXRIGHT] then
    boxx := 1
  else
    boxx := 2;

  if viewy >= bspcoord[BOXTOP] then
    boxy := 0
  else if viewy > bspcoord[BOXBOTTOM] then
    boxy := 1
  else
    boxy := 2;

  boxpos := boxy * 4 + boxx;
  if boxpos = 5 then
  begin
    result := true;
    exit;
  end;

  pcoord := @checkcoord[boxpos];
  x1 := bspcoord[pcoord[0]];
  y1 := bspcoord[pcoord[1]];
  x2 := bspcoord[pcoord[2]];
  y2 := bspcoord[pcoord[3]];

  angle1 := R_PointToAngle(x1, y1);
  angle2 := R_PointToAngle(x2, y2);
  result := gld_clipper_SafeCheckRange(angle2, angle1);
end;

//
// R_Subsector
// Determine floor/ceiling planes.
// Add sprites of things in sector.
// Draw one or more line segments.
//
procedure R_Subsector(const num: integer);
var
  count: integer;
  line: Pseg_t;
  i_line: integer;
  sub: Psubsector_t;
  floorlightlevel: smallint;     // killough 3/16/98: set floor lightlevel
  ceilinglightlevel: smallint;   // killough 4/11/98
  i: integer;
  dummyfloorplane: visplane_t;
  dummyceilingplane: visplane_t;
  tmpline: Pline_t;
  sectorrendered: boolean;
begin
  inc(sscount);
  sub := @subsectors[num];
  frontsector := sub.sector;
  count := sub.numlines;
  i_line := sub.firstline;
  line := @segs[i_line];

  // killough 3/8/98, 4/4/98: Deep water / fake ceiling effect
  frontsector := R_FakeFlat(frontsector, @tempsec,
    @floorlightlevel, @ceilinglightlevel, false);   // killough 4/11/98
  frontsector.floorlightlevel := floorlightlevel;
  frontsector.ceilinglightlevel := ceilinglightlevel;

  if (frontsector.floorheight < viewz) or
     ((frontsector.heightsec <> -1) and
     (sectors[frontsector.heightsec].ceilingpic = skyflatnum)) then
  begin
    floorplane := R_FindPlane(frontsector.floorheight,
                              frontsector.floorpic,
                              floorlightlevel,
                              frontsector.floor_xoffs,
                              frontsector.floor_yoffs);
  end
  else
    floorplane := nil;

  if (frontsector.ceilingheight > viewz) or
     (frontsector.ceilingpic = skyflatnum) or
     ((frontsector.heightsec <> -1) and (sectors[frontsector.heightsec].floorpic = skyflatnum)) then
  begin
    ceilingplane := R_FindPlane(frontsector.ceilingheight,
                                frontsector.ceilingpic,
                                ceilinglightlevel,
                                frontsector.ceiling_xoffs,
                                frontsector.ceiling_yoffs);
  end
  else
    ceilingplane := nil;

  if frontsector = sub.sector then
  begin
    // if the sector has bottomtextures, then the floorheight will be set to the
    // highest surounding floorheight
    if frontsector.no_bottomtextures or (floorplane = nil) then
    begin
      i := frontsector.linecount;

      //e6y: this gives a huge speedup on levels with sectors which have many lines
      if frontsector.floor_validcount = validcount then
      begin
        dummyfloorplane.height := frontsector.highestfloor_height;
        dummyfloorplane.lightlevel := frontsector.highestfloor_lightlevel;
      end
      else
      begin
        frontsector.floor_validcount := validcount;
        dummyfloorplane.height := MININT;
        while i > 0 do
        begin
          dec(i);
          tmpline := frontsector.lines[i];
          if tmpline.backsector <> nil then
            if tmpline.backsector <> frontsector then
              if tmpline.backsector.floorheight > dummyfloorplane.height then
              begin
                dummyfloorplane.height := tmpline.backsector.floorheight;
                dummyfloorplane.lightlevel := tmpline.backsector.lightlevel;
              end;
          if tmpline.frontsector <> nil then
            if tmpline.frontsector <> frontsector then
              if tmpline.frontsector.floorheight > dummyfloorplane.height then
              begin
                dummyfloorplane.height := tmpline.frontsector.floorheight;
                dummyfloorplane.lightlevel := tmpline.frontsector.lightlevel;
              end;
        end;
        //e6y
        frontsector.highestfloor_height := dummyfloorplane.height;
        frontsector.highestfloor_lightlevel := dummyfloorplane.lightlevel;
      end;
      if dummyfloorplane.height <> MININT then
        floorplane := @dummyfloorplane;
    end;
    // the same for ceilings. they will be set to the lowest ceilingheight
    if frontsector.no_toptextures or (ceilingplane = nil) then
    begin
      i := frontsector.linecount;

      // this gives a huge speedup on levels with sectors which have many lines
      if frontsector.ceil_validcount = validcount then
      begin
        dummyceilingplane.height := frontsector.lowestceil_height;
        dummyceilingplane.lightlevel := frontsector.lowestceil_lightlevel;
      end
      else
      begin
        frontsector.ceil_validcount := validcount;
        dummyceilingplane.height := MAXINT;
        while i > 0 do
        begin
          dec(i);
          tmpline := frontsector.lines[i];
          if tmpline.backsector <> nil then
            if tmpline.backsector <> frontsector then
              if tmpline.backsector.ceilingheight < dummyceilingplane.height then
              begin
                dummyceilingplane.height := tmpline.backsector.ceilingheight;
                dummyceilingplane.lightlevel := tmpline.backsector.lightlevel;
              end;
          if tmpline.frontsector <> nil then
            if tmpline.frontsector <> frontsector then
              if tmpline.frontsector.ceilingheight < dummyceilingplane.height then
              begin
                dummyceilingplane.height := tmpline.frontsector.ceilingheight;
                dummyceilingplane.lightlevel := tmpline.frontsector.lightlevel;
              end;
        end;
        frontsector.lowestceil_height := dummyceilingplane.height;
        frontsector.lowestceil_lightlevel := dummyceilingplane.lightlevel;
      end;
      if dummyceilingplane.height <> MAXINT then
        ceilingplane := @dummyceilingplane;
    end;
  end;


  sectorrendered := true;
  if sub.sector.tag <> 1000 then
    sectorrendered := gld_AddPlane(num, floorplane, ceilingplane); // JVAL OPENGL

  if sectorrendered then
    R_AddSprites(sub.sector); //jff 9/11/98 passing frontsector here was
                              //causing the underwater fireball medusa problem
                              //when R_FakeFlat substituted a fake sector

  if gl_add_all_lines then
  begin
    while count <> 0 do
    begin
      // JVAL 27/9/2009
      // If we have a one-sided linedef then we draw it regardless the clipping
      if not line.miniseg then
      begin
        if line.linedef.flags and ML_TWOSIDED = 0 then
          gld_AddWall(line)
        else
          R_AddLine(line);
      end;
      inc(line);
      dec(count);
    end;
  end
  else
  begin
    while count <> 0 do
    begin
      if not line.miniseg then
        R_AddLine(line);
      inc(line);
      dec(count);
    end;
  end;
end;

//
// RenderBSPNode
// Renders all subsectors below a given node,
//  traversing subtree recursively.
// Just call with BSP root.
procedure R_RenderBSPNode(bspnum: integer);
var
  bsp: Pnode_t;
  side: integer;
begin
  while bspnum and NF_SUBSECTOR = 0 do  // Found a subsector?
  begin
    bsp := @nodes[bspnum];

    // Decide which side the view point is on.
    if R_PointOnSide(viewx, viewy, bsp) then
      side := 1
    else
      side := 0;
    // Recursively divide front space.
    R_RenderBSPNode(bsp.children[side]);

    // Possibly divide back space.

    side := side xor 1;
    if not R_CheckBBox(Pfixed_tArray(@bsp.bbox), side) then
      exit;

    bspnum := bsp.children[side];
  end;
  if bspnum = -1 then
    R_Subsector(0)
  else
    R_Subsector(bspnum and not NF_SUBSECTOR);
end;

procedure R_RenderBSP;
begin
  if (viewx < 0) and (viewy > -1750 * FRACUNIT) and (viewy < -1100 * FRACUNIT) then
  begin
    R_AddSprites(@sectors[98]);
    R_AddSprites(@sectors[425]);
    R_AddSprites(@sectors[427]);
  end;
  R_RenderBSPNode(numnodes - 1);
end;

end.
