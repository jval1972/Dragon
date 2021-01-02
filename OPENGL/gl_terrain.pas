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
//  DESCRIPTION:
//    Terrain
//
//------------------------------------------------------------------------------
//  Site  : https://sourceforge.net/projects/dragon-game/
//------------------------------------------------------------------------------

{$I dragon.inc}

unit gl_terrain;

interface

uses
  dglOpenGL,
  d_delphi,
  m_fixed,
  t_main;

procedure gld_InitTerrainData;

procedure gld_FreeTerrainData;

procedure gld_DrawTerrain(const x, y, z: single);

function gld_GetDoomHeightFromCoord(const x, y: fixed_t): float;

function gld_GetDoomHeightFromCoordFixed(const x, y: fixed_t): fixed_t;

function gld_TerrainAdjustFloorZ(const x, y: fixed_t; const floorz: fixed_t): fixed_t;

implementation

uses
  d_main,
  i_system, 
  g_game,
  r_draw,
  gl_defs,
  gl_tex,
  gl_render,
  gl_lightmaps,
  gl_frustum,
  w_pak;

const
  TerrainSize = 513;
  TerrainTriangleSize = 0.25;
  TerrainHeightScale: single = 0.05;
  GroundTexFile: string = 'texture.material';
  DetailTexFile = 'Detail.tex';
  WaterAlpha = 212;
  WaterHeightMapValue = 0; // JVAL: range 0..255
  TerrainSubDivisions = 32;
  MediumDetailRange: single = 48.0;
  LowDetailRange: single = 500; //224.0;
  MultiTextureDist: single = 64.0;
  gl_MultiTexturingTerrain: boolean = true;
  gl_HiResolutionTerrain: boolean = false;

var
  GroundTexture: GLuint = 0;
  DetailTexture: GLuint = 0;
//  WaterTexture: GLuint = 0;

type
  terrainvert_t = record
    vector: TGLVectorf3;

    normal: TGLVectorf3;

    U: Single;

    V: Single;

    void: boolean;

  end;

  Pterrainvert_t = ^terrainvert_t;

  terrainvert_tArray = array[0..TerrainSize, 0..TerrainSize] of terrainvert_t;

  Pterrainvert_tArray = ^terrainvert_tArray;

  terrainsubdivision_t = record
    list_full: GLuint;  // OpenGL compiled list, full detail
    list_medium: GLuint; // OpenGL compiled list, medium resolution
    X, Y, Z: single; // Center of bounding sphere
    radious: single; // Radious of bounding sphere
    floor, ceiling: single;
  end;
  Pterrainsubdivision_t = ^terrainsubdivision_t;


var
  FTerrainPoints: Pterrainvert_tArray;
  FTerrainSubDivisions: array[0..TerrainSubDivisions - 1, 0..TerrainSubDivisions - 1] of terrainsubdivision_t;

var
  WaterRealHeight: single;

procedure CalculateTerrainNormals;
var
  X,Y, XX,YY, targetY, targetX: integer;
  V: TGLVectorf3;
  H, Len: single;
begin
  for Y := 0 to TerrainSize - 1 do
  begin
    for X := 0 to TerrainSize - 1 do
    begin
      V[0] := 0.0;
      V[1] := 0.0;
      V[2] := 0.0;

      for YY := -1 to 1 do
      begin

        if (Y + YY >= 0) and (Y + YY < TerrainSize) then
          targetY := Y + YY
        else if Y + YY < 0 then
          targetY := 0
        else
          targetY := TerrainSize - 1;

        for XX := -1 to 1 do
          if (XX <> 0) and (YY <> 0) then
          begin

            if (X + XX >= 0) and (X + XX < TerrainSize) then
              targetX := X + XX
            else if X + XX < 0 then
              targetX := 0
            else
              targetX := TerrainSize - 1;

            H := FTerrainPoints[targetX, targetY].Vector[1];

            V[0] := V[0] - xx * H;
            V[2] := V[2] - yy * H;
          end;
      end;

      //OpenGL style orientation (Y is vertical)
      V[1] := 1/5; // 1/strength of effect.

      Len := sqrt(V[0] * V[0] + V[1] * V[1] + V[2] * V[2]); // sqrt, auch!
      if Len > 0 then
      begin
        V[0] := V[0] / Len;
        V[1] := V[1] / Len;
        V[2] := V[2] / Len;
      end;

      FTerrainPoints[X, Y].Normal := V;
    end;
  end;
end;


var

  subdivisionlength: single;


procedure MakeSubDivision(const x, y: integer);

var

  sd: Pterrainsubdivision_t;

  xStart: integer;
  xEnd: integer;

  yStart: integer;

  yEnd: integer;
  iX, iY: integer;
  ptv_xy: Pterrainvert_t;

  ptv_x1y: Pterrainvert_t;

  ptv_xy1: Pterrainvert_t;
  ptv_x1y1: Pterrainvert_t;
  avheight: single; // Average height for small list

  avcount: integer;

  llow, lhi: single; // High and low heights of subdivision

  lheight: single; // Height of subdivision

  underwaterdivision: boolean;

begin
  sd := @FTerrainSubDivisions[x, y];


  xStart := x * (TerrainSize - 1) div TerrainSubDivisions;

  xEnd := (x + 1) * (TerrainSize - 1) div TerrainSubDivisions;

  yStart := y * (TerrainSize - 1) div TerrainSubDivisions;

  yEnd := (y + 1) * (TerrainSize - 1) div TerrainSubDivisions;


  llow := 1e10;
  lhi := -1e10;
  for iX := xStart to xEnd - 1 do

    for iY := yStart to yEnd - 1 do
    begin
      if FTerrainPoints[iX, iY].Vector[1] > lhi then
        lhi := FTerrainPoints[iX, iY].Vector[1];
      if FTerrainPoints[iX, iY].Vector[1] < llow then
        llow := FTerrainPoints[iX, iY].Vector[1];
    end;

  sd.floor := llow;
  sd.ceiling := lhi;
  sd.X := (FTerrainPoints[xStart, yStart].Vector[0] +

           FTerrainPoints[xEnd, yEnd].Vector[0]) / 2;

  sd.Y := (lhi + llow) / 2;
  sd.Z := (FTerrainPoints[xStart, yStart].Vector[2] +

           FTerrainPoints[xEnd, yEnd].Vector[2]) / 2;


  lheight := lhi - sd.Y;

  sd.radious := sqrt(2 * sqr(subdivisionlength / 2) + sqr(lheight));


  avheight := 0;; // Average height for small list

  avcount := 0;


  underwaterdivision := false;

  // Create the full detail list

  sd.list_full := glGenLists(1);

  glNewList(sd.list_full, GL_COMPILE);

  glBegin(GL_QUADS);

      ptv_xy := @FTerrainPoints[xStart, yStart];
        glTexCoord2f(ptv_xy.U, ptv_xy.V);
        glNormal3fv(@ptv_xy.normal);

        glVertex3fv(@ptv_xy.Vector);

        glTexCoord2f(ptv_xy.U, ptv_xy.V);

        glNormal3fv(@ptv_xy.normal);

        glVertex3fv(@ptv_xy.Vector);

        glTexCoord2f(ptv_xy.U, ptv_xy.V);

        glNormal3fv(@ptv_xy.normal);

        glVertex3fv(@ptv_xy.Vector);

        glTexCoord2f(ptv_xy.U, ptv_xy.V);

        glNormal3fv(@ptv_xy.normal);

        glVertex3fv(@ptv_xy.Vector);

  for iX := xStart to xEnd - 1 do
    for iY := yStart to yEnd - 1 do
    begin
      inc(avcount);
      ptv_xy := @FTerrainPoints[iX, iY];
      avheight := avheight + ptv_xy.vector[1];

      ptv_x1y := @FTerrainPoints[iX + 1, iY];

      ptv_xy1 := @FTerrainPoints[iX, iY + 1];

      ptv_x1y1 := @FTerrainPoints[iX + 1, iY + 1];


      if (ptv_xy.Vector[1] > WaterRealHeight) or

         (ptv_x1y.Vector[1] > WaterRealHeight) or

         (ptv_xy1.Vector[1] > WaterRealHeight) or

         (ptv_x1y1.Vector[1] > WaterRealHeight) then

      begin

        glTexCoord2f(ptv_xy.U, ptv_xy.V);

        glNormal3fv(@ptv_xy.normal);

        glVertex3fv(@ptv_xy.Vector);

        glTexCoord2f(ptv_xy1.U, ptv_xy1.V);

        glNormal3fv(@ptv_xy1.normal);

        glVertex3fv(@ptv_xy1.Vector);

        glTexCoord2f(ptv_x1y1.U, ptv_x1y1.V);

        glNormal3fv(@ptv_x1y1.normal);

        glVertex3fv(@ptv_x1y1.Vector);

        glTexCoord2f(ptv_x1y.U, ptv_x1y.V);

        glNormal3fv(@ptv_x1y.normal);

        glVertex3fv(@ptv_x1y.Vector);

      end

      else

        underwaterdivision := true;

    end;

  if underwaterdivision then

    for iX := xStart to xEnd - 1 do

      for iY := yStart to yEnd - 1 do
      begin
        inc(avcount);
        ptv_xy := @FTerrainPoints[iX, iY];
        ptv_x1y := @FTerrainPoints[iX + 1, iY];

        ptv_xy1 := @FTerrainPoints[iX, iY + 1];

        ptv_x1y1 := @FTerrainPoints[iX + 1, iY + 1];


      if (ptv_xy.Vector[1] > WaterRealHeight) and

         (ptv_x1y.Vector[1] > WaterRealHeight) and

         (ptv_xy1.Vector[1] > WaterRealHeight) and

         (ptv_x1y1.Vector[1] > WaterRealHeight) then

      begin

        glTexCoord2f(ptv_xy.U, ptv_xy.V);

        glNormal3fv(@ptv_xy.normal);

        glVertex3f(ptv_xy.Vector[0], 2 * WaterRealHeight - ptv_xy.Vector[1] - 2 * TerrainHeightScale, ptv_xy.Vector[2]);

        glTexCoord2f(ptv_xy1.U, ptv_xy1.V);

        glNormal3fv(@ptv_xy1.normal);

        glVertex3f(ptv_xy1.Vector[0], 2 * WaterRealHeight - ptv_xy1.Vector[1] - 2 * TerrainHeightScale, ptv_xy1.Vector[2]);

        glTexCoord2f(ptv_x1y1.U, ptv_x1y1.V);
        glNormal3fv(@ptv_x1y1.normal);

        glVertex3f(ptv_x1y1.Vector[0], 2 * WaterRealHeight - ptv_x1y1.Vector[1] - 2 * TerrainHeightScale, ptv_x1y1.Vector[2]);

        glTexCoord2f(ptv_x1y.U, ptv_x1y.V);

        glNormal3fv(@ptv_x1y.normal);

        glVertex3f(ptv_x1y.Vector[0], 2 * WaterRealHeight - ptv_x1y.Vector[1] - 2 * TerrainHeightScale, ptv_x1y.Vector[2]);

      end;

    end;



  glEnd;

  glEndList;



  // Create the small detail list (actually medium detail)

  sd.list_medium := glGenLists(1);

  glNewList(sd.list_medium, GL_COMPILE);

  glBegin(GL_QUADS);

  for iX := xStart to xEnd - 1 do
    for iY := yStart to yEnd - 1 do
    begin
      if (iX = xStart) or (iX = xEnd - 1) or
         (iY = yStart) or (iY = yEnd - 1) then
      begin
        ptv_xy := @FTerrainPoints[iX, iY];
        ptv_x1y := @FTerrainPoints[iX + 1, iY];
        ptv_xy1 := @FTerrainPoints[iX, iY + 1];

        ptv_x1y1 := @FTerrainPoints[iX + 1, iY + 1];


        glTexCoord2f(ptv_xy.U, ptv_xy.V);

        glNormal3fv(@ptv_xy.normal);

        glVertex3fv(@ptv_xy.Vector);

        glTexCoord2f(ptv_xy1.U, ptv_xy1.V);

        glNormal3fv(@ptv_xy1.normal);

        glVertex3fv(@ptv_xy1.Vector);
        glTexCoord2f(ptv_x1y1.U, ptv_x1y1.V);

        glNormal3fv(@ptv_x1y1.normal);

        glVertex3fv(@ptv_x1y1.Vector);

        glTexCoord2f(ptv_x1y.U, ptv_x1y.V);

        glNormal3fv(@ptv_x1y.normal);

        glVertex3fv(@ptv_x1y.Vector);

      end;

    end;

  glEnd;

  // Compute the average terrain subdivision height
  avheight := avheight / avcount;

  glBegin(GL_TRIANGLE_FAN);

    // Center of triangle fun
    ptv_xy := @FTerrainPoints[(xStart + xEnd) div 2, (yStart + yEnd) div 2];
    glTexCoord2f(ptv_xy.U, ptv_xy.V);
    glNormal3fv(@ptv_xy.normal);
    glVertex3f(ptv_xy.Vector[0], avheight, ptv_xy.Vector[2]);


    // Left

    for iX := xStart + 1 to xEnd - 1 do
    begin
      ptv_xy := @FTerrainPoints[iX, yStart + 1];
      glTexCoord2f(ptv_xy.U, ptv_xy.V);
      glNormal3fv(@ptv_xy.normal);

      glVertex3fv(@ptv_xy.Vector);

    end;

    // Down

    for iY := yStart + 2 to yEnd - 1 do
    begin
      ptv_xy := @FTerrainPoints[xEnd - 1, iY];
      glTexCoord2f(ptv_xy.U, ptv_xy.V);
      glNormal3fv(@ptv_xy.normal);

      glVertex3fv(@ptv_xy.Vector);

    end;

    // Right

    for iX := xEnd - 2 downto xStart + 1 do
    begin
      ptv_xy := @FTerrainPoints[iX, yEnd - 1];
      glTexCoord2f(ptv_xy.U, ptv_xy.V);
      glNormal3fv(@ptv_xy.normal);

      glVertex3fv(@ptv_xy.Vector);

    end;

    // Bottom

    for iY := yEnd - 2 downto yStart + 1 do
    begin
      ptv_xy := @FTerrainPoints[xStart + 1, iY];
      glTexCoord2f(ptv_xy.U, ptv_xy.V);
      glNormal3fv(@ptv_xy.normal);

      glVertex3fv(@ptv_xy.Vector);
    end;

  glEnd;
  glEndList;
end;




var

  terrain_initialized: boolean = false;



procedure gld_InitTerrainData;
var
  iX, iY: Integer;
  ps: TPakStream;
begin
  terrain_initialized := true;
  FTerrainPoints := malloc(SizeOf(terrainvert_tArray));
  ps := TPakStream.Create('terrain.dat', pm_short);
  ps.Read(FTerrainPoints^, SizeOf(terrainvert_tArray));
  ps.Free;

  GroundTexture := gld_LoadExternalTexture(GroundTexFile, false, GL_REPEAT);

  DetailTexture := gld_LoadExternalTexture(DetailTexFile, false, GL_REPEAT);

  subdivisionlength := (TerrainSize / TerrainSubDivisions) * TerrainTriangleSize;

  WaterRealHeight := (WaterHeightMapValue - 128) * TerrainHeightScale;


  for iX := 0 to TerrainSubDivisions - 1 do
    for iY := 0 to TerrainSubDivisions - 1 do

      MakeSubDivision(iX, iY);
end;



procedure gld_FreeTerrainData;
var
  x, y: integer;
begin
  if not terrain_initialized then
    exit;

  memfree(pointer(FTerrainPoints), SizeOf(terrainvert_tArray));

  glDeleteTextures(1, @GroundTexture);
  glDeleteTextures(1, @DetailTexture);
  for x := 0 to TerrainSubDivisions - 1 do
    for y := 0 to TerrainSubDivisions - 1 do
    begin
      glDeleteLists(FTerrainSubDivisions[x, y].list_full, 1);
      glDeleteLists(FTerrainSubDivisions[x, y].list_medium, 1);
    end;

  terrain_initialized := false;
end;

var
  doMultiTexturingTerrain: boolean;

procedure ActivateMultitexturing;
begin
  if canuselightmaps then
  begin
    if doMultiTexturingTerrain then
    begin
      glEnable(GL_TEXTURE_2D);
      glActiveTextureARB(GL_TEXTURE2_ARB);
      glEnable(GL_TEXTURE_2D);
      glActiveTextureARB(GL_TEXTURE0_ARB);
    end
    else
    begin
      glActiveTextureARB(GL_TEXTURE2_ARB);
      glDisable(GL_TEXTURE_2D);
      glActiveTextureARB(GL_TEXTURE0_ARB);
    end;
  end
  else
  begin
    if doMultiTexturingTerrain then
    begin
      glEnable(GL_TEXTURE_2D);
      glActiveTextureARB(GL_TEXTURE1_ARB);
      glEnable(GL_TEXTURE_2D);
      glActiveTextureARB(GL_TEXTURE0_ARB);
    end
    else
    begin
      glActiveTextureARB(GL_TEXTURE1_ARB);
      glDisable(GL_TEXTURE_2D);
      glActiveTextureARB(GL_TEXTURE0_ARB);
    end;
  end
end;

procedure DeActivateMultitexturing;
begin
  if canuselightmaps then
  begin
    if doMultiTexturingTerrain then
    begin
      glDisable(GL_TEXTURE_GEN_S);
      glDisable(GL_TEXTURE_GEN_T);
      glActiveTextureARB(GL_TEXTURE2_ARB);
      glDisable(GL_TEXTURE_2D);
      glActiveTextureARB(GL_TEXTURE0_ARB);
    end;
  end
  else
  begin
    if doMultiTexturingTerrain then
    begin
      glDisable(GL_TEXTURE_GEN_S);
      glDisable(GL_TEXTURE_GEN_T);
      glActiveTextureARB(GL_TEXTURE1_ARB);
      glDisable(GL_TEXTURE_2D);
      glActiveTextureARB(GL_TEXTURE0_ARB);
    end;
  end;
end;

procedure gld_DrawTerrain(const x, y, z: single);
var
  i, j: integer;
{$IFDEF TERRAINSTATS}
  stat_numsubdivisions: integer;
  stat_nummultitextuered: integer;
  stat_numhidetail: integer;
  stat_nummediumdetail: integer;
  stat_numlowdetail: integer;
{$ENDIF}
  TexGenSPlane, TexGenTPlane: TVector4f;
  dist: single; // Distance of a subdivision
  pdiv: Pterrainsubdivision_t;
  mtextest: single;
  mdetailtest: single;                          
begin
  gld_StaticLight(1.0);

  fr_CalculateFrustum;

  gld_ResetLastTexture;

       glEnable(GL_BLEND);
       glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  glEnable(GL_TEXTURE_2D);
  glBindTexture(GL_TEXTURE_2D, GroundTexture);

  // Set detail texture if multitexturing is supported
  doMultiTexturingTerrain := gl_MultiTexturingTerrain and Assigned(glActiveTextureARB);
  if doMultiTexturingTerrain then
  begin
    if canuselightmaps then
      glActiveTextureARB(GL_TEXTURE2_ARB)
    else
      glActiveTextureARB(GL_TEXTURE1_ARB);
    glBindTexture(GL_TEXTURE_2D, DetailTexture);
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_COMBINE_ARB);
    glTexEnvi(GL_TEXTURE_ENV, GL_RGB_SCALE_ARB, 2);
    glEnable(GL_TEXTURE_GEN_S);
    glEnable(GL_TEXTURE_GEN_T);
    glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_OBJECT_LINEAR);
    glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_OBJECT_LINEAR);
    TexGenSPlane[0] := 0.25;
    TexGenSPlane[1] := 0.0;
    TexGenSPlane[2] := 0.0;
    TexGenSPlane[3] := 0.0;
    TexGenTPlane[0] := 0.0;
    TexGenTPlane[1] := 0.0;
    TexGenTPlane[2] := 0.25;
    TexGenTPlane[3] := 0.0;
    glTexGenfv(GL_S, GL_OBJECT_PLANE, @TexGenSPlane);
    glTexGenfv(GL_T, GL_OBJECT_PLANE, @TexGenTPlane);
    glActiveTextureARB(GL_TEXTURE0_ARB);
  end;

  // Draw individual terrain blocks
  mtextest := MultiTextureDist * MultiTextureDist;
  mdetailtest := MediumDetailRange * MediumDetailRange;
{$IFDEF TERRAINSTATS}
  stat_numsubdivisions := 0;
  stat_nummultitextuered := 0;
  stat_numhidetail := 0;
  stat_nummediumdetail := 0;
  stat_numlowdetail := 0;
{$ENDIF}
  for i := 0 to TerrainSubDivisions - 1 do
    for j := 0 to TerrainSubDivisions - 1 do
    begin
      pdiv := @FTerrainSubDivisions[i, j];
      if pdiv.ceiling > (WaterHeightMapValue - 128) * TerrainHeightScale then
      if fr_SphereInFrustum(pdiv.X, pdiv.Y, pdiv.Z, pdiv.radious) then
      begin
        {$IFDEF TERRAINSTATS}
        inc(stat_numsubdivisions);
        {$ENDIF}
        dist := sqr(pdiv.x - x) + sqr(pdiv.y - y) + sqr(pdiv.z - z);
        if canusemultitexture and (dist < mtextest) then //subdivisionlength * 1.5 then
        begin
          {$IFDEF TERRAINSTATS}
          inc(stat_nummultitextuered);
          inc(stat_numhidetail);
          {$ENDIF}
          ActivateMultitexturing;
          glCallList(pdiv.list_full);
          DeActivateMultitexturing;
        end
        else if gl_HiResolutionTerrain then
        begin
          {$IFDEF TERRAINSTATS}
          inc(stat_numhidetail);
          {$ENDIF}
          glCallList(pdiv.list_full);
        end
        else if dist < mdetailtest then
        begin
          {$IFDEF TERRAINSTATS}
          inc(stat_numhidetail);
          {$ENDIF}
          glCallList(pdiv.list_full);
        end
        else // if dist < ldetailtest then
        begin
          {$IFDEF TERRAINSTATS}
          inc(stat_nummediumdetail);
          {$ENDIF}
          glCallList(pdiv.list_medium);
        end
      end;
    end;

{$IFDEF TERRAINSTATS}
  printf('%d calls (%d multitex, %d hi, %d medim %d low) out of %d'#13#10,
    [stat_numsubdivisions, stat_nummultitextuered, stat_numhidetail, stat_nummediumdetail,
     stat_numlowdetail, TerrainSubDivisions * TerrainSubDivisions]);
{$ENDIF}

end;

function gld_GetDoomHeightFromCoord(const x, y: fixed_t): float;
var
  x1, y1: float;
  ix, iy: integer;
  fx, fy: single;
  H1, H2, H3: Single;
begin
  x1 := ((TerrainTriangleSize * MAP_COEFF) / 2 - x / FRACUNIT) / (TerrainTriangleSize * MAP_COEFF) + (TerrainSize - 1) / 2;
  ix := trunc(x1);
  fx := frac(x1);
  if ix < 0 then
  begin
    ix := 0;
    fx := 0.0;
  end
  else if ix > TerrainSize - 1 then
  begin
    ix := TerrainSize - 1;
    fx := 0.999;
  end;
  y1 := ((TerrainTriangleSize * MAP_COEFF) / 2 - y / FRACUNIT) / (TerrainTriangleSize * MAP_COEFF) + (TerrainSize - 1) / 2;
  y1 := TerrainSize - y1;
  iy := trunc(y1);
  fy := frac(y1);
  if iy < 0 then
  begin
    iy := 0;
    fy := 0.0;
  end
  else if iy > TerrainSize - 1 then
  begin
    iy := TerrainSize - 1;
    fy := 0.999;
  end;

  if fx + fy <= 1 then
  begin
    // top-left triangle
    H1 := FTerrainPoints[ix, iy].vector[1];
    H2 := FTerrainPoints[ix + 1, iy].vector[1];
    H3 := FTerrainPoints[ix, iy + 1].vector[1];
    Result := H1 + (H2 - H1) * fx + (H3 - H1) * fy;
  end
  else
  begin
    // bottom-right triangle
    H1 := FTerrainPoints[ix + 1, iy + 1].vector[1];
    H2 := FTerrainPoints[ix, iy + 1].vector[1];
    H3 := FTerrainPoints[ix + 1, iy].vector[1];
    Result := H1 + (H2 - H1) * (1 - fx) + (H3 - H1) * (1 - fy);
  end;
end;

function gld_GetDoomHeightFromCoordFixed(const x, y: fixed_t): fixed_t;
begin
  result := round(gld_GetDoomHeightFromCoord(x, y) * MAP_SCALE);
end;

function gld_TerrainAdjustFloorZ(const x, y: fixed_t; const floorz: fixed_t): fixed_t;
var
  x1, y1: float;
  ix, iy: integer;
  fx, fy: single;
  H1, H2, H3: single;
  floatz: single;
begin
  x1 := ((TerrainTriangleSize * MAP_COEFF) / 2 - x / FRACUNIT) / (TerrainTriangleSize * MAP_COEFF) + (TerrainSize - 1) / 2;
  ix := trunc(x1);
  fx := frac(x1);
  if ix < 0 then
  begin
    ix := 0;
    fx := 0.0;
  end
  else if ix > TerrainSize - 1 then
  begin
    ix := TerrainSize - 1;
    fx := 0.999;
  end;
  y1 := ((TerrainTriangleSize * MAP_COEFF) / 2 - y / FRACUNIT) / (TerrainTriangleSize * MAP_COEFF) + (TerrainSize - 1) / 2;
  y1 := TerrainSize - y1;
  iy := trunc(y1);
  fy := frac(y1);
  if iy < 0 then
  begin
    iy := 0;
    fy := 0.0;
  end
  else if iy > TerrainSize - 1 then
  begin
    iy := TerrainSize - 1;
    fy := 0.999;
  end;

  result := floorz;
  if fx + fy <= 1 then
  begin
    // top-left triangle
    if FTerrainPoints[ix, iy].void then
      exit;
    if FTerrainPoints[ix + 1, iy].void then
      exit;
    if FTerrainPoints[ix, iy + 1].void then
      exit;
    H1 := FTerrainPoints[ix, iy].vector[1];
    H2 := FTerrainPoints[ix + 1, iy].vector[1];
    H3 := FTerrainPoints[ix, iy + 1].vector[1];
    floatz := H1 + (H2 - H1) * fx + (H3 - H1) * fy;
  end
  else
  begin
    // bottom-right triangle
    if FTerrainPoints[ix + 1, iy + 1].void then
      exit;
    if FTerrainPoints[ix, iy + 1].void then
      exit;
    if FTerrainPoints[ix + 1, iy].void then
      exit;
    H1 := FTerrainPoints[ix + 1, iy + 1].vector[1];
    H2 := FTerrainPoints[ix, iy + 1].vector[1];
    H3 := FTerrainPoints[ix + 1, iy].vector[1];
    floatz := H1 + (H2 - H1) * (1 - fx) + (H3 - H1) * (1 - fy);
  end;

  result := round(floatz * MAP_SCALE);
end;

end.


