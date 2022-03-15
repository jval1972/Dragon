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

unit d_main;

interface

uses
  d_event,
  doomdef;

const
  AppTitle = 'Dragon';

//==============================================================================
//
// D_ProcessEvents
//
//==============================================================================
procedure D_ProcessEvents;

//==============================================================================
//
// D_DoAdvanceDemo
//
//==============================================================================
procedure D_DoAdvanceDemo;

//==============================================================================
//
// D_AddFile
//
//==============================================================================
procedure D_AddFile(const fname: string);

//==============================================================================
//
// DragonMain()
// Not a globally visible function, just included for source reference,
// calls all startup code, parses command line options.
// If not overrided by user input, calls N_AdvanceDemo.
//
//==============================================================================
procedure DragonMain;

//==============================================================================
// D_PostEvent
//
// Called by IO functions when input is detected.
//
//==============================================================================
procedure D_PostEvent(ev: Pevent_t);

//==============================================================================
// D_PageTicker
//
// BASE LEVEL
//
//==============================================================================
procedure D_PageTicker;

//==============================================================================
//
// D_PageDrawer
//
//==============================================================================
procedure D_PageDrawer;

//==============================================================================
//
// D_AdvanceDemo
//
//==============================================================================
procedure D_AdvanceDemo;

//==============================================================================
//
// D_StartTitle
//
//==============================================================================
procedure D_StartTitle;

//==============================================================================
//
// D_IsPaused
//
//==============================================================================
function D_IsPaused: boolean;

//==============================================================================
//
// D_Display
//
//==============================================================================
procedure D_Display;

// wipegamestate can be set to -1 to force a wipe on the next draw
var
  wipegamestate: integer = -1;   // JVAL was gamestate_t = GS_DEMOSCREEN;
  wipedisplay: boolean = false;

  nomonsters: boolean;          // checkparm of -nomonsters
  fastparm: boolean;            // checkparm of -fast
  devparm: boolean;             // started game with -devparm
  hackshareware: boolean;       // started game with -hackshareware (undocumented)
  debugmode: boolean = false;   // JVAL: Debug mode, extended checks, setable only with -debugmode
  singletics: boolean;          // debug flag to cancel adaptiveness
  autostart: boolean;
  startskill: skill_t;
  respawnparm: boolean;         // checkparm of -respawn

  startepisode: integer;
  startmap: integer;
  advancedemo: boolean;

  basedefault: string;          // default file

//==============================================================================
//
// D_Version
//
//==============================================================================
function D_Version: string;

//==============================================================================
//
// D_VersionBuilt
//
//==============================================================================
function D_VersionBuilt: string;

//==============================================================================
//
// D_ShutDown
//
//==============================================================================
procedure D_ShutDown;

var
  autoloadgwafiles: boolean = true;

implementation

uses
  d_delphi,
  deh_main,
  doomstat,
  dstrings,
  d_englsh,
  d_player,
  d_net,
  c_con,
  c_cmds,
  f_finale,
  m_argv,
  m_misc,
  m_menu,
  info,
  info_rnd,
  i_system,
  i_io,
  i_tmp,
  i_startup,
  gl_main,
  g_game,
  hu_stuff,
  wi_stuff,
  st_stuff,
  p_setup,
  r_draw,
  r_main,
  r_hires,
  r_intrpl,
  r_data,
  r_lights,
  sounds,
  s_sound,
  sc_decorate,
  t_main,
  v_data,
  v_video,
  w_wad,
  w_pak,
  z_zone;

const
  BGCOLOR = 7;
  FGCOLOR = 8;

//==============================================================================
//
// D_GameLoop()
// Not a globally visible function,
//  just included for source reference,
//  called by DragonMain, never exits.
// Manages timing and IO,
//  calls all ?_Responder, ?_Ticker, and ?_Drawer,
//  calls I_GetTime, I_StartFrame, and I_StartTic
//
// D_PostEvent
// Called by the I/O functions when input is detected
//
//==============================================================================
procedure D_PostEvent(ev: Pevent_t);
begin
  events[eventhead] := ev^;
  inc(eventhead);
  eventhead := eventhead and (MAXEVENTS - 1);
end;

//
// D_ProcessEvents
// Send all the events of the given timestamp down the responder chain
//
var
  map01_lump: integer = -2;

//==============================================================================
//
// D_ProcessEvents
//
//==============================================================================
procedure D_ProcessEvents;
var
  ev: Pevent_t;
begin
// IF STORE DEMO, DO NOT ACCEPT INPUT
  if gamemode = commercial then
  begin
  // JVAL: Optimize checking for MAP01 lump
    if map01_lump = -2 then
      map01_lump := W_CheckNumForName('MAP01');
    if map01_lump = -1 then
      exit;
  end;

  if I_GameFinished then
    exit;

  while eventtail <> eventhead do
  begin
    ev := @events[eventtail];
    if C_Responder(ev) then
      // console ate the event
    else if M_Responder(ev) then
      // menu ate the event
    else
      G_Responder(ev);
    if I_GameFinished then
    begin
      eventtail := eventhead;
      exit;
    end;
    inc(eventtail);
    eventtail := eventtail and (MAXEVENTS - 1);
  end;
end;

//
// D_Display
//  draw current display, possibly wiping it from the previous
//

var
  viewactivestate: boolean = false;
  menuactivestate: boolean = false;
  viewfullscreen: boolean = false;
  inhelpscreensstate: boolean = false;
  borderdrawcount: integer;
  nodrawers: boolean = false; // for comparative timing purposes
  noblit: boolean = false;    // for comparative timing purposes
  norender: boolean = false;  // for comparative timing purposes
  shotnumber: integer = 0;
  lastshotnumber: integer = -1;

//==============================================================================
//
// D_FinishUpdate
//
//==============================================================================
procedure D_FinishUpdate;
begin
  if not noblit then
    I_FinishUpdate; // page flip or blit buffer
end;

//==============================================================================
//
// D_RenderPlayerView
//
//==============================================================================
procedure D_RenderPlayerView(player: Pplayer_t);
begin
  if norender then
  begin
    R_PlayerViewBlanc(aprox_black);
    exit;
  end;

  if player <> nil then
    R_RenderPlayerView(player)
end;

var
  diskbusyend: integer = -1;

//==============================================================================
//
// D_Display
//
//==============================================================================
procedure D_Display;

//==============================================================================
//
// D_DisplayHU
//
//==============================================================================
procedure D_DisplayHU;
var
  redrawsbar: boolean;
  palette: PByteArray;
  nowtime: integer;
begin
  if nodrawers then
    exit; // for comparative timing / profiling

  redrawsbar := false;

  // change the view size if needed
  if setsizeneeded then
  begin
    R_ExecuteSetViewSize;
    oldgamestate := -1; // force background redraw
    borderdrawcount := 3;
  end;

  if (gamestate = GS_LEVEL) and (gametic <> 0) then
    HU_Erase;

  // do buffered drawing
  case gamestate of
    GS_LEVEL:
      begin
        if gametic <> 0 then
        begin
          if ((viewheight <> SCREENHEIGHT) and viewfullscreen) then
            redrawsbar := true;
          if inhelpscreensstate and (not inhelpscreens) then
            redrawsbar := true; // just put away the help screen
          viewfullscreen := viewheight = SCREENHEIGHT;
          if viewfullscreen then
            ST_Drawer(stdo_no, redrawsbar)
          else
            ST_Drawer(stdo_full, redrawsbar);
        end;
      end;
    GS_INTERMISSION:
      WI_Drawer;
    GS_FINALE:
      F_Drawer;
    GS_DEMOSCREEN:
      D_PageDrawer;
  end;

  // draw the view directly
  if gamestate = GS_LEVEL then
  begin
  end
  else if Ord(gamestate) <> oldgamestate then
  begin
  // clean up border stuff
    palette := V_ReadPalette(PU_STATIC);
    I_SetPalette(palette);
    V_SetPalette(palette);
    Z_ChangeTag(palette, PU_CACHE);
  end;

  menuactivestate := menuactive;
  viewactivestate := viewactive;
  inhelpscreensstate := inhelpscreens;
  oldgamestate := Ord(gamestate);
  wipegamestate := Ord(gamestate);

  nowtime := I_GetTime;

  if isdiskbusy then
  begin
    diskbusyend := nowtime + 4; // Display busy disk for a little...
    isdiskbusy := false;
  end;

  if diskbusyend > nowtime then
  begin
    // Menus go directly to the screen
    M_Drawer; // Menu is drawn even on top of everything

    // Draw disk busy patch
    R_DrawDiskBusy; // Draw disk busy is draw on top of console
  end
  else if (diskbusyend <= nowtime) and (diskbusyend <> -1) then
  begin
    M_Drawer;
    diskbusyend := -1;
  end
  else
  begin
    M_Drawer;
  end;

  NetUpdate; // send out any new accumulation

  // normal update
end;

begin
  HU_DoFPSStuff;
  if firstinterpolation then
    ZeroMemory(screen32, V_GetScreenWidth(SCN_FG) * V_GetScreenHeight(SCN_FG) * 4);
  if gamestate = GS_LEVEL then
  begin
    if gametic <> 0 then
    begin
      D_RenderPlayerView(@players[displayplayer]);
    end;
  end;
  if firstinterpolation then
  begin
    D_DisplayHU;
  end;
  D_FinishUpdate; // page flip or blit buffer
end;

//==============================================================================
//
//  D_GameLoop
//
//==============================================================================
procedure D_GameLoop;
var
  iscritical: boolean;
begin
  if demorecording then
    G_BeginRecording;

  while true do
  begin
    // frame syncronous IO operations
    I_StartFrame;

    iscritical := not usemultithread and not devparm and criticalcpupriority;
    if iscritical then
      I_SetCriticalCPUPriority;

    // process one or more tics
    if singletics then
      D_RunSingleTick // will run only one tick
    else
      D_RunMultipleTicks; // will run at least one tick

    if iscritical then
      I_SetNormalCPUPriority;

    S_UpdateSounds(players[consoleplayer].mo);// move positional sounds
  end;
end;

//
//  DEMO LOOP
//
var
  demosequence: integer;
  pagetic: integer;
  pagename: string;

//==============================================================================
//
// D_PageTicker
// Handles timing for warped projection
//
//==============================================================================
procedure D_PageTicker;
begin
  dec(pagetic);
  if pagetic < 0 then
    D_AdvanceDemo;
end;

//==============================================================================
//
// D_PageDrawer
//
//==============================================================================
procedure D_PageDrawer;
begin
  V_PageDrawer(pagename);
end;

//==============================================================================
//
// D_AdvanceDemo
// Called after each demo or intro demosequence finishes
//
//==============================================================================
procedure D_AdvanceDemo;
begin
  advancedemo := true;
end;

//==============================================================================
// D_DoAdvanceDemo
//
// This cycles through the demo sequences.
// FIXME - version dependend demo numbers?
//
//==============================================================================
procedure D_DoAdvanceDemo;
begin
  players[consoleplayer].playerstate := PST_LIVE;  // not reborn
  advancedemo := false;
  usergame := false;               // no save / end game here
  paused := false;
  gameaction := ga_nothing;

  if gamemode = retail then
    demosequence := (demosequence + 1) mod 7
  else
    demosequence := (demosequence + 1) mod 6;

  case demosequence of
    0:
      begin
        if gamemode = commercial then
          pagetic := TICRATE * 11
        else
          pagetic := TICRATE * 30;
        gamestate := GS_DEMOSCREEN;
        pagename := pg_TITLE;
        if gamemode = commercial then
          S_StartMusic(Ord(mus_dm2ttl))
        else
          S_StartMusic(Ord(mus_intro));
      end;
    1:
      begin
        G_DeferedPlayDemo('1');
      end;
    2:
      begin
        pagetic := (TICRATE * 200) div 35;
        gamestate := GS_DEMOSCREEN;
        pagename := pg_CREDIT;
      end;
    3:
      begin
        G_DeferedPlayDemo('2');
      end;
    4:
      begin
        gamestate := GS_DEMOSCREEN;
        if gamemode = commercial then
        begin
          pagetic := TICRATE * 11;
          pagename := pg_TITLE;
          S_StartMusic(Ord(mus_dm2ttl));
        end
        else
        begin
          pagetic := (TICRATE * 200) div 35;
          if gamemode = retail then
            pagename := pg_CREDIT
          else
            pagename := pg_HELP2;
        end;
      end;
    5:
      begin
        G_DeferedPlayDemo('3');
      end;
        // THE DEFINITIVE DOOM Special Edition demo
    6:
      begin
        G_DeferedPlayDemo('4');
      end;
  end;
end;

//==============================================================================
//
// D_StartTitle
//
//==============================================================================
procedure D_StartTitle;
begin
  gameaction := ga_nothing;
  demosequence := -1;
  D_AdvanceDemo;
end;

var
  wadfiles: TDStringList;

//==============================================================================
//
// D_AddFile
//
//==============================================================================
procedure D_AddFile(const fname: string);
begin
  if fname <> '' then
    wadfiles.Add(fname);
end;

//
// IdentifyVersion
// Checks availability of IWAD files by name,
// to determine whether registered/commercial features
// should be executed (notably loading PWAD's).
//
var
  doomcwad: string = ''; // Custom main WAD

//==============================================================================
//
// IdentifyVersion
//
//==============================================================================
procedure IdentifyVersion;
begin
  D_AddFile('DRAGON1.DAT');
  gamemode := shareware; // Will check if retail or register mode later
end;

//==============================================================================
// FindResponseFile
//
// Find a Response File
//
// JVAL: Changed to handle more than 1 response files
//
//==============================================================================
procedure FindResponseFile;
var
  i: integer;
  handle: file;
  size: integer;
  index: integer;
  myargv1: string;
  infile: string;
  filename: string;
  s: TDStringList;
begin
  s := TDStringList.Create;
  try
    s.Add(myargv[0]);

    for i := 1 to myargc - 1 do
    begin
      if myargv[i][1] = '@' then
      begin
        // READ THE RESPONSE FILE INTO MEMORY
        myargv1 := Copy(myargv[i], 2, length(myargv[i]) - 1);
        if fopen(handle, myargv1, fOpenReadOnly) then
        begin
          printf('Found response file %s!'#13#10, [myargv1]);

          size := FileSize(handle);
          seek(handle, 0);
          SetLength(filename, size);
          BlockRead(handle, (@filename[1])^, size);
          close(handle);

          infile := '';
          for index := 1 to Length(filename) do
            if filename[index] = ' ' then
              infile := infile + #13#10
            else
              infile := infile + filename[i];

          s.Text := s.Text + infile;
        end
        else
          printf(#13#10'No such response file: %s!'#13#10, [myargv1]);
      end
      else
        s.Add(myargv[i])
    end;

    index := 0;
    for i := 0 to s.Count - 1 do
      if s[i] <> '' then
      begin
        myargv[index] := s[i];
        inc(index);
        if index = MAXARGS then
          break;
      end;
    myargc := index;
  finally
    s.Free;
  end;
end;

//==============================================================================
//
// D_Version
//
//==============================================================================
function D_Version: string;
begin
  sprintf(result, Apptitle + ' version %d.%d', [VERSION div 100, VERSION mod 100]);
end;

//==============================================================================
//
// D_VersionBuilt
//
//==============================================================================
function D_VersionBuilt: string;
begin
  sprintf(result, ' built %s', [I_VersionBuilt]);
end;

//==============================================================================
//
// D_CmdVersion
//
//==============================================================================
procedure D_CmdVersion;
begin
  printf('%s,%s'#13#10, [D_Version, D_VersionBuilt]);
end;

//==============================================================================
//
// D_CmdAddPakFile
//
//==============================================================================
procedure D_CmdAddPakFile(const parm: string);
var
  files: TDStringList;
  i: integer;
begin
  if parm = '' then
  begin
    printf('Please specify the pak file or directory to load'#13#10);
    exit;
  end;

  // JVAL
  // If a shareware game do not allow external files
 { if gamemode = shareware then
  begin
    I_Warning('You cannot use external files with the shareware version. Register!'#13#10);
    exit;
  end;       }

  if (Pos('*', parm) > 0) or (Pos('?', parm) > 0) then // It's a mask
    files := findfiles(parm)
  else
  begin
    files := TDStringList.Create;
    files.Add(parm)
  end;

  try

    for i := 0 to files.Count - 1 do
      if not PAK_AddFile(files[i]) then
        I_Warning('PAK_AddFile(): %s could not be added to PAK file system.'#13#10, [files[i]]);

  finally
    files.Free;
  end;

end;

//==============================================================================
//
// D_StartThinkers
//
//==============================================================================
procedure D_StartThinkers;
begin
  Info_Init(true);
  printf('Thinkers initialized'#13#10);
end;

//==============================================================================
//
// D_StopThinkers
//
//==============================================================================
procedure D_StopThinkers;
begin
  if demoplayback then
  begin
    I_Warning('Thinkers can not be disabled during demo playback.'#13#10);
    exit;
  end;

  if demorecording then
  begin
    I_Warning('Thinkers can not be disabled during demo recording.'#13#10);
    exit;
  end;

  Info_Init(false);
  printf('Thinkers disabled'#13#10);
end;

//==============================================================================
//
// D_AddWADFiles
//
//==============================================================================
procedure D_AddWADFiles(const parm: string);
var
  p: integer;
begin
  p := M_CheckParm(parm);
  if p <> 0 then
  begin
  // the parms after p are wadfile/lump names,
  // until end of parms or another - preceded parm
    modifiedgame := true; // homebrew levels
    inc(p);
    while (p < myargc) and (myargv[p][1] <> '-') do
    begin
      D_AddFile(myargv[p]);
      inc(p);
    end;
  end;
end;

//==============================================================================
//
// D_AddPAKFiles
//
//==============================================================================
procedure D_AddPAKFiles(const parm: string);
var
  p: integer;
begin
  p := M_CheckParm(parm);
  if p <> 0 then
  begin
  // the parms after p are wadfile/lump names,
  // until end of parms or another - preceded parm
    modifiedgame := true; // homebrew levels
    externalpakspresent := true;
    inc(p);
    while (p < myargc) and (myargv[p][1] <> '-') do
    begin
      PAK_AddFile(myargv[p]);
      inc(p);
    end;
  end;
end;

//==============================================================================
//
// D_AddDEHFiles
//
//==============================================================================
procedure D_AddDEHFiles(const parm: string);
var
  p: integer;
begin
  p := M_CheckParm(parm);
  if p <> 0 then
  begin
  // the parms after p are wadfile/lump names,
  // until end of parms or another - preceded parm
    modifiedgame := true; // homebrew levels
    externaldehspresent := true;
    inc(p);
    while (p < myargc) and (myargv[p][1] <> '-') do
    begin
      DEH_ParseFile(myargv[p]);
      inc(p);
    end;
  end;
end;

//==============================================================================
//
// D_IdentifyGameDirectories
//
//==============================================================================
procedure D_IdentifyGameDirectories;
var
  gamedirectorystring: string;
  i: integer;
  wad: string;
begin
  gamedirectorystring := 'DRAGON1,DRAGON';
  for i := wadfiles.Count - 1 downto 0 do
  begin
    wad := strupper(fname(wadfiles[i]));
    if Pos('.', wad) > 0 then
      wad := Copy(wad, 1, Pos('.', wad) - 1);
    if Pos(wad + ',', gamedirectorystring + ',') = 0 then
      gamedirectorystring := wad + ',' + gamedirectorystring;
  end;

  gamedirectories := PAK_GetDirectoryListFromString(gamedirectorystring);
  for i := 0 to gamedirectories.Count - 1 do
  begin
    wad := gamedirectories[i];
    if wad <> '' then
      if wad[length(wad)] = '\' then
        printf(' %s'#13#10, [gamedirectories[i]]);
  end;
end;

//==============================================================================
//
// DragonMain
//
//==============================================================================
procedure DragonMain;
var
  p: integer;
  filename: string;
  scale: integer;
  _time: integer;
  i: integer;
  mb_min: integer; // minimum zone size
begin
  I_SetDPIAwareness;

  SUC_Open;
  outproc := @SUC_Outproc;
  wadfiles := TDSTringList.Create;

  printf('Starting %s'#13#10, [D_Version]);
  C_AddCmd('ver, version', @D_CmdVersion);
  C_AddCmd('addpakfile, loadpakfile, addpak, loadpak', @D_CmdAddPakFile);
  C_AddCmd('startthinkers', @D_StartThinkers);
  C_AddCmd('stopthinkers', @D_StopThinkers);

  SUC_Progress(1);

  SUC_SetGameMode('1st PGD Challenge: Simple Controller');

  printf('M_InitArgv: Initializing command line parameters.'#13#10);
  M_InitArgv;

  SUC_Progress(2);

  FindResponseFile;

  printf('I_InitializeIO: Initializing input/output streams.'#13#10);
  I_InitializeIO;

  printf('I_InitTempFiles: Initializing temporary file managment.'#13#10);
  I_InitTempFiles;

  SUC_Progress(3);

//  D_AddSystemWAD; // Add system wad first

  SUC_Progress(5);

  IdentifyVersion;

  modifiedgame := false;

  nomonsters := M_CheckParm('-nomonsters') > 0;
  respawnparm := M_CheckParm('-respawn') > 0;
  fastparm := M_CheckParm('-fast') > 0;
  devparm := M_CheckParm('-devparm') > 0;
  hackshareware := M_CheckParm('-hackshareware') > 0;
  debugmode := M_CheckParm('-debugmode') > 0;

  SUC_Progress(6);

  if M_CheckParm('-altdeath') > 0 then
    deathmatch := 2
  else if M_CheckParm('-deathmatch') > 0 then
    deathmatch := 1;

  printf(
           '                         ' +
           'Dragon One Level Demo Startup v%d.%d' +
           '                           '#13#10,
            [VERSION div 100, VERSION mod 100]);

  if devparm then
    printf(D_DEVSTR);

  if M_CheckParmCDROM then
  begin
    printf(D_CDROM);
    basedefault := CD_WORKDIR + 'Doom32.ini';
  end;

  // turbo option
  p := M_CheckParm('-turbo');
  if p <> 0 then
  begin
    if p < myargc - 1 then
    begin
      scale := atoi(myargv[p + 1], 200);
      if scale < 10 then
        scale := 10
      else if scale > 400 then
        scale := 400;
    end
    else
      scale := 200;
    printf(' turbo scale: %d'#13#10, [scale]);
    forwardmove[0] := forwardmove[0] * scale div 100;
    forwardmove[1] := forwardmove[1] * scale div 100;
    sidemove[0] := sidemove[0] * scale div 100;
    sidemove[1] := sidemove[1] * scale div 100;
  end;

  SUC_Progress(7);

  // add any files specified on the command line with -file wadfile
  // to the wad list
  //
  // convenience hack to allow -wart e m to add a wad file
  // prepend a tilde to the filename so wadfile will be reloadable
  p := M_CheckParm('-wart');
  if (p <> 0) and (p < myargc - 1) then
  begin
    myargv[p][5] := 'p';     // big hack, change to -warp

  // Map name handling.
    case gamemode of
      shareware,
      retail,
      registered:
        begin
          if p < myargc - 2 then
          begin
            sprintf(filename, '~' + DEVMAPS + 'E%sM%s.wad',
              [myargv[p + 1][1], myargv[p + 2][1]]);
            printf('Warping to Episode %s, Map %s.'#13#10,
              [myargv[p + 1], myargv[p + 2]]);
          end;
        end;
    else
      begin
        p := atoi(myargv[p + 1]);
        if p < 10 then
          sprintf(filename, '~' + DEVMAPS + 'cdata/map0%d.wad', [p])
        else
          sprintf (filename,'~' + DEVMAPS + 'cdata/map%d.wad', [p]);
      end;
    end;

    D_AddFile(filename);
  end;

  SUC_Progress(8);

  D_AddWADFiles('-file');
  for p := 1 to 9 do
    D_AddWADFiles('-file' + itoa(p));
  D_AddWADFiles('-lfile');  // JVAL launcher specific

  SUC_Progress(9);

  printf('PAK_InitFileSystem: Init PAK/ZIP/PK3/PK4 files.'#13#10);
  PAK_InitFileSystem;
  PAK_AddFile('DRAGON2.DAT');

  SUC_Progress(10);

  D_AddPAKFiles('-pakfile');
  for p := 1 to 9 do
    D_AddPAKFiles('-pakfile' + itoa(p));

  SUC_Progress(15);

  D_AddPAKFiles('-lpakfile'); // JVAL launcher specific

  SUC_Progress(16);

  p := M_CheckParm('-playdemo');

  if p = 0 then
    p := M_CheckParm('-timedemo');

  if (p <> 0) and (p < myargc - 1) then
  begin
    inc(p);
    if Pos('.', myargv[p]) > 0 then
      filename := myargv[p]
    else
      sprintf(filename,'%s.lmp', [myargv[p]]);
    D_AddFile(filename);
    printf('Playing demo %s.'#13#10, [filename]);
  end;

  // get skill / episode / map from parms
  startskill := sk_easy;
  startepisode := 1;
  startmap := 1;
  autostart := false;

  p := M_CheckParm('-skill');
  if (p <> 0) and (p < myargc - 1) then
  begin
    startskill := skill_t(Ord(myargv[p + 1][1]) - Ord('1'));
    autostart := true;
  end;

  p := M_CheckParm('-episode');
  if (p <> 0) and (p < myargc - 1) then
  begin
    startepisode := atoi(myargv[p + 1]);
    startmap := 1;
    autostart := true;
  end;

  p := M_CheckParm('-timer');
  if (p <> 0) and (p < myargc - 1) and (deathmatch <> 0) then
  begin
    _time := atoi(myargv[p + 1]);
    printf('Levels will end after %d minute' + decide(_time > 1, 's', '') + #13#10, [_time]);
  end;

  p := M_CheckParm('-avg');
  if (p <> 0) and (p <= myargc - 1) and (deathmatch <> 0) then
    printf('Austin Virtual Gaming: Levels will end after 20 minutes'#13#10);

  printf('M_LoadDefaults: Load system defaults.'#13#10);
  M_LoadDefaults;              // load before initing other systems

  SUC_Progress(20);

  p := M_CheckParm('-fullscreen');
  if (p <> 0) and (p <= myargc - 1) then
    fullscreen := true;

  p := M_CheckParm('-nofullscreen');
  if p = 0 then
    p := M_CheckParm('-windowed');
  if (p <> 0) and (p <= myargc - 1) then
    fullscreen := false;

  p := M_CheckParm('-zaxisshift');
  if (p <> 0) and (p <= myargc - 1) then
    zaxisshift := true;

  p := M_CheckParm('-nozaxisshift');
  if (p <> 0) and (p <= myargc - 1) then
    zaxisshift := false;

  if M_Checkparm('-ultrares') <> 0 then
    detailLevel := DL_ULTRARES;

  if M_Checkparm('-hires') <> 0 then
    detailLevel := DL_HIRES;

  if M_Checkparm('-normalres') <> 0 then
    detailLevel := DL_NORMAL;

  if M_Checkparm('-mediumres') <> 0 then
    detailLevel := DL_MEDIUM;

  if M_Checkparm('-lowres') <> 0 then
    detailLevel := DL_LOW;

  if M_Checkparm('-lowestres') <> 0 then
    detailLevel := DL_LOWEST;

  if M_Checkparm('-interpolate') <> 0 then
    interpolate := true;

  if M_Checkparm('-nointerpolate') <> 0 then
    interpolate := false;

  p := M_CheckParm('-compatibilitymode');
  if (p <> 0) and (p <= myargc - 1) then
    compatibilitymode := true;

  p := M_CheckParm('-nocompatibilitymode');
  if (p <> 0) and (p <= myargc - 1) then
    compatibilitymode := false;

  oldcompatibilitymode := compatibilitymode;

  p := M_CheckParm('-screenwidth');
  if (p <> 0) and (p < myargc - 1) then
    SCREENWIDTH := atoi(myargv[p + 1])
  else
    SCREENWIDTH := I_ScreenWidth;
  if SCREENWIDTH > MAXWIDTH then
    SCREENWIDTH := MAXWIDTH;

  p := M_CheckParm('-screenheight');
  if (p <> 0) and (p < myargc - 1) then
    SCREENHEIGHT := atoi(myargv[p + 1])
  else
    SCREENHEIGHT := I_ScreenHeight;
  if SCREENHEIGHT > MAXHEIGHT then
    SCREENHEIGHT := MAXHEIGHT;

  singletics := M_CheckParm('-singletics') > 0;

  SUC_Progress(25);

  nodrawers := M_CheckParm('-nodraw') <> 0;
  noblit := M_CheckParm('-noblit') <> 0;
  norender := M_CheckParm('-norender') <> 0;

  if M_CheckParm('-usetransparentsprites') <> 0 then
    usetransparentsprites := true;
  if M_CheckParm('-dontusetransparentsprites') <> 0 then
    usetransparentsprites := false;
  if M_CheckParm('-uselightboost') <> 0 then
    uselightboost := true;
  if M_CheckParm('-dontuselightboost') <> 0 then
    uselightboost := false;
  p := M_CheckParm('-lightboostfactor');
  if (p <> 0) and (p < myargc - 1) then
  begin
    p := atoi(myargv[p + 1], -1);
    if (p >= LFACTORMIN) and (p <= LFACTORMAX) then
      lightboostfactor := p
    else
      I_Warning('Invalid lightboostfactor specified from command line %d. Specify a value in range (%d..%d)'#13#10, [p, LFACTORMIN, LFACTORMAX]);
  end;

// Try to guess minimum zone memory to allocate
  mb_min := 6 + V_ScreensSize(SCN_FG) div (1024 * 1024);
  if zonesize < mb_min then
    zonesize := mb_min;

  mb_used := zonesize;

  p := M_CheckParm('-zone');
  if (p <> 0) and (p < myargc - 1) then
  begin
    mb_used := atoi(myargv[p + 1]);
    if mb_used < mb_min then
    begin
      printf('Zone memory allocation needs at least %d MB (%d).'#13#10, [mb_min, mb_used]);
      mb_used := mb_min;
    end;
    zonesize := mb_used;
  end;

  // init subsystems
  printf('Z_Init: Init zone memory allocation daemon, allocation %d MB.'#13#10, [mb_used]);
  Z_Init;

  SUC_Progress(30);

  p := M_CheckParm('-nothinkers');
  if p = 0 then
  begin
    printf('I_InitInfo: Initialize information tables.'#13#10);
    Info_Init(true);
  end
  else
  begin
    I_Warning('Thinkers not initialized.'#13#10);
    Info_Init(false);
  end;

  SUC_Progress(31);

  printf('W_Init: Init WADfiles.'#13#10);
  if (W_InitMultipleFiles(wadfiles) = 0) or (W_CheckNumForName('playpal') = -1) then
    I_Error('W_InitMultipleFiles(): no files found');

  SUC_Progress(40);

  printf('DEH_Init: Initializing dehacked subsystem.'#13#10);
  DEH_Init;

  if not DEH_ParseLumpName('GAMEDEF') then
    I_Error('DEH_ParseLumpName(): GAMEDEF lump not found, undefined game!');

  SUC_Progress(41);

  printf('SC_Init: Initializing script engine.'#13#10);
  SC_Init;
  printf('SC_ParseDecorateLumps: Parsing ACTORDEF lumps.'#13#10);
  SC_ParseDecorateLumps;

  SUC_Progress(45);

  if M_CheckParm('-nowaddehacked') = 0 then
    if not DEH_ParseLumpName('DEHACKED') then
      printf('DEH_ParseLumpName: DEHACKED lump not found.'#13#10);

  // JVAL Adding dehached files
  D_AddDEHFiles('-deh');
  D_AddDEHFiles('-bex');

  SUC_Progress(50);

  for i := 0 to NUM_STARTUPMESSAGES - 1 do
    if startmsg[i] <> '' then
      printf('%s'#13#10, [startmsg[i]]);

  SUC_Progress(51);

  printf('T_Init: Initializing texture manager.'#13#10);
  T_Init;

  SUC_Progress(55);

  printf('V_Init: allocate screens.'#13#10);
  V_Init;

  SUC_Progress(57);

  p := M_CheckParm('-autoexec');
  if (p <> 0) and (p < myargc - 1) then
    autoexecfile := myargv[p + 1]
  else
    autoexecfile := DEFAUTOEXEC;

  printf('M_InitMenus: Initializing menus.'#13#10);
  M_InitMenus;

  SUC_Progress(59);

  printf('D_IdentifyGameDirectories: Identify game directories.'#13#10, [mb_used]);
  D_IdentifyGameDirectories;

  SUC_Progress(60);

  p := M_CheckParm('-warp');
  if (p <> 0) and (p < myargc - 1) then
  begin
    if gamemode = commercial then
    begin
      startmap := atoi(myargv[p + 1]);
      autostart := true;
    end
    else
    begin
      if p < myargc - 2 then
      begin
        startepisode := atoi(myargv[p + 1]);
        startmap := atoi(myargv[p + 2]);
        autostart := true;
      end;
    end;
  end;

  SUC_Progress(66);

  printf('Info_InitRandom: Initializing randomizers.'#13#10);
  Info_InitRandom;

  SUC_Progress(67);

  printf('M_Init: Init miscellaneous info.'#13#10);
  M_Init;

  SUC_Progress(68);

  p := M_CheckParm('-mmx');
  if p > 0 then
    usemmx := true;

  p := M_CheckParm('-nommx');
  if p > 0 then
    usemmx := false;

  if usemmx then
  begin
    printf('I_DetectCPU: Detecting CPU extensions.'#13#10);
    I_DetectCPU;
  end;

  SUC_Progress(69);

  printf('R_Init: Init screen refresh subsystem.');
  R_Init;

  SUC_Progress(80);

  printf(#13#10 + 'P_Init: Init Playloop state.'#13#10);
  P_Init;

  SUC_Progress(81);

  printf('D_CheckNetGame: Checking network game status.'#13#10);
  D_CheckNetGame;

  SUC_Progress(87);

  printf('S_Init: Setting up sound.'#13#10);
  S_Init(snd_SfxVolume, snd_MusicVolume);

  SUC_Progress(90);

  printf('HU_Init: Setting up heads up display.'#13#10);
  HU_Init;

  SUC_Progress(91);

  printf('ST_Init: Init status bar.'#13#10);
  ST_Init;

  SUC_Progress(92);

  //    // check for a driver that wants intermission stats
  p := M_CheckParm('-statcopy');
  if (p > 0) and (p < myargc - 1) then
  begin
  // for statistics driver
    statcopy := pointer(atoi(myargv[p + 1]));
    printf('External statistics registered.'#13#10);
  end;

  // start the apropriate game based on parms
  p := M_CheckParm('-record');

  if (p <> 0) and (p < myargc - 1) then
  begin
    G_RecordDemo(myargv[p + 1]);
    autostart := true;
  end;

  GL_InitGraphics;

  SUC_Progress(95);

  printf('I_Init: Setting up machine state.'#13#10);
  I_Init;

  SUC_Progress(96);

  printf('C_Init: Initializing console.'#13#10);
  C_Init;

  SUC_Progress(100);

  SUC_Close;

  p := M_CheckParm('-playdemo');
  if (p <> 0) and (p < myargc - 1) then
  begin
  // JVAL
  /// if -nosingledemo param exists does not
  // quit after one demo
    singledemo := M_CheckParm('-nosingledemo') = 0;
    G_DeferedPlayDemo(myargv[p + 1]);
    D_GameLoop;  // never returns
  end;

  p := M_CheckParm('-timedemo');
  if (p <> 0) and (p < myargc - 1) then
  begin
    G_TimeDemo(myargv[p + 1]);
    D_GameLoop;  // never returns
  end;

  p := M_CheckParm('-loadgame');
  if (p <> 0) and (p < myargc - 1) then
  begin
    sprintf(filename, M_SaveFileName(SAVEGAMENAME) + '%s.dsg', [myargv[p + 1][1]]);
    G_LoadGame(filename);
  end;

  if gameaction <> ga_loadgame then
  begin
    if autostart or netgame then
    begin
      G_InitNew(startskill, startepisode, startmap);
    end
    else
      D_StartTitle; // start up intro loop
  end;

  D_GameLoop;  // never returns
end;

//==============================================================================
//
// D_IsPaused
//
//==============================================================================
function D_IsPaused: boolean;
begin
  result := paused;
end;

//==============================================================================
//
// D_ShutDown
//
//==============================================================================
procedure D_ShutDown;
var
  i: integer;
begin
  printf('C_ShutDown: Shut down console.'#13#10);
  C_ShutDown;
  printf('R_ShutDown: Shut down refresh daemon.');
  R_ShutDown;
  printf('Info_ShutDownRandom: Shut down randomizers.'#13#10);
  Info_ShutDownRandom;
  printf('T_ShutDown: Shut down texture manager.'#13#10);
  T_ShutDown;
  printf('SC_ShutDown: Shut down script engine.'#13#10);
  SC_ShutDown;
  printf('DEH_ShutDown: Shut down dehacked subsystem.'#13#10);
  DEH_ShutDown;
  printf('Info_ShutDown: Shut down game definition.'#13#10);
  Info_ShutDown;
  printf('PAK_ShutDown: Shut down PAK/ZIP/PK3/PK4 file system.'#13#10);
  PAK_ShutDown;
  printf('W_ShutDown: Shut down WAD file system.'#13#10);
  W_ShutDown;
  printf('Z_ShutDown: Shut down zone memory allocation daemon.'#13#10, [mb_used]);
  Z_ShutDown;
  printf('V_ShutDown: Shut down screens.'#13#10, [mb_used]);
  V_ShutDown;

  gamedirectories.Free;

  if wadfiles <> nil then
  begin
    for i := 0 to wadfiles.Count - 1 do
      if wadfiles.Objects[i] <> nil then
        wadfiles.Objects[i].Free;

    wadfiles.Free;
  end;

end;

end.
