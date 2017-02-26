unit xr_Cartridge;

interface
type CCartridge = packed record
  vtable:pointer;
  m_ammo_sect: {shared_str} pointer;
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

type pCCartridge = ^CCartridge;

procedure CCartridge__Load(this:pointer; name:PChar; local_ammotype:byte); stdcall;
procedure CopyCartridge(var src:CCartridge; var dst:CCartridge); stdcall;
function GetCartridgeFromMagVector(wpn:pointer; index:cardinal):pCCartridge; stdcall;
function GetMainAmmoTypesCount(wpn:pointer):integer; stdcall;
function GetMainCartridgeSectionByType(wpn:pointer; ammotype:byte):PChar; stdcall;
procedure ChangeAmmoVectorStart(wpn:pointer; bytes:integer); stdcall;
function GetAmmoTypeChangingStatus(wpn:pointer):byte; stdcall;
procedure SetAmmoTypeChangingStatus(wpn:pointer; status:byte); stdcall;
function GetAmmoTypeIndex(wpn:pointer):byte; stdcall;
function GetAmmoTypeToReload(wpn:pointer):byte; stdcall;
function CWeapon__GetAmmoCount(wpn:pointer; ammo_type:byte):integer; stdcall;


implementation
uses  math, HudItemUtils, BaseGameData;


procedure ChangeAmmoVectorStart(wpn:pointer; bytes:integer); stdcall;
asm
  pushad
  mov eax, wpn
  mov ebx, bytes
  add [eax+$6c8], ebx

  popad
end;


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
  tmp:cardinal;
  ptr:pointer;
begin
  result:=nil;
  if (wpn=nil) or (index>=GetAmmoInMagCount(wpn)) then exit;
  if ((GetGLStatus(wpn)=1) or (IsGLAttached(wpn))) and IsGLEnabled(wpn) then
    ptr:= PChar(wpn)+$7EC
  else
    ptr:= PChar(wpn)+$6C8;
  tmp:=(pcardinal(ptr))^;
  result:=pointer(tmp+$3C*index);
end;

function GetMainCartridgeSectionByType(wpn:pointer; ammotype:byte):PChar; stdcall;
var
  tmp:cardinal;
  ptr:pointer;
begin
  result:=nil;
  if (wpn=nil) or (ammotype>=GetMainAmmoTypesCount(wpn)) then exit;

  if ((GetGLStatus(wpn)=1) or (IsGLAttached(wpn))) and IsGLEnabled(wpn) then
    ptr:= PChar(wpn)+$7D8
  else
    ptr:= PChar(wpn)+$6A4;
    
  tmp:=(pcardinal(ptr))^;

  result:=pointer(pcardinal(tmp+4*ammotype)^+$10);

end;

function GetMainAmmoTypesCount(wpn:pointer):integer; stdcall;
asm
  pushad
  pushfd
    mov ebx, wpn

    push ebx
    call GetGLStatus
    cmp eax, 0
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

function GetAmmoTypeIndex(wpn:pointer):byte; stdcall;
asm
    mov eax, wpn
    mov al, byte ptr [eax+$6C4]
    mov @result, al
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

end.
