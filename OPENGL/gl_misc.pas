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

unit gl_misc;

interface

//==============================================================================
//
// gl_i_min
//
//==============================================================================
function gl_i_min(const a, b: integer): integer;

//==============================================================================
//
// gl_i_max
//
//==============================================================================
function gl_i_max(const a, b: integer): integer;

//==============================================================================
//
// gl_f_max
//
//==============================================================================
function gl_f_max(const a, b: single): single;

implementation

//==============================================================================
//
// gl_i_min
//
//==============================================================================
function gl_i_min(const a, b: integer): integer;
begin
  if a > b then
    result := b
  else
    result := a;
end;

//==============================================================================
//
// gl_i_max
//
//==============================================================================
function gl_i_max(const a, b: integer): integer;
begin
  if a > b then
    result := a
  else
    result := b;
end;

//==============================================================================
//
// gl_f_max
//
//==============================================================================
function gl_f_max(const a, b: single): single;
begin
  if a > b then
    result := a
  else
    result := b;
end;

end.

