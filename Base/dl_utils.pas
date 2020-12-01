unit dl_utils;

interface

function Get2Ints(const s: string; var i1, i2: integer): boolean;

function IsCDRomDrive(const drive: char = #0): boolean;

implementation

uses
  Windows, SysUtils;
  
function Get2Ints(const s: string; var i1, i2: integer): boolean;
var
  p: integer;
  s1, s2: string;
begin
  p := Pos('x', s);
  if p <= 0 then
  begin
    result := false;
    exit;
  end;

  s1 := Copy(s, 1, p - 1);
  s2 := Copy(s, p + 1, length(s) - p);

  i1 := StrToIntDef(s1, -1);
  i2 := StrToIntDef(s2, -1);

  result := (i1 > 0) and (i2 > 0);

end;

function IsCDRomDrive(const drive: char = #0): boolean;
var
  drv: array[0..3] of char;
  prm: string;
  i: integer;
begin
  if drive = #0 then
  begin
    prm := ParamStr(0);
    if length(prm) > 4 then
    begin
      for i := 0 to 2 do
        drv[i] := prm[i + 1];
      drv[3] := #0;
      result := GetDriveType(drv) = DRIVE_CDROM;
    end
    else
      result := GetDriveType(nil) = DRIVE_CDROM
  end
  else
  begin
    drv[0] := drive;
    drv[1] := ':';
    drv[2] := '\';
    drv[3] := #0;
    result := GetDriveType(drv) = DRIVE_CDROM;
  end;
end;



end.
 