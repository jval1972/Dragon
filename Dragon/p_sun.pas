unit p_sun;

interface

uses
  m_fixed,
    p_mobj_h;

procedure P_SetSun(const mo: Pmobj_t);

function P_CanSeeSun(const actor: Pmobj_t): boolean;

var
  sun: Pmobj_t = nil;

implementation

uses
  p_sight;
  
procedure P_SetSun(const mo: Pmobj_t);
begin
  sun := mo;
end;

function P_CanSeeSun(const actor: Pmobj_t): boolean;
begin
  if sun = nil then
  begin
    result := false;
    exit;
  end;

  result := P_CheckSight(actor, sun);
end;

end.
