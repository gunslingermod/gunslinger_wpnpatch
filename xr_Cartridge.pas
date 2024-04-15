unit xr_Cartridge;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface
uses xr_strings;
type CCartridge = packed record
  vtable:pointer;
  m_ammo_sect:shared_str;
  SCartridgeParam__kDist:single;
  SCartridgeParam__kDisp:single;
  SCartridgeParam__kHit:single;
  SCartridgeParam__kImpulse:single;
  SCartridgeParam__kAP:single;
  SCartridgeParam__kAirRes:single;
  SCartridgeParam__buck_shot:integer;
  SCartridgeParam__impair:single;
  SCartridgeParam__fWallmarkSize:single;
  SCartridgeParam__u8ColorID:byte;
  __unused1:byte;
  __unused2:word;
  m_local_ammotype:byte;
  __unused3:byte;
  bullet_material_idx:word;
  _flags:cardinal;
  m_InvShortName: {shared_str} pointer;
end;

pCCartridge = ^CCartridge;

II_BriefInfo = packed record
  name:shared_str;
  icon:shared_str;
  cur_ammo:shared_str;
  fmj_ammo:shared_str;
  ap_ammo:shared_str;
  fire_mode:shared_str;
  grenade:shared_str;
end;
pII_BriefInfo = ^II_BriefInfo;

procedure CCartridge__Load(this:pointer; name:PChar; local_ammotype:byte); stdcall;
procedure CopyCartridge(var src:CCartridge; var dst:CCartridge); stdcall;
function GetCartridgeFromMagVector(wpn:pointer; index:cardinal):pCCartridge; stdcall;
function GetGrenadeCartridgeFromGLVector(wpn:pointer; index:cardinal):pCCartridge; stdcall;
function GetMainAmmoTypesCount(wpn:pointer):integer; stdcall;
function GetMainCartridgeSectionByType(wpn:pointer; ammotype:byte):PChar; stdcall;
function GetCurrentCartridgeSectionByType(wpn:pointer; ammotype:byte):PChar; stdcall;
function GetAmmoTypeChangingStatus(wpn:pointer):byte; stdcall;
procedure SetAmmoTypeChangingStatus(wpn:pointer; status:byte); stdcall;
function GetAmmoTypeIndex(wpn:pointer; second:boolean=false):byte; stdcall;
function GetAmmoTypeToReload(wpn:pointer):byte; stdcall;   //Вернет индекс для текущего активного магазина (т.е. разные в режиме подствола и обычном)
function CWeapon__GetAmmoCount(wpn:pointer; ammo_type:byte):integer; stdcall;
function CWeaponMagazinedWGrenade__GetAmmoCount2(wpn:pointer; ammo_type:byte):integer; stdcall;
function GetCartridgeSection(c:pCCartridge):PChar; stdcall;
function GetGLAmmoTypesCount(wpn:pointer):cardinal; stdcall;
function GetGLCartridgeSectionByType(wpn:pointer; ammotype:byte):PChar; stdcall;
procedure SetAmmoTypeIndex(wpn:pointer; index:byte; second:boolean); stdcall;
function GetCartridgeType(c:pCCartridge):byte;

procedure InitCartridge(c:pCCartridge); stdcall;
procedure FreeCartridge(c:pCCartridge); stdcall;


implementation
uses  math, HudItemUtils, BaseGameData;


procedure CopyCartridge(var src:CCartridge; var dst:CCartridge); stdcall;
begin
  Move(src, dst, sizeof(dst));
end;

procedure CCartridge__Load(this:pointer; name:PChar; local_ammotype:byte); stdcall;
asm
  pushad
    mov ecx, this
    movzx eax, local_ammotype
    push eax
    push name
    mov eax, xrgame_addr
    add eax, $2C4180
    call eax
  popad
end;

function GetCartridgeFromMagVector(wpn:pointer; index:cardinal):pCCartridge; stdcall;
var
  tmp, gl_status:cardinal;
  ptr:pointer;
begin
  result:=nil;
  if (wpn=nil) or (index>=GetAmmoInMagCount(wpn)) then exit;

  gl_status:=GetGLStatus(wpn);
  if ((gl_status=1) or ((gl_status=2) and (IsGLAttached(wpn)))) and IsGLEnabled(wpn) then
    ptr:= PChar(wpn)+$7EC
  else
    ptr:= PChar(wpn)+$6C8;
  tmp:=(pcardinal(ptr))^;
  result:=pointer(tmp+$3C*index);
end;

function GetGrenadeCartridgeFromGLVector(wpn:pointer; index:cardinal):pCCartridge; stdcall;
var
  tmp, gl_status:cardinal;
  ptr:pointer;
begin
  result:=nil;
  if (wpn=nil) then exit;

  gl_status:=GetGLStatus(wpn);
  if (gl_status=0) or ((gl_status=2) and not (IsGLAttached(wpn))) or (index>=GetAmmoInGLCount(wpn)) then exit;
  if IsGrenadeMode(wpn) then
    ptr:= PChar(wpn)+$6C8
  else
    ptr:= PChar(wpn)+$7EC;

  tmp:=(pcardinal(ptr))^;
  result:=pointer(tmp+sizeof(CCartridge)*index);
end;

function GetCurrentCartridgeSectionByType(wpn:pointer; ammotype:byte):PChar; stdcall;
begin
  if IsGrenadeMode(wpn) then begin
    result:=GetGLCartridgeSectionByType(wpn, ammotype);
  end else begin
    result:=GetMainCartridgeSectionByType(wpn, ammotype);
  end;
end;

function GetMainCartridgeSectionByType(wpn:pointer; ammotype:byte):PChar; stdcall;
var
  tmp, gl_status:cardinal;
  ptr:pointer;
begin
  result:=nil;
  if (wpn=nil) or (ammotype>=GetMainAmmoTypesCount(wpn)) then exit;

  gl_status:=GetGLStatus(wpn);
  if ((gl_status=1) or ((gl_status=2) and IsGLAttached(wpn))) and IsGLEnabled(wpn) then
    ptr:= PChar(wpn)+$7D8
  else
    ptr:= PChar(wpn)+$6A4;
    
  tmp:=(pcardinal(ptr))^;

  result:=pointer(pcardinal(tmp+4*ammotype)^+$10);

end;

function GetGLCartridgeSectionByType(wpn:pointer; ammotype:byte):PChar; stdcall;
var
  tmp, gl_status:cardinal;
  ptr:pointer;
begin
  result:=nil;
  if (wpn=nil) then exit;

  gl_status:=GetGLStatus(wpn);
  if (gl_status=0) or ((gl_status=2) and not IsGLAttached(wpn)) or (ammotype>=GetGLAmmoTypesCount(wpn)) then exit;

  if not IsGLEnabled(wpn) then
    ptr:= PChar(wpn)+$7D8
  else
    ptr:= PChar(wpn)+$6A4;
    
  tmp:=(pcardinal(ptr))^;

  result:=pointer(pcardinal(tmp+4*ammotype)^+$10);

end;


function GetGLAmmoTypesCount(wpn:pointer):cardinal; stdcall;
var
  pstart, pend, gl_status:cardinal;
  ptr:pointer;
begin
  result:=0;
  if (wpn=nil) then exit;

  gl_status:=GetGLStatus(wpn);
  if (gl_status=0) or ((gl_status = 2) and not IsGLAttached(wpn)) then exit;

  if IsGrenadeMode(wpn) then
    ptr:= PChar(wpn)+$6A4
  else
    ptr:= PChar(wpn)+$7D8;

  pstart:=(pcardinal(ptr))^;
  pend:=(pcardinal(PChar(ptr)+4))^;

  result:=(pend-pstart) div sizeof(pointer);
end;

function GetMainAmmoTypesCount(wpn:pointer):integer; stdcall;
asm
  pushad
  pushfd
    mov ebx, wpn

    pushad
    push ebx
    call GetGLStatus
    cmp eax, 0
    popad
    je @use_main
    push ebx
    call IsGLEnabled
    cmp al, 0
    jne @use_alter

    @use_main:
    mov edx, [ebx+$6A8]
    sub edx, [ebx+$6A4]
    jmp @divide

    @use_alter:
    mov edx, [ebx+$7DC]
    sub edx, [ebx+$7D8]
    jmp @divide

    @divide:
    movzx eax, dx
    shr eax, 2

    mov @result, eax

  popfd
  popad
end;

function GetAmmoTypeToReload(wpn:pointer):byte; stdcall;
begin
  //Вернет индекс для текущего активного магазина (т.е. разные в режиме подствола и обычном)
  result:=GetAmmoTypeChangingStatus(wpn);
  if result=$FF then result:=GetAmmoTypeIndex(wpn);
end;

function GetAmmoTypeChangingStatus(wpn:pointer):byte; stdcall;
asm
    mov eax, wpn
    mov al, byte ptr [eax+$6C7]
    mov @result, al
end;

procedure SetAmmoTypeChangingStatus(wpn:pointer; status:byte); stdcall;
asm
    push eax
    push ecx

    mov eax, wpn
    mov cl, status
    mov byte ptr [eax+$6C7], cl

    pop ecx
    pop eax
end;

function GetAmmoTypeIndex(wpn:pointer; second:boolean):byte; stdcall;
asm

  mov eax, wpn
  cmp second, 0

  jne @second
  movzx eax, byte ptr [eax+$6C4]

  jmp @finish

  @second:
  movzx eax, byte ptr [eax+$7E4]

  @finish:

end;


procedure SetAmmoTypeIndex(wpn:pointer; index:byte; second:boolean); stdcall;
asm
  push eax
  mov eax, wpn
  cmp second, 0

  jne @second
  mov al, index
  mov byte ptr [eax+$6C4], al

  jmp @finish

  @second:
  mov al, index
  mov byte ptr [eax+$7E4], al

  @finish:
  pop eax
end;

function CWeapon__GetAmmoCount(wpn:pointer; ammo_type:byte):integer; stdcall;
asm
  pushad
    movzx eax, ammo_type
    push eax
    mov ecx, wpn

    mov eax, xrgame_addr
    add eax, $2BE0D0
    call eax

    mov @result, eax
  popad
end;

function CWeaponMagazinedWGrenade__GetAmmoCount2(wpn:pointer; ammo_type:byte):integer; stdcall;
asm
  pushad
    movzx eax, ammo_type
    push eax
    mov ecx, wpn

    mov eax, xrgame_addr
    add eax, $2d20a0
    call eax

    mov @result, eax
  popad
end;

function GetCartridgeSection(c:pCCartridge):PChar;
begin
  result:=get_string_value(@c.m_ammo_sect);
  if length(result)=0 then result:=nil;
end;

function GetCartridgeType(c:pCCartridge):byte;
begin
  result:=c.m_local_ammotype;
end;

procedure InitCartridge(c:pCCartridge); stdcall;
begin
  c.vtable:=pointer(xrgame_addr+$5559c4);
  init_string(@c.m_ammo_sect);
  c.SCartridgeParam__kDist:=1.0;
  c.SCartridgeParam__kDisp:=1.0;
  c.SCartridgeParam__kHit:=1.0;
  c.SCartridgeParam__kImpulse:=1.0;
  c.SCartridgeParam__kAP:=1.0;
  c.SCartridgeParam__kAirRes:=1.0;
  c.SCartridgeParam__buck_shot:=1;
  c.SCartridgeParam__impair:=1.0;
  c.SCartridgeParam__fWallmarkSize:=0.05;
  c.SCartridgeParam__u8ColorID:=0;
  c.m_local_ammotype:=0;
  c.bullet_material_idx:=$FFFF;
  c._flags:=0;
  c.m_InvShortName:=nil;
end;

procedure FreeCartridge(c:pCCartridge); stdcall;
begin
  assign_string(@c.m_ammo_sect, nil);
end;

end.
