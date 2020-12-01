//------------------------------------------------------------------------------
//
//  Dragon
//  A game for Windows based on a modified and improved version of the
//  DelphiDoom engine
//
//  Copyright (C) 1993-1996 by id Software, Inc.
//  Copyright (C) 2011 by Jim Valavanis
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
//  DelphiDoom Site: http://delphidoom.sitesled.com/
//------------------------------------------------------------------------------

{$IFDEF FPC}
{$Error: Use you must use Delphi to compile this project.}
{$ENDIF}

{$IFNDEF OPENGL}
{$Error: This project uses opengl renderer, please define "OPENGL"}
{$ENDIF}

{$IFNDEF DOOM}
{$Error: To compile this project you must define "DOOM"}
{$ENDIF}

{$I Dragon.inc}
{$D Dragon game based on the DelphiDoom engine}

program dragon;

{$R *.RES}

uses
  FastMM4 in 'FASTMM4\FastMM4.pas',
  FastMM4Messages in 'FASTMM4\FastMM4Messages.pas',
  dglOpenGL in 'OPENGL\dglOpenGL.pas',
  gl_clipper in 'OPENGL\gl_clipper.pas',
  gl_tex in 'OPENGL\gl_tex.pas',
  gl_defs in 'OPENGL\gl_defs.pas',
  gl_main in 'OPENGL\gl_main.pas',
  gl_misc in 'OPENGL\gl_misc.pas',
  gl_render in 'OPENGL\gl_render.pas',
  gl_sky in 'OPENGL\gl_sky.pas',
  gl_dlights in 'OPENGL\gl_dlights.pas',
  gl_lights in 'OPENGL\gl_lights.pas',
  gl_data in 'OPENGL\gl_data.pas',
  gl_frustum in 'OPENGL\gl_frustum.pas',
  gl_terrain in 'OPENGL\gl_terrain.pas',
  gl_flare in 'OPENGL\gl_flare.pas',
  gl_md2 in 'OPENGL\gl_md2.pas',
  gl_models in 'OPENGL\gl_models.pas',
  gl_types in 'OPENGL\gl_types.pas',
  gl_lightmaps in 'OPENGL\gl_lightmaps.pas',
  jpg_utils in 'JPEGLIB\jpg_utils.pas',
  jpg_COMapi in 'JPEGLIB\jpg_comapi.pas',
  jpg_dAPImin in 'JPEGLIB\jpg_dapimin.pas',
  jpg_dAPIstd in 'JPEGLIB\jpg_dapistd.pas',
  jpg_DCoefCt in 'JPEGLIB\jpg_dcoefct.pas',
  jpg_dColor in 'JPEGLIB\jpg_dcolor.pas',
  jpg_dct in 'JPEGLIB\jpg_dct.pas',
  jpg_dDctMgr in 'JPEGLIB\jpg_ddctmgr.pas',
  jpg_defErr in 'JPEGLIB\jpg_deferr.pas',
  jpg_dHuff in 'JPEGLIB\jpg_dhuff.pas',
  jpg_dInput in 'JPEGLIB\jpg_dinput.pas',
  jpg_dMainCt in 'JPEGLIB\jpg_dmainct.pas',
  jpg_dMarker in 'JPEGLIB\jpg_dmarker.pas',
  jpg_dMaster in 'JPEGLIB\jpg_dmaster.pas',
  jpg_dMerge in 'JPEGLIB\jpg_dmerge.pas',
  jpg_dpHuff in 'JPEGLIB\jpg_dphuff.pas',
  jpg_dPostCt in 'JPEGLIB\jpg_dpostct.pas',
  jpg_dSample in 'JPEGLIB\jpg_dsample.pas',
  jpg_error in 'JPEGLIB\jpg_error.pas',
  jpg_IDctAsm in 'JPEGLIB\jpg_idctasm.pas',
  jpg_IDctFlt in 'JPEGLIB\jpg_idctflt.pas',
  jpg_IDctFst in 'JPEGLIB\jpg_idctfst.pas',
  jpg_IDctRed in 'JPEGLIB\jpg_IDctRed.pas',
  jpg_Lib in 'JPEGLIB\jpg_lib.pas',
  jpg_MemMgr in 'JPEGLIB\jpg_memmgr.pas',
  jpg_memnobs in 'JPEGLIB\jpg_memnobs.pas',
  jpg_moreCfg in 'JPEGLIB\jpg_morecfg.pas',
  jpg_Quant1 in 'JPEGLIB\jpg_quant1.pas',
  jpg_Quant2 in 'JPEGLIB\jpg_quant2.pas',
  mp3_SynthFilter in 'MP3LIB\mp3_SynthFilter.pas',
  mp3_Args in 'MP3LIB\mp3_Args.pas',
  mp3_BitReserve in 'MP3LIB\mp3_BitReserve.pas',
  mp3_BitStream in 'MP3LIB\mp3_BitStream.pas',
  mp3_CRC in 'MP3LIB\mp3_CRC.pas',
  mp3_Header in 'MP3LIB\mp3_Header.pas',
  mp3_Huffman in 'MP3LIB\mp3_Huffman.pas',
  mp3_InvMDT in 'MP3LIB\mp3_InvMDT.pas',
  mp3_L3Tables in 'MP3LIB\mp3_L3Tables.pas',
  mp3_L3Type in 'MP3LIB\mp3_L3Type.pas',
  mp3_Layer3 in 'MP3LIB\mp3_Layer3.pas',
  mp3_MPEGPlayer in 'MP3LIB\mp3_MPEGPlayer.pas',
  mp3_OBuffer in 'MP3LIB\mp3_OBuffer.pas',
  mp3_OBuffer_MCI in 'MP3LIB\mp3_OBuffer_MCI.pas',
  mp3_OBuffer_Wave in 'MP3LIB\mp3_OBuffer_Wave.pas',
  mp3_Player in 'MP3LIB\mp3_Player.pas',
  mp3_ScaleFac in 'MP3LIB\mp3_ScaleFac.pas',
  mp3_Shared in 'MP3LIB\mp3_Shared.pas',
  mp3_SubBand1 in 'MP3LIB\mp3_SubBand1.pas',
  mp3_SubBand2 in 'MP3LIB\mp3_SubBand2.pas',
  mp3_SubBand in 'MP3LIB\mp3_SubBand.pas',
  t_bmp in 'TEXLIB\t_bmp.pas',
  t_colors in 'TEXLIB\t_colors.pas',
  t_draw in 'TEXLIB\t_draw.pas',
  t_jpeg in 'TEXLIB\t_jpeg.pas',
  t_main in 'TEXLIB\t_main.pas',
  t_png in 'TEXLIB\t_png.pas',
  t_tga in 'TEXLIB\t_tga.pas',
  t_material in 'TEXLIB\t_material.pas',
  t_tex in 'TEXLIB\t_tex.pas',
  c_cmds in 'Base\c_cmds.pas',
  c_con in 'Dragon\c_con.pas',
  c_utils in 'Dragon\c_utils.pas',
  d_delphi in 'Common\d_delphi.pas',
  d_englsh in 'Dragon\d_englsh.pas',
  d_event in 'Dragon\d_event.pas',
  d_items in 'Dragon\d_items.pas',
  d_main in 'Dragon\d_main.pas',
  d_net in 'Dragon\d_net.pas',
  d_net_h in 'Dragon\d_net_h.pas',
  d_player in 'Dragon\d_player.pas',
  d_textur in 'Dragon\d_textur.pas',
  d_think in 'Dragon\d_think.pas',
  d_ticcmd in 'Dragon\d_ticcmd.pas',
  deh_main in 'Dragon\deh_main.pas',
  DirectX in 'Common\DirectX.pas',
  doomdata in 'Dragon\doomdata.pas',
  doomdef in 'Dragon\doomdef.pas',
  doomstat in 'Dragon\doomstat.pas',
  doomtype in 'Dragon\doomtype.pas',
  dstrings in 'Dragon\dstrings.pas',
  f_finale in 'Dragon\f_finale.pas',
  g_game in 'Dragon\g_game.pas',
  hu_lib in 'Dragon\hu_lib.pas',
  hu_stuff in 'Dragon\hu_stuff.pas',
  i_input in 'Dragon\i_input.pas',
  i_io in 'Base\i_io.pas',
  i_midi in 'Dragon\i_midi.pas',
  i_mp3 in 'Dragon\i_mp3.pas',
  i_music in 'Dragon\i_music.pas',
  i_net in 'Dragon\i_net.pas',
  i_sound in 'Dragon\i_sound.pas',
  i_system in 'Dragon\i_system.pas',
  i_tmp in 'Base\i_tmp.pas',
  info in 'Dragon\info.pas',
  info_h in 'Dragon\info_h.pas',
  info_rnd in 'Dragon\info_rnd.pas',
  m_argv in 'Dragon\m_argv.pas',
  m_bbox in 'Dragon\m_bbox.pas',
  m_cheat in 'Dragon\m_cheat.pas',
  m_defs in 'Dragon\m_defs.pas',
  m_fixed in 'Base\m_fixed.pas',
  m_menu in 'Dragon\m_menu.pas',
  m_misc in 'Dragon\m_misc.pas',
  m_rnd in 'Base\m_rnd.pas',
  m_stack in 'Base\m_stack.pas',
  m_vectors in 'Base\m_vectors.pas',
  p_ceilng in 'Dragon\p_ceilng.pas',
  p_doors in 'Dragon\p_doors.pas',
  p_enemy in 'Dragon\p_enemy.pas',
  p_extra in 'Dragon\p_extra.pas',
  p_floor in 'Dragon\p_floor.pas',
  p_inter in 'Dragon\p_inter.pas',
  p_lights in 'Dragon\p_lights.pas',
  p_local in 'Dragon\p_local.pas',
  p_map in 'Dragon\p_map.pas',
  p_maputl in 'Dragon\p_maputl.pas',
  p_mobj in 'Dragon\p_mobj.pas',
  p_mobj_h in 'Dragon\p_mobj_h.pas',
  p_plats in 'Dragon\p_plats.pas',
  p_pspr in 'Dragon\p_pspr.pas',
  p_pspr_h in 'Dragon\p_pspr_h.pas',
  p_saveg in 'Dragon\p_saveg.pas',
  p_setup in 'Dragon\p_setup.pas',
  p_sight in 'Dragon\p_sight.pas',
  p_sounds in 'Dragon\p_sounds.pas',
  p_spec in 'Dragon\p_spec.pas',
  p_switch in 'Dragon\p_switch.pas',
  p_telept in 'Dragon\p_telept.pas',
  p_terrain in 'Dragon\p_terrain.pas',
  p_tick in 'Dragon\p_tick.pas',
  p_user in 'Dragon\p_user.pas',
  p_genlin in 'Dragon\p_genlin.pas',
  p_scroll in 'Dragon\p_scroll.pas',
  p_sun in 'Dragon\p_sun.pas',
  r_bsp in 'Dragon\r_bsp.pas',
  r_data in 'Dragon\r_data.pas',
  r_defs in 'Dragon\r_defs.pas',
  r_draw in 'Dragon\r_draw.pas',
  r_hires in 'Base\r_hires.pas',
  r_intrpl in 'Dragon\r_intrpl.pas',
  r_lights in 'Dragon\r_lights.pas',
  r_main in 'Dragon\r_main.pas',
  r_mmx in 'Dragon\r_mmx.pas',
  r_plane in 'Dragon\r_plane.pas',
  r_sky in 'Dragon\r_sky.pas',
  r_things in 'Dragon\r_things.pas',
  rtl_types in 'Dragon\rtl_types.pas',
  s_sound in 'Dragon\s_sound.pas',
  sc_decorate in 'Dragon\sc_decorate.pas',
  sc_engine in 'Dragon\sc_engine.pas',
  sc_params in 'Base\sc_params.pas',
  sc_states in 'Base\sc_states.pas',
  sounds in 'Dragon\sounds.pas',
  st_lib in 'Dragon\st_lib.pas',
  st_stuff in 'Dragon\st_stuff.pas',
  tables in 'Dragon\tables.pas',
  v_data in 'Dragon\v_data.pas',
  v_video in 'Dragon\v_video.pas',
  wi_stuff in 'Dragon\wi_stuff.pas',
  w_utils in 'Dragon\w_utils.pas',
  w_wad in 'Base\w_wad.pas',
  w_pak in 'Base\w_pak.pas',
  z_files in 'ZLIB\z_files.pas',
  z_zone in 'Base\z_zone.pas',
  sc_tokens in 'Base\sc_tokens.pas',
  i_startup in 'Base\i_startup.pas' {StartUpConsoleForm},
  d_sshot in 'Base\d_sshot.pas',
  dl_form in 'Base\dl_form.pas' {ConfigForm},
  dl_utils in 'Base\dl_utils.pas';

var
  Saved8087CW: Word;

begin
  { Save the current FPU state and then disable FPU exceptions }
  Saved8087CW := Default8087CW;
  Set8087CW($133f); { Disable all fpu exceptions }

  try
    DragonMain;
  except
    I_FlashCachedOutput;
  end;

  { Reset the FPU to the previous state }
  Set8087CW(Saved8087CW);

end.
