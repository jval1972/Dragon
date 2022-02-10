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

// JVAL: Needed for model definition

unit sc_states;

interface

uses
  d_delphi;

var
  statenames: TDStringList;

//==============================================================================
//
// SC_ParseStatedefLump
//
//==============================================================================
procedure SC_ParseStatedefLump;

implementation

uses
  sc_engine,
  w_wad;

const
  STATEDEFLUMPNAME = 'STATEDEF';

//==============================================================================
//
// SC_ParseStatedefLump
//
//==============================================================================
procedure SC_ParseStatedefLump;
var
  i: integer;
  sc: TScriptEngine;
begin
  for i := 0 to W_NumLumps - 1 do
    if char8tostring(W_GetNameForNum(i)) = STATEDEFLUMPNAME then
    begin
      sc := TScriptEngine.Create(W_TextLumpNum(i));
      while sc.GetString do
        statenames.Add(strupper(sc._String));
      sc.Free;
      break;
    end;
end;

end.
