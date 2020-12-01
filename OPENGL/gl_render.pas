//------------------------------------------------------------------------------
//
//  DelphiDoom: A modified and improved DOOM engine for Windows
//  based on original Linux Doom as published by "id Software"
//  Copyright (C) 2004-2011 by Jim Valavanis
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
//  E-Mail: jimmyvalavanis@yahoo.gr
//  Site  : http://delphidoom.sitesled.com/
//------------------------------------------------------------------------------

{$I Doom32.inc}

unit gl_render;

interface

uses
  Windows,
  d_delphi,
  dglOpenGL,
  d_player,
  p_mobj_h,
  gl_defs,
  r_defs,
  m_fixed;

var
  extra_red: float = 0.0;
  extra_green: float = 0.0;
  extra_blue: float = 0.0;
  extra_alpha: float = 0.0;

procedure gld_DrawBackground(const name: string);

procedure gld_Finish;

procedure gld_AddSprite(vspr: Pvissprite_t);

procedure gld_AddSun(sun: Pmobj_t);

procedure gld_AddWall(seg: Pseg_t);

procedure gld_StartDrawScene;

procedure gld_DrawScene(player: Pplayer_t);

procedure gld_EndDrawScene;

function gld_AddPlane(subsectornum: integer; floor, ceiling: Pvisplane_t): boolean;

procedure gld_PreprocessLevel;

procedure gld_DrawWeapon(weaponlump: integer; vis: Pvissprite_t; lightlevel: integer);

procedure gld_Init(width, height: integer);

procedure gld_SetPalette(palette: integer);

procedure gld_DrawNumPatch(x, y: integer; lump: integer; cm: integer; flags: integer);

procedure gld_Enable2D;

procedure gld_Disable2D;

procedure gld_StaticLight(light: float);

procedure gld_CleanMemory;

procedure R_ShutDownOpenGL;

procedure gld_ResetSmooth;

implementation

uses
  doomstat,
  i_system,
  tables,
  doomtype,
  doomdef,
  doomdata,
  info_h,
  g_game,
  v_video,
  v_data,
  m_stack,
  info,
  sc_states,
  gl_main,
  gl_misc,
  gl_tex,
  gl_sky,
  gl_lights,
  gl_types,
  gl_dlights,
  gl_models,
  gl_data,
  gl_frustum,
  gl_terrain,
  gl_lightmaps,
  gl_flare,
  p_maputl,
  p_local,
  p_setup,
  p_pspr,
  p_tick,
  r_main,
  r_bsp,
  r_draw,
  r_data,
  r_sky,
  r_intrpl,
  r_things,
  r_lights,
  sc_engine,
  w_wad,
  z_zone, hu_stuff, d_net;

{$IFDEF DEBUG}
var
  rendered_visplanes,
  rendered_segs,
  rendered_vissprites: integer;
{$ENDIF}

{*
 * lookuptable for lightvalues
 * calculated as follow:
 * floatlight=(gammatable(usegamma, lighttable) + (1.0-exp((light^3)*gamma)) / (1.0-exp(1.0*gamma))) / 2;
 * gamma=-0,2;-2,0;-4,0;-6,0;-8,0
 * usegamme=0;1;2;3;4
 * light=0,0 .. 1,0
 *}

var
  gl_lighttable: array[0..GAMMASIZE - 1, 0..255] of float;

function gld_CalcLightLevel(lightlevel: integer): float;
begin
  result := gl_lighttable[usegamma][gl_i_max(gl_i_min((lightlevel), 255), 0)];
end;


procedure gld_StaticLightAlpha(light: float; alpha: float);
begin
  if players[displayplayer].fixedcolormap <> 0 then
    glColor4f(1.0, 1.0, 1.0, alpha)
  else
    glColor4f(light, light, light, alpha);
end;

procedure gld_StaticLight(light: float);
begin
  if players[displayplayer].fixedcolormap <> 0 then
    glColor4f(1.0, 1.0, 1.0, 1.0)
  else
    glColor4f(light, light, light, 1.0);
end;

procedure gld_InitExtensions(ext_list: TDStringList);
begin
  gl_texture_filter_anisotropic := ext_list.IndexOf('GL_EXT_TEXTURE_FILTER_ANISOTROPIC') > -1;
  if gl_texture_filter_anisotropic then
    printf('enabled anisotropic texture filtering'#13#10);
  if gl_use_paletted_texture <> 0 then
  begin
    gl_paletted_texture := ext_list.IndexOf('GL_EXT_PALETTED_TEXTURE') > -1;
    gld_ColorTableEXT := lp3DFXFUNC(wglGetProcAddress('glColorTableEXT'));
   if not Assigned(gld_ColorTableEXT) then
  	  gl_paletted_texture := false
    else
      printf('using GL_EXT_paletted_texture'#13#10);
  end;
  if gl_use_shared_texture_palette <> 0 then
  begin
    gl_shared_texture_palette := ext_list.IndexOf('GL_EXT_SHARED_TEXTURE_PALETTE') > -1;
    gld_ColorTableEXT := lp3DFXFUNC(wglGetProcAddress('glColorTableEXT'));
    if not Assigned(gld_ColorTableEXT) then
      gl_shared_texture_palette := false
    else
      printf('using GL_EXT_shared_texture_palette'#13#10);
  end;

  canuselightmaps := ext_list.IndexOf('GL_ARB_MULTITEXTURE') > -1;
  if not canuselightmaps then
  begin
    I_Warning('gld_InitExtensions(): GL_ARB_MULTITEXTURE extension not supported, lightmap will be disabled'#13#10);
    canusemultitexture := false;
    gl_uselightmaps := false;
  end
  else
  begin
    canuselightmaps := ext_list.IndexOf('GL_EXT_TEXTURE3D') > -1;
    if not canuselightmaps then
    begin
      I_Warning('gld_InitExtensions(): GL_EXT_TEXTURE3D extension not supported, lightmap will be disabled'#13#10);
      gl_uselightmaps := false;
    end;
  end;
end;

{-------------------------------------------------------------------}
{ V-Sync
{ Ok for all system windows 32                                      }
{-------------------------------------------------------------------}
type
  TVSyncMode = (vsmSync, vsmNoSync);

procedure gld_VSync(vsync: TVSyncMode);
var
   i : Integer;
begin
   if WGL_EXT_swap_control then
   begin
      i := wglGetSwapIntervalEXT;
      case VSync of
         vsmSync    : if i<>1 then wglSwapIntervalEXT(1);
         vsmNoSync  : if i<>0 then wglSwapIntervalEXT(0);
      else
         Assert(False);
      end;
   end;

end;

procedure gld_InitLightTable;
var
  sc: TScriptEngine;
  lump: integer;
  i, j: integer;
begin
  lump := W_CheckNumForName('GLGAMMA');
  if lump < 0 then
    exit;

  sc := TScriptEngine.Create(W_TextLumpNum(lump));
  for i := 0 to GAMMASIZE - 1 do
    for j := 0 to 255 do
    begin
      sc.MustGetFloat;
      gl_lighttable[i, j] := sc._Float;
    end;
  sc.Free;
end;

var
  last_screensync: boolean;

procedure gld_Init(width, height: integer);
var
  params: array[0..3] of TGLfloat;
  BlackFogColor: array[0..3] of TGLfloat;
  ext_lst: TDStringList;
  i, tf_id: integer;
  extensions,
  extensions_l: string;
begin
  params[0] := 0.0;
  params[1] := 0.0;
  params[2] := 1.0;
  params[3] := 0.0;
  BlackFogColor[0] := 0.0;
  BlackFogColor[1] := 0.0;
  BlackFogColor[2] := 0.0;
  BlackFogColor[3] := 0.0;

  printf('GL_VENDOR: %s'#13#10 , [glGetString(GL_VENDOR)]);
  printf('GL_RENDERER: %s'#13#10, [glGetString(GL_RENDERER)]);
  printf('GL_VERSION: %s'#13#10, [glGetString(GL_VERSION)]);
  printf('GL_EXTENSIONS:'#13#10);

  extensions := StringVal(glGetString(GL_EXTENSIONS));
  extensions_l := '';
  for i := 1 to Length(extensions) do
  begin
    if extensions[i] = ' ' then
      extensions_l := extensions_l + #13#10
    else
      extensions_l := extensions_l + toupper(extensions[i]);
  end;

  ext_lst := TDStringList.Create;
  try
    ext_lst.Text := extensions_l;
    for i := 0 to ext_lst.count - 1 do
      printf('%s'#13#10, [ext_lst.strings[i]]);
    gld_InitExtensions(ext_lst);
  finally
    ext_lst.Free;
  end;

  gld_InitPalettedTextures;

  glViewport(0, 0, SCREENWIDTH, SCREENHEIGHT);

  {$IFDEF DEBUG}
  glClearColor(0.0, 0.5, 0.5, 1.0);
  glClearDepth(1.0);
  {$ELSE}
  glClearColor(0.0, 0.0, 0.0, 0.0);
  glClearDepth(1.0);
  {$ENDIF}

  glGetIntegerv(GL_MAX_TEXTURE_SIZE, @gld_max_texturesize);
  printf('GL_MAX_TEXTURE_SIZE=%d'#13#10, [gld_max_texturesize]);
  glGetIntegerv(GL_MAX_3D_TEXTURE_SIZE, @gld_max_texturesize3d);
  printf('GL_MAX_3D_TEXTURE_SIZE=%d'#13#10, [gld_max_texturesize3d]);

  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
  glEnable(GL_TEXTURE_2D);
  glDepthFunc(GL_LEQUAL);
  glEnable(GL_ALPHA_TEST);
  glAlphaFunc(GL_GEQUAL, 0.5);
  glDisable(GL_CULL_FACE);
  glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);

  glTexGenfv(GL_Q, GL_EYE_PLANE, @params);
  glTexGenf(GL_S,GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR);
  glTexGenf(GL_T,GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR);
  glTexGenf(GL_Q,GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR);
  glFogi(GL_FOG_MODE, GL_EXP);
  glFogfv(GL_FOG_COLOR, @BlackFogColor);
  glFogf(GL_FOG_DENSITY, fog_density / 3000.0);
  glHint(GL_FOG_HINT, GL_NICEST);
  glFogf(GL_FOG_START, 0.1);
  glFogf(GL_FOG_END, 1.0);

  glHint(GL_POINT_SMOOTH_HINT, GL_NICEST);
  glHint(GL_LINE_SMOOTH_HINT, GL_NICEST);
  glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);

// Texture filtering and mipmaping
  gl_tex_filter_string := strupper(gl_tex_filter_string);
  if gl_tex_filter_string = gl_tex_filters[Ord(FLT_NEAREST_MIPMAP_NEAREST)] then
  begin
    use_mipmapping := true;
    gl_shared_texture_palette := false;
    printf('Using GL_NEAREST for normal textures.'#13#10);
    printf('Using GL_NEAREST_MIPMAP_NEAREST for mipmap textures.'#13#10);
    gl_tex_filter := GL_NEAREST;
    gl_mipmap_filter := GL_NEAREST_MIPMAP_NEAREST;
  end
  else if gl_tex_filter_string = gl_tex_filters[Ord(FLT_LINEAR_MIPMAP_NEAREST)] then
  begin
    use_mipmapping := true;
    gl_shared_texture_palette := false;
    printf('Using GL_LINEAR for normal textures.'#13#10);
    printf('Using GL_LINEAR_MIPMAP_NEAREST for mipmap textures.'#13#10);
    gl_tex_filter := GL_LINEAR;
    gl_mipmap_filter := GL_LINEAR_MIPMAP_NEAREST;
  end
  else if gl_tex_filter_string = gl_tex_filters[Ord(FLT_NEAREST_MIPMAP_LINEAR)] then
  begin
    use_mipmapping := true;
    gl_shared_texture_palette := false;
    printf('Using GL_NEAREST for normal textures.'#13#10);
    printf('Using GL_NEAREST_MIPMAP_LINEAR for mipmap textures.'#13#10);
    gl_tex_filter := GL_NEAREST;
    gl_mipmap_filter := GL_NEAREST_MIPMAP_LINEAR;
  end
  else if gl_tex_filter_string = gl_tex_filters[Ord(FLT_LINEAR_MIPMAP_LINEAR)] then
  begin
    use_mipmapping := true;
    gl_shared_texture_palette := false;
    printf('Using GL_LINEAR for normal textures.'#13#10);
    printf('Using GL_LINEAR_MIPMAP_LINEAR for mipmap textures.'#13#10);
    gl_tex_filter := GL_LINEAR;
    gl_mipmap_filter := GL_LINEAR_MIPMAP_LINEAR;
  end
  else if gl_tex_filter_string = gl_tex_filters[Ord(FLT_NEAREST)] then
  begin
    use_mipmapping := false;
    printf('Using GL_NEAREST for textures.'#13#10);
    gl_tex_filter := GL_NEAREST;
    gl_mipmap_filter := GL_NEAREST;
  end
  else // Default
  begin
    use_mipmapping := false;
    printf('Using GL_LINEAR for textures.'#13#10);
    gl_tex_filter := GL_LINEAR;
    gl_mipmap_filter := GL_LINEAR;
  end;

// Texture format
  gl_tex_format := DEF_TEX_FORMAT;
  gl_tex_format_string := strupper(gl_tex_format_string);
  tf_id := -1;
  for i := 0 to NUM_GL_TEX_FORMATS - 1 do
    if gl_tex_format_string = gl_tex_formats[i].desc then
    begin
      gl_tex_format := gl_tex_formats[i].tex_format;
      tf_id := i;
      break;
    end;

  if tf_id < 0 then
    printf('Using default texture format.'#13#10)
  else
    printf('Using texture format %s.'#13#10, [gl_tex_format_string]);

  if gl_screensync then
    gld_VSync(vsmSync)
  else
    gld_VSync(vsmNoSync);
  last_screensync := gl_screensync;

  gld_InitLightTable;
  gld_CalculateSkyDome(100000.0);
  gld_InitDynamicLights;
  gld_InitModels;
  gld_InitLightmap;
end;


procedure gld_DrawNumPatch(x, y: integer; lump: integer; cm: integer; flags: integer);

  function SCALE_X(const xx: integer): float;
  begin
    if flags and VPT_STRETCH <> 0 then
      result := xx * SCREENWIDTH / 320.0
    else
      result := xx;
  end;

  function SCALE_Y(const yy: integer): float;
  begin
    if flags and VPT_STRETCH <> 0 then
      result := yy * SCREENHEIGHT / 200.0
    else
      result := yy;
  end;

var
  gltexture: PGLTexture;
  fU1, fU2, fV1, fV2: float;
  width, height: float;
  xpos, ypos: float;
begin
  if flags and VPT_TRANS <> 0 then
  begin
    gltexture := gld_RegisterPatch(lump, cm);
    gld_BindPatch(gltexture, cm);
  end
  else
  begin
    gltexture := gld_RegisterPatch(lump, Ord(CR_DEFAULT));
    gld_BindPatch(gltexture, Ord(CR_DEFAULT));
  end;
  if gltexture = nil then
    exit;
  fV1 := 0.0;
  fV2 := gltexture.height / gltexture.tex_height;
  if flags and VPT_FLIP <> 0 then
  begin
    fU1 := gltexture.width / gltexture.tex_width;
    fU2 := 0.0;
  end
  else
  begin
    fU1 := 0.0;
    fU2 := gltexture.width / gltexture.tex_width;
  end;
  xpos := SCALE_X(x - gltexture.leftoffset);
  ypos := SCALE_Y(y - gltexture.topoffset);
  width := SCALE_X(gltexture.realtexwidth);
  height := SCALE_Y(gltexture.realtexheight);

  glBegin(GL_TRIANGLE_STRIP);
    glTexCoord2f(fU1, fV1);
    glVertex2f(xpos, ypos);
    glTexCoord2f(fU1, fV2);
    glVertex2f(xpos, ypos + height);
    glTexCoord2f(fU2, fV1);
    glVertex2f(xpos + width, ypos);
    glTexCoord2f(fU2, fV2);
    glVertex2f(xpos + width, ypos + height);
  glEnd;
end;

procedure gld_DrawBackground(const name: string);
var
  gltexture: PGLTexture;
  fU1, fU2, fV1, fV2: float;
  width, height: integer;
begin
  gltexture := gld_RegisterFlat(W_GetNumForName(name), false);
  gld_BindFlat(gltexture);
  if gltexture = nil then
    exit;
  fU1 := 0;
  fV1 := 0;
  fU2 := 320 / gltexture.realtexwidth;
  fV2 := 200 / gltexture.realtexheight;
  width := SCREENWIDTH;
  height := SCREENHEIGHT;

  glBegin(GL_TRIANGLE_STRIP);
    glTexCoord2f(fU1, fV1);
    glVertex2f(0.0, 0.0);
    glTexCoord2f(fU1, fV2);
    glVertex2f(0.0, height);
    glTexCoord2f(fU2, fV1);
    glVertex2f(width, 0);
    glTexCoord2f(fU2, fV2);
    glVertex2f(width, height);
  glEnd;
end;

procedure gld_DrawLine(x0, y0, x1, y1: integer; BaseColor: integer);
var
  playpal: PByteArray;
  idx: integer;
begin
  glBindTexture(GL_TEXTURE_2D, 0);
  last_gltexture := nil;
  last_cm := -1;

  playpal := V_ReadPalette(PU_STATIC);
  idx := 3 * BaseColor;
  glColor3f(playpal[idx] / 255.0,
            playpal[idx + 1] / 255.0,
            playpal[idx + 2] / 255.0);
  Z_ChangeTag(playpal, PU_CACHE);

  glBegin(GL_LINES);
    glVertex2i(x0, y0);
    glVertex2i(x1, y1);
  glEnd;
end;

procedure gld_DrawWeapon(weaponlump: integer; vis: Pvissprite_t; lightlevel: integer);
var
  gltexture: PGLTexture;
  fU1, fU2, fV1, fV2: float;
  x1, y1, x2, y2: integer;
  scale: float;
  light: float;
  restoreblend: boolean;
begin
  gltexture := gld_RegisterPatch(firstspritelump + weaponlump, Ord(CR_DEFAULT));
  if gltexture = nil then
    exit;
  gld_BindPatch(gltexture, Ord(CR_DEFAULT));
  fU1 := 0.0;
  fV1 := 0.0;
  fU2 := gltexture.width / gltexture.tex_width;
  fV2 := gltexture.height / gltexture.tex_height;
  x1 := viewwindowx + vis.x1;
  x2 := viewwindowx + vis.x2;
  scale := vis.scale / FRACUNIT;
  y1 := viewwindowy + centery - round((vis.texturemid / FRACUNIT) * scale);
  y2 := y1 + round(gltexture.realtexheight * scale) + 1;
  light := gld_CalcLightLevel(lightlevel);

// JVAL??  viewplayer.mo.renderstyle = mrs_translucent
  if viewplayer.mo.flags and MF_SHADOW <> 0 then
  begin
    glBlendFunc(GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA);
    glAlphaFunc(GL_GEQUAL, 0.1);
    glColor4f(0.2, 0.2, 0.2, 0.33);
    restoreblend := true;
  end
  else
  begin
    if (viewplayer.mo.flags_ex and MF_EX_TRANSPARENT <> 0) or
       (viewplayer.mo.renderstyle = mrs_translucent) then
    begin
      gld_StaticLightAlpha(light, tran_filter_pct / 100.0);
      restoreblend := true;
    end
    else
    begin
      gld_StaticLight(light);
      restoreblend := false;
    end;
  end;
  glBegin(GL_TRIANGLE_STRIP);
    glTexCoord2f(fU1, fV1);
    glVertex2f(x1, y1);
    glTexCoord2f(fU1, fV2);
    glVertex2f(x1, y2);
    glTexCoord2f(fU2, fV1);
    glVertex2f(x2, y1);
    glTexCoord2f(fU2, fV2);
    glVertex2f(x2, y2);
  glEnd;
  if restoreblend then
  begin
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glAlphaFunc(GL_GEQUAL, 0.5);
  end;
  glColor3f(1.0, 1.0, 1.0);
end;

procedure gld_FillBlock(x, y, width, height: integer; col: integer);
var
  playpal: PByteArray;
begin
  glBindTexture(GL_TEXTURE_2D, 0);
  last_gltexture := nil;
  last_cm := -1;
  playpal := V_ReadPalette(PU_STATIC);
  glColor3f(playpal[3 * col] / 255.0,
            playpal[3 * col + 1] / 255.0,
            playpal[3 * col + 2] / 255.0);
  Z_ChangeTag(playpal, PU_CACHE);
  glBegin(GL_TRIANGLE_STRIP);
    glVertex2i(x, y);
    glVertex2i(x, y + height);
    glVertex2i(x + width, y);
    glVertex2i(x + width, y + height);
  glEnd;
  glColor3f(1.0, 1.0, 1.0);
end;

var
  last_palette: integer = 0;

procedure gld_SetPalette(palette: integer);
var
  playpal: PByteArray;
  plpal: PByteArray;
  pal: array[0..1023] of byte;
  i: integer;
  col, pcol: integer;
begin
  extra_red := 0.0;
  extra_green := 0.0;
  extra_blue := 0.0;
  extra_alpha := 0.0;
  if palette < 0 then
    palette := last_palette;
  last_palette := palette;
  if gl_shared_texture_palette then
  begin

    playpal := V_ReadPalette(PU_STATIC);
    plpal := @playpal[768];
    if fixedcolormap <> nil then
    begin
      for i := 0 to 255 do
      begin
        col := 3 * fixedcolormap[i];
        pcol := i * 4;
        pal[pcol] := plpal[col];
        pal[pcol + 1] := plpal[col + 1];
        pal[pcol + 2] := plpal[col + 2];
        pal[pcol + 3] := 255;
      end;
    end
    else
    begin
      for i := 0 to 255 do
      begin
        col := 3 * i;
        pcol := col + i;
        pal[pcol] := plpal[col];
        pal[pcol + 1] := plpal[col + 1];
        pal[pcol + 2] := plpal[col + 2];
        pal[pcol + 3] := 255;
      end;
    end;

    Z_ChangeTag(playpal, PU_CACHE);
    pcol := transparent_pal_index * 4;
    pal[pcol] := 0;
    pal[pcol + 1] := 0;
    pal[pcol + 2] := 0;
    pal[pcol + 3] := 0;
    gld_ColorTableEXT(GL_SHARED_TEXTURE_PALETTE_EXT, GL_RGBA, 256, GL_RGBA, GL_UNSIGNED_BYTE, @pal);
  end
  else
  begin
    if palette > 0 then
    begin
      if palette <= 8 then
      begin
        extra_red := palette / 2.0;
        extra_green := 0.0;
        extra_blue := 0.0;
        extra_alpha := palette / 10.0;
      end
      else if palette <= 12 then
      begin
        palette := palette - 8;
        extra_red := palette * 1.0;
        extra_green := palette * 0.8;
        extra_blue := palette * 0.1;
        extra_alpha := palette / 11.0;
      end
      else if palette = 13 then
      begin
        extra_red := 0.4;
        extra_green := 1.0;
        extra_blue := 0.0;
        extra_alpha := 0.2;
      end;
    end;
    if extra_red > 1.0 then
      extra_red := 1.0;
    if extra_green > 1.0 then
      extra_green := 1.0;
    if extra_blue > 1.0 then
      extra_blue := 1.0;
    if extra_alpha > 1.0 then
      extra_alpha := 1.0;
  end;
end;

procedure gld_ReadScreen(scr: PByteArray);
begin
  glReadPixels(0, 0, SCREENWIDTH, SCREENHEIGHT, GL_RGB, GL_UNSIGNED_BYTE, scr);
end;

procedure gld_Enable2D;
var
  vPort: array[0..3] of GLInt;
begin
  glGetIntegerv(GL_VIEWPORT, @vPort);

  glMatrixMode(GL_PROJECTION);
  glPushMatrix;
  glLoadIdentity;

  glOrtho(0, vPort[2], 0, vPort[3], -1, 1);
  glMatrixMode(GL_MODELVIEW);
  glPushMatrix;
  glLoadIdentity;
end;

procedure gld_Disable2D;
begin
  glMatrixMode(GL_PROJECTION);
  glPopMatrix;
  glMatrixMode(GL_MODELVIEW);
  glPopMatrix;
end;


procedure gld_Set2DMode;
begin
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glOrtho(
    0,
    SCREENWIDTH,
    SCREENHEIGHT,
    0,
    -1.0,
    1.0
  );
  glDisable(GL_DEPTH_TEST);
end;

procedure gld_Finish;
begin
  gld_Set2DMode;
  glFinish;
  glFlush;
  SwapBuffers(h_DC);
end;

{*****************
 *               *
 * structs       *
 *               *
 *****************}

var
  gld_max_vertexes: integer = 0;
  gld_num_vertexes: integer = 0;
  gld_vertexes: PGLVertexArray = nil;
  gld_texcoords: PGLTexcoordArray = nil;

procedure gld_AddGlobalVertexes(count: integer);
begin
  if (gld_num_vertexes + count) >= gld_max_vertexes then
  begin
    gld_max_vertexes := gld_max_vertexes + count + 1024;
    gld_vertexes := Z_Realloc(gld_vertexes, gld_max_vertexes * SizeOf(GLVertex), PU_LEVEL, nil);
    gld_texcoords := Z_Realloc(gld_texcoords, gld_max_vertexes * SizeOf(GLTexcoord), PU_LEVEL, nil);
  end;
end;

{* GLLoopDef is the struct for one loop. A loop is a list of vertexes
 * for triangles, which is calculated by the gluTesselator in gld_PrecalculateSector
 * and in gld_PreprocessCarvedFlat
 *}

type
  GLLoopDef = record
    mode: TGLenum;        // GL_TRIANGLES, GL_TRIANGLE_STRIP or GL_TRIANGLE_FAN
    vertexcount: integer; // number of vertexes in this loop
    vertexindex: integer; // index into vertex list
  end;
  PGLLoopDef = ^GLLoopDef;
  GLLoopDefArray = array[0..$FFFF] of GLLoopDef;
  PGLLoopDefArray = ^GLLoopDefArray;

// GLSector is the struct for a sector with a list of loops.

  GLSector = record
    loopcount: integer;     // number of loops for this sector
    loops: PGLLoopDefArray; // the loops itself
    list_f: GLuint;
    list_c: GLuint;
    list_nonormal: GLuint;
  end;
  PGLSector = ^GLSector;
  GLSectorArray = array[0..$FFFF] of GLSector;
  PGLSectorArray = ^GLSectorArray;

  GLSubSector = record
    loop: GLLoopDef; // the loops itself
  end;

  TGLSeg = record
    x1, x2: float;
    z1, z2: float;
  end;
  PGLSeg = ^TGLSeg;
  GLSegArray = array[0..$FFFF] of TGLSeg;
  PGLSegArray = ^GLSegArray;

var
  gl_segs: PGLSegArray = nil;

const
  GLDWF_TOP = 1;
  GLDWF_M1S = 2;
  GLDWF_M2S = 3;
  GLDWF_BOT = 4;
  GLDWF_SKY = 5;
  GLDWF_SKYFLIP = 6;

type
  GLWall = record
    glseg: PGLSeg;
    ytop, ybottom: float;
    ul, ur, vt, vb: float;
    light: float;
    alpha: float;
    skyymid: float;
    skyyaw: float;
    gltexture: PGLTexture;
    flag: byte;
  end;
  PGLWall = ^GLWall;
  GLWallArray = array[0..$FFFF] of GLWall;
  PGLWallArray = ^GLWallArray;

  GLFlat = record
    sectornum: integer;
    light: float; // the lightlevel of the flat
    {$IFDEF DOOM}
    hasoffset: boolean;
    uoffs, voffs: float; // the texture coordinates
    {$ENDIF}
    z: float; // the z position of the flat (height)
    gltexture: PGLTexture;
    ceiling: boolean;
  end;
  PGLFlat = ^GLFlat;
  GLFlatArray = array[0..$FFFF] of GLFlat;
  PGLFlatArray = ^GLFlatArray;

const
  GLS_SHADOW = 1;
  GLS_TRANSPARENT = 2;
  GLS_CLIPPED = 4;
  GLS_WHITELIGHT = 8;
  GLS_REDLIGHT = 16;
  GLS_GREENLIGHT = 32;
  GLS_BLUELIGHT = 64;
  GLS_YELLOWLIGHT = 128;
  GLS_LIGHT = GLS_WHITELIGHT or GLS_REDLIGHT or GLS_GREENLIGHT or GLS_BLUELIGHT or GLS_YELLOWLIGHT;

type
  GLSprite = record
    cm: integer;
    x, y, z: float;
    vt, vb: float;
    ul, ur: float;
    x1, y1: float;
    x2, y2: float;
    light: float;
    scale: fixed_t;
    gltexture: PGLTexture;
    flags: integer;
    alpha: float;
    dlights: TDNumberList;
    models: TDNumberList;
    mo: Pmobj_t;
  end;
  PGLSprite = ^GLSprite;
  GLSpriteArray = array[0..$FFFF] of GLSprite;
  PGLSpriteArray = ^GLSpriteArray;

  GLDrawItemType = (
    GLDIT_NONE,
    GLDIT_WALL,
    GLDIT_FLAT,
    GLDIT_SPRITE,
    GLDIT_DLIGHT
  );

  GLDrawItem = record
    itemtype: GLDrawItemType;
    itemcount: integer;
    firstitemindex: integer;
    rendermarker: byte;
  end;
  PGLDrawItem = ^GLDrawItem;
  GLDrawItemArray = array[0..$FFFF] of GLDrawItem;
  PGLDrawItemArray = ^GLDrawItemArray;

  GLDrawInfo = record
    walls: PGLWallArray;
    num_walls: integer;
    max_walls: integer;
    flats: PGLFlatArray;
    num_flats: integer;
    max_flats: integer;
    sprites: PGLSpriteArray;
    num_sprites: integer;
    max_sprites: integer;
    drawitems: PGLDrawItemArray;
    num_drawitems: integer;
    max_drawitems: integer;
  end;

var
  gld_drawinfo: GLDrawInfo;

// this is the list for all sectors to the loops
  sectorloops: PGLSectorArray;

  rendermarker: byte = 0;
  sectorrendered: PByteArray; // true if sector rendered (only here for malloc)
  sectorrenderedflatex: PByteArray;
  segrendered: PByteArray; // true if sector rendered (only here for malloc)


{*****************************
 *
 * FLATS
 *
 *****************************}

{* proff - 05/15/2000
 * The idea and algorithm to compute the flats with nodes and subsectors is
 * originaly from JHexen. I have redone it.
 *}

const
  MAX_CC_SIDES = 128;

function FIX2DBL(const x: fixed_t): double;
begin
  result := x / 1.0;
end;

function gld_PointOnSide(p: Pvertex_t; d: Pdivline_t): boolean;
begin
  // We'll return false if the point c is on the left side.
  result := (FIX2DBL(d.y) - FIX2DBL(p.y)) * FIX2DBL(d.dx) - (FIX2DBL(d.x) - FIX2DBL(p.x)) * FIX2DBL(d.dy) >= 0;
end;

// Lines start-end and fdiv must intersect.
procedure gld_CalcIntersectionVertex(s: Pvertex_t; e: Pvertex_t; d: Pdivline_t; i: Pvertex_t);
var
  ax: double;
  ay: double;
  bx: double;
  by: double;
  cx: double;
  cy: double;
  dx: double;
  dy: double;
  r: double;
begin
  ax := FIX2DBL(s.x);
  ay := FIX2DBL(s.y);
  bx := FIX2DBL(e.x);
  by := FIX2DBL(e.y);
  cx := FIX2DBL(d.x);
  cy := FIX2DBL(d.y);
  dx := cx + FIX2DBL(d.dx);
  dy := cy + FIX2DBL(d.dy);
  r := ((ay - cy) * (dx - cx) - (ax - cx) * (dy - cy)) / ((bx - ax) * (dy - cy) - (by - ay) * (dx - cx));
  i.x := round(FIX2DBL(s.x) + r * (FIX2DBL(e.x) - FIX2DBL(s.x)));
  i.y := round(FIX2DBL(s.y) + r * (FIX2DBL(e.y) - FIX2DBL(s.y)));
end;

// Returns a pointer to the list of points. It must be used.
//
function gld_FlatEdgeClipper(numpoints: Pinteger; points: Pvertex_tArray; numclippers: integer; clippers: Pdivline_tArray): Pvertex_tArray;
var
  sidelist: array[0..MAX_CC_SIDES - 1] of boolean;
  i, k, num: integer;
  curclip: Pdivline_t;
  startIdx, endIdx: integer;
  newvert: vertex_t;
  previdx: integer;
begin
  num := numpoints^;
  // We'll clip the polygon with each of the divlines. The left side of
  // each divline is discarded.
  for i := 0 to numclippers - 1 do
  begin
    curclip := @clippers[i];

    // First we'll determine the side of each vertex. Points are allowed
    // to be on the line.
    for k := 0 to num - 1 do
      sidelist[k] := gld_PointOnSide(@points[k], curclip);

    k := 0;
    while k < num do
    begin
      startIdx := k;
      endIdx := k + 1;
      // Check the end index.
      if endIdx = num then
        endIdx := 0; // Wrap-around.
      // Clipping will happen when the ends are on different sides.
      if sidelist[startIdx] <> sidelist[endIdx] then
      begin
        gld_CalcIntersectionVertex(@points[startIdx], @points[endIdx], curclip, @newvert);

        // Add the new vertex. Also modify the sidelist.
        inc(num);
        realloc(pointer(points), (num - 1) * SizeOf(vertex_t), num * SizeOf(vertex_t));
        if num >= MAX_CC_SIDES then
          I_Error('gld_FlatEdgeClipper: Too many points in carver');

        // Make room for the new vertex.
        memmove(@points[endIdx + 1], @points[endIdx], (num - endIdx - 1) * SizeOf(vertex_t)); // VJ SOS
        memcpy(@points[endIdx], @newvert, SizeOf(newvert));

        memmove(@sidelist[endIdx + 1], @sidelist[endIdx], num - endIdx - 1);
        sidelist[endIdx] := true;

        // Skip over the new vertex.
        inc(k);
      end;
      inc(k);
    end;

    // Now we must discard the points that are on the wrong side.
    k := 0;
    while k < num do
    begin
      if not sidelist[k] then
      begin
        memmove(@points[k], @points[k + 1], (num - k - 1) * SizeOf(vertex_t));
        memmove(@sidelist[k], @sidelist[k + 1], num - k - 1);
        dec(num);
      end
      else
        inc(k);
    end;
  end;

  // Screen out consecutive identical points.
  i := 0;
  while i < num do
  begin
    previdx := i - 1;
    if previdx < 0 then
      previdx := num - 1;
    if (points[i].x = points[previdx].x) and (points[i].y = points[previdx].y) then
    begin
      // This point (i) must be removed.
      memmove(@points[i], @points[i + 1], (num - i - 1) * SizeOf(vertex_t));
      dec(num)
    end
    else
      inc(i);
  end;

  numpoints^ := num;
  result := points;
end;

procedure gld_FlatConvexCarver(ssidx: integer; num: integer; list: Pdivline_tArray);
var
  ssec: Psubsector_t;
  numclippers: integer;
  clippers: Pdivline_tArray;
  i, numedgepoints: integer;
  edgepoints: Pvertex_tArray;
  epoint: Pvertex_t;
  glsec: PGLSector;
  seg: Pseg_t;
  currentsector: integer;
  plist: Pdivline_t;
  ploop: PGLLoopDef;
  vert: PGLVertex;
begin
  ssec := @subsectors[ssidx];
  numclippers := num + ssec.numlines;

  clippers := malloc(numclippers * SizeOf(divline_t));
  for i := 0 to num - 1 do
  begin
    plist := @list[num - i - 1];
    clippers[i].x := plist.x;
    clippers[i].y := plist.y;
    clippers[i].dx := plist.dx;
    clippers[i].dy := plist.dy;
  end;
  for i := num to numclippers - 1 do
  begin
    seg := @segs[ssec.firstline + i - num];
    clippers[i].x := seg.v1.x;
    clippers[i].y := seg.v1.y;
    clippers[i].dx := seg.v2.x - seg.v1.x;
    clippers[i].dy := seg.v2.y - seg.v1.y;
  end;

  // Setup the 'worldwide' polygon.
  numedgepoints := 4;
  edgepoints := malloc(numedgepoints * Sizeof(vertex_t));

  edgepoints[0].x := MININT;
  edgepoints[0].y := MAXINT;

  edgepoints[1].x := MAXINT;
  edgepoints[1].y := MAXINT;

  edgepoints[2].x := MAXINT;
  edgepoints[2].y := MININT;

  edgepoints[3].x := MININT;
  edgepoints[3].y := MININT;

  // Do some clipping, <snip> <snip>
  edgepoints := gld_FlatEdgeClipper(@numedgepoints, edgepoints, numclippers, clippers);

  if numedgepoints >= 3 then
  begin
    gld_AddGlobalVertexes(numedgepoints);
    if (gld_vertexes <> nil) and (gld_texcoords <> nil) then
    begin

      currentsector := ssec.sector.iSectorID;

      glsec := @sectorloops[currentsector];
      glsec.loops := Z_Realloc(glsec.loops, SizeOf(GLLoopDef) * (glsec.loopcount + 1), PU_LEVEL, nil);
      ploop := @glsec.loops[glsec.loopcount];
      ploop.mode := GL_TRIANGLE_FAN;
      ploop.vertexcount := numedgepoints;
      ploop.vertexindex := gld_num_vertexes;
      inc(glsec.loopcount);

      epoint := @edgepoints[0];
      for i := 0 to numedgepoints - 1 do
      begin
        gld_texcoords[gld_num_vertexes].u := (epoint.x / FRACUNIT) / 64.0;
        gld_texcoords[gld_num_vertexes].v := (-epoint.y / FRACUNIT) / 64.0;
        vert := @gld_vertexes[gld_num_vertexes];
        vert.x := -epoint.x / MAP_SCALE;
        vert.y := 0.0;
        vert.z := epoint.y / MAP_SCALE;
        inc(gld_num_vertexes);
        inc(epoint);
      end;
    end;
  end;
  // We're done, free the edgepoints memory.
  memfree(pointer(edgepoints), numedgepoints * SizeOf(vertex_t));
  memfree(pointer(clippers), numclippers * SizeOf(divline_t));
end;

procedure gld_CarveFlats(bspnode: integer; numdivlines: integer; divlines: Pdivline_tArray; sectorclosed: PBooleanArray);
var
  nod: Pnode_t;
  dl: Pdivline_t;
  childlist: Pdivline_tArray;
  childlistsize: integer;
  ssidx: integer;
begin
  childlistsize := numdivlines + 1;

  if bspnode = -1 then
  begin
    if not sectorclosed[subsectors[0].sector.iSectorID] then
      gld_FlatConvexCarver(0, numdivlines, divlines);
    exit;
  end;

  // If this is a subsector we are dealing with, begin carving with the
  // given list.
  if bspnode and NF_SUBSECTOR <> 0 then
  begin
    // We have arrived at a subsector. The divline list contains all
    // the partition lines that carve out the subsector.
    ssidx := bspnode and (not NF_SUBSECTOR);
    if not sectorclosed[subsectors[ssidx].sector.iSectorID] then
      gld_FlatConvexCarver(ssidx, numdivlines, divlines);
    exit;
  end;

  // Get a pointer to the node.
  nod := @nodes[bspnode];

  // Allocate a new list for each child.
  childlist := malloc(childlistsize * SizeOf(divline_t));

  // Copy the previous lines.
  if divlines <> nil then
    memcpy(childlist, divlines, numdivlines * SizeOf(divline_t));

  dl := @childlist[numdivlines];
  dl.x := nod.x;
  dl.y := nod.y;
  // The right child gets the original line (LEFT side clipped).
  dl.dx := nod.dx;
  dl.dy := nod.dy;
  gld_CarveFlats(nod.children[0], childlistsize, childlist, sectorclosed);

  // The left side. We must reverse the line, otherwise the wrong
  // side would get clipped.
  dl.dx := -nod.dx;
  dl.dy := -nod.dy;
  gld_CarveFlats(nod.children[1], childlistsize, childlist, sectorclosed);

  // We are finishing with this node, free the allocated list.
  memfree(pointer(childlist), childlistsize * SizeOf(divline_t));
end;


(********************************************
 * Name     : gld_GetSubSectorVertices      *
 * created  : 08/13/00                      *
 * modified : 09/18/00, adapted for PrBoom  *
 * author   : figgi                         *
 * what     : prepares subsectorvertices    *
 *            (glnodes only)                *
 ********************************************)

procedure gld_GetSubSectorVertices(sectorclosed: PBooleanArray);
var
  i, j: integer;
  numedgepoints: integer;
  ssector: Psubsector_t;
  currentsector: integer;
  glsec: PGLSector;
  seg: Pseg_t;
  ploop: PGLLoopDef;
  vert: PGLVertex;
begin
  for i := 0 to numsubsectors - 1 do
  begin
    ssector := @subsectors[i];

    if sectorclosed[ssector.sector.iSectorID] then
      continue;

    numedgepoints := ssector.numlines;
    if numedgepoints < 3 then
      continue;

    gld_AddGlobalVertexes(numedgepoints);

    if (gld_vertexes <> nil) and (gld_texcoords <> nil) then
    begin
      currentsector := ssector.sector.iSectorID;

      glsec := @sectorloops[currentsector];
      glsec.loops := Z_Realloc(glsec.loops, SizeOf(GLLoopDef) * (glsec.loopcount + 1), PU_LEVEL, nil);
      ploop := @glsec.loops[glsec.loopcount];
      ploop.mode := GL_TRIANGLE_FAN;
      ploop.vertexcount := numedgepoints;
      ploop.vertexindex := gld_num_vertexes;
      inc(glsec.loopcount);
      seg := @segs[ssector.firstline];
      for j := 0 to numedgepoints - 1 do
      begin
        gld_texcoords[gld_num_vertexes].u := (seg.v1.x / FRACUNIT) / 64.0;
        gld_texcoords[gld_num_vertexes].v :=(-seg.v1.y / FRACUNIT) / 64.0;
        vert := @gld_vertexes[gld_num_vertexes];
        vert.x := -seg.v1.x / MAP_SCALE;
        vert.y := 0.0;
        vert.z := seg.v1.y / MAP_SCALE;
        inc(gld_num_vertexes);
        inc(seg);
      end;
    end;
  end;
end;

procedure gld_PrepareSectorSpecialEffects(const sec: Psector_t);
var
  i: integer;
  line: Pline_t;
begin
  // the following is for specialeffects. see r_bsp.c in R_Subsector
  sec.no_toptextures := true;
  sec.no_bottomtextures := true;

  for i := 0 to sec.linecount - 1 do
  begin
    line := sec.lines[i];
    if (line.sidenum[0] <> -1) and
       (line.sidenum[1] <> -1) then
    begin
      if sides[line.sidenum[0]].toptexture <> 0 then
        sec.no_toptextures := false;
      if sides[line.sidenum[0]].bottomtexture <> 0 then
        sec.no_bottomtextures := false;
      if sides[line.sidenum[1]].toptexture <> 0 then
        sec.no_toptextures := false;
      if sides[line.sidenum[1]].bottomtexture <> 0 then
        sec.no_bottomtextures := false;
    end
    else
    begin
      sec.no_toptextures := false;
      sec.no_bottomtextures := false;
      exit;
    end;
  end;
end;

// gld_PreprocessLevel
//
// this checks all sectors if they are closed and calls gld_PrecalculateSector to
// calculate the loops for every sector
// the idea to check for closed sectors is from DEU. check next commentary
(*
      Note from RQ:
      This is a very simple idea, but it works!  The first test (above)
      checks that all Sectors are closed.  But if a closed set of LineDefs
      is moved out of a Sector and has all its 'external' SideDefs pointing
      to that Sector instead of the new one, then we need a second test.
      That's why I check if the SideDefs facing each other are bound to
      the same Sector.

      Other note from RQ:
      Nowadays, what makes the power of a good editor is its automatic tests.
      So, if you are writing another Doom editor, you will probably want
      to do the same kind of tests in your program.  Fine, but if you use
      these ideas, don't forget to credit DEU...  Just a reminder... :-)
*)
// so I credited DEU

procedure gld_PreprocessSectors;
var
  sectorclosed: PBooleanArray;
  vcheck1, vcheck2: PIntegerArray;
  i, j: integer;
  v1num, v2num: integer;
  ppl: PPline_t;
begin
  sectorclosed := Z_Malloc2(numsectors * SizeOf(boolean), PU_LEVEL, nil);
  if sectorclosed = nil then
    I_Error('gld_PreprocessSectors(): Not enough memory for array sectorclosed');
  ZeroMemory(sectorclosed, SizeOf(boolean) * numsectors);

  sectorloops := Z_Malloc2(numsectors * SizeOf(GLSector), PU_LEVEL, nil);
  if sectorloops = nil then
    I_Error('gld_PreprocessSectors(): Not enough memory for array sectorloops');
  ZeroMemory(sectorloops, numsectors * SizeOf(GLSector));

  sectorrendered := Z_Malloc2(numsectors * SizeOf(byte), PU_LEVEL, nil);
  if sectorrendered = nil then
    I_Error('gld_PreprocessSectors: Not enough memory for array sectorrendered');
  ZeroMemory(sectorrendered, numsectors * SizeOf(byte));

  sectorrenderedflatex := Z_Malloc2(numsectors * SizeOf(byte), PU_LEVEL, nil);
  if sectorrenderedflatex = nil then
    I_Error('gld_PreprocessSectors: Not enough memory for array sectorrenderedflatex');
  ZeroMemory(sectorrenderedflatex, numsectors * SizeOf(byte));

  segrendered := Z_Malloc2(numsegs * SizeOf(byte), PU_LEVEL, nil);
  if segrendered = nil then
    I_Error('gld_PreprocessSectors: Not enough memory for array segrendered');
  ZeroMemory(segrendered, numsegs * SizeOf(byte));

  gld_vertexes := nil;
  gld_texcoords := nil;
  gld_max_vertexes := 0;
  gld_num_vertexes := 0;
  gld_AddGlobalVertexes(numvertexes * 2);

  // JVAL: From prboom-plus
  vcheck1 := malloc(numvertexes * SizeOf(vcheck1[0]));
  vcheck2 := malloc(numvertexes * SizeOf(vcheck2[0]));
  for i := 0 to numsectors - 1 do
  begin
    gld_PrepareSectorSpecialEffects(@sectors[i]);

    ZeroMemory(vcheck1, numvertexes * SizeOf(vcheck1[0]));
    ZeroMemory(vcheck2, numvertexes * SizeOf(vcheck2[0]));

    ppl := @sectors[i].lines[0];
    for j := 0 to sectors[i].linecount - 1 do
    begin
      v1num := (integer(ppl^.v1) - integer(vertexes)) div SizeOf(vertex_t);
      v2num := (integer(ppl^.v2) - integer(vertexes)) div SizeOf(vertex_t);
      if (v1num >= numvertexes) or (v2num >= numvertexes) then
        continue;

      // e6y: for correct handling of missing textures.
      // We do not need to apply some algos for isolated lines.
      inc(vcheck2[v1num]);
      inc(vcheck2[v2num]);

      if ppl^.sidenum[0] <> - 1 then
        if sides[ppl^.sidenum[0]].sector = @sectors[i] then
        begin
          vcheck1[v1num] := vcheck1[v1num] or 1;
          vcheck1[v2num] := vcheck1[v2num] or 2;
        end;
      if ppl^.sidenum[1] <> -1 then
        if sides[ppl^.sidenum[1]].sector = @sectors[i] then
        begin
          vcheck1[v1num] := vcheck1[v1num] or 2;
          vcheck1[v2num] := vcheck1[v2num] or 1;
        end;
      inc(ppl);
    end;

    ppl := @sectors[i].lines[0];
    for j := 0 to sectors[i].linecount - 1 do
    begin
      v1num :=(integer(ppl^.v1) -integer(vertexes)) div SizeOf(vertex_t);
      v2num :=(integer(ppl^.v2) -integer(vertexes)) div SizeOf(vertex_t);
      if (vcheck2[v1num] < 2) and (vcheck2[v2num] < 2) then
        ppl^.renderflags := ppl^.renderflags or LRF_ISOLATED;
      inc(ppl);
    end;
  end;
  memfree(pointer(vcheck1), numvertexes * SizeOf(vcheck1[0]));
  memfree(pointer(vcheck2), numvertexes * SizeOf(vcheck2[0]));

  // figgi -- adapted for glnodes // JVAL
  if glnodesver = 0 then
    gld_CarveFlats(numnodes - 1, 0, nil, sectorclosed)
  else
    gld_GetSubSectorVertices(sectorclosed);

  Z_Free(sectorclosed);
end;

var
  roll: float = 0.0;
  yaw: float = 0.0;
  inv_yaw: float = 0.0;
  pitch: float = 0.0;

procedure infinitePerspective(fovy: GLdouble; aspect: GLdouble; znear: GLdouble);
var
  left, right, bottom, top: GLdouble;
  m: array[0..15] of GLdouble;
begin
  top := znear * tan(fovy * __glPi / 360.0);
  bottom := -top;
  left := bottom * aspect;
  right := top * aspect;

  m[ 0] := (2 * znear) / (right - left);
  m[ 4] := 0;
  m[ 8] := (right + left) / (right - left);
  m[12] := 0;

  m[ 1] := 0;
  m[ 5] := (2 * znear) / (top - bottom);
  m[ 9] := (top + bottom) / (top - bottom);
  m[13] := 0;

  m[ 2] := 0;
  m[ 6] := 0;
//  m[10] := - (zfar + znear) / (zfar - znear);
//  m[14] := - (2 * zfar * znear) / (zfar - znear);
  m[10] := -1;
  m[14] := -2 * znear;

  m[ 3] := 0;
  m[ 7] := 0;
  m[11] := -1;
  m[15] := 0;

  glMultMatrixd(@m);
end;

var
  dodrawsky: boolean;

procedure gld_StartDrawScene;
var
  ytr: float;
  xCamera, yCamera: float;
  height: integer;
begin
  if gl_shared_texture_palette then
    glEnable(GL_SHARED_TEXTURE_PALETTE_EXT);
  gld_SetPalette(-1);

  if last_screensync <> gl_screensync then
  begin
    if gl_screensync then
      gld_VSync(vsmSync)
    else
      gld_VSync(vsmNoSync);
    last_screensync := gl_screensync;
  end;

  if screenblocks > 10 then
    height := SCREENHEIGHT
  else if screenblocks = 10 then
    height := SCREENHEIGHT
  else
    height := (screenblocks * SCREENHEIGHT div 10) and not 7;

  glViewport(viewwindowx, SCREENHEIGHT - (height + viewwindowy - ((height - viewheight) div 2)), viewwidth, height);
  if screenblocks > 10 then
    glDisable(GL_SCISSOR_TEST)
  else
  begin
    glScissor(viewwindowx, SCREENHEIGHT - (viewheight + viewwindowy), viewwidth, viewheight);
    glEnable(GL_SCISSOR_TEST);
  end;

  // Player coordinates
  xCamera := -viewx / MAP_SCALE;
  yCamera := viewy / MAP_SCALE;

  ytr := viewz / MAP_SCALE;

  yaw := 270.0 - (viewangle shr ANGLETOFINESHIFT) * 360.0 / FINEANGLES;
  inv_yaw := -90.0 + (viewangle shr ANGLETOFINESHIFT) * 360.0 / FINEANGLES;

{$IFDEF DEBUG}
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
{$ELSE}
  glClear(GL_DEPTH_BUFFER_BIT);
{$ENDIF}

  glShadeModel(GL_SMOOTH);

  glEnable(GL_DEPTH_TEST);

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;

  infinitePerspective(64.0, 320.0 / 200.0, gl_nearclip / 1000.0);


  if zaxisshift then
    pitch := -players[displayplayer].lookdir / 2
  else
    pitch := 0;
  // JVAL: Correct 2d bsp limitation
  if pitch > 45 then
    pitch := 45;

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;

  glRotatef(roll,  0.0, 0.0, 1.0);
  glRotatef(pitch, 1.0, 0.0, 0.0);
  glRotatef(yaw,   0.0, 1.0, 0.0);
  glTranslatef(-xCamera, -ytr, -yCamera);
  camera.rotation[0] := pitch;
  camera.rotation[1] := yaw;
  camera.rotation[2] := roll;
  camera.position[0] := xCamera;
  camera.position[1] := ytr;
  camera.position[2] := yCamera;

  inc(rendermarker);
  gld_drawinfo.num_walls := 0;
  gld_drawinfo.num_flats := 0;
  gld_drawinfo.num_sprites := 0;
  gld_drawinfo.num_drawitems := 0;
  dodrawsky := false;
  numdlitems := 0;

  fr_CalculateFrustum;
end;

var
  terrainandskycullregion: boolean = true;

procedure gld_EndDrawScene;
var
  player: Pplayer_t;
begin
  player := @players[displayplayer];

  glDisable(GL_POLYGON_SMOOTH);

  glViewport(0, 0, SCREENWIDTH, SCREENHEIGHT);

  if not terrainandskycullregion then
  begin
    gld_CalculateSun;
    gld_DrawSun;
  end;
  
  gld_Set2DMode;


  R_DrawPlayer;

  if player.fixedcolormap = 32 then
  begin
    glBlendFunc(GL_ONE_MINUS_DST_COLOR, GL_ZERO);
    glColor4f(1.0, 1.0, 1.0, 1.0);
    glBindTexture(GL_TEXTURE_2D, 0);
    last_gltexture := nil;
    last_cm := -1;
    glBegin(GL_TRIANGLE_STRIP);
      glVertex2f(0.0, 0.0);
      glVertex2f(0.0, SCREENHEIGHT);
      glVertex2f(SCREENWIDTH, 0.0);
      glVertex2f(SCREENWIDTH, SCREENHEIGHT);
    glEnd;
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    glDisable(GL_ALPHA_TEST);
    glColor4f(0.3, 0.3, 0.3, 0.3);
    glBindTexture(GL_TEXTURE_2D, 0);
    last_gltexture := nil;
    last_cm := -1;
    glBegin(GL_TRIANGLE_STRIP);
      glVertex2f(0.0, 0.0);
      glVertex2f(0.0, SCREENHEIGHT);
      glVertex2f(SCREENWIDTH, 0.0);
      glVertex2f(SCREENWIDTH, SCREENHEIGHT);
    glEnd;
    glEnable(GL_ALPHA_TEST);
  end;

  {$IFDEF DOOM}
  if R_UnderWater then
  begin
    extra_blue := 1.0;
    extra_alpha := extra_alpha + 0.8;
    if extra_alpha > 1.0 then
      extra_alpha := 1.0;
  end;
  {$ENDIF}

  if extra_alpha > 0.0 then
  begin
    glDepthMask(False);
    glDisable(GL_TEXTURE_2D);
    glDisable(GL_ALPHA_TEST);
    glBlendFunc(GL_ONE, GL_ONE);

    glColor4f(extra_red * 0.25, extra_green * 0.25, extra_blue * 0.25, extra_alpha);
    glBindTexture(GL_TEXTURE_2D, 0);
    last_gltexture := nil;
    last_cm := -1;
    glBegin(GL_TRIANGLE_STRIP);
      glVertex2f(0.0, 0.0);
      glVertex2f(0.0, SCREENHEIGHT);
      glVertex2f(SCREENWIDTH, 0.0);
      glVertex2f(SCREENWIDTH, SCREENHEIGHT);
    glEnd;

    glDepthMask(True);
    glEnable(GL_TEXTURE_2D);
    glEnable(GL_ALPHA_TEST);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

  end;

  glColor3f(1.0, 1.0, 1.0);
  glDisable(GL_SCISSOR_TEST);
  if gl_shared_texture_palette then
    glDisable(GL_SHARED_TEXTURE_PALETTE_EXT);
end;

procedure gld_AddDrawItem(itemtype: GLDrawItemType; itemindex: integer);
var
  item: PGLDrawItem;
begin
  if gld_drawinfo.num_drawitems >= gld_drawinfo.max_drawitems then
  begin
    gld_drawinfo.max_drawitems := gld_drawinfo.max_drawitems + 64;
    gld_drawinfo.drawitems := Z_Realloc(gld_drawinfo.drawitems, gld_drawinfo.max_drawitems * SizeOf(GLDrawItem), PU_LEVEL, nil);
    item := @gld_drawinfo.drawitems[gld_drawinfo.num_drawitems];
    item.itemtype := itemtype;
    item.itemcount := 1;
    item.firstitemindex := itemindex;
    item.rendermarker := rendermarker;
    exit;
  end;
  item := @gld_drawinfo.drawitems[gld_drawinfo.num_drawitems];
  if item.rendermarker <> rendermarker then
  begin
    item.itemtype := GLDIT_NONE;
    item.rendermarker := rendermarker;
  end;
  if item.itemtype <> itemtype then
  begin
    if item.itemtype <> GLDIT_NONE then
    begin
      inc(gld_drawinfo.num_drawitems);
    end;
    if gld_drawinfo.num_drawitems >= gld_drawinfo.max_drawitems then
    begin
      gld_drawinfo.max_drawitems := gld_drawinfo.max_drawitems + 64;
      gld_drawinfo.drawitems := Z_Realloc(gld_drawinfo.drawitems, gld_drawinfo.max_drawitems * SizeOf(GLDrawItem), PU_LEVEL, nil);
    end;
    item := @gld_drawinfo.drawitems[gld_drawinfo.num_drawitems];
    item.itemtype := itemtype;
    item.itemcount := 1;
    item.firstitemindex := itemindex;
    item.rendermarker := rendermarker;
    exit;
  end;
  inc(item.itemcount);
end;

(*****************
 *               *
 * Walls         *
 *               *
 *****************)

procedure gld_DrawWall(wall: PGLWall);
var
  seg: PGLSeg;
begin
  if (not gl_drawsky) and (wall.flag >= GLDWF_SKY) then
    exit;
  if wall.gltexture.index = 0 then
    exit;

  gld_BindTexture(wall.gltexture);
  if wall.flag >= GLDWF_SKY then
  begin
    glMatrixMode(GL_TEXTURE);
    glPushMatrix;
    if wall.flag and GLDWF_SKYFLIP = GLDWF_SKYFLIP then
      glScalef(-128.0 / wall.gltexture.buffer_width / 2, 200.0 / 320.0 * 2.0, 1.0)
    else
      glScalef(128.0 / wall.gltexture.buffer_width, 200.0 / 320.0 * 2.0, 1.0);
    glTranslatef(wall.skyyaw, wall.skyymid, 0.0);

    seg := wall.glseg;
    glBegin(GL_TRIANGLE_STRIP);
      glVertex3f(seg.x1, wall.ytop, seg.z1);
      glVertex3f(seg.x1, wall.ybottom, seg.z1);
      glVertex3f(seg.x2, wall.ytop, seg.z2);
      glVertex3f(seg.x2, wall.ybottom, seg.z2);
    glEnd;
    glPopMatrix;
    glMatrixMode(GL_MODELVIEW);
  end
  else
  begin
    gld_StaticLightAlpha(wall.light, wall.alpha);
    seg := wall.glseg;
    glBegin(GL_TRIANGLE_STRIP);
      glTexCoord2f(wall.ul, wall.vt); glVertex3f(seg.x1, wall.ytop, seg.z1);
      glTexCoord2f(wall.ul, wall.vb); glVertex3f(seg.x1, wall.ybottom, seg.z1);
      glTexCoord2f(wall.ur, wall.vt); glVertex3f(seg.x2, wall.ytop, seg.z2);
      glTexCoord2f(wall.ur, wall.vb); glVertex3f(seg.x2, wall.ybottom, seg.z2);
    glEnd;
  end;
end;

procedure CALC_Y_VALUES(w: PGLWall; var lineheight: float; floor_height, ceiling_height: integer);
begin
  w.ytop := ceiling_height / MAP_SCALE + 0.001;
  w.ybottom := floor_height / MAP_SCALE - 0.001;
  lineheight := abs((ceiling_height - floor_height) / FRACUNIT);
end;

procedure CALC_Y_VALUES2(w: PGLWall; var lineheight: float; floor_height, ceiling_height: integer);
begin
  w.ytop := ceiling_height / MAP_SCALE + 0.001;
  w.ybottom := floor_height / MAP_SCALE - 0.001;
  lineheight := (ceiling_height - floor_height) / FRACUNIT;
end;

function OU(tex: PGLTexture; seg: Pseg_t): float;
begin
  result := ((seg.sidedef.textureoffset + seg.offset) / FRACUNIT) / tex.buffer_width;
end;

function OV(tex: PGLTexture; seg: Pseg_t): float;
begin
  result := (seg.sidedef.rowoffset / FRACUNIT) / tex.buffer_height;
end;

function OV_PEG(tex: PGLTexture; seg: Pseg_t; v_offset: integer): float;
begin
  result := ((seg.sidedef.rowoffset - v_offset) / FRACUNIT) / tex.buffer_height;
end;

procedure CALC_TEX_VALUES_TOP(w: PGLWall; seg: Pseg_t; peg: boolean; linelength, lineheight: float);
var
  tex: PGLTexture;
begin
  w.flag := GLDWF_TOP;
  tex := w.gltexture;
  w.ul := OU(tex, seg);
  w.ur := w.ul + (linelength / tex.buffer_width);
  if peg then
  begin
    w.vb := OV(tex, seg) + (tex.height / tex.tex_height);
    w.vt := w.vb - (lineheight / tex.buffer_height);
  end
  else
  begin
    w.vt := OV(tex, seg);
    w.vb := w.vt + (lineheight / tex.buffer_height);
  end;
end;

procedure CALC_TEX_VALUES_MIDDLE1S(w: PGLWall; seg: Pseg_t; peg: boolean; linelength, lineheight: float);
var
  tex: PGLTexture;
begin
  w.flag := GLDWF_M1S;
  tex := w.gltexture;
  w.ul := OU(tex, seg);
  w.ur := w.ul + (linelength / tex.buffer_width);
  if peg then
  begin
    w.vb := OV(tex, seg) + tex.heightscale;
    w.vt := w.vb - (lineheight / tex.buffer_height);
  end
  else
  begin
    w.vt := OV(tex, seg);
    w.vb := w.vt + (lineheight / tex.buffer_height);
  end;
end;

procedure CALC_TEX_VALUES_MIDDLE2S(w: PGLWall; seg: Pseg_t; peg: boolean; linelength, lineheight: float);
var
  tex: PGLTexture;
begin
  w.flag := GLDWF_M2S;
  tex := w.gltexture;
  w.ul := OU(tex, seg);
  w.ur := w.ul + (linelength / tex.buffer_width);
  if peg then
  begin
    w.vb := tex.heightscale;
    w.vt := w.vb - (lineheight / tex.buffer_height)
  end
  else
  begin
    w.vt := 0.0;
    w.vb := lineheight / tex.buffer_height;
  end;
end;

procedure CALC_TEX_VALUES_BOTTOM(w: PGLWall; seg: Pseg_t; peg: boolean; linelength, lineheight: float; v_offset: integer);
var
  tex: PGLTexture;
begin
  w.flag := GLDWF_BOT;
  tex := w.gltexture;
  w.ul := OU(tex, seg);
  w.ur := w.ul + (linelength / tex.realtexwidth);
  if peg then
  begin
    w.vb := OV_PEG(tex, seg, v_offset) + tex.heightscale;
    w.vt := w.vb - lineheight / tex.buffer_height;
  end
  else
  begin
    w.vt := OV(tex, seg);
    w.vb := w.vt + lineheight / tex.buffer_height;
  end;
end;

procedure ADDSKYTEXTURE(wall: PGLWall);
begin
  wall.gltexture := gld_RegisterTexture(skytexture, false);
  wall.skyyaw := -2.0 * ((yaw + 90.0) / 90.0);
  wall.skyymid := 200.0 / 319.5;
  wall.flag := GLDWF_SKY;
  dodrawsky := true;
end;

procedure ADDWALL(wall: PGLWall);
begin
  if gld_drawinfo.num_walls >= gld_drawinfo.max_walls then
  begin
    gld_drawinfo.max_walls := gld_drawinfo.max_walls + 128;
    gld_drawinfo.walls := Z_Realloc(gld_drawinfo.walls, gld_drawinfo.max_walls * SizeOf(GLWall), PU_LEVEL, nil);
  end;
  gld_AddDrawItem(GLDIT_WALL, gld_drawinfo.num_walls);
  gld_drawinfo.walls[gld_drawinfo.num_walls] := wall^;
  inc(gld_drawinfo.num_walls);
end;

procedure gld_AddFlatEx(sectornum: integer; pic, zheight: integer);
var
  {$IFDEF DOOM}
  tempsec: sector_t; // needed for R_FakeFlat
  {$ENDIF}
  sector: Psector_t; // the sector we want to draw
  flat: GLFlat;
begin
  if sectornum < 0 then
    exit;

  if sectorrenderedflatex = nil then
    exit;

  if sectorrenderedflatex[sectornum] = rendermarker then
    exit;

  sectorrenderedflatex[sectornum] := rendermarker;

  flat.sectornum := sectornum;
  sector := @sectors[sectornum]; // get the sector
  {$IFDEF DOOM}
  sector := R_FakeFlat(sector, @tempsec, nil, nil, false); // for boom effects
  {$ENDIF}
  flat.ceiling := true;

  // get the texture. flattranslation is maintained by doom and
  // contains the number of the current animation frame
  flat.gltexture := gld_RegisterFlat(R_GetLumpForFlat(pic), true);
  if flat.gltexture = nil then
    exit;
  // get the lightlevel
  flat.light := gld_CalcLightLevel(sector.lightlevel + (extralight shl 5));
  // calculate texture offsets
  {$IFDEF DOOM}
  flat.hasoffset := (sector.ceiling_xoffs <> 0) or (sector.ceiling_yoffs <> 0);
  flat.uoffs := sector.ceiling_xoffs / FLATUVSCALE;
  flat.voffs := sector.ceiling_yoffs / FLATUVSCALE;
  {$ENDIF}

  // get height from plane
  flat.z := zheight / MAP_SCALE;

  if gld_drawinfo.num_flats >= gld_drawinfo.max_flats then
  begin
    gld_drawinfo.max_flats := gld_drawinfo.max_flats + 128;
    gld_drawinfo.flats := Z_Realloc(gld_drawinfo.flats, gld_drawinfo.max_flats * SizeOf(GLFlat), PU_LEVEL, nil);
  end;
  gld_AddDrawItem(GLDIT_FLAT, gld_drawinfo.num_flats);
  gld_drawinfo.flats[gld_drawinfo.num_flats] := flat;
  inc(gld_drawinfo.num_flats);
end;

procedure gld_AddWall(seg: Pseg_t);
var
  wall: GLWall;
  temptex: PGLTexture;
  frontsector: Psector_t;
  backsector: Psector_t;
  lineheight: float;
  rellight: integer;
  floor_height, ceiling_height: integer;
  floormax, ceilingmin, linelen: integer;
  mip: float;
{$IFDEF DOOM}
  ftempsec: sector_t; // needed for R_FakeFlat
  btempsec: sector_t; // needed for R_FakeFlat
{$ENDIF}
  x: integer;
label
  bottomtexture;
begin
  // mark the segment as visible for auto map
  seg.linedef.flags := seg.linedef.flags or ML_MAPPED;

  if segrendered = nil then
    exit;

  if segrendered[seg.iSegID] = rendermarker then
    exit;

  segrendered[seg.iSegID] := rendermarker;

  x := seg.linedef.v1.x;
  if (x < 0) and (viewx > 0) then
    exit;
  if (x > 0) and (viewx < 0) then
    exit;

  if seg.frontsector = nil then
    exit;

  {$IFDEF DOOM}
  frontsector := R_FakeFlat(seg.frontsector, @ftempsec, nil, nil, false); // for boom effects
  {$ELSE}
  frontsector := seg.frontsector;
  {$ENDIF}
  wall.glseg := @gl_segs[seg.iSegID];

  if seg.linedef.dx = 0 then
    rellight := 16 // 8
  else if seg.linedef.dy = 0 then
    rellight := -16 // -8
  else
    rellight := 0;

  wall.light := gld_CalcLightLevel(frontsector.lightlevel + rellight + (extralight shl 5));
  wall.alpha := 1.0; // JVAL: SOS Lower values for transparent walls!
  wall.gltexture := nil;

  if seg.backsector = nil then // onesided
  begin
    if frontsector.ceilingpic = skyflatnum then
    begin
      wall.ytop := 255.0;
      wall.ybottom := frontsector.ceilingheight / MAP_SCALE;
      ADDSKYTEXTURE(@wall);
      ADDWALL(@wall);
    end;
    if frontsector.floorpic = skyflatnum then
    begin
      wall.ytop := frontsector.floorheight / MAP_SCALE;
      wall.ybottom := -255.0;
      ADDSKYTEXTURE(@wall);
      ADDWALL(@wall);
    end;
    temptex := gld_RegisterTexture(texturetranslation[seg.sidedef.midtexture], true);
    if temptex <> nil then
    begin
      wall.gltexture := temptex;
      CALC_Y_VALUES(@wall, lineheight, frontsector.floorheight, frontsector.ceilingheight);
      CALC_TEX_VALUES_MIDDLE1S(
        @wall, seg, seg.linedef.flags and ML_DONTPEGBOTTOM <> 0,
        seg.length, lineheight
      );
      ADDWALL(@wall);
    end;
  end
  // JVAL: This corrects some problems with MAP18 from Doom2 and other similar maps
  else if seg.backsector.linecount = 1 then
  begin
    if frontsector.ceilingpic = skyflatnum then
    begin
      wall.ytop := 255.0;
      wall.ybottom := frontsector.ceilingheight / MAP_SCALE;
      ADDSKYTEXTURE(@wall);
      ADDWALL(@wall);
    end;
    if frontsector.floorpic = skyflatnum then
    begin
      wall.ytop := frontsector.floorheight / MAP_SCALE;
      wall.ybottom := -255.0;
      ADDSKYTEXTURE(@wall);
      ADDWALL(@wall);
    end;
    temptex := gld_RegisterTexture(texturetranslation[seg.sidedef.toptexture], true);
    if temptex <> nil then
    begin
      wall.gltexture := temptex;
      CALC_Y_VALUES(@wall, lineheight, frontsector.floorheight, frontsector.ceilingheight);
      CALC_TEX_VALUES_MIDDLE1S(
        @wall, seg, seg.linedef.flags and ML_DONTPEGBOTTOM <> 0,
        seg.length, lineheight
      );
      ADDWALL(@wall);
    end;
  end
  else // twosided
  begin
    {$IFDEF DOOM}
    backsector := R_FakeFlat(seg.backsector, @btempsec, nil, nil, true); // for boom effects
    {$ELSE}
    backsector := seg.backsector;
    {$ENDIF}
    // toptexture
    ceiling_height := frontsector.ceilingheight;
    floor_height := backsector.ceilingheight;
    if frontsector.ceilingpic = skyflatnum then
    begin
      wall.ytop := 255.0;
      if  // e6y
          // Fix for HOM in the starting area on Memento Mori map29 and on map30.
          // old code: (backsector.ceilingheight==backsector.floorheight) &&
          ((backsector.ceilingheight = backsector.floorheight) or (backsector.ceilingheight <= frontsector.floorheight)) and
           (backsector.ceilingpic = skyflatnum) then
      begin
        wall.ybottom := backsector.floorheight / MAP_SCALE;
        ADDSKYTEXTURE(@wall);
        ADDWALL(@wall);
      end
      else
      begin
        if texturetranslation[seg.sidedef.toptexture] <> NO_TEXTURE then
        begin
          // e6y
          // It corrects some problem with sky, but I do not remember which one
          // old code: wall.ybottom= frontsector.ceilingheight/MAP_SCALE;
          if frontsector.ceilingheight > backsector.ceilingheight then
            wall.ybottom := frontsector.ceilingheight / MAP_SCALE
          else
            wall.ybottom := backsector.ceilingheight / MAP_SCALE;

          ADDSKYTEXTURE(@wall);
          ADDWALL(@wall);
        end
        else if (backsector.ceilingheight <= frontsector.floorheight) or
                (backsector.ceilingpic <> skyflatnum) then
        begin
          wall.ybottom := backsector.ceilingheight / MAP_SCALE;
          ADDSKYTEXTURE(@wall);
          ADDWALL(@wall);
        end;
      end;
    end;
    if floor_height < ceiling_height then
    begin
      if not ((frontsector.ceilingpic = skyflatnum) and (backsector.ceilingpic = skyflatnum)) then
      begin
        temptex := gld_RegisterTexture(texturetranslation[seg.sidedef.toptexture], true);
        if temptex <> nil then
        begin
          wall.gltexture := temptex;
          CALC_Y_VALUES2(@wall, lineheight, floor_height, ceiling_height);
          CALC_TEX_VALUES_TOP(
            @wall, seg, (seg.linedef.flags and ML_DONTPEGTOP) = 0,
            seg.length, lineheight
          );
          ADDWALL(@wall);
        end
        else if (backsector <> nil) and (seg.linedef.renderflags and LRF_ISOLATED = 0) and
                (frontsector.ceilingpic <> skyflatnum) and (backsector.ceilingpic <> skyflatnum) then
        begin
       //   gld_AddFlatEx(seg.frontsector.iSectorID, seg.backsector.ceilingpic, seg.frontsector.floorheight);
        end;
      end;
    end;

    // midtexture
    temptex := gld_RegisterTexture(texturetranslation[seg.sidedef.midtexture], true);
    if temptex <> nil then
    begin
      wall.gltexture := temptex;
      if seg.linedef.flags and ML_DONTPEGBOTTOM > 0 then
      begin
        if seg.backsector.ceilingheight <= seg.frontsector.floorheight then
          goto bottomtexture;
        floor_height := gl_i_max(seg.frontsector.floorheight, seg.backsector.floorheight) + seg.sidedef.rowoffset;
        ceiling_height := floor_height + (temptex.realtexheight * FRACUNIT);
      end
      else
      begin
        if seg.backsector.ceilingheight <= seg.frontsector.floorheight then
          goto bottomtexture;
        ceiling_height := gl_i_min(seg.frontsector.ceilingheight, seg.backsector.ceilingheight) + seg.sidedef.rowoffset;
        floor_height := ceiling_height - (temptex.realtexheight * FRACUNIT);
      end;

      mip := temptex.realtexheight / temptex.buffer_height;
      if seg.sidedef.bottomtexture <> 0 then
        floormax := gl_i_max(seg.frontsector.floorheight, seg.backsector.floorheight)
      else
        floormax := floor_height;
      if seg.sidedef.toptexture <> 0 then
        ceilingmin := gl_i_min(seg.frontsector.ceilingheight, seg.backsector.ceilingheight)
      else
        ceilingmin := ceiling_height;
      linelen := abs(ceiling_height - floor_height);
      wall.ytop := gl_i_min(ceilingmin, ceiling_height) / MAP_SCALE;
      wall.ybottom := gl_i_max(floormax, floor_height) / MAP_SCALE;
      wall.flag := GLDWF_M2S;
      wall.ul := OU(temptex, seg);
      wall.ur := wall.ul + (seg.length / temptex.buffer_width);
      if floormax <= floor_height then
        wall.vb := mip
      else
        wall.vb := mip * (ceiling_height - floormax) / linelen;
      if ceilingmin >= ceiling_height then
        wall.vt := 0.0
      else
        wall.vt := mip * (ceiling_height - ceilingmin) / linelen;
{      if (seg.linedef.tranlump >= 0) and general_translucency)
        wall.alpha= tran_filter_pct/100.0;}
      ADDWALL(@wall);
      wall.alpha := 1.0;
    end;

bottomtexture:
    ceiling_height := backsector.floorheight;
    floor_height := frontsector.floorheight;
    if frontsector.floorpic = skyflatnum then
    begin
      wall.ybottom := -255.0;
      if (
          (backsector.ceilingheight = backsector.floorheight) and
          (backsector.floorpic = skyflatnum)
         ) then
      begin
        wall.ytop := backsector.floorheight / MAP_SCALE;
        ADDSKYTEXTURE(@wall);
        ADDWALL(@wall);
      end
      else
      begin
        if texturetranslation[seg.sidedef.bottomtexture] <> NO_TEXTURE then
        begin
          wall.ytop := frontsector.floorheight / MAP_SCALE;
          ADDSKYTEXTURE(@wall);
          ADDWALL(@wall);
        end
        else
          if (backsector.floorheight >= frontsector.ceilingheight) or
             (backsector.floorpic <> skyflatnum) then
          begin
            wall.ytop := backsector.floorheight / MAP_SCALE;
            ADDSKYTEXTURE(@wall);
            ADDWALL(@wall);
          end;
      end;
    end;
    if floor_height < ceiling_height then
    begin
      if (frontsector.floorpic <> skyflatnum) and // JVAL 21/5/2011
         (backsector.floorheight > frontsector.floorheight) and
         (texturetranslation[seg.sidedef.bottomtexture] = NO_TEXTURE) then
      begin
      //  gld_AddFlatEx(seg.frontsector.iSectorID, seg.backsector.floorpic, seg.backsector.floorheight);
      end
      else
      begin
        temptex := gld_RegisterTexture(texturetranslation[seg.sidedef.bottomtexture], true);
        if temptex <> nil then
        begin
          wall.gltexture := temptex;
          CALC_Y_VALUES2(@wall, lineheight, floor_height, ceiling_height);
          CALC_TEX_VALUES_BOTTOM(
            @wall, seg, (seg.linedef.flags and ML_DONTPEGBOTTOM) <> 0,
            seg.length, lineheight,
            floor_height - frontsector.ceilingheight
          );
          ADDWALL(@wall);
        end
        else if (backsector <> nil) and (seg.linedef.renderflags and LRF_ISOLATED = 0) and
                (frontsector.ceilingpic <> skyflatnum) and (backsector.ceilingpic <> skyflatnum) then
        begin
          gld_AddFlatEx(seg.frontsector.iSectorID, seg.backsector.floorpic, seg.frontsector.floorheight);
        end;
      end;
    end;
  end;
end;

procedure gld_PreprocessSegs;
var
  i: integer;
begin
  gl_segs := Z_Malloc(numsegs * SizeOf(TGLSeg), PU_LEVEL, nil);
  for i := 0 to numsegs - 1 do
  begin
    gl_segs[i].x1 := -segs[i].v1.x / MAP_SCALE;
    gl_segs[i].z1 :=  segs[i].v1.y / MAP_SCALE;
    gl_segs[i].x2 := -segs[i].v2.x / MAP_SCALE;
    gl_segs[i].z2 :=  segs[i].v2.y / MAP_SCALE;
  end;
end;

(*****************
 *               *
 * Flats         *
 *               *
 *****************)

procedure gld_DrawFlat(flat: PGLFlat);
var
  loopnum, i: integer; // current loop number
  currentloop: PGLLoopDef; // the current loop
  glsec: PGLSector;
begin
  if flat.sectornum < 0 then
    exit;

  glsec := @sectorloops[flat.sectornum];

  if glsec.list_f = 0 then
  begin
    if glsec.loopcount > 0 then
    begin
      glsec.list_f := glGenLists(1);

      if glsec.list_f > 0 then
      begin
        glNewList(glsec.list_f, GL_COMPILE);

        for loopnum := 0 to glsec.loopcount - 1 do
        begin
          // set the current loop
          currentloop := @glsec.loops[loopnum];
          glBegin(currentloop.mode);
          glNormal3f(0.0, 1.0, 0.0);
          for i := currentloop.vertexindex to currentloop.vertexindex + currentloop.vertexcount - 1 do
          begin
            glTexCoord2fv(@gld_texcoords[i]);
            glVertex3fv(@gld_vertexes[i]);
          end;
          glEnd;
        end;

        glEndList;
      end
      else
        glsec.list_f := GL_BAD_LIST;

      glsec.list_c := glGenLists(1);

      if glsec.list_c > 0 then
      begin
        glNewList(glsec.list_c, GL_COMPILE);

        for loopnum := 0 to glsec.loopcount - 1 do
        begin
          // set the current loop
          currentloop := @glsec.loops[loopnum];
          glBegin(currentloop.mode);
          glNormal3f(0.0, -1.0, 0.0);
          for i := currentloop.vertexindex to currentloop.vertexindex + currentloop.vertexcount - 1 do
          begin
            glTexCoord2fv(@gld_texcoords[i]);
            glVertex3fv(@gld_vertexes[i]);
          end;
          glEnd;
        end;

        glEndList;
      end
      else
        glsec.list_c := GL_BAD_LIST;

      glsec.list_nonormal := glGenLists(1);

      if glsec.list_nonormal > 0 then
      begin
        glNewList(glsec.list_nonormal, GL_COMPILE);

        for loopnum := 0 to glsec.loopcount - 1 do
        begin
          // set the current loop
          currentloop := @glsec.loops[loopnum];
          glBegin(currentloop.mode);
          for i := currentloop.vertexindex to currentloop.vertexindex + currentloop.vertexcount - 1 do
          begin
            glTexCoord2fv(@gld_texcoords[i]);
            glVertex3fv(@gld_vertexes[i]);
          end;
          glEnd;
        end;

        glEndList;

        Z_Free(glsec.loops);
      end
      else
        glsec.list_nonormal := GL_BAD_LIST;
    end
    else
    begin
      glsec.list_f := GL_BAD_LIST;
      glsec.list_c := GL_BAD_LIST;
      glsec.list_nonormal := GL_BAD_LIST;
    end;
  end;

  if gl_uselightmaps then
  begin
    glActiveTextureARB(GL_TEXTURE1_ARB);
    glMatrixMode(GL_TEXTURE);
    glPushMatrix;
    glTranslatef(0, flat.z * MAP_COEFF / (LIGHTMAPSIZEY * LIGHTMAPUNIT), 0);
    glActiveTextureARB(GL_TEXTURE0_ARB);
  end;

  gld_BindFlat(flat.gltexture);
  if terrainandskycullregion then
    gld_StaticLight(flat.light);
  glMatrixMode(GL_MODELVIEW);
  glPushMatrix;
  glTranslatef(0.0, flat.z, 0.0);
  {$IFDEF DOOM}
  if flat.hasoffset then
  begin
    glMatrixMode(GL_TEXTURE);
    glPushMatrix;
    glTranslatef(flat.uoffs, flat.voffs, 0.0);
  end;
  {$ENDIF}
  // JVAL: Call the precalced list if available
  if terrainandskycullregion and (glsec.list_nonormal <> GL_BAD_LIST) then
    glCallList(glsec.list_nonormal)
  else if flat.ceiling and (glsec.list_c <> GL_BAD_LIST) and (not terrainandskycullregion) then
    glCallList(glsec.list_c)
  else if not flat.ceiling and (glsec.list_f <> GL_BAD_LIST) and (not terrainandskycullregion) then
    glCallList(glsec.list_f)
  else
  begin
    // go through all loops of this sector
    for loopnum := 0 to glsec.loopcount - 1 do
    begin
      // set the current loop
      currentloop := @glsec.loops[loopnum];
      glDrawArrays(currentloop.mode, currentloop.vertexindex, currentloop.vertexcount);
    end;
  end;
  {$IFDEF DOOM}
  if flat.hasoffset then
  begin
    glPopMatrix;
    glMatrixMode(GL_MODELVIEW);
  end;
  {$ENDIF}
  if gl_uselightmaps then
  begin
    glActiveTextureARB(GL_TEXTURE1_ARB);
    glMatrixMode(GL_TEXTURE);
    glPopMatrix;
    glMatrixMode(GL_MODELVIEW);
    glActiveTextureARB(GL_TEXTURE0_ARB);
  end;

  glPopMatrix;
end;

//
// gld_AddFlat
//
// This draws on flat for the sector 'num'
// The ceiling boolean indicates if the flat is a floor(false) or a ceiling(true)
//
procedure gld_AddFlat(sectornum: integer; ceiling: boolean; plane: Pvisplane_t);
var
  {$IFDEF DOOM}
  tempsec: sector_t; // needed for R_FakeFlat
  {$ENDIF}
  sector: Psector_t; // the sector we want to draw
  flat: GLFlat;
begin
  if sectornum < 0 then
    exit;

  flat.sectornum := sectornum;
  sector := @sectors[sectornum]; // get the sector
  {$IFDEF DOOM}
  sector := R_FakeFlat(sector, @tempsec, nil, nil, false); // for boom effects
  {$ENDIF}
  flat.ceiling := ceiling;
  if ceiling then // if it is a ceiling ...
  begin
    if sector.ceilingpic = skyflatnum then // don't draw if sky
      exit;
    // get the texture. flattranslation is maintained by doom and
    // contains the number of the current animation frame
    flat.gltexture := gld_RegisterFlat(R_GetLumpForFlat(sector.ceilingpic), true);
    if flat.gltexture = nil then
      exit;
    // get the lightlevel from floorlightlevel
    flat.light := gld_CalcLightLevel({$IFDEF DOOM}sector.ceilinglightlevel{$ELSE}sector.lightlevel{$ENDIF} + (extralight shl 5));
    // calculate texture offsets
    {$IFDEF DOOM}
    flat.hasoffset := (sector.ceiling_xoffs <> 0) or (sector.ceiling_yoffs <> 0);
    flat.uoffs := sector.ceiling_xoffs / FLATUVSCALE;
    flat.voffs := sector.ceiling_yoffs / FLATUVSCALE;
    {$ENDIF}
  end
  else // if it is a floor ...
  begin
    if sector.floorpic = skyflatnum then // don't draw if sky
      exit;
    // get the texture. flattranslation is maintained by doom and
    // contains the number of the current animation frame
    flat.gltexture := gld_RegisterFlat(R_GetLumpForFlat(sector.floorpic), true);
    if flat.gltexture = nil then
      exit;
    // get the lightlevel from ceilinglightlevel
    flat.light := gld_CalcLightLevel({$IFDEF DOOM}sector.floorlightlevel{$ELSE}sector.lightlevel{$ENDIF} + (extralight shl 5));
    // calculate texture offsets
    {$IFDEF DOOM}
    flat.hasoffset := (sector.floor_xoffs <> 0) or (sector.floor_yoffs <> 0);
    flat.uoffs := sector.floor_xoffs / FLATUVSCALE;
    flat.voffs := sector.floor_yoffs / FLATUVSCALE;
    {$ENDIF}
  end;

  // get height from plane
  flat.z := plane.height / MAP_SCALE;

  if gld_drawinfo.num_flats >= gld_drawinfo.max_flats then
  begin
    gld_drawinfo.max_flats := gld_drawinfo.max_flats + 128;
    gld_drawinfo.flats := Z_Realloc(gld_drawinfo.flats, gld_drawinfo.max_flats * SizeOf(GLFlat), PU_LEVEL, nil);
  end;
  gld_AddDrawItem(GLDIT_FLAT, gld_drawinfo.num_flats);
  gld_drawinfo.flats[gld_drawinfo.num_flats] := flat;
  inc(gld_drawinfo.num_flats);
end;

function gld_AddPlane(subsectornum: integer; floor, ceiling: Pvisplane_t): boolean;
var
  subsector: Psubsector_t;
  secID: integer;
  x: integer;
begin
  result := false;
  // check if all arrays are allocated
  if sectorrendered = nil then
    exit;

  subsector := @subsectors[subsectornum];
  {$IFDEF DEBUG}
  if subsector = nil then // JVAL unused?
    exit;
  {$ENDIF}

  secID := subsector.sector.iSectorID;

  if sectorrendered[secID] <> rendermarker then // if not already rendered
  begin
    x := sectors[secID].lines[0].v1.x;
    if (x < 0) and (viewx > 0) then
    begin
      sectorrendered[secID] := rendermarker;
      exit;
    end;
    if (x > 0) and (viewx < 0) then
    begin
      sectorrendered[secID] := rendermarker;
      exit;
    end;

    // render the floor
    if floor <> nil then
      if floor.height < viewz then
        gld_AddFlat(secID, false, floor);
    // render the ceiling
    if ceiling <> nil then
      if ceiling.height > viewz then
        gld_AddFlat(secID, true, ceiling);
    // set rendered true
    sectorrendered[secID] := rendermarker;
    result := true;
  end;
end;

(*************************
 *                       *
 * Dynamic Lights        *
 *                       *
 *************************)

procedure gld_MarkDLights(sprite: PGLSprite);
var
  olddlitems: integer;
  l: PGLDRenderLight;
  i: integer;
  dx, dy, dz: single;
  xdist, ydist, zdist: single;
  psl: Pdlsortitem_t;
begin
  if sprite.dlights = nil then
    exit;

  xdist := camera.position[0] - sprite.x;
  ydist := camera.position[1] - sprite.y;
  zdist := camera.position[2] - sprite.z;

  for i := 0 to sprite.dlights.Count - 1 do
  begin
    l := gld_GetDynamicLight(sprite.dlights.Numbers[i]);
    if numdlitems >= realdlitems then
    begin
      olddlitems := realdlitems;
      realdlitems := numdlitems + 32;
      realloc(pointer(dlbuffer), olddlitems * SizeOf(dlsortitem_t), realdlitems * SizeOf(dlsortitem_t));
    end;

    psl := @dlbuffer[numdlitems];
    psl.l := l;
//    Psubsector_t(sprite.mo.subsector).sector.floorheight
    dx := xdist - l.x;
    dy := ydist - l.y;
    dz := zdist - l.z;
    psl.squaredist := dx * dx + dy * dy + dz * dz;
    psl.x := sprite.x + l.x;
    psl.y := sprite.y + l.y;
    psl.z := sprite.z + l.z;
    inc(numdlitems);
  end;
end;

const
  shadow: GLDRenderLight = (
    r: 0.0; g: 0.0;  b: 0.0;
    radious: 0.25;     // radious
    x: 0.0; y: 0.0; z: 0.0;     // Offset
    shadow: true; // JVAL: wolf
  );

procedure gld_MarkDShadows(sprite: PGLSprite);
var
  olddlitems: integer;
  dx, dy, dz: single;
  xdist, ydist, zdist: single;
  psl: Pdlsortitem_t;
begin
  if sprite.dlights <> nil then
    exit;    
  if sprite.models = nil then
    Exit;
    
  xdist := camera.position[0] - sprite.x;
  ydist := camera.position[1] - sprite.y;
  zdist := camera.position[2] - sprite.z;

  if numdlitems >= realdlitems then
  begin
    olddlitems := realdlitems;
    realdlitems := numdlitems + 32;
    realloc(pointer(dlbuffer), olddlitems * SizeOf(dlsortitem_t), realdlitems * SizeOf(dlsortitem_t));
  end;

  psl := @dlbuffer[numdlitems];
  psl.l := @shadow;
  dx := xdist;
  dy := ydist;
  dz := zdist;
  psl.squaredist := dx * dx + dy * dy + dz * dz;
  psl.x := sprite.x;
  psl.y := sprite.y;
  psl.z := sprite.z;
  inc(numdlitems);
end;

(*****************
 *               *
 * Sprites       *
 *               *
 *****************)

function gld_FindNextModelFrame(const mo: PMobj_t; const modelidx: integer): integer;
var
  i: integer;
  idx: integer;
  stnum: integer;
  st: Pstate_t;
begin
  stnum := Ord(mo.state.nextstate);
  if stnum < 1 then
  begin
    result := -1;
    exit;
  end;
  st := @states[stnum];
  if st.models = nil then
  begin
    I_DevWarning('gld_FindNextModelFrame(): Missing model information on state %s'#13#10, [statenames.Strings[stnum]]);
    result := -1;
    exit;
  end;
  for i := 0 to st.models.Count - 1 do
  begin
    idx := st.models.Numbers[i];
    if modelstates[idx].modelidx = modelidx then
    begin
      result := modelstates[idx].startframe;
      exit;
    end;
  end;
  result := -1;
end;

procedure gld_DrawModel(sprite: PGLSprite; const idx: integer);
var
  info: Pmodelstate_t;
  texitem: Ptexturemanagetitem_t;
  modelinf: Pmodelmanageritem_t;
  nextframe: integer;
begin
  info := @modelstates[idx];

  if sprite.flags and GLS_SHADOW <> 0 then
  begin
    glBlendFunc(GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA);
    glAlphaFunc(GL_GEQUAL, 0.1);
    glColor4f(0.2, 0.2, 0.2, 0.33);
  end
  else
  begin
    if sprite.flags and GLS_TRANSPARENT <> 0 then
      gld_StaticLightAlpha(sprite.light, sprite.alpha)
    else if info.transparency < 0.9999 then
      gld_StaticLightAlpha(sprite.light, info.transparency)
    else
      gld_StaticLight(sprite.light);
  end;

  last_gltexture := nil;
  texitem := @modeltexturemanager.items[info.texture];
  if texitem.tex = 0 then
  begin
    texitem.tex := gld_LoadExternalTexture(texitem.name, true, GL_CLAMP);
    if texitem.tex = 0 then
      I_DevError('gld_DrawModel(): Can not load texture %s'#13#10, [texitem.name]);
  end;

  glBindTexture(GL_TEXTURE_2D, texitem.tex);

  modelinf := @modelmanager.items[info.modelidx];
  if modelinf.model = nil then
  begin
    modelinf.model := TModel.Create(modelinf.name, modelinf.offset, modelinf.scale, modelinf.framemerge);
    if modelinf.model = nil then
    begin
      I_Warning('gld_DrawModel(): Can not load model %s'#13#10, [modelinf.name]);
      exit;
    end;
    modelinf.model.DrawSimple(info.startframe);
    exit;
  end;
  {$IFDEF DEBUG}
  printf('**drawing model %d'#13#10, [idx]);
  {$ENDIF}

  if gl_smoothmodelmovement and not isgamesuspended and (P_AproxDistance(sprite.mo.x - viewx, sprite.mo.y - viewy) < MODELINTERPOLATERANGE)  then
  begin
    nextframe := gld_FindNextModelFrame(sprite.mo, info.modelidx);
    modelinf.model.Draw(info.startframe, nextframe, 1.0 - (sprite.mo.tics - ticfrac / FRACUNIT) / sprite.mo.state.tics);
  end
  else
    modelinf.model.DrawSimple(info.startframe);
end;

procedure gld_DrawModels(sprite: PGLSprite);
var
  i: integer;
begin
  gld_EnableSunLight;
  if gl_uselightmaps then
  begin
    glActiveTextureARB(GL_TEXTURE1_ARB);
    glMatrixMode(GL_TEXTURE);
    glPushMatrix;
    glTranslatef(sprite.x * MAP_COEFF / (LIGHTMAPSIZEX * LIGHTMAPUNIT),
                 sprite.y * MAP_COEFF / (LIGHTMAPSIZEY * LIGHTMAPUNIT),
                 sprite.z * MAP_COEFF / (LIGHTMAPSIZEZ * LIGHTMAPUNIT));
    glActiveTextureARB(GL_TEXTURE0_ARB);
  end;

  glMatrixMode(GL_MODELVIEW);
  glPushMatrix;

  glTranslatef(sprite.x, sprite.y, sprite.z);
  glRotatef(sprite.mo.angle / (ANGLE_MAX / 360.0) - 90.0, 0.0, 1.0, 0.0);

  // JVAL
  // Draw light effects (only if not invulnerability)
  if uselightboost then
    if not lightdeflumppresent then
      if players[displayplayer].fixedcolormap <> 32 then
      // JVAL: Use old color effects only if LIGHTDEF lump not found
        if sprite.flags and GLS_LIGHT <> 0 then
        begin
          if sprite.flags and GLS_WHITELIGHT <> 0 then
            gld_SetUplight(1.0, 1.0, 1.0)
          else if sprite.flags and GLS_REDLIGHT <> 0 then
            gld_SetUplight(1.0, 0.0, 0.0)
          else if sprite.flags and GLS_GREENLIGHT <> 0 then
            gld_SetUplight(0.0, 1.0, 0.0)
          else if sprite.flags and GLS_BLUELIGHT <> 0 then
            gld_SetUplight(0.0, 0.0, 1.0)
          else if sprite.flags and GLS_YELLOWLIGHT <> 0 then
            gld_SetUplight(1.0, 1.0, 0.0);
          glBegin(GL_TRIANGLE_STRIP);
            glTexCoord2f(0.0, 0.0); glVertex3f(2.0 * sprite.x1, 2.0 * sprite.y1, 0.01);
            glTexCoord2f(1.0, 0.0); glVertex3f(2.0 * sprite.x2, 2.0 * sprite.y1, 0.01);
            glTexCoord2f(0.0, 1.0); glVertex3f(2.0 * sprite.x1, 2.0 * sprite.y2, 0.01);
            glTexCoord2f(1.0, 1.0); glVertex3f(2.0 * sprite.x2, 2.0 * sprite.y2, 0.01);
          glEnd;
          glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
          glAlphaFunc(GL_GEQUAL, 0.5);
        end;

  for i := 0 to sprite.models.Count - 1 do
    gld_DrawModel(sprite, sprite.models.Numbers[i]);

  glPopMatrix;

  if gl_uselightmaps then
  begin
    glActiveTextureARB(GL_TEXTURE1_ARB);
    glMatrixMode(GL_TEXTURE);
    glPopMatrix;
    glMatrixMode(GL_MODELVIEW);
    glActiveTextureARB(GL_TEXTURE0_ARB);
  end;

  if sprite.flags and (GLS_SHADOW or GLS_TRANSPARENT) <> 0 then
  begin
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glAlphaFunc(GL_GEQUAL, 0.5);
  end;
  glColor3f(1.0, 1.0, 1.0);
  gld_DisableSunLight;

end;

procedure gld_DrawSprite(sprite: PGLSprite);
begin
  if gl_drawmodels and (sprite.models <> nil) then
  begin
    gld_DrawModels(sprite);
    exit;
  end;

  if gl_uselightmaps then
  begin
    glActiveTextureARB(GL_TEXTURE1_ARB);
    glMatrixMode(GL_TEXTURE);
    glPushMatrix;
    glTranslatef(sprite.x * MAP_COEFF / (LIGHTMAPSIZEX * LIGHTMAPUNIT),
                 sprite.y * MAP_COEFF / (LIGHTMAPSIZEY * LIGHTMAPUNIT),
                 sprite.z * MAP_COEFF / (LIGHTMAPSIZEZ * LIGHTMAPUNIT));
    glActiveTextureARB(GL_TEXTURE0_ARB);
  end;

  glMatrixMode(GL_MODELVIEW);
  glPushMatrix;
  glTranslatef(sprite.x, sprite.y, sprite.z);
  glRotatef(inv_yaw, 0.0, 1.0, 0.0);

  // JVAL
  // Draw light effects (only if not invulnerability)
  if uselightboost then
    if not lightdeflumppresent then
      if players[displayplayer].fixedcolormap <> 32 then
      // JVAL: Use old color effects only if LIGHTDEF lump not found
        if sprite.flags and GLS_LIGHT <> 0 then
        begin
          if sprite.flags and GLS_WHITELIGHT <> 0 then
            gld_SetUplight(1.0, 1.0, 1.0)
          else if sprite.flags and GLS_REDLIGHT <> 0 then
            gld_SetUplight(1.0, 0.0, 0.0)
          else if sprite.flags and GLS_GREENLIGHT <> 0 then
            gld_SetUplight(0.0, 1.0, 0.0)
          else if sprite.flags and GLS_BLUELIGHT <> 0 then
            gld_SetUplight(0.0, 0.0, 1.0)
          else if sprite.flags and GLS_YELLOWLIGHT <> 0 then
            gld_SetUplight(1.0, 1.0, 0.0);
          glBegin(GL_TRIANGLE_STRIP);
            glTexCoord2f(0.0, 0.0); glVertex3f(2.0 * sprite.x1, 2.0 * sprite.y1, 0.01);
            glTexCoord2f(1.0, 0.0); glVertex3f(2.0 * sprite.x2, 2.0 * sprite.y1, 0.01);
            glTexCoord2f(0.0, 1.0); glVertex3f(2.0 * sprite.x1, 2.0 * sprite.y2, 0.01);
            glTexCoord2f(1.0, 1.0); glVertex3f(2.0 * sprite.x2, 2.0 * sprite.y2, 0.01);
          glEnd;
          glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
          glAlphaFunc(GL_GEQUAL, 0.5);
        end;

  gld_BindPatch(sprite.gltexture, sprite.cm);

  if sprite.flags and GLS_SHADOW <> 0 then
  begin
    glBlendFunc(GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA);
    glAlphaFunc(GL_GEQUAL, 0.1);
    glColor4f(0.2, 0.2, 0.2, 0.33);
  end
  else
  begin
    if sprite.flags and GLS_TRANSPARENT <> 0 then
      gld_StaticLightAlpha(sprite.light, sprite.alpha)
    else
      gld_StaticLight(sprite.light);
  end;
  glBegin(GL_TRIANGLE_STRIP);
    glTexCoord2f(sprite.ul, sprite.vt); glVertex3f(sprite.x1, sprite.y1, 0.0);
    glTexCoord2f(sprite.ur, sprite.vt); glVertex3f(sprite.x2, sprite.y1, 0.0);
    glTexCoord2f(sprite.ul, sprite.vb); glVertex3f(sprite.x1, sprite.y2, 0.0);
    glTexCoord2f(sprite.ur, sprite.vb); glVertex3f(sprite.x2, sprite.y2, 0.0);
  glEnd;

  glPopMatrix;

  if gl_uselightmaps then
  begin
    glActiveTextureARB(GL_TEXTURE1_ARB);
    glMatrixMode(GL_TEXTURE);
    glPopMatrix;
    glMatrixMode(GL_MODELVIEW);
    glActiveTextureARB(GL_TEXTURE0_ARB);
  end;

  if sprite.flags and (GLS_SHADOW or GLS_TRANSPARENT) <> 0 then
  begin
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glAlphaFunc(GL_GEQUAL, 0.5);
  end;
  glColor3f(1.0, 1.0, 1.0);
end;

const
  COS16TABLE: array[0..16] of float = (
    1.0000000000,
    0.9238795042,
    0.7071067691,
    0.3826834261,
   -0.0000000000,
   -0.3826834261,
   -0.7071067691,
   -0.9238795042,
   -1.0000000000,
   -0.9238795042,
   -0.7071067691,
   -0.3826834261,
    0.0000000000,
    0.3826834261,
    0.7071067691,
    0.9238795042,
    1.0000000000
   );

  SIN16TABLE: array[0..16] of float = (
    0.0000000000,
    0.3826834261,
    0.7071067691,
    0.9238795042,
    1.0000000000,
    0.9238795042,
    0.7071067691,
    0.3826834261,
   -0.0000000000,
   -0.3826834261,
   -0.7071067691,
   -0.9238795042,
   -1.0000000000,
   -0.9238795042,
   -0.7071067691,
   -0.3826834261,
    0.0000000000
   );


//
//  gld_DrawDLight()
//  JVAL: Draw a single dynamic light
//
procedure gld_DrawDLight(const pdls: Pdlsortitem_t);
var
  i: integer;
  sz: float;
begin
  glPushMatrix;
  glTranslatef(pdls.x, pdls.y, pdls.z);
  glRotatef(inv_yaw, 0.0, 1.0, 0.0);

  sz := pdls.l.radious;
//  if GL_CheckVisibility(pdls.x, pdls.y, pdls.z, 2 * sz) then
  begin
    glBegin(GL_TRIANGLE_FAN);
      glColor4f(pdls.l.r * 0.2, pdls.l.g * 0.2, pdls.l.b * 0.2, 0.1);
      glVertex3f(0.0, 0.0, 0.05);
      glColor4f(0.0, 0.0, 0.0, 0.1);
      for i := 0 to 16 do
        glVertex3f(sz * COS16TABLE[i], sz * SIN16TABLE[i], 0.05);
    glEnd;
  end;

  glPopMatrix;
end;

//
//  gld_SortDlights()
//  JVAL: Sort the dynamic lights according to square distance of camera
//        (note: closer light is first!)
//
procedure gld_SortDlights;

  procedure qsort(l, r: Integer);
  var
    i, j: Integer;
    tmp: dlsortitem_t;
    squaredist: float;
  begin
    repeat
      i := l;
      j := r;
      squaredist := dlbuffer[(l + r) shr 1].squaredist;
      repeat
        while dlbuffer[i].squaredist < squaredist do
          inc(i);
        while dlbuffer[j].squaredist > squaredist do
          dec(j);
        if i <= j then
        begin
          tmp := dlbuffer[i];
          dlbuffer[i] := dlbuffer[j];
          dlbuffer[j] := tmp;
          inc(i);
          dec(j);
        end;
      until i > j;
      if l < j then
        qsort(l, j);
      l := i;
    until i >= r;
  end;

begin
  if numdlitems > 0 then
    qsort(0, numdlitems - 1);
end;

//
//  gld_DrawDLights()
//  JVAL: Draw the marked dynamic lights
//
procedure gld_DrawDLights;
var
  pdls: Pdlsortitem_t;
  lastitem: dlsortitem_t;
begin
  if not uselightboost then
    exit;

  if numdlitems = 0 then
    exit;

  glMatrixMode(GL_MODELVIEW);
  glDepthMask(False);
  glDisable(GL_TEXTURE_2D);
  glDisable(GL_ALPHA_TEST);
  glBlendFunc(GL_ONE, GL_ONE);

  ZeroMemory(@lastitem, SizeOf(dlsortitem_t));
  // Draw each light in order
  pdls := @dlbuffer[numdlitems];
  while integer(pdls) <> integer(dlbuffer) do
  begin
    dec(pdls);
    if not pdls.l.shadow then //jval: WOLF
    begin
      if (pdls.l <> lastitem.l) or
        (pdls.x <> lastitem.x) or
        (pdls.y <> lastitem.y) or
        (pdls.z <> lastitem.z) then
      begin
        gld_DrawDLight(pdls);
        lastitem := pdls^;
      end;
    end;
  end;

  glDepthMask(True);
  glEnable(GL_TEXTURE_2D);
  glEnable(GL_ALPHA_TEST);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

end;

var
  plsmooth: TIntegerQueue;

procedure gld_AddSprite(vspr: Pvissprite_t);
var
  pSpr: Pmobj_t;
  sprite: GLSprite;
  voff, hoff: float;
  tex: PGLTexture;
  i: integer;
  sum1: integer;
  calcz: float;
  terrainz: integer;
  hack1: boolean;
  size1: integer;
begin
  pSpr := vspr.mo;
  if (viewx < -3000 * FRACUNIT) and (viewy < -3000 * FRACUNIT) then
    if (pSpr.x < -3000 * FRACUNIT) and (pSpr.y > -500 * FRACUNIT) then
      exit; 
  if (viewy > -500 * FRACUNIT) then
    if (pSpr.x < -3500 * FRACUNIT) and (pSpr.y < -3000 * FRACUNIT) then
      exit;
  if (viewx < 0) and (pSpr.x > 0) then
    exit;
  if (viewx > 0) and (pSpr.x < 0) then
    exit;
  sprite.scale := vspr.scale;
  if pSpr.frame and FF_FULLBRIGHT <> 0 then
    sprite.light := 1.0
  else
    sprite.light := gld_CalcLightLevel(Psubsector_t(pSpr.subsector).sector.lightlevel + (extralight shl 5));
  sprite.cm := Ord(CR_LIMIT) + ((pSpr.flags and MF_TRANSLATION) shr (MF_TRANSSHIFT));
  sprite.gltexture := gld_RegisterPatch(vspr.patch + firstspritelump, sprite.cm);
  if sprite.gltexture = nil then
    exit;

  tex := sprite.gltexture;

  sprite.alpha := 0.0;
  sprite.flags := 0;
  if pSpr.flags and MF_SHADOW <> 0 then
    sprite.flags := GLS_SHADOW;
  if pSpr.flags_ex and MF_EX_TRANSPARENT <> 0 then // JVAL -> alpha here!!!!
  begin
    sprite.flags := sprite.flags or GLS_TRANSPARENT;
    sprite.alpha := tran_filter_pct / 100;
  end;
  if pSpr.renderstyle = mrs_translucent then
  begin
    sprite.flags := sprite.flags or GLS_TRANSPARENT;
    sprite.alpha := pSpr.alpha / FRACUNIT;
  end;
  if pSpr.flags_ex and MF_EX_LIGHT <> 0 then
  begin
    if pSpr.flags_ex and MF_EX_WHITELIGHT <> 0 then
      sprite.flags := sprite.flags or GLS_WHITELIGHT;
    if pSpr.flags_ex and MF_EX_REDLIGHT <> 0 then
      sprite.flags := sprite.flags or GLS_REDLIGHT;
    if pSpr.flags_ex and MF_EX_GREENLIGHT <> 0 then
      sprite.flags := sprite.flags or GLS_GREENLIGHT;
    if pSpr.flags_ex and MF_EX_BLUELIGHT <> 0 then
      sprite.flags := sprite.flags or GLS_BLUELIGHT;
    if pSpr.flags_ex and MF_EX_YELLOWLIGHT <> 0 then
      sprite.flags := sprite.flags or GLS_YELLOWLIGHT;
  end;

  sprite.dlights := vspr.mo.state.dlights;
  sprite.models := vspr.mo.state.models;
  sprite.mo := vspr.mo;

  sprite.x := -pSpr.x / MAP_SCALE;

  if sprite.mo.player <> nil then
  begin
    size1 := HU_FPS div 2;
    if size1 < 20 then
      size1 := 20;
    while plsmooth.Count > size1 do
      plsmooth.Remove;
    if (pSpr.subsector <> nil) and
       (Psubsector_t(pSpr.subsector) <> nil) and
       (Psubsector_t(pSpr.subsector).sector.tag = 1000) then
    begin
      terrainz := gld_GetDoomHeightFromCoordFixed(pSpr.x, pSpr.y);
      plsmooth.Add(terrainz + (pSpr.z - pSpr.floorz));

      sum1 := 0;
      for i := 0 to plsmooth.Count - 1 do
        sum1 := sum1 + plsmooth.Numbers[i];
      calcz := sum1 / plsmooth.Count;
      if calcz < terrainz + 8 * FRACUNIT then
        calcz := terrainz + 8 * FRACUNIT;
      sprite.y := calcz / MAP_SCALE;
    end
    else
    begin
      plsmooth.Clear; // }Add(pSpr.z);
      sprite.y := pSpr.z / MAP_SCALE;
    end;

  end
  else
  begin
    hack1 := (pSpr.x > - 2130 * FRACUNIT) and (pSpr.x < - 1990 * FRACUNIT) and (pSpr.y > - 3584 * FRACUNIT) and (pSpr.y < - 3490 * FRACUNIT);
    if hack1 then
      sprite.y := gld_GetDoomHeightFromCoord(pSpr.x, pSpr.y) + (pSpr.z - pSpr.floorz) / MAP_SCALE
    else if (pSpr.subsector <> nil) and
       (Psubsector_t(pSpr.subsector) <> nil) and
       (Psubsector_t(pSpr.subsector).sector.tag = 1000) then
        sprite.y := gld_GetDoomHeightFromCoord(pSpr.x, pSpr.y) + (pSpr.z - pSpr.floorz) / MAP_SCALE
    else
      sprite.y := pSpr.z / MAP_SCALE;
  end;

  sprite.z :=  pSpr.y / MAP_SCALE;

  sprite.vt := 0.0;
  sprite.vb := tex.height / tex.tex_height;
  if vspr.flip then
  begin
    sprite.ul := 0.0;
    sprite.ur := tex.width / tex.tex_width;
  end
  else
  begin
    sprite.ul := tex.width / tex.tex_width;
    sprite.ur := 0.0;
  end;
  hoff := tex.leftoffset / MAP_COEFF;
  voff := tex.topoffset / MAP_COEFF;
  sprite.x1 := hoff - (tex.realtexwidth / MAP_COEFF);
  sprite.x2 := hoff;
  sprite.y1 := voff;
  sprite.y2 := voff - (tex.realtexheight / MAP_COEFF);

  if (sprite.y2 < 0) and (vspr.mobjflags and (MF_SPAWNCEILING or MF_FLOAT or MF_MISSILE or MF_NOGRAVITY) = 0) then
  begin
    sprite.y1 := sprite.y1 - sprite.y2;
    sprite.y2 := 0.0;
    sprite.flags := sprite.flags or GLS_CLIPPED;
  end;

  if gld_drawinfo.num_sprites >= gld_drawinfo.max_sprites then
  begin
    gld_drawinfo.max_sprites := gld_drawinfo.max_sprites + 128;
    gld_drawinfo.sprites := Z_Realloc(gld_drawinfo.sprites, gld_drawinfo.max_sprites * SizeOf(GLSprite), PU_LEVEL, nil);
  end;
  gld_AddDrawItem(GLDIT_SPRITE, gld_drawinfo.num_sprites);
  gld_drawinfo.sprites[gld_drawinfo.num_sprites] := sprite;
  inc(gld_drawinfo.num_sprites);

  // JVAL: Mark the dynamic lights of the sprite
  gld_MarkDLights(@sprite);
  gld_MarkDShadows(@sprite); // jval: WOLF
end;

procedure gld_AddSun(sun: Pmobj_t);
begin
  gld_SetSun(-sun.x / MAP_SCALE, sun.z / MAP_SCALE, sun.y / MAP_SCALE);
end;

(*****************
 *               *
 * Draw          *
 *               *
 *****************)

procedure gld_StartFog;
{$IFDEF DOOM}
var
  FogColor: array[0..3] of TGLfloat; // JVAL: set blue fog color if underwater
{$ENDIF}
begin
  if use_fog then
    if players[displayplayer].fixedcolormap = 0 then
    begin
{$IFDEF DOOM}
      FogColor[0] := 0.25;
      FogColor[1] := 0.25;
      if R_UnderWater then
        FogColor[2] := 1.0
      else
        FogColor[2] := 0.25;
      FogColor[3] := 0.0;

      glFogfv(GL_FOG_COLOR, @FogColor);
{$ENDIF}

      if (players[displayplayer].mo <> nil) and
         (Psubsector_t(players[displayplayer].mo.subsector).sector.tag = 666) then
          glFogf(GL_FOG_DENSITY, fog_density / 300.0)
      else
          glFogf(GL_FOG_DENSITY, fog_density / 3000.0);


      glEnable(GL_FOG);
      exit;
    end;

  glDisable(GL_FOG);
end;

procedure gld_DrawScene(player: Pplayer_t);
var
  i, j, k, count: integer;
  max_scale: fixed_t;
  wallrange: integer;
  pglitem: PGLDrawItem;
  wall: PGLWall;
  seg: PGLSeg;
begin
  terrainandskycullregion := Psubsector_t(player.mo.subsector).sector.floorheight < -190 * FRACUNIT;

  if zaxisshift then
  begin
    wallrange := GLDWF_BOT;
    if not terrainandskycullregion then
      if not gl_stencilsky then
      begin
        if pitch <= -35.0 then
          gld_DrawSky(true, false)
        else if pitch >= 35.0 then
          gld_DrawSky(false, true)
        else
          gld_DrawSky(true, true);
      end;
  end
  else
    wallrange := GLDWF_SKYFLIP;

  // Sort the dynamic lights
  gld_SortDlights;

  gl_uselightmaps := gl_uselightmaps and canuselightmaps;

  if gl_uselightmaps then
    gld_ActivateLightmap;

  glEnableClientState(GL_VERTEX_ARRAY);
  glEnableClientState(GL_TEXTURE_COORD_ARRAY);

  gld_StartFog;
  gld_EnableSunLight;
  if not terrainandskycullregion then
    gld_DrawTerrain(camera.position[0], camera.position[1], camera.position[2]);
  gld_Draw3DFloors; // jval: WOLF
  gld_DisableSunLight;

{$IFDEF DEBUG}
  rendered_visplanes := 0;
  rendered_segs := 0;
  rendered_vissprites := 0;
{$ENDIF}

  glTexCoordPointer(2, GL_FLOAT, 0, gld_texcoords);
  glVertexPointer(3, GL_FLOAT, 0, gld_vertexes);

  // Floors and ceilings
  gld_EnableSunLight;
  for i := gld_drawinfo.num_drawitems downto 0 do
  begin
    pglitem := @gld_drawinfo.drawitems[i];
    if pglitem.itemtype = GLDIT_FLAT then
    begin
      {$IFDEF DEBUG}
      rendered_visplanes := rendered_visplanes + pglitem.itemcount;
      {$ENDIF}
      for j := pglitem.itemcount - 1 downto 0 do
        gld_DrawFlat(@gld_drawinfo.flats[j + pglitem.firstitemindex]);
    end;
  end;
  gld_DisableSunLight;

  // Walls
  for i := gld_drawinfo.num_drawitems downto 0 do
  begin
    pglitem := @gld_drawinfo.drawitems[i];
    if pglitem.itemtype = GLDIT_WALL then
    begin
      count := 0;
      for k := GLDWF_TOP to wallrange do
      begin
        if count >= pglitem.itemcount then
          continue;
        if gl_drawsky and (k >= GLDWF_SKY) then
        begin
          if gl_uselightmaps then
            gld_PauseLightmap;
          if gl_shared_texture_palette then
            glDisable(GL_SHARED_TEXTURE_PALETTE_EXT);
          glEnable(GL_TEXTURE_GEN_S);
          glEnable(GL_TEXTURE_GEN_T);
          glEnable(GL_TEXTURE_GEN_Q);
          glDisable(GL_FOG);
          glColor4fv(@gl_whitecolor);
        end;
        for j := pglitem.itemcount - 1 downto 0 do
          if gld_drawinfo.walls[j + pglitem.firstitemindex].flag = k then
          begin
            {$IFDEF DEBUG}
            inc(rendered_segs);
            {$ENDIF}
            inc(count);
            gld_DrawWall(@gld_drawinfo.walls[j + pglitem.firstitemindex]);
          end;
        if gl_drawsky and (k >= GLDWF_SKY) then
        begin
          gld_ResumeLightmap;
          gld_StartFog;
          glDisable(GL_TEXTURE_GEN_Q);
          glDisable(GL_TEXTURE_GEN_T);
          glDisable(GL_TEXTURE_GEN_S);
          if gl_shared_texture_palette then
            glEnable(GL_SHARED_TEXTURE_PALETTE_EXT);
        end;
      end;
    end;
  end;

  // Sprites
  if gld_drawinfo.num_sprites > 100 then
  begin
    for i := 0 to gld_drawinfo.num_sprites - 1 do
    begin
      {$IFDEF DEBUG}
      inc(rendered_vissprites);
      {$ENDIF}
      gld_DrawSprite(@gld_drawinfo.sprites[i]);
    end;
  end
  else for i := gld_drawinfo.num_drawitems downto 0 do
  begin
    pglitem := @gld_drawinfo.drawitems[i];
    if pglitem.itemtype = GLDIT_SPRITE then
    begin
      repeat
        max_scale := MAXINT;
        k := -1;
        for j := pglitem.itemcount - 1 downto 0 do
          if gld_drawinfo.sprites[j + pglitem.firstitemindex].scale < max_scale then
          begin
            max_scale := gld_drawinfo.sprites[j + pglitem.firstitemindex].scale;
            k := j + pglitem.firstitemindex;
          end;
        if k >= 0 then
        begin
          {$IFDEF DEBUG}
          inc(rendered_vissprites);
          {$ENDIF}
          gld_DrawSprite(@gld_drawinfo.sprites[k]);
          gld_drawinfo.sprites[k].scale := MAXINT;
        end;
      until max_scale = MAXINT;
    end;
  end;
                               
  if gl_uselightmaps then
    gld_DeActivateLightmap;

  gld_DrawDLights;

  glDisable(GL_FOG);

  if zaxisshift then
  begin
    if gl_drawsky and dodrawsky then
    begin

      if gl_stencilsky then
      begin
        glClear(GL_STENCIL_BUFFER_BIT); // Clear the stencil buffer the first time
        glEnable(GL_STENCIL_TEST);      // Turn on the stencil buffer test
        glDisable(GL_TEXTURE_2D);
        glColor4f(1.0, 1.0, 1.0, 1.0);
        glStencilFunc(GL_ALWAYS, 1, 1); // Setup the stencil buffer to write
        glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);  // a 1 everywhere the plane is.

        for j := 0 to gld_drawinfo.num_walls - 1 do
          if gld_drawinfo.walls[j].flag >= GLDWF_SKY then
          begin
            wall := @gld_drawinfo.walls[j];
            seg := wall.glseg;
            glBegin(GL_TRIANGLE_STRIP);
              glVertex3f(seg.x1, wall.ytop, seg.z1);
              glVertex3f(seg.x1, wall.ybottom, seg.z1);
              glVertex3f(seg.x2, wall.ytop, seg.z2);
              glVertex3f(seg.x2, wall.ybottom, seg.z2);
            glEnd;
          end;

        glStencilFunc(GL_EQUAL, 1, 1);          // Set the stencil buffer to update
        glStencilOp(GL_KEEP, GL_KEEP, GL_INCR); // only where it finds a 1 from the plane and increment the buffer

        glEnable(GL_TEXTURE_2D);

        if pitch <= -35.0 then
          gld_DrawSky(true, false)
        else if pitch >= 35.0 then
          gld_DrawSky(false, true)
        else
          gld_DrawSky(true, true);

        glEnable(GL_DEPTH_TEST);
        glDisable(GL_STENCIL_TEST); // Turn off the stencil buffer test

      end;
    end;
  end;


{$IFDEF DEBUG}
  printf('rendered_visplanes := %d'#13#10'rendered_segs := %d'#13#10'rendered_vissprites := %d'#13#10#13#10,
        [rendered_visplanes, rendered_segs, rendered_vissprites]);
{$ENDIF}

  glDisableClientState(GL_TEXTURE_COORD_ARRAY);
  glDisableClientState(GL_VERTEX_ARRAY);

end;

procedure gld_PreprocessLevel;
begin
  // preload graphics
  // JVAL
  // Precache if we have external textures
  if precache or externalpakspresent then
    gld_Precache;
  gld_PreprocessSectors;
  gld_PreprocessSegs;
  gld_InitTerrainData;
  ZeroMemory(@gld_drawinfo, SizeOf(GLDrawInfo));
  glTexCoordPointer(2, GL_FLOAT, 0, gld_texcoords);
  glVertexPointer(3, GL_FLOAT, 0, gld_vertexes);
end;

procedure gld_FreeSectorLists;
var
  i: integer;
begin
  for i := 0 to numsectors - 1 do
  begin
    if (sectorloops[i].list_c <> 0) and (sectorloops[i].list_c <> GL_BAD_LIST) then
      glDeleteLists(sectorloops[i].list_c, 1);
    if (sectorloops[i].list_f <> 0) and (sectorloops[i].list_f <> GL_BAD_LIST) then
      glDeleteLists(sectorloops[i].list_f, 1);
    if (sectorloops[i].list_nonormal <> 0) and (sectorloops[i].list_nonormal <> GL_BAD_LIST) then
      glDeleteLists(sectorloops[i].list_nonormal, 1);
  end;
end;

procedure gld_CleanMemory;
begin
  gld_FreeSectorLists;
  gld_CleanTextures;
  gld_CleanPatchTextures;
  gld_CleanModelTextures;
  gld_FreeTerrainData;
  gld_ResetSun;
end;

procedure R_ShutDownOpenGL;
begin
  if gl_initialized then
  begin
    gld_SkyDone;
    gld_FreeTerrainData;
    gld_DynamicLightsDone;
    gld_ModelsDone;
    gld_LightmapDone;
  end;
end;

procedure gld_ResetSmooth;
begin
  plsmooth.Clear;
end;

initialization
  plsmooth := TIntegerQueue.Create;

finalization
  plsmooth.Free;

end.

