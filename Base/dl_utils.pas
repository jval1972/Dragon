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

unit dl_utils;

interface

function Get2Ints(const s: string; var i1, i2: integer): boolean;

function IsCDRomDrive(const drive: char = #0): boolean;

implementation

uses
  Windows, SysUtils;
  
function Get2Ints(const s: string; var i1, i2: integer): boolean;
var
  p: integer;
  s1, s2: string;
begin
  p := Pos('x', s);
  if p <= 0 then
  begin
    result := false;
    exit;
  end;

  s1 := Copy(s, 1, p - 1);
  s2 := Copy(s, p + 1, length(s) - p);

  i1 := StrToIntDef(s1, -1);
  i2 := StrToIntDef(s2, -1);

  result := (i1 > 0) and (i2 > 0);

end;

function IsCDRomDrive(const drive: char = #0): boolean;
var
  drv: array[0..3] of char;
  prm: string;
  i: integer;
begin
  if drive = #0 then
  begin
    prm := ParamStr(0);
    if length(prm) > 4 then
    begin
      for i := 0 to 2 do
        drv[i] := prm[i + 1];
      drv[3] := #0;
      result := GetDriveType(drv) = DRIVE_CDROM;
    end
    else
      result := GetDriveType(nil) = DRIVE_CDROM
  end
  else
  begin
    drv[0] := drive;
    drv[1] := ':';
    drv[2] := '\';
    drv[3] := #0;
    result := GetDriveType(drv) = DRIVE_CDROM;
  end;
end;



end.
 
