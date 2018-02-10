unit xr_RocketLauncher;

interface
uses MatVectors;
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
procedure DetachRocket(rl:pCRocketLauncher; rocket_id:word; bLaunch:boolean); stdcall;

procedure CWeaponMagazinedWGrenade__LaunchGrenade(wpn:pointer); stdcall;
procedure CRocketLauncher__SpawnRocket(rl:pointer; g_section:PChar);

procedure LL_SetRocketLaunchedStatus(r:pCCustomRocket; status:boolean); stdcall;

procedure virtual_CCustomRocket__Contact(r:pCCustomRocket; pos:pFVector3; normal:pFVector3);  stdcall;

implementation
uses Misc, BaseGameData, sysutils, dynamic_caster;

procedure DetachRocket(rl:pCRocketLauncher; rocket_id:word; bLaunch:boolean); stdcall;
asm
  pushad
    movzx ebx, bLaunch
    push ebx

    movzx eax, rocket_id
    push eax    

    mov ecx, rl
    mov eax, xrgame_addr
    add eax, $2CC880
    call eax
  popad
end;

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
  cnt:cardinal;
  r:pCCustomRocket;
begin
  cnt:=GetRocketsCount(rl);
  if cnt=0 then exit;
  r:= GetRocket(rl, cnt-1);
  alife_release(get_server_object_by_id(GetCObjectID(r)));
  rl.m_rockets__last:=pointer(cardinal(rl.m_rockets__last)-4);
end;

procedure CWeaponMagazinedWGrenade__LaunchGrenade(wpn:pointer); stdcall;
asm
  pushad
    mov ecx, wpn
    mov eax, xrgame_addr
    add eax, $2D2C70
    call eax
  popad
end;

procedure CRocketLauncher__SpawnRocket(rl:pointer; g_section:PChar);
var
  g_string:string;
  s, pps:PChar;
  l:cardinal;
  cgo:pointer;
begin
  l:=length(g_section);
  g_string:=chr(0)+chr(0)+chr(0)+chr(0);
  g_string:=g_string+(PChar(@l))[0]+(PChar(@l))[1]+(PChar(@l))[2]+(PChar(@l))[3];
  g_string:=g_string+chr(0)+chr(0)+chr(0)+chr(0);
  g_string:=g_string+chr(0)+chr(0)+chr(0)+chr(0);
  g_string:=g_string+g_section+chr(0);
  cgo:=dynamic_cast(rl, 0, RTTI_CRocketLauncher, RTTI_CGameObject, false);

  s:=PChar(g_string);
  pps:=@s;

  asm
    pushad
      push cgo
      push pps

      mov eax, xrgame_addr
      add eax, $2CC6D0
      call eax

    popad
  end;

end;

procedure virtual_CCustomRocket__Contact(r:pCCustomRocket; pos:pFVector3; normal:pFVector3); stdcall;
asm
  pushad
    push normal
    push pos 
    mov ecx, r
    mov eax, [ecx]
    mov eax, [eax+$210]
    call eax
  popad
end;

procedure LL_SetRocketLaunchedStatus(r:pCCustomRocket; status:boolean); stdcall;
asm
  pushad
  mov esi, r
  mov al, status
  mov byte ptr [esi+$208], al
  popad
end;



end.
