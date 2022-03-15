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

unit gl_main;

interface

uses
  SysUtils,
  Windows,
  d_delphi;

//==============================================================================
//
// GL_InitGraphics
//
//==============================================================================
procedure GL_InitGraphics;

//==============================================================================
//
// GL_ChangeFullScreen
//
//==============================================================================
procedure GL_ChangeFullScreen(const full: boolean);

//==============================================================================
//
// I_ShutDownGraphics
//
//==============================================================================
procedure I_ShutDownGraphics;

//==============================================================================
// I_SetPalette
//
// Takes full 8 bit values.
//
//==============================================================================
procedure I_SetPalette(const palette: PByteArray);

//==============================================================================
//
// I_FinishUpdate
//
//==============================================================================
procedure I_FinishUpdate;

//==============================================================================
//
// I_ReadScreen32
//
//==============================================================================
procedure I_ReadScreen32(dest: pointer);

//==============================================================================
//
// I_RestoreWindowPos
//
//==============================================================================
procedure I_RestoreWindowPos;

var
  fixstallhack: boolean = true;

var
  h_DC: HDC;    // Global device context
  h_RC: HGLRC;  // OpenGL rendering context
  hMainWnd: HWND;
var
  gl_initialized: boolean = false;

implementation

uses
  Messages,
  doomdef,
  d_main,
  g_game,
  p_tick,
  i_input,
  i_system,
  m_menu,
  dglOpenGL,
  gl_render, // JVAL OPENGL
  gl_tex,
  gl_defs,
  v_data,
  v_video,
  d_player;

var
  s_alttab_disabled: boolean = false;

var
  screen: PLongWordArray;
  oscreen: pointer;

//==============================================================================
//
// I_RestoreWindowPos
//
//==============================================================================
procedure I_RestoreWindowPos;
begin
  SetWindowPos(hMainWnd, HWND_TOP, 0, 0, SCREENWIDTH, SCREENHEIGHT, SWP_SHOWWINDOW);
end;

//==============================================================================
//
// I_DisableAltTab
//
//==============================================================================
procedure I_DisableAltTab;
var
  old: Boolean;
begin
  if s_alttab_disabled then
    Exit;

  if Win32Platform = VER_PLATFORM_WIN32_NT then
  begin
    if isLibrary then
      RegisterHotKey(0, $C000, MOD_ALT, VK_TAB)
    else
      RegisterHotKey(0, 0, MOD_ALT, VK_TAB)
  end
  else
    SystemParametersInfo(SPI_SCREENSAVERRUNNING, 1, @old, 0);

  s_alttab_disabled := true;
end;

//==============================================================================
//
// I_EnableAltTab
//
//==============================================================================
procedure I_EnableAltTab;
var
  old: Boolean;
begin
  if s_alttab_disabled then
  begin
    if Win32Platform = VER_PLATFORM_WIN32_NT then
    begin
      if isLibrary then
        UnregisterHotKey(0, $C000)
      else
        UnregisterHotKey(0, 0)
    end
    else
      SystemParametersInfo(SPI_SCREENSAVERRUNNING, 0, @old, 0);

    s_alttab_disabled := false;
  end;
end;

var
  allocscreensize: integer;

{---------------------------------------------------------------------}
{  Properly destroys the window created at startup (no memory leaks)  }
{---------------------------------------------------------------------}

//==============================================================================
//
// glKillWnd
//
//==============================================================================
procedure glKillWnd;
begin
  if fullscreen then             // Change back to non fullscreen
    ChangeDisplaySettings(devmode(nil^), 0);

  if gl_initialized then
  begin
    // Makes current rendering context not current, and releases the device
    // context that is used by the rendering context.
    if (not wglMakeCurrent(h_DC, 0)) then
      I_Warning('glKillWnd(): Release of DC and RC failed!'#13#10);

    // Attempts to delete the rendering context
    if (not wglDeleteContext(h_RC)) then
    begin
      I_Warning('glKillWnd(): Release of rendering context failed!'#13#10);
      h_RC := 0;
    end;
  end;

  // Attemps to release the device context
  if ((h_DC > 0) and (ReleaseDC(hMainWnd, h_DC) = 0)) then
  begin
    I_Warning('glKillWnd(): Release of device context failed!'#13#10);
    h_DC := 0;
  end;

end;

//==============================================================================
//
// I_ShutDownGraphics
//
//==============================================================================
procedure I_ShutDownGraphics;
begin
  gld_ShutDownTextures;
  glKillWnd;
  I_EnableAltTab;
  memfree(oscreen, allocscreensize);
end;

//==============================================================================
//
// glEnable2D
//
//==============================================================================
procedure glEnable2D;
var
  vPort: array[0..3] of GLInt;
begin
   glGetIntegerv(GL_VIEWPORT, @vPort);

   glMatrixMode(GL_PROJECTION);
   glPushMatrix();
   glLoadIdentity();

   glOrtho(0, vPort[2], 0, vPort[3], -1, 1);
   glMatrixMode(GL_MODELVIEW);
   glPushMatrix();
   glLoadIdentity();
end;

//==============================================================================
//
// glDisable2D
//
//==============================================================================
procedure glDisable2D;
begin
   glMatrixMode(GL_PROJECTION);
   glPopMatrix();
   glMatrixMode(GL_MODELVIEW);
   glPopMatrix();
end;

var
  overlay_tex: glUint = 0;
  set_hud: boolean;

{$IFDEF OPENGLSAFETRANSLATE}
var
  translation_array: array[0..GLDRAWTEXHEIGHT - 1, 0..GLDRAWTEXWIDTH - 1] of LongWord;

//==============================================================================
//
// GL_SafeTranslate
//
//==============================================================================
procedure GL_SafeTranslate;
var
  i, j, k: integer;
begin
  k := 0;
  for i := 0 to GLDRAWHEIGHT - 1 do
    for j := 0 to GLDRAWWIDTH - 1 do
    begin
      translation_array[i, j] := screen32[k];
      inc(k);
    end;
end;
{$ENDIF}

var
  overlay_created: boolean = false;
//  sub_y2: integer;
  did_fullhu: integer = 10;
  last_y1: integer = GLDRAWTEXHEIGHT;
  health1, health2, ammo1, ammo2: GLuint;
  uitexloaded: Boolean = false;

//==============================================================================
//
// I_FinishUpdate
//
//==============================================================================
procedure I_FinishUpdate;
var
  h, a: integer;
begin
  if (hMainWnd = 0) or (screens[SCN_FG] = nil) or (screen32 = nil) then
    exit;

  glPushAttrib(GL_ALL_ATTRIB_BITS);
  gld_Enable2D;

  glColor4f(1.0, 1.0, 1.0, 1.0);
  glEnable(GL_ALPHA_TEST);
  glAlphaFunc(GL_NOTEQUAL, 0);

  if (gamestate <> GS_LEVEL) or menuactive then
  begin
    glBindTexture(GL_TEXTURE_2D, overlay_tex);
    glTexImage2D(GL_TEXTURE_2D, 0, 4, GLDRAWTEXWIDTH, GLDRAWTEXHEIGHT, 0, GL_BGRA, GL_UNSIGNED_BYTE, screen32);
    glBegin(GL_QUADS);
      glTexCoord2f(0.0, GLDRAWHEIGHT / GLDRAWTEXHEIGHT);
      glVertex2f(0, 0);
      glTexCoord2f(GLDRAWWIDTH / GLDRAWTEXWIDTH, GLDRAWHEIGHT / GLDRAWTEXHEIGHT);
      glVertex2f(SCREENWIDTH, 0);
      glTexCoord2f(GLDRAWWIDTH / GLDRAWTEXWIDTH, 0.0);
      glVertex2f(SCREENWIDTH, SCREENHEIGHT);
      glTexCoord2f(0.0, 0.0);
      glVertex2f(0, SCREENHEIGHT);
    glEnd;
  end;

  if gamestate = GS_LEVEL then
  begin
    if not uitexloaded then
    begin
      health1 := gld_LoadExternalTexture('health1.material', true, GL_CLAMP);
      health2 := gld_LoadExternalTexture('health2.material', true, GL_CLAMP);
      ammo1 := gld_LoadExternalTexture('ammo1.material', true, GL_CLAMP);
      ammo2 := gld_LoadExternalTexture('ammo2.material', true, GL_CLAMP);
      uitexloaded := True;
    end;

    if SCREENWIDTH >= 800 then
    begin
      h := players[displayplayer].health * 2;
      a := players[displayplayer].ammo[Ord(am_cell)] * 2;
    end
    else
    begin
      h := Round(players[displayplayer].health * 1.4);
      a := Round(players[displayplayer].ammo[Ord(am_cell)] * 1.4);
    end;

    glBindTexture(GL_TEXTURE_2D, health1);
    glBegin(GL_QUADS);
      glTexCoord2f(0.0, 1.0);
      glVertex2i(10, 32);
      glTexCoord2f(1.0, 1.0);
      glVertex2i(138, 32);
      glTexCoord2f(1.0, 0.0);
      glVertex2i(138, 64);
      glTexCoord2f(0.0, 0.0);
      glVertex2i(10, 64);
    glEnd;

    if (h < 50) and ((leveltime div 20) and 1 = 0) then
    else
    begin
      glBindTexture(GL_TEXTURE_2D, health2);
      glBegin(GL_QUADS);
        glTexCoord2f(0.0, 1.0);
        glVertex2i(140, 32);
        glTexCoord2f(1.0, 1.0);
        glVertex2i(140 + h, 32);
        glTexCoord2f(1.0, 0.0);
        glVertex2i(140 + h, 64);
        glTexCoord2f(0.0, 0.0);
        glVertex2i(140, 64);
      glEnd;
    end;

    glBindTexture(GL_TEXTURE_2D, ammo1);
    glBegin(GL_QUADS);
      glTexCoord2f(0.0, 1.0);
      glVertex2i(10, 1);
      glTexCoord2f(1.0, 1.0);
      glVertex2i(138, 1);
      glTexCoord2f(1.0, 0.0);
      glVertex2i(138, 32);
      glTexCoord2f(0.0, 0.0);
      glVertex2i(10, 32);
    glEnd;

    glBindTexture(GL_TEXTURE_2D, ammo2);
    glBegin(GL_QUADS);
      glTexCoord2f(0.0, 1.0);
      glVertex2i(140, 1);
      glTexCoord2f(1.0, 1.0);
      glVertex2i(140 + a, 1);
      glTexCoord2f(1.0, 0.0);
      glVertex2i(140 + a, 32);
      glTexCoord2f(0.0, 0.0);
      glVertex2i(140, 32);
    glEnd;

    glDisable(GL_BLEND);
  end;

  gld_Disable2D;
  glPopAttrib;
  gld_Finish;
end;

//==============================================================================
//
// Palette stuff.
//
// I_SetPalette
//
//==============================================================================
procedure I_SetPalette(const palette: PByteArray);
var
  dest: PLongWord;
  src: PByteArray;
  limit: integer;
  curgamma: PByteArray;
begin
  dest := @curpal[0];
  src := palette;
  curgamma := @gammatable[usegamma];
  limit := integer(@palette[256 * 3]);
  while integer(src) < limit do
  begin
    dest^ := (LongWord(curgamma[src[0]]) shl 16) or
             (LongWord(curgamma[src[1]]) shl 8) or
             (LongWord(curgamma[src[2]]));
    inc(dest);
    src := PByteArray(integer(src) + 3);
  end;
end;

//==============================================================================
//
// I_AdjustWindowMode
//
//==============================================================================
function I_AdjustWindowMode: boolean;
begin
  result := false;
  if SCREENWIDTH > GetSystemMetrics(SM_CXSCREEN) then
  begin
    SCREENWIDTH := GetSystemMetrics(SM_CXSCREEN);
    result := true;
  end;
  if SCREENHEIGHT > GetSystemMetrics(SM_CYSCREEN) then
  begin
    SCREENHEIGHT := GetSystemMetrics(SM_CYSCREEN);
    result := true;
  end;
end;

const
  ERROR_OFFSET = 20;

{------------------------------------------------------------------}
{  Handle window resize                                            }
{------------------------------------------------------------------}

//==============================================================================
//
// glResizeWnd
//
//==============================================================================
procedure glResizeWnd;
begin
  glViewport(0, 0, SCREENWIDTH, SCREENHEIGHT);    // Set the viewport for the OpenGL window
  glMatrixMode(GL_PROJECTION);        // Change Matrix Mode to Projection
  glLoadIdentity;                     // Reset View
  gluPerspective(45.0, SCREENWIDTH / SCREENHEIGHT, 1.0, 100.0);  // Do the perspective calculations. Last value = max clipping depth

  glMatrixMode(GL_MODELVIEW);         // Return to the modelview matrix
  glLoadIdentity;                     // Reset View
end;

{------------------------------------------------------------------}
{  Initialise OpenGL                                               }
{------------------------------------------------------------------}

//==============================================================================
//
// glInit
//
//==============================================================================
procedure glInit;
begin
  glClearColor(0.0, 0.0, 0.0, 0.0); 	     // Black Background
  glShadeModel(GL_SMOOTH);                 // Enables Smooth Color Shading
  glClearDepth(1.0);                       // Depth Buffer Setup
  glEnable(GL_DEPTH_TEST);                 // Enable Depth Buffer
  glDepthFunc(GL_LESS);		                 // The Type Of Depth Test To Do
  glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);   //Realy Nice perspective calculations
  glEnable(GL_TEXTURE_2D);                     // Enable Texture Mapping
end;

//==============================================================================
//
// WindowProc
//
//==============================================================================
function WindowProc(hWnd: HWND; Msg: UINT; wParam: WPARAM;
  lParam: LPARAM): LRESULT; stdcall; export;
begin
  if not I_GameFinished then
  begin
    case Msg of
      WM_SETCURSOR:
        begin
          SetCursor(0);
        end;
      WM_SYSCOMMAND:
        begin
          if (wParam = SC_SCREENSAVE) or (wParam = SC_MINIMIZE) then
          begin
            result := 0;
            exit;
          end;
          if fullscreen and (wParam = SC_TASKLIST) then
          begin
            result := 0;
            exit;
          end;
        end;
      WM_SIZE:
        begin
//          glResizeWnd;
          result := 0;
          exit;
        end;
      WM_ACTIVATE:
        begin
          InBackground := (LOWORD(wparam) = WA_INACTIVE) or (HIWORD(wparam) <> 0);
          I_SynchronizeInput(not InBackground);
        end;
      WM_CLOSE:
        begin
          result := 0; // Preserve closing window by pressing Alt + F4
          exit;
        end;
      WM_DESTROY:
        begin
          result := 0;
          I_Destroy(0);
          exit;
        end;
    end;
  end;

  result := DefWindowProc(hWnd, Msg, WParam, LParam);
end;

//==============================================================================
//
// GL_InitGraphics
//
//==============================================================================
procedure GL_InitGraphics;
var
  WindowClass: TWndClass;
  dwStyle : DWORD;              // Window styles
  dwExStyle : DWORD;            // Extended window styles
  dmScreenSettings : DEVMODE;   // Screen settings (fullscreen, etc...)
  PixelFormat : GLuint;         // Settings for the OpenGL rendering
  h_Instance : HINST;           // Current instance
  pfd : TPIXELFORMATDESCRIPTOR;  // Settings for the OpenGL window
begin
  InitOpenGL;                               // New call to initialize and bind the OpenGL dll
  gl_initialized := true;

  h_Instance := GetModuleHandle(nil);       //Grab An Instance For Our Window
  ZeroMemory(@WindowClass, SizeOf(TWndClass));  // Clear the window class structure

  with WindowClass do                    // Set up the window class
  begin
    style         := CS_HREDRAW or    // Redraws entire window if length changes
                     CS_VREDRAW or    // Redraws entire window if height changes
                     CS_OWNDC;        // Unique device context for the window
    lpfnWndProc   := @WindowProc;        // Set the window procedure to our func WndProc
    hInstance     := h_Instance;
    hCursor       := LoadCursor(0, IDC_ARROW);
    lpszClassName := 'Dragon';
    hIcon := LoadIcon(HInstance, 'MAINICON');
  end;

  if (RegisterClass(WindowClass) = 0) then  // Attemp to register the window class
  begin
    I_Error('I_InitGraphics(): Failed to register the window class!');
    exit;
  end;

  // Change to fullscreen if so desired
  if fullscreen then
  begin
    ZeroMemory(@dmScreenSettings, SizeOf(dmScreenSettings));
    with dmScreenSettings do begin              // Set parameters for the screen setting
      dmSize       := SizeOf(dmScreenSettings);
      dmPelsWidth  := SCREENWIDTH;                    // Window width
      dmPelsHeight := SCREENHEIGHT;                   // Window height
      dmBitsPerPel := 32;               // Window color depth
      dmFields     := DM_PELSWIDTH or DM_PELSHEIGHT or DM_BITSPERPEL;
    end;

    // Try to change screen mode to fullscreen
    if ChangeDisplaySettings(dmScreenSettings, CDS_FULLSCREEN) = DISP_CHANGE_FAILED then
    begin
      I_Error('I_InitGraphics(): Unable to switch to fullscreen!');
      fullscreen := False;
    end;
  end;

  dwStyle := WS_POPUP or        // Creates a popup window
             WS_CLIPCHILDREN or // Doesn't draw within child windows
             WS_CLIPSIBLINGS;   // Doesn't draw within sibling windows
  dwExStyle := WS_EX_APPWINDOW;         // Top level window
  ShowCursor(False);                    // Turn of the cursor (gets in the way)

  // Attempt to create the actual window
  hMainWnd := CreateWindowEx(dwExStyle,      // Extended window styles
                          WindowClass.lpszClassName,
                          AppTitle,
                          dwStyle,        // Window styles
                          0, 0,           // Window position
                          SCREENWIDTH,
                          SCREENHEIGHT,
                          0,              // No parent window
                          0,              // No menu
                          h_Instance,     // Instance
                          nil);           // Pass nothing to WM_CREATE

  if hMainWnd = 0 then
  begin
    glKillWnd;                // Undo all the settings we've changed
    I_Error('I_InitGraphics(): Unable to create window!');
    Exit;
  end;

  // Try to get a device context
  h_DC := GetDC(hMainWnd);
  if (h_DC = 0) then
  begin
    glKillWnd;
    I_Error('I_InitGraphics(): Unable to get a device context!');
    exit;
  end;

  // Settings for the OpenGL window
  with pfd do
  begin
    nSize           := SizeOf(TPIXELFORMATDESCRIPTOR); // Size Of This Pixel Format Descriptor
    nVersion        := 1;                    // The version of this data structure
    dwFlags         := PFD_DRAW_TO_WINDOW    // Buffer supports drawing to window
                       or PFD_SUPPORT_OPENGL // Buffer supports OpenGL drawing
                       or PFD_DOUBLEBUFFER;  // Supports double buffering
    iPixelType      := PFD_TYPE_RGBA;        // RGBA color format
    cColorBits      := 32;                   // OpenGL color depth
    cRedBits        := 0;                    // Number of red bitplanes
    cRedShift       := 0;                    // Shift count for red bitplanes
    cGreenBits      := 0;                    // Number of green bitplanes
    cGreenShift     := 0;                    // Shift count for green bitplanes
    cBlueBits       := 0;                    // Number of blue bitplanes
    cBlueShift      := 0;                    // Shift count for blue bitplanes
    cAlphaBits      := 0;                    // Not supported
    cAlphaShift     := 0;                    // Not supported
    cAccumBits      := 0;                    // No accumulation buffer
    cAccumRedBits   := 0;                    // Number of red bits in a-buffer
    cAccumGreenBits := 0;                    // Number of green bits in a-buffer
    cAccumBlueBits  := 0;                    // Number of blue bits in a-buffer
    cAccumAlphaBits := 0;                    // Number of alpha bits in a-buffer
    cDepthBits      := 16;                   // Specifies the depth of the depth buffer
    cStencilBits    := 0;                    // Turn off stencil buffer
    cAuxBuffers     := 0;                    // Not supported
    iLayerType      := PFD_MAIN_PLANE;       // Ignored
    bReserved       := 0;                    // Number of overlay and underlay planes
    dwLayerMask     := 0;                    // Ignored
    dwVisibleMask   := 0;                    // Transparent color of underlay plane
    dwDamageMask    := 0;                     // Ignored
  end;

  // Attempts to find the pixel format supported by a device context that is the best match to a given pixel format specification.
  PixelFormat := ChoosePixelFormat(h_DC, @pfd);
  if PixelFormat = 0 then
  begin
    glKillWnd;
    I_Error('I_InitGraphics(): Unable to find a suitable pixel format');
    exit;
  end;

  // Sets the specified device context's pixel format to the format specified by the PixelFormat.
  if not SetPixelFormat(h_DC, PixelFormat, @pfd) then
  begin
    glKillWnd;
    I_Error('I_InitGraphics(): Unable to set the pixel format');
    exit;
  end;

  // Create a OpenGL rendering context
  h_RC := wglCreateContext(h_DC);
  if h_RC = 0 then
  begin
    glKillWnd;
    I_Error('I_InitGraphics(): Unable to create an OpenGL rendering context');
    exit;
  end;

  // Makes the specified OpenGL rendering context the calling thread's current rendering context
  if not wglMakeCurrent(h_DC, h_RC) then
  begin
    glKillWnd;
    I_Error('I_InitGraphics(): Unable to activate OpenGL rendering context');
    exit;
  end;
  // Read And Assign Extentions
  ReadExtensions;
  ReadImplementationProperties;

  // Settings to ensure that the window is the topmost window
  ShowWindow(hMainWnd, SW_SHOW);
  SetForegroundWindow(hMainWnd);
  SetFocus(hMainWnd);

  // Ensure the OpenGL window is resized properly
  glResizeWnd;
  glInit;

  gld_Init(SCREENWIDTH, SCREENHEIGHT);

  allocscreensize := 2048 * (1536 + ERROR_OFFSET) * SizeOf(LongWord) and not (4095);
  screen := mallocA(allocscreensize, $10000, oscreen); // JVAL: Memory padding may increase performance until 4%
  screen32 := screen;

  glGenTextures(1, @overlay_tex);
  glBindTexture(GL_TEXTURE_2D, overlay_tex);
  glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);  {Texture blends with object background}
  if gl_linear_hud then
  begin
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  end
  else
  begin
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  end;
  set_hud := gl_linear_hud;

  glTexImage2D(GL_TEXTURE_2D, 0, 4, GLDRAWTEXWIDTH, GLDRAWTEXHEIGHT, 0, GL_BGRA, GL_UNSIGNED_BYTE, screen32);

end;

const
  NUNSTDRESOLUTIONS = 8;
  STANDARDSCREENRESOLUTIONS: array[0..NUNSTDRESOLUTIONS - 1, 0..1] of integer = (
    (1280, 1024), (1280, 800), (1024, 768), (800, 600), (640, 480), (512, 384), (400, 300), (320, 200)
  );

//==============================================================================
//
// GL_ChangeFullScreen
//
//==============================================================================
procedure GL_ChangeFullScreen(const full: boolean);
var
  dmScreenSettings : DEVMODE;   // Screen settings (fullscreen, etc...)
begin
  I_RestoreWindowPos;
  fullscreen := full;
  // Change to fullscreen if so desired
  if fullscreen then
  begin
    ZeroMemory(@dmScreenSettings, SizeOf(dmScreenSettings));
    with dmScreenSettings do
    begin              // Set parameters for the screen setting
      dmSize       := SizeOf(dmScreenSettings);
      dmPelsWidth  := SCREENWIDTH;                    // Window width
      dmPelsHeight := SCREENHEIGHT;                   // Window height
      dmBitsPerPel := 32;                             // Window color depth
      dmFields     := DM_PELSWIDTH or DM_PELSHEIGHT or DM_BITSPERPEL;
    end;

    // Try to change screen mode to fullscreen
    if ChangeDisplaySettings(dmScreenSettings, CDS_FULLSCREEN) = DISP_CHANGE_FAILED then
      I_Warning('I_ChangeFullScreen(): Can not change to fullscreen mode'#13#10)
  end
  else
    ChangeDisplaySettings(devmode(nil^), 0);
end;

//==============================================================================
//
// I_ReadScreen32
//
//==============================================================================
procedure I_ReadScreen32(dest: pointer);
begin
    glReadPixels(0, 0, SCREENWIDTH, SCREENHEIGHT, GL_BGRA, GL_UNSIGNED_BYTE, dest);
end;

end.
