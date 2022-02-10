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

unit m_menu;

interface

uses
  d_event;

//==============================================================================
//
// M_Responder
//
//==============================================================================
function M_Responder(ev: Pevent_t): boolean;

{ Called by main loop, }
{ only used for menu (skull cursor) animation. }

//==============================================================================
//
// M_Ticker
//
//==============================================================================
procedure M_Ticker;

{ Called by main loop, }
{ draws the menus directly into the screen buffer. }

//==============================================================================
//
// M_Drawer
//
//==============================================================================
procedure M_Drawer;

//==============================================================================
// M_Init
//
// Called by DragonMain
// loads the config file.
//
//==============================================================================
procedure M_Init;

{ Called by intro code to force menu up upon a keypress, }
{ does nothing if menu is already up. }

//==============================================================================
//
// M_StartControlPanel
//
//==============================================================================
procedure M_StartControlPanel;

var
//
// defaulted values
//
  mouseSensitivity: integer;  // has default

// Show messages has default, 0 = off, 1 = on
  showMessages: integer;

  shademenubackground: boolean;

  menuactive: boolean;

  inhelpscreens: boolean;

//==============================================================================
//
// M_InitMenus
//
//==============================================================================
procedure M_InitMenus;

implementation

uses
  d_delphi,
  doomdef,
  c_cmds,
  dstrings,
  d_englsh,
  d_main,
  d_player,
  g_game,
  m_argv,
  m_misc,
  m_fixed,
  i_system,
  i_io,
  i_mp3,
  i_sound,
  gl_main,
  gl_defs,
  gl_models,
  gl_lightmaps,
  p_setup,
  p_mobj_h,
  p_terrain,
  p_enemy,
  r_main,
  r_hires,
  r_lights,
  r_intrpl,
  r_draw,
  t_main,
  z_zone,
  v_data,
  v_video,
  w_wad,
  hu_stuff,
  st_stuff,
  s_sound,
  doomstat,
// Data.
  sounds;

var
// temp for screenblocks (0-9)
  m_screensize: integer;

// -1 = no quicksave slot picked!
  quickSaveSlot: integer;

 // 1 = message to be printed
  messageToPrint: integer;
// ...and here is the message string!
  messageString: string;

  messageLastMenuActive: boolean;

// timed message = no input from user
  messageNeedsInput: boolean;

type
  PmessageRoutine = function(i: integer): pointer;

var
  messageRoutine: PmessageRoutine;

const
  SAVESTRINGSIZE = 24;

var
  gammamsg: array[0..GAMMASIZE - 1] of string;

// we are going to be entering a savegame string
  saveStringEnter: integer;
  saveSlot: integer;  // which slot to save in
  saveCharIndex: integer; // which char we're editing
// old save description before edit
  saveOldString: string;

const
  SKULLXOFF = -32;
  SKULLYOFF = -5;
  ARROWXOFF = -8;
  LINEHEIGHT = 16;
  LINEHEIGHT2 = 8;

var
  savegamestrings: array[0..9] of string;

type
  menuitem_t = record
    // 0 = no cursor here, 1 = ok, 2 = arrows ok
    status: smallint;

    name: string;
    cmd: string;

    // choice = menu item #.
    // if status = 2,
    //   choice=0:leftarrow,1:rightarrow
    routine: PmessageRoutine;

    // Yes/No location
    pBoolVal: PBoolean;
    // hotkey in menu
    alphaKey: char;
  end;
  Pmenuitem_t = ^menuitem_t;
  menuitem_tArray = packed array[0..$FFFF] of menuitem_t;
  Pmenuitem_tArray = ^menuitem_tArray;

  Pmenu_t = ^menu_t;
  menu_t = record
    numitems: smallint;         // # of menu items
    prevMenu: Pmenu_t;          // previous menu
    menuitems: Pmenuitem_tArray;// menu items
    routine: PProcedure;        // draw routine
    x: smallint;
    y: smallint;                // x,y of menu
    lastOn: smallint;           // last item user was on in menu
    itemheight: integer;
  end;

var
  itemOn: smallint;             // menu item skull is on
  skullAnimCounter: smallint;   // skull animation counter
  whichSkull: smallint;         // which skull to draw

// graphic name of skulls
// warning: initializer-string for array of chars is too long
  skullName: array[0..1] of string;

// current menudef
  currentMenu: Pmenu_t;

//==============================================================================
// M_DrawThermo
//
//      Menu Functions
//
//==============================================================================
procedure M_DrawThermo(x, y, thermWidth, thermDot: integer);
var
  xx: integer;
  i: integer;
begin
  xx := x;
  V_DrawPatch(xx, y, SCN_TMP, 'M_THERML', false);
  xx := xx + 8;
  for i := 0 to thermWidth - 1 do
  begin
    V_DrawPatch(xx, y, SCN_TMP, 'M_THERMM', false);
    xx := xx + 8;
  end;
  V_DrawPatch(xx, y, SCN_TMP, 'M_THERMR', false);

  V_DrawPatch((x + 8) + thermDot * 8, y, SCN_TMP,
    'M_THERMO', false);
end;

//==============================================================================
//
// M_DrawEmptyCell
//
//==============================================================================
procedure M_DrawEmptyCell(menu: Pmenu_t; item: integer);
begin
  V_DrawPatch(menu.x - 10, menu.y + item * menu.itemheight - 1, SCN_TMP,
    'M_CELL1', false);
end;

//==============================================================================
//
// M_DrawSelCell
//
//==============================================================================
procedure M_DrawSelCell(menu: Pmenu_t; item: integer);
begin
  V_DrawPatch(menu.x - 10, menu.y + item * menu.itemheight - 1, SCN_TMP,
    'M_CELL2', false);
end;

//==============================================================================
//
// M_StartMessage
//
//==============================================================================
procedure M_StartMessage(const str: string; routine: PmessageRoutine; const input: boolean);
begin
  messageLastMenuActive := menuactive;
  messageToPrint := 1;
  messageString := str;
  if Assigned(routine) then
    @messageRoutine := @routine
  else
    messageRoutine := nil;
  messageNeedsInput := input;
  menuactive := true;
end;

//==============================================================================
//
// M_StopMessage
//
//==============================================================================
procedure M_StopMessage;
begin
  menuactive := messageLastMenuActive;
  messageToPrint := 0;
end;

//==============================================================================
//  M_StringWidth
//
// Find string width from hu_font chars
//
//==============================================================================
function  M_StringWidth(const str: string): integer;
var
  i: integer;
  c: integer;
begin
  result := 0;
  for i := 1 to Length(str) do
  begin
    c := Ord(toupper(str[i])) - Ord(HU_FONTSTART);
    if (c < 0) or (c >= HU_FONTSIZE) then
      result := result + 4
    else
      result := result + hu_font[c].width;
  end;
end;

//==============================================================================
//  M_StringHeight
//
//      Find string height from hu_font chars
//
//==============================================================================
function  M_StringHeight(const str: string): integer;
var
  i: integer;
  height: integer;
begin
  height := hu_font[0].height;

  result := height;
  for i := 1 to Length(str) do
    if str[i] = #13 then
      result := result + height;
end;

//==============================================================================
// M_WriteText
//
//      Write a string using the hu_font
//
//==============================================================================
procedure M_WriteText(x, y: integer; const str: string; const fraczoom: fixed_t = FRACUNIT);
var
  w: integer;
  ch: integer;
  c: integer;
  cx: integer;
  cy: integer;
  len: integer;
begin
  len := Length(str);
  if len = 0 then
    exit;

  ch := 1;
  cx := x;
  cy := y;

  while true do
  begin
    if ch > len then
      break;

    c := Ord(str[ch]);
    inc(ch);

    if c = 0 then
      break;

    if c = 10 then
    begin
      cx := x;
      continue;
    end;

    if c = 13 then
    begin
      cy := cy + 12 * fraczoom div FRACUNIT;
      continue;
    end;

    c := Ord(toupper(Chr(c))) - Ord(HU_FONTSTART);
    if (c < 0) or (c >= HU_FONTSIZE) then
    begin
      cx := cx + 4 * fraczoom div FRACUNIT;
      continue;
    end;

    w := hu_font[c].width;
    if (cx + w) > 320 then
      break;
    V_DrawPatchZoomed(cx, cy, SCN_TMP, hu_font[c], false, fraczoom);
    cx := cx + w * fraczoom div FRACUNIT;
  end;
end;

//==============================================================================
//
// M_ClearMenus
//
//==============================================================================
procedure M_ClearMenus;
begin
  menuactive := false;
end;

//==============================================================================
//
// M_SetupNextMenu
//
//==============================================================================
procedure M_SetupNextMenu(menudef: Pmenu_t);
begin
  currentMenu := menudef;
  itemOn := currentMenu.lastOn;
end;

//
// MENU DEFINITIONS
//
type
//
// DOOM MENU
//
  main_e = (
    mm_newgame,
//    mm_options,
    mm_loadgame,
    mm_savegame,
    mm_demo,
    mm_quitdoom,
    main_end
  );

var
  MainMenu: array[0..4] of menuitem_t;
  MainDef: menu_t;

type
//
// EPISODE SELECT
//
  episodes_e = (
    ep1,
    ep2,
    ep3,
    ep4,
    ep_end
  );

var
  EpisodeMenu: array[0..3] of menuitem_t;
  EpiDef: menu_t;

type
//
// NEW GAME
//
  newgame_e = (
    killthings,
    toorough,
    hurtme,
    violence,
    nightmare,
    newg_end
  );

var
  NewGameMenu: array[0..4] of menuitem_t;
  NewDef: menu_t;

type
//
// OPTIONS MENU
//
  options_e = (
    opt_general,
    opt_display,
    opt_sound,
    opt_compatibility,
    opt_controls,
    opt_system,
    opt_end
  );

var
  OptionsMenu: array[0..Ord(opt_end) - 1] of menuitem_t;
  OptionsDef: menu_t;

// GENERAL MENU
type
  optionsgeneral_e = (
    endgame,
    messages,
    scrnsize,
    option_empty1,
    mousesens,
    option_empty2,
    optgen_end
  );

var
  OptionsGeneralMenu: array[0..Ord(optgen_end) - 1] of menuitem_t;
  OptionsGeneralDef: menu_t;

// DISPLAY MENU
type
  optionsdisplay_e = (
    od_opengl,
    od_appearance,
    od_advanced,
    od_32bitsetup,
    optdisp_end
  );

var
  OptionsDisplayMenu: array[0..Ord(optdisp_end) - 1] of menuitem_t;
  OptionsDisplayDef: menu_t;

// DISPLAY DETAIL MENU
type
  optionsdisplaydetail_e = (
    od_detaillevel,
    od_allowlowdetails,
    optdispdetail_end
  );

var
  OptionsDisplayDetailMenu: array[0..Ord(optdispdetail_end) - 1] of menuitem_t;
  OptionsDisplayDetailDef: menu_t;

// DISPLAY APPEARANCE MENU
type
  optionsdisplayappearance_e = (
    od_drawfps,
    od_shademenubackground,
    od_displaydiskbusyicon,
    od_showdemoplaybackprogress,
    optdispappearance_end
  );

var
  OptionsDisplayAppearanceMenu: array[0..Ord(optdispappearance_end) - 1] of menuitem_t;
  OptionsDisplayAppearanceDef: menu_t;

// DISPLAY ADVANCED MENU
type
  optionsdisplayadvanced_e = (
    od_fullscreen,
    od_usetransparentsprites,
    od_interpolate,
    od_zaxisshift,
    od_chasecamera,
    od_fixstallhack,
    od_hidedoublicatedbarrels,
    optdispadvanced_end
  );

var
  OptionsDisplayAdvancedMenu: array[0..Ord(optdispadvanced_end) - 1] of menuitem_t;
  OptionsDisplayAdvancedDef: menu_t;

// DISPLAY 32 BIT RENDERING MENU
type
  optionsdisplay32bit_e = (
    od_uselightboost,
    od_forcecolormaps,
    od_32bittexturepaletteeffects,
    od_use32bitfuzzeffect,
    od_useexternaltextures,
    od_preferetexturesnamesingamedirectory,
    od_flatfiltering,
    optdisp32bit_end
  );

var
  OptionsDisplay32bitMenu: array[0..Ord(optdisp32bit_end) - 1] of menuitem_t;
  OptionsDisplay32bitDef: menu_t;

// DISPLAY OPENGL RENDERING MENU
type
  optionsdisplayopengl_e = (
    od_usefog,
    od_gl_texture_filter_anisotropic,
    od_gl_drawsky,
    od_gl_stencilsky,
    od_gl_drawmodels,
    od_gl_smoothmodelmovement,
    od_gl_precachemodeltextures,
    od_gl_uselightmaps,
    od_gl_linear_hud,
    od_gl_add_all_lines,
    od_gl_useglnodesifavailable,
    od_gl_autoloadgwafiles,
    od_gl_screensync,
    optdispopengl_end
  );

var
  OptionsDisplayOpenGLMenu: array[0..Ord(optdispopengl_end) - 1] of menuitem_t;
  OptionsDisplayOpenGLDef: menu_t;

type
//
// Read This! MENU 1 & 2
//
  read_e = (
    rdthsempty1,
    read1_end
  );

var
  ReadMenu1: array[0..0] of menuitem_t;
  ReadDef1: menu_t;

type
  read_e2 = (
    rdthsempty2,
    read2_end
  );

var
  ReadMenu2: array[0..0] of menuitem_t;
  ReadDef2: menu_t;

type
//
// SOUND MENU
//
  sound_e = (
    snd_volume,
    snd_usemp3,
    snd_preferemp3namesingamedirectory,
    snd_usewav,
    snd_preferewavnamesingamedirectory,
    sound_end
  );

var
  SoundMenu: array[0..Ord(sound_end) - 1] of menuitem_t;
  SoundDef: menu_t;

type
//
// SOUND VOLUME MENU
//
  soundvol_e = (
    sfx_vol,
    sfx_empty1,
    music_vol,
    sfx_empty2,
    soundvol_end
  );

var
  SoundVolMenu: array[0..Ord(soundvol_end) - 1] of menuitem_t;
  SoundVolDef: menu_t;

type
//
// COMPATIBILITY MENU
//
  compatibility_e = (
    cmp_allowplayerjumps,
    cmp_keepcheatsinplayerrebord,
    cmp_majorbossdeathendsdoom1level,
    cmp_spawnrandommonsters,
    cmp_allowterrainsplashes,
    cmp_continueafterplayerdeath,
    cmp_end
  );

var
  CompatibilityMenu: array[0..Ord(cmp_end) - 1] of menuitem_t;
  CompatibilityDef: menu_t;

type
//
// CONTROLS MENU
//
  controls_e = (
    ctrl_usemouse,
    ctrl_invertmouselook,
    ctrl_invertmouseturn,
    ctrl_usejoystic,
    ctrl_autorun,
    ctrl_keyboardmodearrows,
    ctrl_keyboardmodewasd,
    ctrl_end
  );

var
  ControlsMenu: array[0..Ord(ctrl_end) - 1] of menuitem_t;
  ControlsDef: menu_t;

type
//
// SYSTEM  MENU
//
  system_e = (
    sys_safemode,
    sys_usemmx,
    sys_criticalcpupriority,
    sys_usemultithread,
    sys_end
  );

var
  SystemMenu: array[0..Ord(sys_end) - 1] of menuitem_t;
  SystemDef: menu_t;

var
  LoadMenu: array[0..Ord(load_end) - 1] of menuitem_t;
  LoadDef: menu_t;
  SaveMenu: array[0..Ord(load_end) - 1] of menuitem_t;
  SaveDef: menu_t;

//==============================================================================
//
// M_ReadSaveStrings
//  read the strings from the savegame files
//
//==============================================================================
procedure M_ReadSaveStrings;
var
  handle: file;
  i: integer;
  name: string;
begin
  for i := 0 to Ord(load_end) - 1 do
  begin
    sprintf(name, M_SaveFileName(SAVEGAMENAME) + '%d.dsg', [i]);

    if not fopen(handle, name, fOpenReadOnly) then
    begin
      savegamestrings[i] := 'EMPTY SLOT';
      LoadMenu[i].status := 0;
      continue;
    end;
    savegamestrings[i] := 'GAME ' + itoa(i + 1);
    close(handle);
    LoadMenu[i].status := 1;
  end;
end;

//==============================================================================
// M_DrawSaveLoadBorder
//
// Draw border for the savegame description
//
//==============================================================================
procedure M_DrawSaveLoadBorder(x, y: integer);
var
  i: integer;
begin
  V_DrawPatch(x - 8, y + 7, SCN_TMP, 'M_LSLEFT', false);

  for i := 0 to 10 do
  begin
    V_DrawPatch (x, y + 7, SCN_TMP, 'M_LSCNTR', false);
    x := x + 8;
  end;

  V_DrawPatch(x, y + 7, SCN_TMP, 'M_LSRGHT', false);
end;

//==============================================================================
// M_DrawLoad
//
// M_LoadGame & Cie.
//
//==============================================================================
procedure M_DrawLoad;
var
  i: integer;
begin
 // V_DrawPatch(72, LoadDef.y - 26, SCN_TMP, 'M_LOADG', false);
  for i := 0 to Ord(load_end) - 1 do
  begin
    M_DrawSaveLoadBorder(LoadDef.x, LoadDef.y + LoadDef.itemheight * i);
    M_WriteText(LoadDef.x, LoadDef.y + LoadDef.itemheight * i, savegamestrings[i]);
  end;
end;

//==============================================================================
// M_LoadSelect
//
// User wants to load this game
//
//==============================================================================
procedure M_LoadSelect(choice: integer);
var
  name: string;
begin
  sprintf(name, M_SaveFileName(SAVEGAMENAME) + '%d.dsg', [choice]);
  G_LoadGame(name);
  M_ClearMenus;
end;

//==============================================================================
// M_LoadGame
//
// Selected from DOOM menu
//
//==============================================================================
procedure M_LoadGame(choice: integer);
begin
{  if netgame then
  begin
    M_StartMessage(LOADNET + #13#10 + PRESSKEY, nil, false);
    exit;
  end;      }

  M_SetupNextMenu(@LoadDef);
  M_ReadSaveStrings;
end;

//==============================================================================
// M_DrawSave
//
//  M_SaveGame & Cie.
//
//==============================================================================
procedure M_DrawSave;
var
  i: integer;
begin
 // V_DrawPatch(72, LoadDef.y - 28, SCN_TMP, 'M_SAVEG', false);
  for i := 0 to Ord(load_end) - 1 do
  begin
    M_DrawSaveLoadBorder(LoadDef.x, LoadDef.y + LoadDef.itemheight * i);
    M_WriteText(LoadDef.x, LoadDef.y + LoadDef.itemheight * i, savegamestrings[i]);
  end;

  if saveStringEnter <> 0 then
  begin
    {i := }M_StringWidth(savegamestrings[saveSlot]);
   { if (gametic div 18) mod 2 = 0 then
      M_WriteText(LoadDef.x + i, LoadDef.y + LoadDef.itemheight * saveSlot, '_'); }
  end;
end;

//==============================================================================
// M_DoSave
//
// M_Responder calls this when user is finished
//
//==============================================================================
procedure M_DoSave(slot: integer);
begin
  G_SaveGame(slot, 'SLOT' + itoa(slot + 1));
  M_ClearMenus;

  // PICK QUICKSAVE SLOT YET?
  if (quickSaveSlot = -2) then
    quickSaveSlot := slot;
end;

//==============================================================================
// M_SaveSelect
//
// User wants to save. Start string input for M_Responder
//
//==============================================================================
procedure M_SaveSelect(choice: integer);
begin
  // we are going to be intercepting all chars
  saveStringEnter := 1;

  saveSlot := choice;
  saveOldString := savegamestrings[choice];
  if savegamestrings[choice] <> '' then
    savegamestrings[choice] := 'SLOT' + itoa(choice+1);

  saveCharIndex := Length(savegamestrings[choice]);
end;

//==============================================================================
// M_SaveGame
//
// Selected from DOOM menu
//
//==============================================================================
procedure M_SaveGame(choice: integer);
begin
  if gamestate <> GS_LEVEL then
    exit;

  M_SetupNextMenu(@SaveDef);
  M_ReadSaveStrings;
end;

//==============================================================================
// M_SwtchnSound
//
//      M_QuickSave
//
//==============================================================================
procedure M_SwtchnSound;
begin
  S_StartSound(nil, Ord(sfx_swtchn));
end;

//==============================================================================
//
// M_SwtchxSound
//
//==============================================================================
procedure M_SwtchxSound;
begin
  S_StartSound(nil, Ord(sfx_swtchn));
end;

//==============================================================================
//
// M_QuickSaveResponse
//
//==============================================================================
procedure M_QuickSaveResponse(ch: integer);
begin
  if ch = Ord('y') then
  begin
    M_DoSave(quickSaveSlot);
    M_SwtchxSound;
  end;
end;

//==============================================================================
//
// M_QuickSave
//
//==============================================================================
procedure M_QuickSave;
var
  tempstring: string;
begin
  if not usergame then
  begin
    S_StartSound(nil, Ord(sfx_oof));
    exit;
  end;

  if gamestate <> GS_LEVEL then
    exit;

  if quickSaveSlot < 0 then
  begin
    M_StartControlPanel;
    M_ReadSaveStrings;
    M_SetupNextMenu(@SaveDef);
    quickSaveSlot := -2;  // means to pick a slot now
    exit;
  end;

  sprintf(tempstring, QSPROMPT + #13#10 + PRESSYN, [savegamestrings[quickSaveSlot]]);
  M_StartMessage(tempstring, @M_QuickSaveResponse, true);
end;

//==============================================================================
// M_QuickLoadResponse
//
// M_QuickLoad
//
//==============================================================================
procedure M_QuickLoadResponse(ch: integer);
begin
  if ch = Ord('y') then
  begin
    M_LoadSelect(quickSaveSlot);
    M_SwtchxSound;
  end;
end;

//==============================================================================
//
// M_QuickLoad
//
//==============================================================================
procedure M_QuickLoad;
var
  tempstring: string;
begin
  if netgame then
  begin
    M_StartMessage(QLOADNET + #13#10 + PRESSKEY, nil, false);
    exit;
  end;

  if quickSaveSlot < 0 then
  begin
    M_StartMessage(QSAVESPOT + #13#10 + PRESSKEY, nil, false);
    exit;
  end;

  sprintf(tempstring, QLPROMPT + #13#10 + PRESSYN, [savegamestrings[quickSaveSlot]]);
  M_StartMessage(tempstring, @M_QuickLoadResponse, true);
end;

//==============================================================================
// M_DrawReadThis1
//
// Read This Menus
// Had a "quick hack to fix romero bug"
//
//==============================================================================
procedure M_DrawReadThis1;
begin
  inhelpscreens := true;
  case gamemode of
    commercial:
      V_PageDrawer(pg_HELP);
    shareware,
    registered,
    retail:
      V_PageDrawer(pg_HELP1);
  end;
end;

//==============================================================================
// M_DrawReadThis2
//
// Read This Menus - optional second page.
//
//==============================================================================
procedure M_DrawReadThis2;
begin
  inhelpscreens := true;
  case gamemode of
    retail,
    commercial:
      // This hack keeps us from having to change menus.
      V_PageDrawer(pg_CREDIT);
    shareware,
    registered:
      V_PageDrawer(pg_HELP2);
  end;
end;

//==============================================================================
// M_DrawSoundVol
//
// Change Sfx & Music volumes
//
//==============================================================================
procedure M_DrawSoundVol;
begin
  V_DrawPatch(60, 38, SCN_TMP, 'M_SVOL', false);

  M_DrawThermo(
    SoundVolDef.x, SoundVolDef.y + SoundVolDef.itemheight * (Ord(sfx_vol) + 1), 16, snd_SfxVolume);

  M_DrawThermo(
    SoundVolDef.x, SoundVolDef.y + SoundVolDef.itemheight * (Ord(music_vol) + 1), 16, snd_MusicVolume);
end;

//==============================================================================
//
// M_DrawCompatibility
//
//==============================================================================
procedure M_DrawCompatibility;
begin
  V_DrawPatch(108, 15, SCN_TMP, 'M_OPTTTL', false);
  M_WriteText(20, 48, 'Compatibility', 2 * FRACUNIT);
end;

//==============================================================================
//
// M_DrawControls
//
//==============================================================================
procedure M_DrawControls;
begin
  V_DrawPatch(108, 15, SCN_TMP, 'M_OPTTTL', false);
  M_WriteText(20, 48, 'Controls', 2 * FRACUNIT);

  M_WriteText(ControlsDef.x, ControlsDef.y + ControlsDef.itemheight * Ord(ctrl_keyboardmodearrows), 'Use arrows for moving');
  M_WriteText(ControlsDef.x, ControlsDef.y + ControlsDef.itemheight * Ord(ctrl_keyboardmodewasd), 'Use WASD keys for moving');
end;

//==============================================================================
//
// M_DrawSound
//
//==============================================================================
procedure M_DrawSound;
begin
  V_DrawPatch(108, 15, SCN_TMP, 'M_OPTTTL', false);
  M_WriteText(20, 48, 'Sound', 2 * FRACUNIT);
end;

//==============================================================================
//
// M_DrawSystem
//
//==============================================================================
procedure M_DrawSystem;
begin
  V_DrawPatch(108, 15, SCN_TMP, 'M_OPTTTL', false);
  M_WriteText(20, 48, 'System', 2 * FRACUNIT);
end;

//==============================================================================
//
// M_OptionsSound
//
//==============================================================================
procedure M_OptionsSound(choice: integer);
begin
  M_SetupNextMenu(@SoundDef);
end;

//==============================================================================
//
// M_SoundVolume
//
//==============================================================================
procedure M_SoundVolume(choice: integer);
begin
  M_SetupNextMenu(@SoundVolDef);
end;

//==============================================================================
//
// M_OptionsConrols
//
//==============================================================================
procedure M_OptionsConrols(choice: integer);
begin
  M_SetupNextMenu(@ControlsDef);
end;

//==============================================================================
//
// M_OptionsCompatibility
//
//==============================================================================
procedure M_OptionsCompatibility(choice: integer);
begin
  M_SetupNextMenu(@CompatibilityDef);
end;

//==============================================================================
//
// M_OptionsSystem
//
//==============================================================================
procedure M_OptionsSystem(choice: integer);
begin
  M_SetupNextMenu(@SystemDef);
end;

//==============================================================================
//
// M_OptionsGeneral
//
//==============================================================================
procedure M_OptionsGeneral(choice: integer);
begin
  M_SetupNextMenu(@OptionsGeneralDef);
end;

//==============================================================================
//
// M_OptionsDisplay
//
//==============================================================================
procedure M_OptionsDisplay(choice: integer);
begin
  M_SetupNextMenu(@OptionsDisplayDef);
end;

//==============================================================================
//
// M_OptionsDisplayDetail
//
//==============================================================================
procedure M_OptionsDisplayDetail(choice: integer);
begin
  M_SetupNextMenu(@OptionsDisplayDetailDef);
end;

//==============================================================================
//
// M_OptionsDisplayAppearance
//
//==============================================================================
procedure M_OptionsDisplayAppearance(choice: integer);
begin
  M_SetupNextMenu(@OptionsDisplayAppearanceDef);
end;

//==============================================================================
//
// M_OptionsDisplayAdvanced
//
//==============================================================================
procedure M_OptionsDisplayAdvanced(choice: integer);
begin
  M_SetupNextMenu(@OptionsDisplayAdvancedDef);
end;

//==============================================================================
//
// M_OptionsDisplay32bit
//
//==============================================================================
procedure M_OptionsDisplay32bit(choice: integer);
begin
  M_SetupNextMenu(@OptionsDisplay32bitDef);
end;

//==============================================================================
//
// M_OptionsDisplayOpenGL
//
//==============================================================================
procedure M_OptionsDisplayOpenGL(choice: integer);
begin
  M_SetupNextMenu(@OptionsDisplayOpenGLDef);
end;

//==============================================================================
//
// M_SfxVol
//
//==============================================================================
procedure M_SfxVol(choice: integer);
begin
  case choice of
    0: if snd_SfxVolume <> 0 then dec(snd_SfxVolume);
    1: if snd_SfxVolume < 15 then inc(snd_SfxVolume);
  end;
  S_SetSfxVolume(snd_SfxVolume);
end;

//==============================================================================
//
// M_MusicVol
//
//==============================================================================
procedure M_MusicVol(choice: integer);
begin
  case choice of
    0: if snd_MusicVolume <> 0 then dec(snd_MusicVolume);
    1: if snd_MusicVolume < 15 then inc(snd_MusicVolume);
  end;
  S_SetMusicVolume(snd_MusicVolume);
end;

//==============================================================================
//
// M_DrawMainMenu
//
//==============================================================================
procedure M_DrawMainMenu;
begin
end;

//==============================================================================
// M_DrawNewGame
//
// M_NewGame
//
//==============================================================================
procedure M_DrawNewGame;
begin
//  V_DrawPatch(96, 14, SCN_TMP, 'M_NEWG', false);
//  V_DrawPatch(54, 38, SCN_TMP, 'M_SKILL', false);
end;

//==============================================================================
//
// M_NewGame
//
//==============================================================================
procedure M_NewGame(choice: integer);
begin
  if netgame and (not demoplayback) then
  begin
    M_StartMessage(SNEWGAME + #13#10 + PRESSKEY, nil, false);
    exit;
  end;

      NewDef.numitems := Ord(nightmare); // No nightmare in old shareware shareware
    M_SetupNextMenu(@NewDef);
(*  if gamemode = commercial then
  begin
    if oldsharewareversion then
      NewDef.numitems := Ord(nightmare); // No nightmare in old shareware shareware
    M_SetupNextMenu(@NewDef);
  end
  else
    M_SetupNextMenu(@EpiDef);  *)
end;

//
//      M_Episode
//
var
  epi: integer;

//==============================================================================
//
// M_DrawEpisode
//
//==============================================================================
procedure M_DrawEpisode;
begin
  V_DrawPatch(54, 38, SCN_TMP, 'M_EPISOD', false);
end;

//==============================================================================
//
// M_VerifyNightmare
//
//==============================================================================
procedure M_VerifyNightmare(ch: integer);
begin
  if ch <> Ord('y') then
    exit;

  G_DeferedInitNew(sk_nightmare, epi + 1, 1); // JVAL nightmare become sk_nightmare
  M_ClearMenus;
end;

//==============================================================================
//
// M_ChooseSkill
//
//==============================================================================
procedure M_ChooseSkill(choice: integer);
begin
{  if choice = Ord(nightmare) then
  begin
    M_StartMessage(SNIGHTMARE + #13#10 + PRESSYN, @M_VerifyNightmare, true);
    exit;
  end;      }

  G_DeferedInitNew(skill_t(choice), epi + 1, 1);
  M_ClearMenus;
end;

//==============================================================================
//
// M_Episode
//
//==============================================================================
procedure M_Episode(choice: integer);
begin
  if (gamemode = shareware) and (choice <> 0) then
  begin
    M_StartMessage(SWSTRING + #13#10 + PRESSKEY, nil, false);
    M_SetupNextMenu(@ReadDef1);
    exit;
  end;

  // Yet another hack...
  if (gamemode = registered) and (choice > 2) then
  begin
    I_Warning('M_Episode(): 4th episode requires UltimateDOOM' + #13#10);
    choice := 0;
  end;

  epi := choice;

  M_SetupNextMenu(@NewDef);
end;

//
// M_Options
//
var
  msgNames: array[0..1] of string = ('M_MSGOFF', 'M_MSGON');

//==============================================================================
//
// M_DrawOptions
//
//==============================================================================
procedure M_DrawOptions;
begin
  V_DrawPatch(108, 15, SCN_TMP, 'M_OPTTTL', false);
end;

//==============================================================================
//
// M_DrawGeneralOptions
//
//==============================================================================
procedure M_DrawGeneralOptions;
begin
  V_DrawPatch(108, 15, SCN_TMP, 'M_OPTTTL', false);

  V_DrawPatch(OptionsGeneralDef.x + 120, OptionsGeneralDef.y + OptionsGeneralDef.itemheight * Ord(messages), SCN_TMP,
      msgNames[showMessages], false);

  M_DrawThermo(
    OptionsGeneralDef.x, OptionsGeneralDef.y + OptionsGeneralDef.itemheight * (Ord(mousesens) + 1), 10, mouseSensitivity);

  M_DrawThermo(
    OptionsGeneralDef.x, OptionsGeneralDef.y + OptionsGeneralDef.itemheight * (Ord(scrnsize) + 1), 9, m_screensize);
end;

//==============================================================================
//
// M_DrawDisplayOptions
//
//==============================================================================
procedure M_DrawDisplayOptions;
var
  lump: integer;
begin
  lump := W_CheckNumForName('M_DISOPT');
  if lump >= 0 then
    V_DrawPatch(52, 15, SCN_TMP, lump, false)
  else
    V_DrawPatch(108, 15, SCN_TMP, 'M_OPTTTL', false);
end;

var
  colordepths: array[boolean] of string = ('8bit', '32bit');

//==============================================================================
//
// M_DrawDisplayDetailOptions
//
//==============================================================================
procedure M_DrawDisplayDetailOptions;
var
  stmp: string;
begin
  M_DrawDisplayOptions;
  sprintf(stmp, 'Detail level: %s (%dx%dx32)', [detailStrings[detailLevel], SCREENWIDTH, SCREENHEIGHT]);
  M_WriteText(OptionsDisplayDetailDef.x, OptionsDisplayDetailDef.y + OptionsDisplayDetailDef.itemheight * Ord(od_detaillevel), stmp);
end;

//==============================================================================
//
// M_DrawDisplayAppearanceOptions
//
//==============================================================================
procedure M_DrawDisplayAppearanceOptions;
begin
  M_DrawDisplayOptions;
end;

//==============================================================================
//
// M_DrawOptionsDisplayAdvanced
//
//==============================================================================
procedure M_DrawOptionsDisplayAdvanced;
begin
  M_DrawDisplayOptions;
end;

//==============================================================================
//
// M_DrawOptionsDisplay32bit
//
//==============================================================================
procedure M_DrawOptionsDisplay32bit;
begin
  M_DrawDisplayOptions;

  M_WriteText(OptionsDisplay32bitDef.x, OptionsDisplay32bitDef.y + OptionsDisplay32bitDef.itemheight * Ord(od_flatfiltering),
    'Flat filtering: ' + flatfilteringstrings[extremeflatfiltering]);
end;

//==============================================================================
//
// M_DrawOptionsDisplayOpenGL
//
//==============================================================================
procedure M_DrawOptionsDisplayOpenGL;
begin
  M_DrawDisplayOptions;
end;

//==============================================================================
//
// M_Options
//
//==============================================================================
procedure M_Options(choice: integer);
begin
  M_SetupNextMenu(@OptionsDef);
end;

//==============================================================================
// M_ChangeMessages
//
//      Toggle messages on/off
//
//==============================================================================
procedure M_ChangeMessages(choice: integer);
begin
  showMessages := 1 - showMessages;

  if showMessages = 0 then
    players[consoleplayer]._message := MSGOFF
  else
    players[consoleplayer]._message := MSGON;

  message_dontfuckwithme := true;
end;

//==============================================================================
// M_EndGameResponse
//
// M_EndGame
//
//==============================================================================
procedure M_EndGameResponse(ch: integer);
begin
  if ch <> Ord('y') then
    exit;

  currentMenu.lastOn := itemOn;
  M_ClearMenus;
  D_StartTitle;
end;

//==============================================================================
//
// M_CmdEndGame
//
//==============================================================================
procedure M_CmdEndGame;
begin
  if not usergame then
  begin
    S_StartSound(nil, Ord(sfx_oof));
    exit;
  end;

  if netgame then
  begin
    M_StartMessage(NETEND + #13#10 + PRESSKEY, nil, false);
    exit;
  end;

  M_StartMessage(SENDGAME + #13#10 + PRESSYN, @M_EndGameResponse, true);
 //jval: wolf C_ExecuteCmd('closeconsole', '1');
end;

//==============================================================================
//
// M_EndGame
//
//==============================================================================
procedure M_EndGame(choice: integer);
begin
  M_CmdEndGame;
end;

//==============================================================================
//
// M_ReadThis
//
//==============================================================================
procedure M_ReadThis(choice: integer);
begin
  M_SetupNextMenu(@ReadDef1);
end;

//==============================================================================
//
// M_ReadThis2
//
//==============================================================================
procedure M_ReadThis2(choice: integer);
begin
  M_SetupNextMenu(@ReadDef2);
end;

//==============================================================================
//
// M_FinishReadThis
//
//==============================================================================
procedure M_FinishReadThis(choice: integer);
begin
  M_SetupNextMenu(@MainDef);
end;

//
// M_QuitDOOM
//
const
  quitsounds: array[0..7] of integer = (
    Ord(sfx_pldeth),
    Ord(sfx_dmpain),
    Ord(sfx_popain),
    Ord(sfx_slop),
    Ord(sfx_telept),
    Ord(sfx_posit1),
    Ord(sfx_posit3),
    Ord(sfx_sgtatk)
  );

  quitsounds2: array[0..7] of integer = (
    Ord(sfx_vilact),
    Ord(sfx_getpow),
    Ord(sfx_boscub),
    Ord(sfx_slop),
    Ord(sfx_skeswg),
    Ord(sfx_kntdth),
    Ord(sfx_bspact),
    Ord(sfx_sgtatk)
  );

//==============================================================================
//
// M_CmdQuit
//
//==============================================================================
procedure M_CmdQuit;
begin
  if not netgame then
  begin
{    if gamemode = commercial then
      S_StartSound(nil, quitsounds2[_SHR(gametic, 2) and 7])
    else
      S_StartSound(nil, quitsounds[_SHR(gametic, 2) and 7]);   }
    I_WaitVBL(1000);
  end;
  if (gamestate = GS_LEVEL)  and not demoplayback  then
  begin
    currentMenu.lastOn := itemOn;
    M_ClearMenus;
    D_StartTitle;
  end
  else
    G_Quit;
end;

//==============================================================================
//
// M_QuitDOOM
//
//==============================================================================
procedure M_QuitDOOM(choice: integer);
begin
  M_CmdQuit;
end;

//==============================================================================
//
// M_Demo
//
//==============================================================================
procedure M_Demo;
begin
  players[consoleplayer].playerstate := PST_LIVE;  // not reborn
  advancedemo := false;
  usergame := false;               // no save / end game here
  paused := false;
  gameaction := ga_nothing;
  demoplayback := true;
  G_DeferedPlayDemo('5');
  menuactive := false;
end;

//==============================================================================
//
// M_ChangeSensitivity
//
//==============================================================================
procedure M_ChangeSensitivity(choice: integer);
begin
  case choice of
    0:
      if mouseSensitivity > 0 then
        dec(mouseSensitivity);
    1:
      if mouseSensitivity < 9 then
        inc(mouseSensitivity);
  end;
end;

//==============================================================================
//
// M_ChangeDetail
//
//==============================================================================
procedure M_ChangeDetail(choice: integer);
begin
  detailLevel := (detailLevel + 1) mod DL_NUMRESOLUTIONS;

  R_SetViewSize;

  case detailLevel of
    DL_LOWEST:
      players[consoleplayer]._message := DETAILLOWEST;
    DL_LOW:
      players[consoleplayer]._message := DETAILLOW;
    DL_MEDIUM:
      players[consoleplayer]._message := DETAILMED;
    DL_NORMAL:
      players[consoleplayer]._message := DETAILNORM;
    DL_HIRES:
      players[consoleplayer]._message := DETAILHI;
    DL_ULTRARES:
      players[consoleplayer]._message := DETAILULTRA;
  end;

end;

//==============================================================================
//
// M_ChangeFlatFiltering
//
//==============================================================================
procedure M_ChangeFlatFiltering(choice: integer);
begin
  C_ExecuteCmd('extremeflatfiltering', yesnoStrings[not extremeflatfiltering]);
end;

//==============================================================================
//
// M_BoolCmd
//
//==============================================================================
procedure M_BoolCmd(choice: integer);
var
  s: string;
begin
  s := currentMenu.menuitems[choice].cmd;
  if length(s) = 0 then
    I_Error('M_BoolCmd(): Unknown option');
  C_ExecuteCmd(s, yesnoStrings[not currentMenu.menuitems[choice].pBoolVal^]);
end;

//==============================================================================
//
// M_KeyboardModeArrows
//
//==============================================================================
procedure M_KeyboardModeArrows(choice: integer);
begin
  G_SetKeyboardMode(0);
end;

//==============================================================================
//
// M_KeyboardModeWASD
//
//==============================================================================
procedure M_KeyboardModeWASD(choice: integer);
begin
  G_SetKeyboardMode(1);
end;

//==============================================================================
//
// M_CmdKeyboardMode
//
//==============================================================================
procedure M_CmdKeyboardMode(const parm1, parm2: string);
var
  wrongparms: boolean;
begin
  wrongparms := false;

  if (parm1 = '') or (parm2 <> '') then
    wrongparms := true;

  if (parm1 <> '0') and (parm1 <> '1') then
    wrongparms := true;

  if wrongparms then
  begin
    printf('Specify the keyboard mode:'#13#10);
    printf('  0: Arrows'#13#10);
    printf('  1: WASD'#13#10);
    exit;
  end;

  if parm1 = '0' then
    G_SetKeyboardMode(0)
  else
    G_SetKeyboardMode(1);

end;

//==============================================================================
//
// M_SizeDisplay
//
//==============================================================================
procedure M_SizeDisplay(choice: integer);
begin
  case choice of
    0:
      begin
        if m_screensize > 0 then
        begin
          dec(screenblocks);
          dec(m_screensize);
        end;
      end;
    1:
      begin
        if m_screensize < 8 then
        begin
          inc(screenblocks);
          inc(m_screensize);
        end;
      end;
  end;

  R_SetViewSize;
end;

//
// CONTROL PANEL
//

//
// M_Responder
//
var
  joywait: integer;
  mousewait: integer;
  mmousex: integer;
  mmousey: integer;
  mlastx: integer;
  mlasty: integer;
  m_altdown: boolean = false;

//==============================================================================
//
// M_Responder
//
//==============================================================================
function M_Responder(ev: Pevent_t): boolean;
var
  ch: integer;
  i: integer;
begin
  if (ev.data1 = KEY_RALT) or (ev.data1 = KEY_LALT) then
  begin
    m_altdown := ev._type = ev_keydown;
    result := false;
    exit;
  end;

  if ev._type = ev_keydown then
    ch := ev.data1
  else
  begin
    result := false;
    exit;
  end;

  // Save Game string input
  if saveStringEnter <> 0 then
  begin
    saveStringEnter := 0;
    M_DoSave(saveSlot);
    result := true;
    exit;
  end;

  // F-Keys
  if not menuactive and false then
    case ch of
      KEY_ENTER:
        begin
          if m_altdown then
          begin
            GL_ChangeFullScreen(not fullscreen);
            result := true;
            exit;
          end;
        end;
    end;

  // Pop-up menu?
  if not menuactive then
  begin
    if ch = KEY_ESCAPE then
    begin
      M_StartControlPanel;
      M_SwtchnSound;
      result := true;
      exit;
    end;
    result := false;
    exit;
  end;

  // Keys usable within menu
  case ch of
    KEY_PAGEUP:
      begin
        itemOn := -1;
        repeat
          inc(itemOn);
          S_StartSound(nil, Ord(sfx_pstop));
        until currentMenu.menuitems[itemOn].status <> -1;
        result := true;
        exit;
      end;
    KEY_PAGEDOWN:
      begin
        itemOn := currentMenu.numitems;
        repeat
          dec(itemOn);
          S_StartSound(nil, Ord(sfx_pstop));
        until currentMenu.menuitems[itemOn].status <> -1;
        result := true;
        exit;
      end;
    KEY_DOWNARROW:
      begin
        repeat
          if itemOn + 1 > currentMenu.numitems - 1 then
            itemOn := 0
          else
            inc(itemOn);
          S_StartSound(nil, Ord(sfx_pstop));
        until currentMenu.menuitems[itemOn].status <> -1;
        result := true;
        exit;
      end;
    KEY_UPARROW:
      begin
        repeat
          if itemOn = 0 then
            itemOn := currentMenu.numitems - 1
          else
            dec(itemOn);
          S_StartSound(nil, Ord(sfx_pstop));
        until currentMenu.menuitems[itemOn].status <> -1;
        result := true;
        exit;
      end;
    KEY_LEFTARROW:
      begin
        if Assigned(currentMenu.menuitems[itemOn].routine) and
          (currentMenu.menuitems[itemOn].status = 2) then
        begin
          S_StartSound(nil, Ord(sfx_stnmov));
          currentMenu.menuitems[itemOn].routine(0);
        end;
        result := true;
        exit;
      end;
    KEY_RIGHTARROW:
      begin
        if Assigned(currentMenu.menuitems[itemOn].routine) and
          (currentMenu.menuitems[itemOn].status = 2) then
        begin
          S_StartSound(nil, Ord(sfx_stnmov));
          currentMenu.menuitems[itemOn].routine(1);
        end;
        result := true;
        exit;
      end;
    KEY_ENTER:
      begin
        if Assigned(currentMenu.menuitems[itemOn].routine) and
          (currentMenu.menuitems[itemOn].status <> 0) then
        begin
          currentMenu.lastOn := itemOn;
          if currentMenu.menuitems[itemOn].status = 2 then
          begin
            currentMenu.menuitems[itemOn].routine(1); // right arrow
            S_StartSound(nil, Ord(sfx_stnmov));
          end
          else
          begin
            currentMenu.menuitems[itemOn].routine(itemOn);
            S_StartSound(nil, Ord(sfx_pistol));
          end;
        end;
        result := true;
        exit;
      end;
    KEY_ESCAPE:
      begin
        currentMenu.lastOn := itemOn;
        M_ClearMenus;
        M_SwtchxSound;
        result := true;
        exit;
      end;
    KEY_BACKSPACE:
      begin
        currentMenu.lastOn := itemOn;
        if currentMenu.prevMenu <> nil then
        begin
          currentMenu := currentMenu.prevMenu;
          itemOn := currentMenu.lastOn;
          M_SwtchnSound;
        end;
        result := true;
        exit;
      end;
  else
    begin
      for i := itemOn + 1 to currentMenu.numitems - 1 do
        if currentMenu.menuitems[i].alphaKey = Chr(ch) then
        begin
          itemOn := i;
          S_StartSound(nil, Ord(sfx_pstop));
          result := true;
          exit;
        end;
      for i := 0 to itemOn do
        if currentMenu.menuitems[i].alphaKey = Chr(ch) then
        begin
          itemOn := i;
          S_StartSound(nil, Ord(sfx_pstop));
          result := true;
          exit;
        end;
    end;
  end;

  result := false;
end;

//==============================================================================
//
// M_StartControlPanel
//
//==============================================================================
procedure M_StartControlPanel;
begin
  // intro might call this repeatedly
  if menuactive then
    exit;

  menuactive := true;
  currentMenu := @MainDef;// JDC
  itemOn := currentMenu.lastOn; // JDC
end;

//==============================================================================
// M_Thr_ShadeScreen
//
// M_Drawer
// Called after the view has been rendered,
// but before it has been blitted.
//
// JVAL
// Threaded shades the half screen
//
//==============================================================================
function M_Thr_ShadeScreen(p: pointer): integer; stdcall;
var
  half: integer;
begin
  half := V_GetScreenWidth(SCN_FG) * V_GetScreenHeight(SCN_FG) div 2;
  V_ShadeBackground(half, V_GetScreenWidth(SCN_FG) * V_GetScreenHeight(SCN_FG) - half);
  result := 0;
end;

//==============================================================================
//
// M_MenuShader
//
//==============================================================================
procedure M_MenuShader;
var
  h1: integer;
begin
  if (not wipedisplay) and shademenubackground then
  begin
    if usemultithread then
    begin
    // JVAL
      h1 := I_CreateProcess(@M_Thr_ShadeScreen, nil);
      V_ShadeBackground(0, V_GetScreenWidth(SCN_FG) * V_GetScreenHeight(SCN_FG) div 2);
      // Wait for extra thread to terminate.
      I_WaitForProcess(h1);
    end
    else
      V_ShadeBackground;
  end;
end;

//==============================================================================
//
// M_FinishUpdate
//
//==============================================================================
procedure M_FinishUpdate(const height: integer);
begin
  // JVAL
  // Menu is no longer drawn to primary surface,
  // Instead we use SCN_TMP and after the drawing we blit to primary surface
  if inhelpscreens then
  begin
    V_CopyRectTransparent(0, 0, SCN_TMP, 320, 200, 0, 0, SCN_FG, true);
    inhelpscreens := false;
  end
  else
  begin
    M_MenuShader;
    V_CopyRectTransparent(0, 0, SCN_TMP, 320, height, 0, 0, SCN_FG, true);
  end;
end;

//==============================================================================
//
// M_Drawer
//
//==============================================================================
procedure M_Drawer;
var
  i: integer;
  max: integer;
  str: string;
  len: integer;
  x, y: integer;
  mheight: integer;
begin
 // Horiz. & Vertically center string and print it.
  if messageToPrint <> 0 then
  begin

    mheight := M_StringHeight(messageString);
    y := (200 - mheight) div 2;
    mheight := y + mheight + 20;
    ZeroMemory(screens[SCN_TMP], 320 * mheight);
    len := Length(messageString);
    str := '';
    for i := 1 to len do
    begin
      if messageString[i] = #13 then
        y := y + hu_font[0].height
      else if messageString[i] = #10 then
      begin
        x := (320 - M_StringWidth(str)) div 2;
        M_WriteText(x, y, str);
        str := '';
      end
      else
        str := str + messageString[i];
    end;
    if str <> '' then
    begin
      x := (320 - M_StringWidth(str)) div 2;
      y := y + hu_font[0].height;
      M_WriteText(x, y, str);
    end;

    M_FinishUpdate(mheight);
    exit;
  end;

  if not menuactive then
    exit;

  if (gamestate = GS_LEVEL) and not demoplayback then
    MainMenu[4].name := '@End game'
  else
    MainMenu[4].name := '@Exit';

   ZeroMemory(screens[SCN_TMP], 320 * 200);

  if Assigned(currentMenu.routine) then
    currentMenu.routine; // call Draw routine

  // DRAW MENU
  x := currentMenu.x;
  y := currentMenu.y;
  max := currentMenu.numitems;

  for i := 0 to max - 1 do
  begin
    str := currentMenu.menuitems[i].name;
    if str <> '' then
    begin
      if str[1] = '@' then // Draw text
      begin
        delete(str, 1, 1);
        M_WriteText(x, y, str, {2 *} FRACUNIT)
      end
      else if str[1] = '!' then // Draw text with Yes/No
      begin
        delete(str, 1, 1);
        if currentMenu.menuitems[i].pBoolVal <> nil then
          M_WriteText(x, y, str + ': ' + yesnoStrings[currentMenu.menuitems[i].pBoolVal^])
        else
          M_WriteText(x, y, str);
      end
      else
        V_DrawPatch(x, y, SCN_TMP,
          currentMenu.menuitems[i].name, false);
    end;
    y := y + currentMenu.itemheight;
  end;

  if currentMenu.itemheight <= LINEHEIGHT2 then
    M_WriteText(x + ARROWXOFF, currentMenu.y + itemOn * LINEHEIGHT2, '>')
  else
    // DRAW SKULL
    V_DrawPatch(x + SKULLXOFF, currentMenu.y + SKULLYOFF + itemOn * LINEHEIGHT, SCN_TMP,
      skullName[whichSkull], false);

  M_FinishUpdate(200);
end;

//==============================================================================
//
// M_Ticker
//
//==============================================================================
procedure M_Ticker;
begin
  dec(skullAnimCounter);
  if skullAnimCounter <= 0 then
  begin
    whichSkull := whichSkull xor 1;
    skullAnimCounter := 8;
  end;
end;

//==============================================================================
//
// M_CmdSetupNextMenu
//
//==============================================================================
procedure M_CmdSetupNextMenu(menudef: Pmenu_t);
begin
  menuactive := true;
  if (menudef = @LoadDef) or (menudef = @SaveDef) then
    M_ReadSaveStrings;
  M_SetupNextMenu(menudef);
  C_ExecuteCmd('closeconsole');
end;

//==============================================================================
//
// M_CmdMenuMainDef
//
//==============================================================================
procedure M_CmdMenuMainDef;
begin
  M_CmdSetupNextMenu(@MainDef);
end;

//==============================================================================
//
// M_CmdMenuNewDef
//
//==============================================================================
procedure M_CmdMenuNewDef;
begin
  M_CmdSetupNextMenu(@NewDef);
end;

//==============================================================================
//
// M_CmdMenuOptionsDef
//
//==============================================================================
procedure M_CmdMenuOptionsDef;
begin
  M_CmdSetupNextMenu(@OptionsDef);
end;

//==============================================================================
//
// M_CmdMenuOptionsGeneralDef
//
//==============================================================================
procedure M_CmdMenuOptionsGeneralDef;
begin
  M_CmdSetupNextMenu(@OptionsGeneralDef);
end;

//==============================================================================
//
// M_CmdMenuOptionsDisplayDef
//
//==============================================================================
procedure M_CmdMenuOptionsDisplayDef;
begin
  M_CmdSetupNextMenu(@OptionsDisplayDef);
end;

//==============================================================================
//
// M_CmdMenuOptionsDisplayDetailDef
//
//==============================================================================
procedure M_CmdMenuOptionsDisplayDetailDef;
begin
  M_CmdSetupNextMenu(@OptionsDisplayDetailDef);
end;

//==============================================================================
//
// M_CmdMenuOptionsDisplayAppearanceDef
//
//==============================================================================
procedure M_CmdMenuOptionsDisplayAppearanceDef;
begin
  M_CmdSetupNextMenu(@OptionsDisplayAppearanceDef);
end;

//==============================================================================
//
// M_CmdMenuOptionsDisplayAdvancedDef
//
//==============================================================================
procedure M_CmdMenuOptionsDisplayAdvancedDef;
begin
  M_CmdSetupNextMenu(@OptionsDisplayAdvancedDef);
end;

//==============================================================================
//
// M_CmdMenuOptionsDisplay32bitDef
//
//==============================================================================
procedure M_CmdMenuOptionsDisplay32bitDef;
begin
  M_CmdSetupNextMenu(@OptionsDisplay32bitDef);
end;

//==============================================================================
//
// M_CmdOptionsDisplayOpenGL
//
//==============================================================================
procedure M_CmdOptionsDisplayOpenGL;
begin
  M_CmdSetupNextMenu(@OptionsDisplayOpenGLDef);
end;

//==============================================================================
//
// M_CmdMenuSoundDef
//
//==============================================================================
procedure M_CmdMenuSoundDef;
begin
  M_CmdSetupNextMenu(@SoundDef);
end;

//==============================================================================
//
// M_CmdMenuSoundVolDef
//
//==============================================================================
procedure M_CmdMenuSoundVolDef;
begin
  M_CmdSetupNextMenu(@SoundVolDef);
end;

//==============================================================================
//
// M_CmdMenuCompatibilityDef
//
//==============================================================================
procedure M_CmdMenuCompatibilityDef;
begin
  M_CmdSetupNextMenu(@CompatibilityDef);
end;

//==============================================================================
//
// M_CmdMenuControlsDef
//
//==============================================================================
procedure M_CmdMenuControlsDef;
begin
  M_CmdSetupNextMenu(@ControlsDef);
end;

//==============================================================================
//
// M_CmdMenuSystemDef
//
//==============================================================================
procedure M_CmdMenuSystemDef;
begin
  M_CmdSetupNextMenu(@SystemDef);
end;

//==============================================================================
//
// M_CmdMenuLoadDef
//
//==============================================================================
procedure M_CmdMenuLoadDef;
begin
  M_CmdSetupNextMenu(@LoadDef);
end;

//==============================================================================
//
// M_CmdMenuSaveDef
//
//==============================================================================
procedure M_CmdMenuSaveDef;
begin
  M_CmdSetupNextMenu(@SaveDef);
end;

//==============================================================================
//
// M_Init
//
//==============================================================================
procedure M_Init;
begin
  currentMenu := @MainDef;
  menuactive := false;
  itemOn := currentMenu.lastOn;
  whichSkull := 0;
  skullAnimCounter := 10;
  m_screensize := screenblocks - 4;
  messageToPrint := 0;
  messageString := '';
  messageLastMenuActive := menuactive;
  quickSaveSlot := -1;

  // Here we could catch other version dependencies,
  //  like HELP1/2, and four episodes.

        // This is used because DOOM 2 had only one HELP
        //  page. I use CREDIT as second page now, but
        //  kept this hack for educational purposes.
     //   MainMenu[Ord(mm_readthis)] := MainMenu[Ord(mm_quitdoom)];
     ///   dec(MainDef.numitems);
        MainDef.y := MainDef.y + 8;
        NewDef.prevMenu := @MainDef;
        ReadDef1.routine := M_DrawReadThis1;
        ReadDef1.x := 330;
        ReadDef1.y := 165;
        ReadMenu1[0].routine := @M_FinishReadThis;
     (*
  case gamemode of
    commercial:
      begin
        // This is used because DOOM 2 had only one HELP
        //  page. I use CREDIT as second page now, but
        //  kept this hack for educational purposes.
        MainMenu[Ord(mm_readthis)] := MainMenu[Ord(mm_quitdoom)];
        dec(MainDef.numitems);
        MainDef.y := MainDef.y + 8;
        NewDef.prevMenu := @MainDef;
        ReadDef1.routine := M_DrawReadThis1;
        ReadDef1.x := 330;
        ReadDef1.y := 165;
        ReadMenu1[0].routine := @M_FinishReadThis;
      end;
    shareware:
      begin
        ReadDef2.x := 280;
        ReadDef2.y := 185; // x,y of menu
        // We need to remove the fourth episode.
        // Episode 2 and 3 are handled,
        // branching to an ad screen.
        dec(EpiDef.numitems);
      end;
    registered:
      begin
        // We need to remove the fourth episode.
        dec(EpiDef.numitems);
      end;
  end;
               *)
  C_AddCmd('keyboardmode', @M_CmdKeyboardMode);
  C_AddCmd('exit, quit', @M_CmdQuit);
  C_AddCmd('set', @Cmd_Set);
  C_AddCmd('get', @Cmd_Get);
  C_AddCmd('typeof', @Cmd_TypeOf);
  C_AddCmd('endgame', @M_CmdEndGame);
  C_AddCmd('defaults, setdefaults', @M_SetDefaults);
  C_AddCmd('default, setdefault', @M_SetDefaults);
  C_AddCmd('menu_main', @M_CmdMenuMainDef);
  C_AddCmd('menu_newgame, menu_new', @M_CmdMenuNewDef);
  C_AddCmd('menu_options', @M_CmdMenuOptionsDef);
  C_AddCmd('menu_optionsgeneral, menu_generaloptions', @M_CmdMenuOptionsGeneralDef);
  C_AddCmd('menu_optionsdisplay, menu_displayoptions, menu_display', @M_CmdMenuOptionsDisplayDef);
  C_AddCmd('menu_optionsdisplayappearence, menu_displayappearenceoptions, menu_displayappearence', @M_CmdMenuOptionsDisplayAppearanceDef);
  C_AddCmd('menu_optionsdisplayadvanced, menu_displayadvancedoptions, menu_displayadvanced', @M_CmdMenuOptionsDisplayAdvancedDef);
  C_AddCmd('menu_optionsdisplay32bit, menu_display32bitoptions, menu_display32bit', @M_CmdMenuOptionsDisplay32bitDef);
  C_AddCmd('menu_optionsdisplayopengl, menu_optionsopengl, menu_opengl', @M_CmdOptionsDisplayOpenGL);
  C_AddCmd('menu_optionssound, menu_soundoptions, menu_sound', @M_CmdMenuSoundDef);
  C_AddCmd('menu_optionssoundvol, menu_soundvoloptions, menu_soundvol', @M_CmdMenuSoundVolDef);
  C_AddCmd('menu_optionscompatibility, menu_compatibilityoptions, menu_compatibility', @M_CmdMenuCompatibilityDef);
  C_AddCmd('menu_optionscontrols, menu_controlsoptions, menu_controls', @M_CmdMenuControlsDef);
  C_AddCmd('menu_optionssystem, menu_systemoptions, menu_system', @M_CmdMenuSystemDef);
  C_AddCmd('menu_load, menu_loadgame', @M_CmdMenuLoadDef);
  C_AddCmd('menu_save, menu_savegame', @M_CmdMenuSaveDef);
end;

//==============================================================================
//
// M_InitMenus
//
//==============================================================================
procedure M_InitMenus;
var
  i: integer;
  pmi: Pmenuitem_t;
begin
////////////////////////////////////////////////////////////////////////////////
//gammamsg
  gammamsg[0] := GAMMALVL0;
  gammamsg[1] := GAMMALVL1;
  gammamsg[2] := GAMMALVL2;
  gammamsg[3] := GAMMALVL3;
  gammamsg[4] := GAMMALVL4;

////////////////////////////////////////////////////////////////////////////////
//skullName
  skullName[0] := 'M_SKULL1';
  skullName[1] := 'M_SKULL2';

////////////////////////////////////////////////////////////////////////////////
// MainMenu
  pmi := @MainMenu[0];
  pmi.status := 1;
  pmi.name := '@New Game';
  pmi.cmd := '';
  pmi.routine := @M_NewGame;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'n';

 { inc(pmi);
  pmi.status := 1;
  pmi.name := 'M_OPTION';
  pmi.cmd := '';
  pmi.routine := @M_Options;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'o';      }

  inc(pmi);
  pmi.status := 1;
  pmi.name := '@Load Game';
  pmi.cmd := '';
  pmi.routine := @M_LoadGame;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'l';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '@Save Game';
  pmi.cmd := '';
  pmi.routine := @M_SaveGame;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 's';

  // Another hickup with Special edition.
{  inc(pmi);
  pmi.status := 1;
  pmi.name := 'M_RDTHIS';
  pmi.cmd := '';
  pmi.routine := @M_ReadThis;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'r';     }

  inc(pmi);
  pmi.status := 1;
  pmi.name := '@Demo';
  pmi.cmd := '';
  pmi.routine := @M_Demo;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'd';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '@Exit';
  pmi.cmd := '';
  pmi.routine := @M_QuitDOOM;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'q';

////////////////////////////////////////////////////////////////////////////////
//MainDef
  MainDef.numitems := Ord(main_end);
  MainDef.prevMenu := nil;
  MainDef.menuitems := Pmenuitem_tArray(@MainMenu);
  MainDef.routine := @M_DrawMainMenu;  // draw routine
  MainDef.x := 97;
  MainDef.y := 64;
  MainDef.lastOn := 0;
  MainDef.itemheight := LINEHEIGHT;

////////////////////////////////////////////////////////////////////////////////
//EpisodeMenu
  pmi := @EpisodeMenu[0];
  pmi.status := 1;
  pmi.name := 'M_EPI1';
  pmi.cmd := '';
  pmi.routine := @M_Episode;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'k';

  inc(pmi);
  pmi.status := 1;
  pmi.name := 'M_EPI2';
  pmi.cmd := '';
  pmi.routine := @M_Episode;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 't';

  inc(pmi);
  pmi.status := 1;
  pmi.name := 'M_EPI3';
  pmi.cmd := '';
  pmi.routine := @M_Episode;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'i';

  inc(pmi);
  pmi.status := 1;
  pmi.name := 'M_EPI4';
  pmi.cmd := '';
  pmi.routine := @M_Episode;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 't';

////////////////////////////////////////////////////////////////////////////////
//EpiDef
  EpiDef.numitems := Ord(ep_end); // # of menu items
  EpiDef.prevMenu := @MainDef; // previous menu
  EpiDef.menuitems := Pmenuitem_tArray(@EpisodeMenu);  // menu items
  EpiDef.routine := @M_DrawEpisode;  // draw routine
  EpiDef.x := 48;
  EpiDef.y := 63; // x,y of menu
  EpiDef.lastOn := Ord(ep1); // last item user was on in menu
  EpiDef.itemheight := LINEHEIGHT;

////////////////////////////////////////////////////////////////////////////////
//NewGameMenu
  pmi := @NewGameMenu[0];
  pmi.status := 1;
  pmi.name := '@Beginner';
  pmi.cmd := '';
  pmi.routine := @M_ChooseSkill;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'i';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '@Easy';
  pmi.cmd := '';
  pmi.routine := @M_ChooseSkill;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'h';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '@Normal';
  pmi.cmd := '';
  pmi.routine := @M_ChooseSkill;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'h';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '@Hard';
  pmi.cmd := '';
  pmi.routine := @M_ChooseSkill;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'u';

 { inc(pmi);
  pmi.status := 1;
  pmi.name := 'M_NMARE';
  pmi.cmd := '';
  pmi.routine := @M_ChooseSkill;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'n';     }

////////////////////////////////////////////////////////////////////////////////
//NewDef
  NewDef.numitems := Ord(newg_end); // # of menu items
  NewDef.prevMenu := @EpiDef; // previous menu
  NewDef.menuitems := Pmenuitem_tArray(@NewGameMenu);  // menu items
  NewDef.routine := @M_DrawNewGame;  // draw routine
  NewDef.x := 97;
  NewDef.y := 72; // x,y of menu
  NewDef.lastOn := Ord(killthings); // last item user was on in menu
  NewDef.itemheight := LINEHEIGHT;

////////////////////////////////////////////////////////////////////////////////
//OptionsMenu
  pmi := @OptionsMenu[0];
  pmi.status := 1;
  pmi.name := '@General';
  pmi.cmd := '';
  pmi.routine := @M_OptionsGeneral;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'g';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '@Display';
  pmi.cmd := '';
  pmi.routine := @M_OptionsDisplay;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'd';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '@Sound';
  pmi.cmd := '';
  pmi.routine := @M_OptionsSound;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 's';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '@Compatibility';
  pmi.cmd := '';
  pmi.routine := @M_OptionsCompatibility;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'c';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '@Controls';
  pmi.cmd := '';
  pmi.routine := @M_OptionsConrols;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'r';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '@System';
  pmi.cmd := '';
  pmi.routine := @M_OptionsSystem;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'y';

////////////////////////////////////////////////////////////////////////////////
//OptionsDef
  OptionsDef.numitems := Ord(opt_end); // # of menu items
  OptionsDef.prevMenu := @MainDef; // previous menu
  OptionsDef.menuitems := Pmenuitem_tArray(@OptionsMenu);  // menu items
  OptionsDef.routine := @M_DrawOptions;  // draw routine
  OptionsDef.x := 72;
  OptionsDef.y := 48; // x,y of menu
  OptionsDef.lastOn := 0; // last item user was on in menu
  OptionsDef.itemheight := LINEHEIGHT;

////////////////////////////////////////////////////////////////////////////////
//OptionsGeneralMenu
  pmi := @OptionsGeneralMenu[0];
  pmi.status := 1;
  pmi.name := 'M_ENDGAM';
  pmi.cmd := '';
  pmi.routine := @M_EndGame;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'e';

  inc(pmi);
  pmi.status := 1;
  pmi.name := 'M_MESSG';
  pmi.cmd := '';
  pmi.routine := @M_ChangeMessages;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'm';

  inc(pmi);
  pmi.status := 2;
  pmi.name := 'M_SCRNSZ';
  pmi.cmd := '';
  pmi.routine := @M_SizeDisplay;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 's';

  inc(pmi);
  pmi.status := -1;
  pmi.name := '';
  pmi.cmd := '';
  pmi.routine := nil;
  pmi.pBoolVal := nil;
  pmi.alphaKey := #0;

  inc(pmi);
  pmi.status := 2;
  pmi.name := 'M_MSENS';
  pmi.cmd := '';
  pmi.routine := @M_ChangeSensitivity;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'm';

  inc(pmi);
  pmi.status := -1;
  pmi.name := '';
  pmi.cmd := '';
  pmi.routine := nil;
  pmi.pBoolVal := nil;
  pmi.alphaKey := #0;

////////////////////////////////////////////////////////////////////////////////
//OptionsGeneralDef
  OptionsGeneralDef.numitems := Ord(optgen_end); // # of menu items
  OptionsGeneralDef.prevMenu := @OptionsDef; // previous menu
  OptionsGeneralDef.menuitems := Pmenuitem_tArray(@OptionsGeneralMenu);  // menu items
  OptionsGeneralDef.routine := @M_DrawGeneralOptions;  // draw routine
  OptionsGeneralDef.x := 80;
  OptionsGeneralDef.y := 48; // x,y of menu
  OptionsGeneralDef.lastOn := 0; // last item user was on in menu
  OptionsGeneralDef.itemheight := LINEHEIGHT;

////////////////////////////////////////////////////////////////////////////////
//OptionsDisplayMenu
  pmi := @OptionsDisplayMenu[0];
  pmi.status := 1;
  pmi.name := '@OpenGL';
  pmi.cmd := '';
  pmi.routine := @M_OptionsDisplayOpenGL;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'o';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '@Appearance';
  pmi.cmd := '';
  pmi.routine := @M_OptionsDisplayAppearance;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'a';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '@Advanced';
  pmi.cmd := '';
  pmi.routine := @M_OptionsDisplayAdvanced;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'v';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '@32 bit rendering';
  pmi.cmd := '';
  pmi.routine := @M_OptionsDisplay32bit;
  pmi.pBoolVal := nil;
  pmi.alphaKey := '3';

////////////////////////////////////////////////////////////////////////////////
//OptionsDisplayDef
  OptionsDisplayDef.numitems := Ord(optdisp_end); // # of menu items
  OptionsDisplayDef.prevMenu := @OptionsDef; // previous menu
  OptionsDisplayDef.menuitems := Pmenuitem_tArray(@OptionsDisplayMenu);  // menu items
  OptionsDisplayDef.routine := @M_DrawDisplayOptions;  // draw routine
  OptionsDisplayDef.x := 50;
  OptionsDisplayDef.y := 40; // x,y of menu
  OptionsDisplayDef.lastOn := 0; // last item user was on in menu
  OptionsDisplayDef.itemheight := LINEHEIGHT;

////////////////////////////////////////////////////////////////////////////////
//OptionsDisplayDetailMenu
  pmi := @OptionsDisplayDetailMenu[0];
  pmi.status := 1;
  pmi.name := '';
  pmi.cmd := '';
  pmi.routine := @M_ChangeDetail;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'd';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Allow low details';
  pmi.cmd := 'allowlowdetails';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @allowlowdetails;
  pmi.alphaKey := 'l';

////////////////////////////////////////////////////////////////////////////////
//OptionsDisplayDetailDef
  OptionsDisplayDetailDef.numitems := Ord(optdispdetail_end); // # of menu items
  OptionsDisplayDetailDef.prevMenu := @OptionsDisplayDef; // previous menu
  OptionsDisplayDetailDef.menuitems := Pmenuitem_tArray(@OptionsDisplayDetailMenu);  // menu items
  OptionsDisplayDetailDef.routine := @M_DrawDisplayDetailOptions;  // draw routine
  OptionsDisplayDetailDef.x := 30;
  OptionsDisplayDetailDef.y := 40; // x,y of menu
  OptionsDisplayDetailDef.lastOn := 0; // last item user was on in menu
  OptionsDisplayDetailDef.itemheight := LINEHEIGHT2;

////////////////////////////////////////////////////////////////////////////////
//OptionsDisplayAppearanceMenu
  pmi := @OptionsDisplayAppearanceMenu[0];
  pmi.status := 1;
  pmi.name := '!Display fps';
  pmi.cmd := 'drawfps';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @drawfps;
  pmi.alphaKey := 'f';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Shade menu background';
  pmi.cmd := 'shademenubackground';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @shademenubackground;
  pmi.alphaKey := 's';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Display disk busy icon';
  pmi.cmd := 'displaydiskbusyicon';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @displaydiskbusyicon;
  pmi.alphaKey := 'b';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Display demo playback progress';
  pmi.cmd := 'showdemoplaybackprogress';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @showdemoplaybackprogress;
  pmi.alphaKey := 'p';

////////////////////////////////////////////////////////////////////////////////
//OptionsDisplayAppearanceDef
  OptionsDisplayAppearanceDef.numitems := Ord(optdispappearance_end); // # of menu items
  OptionsDisplayAppearanceDef.prevMenu := @OptionsDisplayDef; // previous menu
  OptionsDisplayAppearanceDef.menuitems := Pmenuitem_tArray(@OptionsDisplayAppearanceMenu);  // menu items
  OptionsDisplayAppearanceDef.routine := @M_DrawDisplayAppearanceOptions;  // draw routine
  OptionsDisplayAppearanceDef.x := 30;
  OptionsDisplayAppearanceDef.y := 40; // x,y of menu
  OptionsDisplayAppearanceDef.lastOn := 0; // last item user was on in menu
  OptionsDisplayAppearanceDef.itemheight := LINEHEIGHT2;

////////////////////////////////////////////////////////////////////////////////
//OptionsDisplayAdvancedMenu
  pmi := @OptionsDisplayAdvancedMenu[0];
  pmi.status := 1;
  pmi.name := '!Fullscreen';
  pmi.cmd := 'fullscreen';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @fullscreen;
  pmi.alphaKey := 'f';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Transparent sprites';
  pmi.cmd := 'usetransparentsprites';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @usetransparentsprites;
  pmi.alphaKey := 's';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Interpolate';
  pmi.cmd := 'interpolate';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @interpolate;
  pmi.alphaKey := 'i';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Z-Axis Shift';
  pmi.cmd := 'zaxisshift';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @zaxisshift;
  pmi.alphaKey := 'z';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Chase camera';
  pmi.cmd := 'chasecamera';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @chasecamera;
  pmi.alphaKey := 'c';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Stretch to fix memory stall';
  pmi.cmd := 'fixstallhack';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @fixstallhack;
  pmi.alphaKey := 's';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Hide duplicated barrels';
  pmi.cmd := 'hidedoublicatedbarrels';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @hidedoublicatedbarrels;
  pmi.alphaKey := 'b';

////////////////////////////////////////////////////////////////////////////////
//OptionsDisplayAdvancedDef
  OptionsDisplayAdvancedDef.numitems := Ord(optdispadvanced_end); // # of menu items
  OptionsDisplayAdvancedDef.prevMenu := @OptionsDisplayDef; // previous menu
  OptionsDisplayAdvancedDef.menuitems := Pmenuitem_tArray(@OptionsDisplayAdvancedMenu);  // menu items
  OptionsDisplayAdvancedDef.routine := @M_DrawOptionsDisplayAdvanced;  // draw routine
  OptionsDisplayAdvancedDef.x := 30;
  OptionsDisplayAdvancedDef.y := 40; // x,y of menu
  OptionsDisplayAdvancedDef.lastOn := 0; // last item user was on in menu
  OptionsDisplayAdvancedDef.itemheight := LINEHEIGHT2;

////////////////////////////////////////////////////////////////////////////////
//OptionsDisplay32bitMenu
  pmi := @OptionsDisplay32bitMenu[0];
  pmi.status := 1;
  pmi.name := '!Light effects';
  pmi.cmd := 'uselightboost';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @uselightboost;
  pmi.alphaKey := 'e';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Use 32 bit colormaps';
  pmi.cmd := 'forcecolormaps';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @forcecolormaps;
  pmi.alphaKey := 'c';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!32 bit palette effect simulation';
  pmi.cmd := '32bittexturepaletteeffects';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @dc_32bittexturepaletteeffects;
  pmi.alphaKey := 'p';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Use classic fuzz effect in 32 bit';
  pmi.cmd := 'use32bitfuzzeffect';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @use32bitfuzzeffect;
  pmi.alphaKey := 'f';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Use external textures';
  pmi.cmd := 'useexternaltextures';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @useexternaltextures;
  pmi.alphaKey := 'x';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Search texture paths in PK3';
  pmi.cmd := 'preferetexturesnamesingamedirectory';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @preferetexturesnamesingamedirectory;
  pmi.alphaKey := 'p';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '';
  pmi.cmd := '';
  pmi.routine := @M_ChangeFlatFiltering;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'f';

////////////////////////////////////////////////////////////////////////////////
//OptionsDisplay32bitDef
  OptionsDisplay32bitDef.numitems := Ord(optdisp32bit_end); // # of menu items
  OptionsDisplay32bitDef.prevMenu := @OptionsDisplayDef; // previous menu
  OptionsDisplay32bitDef.menuitems := Pmenuitem_tArray(@OptionsDisplay32bitMenu);  // menu items
  OptionsDisplay32bitDef.routine := @M_DrawOptionsDisplay32bit;  // draw routine
  OptionsDisplay32bitDef.x := 30;
  OptionsDisplay32bitDef.y := 40; // x,y of menu
  OptionsDisplay32bitDef.lastOn := 0; // last item user was on in menu
  OptionsDisplay32bitDef.itemheight := LINEHEIGHT2;

////////////////////////////////////////////////////////////////////////////////
//OptionsDisplayOpenGLMenu
  pmi := @OptionsDisplayOpenGLMenu[0];
  pmi.status := 1;
  pmi.name := '!Use fog';
  pmi.cmd := 'use_fog';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @use_fog;
  pmi.alphaKey := 'f';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Anisotropic texture filtering';
  pmi.cmd := 'gl_texture_filter_anisotropic';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @gl_texture_filter_anisotropic;
  pmi.alphaKey := 'a';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Draw Sky';
  pmi.cmd := 'gl_drawsky';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @gl_drawsky;
  pmi.alphaKey := 's';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Use stencil buffer for sky';
  pmi.cmd := 'gl_stencilsky';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @gl_stencilsky;
  pmi.alphaKey := 'c';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Draw models instead of sprites';
  pmi.cmd := 'gl_drawmodels';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @gl_drawmodels;
  pmi.alphaKey := 'm';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Smooth model movement';
  pmi.cmd := 'gl_smoothmodelmovement';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @gl_smoothmodelmovement;
  pmi.alphaKey := 's';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Precache model textures';
  pmi.cmd := 'gl_precachemodeltextures';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @gl_precachemodeltextures;
  pmi.alphaKey := 'p';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Use lightmaps';
  pmi.cmd := 'gl_uselightmaps';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @gl_uselightmaps;
  pmi.alphaKey := 'l';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Linear HUD filtering';
  pmi.cmd := 'gl_linear_hud';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @gl_linear_hud;
  pmi.alphaKey := 'h';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Draw all linedefs';
  pmi.cmd := 'gl_add_all_lines';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @gl_add_all_lines;
  pmi.alphaKey := 'l';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Use GL_NODES if available';
  pmi.cmd := 'useglnodesifavailable';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @useglnodesifavailable;
  pmi.alphaKey := 'u';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Automatically load GWA files';
  pmi.cmd := 'autoloadgwafiles';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @autoloadgwafiles;
  pmi.alphaKey := 'g';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Limit framerate to screen sync';
  pmi.cmd := 'gl_screensync';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @gl_screensync;
  pmi.alphaKey := 'y';

////////////////////////////////////////////////////////////////////////////////
//OptionsDisplayOpenGLDef
  OptionsDisplayOpenGLDef.numitems := Ord(optdispopengl_end); // # of menu items
  OptionsDisplayOpenGLDef.prevMenu := @OptionsDisplayDef; // previous menu
  OptionsDisplayOpenGLDef.menuitems := Pmenuitem_tArray(@OptionsDisplayOpenGLMenu);  // menu items
  OptionsDisplayOpenGLDef.routine := @M_DrawOptionsDisplayOpenGL;  // draw routine
  OptionsDisplayOpenGLDef.x := 30;
  OptionsDisplayOpenGLDef.y := 40; // x,y of menu
  OptionsDisplayOpenGLDef.lastOn := 0; // last item user was on in menu
  OptionsDisplayOpenGLDef.itemheight := LINEHEIGHT2;

////////////////////////////////////////////////////////////////////////////////
//ReadMenu1
  pmi := @ReadMenu1[0];
  pmi.status := 1;
  pmi.name := '';
  pmi.cmd := '';
  pmi.routine := @M_ReadThis2;
  pmi.pBoolVal := nil;
  pmi.alphaKey := #0;

////////////////////////////////////////////////////////////////////////////////
//ReadDef1
  ReadDef1.numitems := Ord(read1_end); // # of menu items
  ReadDef1.prevMenu := @MainDef; // previous menu
  ReadDef1.menuitems := Pmenuitem_tArray(@ReadMenu1);  // menu items
  ReadDef1.routine := @M_DrawReadThis1;  // draw routine
  ReadDef1.x := 330;
  ReadDef1.y := 165; // x,y of menu
  ReadDef1.lastOn := 0; // last item user was on in menu
  ReadDef1.itemheight := LINEHEIGHT;

////////////////////////////////////////////////////////////////////////////////
//ReadMenu2
  pmi := @ReadMenu2[0];
  pmi.status := 1;
  pmi.name := '';
  pmi.cmd := '';
  pmi.routine := @M_FinishReadThis;
  pmi.pBoolVal := nil;
  pmi.alphaKey := #0;

////////////////////////////////////////////////////////////////////////////////
//ReadDef2
  ReadDef2.numitems := Ord(read2_end); // # of menu items
  ReadDef2.prevMenu := @ReadDef1; // previous menu
  ReadDef2.menuitems := Pmenuitem_tArray(@ReadMenu2);  // menu items
  ReadDef2.routine := @M_DrawReadThis2;  // draw routine
  ReadDef2.x := 330;
  ReadDef2.y := 165; // x,y of menu
  ReadDef2.lastOn := 0; // last item user was on in menu
  ReadDef2.itemheight := LINEHEIGHT;

////////////////////////////////////////////////////////////////////////////////
//SoundMenu
  pmi := @SoundMenu[0];
  pmi.status := 1;
  pmi.name := '!Volume Control';
  pmi.cmd := '';
  pmi.routine := @M_SoundVolume;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'v';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Use external MP3 files';
  pmi.cmd := 'usemp3';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @usemp3;
  pmi.alphaKey := 'm';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Search MP3 paths in PK3';
  pmi.cmd := 'preferemp3namesingamedirectory';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @preferemp3namesingamedirectory;
  pmi.alphaKey := 's';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Use external WAV files';
  pmi.cmd := 'useexternalwav';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @useexternalwav;
  pmi.alphaKey := 'w';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Search WAV paths in PK3';
  pmi.cmd := 'preferewavnamesingamedirectory';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @preferewavnamesingamedirectory;
  pmi.alphaKey := 's';

////////////////////////////////////////////////////////////////////////////////
//SoundDef
  SoundDef.numitems := Ord(sound_end); // # of menu items
  SoundDef.prevMenu := @OptionsDef; // previous menu
  SoundDef.menuitems := Pmenuitem_tArray(@SoundMenu);  // menu items
  SoundDef.routine := @M_DrawSound;  // draw routine
  SoundDef.x := 32;
  SoundDef.y := 68; // x,y of menu
  SoundDef.lastOn := 0; // last item user was on in menu
  SoundDef.itemheight := LINEHEIGHT2;

////////////////////////////////////////////////////////////////////////////////
//SoundVolMenu
  pmi := @SoundVolMenu[0];
  pmi.status := 2;
  pmi.name := 'M_SFXVOL';
  pmi.cmd := '';
  pmi.routine := @M_SfxVol;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 's';

  inc(pmi);
  pmi.status := -1;
  pmi.name := '';
  pmi.cmd := '';
  pmi.routine := nil;
  pmi.pBoolVal := nil;
  pmi.alphaKey := #0;

  inc(pmi);
  pmi.status := 2;
  pmi.name := 'M_MUSVOL';
  pmi.cmd := '';
  pmi.routine := @M_MusicVol;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'm';

  inc(pmi);
  pmi.status := -1;
  pmi.name := '';
  pmi.cmd := '';
  pmi.routine := nil;
  pmi.pBoolVal := nil;
  pmi.alphaKey := #0;

////////////////////////////////////////////////////////////////////////////////
//SoundVolDef
  SoundVolDef.numitems := Ord(soundvol_end); // # of menu items
  SoundVolDef.prevMenu := @SoundDef; // previous menu
  SoundVolDef.menuitems := Pmenuitem_tArray(@SoundVolMenu);  // menu items
  SoundVolDef.routine := @M_DrawSoundVol;  // draw routine
  SoundVolDef.x := 80;
  SoundVolDef.y := 64; // x,y of menu
  SoundVolDef.lastOn := 0; // last item user was on in menu
  SoundVolDef.itemheight := LINEHEIGHT;

////////////////////////////////////////////////////////////////////////////////
//CompatibilityMenu
  pmi := @CompatibilityMenu[0];
  pmi.status := 1;
  pmi.name := '!Allow player jumps';
  pmi.cmd := 'allowplayerjumps';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @allowplayerjumps;
  pmi.alphaKey := 'j';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Keep cheats when reborn';
  pmi.cmd := 'keepcheatsinplayerreborn';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @keepcheatsinplayerreborn;
  pmi.alphaKey := 'c';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Major boss death ends Doom1 level';
  pmi.cmd := 'majorbossdeathendsdoom1level';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @majorbossdeathendsdoom1level;
  pmi.alphaKey := 'd';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Spawn random monsters';
  pmi.cmd := 'spawnrandommonsters';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @spawnrandommonsters;
  pmi.alphaKey := 's';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Splashes on special terrains';
  pmi.cmd := 'allowterrainsplashes';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @allowterrainsplashes;
  pmi.alphaKey := 't';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Monsters fight after player death';
  pmi.cmd := 'continueafterplayerdeath';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @continueafterplayerdeath;
  pmi.alphaKey := 'f';

////////////////////////////////////////////////////////////////////////////////
//CompatibilityDef
  CompatibilityDef.numitems := Ord(cmp_end); // # of menu items
  CompatibilityDef.prevMenu := @OptionsDef; // previous menu
  CompatibilityDef.menuitems := Pmenuitem_tArray(@CompatibilityMenu);  // menu items
  CompatibilityDef.routine := @M_DrawCompatibility;  // draw routine
  CompatibilityDef.x := 32;
  CompatibilityDef.y := 68; // x,y of menu
  CompatibilityDef.lastOn := 0; // last item user was on in menu
  CompatibilityDef.itemheight := LINEHEIGHT2;

////////////////////////////////////////////////////////////////////////////////
//ControlsMenu
  pmi := @ControlsMenu[0];
  pmi.status := 1;
  pmi.name := '!Use mouse';
  pmi.cmd := 'use_mouse';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @usemouse;
  pmi.alphaKey := 'm';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Invert mouse up/down look';
  pmi.cmd := 'invertmouselook';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @invertmouselook;
  pmi.alphaKey := 'i';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Invert mouse turn left/right';
  pmi.cmd := 'invertmouseturn';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @invertmouseturn;
  pmi.alphaKey := 'i';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Use joystic';
  pmi.cmd := 'use_joystick';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @usejoystick;
  pmi.alphaKey := 'j';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Always run';
  pmi.cmd := 'autorunmode';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @autorunmode;
  pmi.alphaKey := 'a';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '';
  pmi.cmd := '';
  pmi.routine := @M_KeyboardModeArrows;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'k';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '';
  pmi.cmd := '';
  pmi.routine := @M_KeyboardModeWASD;
  pmi.pBoolVal := nil;
  pmi.alphaKey := 'k';

////////////////////////////////////////////////////////////////////////////////
//ControlsDef
  ControlsDef.numitems := Ord(ctrl_end); // # of menu items
  ControlsDef.prevMenu := @OptionsDef; // previous menu
  ControlsDef.menuitems := Pmenuitem_tArray(@ControlsMenu);  // menu items
  ControlsDef.routine := @M_DrawControls;  // draw routine
  ControlsDef.x := 32;
  ControlsDef.y := 68; // x,y of menu
  ControlsDef.lastOn := 0; // last item user was on in menu
  ControlsDef.itemheight := LINEHEIGHT2;

////////////////////////////////////////////////////////////////////////////////
//SystemMenu
  pmi := @SystemMenu[0];
  pmi.status := 1;
  pmi.name := '!Safe mode';
  pmi.cmd := 'safemode';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @safemode;
  pmi.alphaKey := 's';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Use mmx/AMD 3D-Now';
  pmi.cmd := 'mmx';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @usemmx;
  pmi.alphaKey := 'm';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Time critical CPU priority';
  pmi.cmd := 'criticalcpupriority';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @criticalcpupriority;
  pmi.alphaKey := 'c';

  inc(pmi);
  pmi.status := 1;
  pmi.name := '!Multithreading functions';
  pmi.cmd := 'usemultithread';
  pmi.routine := @M_BoolCmd;
  pmi.pBoolVal := @usemultithread;
  pmi.alphaKey := 't';

////////////////////////////////////////////////////////////////////////////////
//ControlsDef
  SystemDef.numitems := Ord(sys_end); // # of menu items
  SystemDef.prevMenu := @OptionsDef; // previous menu
  SystemDef.menuitems := Pmenuitem_tArray(@SystemMenu);  // menu items
  SystemDef.routine := @M_DrawSystem;  // draw routine
  SystemDef.x := 32;
  SystemDef.y := 68; // x,y of menu
  SystemDef.lastOn := 0; // last item user was on in menu
  SystemDef.itemheight := LINEHEIGHT2;

////////////////////////////////////////////////////////////////////////////////
//LoadMenu
  pmi := @LoadMenu[0];
  for i := 0 to Ord(load_end) - 1 do
  begin
    pmi.status := 1;
    pmi.name := '';
    pmi.cmd := '';
    pmi.routine := @M_LoadSelect;
    pmi.pBoolVal := nil;
    pmi.alphaKey := Chr(Ord('1') + i);
    inc(pmi);
  end;

////////////////////////////////////////////////////////////////////////////////
//LoadDef
  LoadDef.numitems := Ord(load_end); // # of menu items
  LoadDef.prevMenu := @MainDef; // previous menu
  LoadDef.menuitems := Pmenuitem_tArray(@LoadMenu);  // menu items
  LoadDef.routine := @M_DrawLoad;  // draw routine
  LoadDef.x := 96;
  LoadDef.y := 38; // x,y of menu
  LoadDef.lastOn := 0; // last item user was on in menu
  LoadDef.itemheight := LINEHEIGHT;

////////////////////////////////////////////////////////////////////////////////
//SaveMenu
  pmi := @SaveMenu[0];
  for i := 0 to Ord(load_end) - 1 do
  begin
    pmi.status := 1;
    pmi.name := '';
    pmi.cmd := '';
    pmi.routine := @M_SaveSelect;
    pmi.alphaKey := Chr(Ord('1') + i);
    pmi.pBoolVal := nil;
    inc(pmi);
  end;

////////////////////////////////////////////////////////////////////////////////
//SaveDef
  SaveDef.numitems := Ord(load_end); // # of menu items
  SaveDef.prevMenu := @MainDef; // previous menu
  SaveDef.menuitems := Pmenuitem_tArray(@SaveMenu);  // menu items
  SaveDef.routine := M_DrawSave;  // draw routine
  SaveDef.x := 96;
  SaveDef.y := 38; // x,y of menu
  SaveDef.lastOn := 0; // last item user was on in menu
  SaveDef.itemheight := LINEHEIGHT;

////////////////////////////////////////////////////////////////////////////////
  joywait := 0;
  mousewait := 0;
  mmousex := 0;
  mmousey := 0;
  mlastx := 0;
  mlasty := 0;

end;

end.

