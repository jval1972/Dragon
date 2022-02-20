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

unit w_pak;

interface

uses
  d_delphi,
  z_files;

const
  Pakid: integer = $4B434150;   // 'PACK' In Hex!
  WAD2id: integer = $32444157;  // 'WAD2' in Hex!
  WAD3id: integer = $33444157;  // 'WAD3' in Hex!

type
  FPakHead = packed record // A PAK Directory Entry
    Name: packed array[1..56] of char;
    Offs: integer;
    Fsize: integer;
  end;

  TFPakHeadArray = packed array[0..$FFFF] of FPakHead;
  PFPakHeadArray = ^TFPakHeadArray;

  FWadHead = packed record // A WAD2/WAD3 Directory Entry
    Offs: integer;
    disksize: integer;
    size: integer;  // uncompressed
    _type: char;
    compression: char;
    pad1, pad2: char;
    name: packed array[1..16] of char; // must be null terminated
  end;

  TFWadHeadArray = packed array[0..$FFFF] of FWadHead;
  PFWadHeadArray = ^TFWadHeadArray;

type
  TCompressorCache = class(TObject)
  private
    fZip: TZipFile;
    fID: integer;
    fPosition: integer;
    fSize: integer;
    data: pointer;
  public
    constructor Create(aZip: TZipFile; aID: integer); virtual;
    destructor Destroy; override;
    function Read(var Buf; Sz: Integer): integer;
    function Seek(pos: integer): boolean;
    property Position: integer read fPosition;
    property Size: integer read fSize;
  end;

  TPakEntry = record // A Directory Entry Memory Image
    Pak: string[255];
    Name: string[255];
    ShortName: string[32];
    Offset, Size: Integer;
    Hash: integer;
    ZIP: TZipFile;
  end;
  PPakEntry = ^TPakEntry;

  TPakEntries = array[0..$FFFF] of TPakEntry;
  PPakEntries = ^TPakEntries;

  TPakFile = record
    Entry: Integer;
    F: file;
    Z: TCompressorCache;
  end;
  PPakFile = ^TPakFile;

const
  PAKHASHSIZE = 8192;

type
  PPakHash = ^TPakHash;
  TPakHash = record
    index: integer;
    next: PPakHash;
  end;

  PPakHashArray = array[0..PAKHASHSIZE - 1] of PPakHash;
  PPakHashPArray = ^PPakHashArray;

  TPakManager = class
  private
    Entries: PPakEntries;
    NumEntries: Integer;
    MaxEntries: Integer;
    PAKS: TDStringList;
    HashTable: PPakHashPArray;
    procedure Grow;
    procedure AddEntry(var H: FPakHead; const Pakn: string); overload;
    procedure AddEntry(var HD: FWADhead; const Pakn: string); overload;
    procedure AddEntry(ZIPFILE: TZipFile; const ZIPFileName, EntryName: string; const index: integer); overload;
    function HashToHashTableIndex(const hash: integer): integer;
    procedure AddEntryToHashTable(const idx: integer);
    function POpenPreferedFileNameSearch(var F: TPakFile; const aName: string; prefdirs: TDStringList): boolean;
    function POpenPreferedFileNameHash(var F: TPakFile; const aName: string; prefdirs: TDStringList): boolean;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure GetEntries(var s: TDStringList);
    function GetMatchingEntries(Name: string): TDNumberList;
    function POpenFileName(var F: TPakFile; Name: string): boolean;
    function POpenEntry(var F: TPakFile; const idx: integer): boolean;
    function POpenShortFileName(var F: TPakFile; Name: string): boolean;
    function POpenPreferedFileName(var F: TPakFile; const aName: string; prefdirs: TDStringList): boolean;
    function PClosefile(var F: TPakFile): boolean;
    function PBlockRead(var F: TPakFile; var Buf; const Size: Integer): integer;
    function PSeek(var F: TPakFile; const Pos: Integer): boolean;
    function PFilePos(var F: TPakFile): Integer;
    function PFileSize(var F: TPakFile): Integer;
    procedure PAddDirectory(const path: string);
    function PAddFile(const FileName: string): boolean;
  end;

  pakmode_t = (
    pm_full,    // Full pathname match
    pm_short,   // Filename only match
    pm_prefered // Filename match but specified prefered directories
  );

//==============================================================================
//
// PAK_GetDirectoryListFromString
//
//==============================================================================
function PAK_GetDirectoryListFromString(const aprefdirs: string): TDStringList;

type
  TPakStream = class(TStream)
  private
    entry: TPakFile;
    manager: TPakManager;
    mode: pakmode_t;
    prefdirs: TDStringList;
  public
    constructor Create(const FileName: string; amode: pakmode_t; const aprefdirs: string = ''); overload;
    constructor Create(const FileName: string; amode: pakmode_t; const apreflist: TDStringList); overload;
    constructor Create(const idx: integer); overload;
    destructor Destroy; override;
    function Read(var Buffer; Count: integer): integer; override;
    function Write(const Buffer; Count: integer): integer; override;
    function Seek(Offset: integer; Origin: Word): integer; override;
    function Size: integer; override;
    function Position: integer; override;
  end;

//==============================================================================
//
// PAK_InitFileSystem
//
//==============================================================================
procedure PAK_InitFileSystem;

//==============================================================================
//
// PAK_ShutDown
//
//==============================================================================
procedure PAK_ShutDown;

//==============================================================================
//
// PAK_AddDirectory
//
//==============================================================================
procedure PAK_AddDirectory(const path: string);

//==============================================================================
//
// PAK_AddFile
//
//==============================================================================
function PAK_AddFile(const FileName: string): boolean;

//==============================================================================
//
// PAK_GetMatchingEntries
//
//==============================================================================
function PAK_GetMatchingEntries(const Name: string): TDNumberList;

type
  stringiteratorproc = procedure(const atext: string);

//==============================================================================
//
// PAK_StringIterator
//
//==============================================================================
function PAK_StringIterator(const filename: string; proc: stringiteratorproc): integer;

implementation

uses
  i_system;

{******** TCompressorCache ********}

//==============================================================================
//
// TCompressorCache.Create
//
//==============================================================================
constructor TCompressorCache.Create(aZip: TZipFile; aID: integer);
begin
  Inherited Create;
  fZip := aZip;
  fID := aID;
  fZip.GetZipFileData(fID, data, fSize);
  fPosition := 0;
end;

//==============================================================================
//
// TCompressorCache.Destroy
//
//==============================================================================
destructor TCompressorCache.Destroy;
begin
  memfree(data, fSize);
  Inherited Destroy;
end;

//==============================================================================
//
// TCompressorCache.Read
//
//==============================================================================
function TCompressorCache.Read(var Buf; Sz: Integer): integer;
begin
  if fPosition + Sz > Size then
    result := Size - fPosition
  else
    result := Sz;

  memcpy(@buf, pointer(integer(data) + fPosition), result);
  fPosition := fPosition + result;
end;

//==============================================================================
//
// TCompressorCache.Seek
//
//==============================================================================
function TCompressorCache.Seek(pos: integer): boolean;
begin
  if (pos < 0) or (pos > Size) then
    result := false
  else
  begin
    fPosition := pos;
    result := true;
  end;
end;

//==============================================================================
//
// MkHash
//
//==============================================================================
function MkHash(const s: string): integer;
var
  i: integer;
begin
  result := 0;
  for i := 1 to length(s) do
  begin
    result := ((result shl 7) or (result shr 25)) + Ord(s[i]);
  end;
end;

{********* TPackDir *********}

//==============================================================================
//
// TPakManager.Create
//
//==============================================================================
constructor TPakManager.Create;
begin
  PAKS := TDStringList.Create;

  Entries := nil;
  NumEntries := 0;
  MaxEntries := 0;

  HashTable := mallocz(SizeOf(PPakHashArray));
end;

//==============================================================================
//
// TPakManager.PAddDirectory
//
//==============================================================================
procedure TPakManager.PAddDirectory(const path: string);

  procedure DoLoad(const msk: string);
  var
    mask: string;
    sl: TDStringList;
    i: integer;
  begin
    mask := msk;
    if path <> '' then
      mask := path + '\' + mask;

    sl := findfiles(mask);
    for i := 0 to sl.Count - 1 do
      PAddFile(sl[i]);
    sl.Free;
  end;

begin
// JVAL
// Autoload file types in directory
// Does not load ZIP files, only PK3/PK4 files as well as PAK files and new WAD format.
  DoLoad('*.PAK');
  DoLoad('*.PK3');
  DoLoad('*.PK4');
  DoLoad('*.WAD');
end;

//==============================================================================
//
// TPakManager.Grow
//
//==============================================================================
procedure TPakManager.Grow;
var
  newentries: integer;
begin
  Inc(NumEntries);
  if NumEntries > MaxEntries then
  begin
    newentries := MaxEntries + 512;
    realloc(pointer(Entries), MaxEntries * Sizeof(TPakentry), newentries * SizeOf(TPakentry));
    MaxEntries := newentries;
  end;
end;

//==============================================================================
// TPakManager.AddEntry
//
// Add a ZIP file entry (ZIP/PK3/PK4)
//
//==============================================================================
procedure TPakManager.AddEntry(ZIPFILE: TZipFile; const ZIPFileName, EntryName: string; const index: integer);
var
  e: PPakEntry;
begin
  Grow;
  e := @Entries[NumEntries - 1];
  e.Pak := ZIPFileName;
  e.Name := strupper(EntryName);
  e.ShortName := fshortname(e.Name);
  e.Hash := MkHash(e.ShortName);
  e.Offset := index; // offset -> index to ZIP file
  e.Size := 0;
  e.ZIP := ZIPFILE;

  AddEntryToHashTable(NumEntries - 1);
end;

//==============================================================================
// TPakManager.AddEntry
//
// Add an entry from Quake PAK file
//
//==============================================================================
procedure TPakManager.AddEntry(var H: FPakHead; const Pakn: string); // Add A Pak Entry to Memory List
var
  S: string;
  I: Integer;
  e: PPakEntry;
begin
  Grow;

  S := '';
  for I := 1 to 56 do
    if H.Name[I] <> #0 then
      S := S + toupper(H.Name[I])
    else
      break;

  e := @Entries[NumEntries - 1];
  e.Pak := Pakn;
  e.Name := S;
  e.ShortName := fshortname(e.Name);
  e.Hash := MkHash(e.ShortName);
  e.Offset := H.Offs;
  e.Size := H.Fsize;
  e.ZIP := nil;

  AddEntryToHashTable(NumEntries - 1);
end;

//==============================================================================
// TPakManager.AddEntry
//
// Add an entry from a WAD file (new WAD version)
//
//==============================================================================
procedure TPakManager.AddEntry(var HD: FWADhead; const Pakn: string);
var
  S: string;
  I: Integer;
  e: PPakEntry;
begin
  Grow;

  S := '';
  for I := 1 to 16 do
    if HD.Name[I] <> #0 then
      S := S + UpCase(HD.Name[I])
    else
      break;

  e := @Entries[NumEntries - 1];
  e.Pak := Pakn;
  e.Name := S;
  e.ShortName := fshortname(e.Name);
  e.Hash := MkHash(e.ShortName);
  e.Offset := HD.Offs;
  e.Size := HD.size;
  e.ZIP := nil;

  AddEntryToHashTable(NumEntries - 1);
end;

//==============================================================================
//
// TPakManager.HashToHashTableIndex
//
//==============================================================================
function TPakManager.HashToHashTableIndex(const hash: integer): integer;
begin
  result := abs(hash) mod PAKHASHSIZE;
end;

//==============================================================================
//
// TPakManager.AddEntryToHashTable
//
//==============================================================================
procedure TPakManager.AddEntryToHashTable(const idx: integer);
var
  hashidx: integer;
  parent: PPakHash;
begin
  hashidx := HashToHashTableIndex(Entries[idx].Hash);

  parent := HashTable[hashidx];

  HashTable[hashidx] := malloc(SizeOf(TPakHash));
  HashTable[hashidx].index := idx;
  HashTable[hashidx].next := parent;
end;

//==============================================================================
//
// TPakManager.PAddFile
//
//==============================================================================
function TPakManager.PAddFile(const FileName: string): boolean; // Add A Pak file
var
  Nr: Integer;
  N, Id, Ofs:Integer;
  F: file;
  P: Pointer;
  I: Integer;
  z: TZipFile;
  pkid: integer;
  Fn: string;
begin
  result := false;
  Fn := strupper(FileName);
  if PAKS.IndexOf(Fn) > -1  then
    exit;

  pkid := PAKS.Add(Fn);
  PAKS.Objects[pkid] := nil;

  if not fopen(F, fn, fOpenReadOnly) then
    exit;

  Blockread(F, Id, 4, N);
  if N <> 4 then
  begin
    close(F);
    exit;
  end;
  if (Id <> Pakid) and (Id <> WAD2Id) and (Id <> WAD3Id) and (id <> ZIPFILESIGNATURE) then
  begin
    result := false;
    close(F);
    exit;
  end;

  if Id = Pakid then // PAK file
  begin
    BlockRead(F, Ofs, 4, N);
    if N <> 4 then
    begin
      close(F);
      exit;
    end;
    BlockRead(F, Nr, 4, N);
    if N <> 4 then
    begin
      close(F);
      exit;
    end;
    Nr := Nr div SizeOf(FPakHead);
    Seek(F, Ofs);
    P := malloc(Nr * SizeOf(FPakHead));
    Blockread(f, P^, Nr * SizeOf(FPakHead), N);
    for i := 0 to N div SizeOf(FPakHead) - 1 do
      AddEntry(PFPakHeadArray(P)[i], Fn);
    memfree(P, Nr * SizeOf(FPakHead));
  end
  else if id = ZIPFILESIGNATURE then // zip, pk3, pk4 file
  begin
    z := TZipFile.Create(Fn);
    PAKS.Objects[pkid] := z;
    for i := 0 to z.FileCount - 1 do
      AddEntry(z, Fn, z.Files[i], i);
  end
  else // WAD2 or WAD3
  begin
    BlockRead(F, Nr, 4, N);
    if N <> 4 then
    begin
      close(F);
      exit;
    end;
    BlockRead(F, Ofs, 4, N);
    if N <> 4 then
    begin
      close(F);
      exit;
    end;
    seek(F, Ofs);
    P := malloc(Nr * SizeOf(FWadHead));
    Blockread(f, P^, Nr * SizeOf(FWadHead), N);
    for i := 0 to N div SizeOf(FWadHead) - 1 do
      AddEntry(PFWadHeadArray(P)[i], Fn);
    memfree(P, Nr * SizeOf(FWadHead));

  end;
  close(F);
  result := true;
  printf(' adding %s'#13#10, [FileName]);
end;

//==============================================================================
//
// TPakManager.GetEntries
//
//==============================================================================
procedure TPakManager.GetEntries(var s: TDStringList);
var i: integer;
begin
  if s = nil then
    s := TDStringList.Create;
  for i := NumEntries - 1 downto 0 do
    s.Add(Entries[I].Name);
end;

//==============================================================================
//
// TPakManager.GetMatchingEntries
//
//==============================================================================
function TPakManager.GetMatchingEntries(Name: string): TDNumberList;
var
  i: integer;
  hcode: integer;
  pe: PPakEntry;
begin
  result := TDNumberList.Create;

  Name := strupper(fshortname(Name));
  hcode := MkHash(Name);

  for i := 0 to NumEntries - 1 do
  begin
    pe := @Entries[i];
    if hcode = pe.Hash then
      if pe.ShortName = Name then
      begin // Found In Pak
        result.Add(i)
      end;
  end;

end;

//==============================================================================
// TPakManager.POpenFileName
//
// Opens a file
//
//==============================================================================
function TPakManager.POpenFileName(var F: TPakFile; Name: string): boolean;
var
  I: Integer;
  hcode: integer;
  pe: PPakEntry;
  hashcheck: PPakHash;
begin
  result := false;
  F.Z := nil;

  if fopen(F.F, Name, fOpenReadOnly) then
  begin
    F.Entry := -1;
    result := true;
    Exit;
  end; // Disk file Overrides Pak file

  Name := strupper(Name);
  hcode := MkHash(fshortname(Name));

  hashcheck := HashTable[HashToHashTableIndex(hcode)];
  while hashcheck <> nil do
  begin
    pe := @Entries[hashcheck.index];
    if hcode = pe.Hash then   // Fast compare the hash values
      if pe.Name = Name then  // Slow compare strings
      begin // Found In Pak
        if pe.ZIP <> nil then // It's a zip (pk3/pk4) file
          F.Z := TCompressorCache.Create(pe.ZIP, pe.Offset)
        else
        begin // Standard Quake1/2 pak file
          if not fopen(F.F, string(pe.Pak), fOpenReadOnly)  then
            exit;
          Seek(F.F, pe.Offset);
        end;
        F.Entry := hashcheck.index;
        result := true;
        exit;
      end;
    hashcheck := hashcheck.next;
  end;

  // Highly unlikely that we get to this point....
  for i := NumEntries - 1 downto 0 do // From last entry to zero, last file has priority
  begin
    pe := @Entries[i];
    if hcode = pe.Hash then   // Fast compare the hash values
      if pe.Name = Name then  // Slow compare strings
      begin // Found In Pak
        if pe.ZIP <> nil then // It's a zip (pk3/pk4) file
          F.Z := TCompressorCache.Create(pe.ZIP, pe.Offset)
        else
        begin // Standard Quake1/2 pak file
          if not fopen(F.F, string(pe.Pak), fOpenReadOnly)  then
            exit;
          Seek(F.F, pe.Offset);
        end;
        F.Entry := i;
        result := true;
        exit;
      end;
  end;
end;

//==============================================================================
//
// TPakManager.POpenEntry
//
//==============================================================================
function TPakManager.POpenEntry(var F: TPakFile; const idx: integer): boolean;
var
  pe: PPakEntry;
begin
  result := false;

  if idx < 0 then
    exit;

  if idx >= NumEntries then
    exit;

  pe := @Entries[idx];
  if pe.ZIP <> nil then // It's a zip (pk3/pk4) file
    F.Z := TCompressorCache.Create(pe.ZIP, pe.Offset)
  else
  begin // Standard Quake1/2 pak file
    if not fopen(F.F, string(pe.Pak), fOpenReadOnly)  then
      exit;
    Seek(F.F, pe.Offset);
  end;
  F.Entry := idx;
  result := true;
end;

//==============================================================================
// TPakManager.POpenShortFileName
//
// Opens a file without extensive search, checks filenames only, not directory structure!!
//
//==============================================================================
function TPakManager.POpenShortFileName(var F: TPakFile; Name: string): boolean;
var
  I: Integer;
  hcode: integer;
  pe: PPakEntry;
  hashcheck: PPakHash;
begin
  result := false;
  F.Z := nil;

  if fopen(F.F, Name, fOpenReadOnly) then
  begin
    F.Entry := -1;
    result := true;
    Exit;
  end; // Disk file Overrides Pak file

  Name := strupper(fshortname(Name));
  hcode := MkHash(Name);

  hashcheck := HashTable[HashToHashTableIndex(hcode)];
  while hashcheck <> nil do
  begin
    pe := @Entries[hashcheck.index];
    if hcode = pe.Hash then   // Fast compare the hash values
      if pe.ShortName = Name then  // Slow compare strings
      begin // Found In Pak
        if pe.ZIP <> nil then // It's a zip (pk3/pk4) file
          F.Z := TCompressorCache.Create(pe.ZIP, pe.Offset)
        else
        begin // Standard Quake1/2 pak file
          if not fopen(F.F, string(pe.Pak), fOpenReadOnly)  then
            exit;
          Seek(F.F, pe.Offset);
        end;
        F.Entry := hashcheck.index;
        result := true;
        exit;
      end;
    hashcheck := hashcheck.next;
  end;

  // Highly unlikely that we get to this point....
  for I := NumEntries - 1 downto 0 do
  begin
    pe := @Entries[i];
    if hcode = pe.Hash then
      if pe.ShortName = Name then
      begin // Found In Pak
        if pe.ZIP <> nil then
          F.Z := TCompressorCache.Create(pe.ZIP, pe.Offset)
        else
        begin
          if not fopen(F.F, string(pe.Pak), fOpenReadOnly) then
            exit;
          Seek(F.F, pe.Offset);
        end;
        F.Entry := I;
        result := true;
        Exit;
      end;
  end;
end;

type
  Ppref_rec = ^pref_rec;
  pref_rec = record
    index: integer;
    priority: integer;
    next: Ppref_rec;
  end;

//==============================================================================
//
// recourcefreememlist
//
//==============================================================================
procedure recourcefreememlist(var list: Ppref_rec);
begin
  if list <> nil then
  begin
    recourcefreememlist(list.next);
    memfree(pointer(list), SizeOf(pref_rec));
  end;
end;

//==============================================================================
// TPakManager.POpenPreferedFileNameSearch
//
// Opens a file with extensive search prefering the pathname to be contained to prefdirs
// Serial search, does not use hash table
//
//==============================================================================
function TPakManager.POpenPreferedFileNameSearch(var F: TPakFile; const aName: string; prefdirs: TDStringList): boolean;
var
  I: Integer;
  hcode: integer;
  pe: PPakEntry;
  pref_head: Ppref_rec;
  pref_list: Ppref_rec;
  j: integer;
  bestpriority: integer;
  Name: string;
begin
  result := false;
  F.Z := nil;

  pref_head := malloc(SizeOf(pref_rec));
  pref_head.index := -1;
  pref_head.priority := MAXINT;
  pref_head.next := nil;
  pref_list := pref_head;

  Name := strupper(fshortname(aName));
  hcode := MkHash(Name);
  for I := NumEntries - 1 downto 0 do
  begin
    pe := @Entries[i];
    if hcode = pe.Hash then
      if pe.ShortName = Name then
      begin // Found In Pak
        pref_list.index := i;
        pref_list.priority := prefdirs.Count;
        for j := 0 to prefdirs.Count - 1 do
          if Pos(prefdirs[j], pe.Name) > 0 then
          begin
            pref_list.priority := j;
            break;
          end;
        pref_list.next := malloc(SizeOf(pref_rec));
        pref_list := pref_list.next;
        pref_list.index := -1;
        pref_list.next := nil;
      end;
  end;

  pref_list := pref_head;
  bestpriority := MAXINT;
  i := -1;
  while pref_list.index >= 0 do
  begin
    if pref_list.priority < bestpriority then
    begin
      i := pref_list.index;
      bestpriority := pref_list.priority;
    end;
    pref_list := pref_list.next;
  end;

  recourcefreememlist(pref_head);

  if i < 0 then
    exit;

  pe := @Entries[i];
  if pe.ZIP <> nil then
    F.Z := TCompressorCache.Create(pe.ZIP, pe.Offset)
  else
  begin
    if not fopen(F.F, string(pe.Pak), fOpenReadOnly) then
      exit;
    Seek(F.F, pe.Offset);
  end;
  F.Entry := I;
  result := true;
end;

//==============================================================================
// TPakManager.POpenPreferedFileNameHash
//
// Opens a file with extensive search prefering the pathname to be contained to prefdirs
// Fast search using hash table
//
//==============================================================================
function TPakManager.POpenPreferedFileNameHash(var F: TPakFile; const aName: string; prefdirs: TDStringList): boolean;
var
  I: Integer;
  hcode: integer;
  pe: PPakEntry;
  pref_head: Ppref_rec;
  pref_list: Ppref_rec;
  j: integer;
  bestpriority: integer;
  Name: string;
  hashcheck: PPakHash;
begin
  result := false;
  F.Z := nil;

  if fopen(F.F, aName, fOpenReadOnly) then
  begin
    F.Entry := -1;
    result := true;
    Exit;
  end; // Disk file Overrides Pak file

  pref_head := malloc(SizeOf(pref_rec));
  pref_head.index := -1;
  pref_head.priority := MAXINT;
  pref_head.next := nil;
  pref_list := pref_head;

  Name := strupper(fshortname(aName));
  hcode := MkHash(Name);

  hashcheck := HashTable[HashToHashTableIndex(hcode)];
  while hashcheck <> nil do
  begin
    pe := @Entries[hashcheck.index];
    if hcode = pe.Hash then
      if pe.ShortName = Name then
      begin // Found In Pak
        pref_list.index := hashcheck.index;
        pref_list.priority := prefdirs.Count;
        for j := 0 to prefdirs.Count - 1 do
          if Pos(prefdirs[j], pe.Name) > 0 then
          begin
            pref_list.priority := j;
            break;
          end;
        pref_list.next := malloc(SizeOf(pref_rec));
        pref_list := pref_list.next;
        pref_list.index := -1;
        pref_list.next := nil;
      end;
    hashcheck := hashcheck.next;
  end;

  pref_list := pref_head;
  bestpriority := MAXINT;
  i := -1;
  while pref_list.index >= 0 do
  begin
    if pref_list.priority < bestpriority then
    begin
      i := pref_list.index;
      bestpriority := pref_list.priority;
    end;
    pref_list := pref_list.next;
  end;

  recourcefreememlist(pref_head);

  if i < 0 then
    exit;

  pe := @Entries[i];
  if pe.ZIP <> nil then
    F.Z := TCompressorCache.Create(pe.ZIP, pe.Offset)
  else
  begin
    if not fopen(F.F, string(pe.Pak), fOpenReadOnly) then
      exit;
    Seek(F.F, pe.Offset);
  end;
  F.Entry := I;
  result := true;
end;

//==============================================================================
//
// TPakManager.POpenPreferedFileName
//
//==============================================================================
function TPakManager.POpenPreferedFileName(var F: TPakFile; const aName: string; prefdirs: TDStringList): boolean;
begin
  result := POpenPreferedFileNameHash(F, aName, prefdirs);
  if not result then
    result := POpenPreferedFileNameSearch(F, aName, prefdirs);
end;

//==============================================================================
//
// TPakManager.PClosefile
//
//==============================================================================
function TPakManager.PClosefile(var F: TPakFile): boolean;
begin
  if F.Z <> nil then
  begin
    F.Z.Free;
    F.Z := nil;
    result := true;
  end
  else
  begin
    {$I-}
    Close(F.F);
    {$I+}
    result := IOResult = 0;
  end;
end;

//==============================================================================
//
// TPakManager.PBlockRead
//
//==============================================================================
function TPakManager.PBlockRead(var F: TPakFile; var Buf; const Size: Integer): integer;
begin
  if F.Z <> nil then
    result := F.Z.Read(Buf, Size)
  else
  begin
    {$I-}
    Blockread(F.F, Buf, Size, result);
    {$I+}
  end;
end;

//==============================================================================
//
// TPakManager.PSeek
//
//==============================================================================
function TPakManager.PSeek(var F: TPakFile; const Pos: Integer): boolean;
begin
  if F.Z <> nil then
    result := F.Z.Seek(pos)
  else
  begin
  {$I-}
    if F.Entry = -1 then
      Seek(F.F, Pos)
    else
      Seek(F.F, Entries[F.Entry].Offset + Pos);
    {$I+}
    result := IOResult = 0;
  end;
end;

//==============================================================================
//
// TPakManager.PFilePos
//
//==============================================================================
function TPakManager.PFilePos(var F: TPakFile): Integer;
begin
  if F.Z <> nil then
    result := F.Z.Position
  else
  begin
    result := FilePos(F.F);
    if F.Entry <> -1 then
      result := result - Entries[F.Entry].Offset;
  end;
end;

//==============================================================================
//
// TPakManager.PFileSize
//
//==============================================================================
function TPakManager.PFileSize(var F: TPakFile): Integer;
begin
  if F.Z <> nil then
    result := F.Z.Size
  else if F.Entry <> -1 then
    result := Entries[F.Entry].Size
  else
  begin
  {$I-}
    result := Filesize(F.F);
  {$I+}
    if IOResult <> 0 then
      result := 0;
  end;
end;

//==============================================================================
//
// TPakManager.Destroy
//
//==============================================================================
destructor TPakManager.Destroy;
var
  i: integer;

  procedure recoursivefreehashitem(var h: PPakHash);
  begin
    if h.next <> nil then
      recoursivefreehashitem(h.next);
    memfree(pointer(h), SizeOf(TPakHash));
  end;

begin
  for i := 0 to PAKHASHSIZE - 1 do
    if HashTable[i] <> nil then
      recoursivefreehashitem(HashTable[i]);

  memfree(pointer(HashTable), SizeOf(PPakHashArray));

  realloc(pointer(Entries), MaxEntries * Sizeof(TPakentry), 0);

  for i := 0 to PAKS.Count - 1 do
    if PAKS.Objects[i] <> nil then
      PAKS.Objects[i].Free;

  PAKS.Free;
end;

// Global Pak Loader Object
var
  pakmanager: TPakManager;

//==============================================================================
//
// PAK_GetDirectoryListFromString
//
//==============================================================================
function PAK_GetDirectoryListFromString(const aprefdirs: string): TDStringList;
var
  i: integer;
  stmp: string;
  stmp2: string;
begin
  result := TDStringList.Create;
  if aprefdirs <> '' then
  begin
    stmp := '';
    for i := 1 to Length(aprefdirs) do
      if aprefdirs[i] in [' ', ','] then
        stmp := stmp + #13#10
      else
        stmp := stmp + toupper(aprefdirs[i]);
    result.Text := stmp;
    for i := result.count - 1 downto 0 do
      if result.strings[i] = '' then
        result.Delete(i);
    stmp := '';
    for i := 0 to result.Count - 1 do
    begin
      stmp2 := result[i];
      if Length(stmp2) > 0 then
        if stmp2[Length(stmp2)] <> '\' then
          stmp := stmp + stmp2 + '\'#13#10;
      stmp := stmp + stmp2 + #13#10;
    end;
    result.Text := stmp;
  end;

end;

//==============================================================================
// TPakStream.Create
//
// TPakStream
//
//==============================================================================
constructor TPakStream.Create(const FileName: string; amode: pakmode_t; const apreflist: TDStringList);
var
  ok: boolean;
  i: integer;
begin
  Inherited Create;

  OnBeginBusy := nil;
  OnEndBusy := nil;

  prefdirs := TDStringList.Create;
  for i := 0 to apreflist.Count - 1 do
    prefdirs.Add(apreflist[i]);

  manager := pakmanager;
  mode := amode;
  if mode = pm_full then
    ok := manager.POpenFileName(entry, FileName)
  else if mode = pm_short then
    ok := manager.POpenShortFileName(entry, FileName)
  else if mode = pm_prefered then
    ok := manager.POpenPreferedFileName(entry, FileName, prefdirs)
  else
    ok := false;
  if not ok then
    FIOResult := 1
  else
    FIOResult := 0;
end;

//==============================================================================
//
// TPakStream.Create
//
//==============================================================================
constructor TPakStream.Create(const FileName: string; amode: pakmode_t; const aprefdirs: string = '');
var
  apreflist: TDStringList;
begin
  apreflist := PAK_GetDirectoryListFromString(aprefdirs);
  Create(FileName, amode, apreflist);
  apreflist.Free;
end;

//==============================================================================
//
// TPakStream.Create
//
//==============================================================================
constructor TPakStream.Create(const idx: integer);
var
  ok: boolean;
begin
  Inherited Create;

  OnBeginBusy := nil;
  OnEndBusy := nil;

  prefdirs := TDStringList.Create;

  manager := pakmanager;
  mode := pm_short;
  ok := manager.POpenEntry(entry, idx);
  if not ok then
    FIOResult := 1
  else
    FIOResult := 0;
end;

//==============================================================================
//
// TPakStream.Destroy
//
//==============================================================================
destructor TPakStream.Destroy;
begin
  manager.PClosefile(entry);
  prefdirs.Free;
  Inherited;
end;

//==============================================================================
//
// TPakStream.Read
//
//==============================================================================
function TPakStream.Read(var Buffer; Count: integer): integer;
begin
  result := manager.PBlockRead(entry, Buffer, Count);
  if IOResult <> 0 then
    inc(FIOResult);
end;

//==============================================================================
//
// TPakStream.Write
//
//==============================================================================
function TPakStream.Write(const Buffer; Count: integer): integer;
begin
  I_Warning('TPakStream::Write(): Pak managment is read-only'#13#10);
  inc(FIOResult);
  result := 0;
end;

//==============================================================================
//
// TPakStream.Seek
//
//==============================================================================
function TPakStream.Seek(Offset: integer; Origin: Word): integer;
var
  p: integer;
begin
  if Origin = sFromBeginning then
    p := Offset
  else if Origin = sFromCurrent then
    p := manager.PFilePos(entry) + Offset
  else {sFromEnd}
    p := manager.PFileSize(entry) - Offset;

  if not manager.PSeek(entry, p) then
    inc(FIOResult);
  result := p;
end;

//==============================================================================
//
// TPakStream.Size
//
//==============================================================================
function TPakStream.Size: integer;
begin
  result := manager.PFileSize(entry)
end;

//==============================================================================
//
// TPakStream.Position
//
//==============================================================================
function TPakStream.Position: integer;
begin
  result := manager.PFilePos(entry);
end;

//==============================================================================
//
// PAK_InitFileSystem
//
//==============================================================================
procedure PAK_InitFileSystem;
begin
  pakmanager := TPakManager.Create;
end;

//==============================================================================
//
// PAK_ShutDown
//
//==============================================================================
procedure PAK_ShutDown;
begin
  pakmanager.Free;
end;

//==============================================================================
//
// PAK_AddDirectory
//
//==============================================================================
procedure PAK_AddDirectory(const path: string);
begin
  printf(' adding directory %s'#13#10, [path]);
  pakmanager.PAddDirectory(path);
end;

//==============================================================================
//
// PAK_AddFile
//
//==============================================================================
function PAK_AddFile(const FileName: string): boolean;
begin
  if I_DirectoryExists(FileName) then
  begin
    result := true;
    PAK_AddDirectory(FileName)
  end
  else
    result := pakmanager.PAddFile(FileName);
end;

//==============================================================================
//
// PAK_GetMatchingEntries
//
//==============================================================================
function PAK_GetMatchingEntries(const Name: string): TDNumberList;
begin
  result := pakmanager.GetMatchingEntries(Name);
end;

//==============================================================================
//
// PAK_StringIterator
//
//==============================================================================
function PAK_StringIterator(const filename: string; proc: stringiteratorproc): integer;
var
  entries: TDNumberList;
  strm: TPakStream;
  list: TDStringList;
  i: integer;
begin
  result := 0;
  entries := PAK_GetMatchingEntries(filename);
  list := TDStringList.Create;
  for i := 0 to entries.Count - 1 do
  begin
    strm := TPakStream.Create(entries.Numbers[i]);
    if strm.IOResult = 0 then
    begin
      list.LoadFromStream(strm);
      proc(list.Text);
      inc(result);
    end;
    strm.Free;
  end;
  list.Free;
  entries.Free;
end;

end.

