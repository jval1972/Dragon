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

unit i_input;

interface

//==============================================================================
//
// I_InitInput
//
//==============================================================================
procedure I_InitInput;

//==============================================================================
//
// I_ProcessInput
//
//==============================================================================
procedure I_ProcessInput;

//==============================================================================
//
// I_ShutDownInput
//
//==============================================================================
procedure I_ShutDownInput;

//==============================================================================
//
// I_SynchronizeInput
//
//==============================================================================
procedure I_SynchronizeInput(active: boolean);

var
  usedirectinput: boolean = false;

implementation

uses
  Windows,
  DirectX,
  d_delphi,
  doomdef,
  d_event,
  d_main,
  gl_main,
  i_system;

//==============================================================================
//
// TranslateKey
//
//==============================================================================
function TranslateKey(keycode: integer): integer;
begin
  case keycode of
    VK_LEFT, VK_NUMPAD4: result := KEY_LEFTARROW;
    VK_RIGHT, VK_NUMPAD6: result := KEY_RIGHTARROW;
    VK_DOWN, VK_NUMPAD2: result := KEY_DOWNARROW;
    VK_UP, VK_NUMPAD8: result := KEY_UPARROW;
    VK_ESCAPE: result := KEY_ESCAPE;
    VK_RETURN: result := KEY_ENTER;
    VK_SNAPSHOT: result := KEY_PRNT;
  else
    result := 0;
  end;
end;

//==============================================================================
//
// TranslateSysKey
//
//==============================================================================
function TranslateSysKey(keycode: integer): integer;
begin
  case keycode of
    VK_CONTROL: result := KEY_RCTRL;
    VK_MENU: result := KEY_RALT;
  else
    result := 0;
  end;
end;

const
  I_IGRORETICKS = 15; // ~ half second

var
  ignoretics: integer;
  g_pDI: IDirectInputA = nil;
  g_pdidKeyboard: IDirectInputDevice = nil;
  curkeys: PKeyboardState;
  oldkeys: PKeyboardState;

//==============================================================================
// I_InitInput
//
//-----------------------------------------------------------------------------
// Name: CreateDInput()
// Desc: Initialize the DirectInput variables using:
//           DirectInputCreate
//           IDirectInput::CreateDevice
//           IDirectInputDevice::SetDataFormat
//           IDirectInputDevice::SetCooperativeLevel
//-----------------------------------------------------------------------------
//
//==============================================================================
procedure I_InitInput;
var
  hres: HRESULT;

  procedure I_ErrorInitInput(const msg: string);
  begin
    I_Error('I_InitInput(): %s failed, result = %d', [msg, hres]);
  end;

begin
  ignoretics := 0;

  curkeys := mallocz(SizeOf(TKeyboardState));
  oldkeys := mallocz(SizeOf(TKeyboardState));
  printf(' Keyboard initialized'#13#10);
end;

//-----------------------------------------------------------------------------
// Name: I_ShutDownInput
// Desc: Terminate our usage of DirectInput
//-----------------------------------------------------------------------------
//
//==============================================================================
procedure I_ShutDownInput;
begin
  memfree(pointer(curkeys), SizeOf(TKeyboardState));
  memfree(pointer(oldkeys), SizeOf(TKeyboardState));
end;

//-----------------------------------------------------------------------------
// Name: I_ProcessInput;
// Desc: The game plays here. Read keyboard data and displaying it.
//-----------------------------------------------------------------------------
//
//==============================================================================
procedure I_ProcessInput;

  function DIKEYtoVK(Key: Byte): Integer;
  begin
    result := 0;
    case Key of
      DIK_ESCAPE       : result := VK_ESCAPE;
      DIK_1            : result := Ord('1');
      DIK_2            : result := Ord('2');
      DIK_3            : result := Ord('3');
      DIK_4            : result := Ord('4');
      DIK_5            : result := Ord('5');
      DIK_6            : result := Ord('6');
      DIK_7            : result := Ord('7');
      DIK_8            : result := Ord('8');
      DIK_9            : result := Ord('9');
      DIK_0            : result := Ord('0');
      DIK_EQUALS       : result := Ord('=');
      DIK_BACK         : result := VK_BACK;
      DIK_TAB          : result := VK_TAB;
      DIK_Q            : result := Ord('Q');
      DIK_W            : result := Ord('W');
      DIK_E            : result := Ord('E');
      DIK_R            : result := Ord('R');
      DIK_T            : result := Ord('T');
      DIK_Y            : result := Ord('Y');
      DIK_U            : result := Ord('U');
      DIK_I            : result := Ord('I');
      DIK_O            : result := Ord('O');
      DIK_P            : result := Ord('P');
      DIK_LBRACKET     : result := Ord('[');
      DIK_RBRACKET     : result := Ord(']');
      DIK_RETURN       : result := VK_RETURN;
      DIK_LCONTROL     : result := VK_CONTROL;
      DIK_A            : result := Ord('A');
      DIK_S            : result := Ord('S');
      DIK_D            : result := Ord('D');
      DIK_F            : result := Ord('F');
      DIK_G            : result := Ord('G');
      DIK_H            : result := Ord('H');
      DIK_J            : result := Ord('J');
      DIK_K            : result := Ord('K');
      DIK_L            : result := Ord('L');
      DIK_SEMICOLON    : result := Ord(';');
      DIK_APOSTROPHE   : result := Ord('''');
      DIK_LSHIFT       : result := VK_SHIFT;
      DIK_BACKSLASH    : result := Ord('\');
      DIK_Z            : result := Ord('Z');
      DIK_X            : result := Ord('X');
      DIK_C            : result := Ord('C');
      DIK_V            : result := Ord('V');
      DIK_B            : result := Ord('B');
      DIK_N            : result := Ord('N');
      DIK_M            : result := Ord('M');
      DIK_COMMA        : result := Ord(',');
      DIK_PERIOD       : result := Ord('.');
      DIK_SLASH        : result := Ord('/');
      DIK_RSHIFT       : result := VK_SHIFT;
      DIK_MULTIPLY     : result := Ord('*');
      DIK_LMENU        : result := VK_MENU;
      DIK_SPACE        : result := VK_SPACE;
      DIK_CAPITAL      : result := VK_CAPITAL;
      DIK_F1           : result := VK_F1;
      DIK_F2           : result := VK_F2;
      DIK_F3           : result := VK_F3;
      DIK_F4           : result := VK_F4;
      DIK_F5           : result := VK_F5;
      DIK_F6           : result := VK_F6;
      DIK_F7           : result := VK_F7;
      DIK_F8           : result := VK_F8;
      DIK_F9           : result := VK_F9;
      DIK_F10          : result := VK_F10;
      DIK_NUMLOCK      : result := VK_NUMLOCK;
      DIK_SCROLL       : result := VK_SCROLL;
      DIK_NUMPAD7      : result := VK_NUMPAD7;
      DIK_NUMPAD8      : result := VK_NUMPAD8;
      DIK_NUMPAD9      : result := VK_NUMPAD9;
      DIK_SUBTRACT     : result := VK_SUBTRACT;
      DIK_NUMPAD4      : result := VK_NUMPAD4;
      DIK_NUMPAD5      : result := VK_NUMPAD5;
      DIK_NUMPAD6      : result := VK_NUMPAD6;
      DIK_ADD          : result := VK_ADD;
      DIK_NUMPAD1      : result := VK_NUMPAD1;
      DIK_NUMPAD2      : result := VK_NUMPAD2;
      DIK_NUMPAD3      : result := VK_NUMPAD3;
      DIK_NUMPAD0      : result := VK_NUMPAD0;
      DIK_DECIMAL      : result := VK_DECIMAL;
      DIK_F11          : result := VK_F11;
      DIK_F12          : result := VK_F12;
      DIK_NUMPADENTER  : result := VK_RETURN;
      DIK_RCONTROL     : result := VK_CONTROL;
      DIK_DIVIDE       : result := VK_DIVIDE;
      DIK_RMENU        : result := VK_MENU;
      DIK_HOME         : result := VK_HOME;
      DIK_UP           : result := VK_UP;
      DIK_PRIOR        : result := VK_PRIOR;
      DIK_LEFT         : result := VK_LEFT;
      DIK_RIGHT        : result := VK_RIGHT;
      DIK_END          : result := VK_END;
      DIK_DOWN         : result := VK_DOWN;
      DIK_NEXT         : result := VK_NEXT;
      DIK_INSERT       : result := VK_INSERT;
      DIK_DELETE       : result := VK_DELETE;
      DIK_LWIN         : result := VK_LWIN;
      DIK_RWIN         : result := VK_RWIN;
      DIK_APPS         : result := VK_APPS;
    end;
  end;

var
  i: integer;
  ev: event_t;
  key: integer;
  p: PKeyboardState;
begin
  if ignoretics > 0 then
  begin
    dec(ignoretics);
    exit;
  end;

// Keyboard
  if I_GameFinished or InBackground or
     IsIconic(hMainWnd) or (GetForegroundWindow <> hMainWnd) then
    exit;

  GetKeyboardState(curkeys^);

  ZeroMemory(@ev, SizeOf(ev));

  for i := 0 to SizeOf(curkeys^) - 1 do
  begin

    if (oldkeys[i] and $80) <> (curkeys[i] and $80) then
    begin
      key := TranslateKey(i);
      if key <> 0 then
      begin
        if curkeys[i] and $80 <> 0 then
          ev._type := ev_keydown
        else
          ev._type := ev_keyup;
        ev.data1 := key;
        D_PostEvent(@ev);
      end;

      key := TranslateSysKey(i);
      if key <> 0 then
      begin
        if curkeys[i] and $80 <> 0 then
          ev._type := ev_keydown
        else
          ev._type := ev_keyup;
        ev.data1 := key;
        D_PostEvent(@ev);
      end;
    end;

  end;

  p := oldkeys;
  oldkeys := curkeys;
  curkeys := p;

end;

//==============================================================================
//
// I_SynchronizeInput
//
//==============================================================================
procedure I_SynchronizeInput(active: boolean);
begin
  if active then
    ignoretics := I_IGRORETICKS; // Wait ~ half second when get the focus again
end;

end.

