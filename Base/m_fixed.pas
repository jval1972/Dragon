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
//  Fixed point arithemtics, implementation.
//
//------------------------------------------------------------------------------
//  Site  : https://sourceforge.net/projects/dragon-game/
//------------------------------------------------------------------------------

{$I dragon.inc}

unit m_fixed;

interface

//-----------------------------------------------------------------------------

//
// Fixed point, 32bit as 16.16.
//

const
  FRACBITS = 16;
  FRACUNIT = 1 shl FRACBITS;

type
  fixed_t = integer;
  Pfixed_t = ^fixed_t;
  fixed_tArray = packed array[0..$FFFF] of fixed_t;
  Pfixed_tArray = ^fixed_tArray;

//==============================================================================
//
// FixedMul
//
//==============================================================================
function FixedMul(const a, b: fixed_t): fixed_t;

//==============================================================================
//
// FixedMul88
//
//==============================================================================
function FixedMul88(const a, b: fixed_t): fixed_t;

//==============================================================================
//
// FixedMul8
//
//==============================================================================
function FixedMul8(const a, b: fixed_t): fixed_t;

//==============================================================================
//
// FixedIntMul
//
//==============================================================================
function FixedIntMul(const a, b: fixed_t): fixed_t;

//==============================================================================
//
// IntFixedMul
//
//==============================================================================
function IntFixedMul(const a, b: fixed_t): fixed_t;

//==============================================================================
//
// FixedDiv
//
//==============================================================================
function FixedDiv(const a, b: fixed_t): fixed_t;

//==============================================================================
//
// FixedDiv2
//
//==============================================================================
function FixedDiv2(const a, b: fixed_t): fixed_t;

//==============================================================================
//
// FixedInt
//
//==============================================================================
function FixedInt(const x: integer): integer;

implementation

uses
  d_delphi,
  doomtype;

//==============================================================================
//
// FixedMul
//
//==============================================================================
function FixedMul(const a, b: fixed_t): fixed_t; assembler;
asm
  imul b
  shrd eax, edx, 16
end;

//==============================================================================
//
// FixedMul88
//
//==============================================================================
function FixedMul88(const a, b: fixed_t): fixed_t; assembler;
asm
  sar a, 8
  sar b, 8
  imul b
  shrd eax, edx, 16
end;

//==============================================================================
//
// FixedMul8
//
//==============================================================================
function FixedMul8(const a, b: fixed_t): fixed_t; assembler;
asm
  sar a, 8
  imul b
  shrd eax, edx, 16
end;

//==============================================================================
//
// FixedIntMul
//
//==============================================================================
function FixedIntMul(const a, b: fixed_t): fixed_t; assembler;
asm
  sar b, FRACBITS
  imul b
  shrd eax, edx, 16
end;

//==============================================================================
//
// IntFixedMul
//
//==============================================================================
function IntFixedMul(const a, b: fixed_t): fixed_t; assembler;
asm
  sar eax, FRACBITS
  imul b
  shrd eax, edx, 16
end;

//==============================================================================
//
// FixedDiv
//
//==============================================================================
function FixedDiv(const a, b: fixed_t): fixed_t;
begin
  if _SHR14(abs(a)) >= abs(b) then
  begin
    if a xor b < 0 then
      result := MININT
    else
      result := MAXINT;
  end
  else
    result := FixedDiv2(a, b);
end;

//==============================================================================
//
// FixedDiv2
//
//==============================================================================
function FixedDiv2(const a, b: fixed_t): fixed_t; assembler;
asm
  mov ebx, b
  mov edx, eax
  sal eax, 16
  sar edx, 16
  idiv ebx
end;

//==============================================================================
//
// FixedInt
//
//==============================================================================
function FixedInt(const x: integer): integer; assembler;
asm
  sar eax, FRACBITS
end;

end.

