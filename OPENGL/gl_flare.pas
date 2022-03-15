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

unit gl_flare;

interface

uses
  d_delphi;

//==============================================================================
//
// gld_SetSun
//
//==============================================================================
procedure gld_SetSun(const x, y, z: float);

//==============================================================================
//
// gld_DrawSun
//
//==============================================================================
procedure gld_DrawSun;

//==============================================================================
//
// gld_CalculateSun
//
//==============================================================================
procedure gld_CalculateSun;

//==============================================================================
//
// gld_ResetSun
//
//==============================================================================
procedure gld_ResetSun;

//==============================================================================
//
// gld_EnableSunLight
//
//==============================================================================
procedure gld_EnableSunLight;

//==============================================================================
//
// gld_DisableSunLight
//
//==============================================================================
procedure gld_DisableSunLight;

implementation

uses
  doomdef,
  gl_tex,
  gl_defs,
  p_tick,
  r_main,
  dglOpenGL;

const
  SUNTICKS = TICRATE div 4;

var
 gl_sun: array[0..3] of float;
 timesunstops: integer;

//==============================================================================
//
// gld_SetSun
//
//==============================================================================
procedure gld_SetSun(const x, y, z: float);
begin
  gl_sun[0] := x;
  gl_sun[1] := y;
  gl_sun[2] := z;
  gl_sun[3] := 1.0;
end;

//==============================================================================
//
// gld_ResetSun
//
//==============================================================================
procedure gld_ResetSun;
begin
  timesunstops := -1;
end;

//==============================================================================
//
// gld_GetSunFlarePos
//
//==============================================================================
function gld_GetSunFlarePos(var sx, sy, sz: glDouble): boolean;
var
  modelMatrix: TGLMatrixd4; // The model matrix.
  projMatrix: TGLMatrixd4;  // The projection matrix.
  viewport: TVector4i;      // The viewport.
  Depth: glFloat;
begin
  glGetDoublev(GL_MODELVIEW_MATRIX, @modelMatrix); // Load the matricies and viewport.
  glGetDoublev(GL_PROJECTION_MATRIX, @projMatrix);
  glGetIntegerv(GL_VIEWPORT, @viewport);

  gluProject(gl_sun[0], gl_sun[1], gl_sun[2], modelMatrix, projMatrix, viewport, @sx, @sy, @sz); // Find out where the light is on the screen.

  if (sx < viewport[2]) and (sx >= 0) and
     (sy < viewport[3]) and (sy >= 0)  then
  begin
    glReadPixels(round(sx), round(sy), 1, 1, GL_DEPTH_COMPONENT, GL_FLOAT, @depth);
    if depth < sz then // but it is behind something.
      result := False   // The light can't be seen.
    else
      result := true;
  end
  else // If the light isn't on the screen
    result := False; // The light can't be seen.

end;

//==============================================================================
//
// gld_DrawFlareQuad
//
//==============================================================================
procedure gld_DrawFlareQuad(x, y, size: glFloat);
begin
  glbegin(GL_QUADS);
    glTexCoord2f(0,0); glVertex2f(x - size, y - size);
    glTexCoord2f(1,0); glVertex2f(x + size, y - size);
    glTexCoord2f(1,1); glVertex2f(x + size, y + size);
    glTexCoord2f(0,1); glVertex2f(x - size, y + size);
  glend;
end;

var
  FlareTex: array[0..8] of GLUint;
  Flarecol: gldouble = 0.0;
  flareloaded: boolean = false;
  sunvisible: boolean;
  sx, sy, sz: glDouble;

//==============================================================================
//
// gld_CalculateSun
//
//==============================================================================
procedure gld_CalculateSun;
begin
  dec(timesunstops);

  sunvisible := gld_GetSunFlarePos(Sx, Sy, Sz);

  if sunvisible then
    timesunstops := leveltime + SUNTICKS;

  if timesunstops < leveltime then
    sunvisible := false;

end;

//==============================================================================
//
// DrawQuad
//
//==============================================================================
procedure DrawQuad(Size: glFloat);
begin
  glbegin(GL_QUADS);
    glTexCoord2f(0, 0); glVertex3f(-size,-size, 0);
    glTexCoord2f(1, 0); glVertex3f( size,-size, 0);
    glTexCoord2f(1, 1); glVertex3f( size, size, 0);
    glTexCoord2f(0, 1); glVertex3f(-size, size, 0);
  glend;
end;

//==============================================================================
//
// gld_DrawSun
//
//==============================================================================
procedure gld_DrawSun;
var
  flx, fly: glFloat;
  hw, hh: glDouble;
  FlareSize: glDouble;
  i: integer;
begin
  if timesunstops < leveltime then
    exit;

  if viewx > 0 then
    exit;

  if not flareloaded then
  begin
    for i := 0 to 8 do
      FlareTex[i] := gld_LoadExternalTexture('Flare' + itoa(i) + '.png', true, GL_CLAMP);
    flareloaded := true;
  end;

  hw := SCREENWIDTH / 2;
  hh := SCREENHEIGHT / 2;
  FlareSize := hw / 5;
  Flarecol := (timesunstops - leveltime) / SUNTICKS * 0.75;

  flx := Sx - hw;
  fly := Sy - hh;

  glDisable(GL_DEPTH_TEST);
  glDisable(GL_CULL_FACE);
  glEnable(GL_BLEND);
  glBlendFunc(GL_ONE, GL_ONE);

  glcolor3f(FlareCol, FlareCol, FlareCol);

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glViewport(0, 0, SCREENWIDTH, SCREENHEIGHT);
  glOrtho(0, SCREENWIDTH, 0, SCREENHEIGHT, 0.01, 1000);

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;

  glPushMatrix;
    glTranslatef(hw + flx, hh + fly, -5);
    glRotatef(Sx / hw * 90, 0, 0, 1);
    glBindTexture(GL_TEXTURE_2D, FlareTex[0]);
    DrawQuad(FlareSize);
  glPopMatrix;

  glPushMatrix;
    glTranslatef(hw + flx, hh + fly, -5);
    glBindTexture(GL_TEXTURE_2D, FlareTex[1]);
    DrawQuad(FlareSize * 1.1);
  glPopMatrix;

  glColor3f(FlareCol - 0.1,FlareCol - 0.1,FlareCol - 0.1);

  glPushMatrix;
    glTranslatef(hw - flx, hh - fly, -5);
    glBindTexture(GL_TEXTURE_2D, FlareTex[2]);
    DrawQuad(FlareSize * 0.8);
  glPopMatrix;

  glPushMatrix;
    glTranslatef(hw - flx * 0.9, hh - fly * 0.9, -5);
    glBindTexture(GL_TEXTURE_2D, FlareTex[3]);
    DrawQuad(FlareSize * 0.4);
  glPopMatrix;

  glPushMatrix;
    glTranslatef(hw + flx * 1.5, hh + fly * 1.5, -5);
    glBindTexture(GL_TEXTURE_2D, FlareTex[8]);
    DrawQuad(FlareSize * 0.3);
  glPopMatrix;

  glPushMatrix;
    glTranslatef(hw - flx * 0.65, hh - fly * 0.65, -5);
    glBindTexture(GL_TEXTURE_2D, FlareTex[7]);
    DrawQuad(FlareSize * 0.2);
  glPopMatrix;

  glPushMatrix;
    glTranslatef(hw - flx * 0.35, hh - fly * 0.35, -5);
    glBindTexture(GL_TEXTURE_2D, FlareTex[6]);
    DrawQuad(FlareSize * 0.15);
  glPopMatrix;

  glPushMatrix;
    glTranslatef(hw - flx * 0.1, hh - fly * 0.1, -5);
    glBindTexture(GL_TEXTURE_2D, FlareTex[4]);
    DrawQuad(FlareSize * 0.05);
  glPopMatrix;

  glPushMatrix;
    glTranslatef(hw - flx * 0.3, hh - fly * 0.3, -5);
    glBindTexture(GL_TEXTURE_2D, FlareTex[5]);
    DrawQuad(FlareSize * 0.3);
    glPopMatrix;

  glPushMatrix;
    glTranslatef(hw + flx * 0.5, hh + fly * 0.5, -5);
    glBindTexture(GL_TEXTURE_2D, FlareTex[7]);
    DrawQuad(FlareSize * 0.2);
  glPopMatrix;

  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

end;

//==============================================================================
//
// gld_EnableSunLight
//
//==============================================================================
procedure gld_EnableSunLight;
var
  lightcolor: array[0..3] of float;
  pos2: array[0..3] of float;
begin
  glLightfv (GL_LIGHT0, GL_POSITION, @gl_sun);

  lightcolor[0] := 0.7;
  lightcolor[1] := 0.7;
  lightcolor[2] := 0.7;
  lightcolor[3] := 1.0;

	glLightfv (GL_LIGHT0, GL_DIFFUSE, @lightcolor);

  glEnable(GL_LIGHTING);
	glEnable(GL_LIGHT0);

  pos2[0] := camera.position[0];
  pos2[1] := camera.position[1];
  pos2[2] := camera.position[2];
  pos2[3] := 1.0;

  glLightfv (GL_LIGHT1, GL_POSITION, @pos2);

  pos2[0] := -camera.rotation[0];
  pos2[1] := -camera.rotation[1];
  pos2[2] := -camera.rotation[2];

  glLightfv(GL_LIGHT1, GL_SPOT_DIRECTION, @pos2);
  glLightf(GL_LIGHT1, GL_SPOT_EXPONENT, 0.5);
  glLightf(GL_LIGHT1, GL_SPOT_CUTOFF, 180);

  lightcolor[0] := 1.0;
  lightcolor[1] := 1.0;
  lightcolor[2] := 1.0;
  lightcolor[3] := 1.0;

	glLightfv(GL_LIGHT1, GL_DIFFUSE, @lightcolor);

  glEnable(GL_LIGHTING);
	glEnable(GL_LIGHT1);
end;

//==============================================================================
//
// gld_DisableSunLight
//
//==============================================================================
procedure gld_DisableSunLight;
begin
  glDisable(GL_LIGHTING);
	glDisable(GL_LIGHT0);
	glDisable(GL_LIGHT1);
end;

end.
