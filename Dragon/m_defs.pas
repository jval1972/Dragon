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

unit m_defs;

interface

uses
  c_con,
  doomdef,
  d_englsh,
  d_main,
  g_game,
  hu_stuff,
  p_mobj_h,
  p_terrain,
  p_enemy,
  p_setup,
  i_system,
  i_mp3,
  i_music,
  i_sound,
  gl_main,
  gl_defs,
  gl_models,
  gl_lightmaps,
  m_menu,
  r_defs,
  r_main,
  r_hires,
  r_lights,
  r_intrpl,
  r_draw,
  s_sound,
  t_main,
  v_video;

const
  DFS_NEVER = 0;
  DFS_SINGLEPLAYER = 1;
  DFS_NETWORK = 2;
  DFS_ALWAYS = 3;

var
// Stub variables
  displayendscreen: boolean;

type
  ttype_t = (tString, tInteger, tBoolean, tGroup);

  default_t = record
    name: string;
    location: pointer;
    setable: byte;
    defaultsvalue: string;
    defaultivalue: integer;
    defaultbvalue: boolean;
    _type: ttype_t;
  end;
  Pdefault_t = ^default_t;

const
  NUMDEFAULTS = 125;

// JVAL
// Note: All setable defaults must be in lowercase, don't ask why. Just do it. :)
  defaults: array[0..NUMDEFAULTS - 1] of default_t = (
    (name: 'Display';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'gl_screenwidth';
     location: @SCREENWIDTH;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 800;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'gl_screenheight';
     location: @SCREENHEIGHT;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 600;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'fullscreen';
     location: @fullscreen;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'interpolate';
     location: @interpolate;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'fixstallhack';
     location: @fixstallhack;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: '32bittexturepaletteeffects';
     location: @dc_32bittexturepaletteeffects;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'zaxisshift';
     location: @zaxisshift;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'chasecamera';
     location: @chasecamera;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'chasecamera_viewxy';
     location: @chasecamera_viewxy;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 64;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'chasecamera_viewz';
     location: @chasecamera_viewz;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 32;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'drawfps';
     location: @drawfps;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'shademenubackground';
     location: @shademenubackground;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'displaydiskbusyicon';
     location: @displaydiskbusyicon;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'displayendscreen';
     location: @displayendscreen;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'showdemoplaybackprogress';
     location: @showdemoplaybackprogress;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'screenblocks';
     location: @screenblocks;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 11;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'detaillevel';
     location: @detailLevel;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: DL_NORMAL;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'allowlowdetails';
     location: @allowlowdetails;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'uselightboost';
     location: @uselightboost;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'lightboostfactor';
     location: @lightboostfactor;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 192;
     defaultbvalue: true;
     _type: tInteger),

    (name: 'usegamma';
     location: @usegamma;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'forcecolormaps';
     location: @forcecolormaps;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'use32bitfuzzeffect';
     location: @use32bitfuzzeffect;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'usetransparentsprites';
     location: @usetransparentsprites;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'diher8bittransparency';
     location: @diher8bittransparency;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'hidedoublicatedbarrels';
     location: @hidedoublicatedbarrels;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'OpenGL';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'default_transparent_filter_percent';
     location: @tran_filter_pct;
     setable: DFS_ALWAYS;
     defaultsvalue: '66';
     defaultivalue: 66;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'use_fog';
     location: @use_fog;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'fog_density';
     location: @fog_density;
     setable: DFS_ALWAYS;
     defaultsvalue: '100';
     defaultivalue: 100;
     defaultbvalue: true;
     _type: tInteger),

    (name: 'gl_nearclip';
     location: @gl_nearclip;
     setable: DFS_ALWAYS;
     defaultsvalue: '5';
     defaultivalue: 5;
     defaultbvalue: true;
     _type: tInteger),

    (name: 'gl_tex_filter';
     location: @gl_tex_filter_string;
     setable: DFS_ALWAYS;
     defaultsvalue: 'GL_LINEAR';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tString),

    (name: 'gl_texture_filter_anisotropic';
     location: @gl_texture_filter_anisotropic;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'gl_drawsky';
     location: @gl_drawsky;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'gl_stencilsky';
     location: @gl_stencilsky;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'gl_drawmodels';
     location: @gl_drawmodels;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'gl_smoothmodelmovement';
     location: @gl_smoothmodelmovement;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'gl_precachemodeltextures';
     location: @gl_precachemodeltextures;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'gl_uselightmaps';
     location: @gl_uselightmaps;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'gl_screensync';
     location: @gl_screensync;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'gl_linear_hud';
     location: @gl_linear_hud;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'gl_add_all_lines';
     location: @gl_add_all_lines;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'useglnodesifavailable';
     location: @useglnodesifavailable;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'autoloadgwafiles';
     location: @autoloadgwafiles;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

     // Textures
    (name: 'Textures';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'useexternaltextures';
     location: @useexternaltextures;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'preferetexturesnamesingamedirectory';
     location: @preferetexturesnamesingamedirectory;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'extremeflatfiltering';
     location: @extremeflatfiltering;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

     // Compatibility
    (name: 'Compatibility';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'compatibilitymode';
     location: @compatibilitymode;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'keepcheatsinplayerreborn';
     location: @keepcheatsinplayerreborn;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'allowplayerjumps';
     location: @allowplayerjumps;
     setable: DFS_SINGLEPLAYER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'majorbossdeathendsdoom1level';
     location: @majorbossdeathendsdoom1level;
     setable: DFS_SINGLEPLAYER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'allowterrainsplashes';
     location: @allowterrainsplashes;
     setable: DFS_SINGLEPLAYER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'continueafterplayerdeath';
     location: @continueafterplayerdeath;
     setable: DFS_SINGLEPLAYER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

     // Navigation
    (name: 'Controls';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'autorunmode';
     location: @autorunmode;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'Keyboard';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'key_right';
     location: @key_right;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_RIGHTARROW;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_left';
     location: @key_left;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_LEFTARROW;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_up';
     location: @key_up;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_UPARROW;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_down';
     location: @key_down;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_DOWNARROW;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_strafeleft';
     location: @key_strafeleft;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: Ord(',');
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_straferight';
     location: @key_straferight;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: Ord('.');
     defaultbvalue: false;
     _type: tInteger),

     // JVAL Jump
    (name: 'key_jump';
     location: @key_jump;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: Ord('a');
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_fire';
     location: @key_fire;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_RCTRL;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_use';
     location: @key_use;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: Ord(' ');
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_strafe';
     location: @key_strafe;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_RALT;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_speed';
     location: @key_speed;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_RSHIFT;
     defaultbvalue: false;
     _type: tInteger),

     // JVAL Look UP and DOWN using z-axis shift
    (name: 'key_lookup';
     location: @key_lookup;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_PAGEDOWN;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_lookdown';
     location: @key_lookdown;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_DELETE;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_lookcenter';
     location: @key_lookcenter;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_INS;
     defaultbvalue: false;

     _type: tInteger),

     // JVAL Look LEFT/RIGHT
    (name: 'key_lookright';

     location: @key_lookright;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_PAGEUP;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_lookleft';
     location: @key_lookleft;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_HOME;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'key_lookforward';
     location: @key_lookforward;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: KEY_ENTER;
     defaultbvalue: false;
     _type: tInteger),

     // Mouse

    (name: 'Mouse';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'use_mouse';
     location: @usemouse;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'mouse_sensitivity';
     location: @mouseSensitivity;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 5;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'invertmouselook';
     location: @invertmouselook;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'invertmouseturn';
     location: @invertmouseturn;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'mouseb_fire';
     location: @mousebfire;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'mouseb_strafe';
     location: @mousebstrafe;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'mouseb_forward';
     location: @mousebforward;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 2;
     defaultbvalue: false;
     _type: tInteger),

     // Joystick
    (name: 'Joystick';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'use_joystick';
     location: @usejoystick;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'joyb_fire';
     location: @joybfire;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'joyb_strafe';
     location: @joybstrafe;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'joyb_use';
     location: @joybuse;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 3;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'joyb_speed';
     location: @joybspeed;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 2;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'joyb_jump';
     location: @joybjump;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 4;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'joyb_lookleft';
     location: @joyblleft;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 6;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'joyb_lookright';
     location: @joyblright;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 7;
     defaultbvalue: false;
     _type: tInteger),

     // Sound
    (name: 'Sound';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'snd_channels';
     location: @numChannels;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 6;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'sfx_volume';
     location: @snd_SfxVolume;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 15;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'music_volume';
     location: @snd_MusicVolume;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 8;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'miditempo';
     location: @miditempo;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 128;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'usemp3';
     location: @usemp3;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'preferemp3namesingamedirectory';
     location: @preferemp3namesingamedirectory;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'useexternalwav';
     location: @useexternalwav;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'preferewavnamesingamedirectory';
     location: @preferewavnamesingamedirectory;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

     // Console
    (name: 'Console';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'console_colormap';
     location: @ConsoleColormap;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: NUMCOLORMAPS div 2;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'mirror_stdout';
     location: @mirror_stdout;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: true;
     _type: tBoolean),

     // Messages
    (name: 'show_messages';
     location: @showMessages;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 1;
     defaultbvalue: false;
     _type: tInteger),

    (name: 'Chat strings';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'chatmacro0';
     location: @chat_macros[0];
     setable: DFS_ALWAYS;
     defaultsvalue: HUSTR_CHATMACRO0;
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'chatmacro1';
     location: @chat_macros[1];
     setable: DFS_ALWAYS;
     defaultsvalue: HUSTR_CHATMACRO1;
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'chatmacro2';
     location: @chat_macros[2];
     setable: DFS_ALWAYS;
     defaultsvalue: HUSTR_CHATMACRO2;
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'chatmacro3';
     location: @chat_macros[3];
     setable: DFS_ALWAYS;
     defaultsvalue: HUSTR_CHATMACRO3;
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'chatmacro4';
     location: @chat_macros[4];
     setable: DFS_ALWAYS;
     defaultsvalue: HUSTR_CHATMACRO4;
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'chatmacro5';
     location: @chat_macros[5];
     setable: DFS_ALWAYS;
     defaultsvalue: HUSTR_CHATMACRO5;
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'chatmacro6';
     location: @chat_macros[6];
     setable: DFS_ALWAYS;
     defaultsvalue: HUSTR_CHATMACRO6;
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'chatmacro7';
     location: @chat_macros[7];
     setable: DFS_ALWAYS;
     defaultsvalue: HUSTR_CHATMACRO7;
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'chatmacro8';
     location: @chat_macros[8];
     setable: DFS_ALWAYS;
     defaultsvalue: HUSTR_CHATMACRO8;
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'chatmacro9';
     location: @chat_macros[9];
     setable: DFS_ALWAYS;
     defaultsvalue: HUSTR_CHATMACRO9;
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tString),

    (name: 'Randomizer';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'spawnrandommonsters';
     location: @spawnrandommonsters;
     setable: DFS_SINGLEPLAYER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'Advanced';
     location: nil;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tGroup),

    (name: 'safemode';
     location: @safemode;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'usemmx';
     location: @usemmx;
     setable: DFS_NEVER;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: true;
     _type: tBoolean),

    (name: 'usemultithread';
     location: @usemultithread;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'criticalcpupriority';
     location: @criticalcpupriority;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 0;
     defaultbvalue: false;
     _type: tBoolean),

    (name: 'zonesize';
     location: @zonesize;
     setable: DFS_ALWAYS;
     defaultsvalue: '';
     defaultivalue: 32;
     defaultbvalue: false;
     _type: tInteger)

  );

implementation

end.
