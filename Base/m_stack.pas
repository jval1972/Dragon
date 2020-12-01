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
//------------------------------------------------------------------------------
//  Site  : https://sourceforge.net/projects/dragon-game/
//------------------------------------------------------------------------------

{$I dragon.inc}

unit m_stack;

interface

uses
  d_delphi;

type
  TIntegerStack = class(TDNumberList)
  public
    procedure Push(const x: integer);
    function Pop(var x: integer): boolean;
  end;

  TIntegerQueue = class(TDNumberList)
  public
    function Remove(var x: integer): boolean; overload;
    function Remove: boolean; overload;
  end;

procedure M_PushValue(const x: integer);

function M_PopValue: integer;

implementation

uses
  i_system;
  
var
  globalstack: TIntegerStack;

procedure TIntegerStack.Push(const x: integer);
begin
  Add(x);
end;

function TIntegerStack.Pop(var x: integer): boolean;
begin
  result := Count > 0;
  if result then
  begin
    x := Numbers[Count - 1];
    Delete(Count - 1);
  end;
end;

function TIntegerQueue.Remove(var x: integer): boolean;
begin
  result := Count > 0;
  if result then
  begin
    x := Numbers[0];
    Delete(0);
  end;
end;

function TIntegerQueue.Remove: boolean;
begin
  result := Count > 0;
  Delete(0);
end;

procedure M_PushValue(const x: integer);
begin
  globalstack.Push(x);
end;

function M_PopValue: integer;
begin
  if not globalstack.Pop(result) then
    I_DevError('M_PopValue(): Global Stack is empty!'#13#10);
end;

initialization
  globalstack := TIntegerStack.Create;

finalization
  globalstack.Free;

end.
