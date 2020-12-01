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
//  Refresh, visplane stuff (floor, ceilings).
//  Here is a core component: drawing the floors and ceilings,
//   while maintaining a per column clipping list only.
//  Moreover, the sky areas have to be determined.
//
//------------------------------------------------------------------------------
//  Site  : https://sourceforge.net/projects/dragon-game/
//------------------------------------------------------------------------------

{$I dragon.inc}

unit r_plane;

interface

uses
  m_fixed,
  doomdef, 
  r_data,
  r_defs;

//-----------------------------------------------------------------------------

procedure R_InitPlanes;
procedure R_ClearPlanes;

function R_FindPlane(height: fixed_t; picnum: integer; lightlevel: integer; xoffs, yoffs: fixed_t): Pvisplane_t;

var
  floorplane: Pvisplane_t;
  ceilingplane: Pvisplane_t;

//
// opening
//

// ?
const
  MAXOPENINGS = MAXWIDTH * 64;

var
  openings: packed array[0..MAXOPENINGS - 1] of smallint;
  lastopening: integer;

implementation

uses
  d_delphi,
  doomstat,
  d_player,
  tables,
  i_system,
  r_sky,
  r_draw,
  r_main,
  r_things,
  r_hires,
  z_zone,
  w_wad;

// Here comes the obnoxious "visplane".
const
// JVAL - Note about visplanes:
//   Top and Bottom arrays (of visplane_t struct) are now
//   allocated dynamically (using zone memory)
//   Use -zone cmdline param to specify more zone memory allocation
//   if out of memory.
//   See also R_NewVisPlane()
// Now maximum visplanes are 2048 (originally 128)
  MAXVISPLANES = 2048;

var
  visplanes: array[0..MAXVISPLANES - 1] of visplane_t;
  lastvisplane: integer;

//
// spanstart holds the start of a plane span
// initialized to 0 at start
//
  basexscale: fixed_t;
  baseyscale: fixed_t;

  cachedheight: array[0..MAXHEIGHT - 1] of fixed_t;

//
// R_InitPlanes
// Only at game startup.
//
procedure R_InitPlanes;
begin
  // Doh!
end;

//
// R_ClearPlanes
// At begining of frame.
//
procedure R_ClearPlanes;
var
  angle: angle_t;
begin
  lastvisplane := 0;
  lastopening := 0;

  // texture calculation
  ZeroMemory(@cachedheight, SizeOf(cachedheight));

  // left to right mapping
  angle := (viewangle - ANG90) shr ANGLETOFINESHIFT;

  // scale will be unit scale at SCREENWIDTH/2 distance
  basexscale := FixedDiv(finecosine[angle], centerxfrac);
  baseyscale := -FixedDiv(finesine[angle], centerxfrac);
end;

//
// R_NewVisPlane
//
// JVAL
//   Create a new visplane
//   Uses zone memory to allocate top and bottom arrays
//
procedure R_NewVisPlane;
begin
  if lastvisplane > maxvisplane then
    maxvisplane := lastvisplane;

  inc(lastvisplane);
end;

//
// R_FindPlane
//
function R_FindPlane(height: fixed_t; picnum: integer; lightlevel: integer; xoffs, yoffs: fixed_t): Pvisplane_t;
var
  check: integer;
begin
  if picnum = skyflatnum then
  begin
    height := 0; // all skies map together
    lightlevel := 0;
    xoffs := 0;
    yoffs := 0;
  end;

  check := 0;
  result := @visplanes[0];
  while check < lastvisplane do
  begin
    if (height = result.height) and
       (picnum = result.picnum) and
       (xoffs = result.xoffs) and
       (yoffs = result.yoffs) and
       (lightlevel = result.lightlevel) then
      break;
    inc(check);
    inc(result);
  end;

  if check < lastvisplane then
  begin
    exit;
  end;

  if lastvisplane = MAXVISPLANES then
    I_Error('R_FindPlane(): no more visplanes');

  R_NewVisPlane;

  result.height := height;
  result.picnum := picnum;
  result.lightlevel := lightlevel;
  result.minx := SCREENWIDTH;
  result.maxx := -1;
  result.xoffs := xoffs;
  result.yoffs := yoffs;
end;

end.

