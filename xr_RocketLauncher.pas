unit xr_RocketLauncher;

interface

type CRocketLauncher = packed record
  vtable:pointer;
  m_rockets__first:pointer;
  m_rockets__last:pointer;
  m_rockets__memend:pointer;

  m_launched_rockets__first:pointer;
  m_launched_rockets__last:pointer;
  m_launched_rockets__memend:pointer;

  m_fLaunchSpeed:single;
end;

pCRocketLauncher = ^CRocketLauncher;

pCCustomRocket = pointer;

function GetRocketsCount(rl:pCRocketLauncher):cardinal; stdcall;
function GetRocket(rl:pCRocketLauncher; index:cardinal):pCCustomRocket; stdcall;
procedure UnloadRockets(rl:pCRocketLauncher); stdcall;
procedure UnloadOneRocket(rl:pCRocketLauncher); stdcall;

implementation
uses Misc, BaseGameData, sysutils;

function GetRocketsCount(rl:pCRocketLauncher):cardinal; stdcall;
begin
  result:= (cardinal(rl.m_rockets__last)-cardinal(rl.m_rockets__first)) div 4;
end;

function GetRocket(rl:pCRocketLauncher; index:cardinal):pCCustomRocket; stdcall;
begin
  result:= pCCustomRocket(   pcardinal(cardinal(rl.m_rockets__first)+index*4)^   );
end;

procedure UnloadRockets(rl:pCRocketLauncher); stdcall;
var
  cnt, i:cardinal;
  r:pCCustomRocket;
begin
  cnt:=GetRocketsCount(rl);
  if cnt=0 then exit;
  for i:=0 to cnt-1 do begin
    r:= GetRocket(rl, i);
    alife_release(get_server_object_by_id(GetCObjectID(r)));
  end;
  rl.m_rockets__last:=rl.m_rockets__first;
end;


procedure UnloadOneRocket(rl:pCRocketLauncher); stdcall;
var
  cnt, i:cardinal;
  r:pCCustomRocket;
begin
  cnt:=GetRocketsCount(rl);
  if cnt=0 then exit;
  r:= GetRocket(rl, cnt-1);
  alife_release(get_server_object_by_id(GetCObjectID(r)));
  rl.m_rockets__last:=pointer(cardinal(rl.m_rockets__last)-4);
end;

end.
