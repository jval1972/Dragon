//
//  Dragon
//  A game for Windows based on a modified and improved version of the
//  DelphiDoom engine
//
//  Copyright (C) 1993-1996 by id Software, Inc.
//  Copyright (C) 2004-2020 by Jim Valavanis
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
// DESCRIPTION:
//   Zone Memory Allocation, perhaps NeXT ObjectiveC inspired.
//   Remark: this was the only stuff that, according
//   to John Carmack, might have been useful for
//   Quake.
//
//------------------------------------------------------------------------------
//  Site  : https://sourceforge.net/projects/dragon-game/
//------------------------------------------------------------------------------

{$I dragon.inc}

unit z_zone;

interface

uses
  d_delphi;

//
// ZONE MEMORY
// PU - purge tags.
// Tags < 100 are not overwritten until freed.

const
  PU_LOTAG = 1;
  PU_STATIC = 1;    // static entire execution time
  PU_SOUND = 2;     // static while playing
  PU_MUSIC = 3;     // static while playing
  PU_DAVE = 4;      // anything else Dave wants static
  PU_LEVEL = 50;    // static until level exited
  PU_LEVSPEC = 51;  // a special thinker in a level
  // Tags >= 100 are purgable whenever needed.
  PU_PURGELEVEL = 100;
  PU_CACHE = 101;
  PU_HITAG = 101;

procedure Z_Init;
procedure Z_ShutDown;

function Z_Malloc(size: integer; tag: integer; user: pointer): pointer;
function Z_Malloc2(size: integer; tag: integer; user: pointer): pointer;
function Z_Realloc(ptr: pointer; size: integer; tag: integer; user: pointer): pointer;

procedure Z_Free(ptr: pointer);

function Z_FreeTags(lowtag: integer; hightag: integer): boolean;

procedure Z_DumpHeap(lowtag: integer; hightag: integer);

procedure Z_FileDumpHeapf(var f: file);

procedure Z_FileDumpHeap(const filename: string);

procedure Z_CheckMemory;

procedure Z_CheckHeap;

procedure Z_ChangeTag(ptr: pointer; tag: integer);

function Z_FreeMemory: integer;

function Z_CacheMemory: integer;

// including the header and possibly tiny fragments
// NULL if a free block
// purgelevel
// should be ZONEID

type
  Pmemblock_t = ^memblock_t;

  memblock_t = record
    size: integer;  // including the header and possibly tiny fragments
    user: PPointer; // NULL if a free block
    tag: integer;   // purgelevel
    id: integer;    // should be ZONEID
    next: Pmemblock_t;
    prev: Pmemblock_t;
  end;

implementation

uses
  c_cmds,
  i_system;

//
// ZONE MEMORY ALLOCATION
//
// There is never any space between memblocks,
//  and there will never be two contiguous free memblocks.
// The rover can be left pointing at a non-empty block.
//
// It is of no value to free a cachable block,
//  because it will get overwritten automatically if needed.
//

const
  ZONEID = $1d4a11;

type
  memzone_t = record
    // total bytes malloced, including header
    size: integer;
    // start / end cap for linked list
    blocklist: memblock_t;
    rover: Pmemblock_t;
  end;
  Pmemzone_t = ^memzone_t;

var
  mainzone: Pmemzone_t;

//
// Z_FreeMemory
//
function Z_FreeMemory: integer;
var
  block: Pmemblock_t;
begin
  result := 0;

  block := mainzone.blocklist.next;
  while block <> @mainzone.blocklist do
  begin
    if (block.user = nil) or (block.tag >= PU_PURGELEVEL) then
      result := result + block.size;
    block := block.next;
  end;
end;

function Z_CacheMemory: integer;
var
  block: Pmemblock_t;
begin
  result := 0;

  block := mainzone.blocklist.next;
  while block <> @mainzone.blocklist do
  begin
    if block.tag >= PU_PURGELEVEL then
      result := result + block.size;
    block := block.next;
  end;
end;

procedure Z_CmdZoneMem;
var
  fr: integer;
  cache: integer;
begin
  printf('%6d KB memory allocated for zone.'#13#10, [mainzone.size div 1024]);
  fr := Z_FreeMemory;
  cache := Z_CacheMemory;
  printf('%6d KB zone memory in use.'#13#10, [(mainzone.size - fr + cache) div 1024]);
  printf('%6d KB zone memory used for static memory allocation.'#13#10, [(mainzone.size - fr) div 1024]);
  printf('%6d KB zone memory used for cache.'#13#10, [(cache) div 1024]);
  printf('%6d KB free zone memory.'#13#10, [(fr - cache) div 1024]);
  printf('%6d KB zone memory available for Z_Malloc().'#13#10, [fr div 1024]);
end;

procedure Z_CmdMem;
var
  imgsize: integer;
begin
  imgsize := I_GetExeImageSize;
  printf('%6d KB total memory in use.'#13#10, [(memoryusage + imgsize) div 1024]);
  printf('%6d KB program image size.'#13#10, [imgsize div 1024]);
  printf('%6d KB program memory allocation.'#13#10, [AllocMemSize div 1024]);
  printf('%6d KB total memory dynamically allocated.'#13#10, [memoryusage div 1024]);
  printf(#13#10);
  printf('%6d KB external memory allocated.'#13#10, [(memoryusage - mainzone.size) div 1024]);
  Z_CmdZoneMem;
end;

procedure Z_CmdZoneMemDump(const parm1, parm2: string);
var
  lowtag: integer;
  hightag: integer;
begin
  if parm1 <> '' then
  begin
    lowtag := atoi(parm1);
    if parm2 = '' then
      hightag := lowtag
    else
      hightag := atoi(parm2);
    if hightag < lowtag then
      Z_DumpHeap(hightag, lowtag)
    else
      Z_DumpHeap(lowtag, hightag);
  end
  else
    Z_DumpHeap(PU_LOTAG, PU_HITAG);
end;

//
// Z_ClearZone
//
procedure Z_ClearZone(zone: Pmemzone_t);
var
  block: Pmemblock_t;
begin
  // set the entire zone to one free block
  block := Pmemblock_t(integer(zone) + SizeOf(memzone_t));
  zone.blocklist.next := block;
  zone.blocklist.prev := block;

  zone.blocklist.user := PPointer(zone);
  zone.blocklist.tag := PU_STATIC;
  zone.rover := block;

  block.prev := @zone.blocklist;
  block.next := block.prev;

  // NULL indicates a free block.
  block.user := nil;

  block.size := zone.size - SizeOf(memzone_t);
end;

//
// Z_Init
//
procedure Z_Init;
var
  block: Pmemblock_t;
  size: integer;
begin
  mainzone := Pmemzone_t(I_ZoneBase(size));
  mainzone.size := size;

  // set the entire zone to one free block
  block := Pmemblock_t(integer(mainzone) + SizeOf(memzone_t));
  mainzone.blocklist.next := block;
  mainzone.blocklist.prev := block;

  mainzone.blocklist.user := PPointer(mainzone);
  mainzone.blocklist.tag := PU_STATIC;
  mainzone.rover := block;

  block.prev := @mainzone.blocklist;
  block.next := block.prev;

  // NULL indicates a free block.
  block.user := nil;

  block.size := mainzone.size - SizeOf(memzone_t);

  C_AddCmd('mem', @Z_CmdMem);
  C_AddCmd('zonemem', @Z_CmdZoneMem);
  C_AddCmd('zonedump', @Z_CmdZoneMemDump);
  C_AddCmd('zonefiledump', @Z_FileDumpHeap);

end;

procedure Z_ShutDown;
begin
  I_ZoneFree(pointer(mainzone));
end;

//
// Z_Free
//
procedure Z_Free(ptr: pointer);
var
  block: Pmemblock_t;
  other: Pmemblock_t;
begin
  block := Pmemblock_t(integer(ptr) - SizeOf(memblock_t));

  if block.id <> ZONEID then
    I_Error('Z_Free(): freed a pointer without ZONEID');

  if LongWord(block.user) > $100 then
  begin
    // smaller values are not pointers
    // Note: OS-dependend?

    // clear the user's mark
    block.user^ := nil;
  end;

  // mark as free
  block.user := nil;
  block.tag := 0;
  block.id := 0;

  other := block.prev;

  if other.user = nil then
  begin
    // merge with previous free block
    other.size := other.size + block.size;
    other.next := block.next;
    other.next.prev := other;

    if block = mainzone.rover then
      mainzone.rover := other;

    block := other;
  end;

  other := block.next;
  if other.user = nil then
  begin
    // merge the next free block onto the end
    block.size := block.size + other.size;
    block.next := other.next;
    block.next.prev := block;

    if other = mainzone.rover then
      mainzone.rover := block;
  end;
end;

//
// Z_Malloc
// You can pass a NULL user if the tag is < PU_PURGELEVEL.
//
const
  MINFRAGMENT = 64;

function Z_Malloc(size: integer; tag: integer; user: pointer): pointer;
var
  extra: integer;
  start: Pmemblock_t;
  rover: Pmemblock_t;
  newblock: Pmemblock_t;
  base: Pmemblock_t;
begin
  size := (size + 7) and (not 7);

  // scan through the block list,
  // looking for the first free block
  // of sufficient size,
  // throwing out any purgable blocks along the way.

  // account for size of block header
  size := size + SizeOf(memblock_t);

  // if there is a free block behind the rover,
  //  back up over them
  base := mainzone.rover;

  if base.prev.user = nil then
    base := base.prev;

  rover := base;
  start := base.prev;

  repeat
    if rover = start then
    begin
      // scanned all the way around the list
      I_Error('Z_Malloc(): failed on allocation of %d bytes.'#13#10 +
              'Zone memory in use: %d MB.'#13#10 +
              'Try to specify [-zone %d] from the command line.', [size, mb_used, mb_used + (size div 1024 div 1024) + 1]);
    end;

    if rover.user <> nil then
    begin
      if rover.tag < PU_PURGELEVEL then
      begin
        // hit a block that can't be purged,
        //  so move base past it
        rover := rover.next;
        base := rover;
      end
      else
      begin
        // free the rover block (adding the size to base)
        // the rover can be the base block
        base := base.prev;
        Z_Free(pointer(integer(rover) + SizeOf(memblock_t)));
        base := base.next;
        rover := base.next;
      end;
    end
    else
      rover := rover.next;
  until not ((base.user <> nil) or (base.size < size));


  // found a block big enough
  extra := base.size - size;

  if extra > MINFRAGMENT then
  begin
    // there will be a free fragment after the allocated block
    newblock := Pmemblock_t(integer(base) + size);
    newblock.size := extra;

    // NULL indicates free block.
    newblock.user := nil;
    newblock.tag := 0;
    newblock.prev := base;
    newblock.next := base.next;
    newblock.next.prev := newblock;

    base.next := newblock;
    base.size := size;
  end;

  if user <> nil then
  begin
    // mark as an in use block
    base.user := user;
    PPointer(user)^ := Pointer(integer(base) + SizeOf(memblock_t));
  end
  else
  begin
    if tag >= PU_PURGELEVEL then
      I_Error('Z_Malloc(): an owner is required for purgable blocks');

    // mark as in use, but unowned
    base.user := Pointer(2);
  end;

  base.tag := tag;

  // next allocation will start looking here
  mainzone.rover := base.next;

  base.id := ZONEID;

  result := Pointer(integer(base) + SizeOf(memblock_t));
end;

function Z_Malloc2(size: integer; tag: integer; user: pointer): pointer;
var
  extra: integer;
  start: Pmemblock_t;
  rover: Pmemblock_t;
  newblock: Pmemblock_t;
  base: Pmemblock_t;
begin
  size := (size + 7) and (not 7);

  // scan through the block list,
  // looking for the first free block
  // of sufficient size,
  // throwing out any purgable blocks along the way.

  // account for size of block header
  size := size + SizeOf(memblock_t);

  // if there is a free block behind the rover,
  //  back up over them
  base := mainzone.rover;

  if base.prev.user = nil then
    base := base.prev;

  rover := base;
  start := base.prev;

  repeat
    if rover = start then
    begin
      // scanned all the way around the list
      result := nil;
      exit;
    end;

    if rover.user <> nil then
    begin
      if rover.tag < PU_PURGELEVEL then
      begin
        // hit a block that can't be purged,
        //  so move base past it
        rover := rover.next;
        base := rover;
      end
      else
      begin
        // free the rover block (adding the size to base)
        // the rover can be the base block
        base := base.prev;
        Z_Free(pointer(integer(rover) + SizeOf(memblock_t)));
        base := base.next;
        rover := base.next;
      end;
    end
    else
      rover := rover.next;
  until not ((base.user <> nil) or (base.size < size));


  // found a block big enough
  extra := base.size - size;

  if extra > MINFRAGMENT then
  begin
    // there will be a free fragment after the allocated block
    newblock := Pmemblock_t(integer(base) + size);
    newblock.size := extra;

    // NULL indicates free block.
    newblock.user := nil;
    newblock.tag := 0;
    newblock.prev := base;
    newblock.next := base.next;
    newblock.next.prev := newblock;

    base.next := newblock;
    base.size := size;
  end;

  if user <> nil then
  begin
    // mark as an in use block
    base.user := user;
    PPointer(user)^ := Pointer(integer(base) + SizeOf(memblock_t));
  end
  else
  begin
    if tag >= PU_PURGELEVEL then
      I_Error('Z_Malloc(): an owner is required for purgable blocks');

    // mark as in use, but unowned
    base.user := Pointer(2);
  end;

  base.tag := tag;

  // next allocation will start looking here
  mainzone.rover := base.next;

  base.id := ZONEID;

  result := Pointer(integer(base) + SizeOf(memblock_t));
end;

function Z_Realloc(ptr: pointer; size: integer; tag: integer; user: pointer): pointer;
var
  block: Pmemblock_t;
  tmp: pointer;
  copysize: integer;
begin
  if size = 0 then
  begin
    Z_Free(ptr);
    result := nil;
    exit;
  end;

  if ptr = nil then
  begin
    result := Z_Malloc(size, tag, user);
    exit;
  end;

  block := Pmemblock_t(integer(ptr) - SizeOf(memblock_t));
  if block.size = size then
  begin
    result := ptr;
    exit;
  end;

  if size > block.size then
    copysize := block.size
  else
    copysize := size;
  result := Z_Malloc2(size, tag, user);
  if result <> nil then
  begin
    memcpy(result, ptr, copysize);
    Z_Free(ptr);
  end
  else
  begin
    tmp := malloc(block.size);
    memcpy(tmp, ptr, copysize);
    Z_Free(ptr);
    result := Z_Malloc(size, tag, user);
    memcpy(result, tmp, copysize);
  end;
end;

//
// Z_FreeTags
//
function Z_FreeTags(lowtag: integer; hightag: integer): boolean;
var
  block: Pmemblock_t;
  next: Pmemblock_t;
begin
  result := false;
  block := mainzone.blocklist.next;
  while block <> @mainzone.blocklist do
  begin
    // get link before freeing
    next := block.next;

    // not free block?
    if block.user <> nil then
      if (block.tag >= lowtag) and (block.tag <= hightag) then
      begin
        Z_Free(Pointer(integer(block) + SizeOf(memblock_t)));
        result := true;
      end;
    block := next;
  end;
end;

//
// Z_DumpHeap
// Note: TFileDumpHeap( stdout ) ?
//
procedure Z_DumpHeap(lowtag: integer; hightag: integer);
var
  block: Pmemblock_t;
begin
  printf('zone size: %d  location: %s'#13#10,
    [mainzone.size, IntToStrZfill(8, integer(mainzone))]);

  printf('tag range: %s to %s'#13#10,
    [IntToStrZfill(3, lowtag), IntToStrZfill(3, hightag)]);

  block := mainzone.blocklist.next;
  while true do
  begin
    if (block.tag >= lowtag) and (block.tag <= hightag) then
      printf('block:%s    size:%s    user:%s    tag:%s'#13#10,
        [IntToStrZfill(8, integer(block)), IntToStrZfill(7, block.size),
         IntToStrZfill(8, integer(block.user)), IntToStrZfill(3, block.tag)]);
    if block.next = @mainzone.blocklist then
    begin
      // all blocks have been hit
      break;
    end;

    if integer(block) + block.size <> integer(block.next) then
      printf('ERROR: block size does not touch the next block'#13#10);

    if block.next.prev <> block then
      printf('ERROR: next block doesn''t have proper back link'#13#10);

    if (block.user = nil) and (block.next.user = nil) then
      printf('ERROR: two consecutive free blocks'#13#10);

    block := block.next;
  end;
end;

procedure Z_FileDumpHeapf(var f: file);
var
  block: Pmemblock_t;
begin
  fprintf(f, 'zone size: %d  location: %s'#13#10,
    [mainzone.size, IntToStrZfill(8, integer(mainzone))]);

  block := mainzone.blocklist.next;
  while true do
  begin
    fprintf(f, 'block:%s    size:%s    user:%s    tag:%s'#13#10,
      [IntToStrZfill(8, integer(block)), IntToStrZfill(7, block.size),
       IntToStrZfill(8, integer(block.user)), IntToStrZfill(3, block.tag)]);
    if block.next = @mainzone.blocklist then
    begin
      // all blocks have been hit
      break;
    end;

    if integer(block) + block.size <> integer(block.next) then
      fprintf(f, 'ERROR: block size does not touch the next block'#13#10);

    if block.next.prev <> block then
      fprintf(f, 'ERROR: next block doesn''t have proper back link'#13#10);

    if (block.user = nil) and (block.next.user = nil) then
      fprintf(f, 'ERROR: two consecutive free blocks'#13#10);

    block := block.next;
  end;
end;

procedure Z_FileDumpHeap(const filename: string);
var
  f: file;
begin
  if filename = '' then
  begin
    printf('Please specify the filename to dump the Zone Heap'#13#10);
    exit;
  end;

  if fopen(f, filename, fCreate) then
  begin
    Z_FileDumpHeapf(f);
    close(f);
  end
  else
    I_Warning('Z_FileDumpHeap(): Can not create output file: %s'#13#10, [filename]);
end;

//
// Z_CheckMemory
//
procedure Z_CheckMemory;
var
  block: Pmemblock_t;
begin
  block := mainzone.blocklist.next;
  while block <> @mainzone.blocklist do
  begin
    if (integer(block.user) > 100) and (integer(block.user) < $10000) then
      I_Error('Z_CheckMemory(): User is invalid pointer ($%.*x)', [4, integer(block.user)]);
    block := block.next;
  end;
end;

//
// Z_CheckHeap
//
procedure Z_CheckHeap;
var
  block: Pmemblock_t;
begin
  block := mainzone.blocklist.next;
  while true do
  begin
    if block.next = @mainzone.blocklist then
    begin
      // all blocks have been hit
      break;
    end;

    if integer(block) + block.size <> integer(block.next) then
      I_Error('Z_CheckHeap(): block size does not touch the next block, block=%d, block size=%d, next block = %d', [integer(block), block.size, integer(block.next)]);

    if block.next.prev <> block then
      I_Error('Z_CheckHeap(): next block doesn''t have proper back link');

    if (block.user = nil) and (block.next.user = nil) then
      I_Error('Z_CheckHeap(): two consecutive free blocks');

    block := block.next
  end;
end;

//
// Z_ChangeTag
//
procedure Z_ChangeTag(ptr: pointer; tag: integer);
var
  block: Pmemblock_t;
begin
  block := Pmemblock_t(integer(ptr) - SizeOf(memblock_t));

  if block.id <> ZONEID then
    I_Error('Z_ChangeTag(): freed a pointer without ZONEID');

  if (tag >= PU_PURGELEVEL) and (LongWord(block.user) < $100) then
    I_Error('Z_ChangeTag(): an owner is required for purgable blocks');

  block.tag := tag;
end;

end.

