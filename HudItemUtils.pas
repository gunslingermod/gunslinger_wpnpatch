unit HudItemUtils;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface
uses MatVectors, WeaponSoundLoader, UIUtils;

type CMotionDef = packed record
  bone_or_part:word;
  motion:word;
  speed:word;
  power:word;
  accrue:word;
  falloff:word;
  flags:cardinal;
  marks_vec_start:pointer;
  marks_vec_end:pointer;
  marks_vec_end2:pointer;
end;
pCMotionDef = ^CMotionDef;

function Init():boolean;

function GetPlayerHud():pointer; stdcall;
procedure player_hud__attach_item(wpn:pointer); stdcall;
procedure ChangeParticles(wpn:pointer; name:PChar; particle_type:cardinal); stdcall;

function GetAttachableHudItem(index:cardinal):pointer; stdcall;
function GetCHudItemFromAttachableHudItem(ahi:pointer):pointer; stdcall;
procedure PlayAnimIdle(wpn: pointer); stdcall;
//function GetPositionVector(obj:pointer):pointer;
//function GetCurrentHud(wpn: pointer):pointer; stdcall;
procedure PlayHudAnim(wpn: pointer; anim_name:PChar; bMixIn:boolean); stdcall;
function get_addons_state(wpn:pointer):cardinal; stdcall;
procedure set_addons_state(wpn:pointer; state:cardinal); stdcall;
function IsScopeAttached(wpn:pointer):boolean; stdcall;
function IsSilencerAttached(wpn:pointer):boolean; stdcall;
function IsGLAttached(wpn:pointer):boolean; stdcall;
function IsGLEnabled(wpn:pointer):boolean; stdcall;       //����� ������� - ����������� ���������, ��� ���������� �� ������ ������ ����! ��������� ������ ������ �� ������������ ����������, � ����� ������� ����� ���������� ����� ��� ���� ������������� �����!
procedure SetGLEnabled(wpn:pointer; state:boolean); stdcall;
function IsWeaponJammed(wpn:pointer):boolean; stdcall;
function CurrentQueueSize(wpn:pointer):integer; stdcall;
function GetInstalledUpgradesCount(wpn:pointer):cardinal; stdcall;
function GetInstalledUpgradeSection(wpn:pointer; index:cardinal):PChar; stdcall;
function FindBoolValueInUpgradesDef(wpn:pointer; key:PChar; def:boolean; scan_after_nodefault:boolean=false):boolean; stdcall;
function FindStrValueInUpgradesDef(wpn:pointer; key:PChar; def:PChar):PChar; stdcall;
function FindIntValueInUpgradesDef(wpn:pointer; key:PChar; def:integer):integer; stdcall;
function ModifyFloatUpgradedValue(wpn:pointer; key:PChar; def:single):single; stdcall;
function GetSection(wpn:pointer):PChar; stdcall;
function GetID(wpn:pointer):word; stdcall;
function GetWeaponVisualName(wpn:pointer):pchar; stdcall;
function GetHUDSection(wpn:pointer):PChar; stdcall;
function GetScopeStatus(wpn:pointer):cardinal; stdcall;
function GetSilencerStatus(wpn:pointer):cardinal; stdcall;
function GetGLStatus(wpn:pointer):cardinal; stdcall;
function GetCurrentScopeSection(wpn:pointer):PChar; stdcall;
function GetScopesCount(wpn:pointer):cardinal; stdcall;
function GetCurrentScopeIndex(wpn:pointer):integer; stdcall;
function GetScopeSection(wpn:pointer; index:cardinal):PChar; stdcall;
procedure SetWpnVisual(wpn:pointer; name:pchar);stdcall;
procedure SetObjectVisual(obj:pointer; name:pchar);stdcall;
procedure SetHUDSection(wpn:pointer; new_hud_section:PChar); stdcall;
function GetAmmoInMagCount(wpn:pointer):cardinal; stdcall;
function GetAmmoInGLCount(wpn:pointer):cardinal; stdcall;
procedure SetAmmoInGLCount(wpn:pointer; cnt:cardinal); stdcall;
function GetCurrentAmmoCount(wpn:pointer):integer; stdcall;
procedure SetCurrentAmmoCount(wpn:pointer; cnt:integer); stdcall;
function GetOwner(wpn:pointer):pointer; stdcall;
function IsAimNow(wpn:pointer):boolean; stdcall;
function GetAimFactor(wpn:pointer):single; stdcall;
procedure SetAimFactor(wpn:pointer; f:single); stdcall;
function IsZoomHideCrosshair(wpn:pointer):boolean; stdcall;

function IsTriStateReload(wpn:pointer):boolean; stdcall;

function GetCurrentState(wpn:pointer):integer; stdcall;
procedure CHudItem_Play_Snd(itm:pointer; alias:PChar); stdcall;
procedure CHudItem_StopAllSounds(itm:pointer); stdcall;
function GetLevelVertexID(wpn:pointer):cardinal; stdcall;
function GetGameVertexID(wpn:pointer):cardinal; stdcall;
function GetSilencerSection(wpn:pointer):PChar; stdcall;
procedure DetachAddon(wpn:pointer; addon_type:integer);stdcall;
function GetGLSection(wpn:pointer):PChar; stdcall;
procedure SetShootLockTime(wpn:pointer; time:single);stdcall;
function GetShootLockTime(wpn:pointer):single;stdcall;
function GetOneShotTime(wpn:pointer):single;stdcall;
procedure SetCurrentScopeType(wpn:pointer; scope_type:byte); stdcall;
function GetCurrentCondition(wpn:pointer):single; stdcall;
procedure SetCondition(wpn:pointer; cond:single); stdcall;
function GetPosition(wpn:pointer):pointer; stdcall;
function GetOrientation(wpn:pointer):pointer; stdcall;
function GetActualCurrentAnim(wpn:pointer):PChar; stdcall;
procedure CSE_SetPosition(swpn:pointer; pos:pointer); stdcall;
procedure CSE_SetAngle(swpn:pointer; ang:pointer); stdcall;
procedure SetCurrentParticles(wpn:pointer; name:PChar; part_type:cardinal); stdcall;
function GetMagCapacityInCurrentWeaponMode(wpn:pointer):integer; stdcall;
procedure SetMagCapacityInCurrentWeaponMode(wpn:pointer; cnt:integer); stdcall;
function GetNextState(wpn:pointer):integer; stdcall;
procedure SetWeaponMisfireStatus(wpn:pointer; status:boolean); stdcall;
procedure ForceWpnHudBriefUpdate(wpn:pointer); stdcall;
procedure PlayCycle (obj:pointer; anim:PChar; mix_in:boolean);stdcall;
function QueueFiredCount(wpn:pointer):integer; stdcall;
procedure SetQueueFiredCount(wpn:pointer; cnt:cardinal); stdcall;
function GetCurrentMotionDef(wpn:pointer):pCMotionDef; stdcall;
function CSE_GetWpnState(swpn:pointer):byte; stdcall;
procedure CSE_SetWpnState(swpn:pointer; s:byte); stdcall;
function CSE_GetAddonsFlags(swpn:pointer):byte; stdcall;
procedure CSE_SetAddonsFlags(swpn:pointer; s:byte); stdcall;



function GetClassName(wpn:pointer):string; stdcall;

function WpnCanShoot(wpn:pointer):boolean;stdcall;
function WpnIsDetector(wpn:pointer):boolean;stdcall;
function IsKnife(wpn:pointer):boolean;stdcall;
function IsThrowable(wpn:pointer):boolean;stdcall;
function IsBino(wpn:pointer):boolean;stdcall;
function IsBM16(wpn:pointer):boolean;stdcall;
function IsDetector(wpn:pointer):boolean;stdcall;


function GetAnimTimeState(wpn:pointer; what:cardinal=$2FC):cardinal; stdcall;

procedure SetSubState(wpn:pointer; substate:byte); stdcall;
function GetSubState(wpn:pointer):byte; stdcall;

{function CountOfCurrentAmmoInRuck(wpn:pointer):cardinal; stdcall;
function CountOfOtherAmmoInRuck(wpn:pointer):cardinal; stdcall;}

procedure SetCurrentState(wpn:pointer; status:cardinal); stdcall;
procedure SetNextState(wpn:pointer; status:cardinal); stdcall;

procedure SetZoomStatus(wpn:pointer; status:boolean); stdcall;
procedure SetZoomFactor(wpn:pointer; factor:single); stdcall;
function IsAimToggle():boolean; stdcall;

function virtual_Action(wpn:pointer; cmd:cardinal; flags:cardinal):boolean; stdcall;
function virtual_IKinematicsAnimated__LL_MotionID(IKinematicsAnimated:pointer; name:PChar):integer; stdcall;
procedure virtual_CHudItem_PlaySound(CHudItem:pointer; alias:PChar; position_ptr:pointer); stdcall;
procedure virtual_CHudItem_SwitchState(Weapon:pointer; state:cardinal); stdcall;
procedure virtual_CShootingObject_FireStart(Weapon:pointer); stdcall;

procedure virtual_CWeaponMagazined__UnloadMagazine(wpn:pointer; spawn_ammo:boolean);stdcall;
procedure virtual_CWeaponMagazined__ReloadMagazine(wpn:pointer);stdcall;
procedure virtual_CWeaponMagazined__OnEmptyClick(wpn:pointer);stdcall;
procedure virtual_CWeaponShotgun__AddCartridge(wpn:pointer; cnt:cardinal);stdcall;

function  CWeaponShotgun__HaveCartridgeInInventory(wpn:pointer; cnt:cardinal):boolean; stdcall; //������ �������� � ��� ���������� ������

function CHudItem__HudItemData(CHudItem:pointer):{attachable_hud_item*}pointer; stdcall;
function CHudItem__GetHUDMode(CHudItem:pointer):boolean; stdcall;

procedure CHudItem__PlayHUDMotion(wpn: pointer; anim_name:PChar; bMixIn:boolean; state:cardinal); stdcall;

procedure SetHandsPosOffset(attachable_hud_item:pointer; v:pFVector3);
procedure SetHandsRotOffset(attachable_hud_item:pointer; v:pFVector3);

function GetHandsPosOffset(attachable_hud_item:pointer):FVector3;
function GetHandsRotOffset(attachable_hud_item:pointer):FVector3;

procedure attachable_hud_item__GetBoneOffsetPosDir(this:pointer; bone:PChar;dest_pos:pFVector3; dest_dir:pFVector3; bone_offset:pFVector3);stdcall;

procedure CShootingObject__UpdateParticles(wpn:pointer; CParticlesObject:pointer; pos:pFVector3; vel:pFVector3);stdcall;
procedure CShootingObject__StartParticles(wpn:pointer; CParticlesObject:pointer; particles_name:PChar; pos:pFVector3; vel:pFVector3; auto_remove_flag:boolean);stdcall;
procedure CShootingObject__StopParticles(wpn:pointer; CParticlesObject:pointer); stdcall;
procedure SetParticlesHudStatus(CParticlesObject:pointer; status:boolean); stdcall;

function GetLastFP(wpn:pointer):FVector3;
function GetLastFD(wpn:pointer):FVector3;
function GetXFORM(wpn:pointer):pFMatrix4x4;stdcall;

procedure SetWorkingState(wpn:pointer; state:boolean); stdcall;

procedure AllowWeaponInertion(wpn:pointer; status:boolean);stdcall;

function IsPending(wpn:pointer):boolean; stdcall;
procedure StartPending(wpn:pointer); stdcall;
procedure EndPending(wpn:pointer); stdcall;

function GetSoundCollection(wpn:pointer):pHUD_SOUND_COLLECTION; stdcall;
function PlaySoundByAnimName(wpn:pointer; anm:string):boolean;

function IsGrenadeMode(wpn:pointer):boolean; stdcall;
procedure PerformSwitchGL(wpn:pointer); stdcall;

function HasDifferentFireModes(wpn:pointer):boolean; stdcall;

function SetQueueFired(wpn:pointer; status:boolean):cardinal; stdcall;

function HasBinocularVision(wpn:pointer):boolean; stdcall;
function GetHudFlags():cardinal; stdcall;

function GetWeaponZoomUI(wpn:pointer):pCUIWindow; stdcall;
function IsWeaponNightVisionPPExist(wpn:pointer):boolean; stdcall;

const
  OFFSET_PARTICLE_WEAPON_CURFLAME:cardinal = $42C;
  OFFSET_PARTICLE_WEAPON_CURSHELLS:cardinal = $410;
  OFFSET_PARTICLE_WEAPON_CURSMOKE:cardinal = $438;

  ANM_TIME_START:cardinal=$304;
  ANM_TIME_CUR:cardinal=$300;
  ANM_TIME_END:cardinal=$308;

  EWeaponStates__eFire:cardinal = $5;
  EWeaponStates__eFire2:cardinal = $6;
  EWeaponStates__eReload:cardinal = $7;
  EWeaponStates__eMisfire:cardinal = $8;
  EWeaponStates__eMagEmpty:cardinal = $9;
  EWeaponStates__eSwitch:cardinal = $A;
  EHudStates__eIdle:cardinal = $0;
  EHudStates__eShowing:cardinal = $1;
  EHudStates__eHiding:cardinal = $2;
  EHudStates__eHidden:cardinal = $3;
  EHudStates__eBore:cardinal = $4;
  EHudStates__eLastBaseState:cardinal = $4;
  EMissileStates__eThrowStart:cardinal = $5;
  EMissileStates__eReady:cardinal = $6;
  EMissileStates__eThrow:cardinal = $7;
  EMissileStates__eThrowEnd:cardinal = $8;

  EWeaponSubStates__eSubStateReloadBegin:byte = $0;
  EWeaponSubStates__eSubStateReloadInProcess:byte = $1;
  EWeaponSubStates__eSubStateReloadEnd:byte = $2;
  
  ANM_LEFTHAND:string='anm_lefthand_';

  CWEAPON_SHELL_PARTICLES:cardinal=$410;
  CWEAPON_FLAME_PARTICLES_CURRENT:cardinal=$42C;  
  CWEAPON_FLAME_PARTICLES:cardinal=$430;
  CWEAPON_SMOKE_PARTICLES_CURRENT:cardinal=$438;  
  CWEAPON_SMOKE_PARTICLES:cardinal=$43C;

  HUD_DRAW:cardinal = 16;
  HUD_DRAW_RT:cardinal = 1024;
  HUD_WEAPON_RT2:cardinal = 2048;

//procedure SetCollimatorStatus(wpn:pointer; status:boolean); stdcall;


implementation
uses BaseGameData, gunsl_config, sysutils, ActorUtils, Misc, xr_BoneUtils, windows, dynamic_caster, xr_Cartridge, xr_strings;
var
  PlayHudAnim_Func:cardinal;
  _pps_HudFlags:pcardinal;


procedure SetHUDSection(wpn:pointer; new_hud_section:PChar); stdcall;
asm
    pushad
    pushfd
    mov edi, wpn
    //�������� ����� ������ � str_container
    push new_hud_section
    call str_container_dock
    test eax, eax
    je @finish
    mov ecx, [edi+$314]
    test ecx, ecx
    je @finish
    cmp eax, ecx
    je @finish
    //�������� ������� ������������� � ����� ������ ���� � �������� � ������
    add [eax], 1
    sub [ecx], 1
    //������� ����� ��� � ������
    mov [edi+$314], eax
    @finish:
    popfd
    popad
end;

procedure SetWpnVisual (wpn:pointer; name:pchar);stdcall;
//����� ������������� ��� ������
asm
    pushad
    pushfd

    add wpn, $000000E8
    push wpn
    call game_object_GetScriptGameObject
    mov ecx, eax
    push name

    mov eax, xrgame_addr
    add eax, $1BFF60
    call eax

    popfd
    popad
end;

procedure SetObjectVisual (obj:pointer; name:pchar);stdcall;
//����� ������������� ��� ������
asm
    pushad
    pushfd

    push obj
    call game_object_GetScriptGameObject
    mov ecx, eax
    push name

    mov eax, xrgame_addr
    add eax, $1BFF60
    call eax

    popfd
    popad
end;

procedure PlayCycle (obj:pointer; anim:PChar; mix_in:boolean);stdcall;
asm
    pushad
    pushfd

    add obj, $000000E8
    push obj
    call game_object_GetScriptGameObject

    movzx ebx, mix_in
    push ebx
    push anim
    mov ecx, eax
    mov eax, xrgame_addr
    add eax, $1c1ab0
    call eax         //CScriptGameObject::play_cycle

    popfd
    popad
end;

function GetInstalledUpgradeSection(wpn:pointer; index:cardinal):PChar; stdcall;
asm
    mov eax, wpn
    mov eax, [eax+$D8]
    mov ecx, index
    lea eax, [eax+4*ecx]
    mov eax, [eax]
    add eax, $10
    mov @result, eax;
end;

function GetInstalledUpgradesCount(wpn:pointer):cardinal; stdcall;
asm
    mov ecx, wpn
{    mov eax, [ecx+$DE]
    cmp eax, 0
    je @finish}
    mov eax, [ecx+$DC] //��������� ����� ������� ���������
    mov ecx, [ecx+$D8] //��������� ������ ������� ���������
    sub eax, ecx
    shr eax, 2
    mov @result, eax
    @finish:
end;

function FindBoolValueInUpgradesDef(wpn:pointer; key:PChar; def:boolean; scan_after_nodefault:boolean):boolean; stdcall;
var
  i:integer;
  str:PChar;
begin
  result:=def;
  for i:=0 to GetInstalledUpgradesCount(wpn)-1 do begin
    str:=GetInstalledUpgradeSection(wpn, i);
    str:=game_ini_read_string(str, 'section');
    if game_ini_line_exist(str, key) then begin
      result:=game_ini_r_bool(str, key);
      if (not scan_after_nodefault) and (result<>def) then exit;
    end;
  end;
end;

function FindStrValueInUpgradesDef(wpn:pointer; key:PChar; def:PChar):PChar; stdcall;
var
  i:integer;
  str:PChar;
begin
  for i:=0 to GetInstalledUpgradesCount(wpn)-1 do begin
    str:=GetInstalledUpgradeSection(wpn, i);
    str:=game_ini_read_string(str, 'section');
    if game_ini_line_exist(str, key) then begin
      result:=game_ini_read_string(str, key);
      if result<>def then exit;
    end;
  end;
  result:=def;
end;


function FindIntValueInUpgradesDef(wpn:pointer; key:PChar; def:integer):integer; stdcall;
var
  i:integer;
  str:PChar;
begin
  result:=def;
  for i:=0 to GetInstalledUpgradesCount(wpn)-1 do begin
    str:=GetInstalledUpgradeSection(wpn, i);
    str:=game_ini_read_string(str, 'section');
    if game_ini_line_exist(str, key) then begin
      result:=game_ini_r_int_def(str, key, def);
    end;
  end;

end;

function ModifyFloatUpgradedValue(wpn:pointer; key:PChar; def:single):single; stdcall;
var
  i:integer;
  str:PChar;
begin
  result:=def;
  for i:=0 to GetInstalledUpgradesCount(wpn)-1 do begin
    str:=GetInstalledUpgradeSection(wpn, i);
    str:=game_ini_read_string(str, 'section');
    if game_ini_line_exist(str, key) then begin
      result:=result+game_ini_r_single_def(str, key, 0);
    end;
  end;
end;

function GetAmmoInMagCount(wpn:pointer):cardinal; stdcall;
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
    mov edx, [ebx+$6CC]
    sub edx, [ebx+$6C8]
    jmp @divide

    @use_alter:
    mov edx, [ebx+$7F0]
    sub edx, [ebx+$7EC]
    jmp @divide

    @divide:
    movzx eax, dx
    shr edx, 16
    mov ebx, $3c;
    div bx

    mov @result, eax

    popfd
    popad
end;


function GetAmmoInGLCount(wpn:pointer):cardinal; stdcall;
var
  pstart, pend, gl_status:cardinal;
  ptr:pointer;
begin
  result:=0;

  if wpn = nil then exit;

  gl_status:=GetGLStatus(wpn);
  if (gl_status=0) or ((gl_status=2) and not IsGLAttached(wpn)) then exit;
  if IsGrenadeMode(wpn) then
    ptr:= PChar(wpn)+$6C8
  else
    ptr:= PChar(wpn)+$7EC;

  pstart:=(pcardinal(ptr))^;
  pend:=(pcardinal(PChar(ptr)+4))^;

  result:=(pend-pstart) div sizeof(CCartridge);
end;


procedure SetAmmoInGLCount(wpn:pointer; cnt:cardinal); stdcall;
//�������� ������ �� ����������!!!
var
  pstart, pend, gl_status:cardinal;
  ptr:pointer;
begin
  if wpn = nil then exit;

  gl_status:=GetGLStatus(wpn);
  if (gl_status=0) or ((gl_status=2) and not IsGLAttached(wpn)) then exit;
  if IsGrenadeMode(wpn) then
    ptr:= PChar(wpn)+$6C8
  else
    ptr:= PChar(wpn)+$7EC;

  pstart:=(pcardinal(ptr))^;
  pend:= pstart+cnt*sizeof(CCartridge);

  (pcardinal(PChar(ptr)+4))^:=pend;
end;

function IsAimNow(wpn:pointer):boolean; stdcall;
asm
  mov @result, 0
  pushad
    push 0
    push RTTI_CWeapon
    push RTTI_CHudItemObject
    push 0
    push wpn
    call dynamic_cast
    cmp eax, 0
    je @finish

    mov ecx, wpn
    mov al, [ecx+$496]
    mov @result, al
    
    @finish:
  popad
end;

function IsTriStateReload(wpn:pointer):boolean; stdcall;
asm
  mov @result, 0
  pushad
    push 0
    push RTTI_CWeapon
    push RTTI_CWeaponShotgun
    push 0
    push wpn
    call dynamic_cast
    cmp eax, 0
    je @finish

    mov ecx, wpn
    mov al, [ecx+$458]
    mov @result, al
    
    @finish:
  popad
end;

function GetOwner(wpn:pointer):pointer; stdcall;
asm
    mov eax, wpn
    mov eax, [eax+$19c]
    mov @result, eax
end;

function GetScopesCount(wpn:pointer):cardinal; stdcall;
asm
  pushad
    mov edi, wpn
    mov ebx, [edi+$6b4]
    sub ebx, [edi+$6b0]
    shr ebx, 2
    mov @result, ebx
  popad
end;

function GetCurrentScopeIndex(wpn:pointer):integer; stdcall;
asm
  pushad
    mov edi, wpn
    movzx eax, byte ptr [edi+$6bc]
    mov @result, eax
  popad
end;

function GetScopeSection(wpn:pointer; index:cardinal):PChar; stdcall;
asm
  pushad
    mov @result, 0
    mov edi, wpn
    mov eax, [edi+$6B0]

    mov ebx, index
    shl ebx, 2
    add eax, ebx

    cmp eax, [edi+$6B4]
    jae @finish

    mov eax, [eax]
    add eax, $10
    mov @result, eax

    @finish:
  popad
end;

function GetCurrentScopeSection(wpn:pointer):PChar; stdcall;
const
  FUNNAME:PChar = 'GetCurrentScopeSection';
  EXPR:PChar='Invalid scope idx';
  DEFAULT_SCOPE_SECT:PChar='';
asm
    pushad
    pushfd
    mov eax, DEFAULT_SCOPE_SECT
    mov @result, eax
    mov edi, wpn

    mov ebx, [edi+$6b0]
    mov edx, [edi+$6b4]
    cmp ebx, edx
    je @finish
    movzx eax, byte ptr [edi+$6bc]

    //��������, ����������� �� � �������� �������� (������ ������)
    sub edx, ebx
    shr edx, 2
    cmp eax, edx
    jnb @assert_gen

    mov ebx, [edi+$6b0]
    mov ebx, [4*eax+ebx]
    add ebx, $10
    mov @result, ebx
    jmp @finish

    @assert_gen:
    push FUNNAME
    push EXPR
    call DebugFail
    
    @finish:
    popfd
    popad
end;

function GetGLStatus_internal(wpn:pointer):cardinal; stdcall;
asm
    mov eax, wpn
    mov eax, [eax+$46c]
    mov @result, eax
end;

function GetGLStatus(wpn:pointer):cardinal; stdcall;
begin
  result:=0;
  if dynamic_cast(wpn, 0, RTTI_CHudItemObject, RTTI_CWeaponMagazinedWGrenade, false)=nil then exit;
  result:=GetGLStatus_internal(wpn);
end;

function GetSilencerStatus_internal(wpn:pointer):cardinal; stdcall;
asm
    mov eax, wpn
    mov eax, [eax+$468]
    mov @result, eax
end;

function GetSilencerStatus(wpn:pointer):cardinal; stdcall;
begin
  result:=0;
  if dynamic_cast(wpn, 0, RTTI_CHudItemObject, RTTI_CWeapon, false)=nil then exit;
  result:=GetSilencerStatus_internal(wpn);
end;

function GetScopeStatus_internal(wpn:pointer):cardinal; stdcall;
asm
    mov eax, wpn
    mov eax, [eax+$464]
    mov @result, eax
end;

function GetScopeStatus(wpn:pointer):cardinal; stdcall;
begin
  result:=0;
  if dynamic_cast(wpn, 0, RTTI_CHudItemObject, RTTI_CWeapon, false)=nil then exit;
  result:=GetScopeStatus_internal(wpn);
end;

function IsWeaponJammed(wpn:pointer):boolean; stdcall;
asm
    mov eax, wpn
    mov al, [eax+$45A]
    mov @result, al
end;

function CurrentQueueSize(wpn:pointer):integer; stdcall;
asm
    mov eax, wpn
    mov eax, [eax+$770]
    mov @result, eax
end;

function HasDifferentFireModes(wpn:pointer):boolean; stdcall;
asm
    mov eax, wpn
    mov al, byte ptr [eax+$79E]
    mov @result, al
end;

function QueueFiredCount(wpn:pointer):integer; stdcall;
asm
    mov eax, wpn
    mov eax, [eax+$774]
    mov @result, eax
end;

procedure SetQueueFiredCount(wpn:pointer; cnt:cardinal); stdcall;
asm
  pushad
    mov eax, wpn
    mov ecx, cnt
    mov [eax+$774], ecx
  popad
end;

function GetSection(wpn:pointer):PChar; stdcall;
asm
    mov eax, [wpn]
    mov eax, [eax+$90]
    add eax, $10
    mov @result, eax
end;

function GetID(wpn:pointer):word; stdcall;
asm
  mov eax, [wpn]
  movzx eax, word ptr [eax+$18c]
  mov @result, ax
end;

function GetWeaponVisualName(wpn:pointer):pchar; stdcall;
asm
  mov eax, [wpn]
  mov eax, dword ptr [eax+$198] // NameVisual from CObject parent class
  test eax, eax
  je @finish
  add eax, $10
  @finish:
  mov @result, eax
end;

function GetHUDSection(wpn:pointer):PChar; stdcall;
asm
    mov eax, wpn
    mov eax, [eax+$314]
    add eax, $10
    mov @result, eax
end;

function GetActualCurrentAnim(wpn:pointer):PChar; stdcall;
asm
    mov eax, wpn
    mov eax, [eax+$2FC]

    test eax, eax
    je @finish

    add eax, $10

    @finish:
    mov @result, eax
end;

function get_addons_state(wpn:pointer):cardinal; stdcall;
asm
  mov eax, wpn
  movzx eax, byte ptr [eax+$460]
  mov @result, eax
end;

procedure set_addons_state(wpn:pointer; state:cardinal); stdcall;
asm
  pushad
  mov eax, wpn
  mov ebx, state
  mov byte ptr [eax+$460], bl

  mov ecx, wpn
  mov eax, [ecx]
  mov eax, [eax+$158] //wpn->InitAddons
  call eax

  popad
end;

function IsScopeAttached(wpn:pointer):boolean; stdcall;
asm
    push wpn
    call get_addons_state
    test eax, 1
    jz @noaddon
    mov @result, 1
    jmp @finish
    @noaddon:
    mov @result, 0
    @finish:
end;

function IsSilencerAttached(wpn:pointer):boolean; stdcall;
asm
    push wpn
    call get_addons_state
    test eax, 4
    jz @noaddon
    mov @result, 1
    jmp @finish
    @noaddon:
    mov @result, 0
    @finish:
end;

function IsGLAttached(wpn:pointer):boolean; stdcall;
asm
    push wpn
    call get_addons_state
    test eax, 2
    jz @noaddon
    mov @result, 1
    jmp @finish
    @noaddon:
    mov @result, 0
    @finish:
end;

function IsGLEnabled(wpn:pointer):boolean; stdcall;
asm
    mov @result, 0
    mov eax, wpn
    cmp byte ptr [eax+$7F8], 0;
    je @finish
    mov @result, 1
    @finish:
end;

procedure SetGLEnabled(wpn:pointer; state:boolean); stdcall;
asm
    pushad
    mov eax, wpn
    mov bl, state
    mov byte ptr [eax+$7F8], bl;
    popad
end;

procedure SetWorkingState(wpn:pointer; state:boolean); stdcall;
asm
    pushad
    mov eax, wpn
    mov bl, state
    mov byte ptr [eax+$35a], bl;
    popad
end;

procedure PlayHudAnim(wpn: pointer; anim_name:PChar; bMixIn:boolean); stdcall;
asm
    pushad
    pushfd

    push anim_name
    call str_container_dock
    test eax, eax
    je @finish
//    add [eax], 1
    push eax
    mov eax, esp


    mov ebx, wpn
    lea ecx, [ebx+$2E0]

    push 0
    push 0
    movzx edx, bMixIn
    push edx              //������ �� ����� ������� � ���
    push eax              //��������� �� ��� �����
    call PlayHudAnim_Func

    pop eax

    @finish:
    popfd
    popad
end;

procedure CHudItem__PlayHUDMotion(wpn: pointer; anim_name:PChar; bMixIn:boolean; state:cardinal); stdcall;
asm
    pushad
    pushfd

    push anim_name
    call str_container_dock
    test eax, eax
    je @finish
//    add [eax], 1
    push eax
    mov eax, esp


    mov ebx, wpn
    lea ecx, [ebx+$2E0]

    push state
    push 0
    movzx edx, bMixIn
    push edx              //������ �� ����� ������� � ���
    push eax              //��������� �� ��� �����
    call PlayHudAnim_Func

    pop eax

    @finish:
    popfd
    popad
end;

function GetClassName(wpn:pointer):string; stdcall;
var i:cardinal;
    c:char;
begin
  result:='';
  for i:=7 downto 0 do begin
    asm
      push eax
      mov eax, wpn
      add eax, $F0
      add eax, i
      mov al, [eax]
      mov c, al
      pop eax
    end;
    result:=result+c;
  end;
  result:=trim(result);
end;

function WpnCanShoot(wpn:pointer):boolean;stdcall;
begin
//  result:=(cls='WP_AK74') or (cls='WP_LR300') or (cls='WP_BM16') or (cls='WP_PM') or (cls='WP_GROZA') or (cls='WP_SVD') or (cls='WP_HPSA') or (cls='WP_ASHTG') or (cls='WP_RG6') or (cls='WP_RPG7') or (cls='WP_VAL') or (cls='WP_SHOTG') or (cls='WP_SVU');
  result:=(dynamic_cast(wpn, 0, RTTI_CHudItemObject, RTTI_CWeaponMagazined, false)<>nil) and (dynamic_cast(wpn, 0, RTTI_CHudItemObject, RTTI_CWeaponBinoculars, false)=nil);
end;

function IsThrowable(wpn:pointer):boolean;stdcall;
begin
//  result:=(cls='G_F1_S') or (cls='G_RGD5_S') or (cls='II_BOLT');
  result:=(dynamic_cast(wpn, 0, RTTI_CHudItemObject, RTTI_CMissile, false)<>nil);
end;

function IsDetector(wpn:pointer):boolean;stdcall;
begin
  result:=(dynamic_cast(wpn, 0, RTTI_CHudItemObject, RTTI_CCustomDetector, false)<>nil);
end;

function IsBino(wpn:pointer):boolean;stdcall;
begin
//  result:=(cls='WP_BINOC');
  result:=(dynamic_cast(wpn, 0, RTTI_CHudItemObject, RTTI_CWeaponBinoculars, false)<>nil);
end;

function IsBM16(wpn:pointer):boolean;stdcall;
begin
  result:=(dynamic_cast(wpn, 0, RTTI_CHudItemObject, RTTI_CWeaponBM16, false)<>nil);
end;

function GetCurrentState(wpn:pointer):integer; stdcall;
asm
    mov eax, wpn
    mov eax, [eax+$2E4]
    mov @result, eax
end;

procedure SetCurrentState(wpn:pointer; status:cardinal); stdcall;
asm
    push eax
    push ecx

    mov eax, wpn
    mov ecx, status
    mov [eax+$2e4], ecx

    pop ecx
    pop eax
end;


procedure SetNextState(wpn:pointer; status:cardinal); stdcall;
asm
    push eax
    push ecx

    mov eax, wpn
    mov ecx, status
    mov [eax+$2e8], ecx

    pop ecx
    pop eax
end;

procedure SetZoomStatus(wpn:pointer; status:boolean); stdcall;
asm
    push eax
    push ecx

    mov eax, wpn
    mov cl, status
    mov byte ptr [eax+$496], cl

    pop ecx
    pop eax
end;

function GetNextState(wpn:pointer):integer; stdcall;
asm
    mov eax, wpn
    mov eax, [eax+$2E8]
    mov @result, eax
end;

procedure CHudItem_Play_Snd(itm:pointer; alias:PChar); stdcall;
asm
  pushad
  mov esi, itm


  push esi
  call GetPosition
  push eax

  push alias

  add esi, $2e0
  push esi          //CHudItem

  call virtual_CHudItem_PlaySound

  popad
end;

procedure CHudItem_StopAllSounds(itm:pointer); stdcall;
asm
pushad
  mov ecx, itm
  add ecx, $2e0 + $44 //m_sounds

  mov eax, xrGame_addr
  add eax, $2FA560 //HUD_SOUND_COLLECTION::StopAllSounds
  call eax
popad
end;

procedure PlayHudSoundEx(itm:pointer; alias:PAnsiChar; position:pFVector3; root_cobject:pointer; hud_mode:boolean; looped:boolean; index:byte); stdcall;
asm
  pushad

  movzx ecx, index
  push ecx

  movzx ecx, looped
  push ecx

  movzx ecx, hud_mode
  push ecx

  mov eax, root_cobject
  push eax //cobject

  mov ebx, position
  push ebx

  mov eax, alias
  push eax

  mov ecx, itm
  add ecx, $2e0 + $44 //m_sounds

  mov eax, xrGame_addr
  add eax, $2fa6c0 //HUD_SOUND_COLLECTION::PlaySound
  call eax

  popad
end;

////////////////////////////////////////////////////////////////////////////////

procedure DetachGLRight(wpn:pointer);stdcall;
//����� � ������ ��������� ���������� ���������
var addon_name:PChar;
begin
  addon_name:=GetGLSection(wpn);
  if addon_name = nil then begin;
    Log('WpnUtils.DetachGLRight: Weapon has no GL!', true);
    exit;
  end;
  asm
    pushad
      push addon_name
      call ActorUtils.CreateObjectToActor

      mov esi, wpn
      and [esi+$460], $FFFFFFFD
      cmp byte ptr [esi+$7f8], 0
      jne @active_gl

      mov ecx, esi
      mov eax, xrgame_addr
      add eax, $2d3740
      call eax                 //PerformSwitchGL [bug] ��� � CWeaponMagazinedWGrenade::Detach - ���� ������ ��� ������������ �� ��������� �� � ��������� �������� �������, �� �������� ������������ ��� ���������� �����      


      @active_gl:
      push 01
      push esi
      call virtual_CWeaponMagazined__UnloadMagazine


      mov ecx, esi
      mov eax, xrgame_addr
      add eax, $2d3740
      call eax                 //PerformSwitchGL


      mov ebx, xrgame_addr
      add ebx, $2BD930
      mov ecx, esi
      call ebx                  //call CWeapon::UpdateAddonsVisibility

      cmp [esi+$2E4], 0
      jne @finish
      mov eax, [esi+$2e0]
      mov edx, [eax+$60]
      lea ecx, [esi+$2e0]
      call edx
      @finish:
      popad
  end;
end;


procedure DetachAddon(wpn:pointer; addon_type:integer);stdcall;
var addon_name:PChar;
begin
  case addon_type of
    1:addon_name:=game_ini_read_string(GetCurrentScopeSection(wpn), 'scope_name');
    4:addon_name:=GetSilencerSection(wpn);
    2: begin
        DetachGLRight(wpn);
        exit;
       end;
  else
    Log('WpnUtils.DetachAddon: Invalid addon type!', true);
    exit;
  end;
  if addon_name = nil then exit;
  asm
    pushad
      push addon_name
      call ActorUtils.CreateObjectToActor

      mov esi, wpn
      mov eax, addon_type
      not eax
      and [esi+$460], eax


      mov ebx, xrgame_addr
      add ebx, $2BD930
      mov ecx, esi
      call ebx                  //call CWeapon::UpdateAddonsVisibility

      mov eax, [esi]
      mov edx, [eax+$158]
      mov ecx, esi
      call edx

      cmp addon_type, 1
      jne @finish
      mov byte ptr [esi+$6bc], 0

      @finish:
    popad
  end;
end;

////////////////////////////////////////////////////////////////////////////////

function GetSilencerSection(wpn:pointer):PChar; stdcall;
asm
    push eax

    mov @result, 0
    mov eax, wpn
    mov eax, [eax+$474]
    cmp eax, 0
    je @finish
    add eax, $10
    mov @result, eax
    
    @finish:
    pop eax
end;


function GetGLSection(wpn:pointer):PChar; stdcall;
asm
    push eax

    mov @result, 0
    mov eax, wpn
    mov eax, [eax+$478]
    cmp eax, 0
    je @finish
    add eax, $10
    mov @result, eax
                               
    @finish:
    pop eax
end;

procedure SetShootLockTime(wpn:pointer; time:single);stdcall;
asm
    push eax
    push eax
    movss [esp], xmm0

    mov eax, wpn
    movss xmm0, time
    movss [eax+$390], xmm0

    movss xmm0, [esp]
    add esp, 4
    pop eax
end;

function Init():boolean;
begin
  PlayHudAnim_Func:=xrGame_addr+$2F9A60;
  _pps_HudFlags:=pointer(xrEngine_addr+$90904);
  result:=true;
end;

procedure SetCurrentScopeType(wpn:pointer; scope_type:byte); stdcall;
asm
    push eax
    push ecx

    mov eax, wpn
    mov cl, scope_type
    mov byte ptr [eax+$6BC], cl

    pop ecx
    pop eax
end;

function GetShootLockTime(wpn:pointer):single;stdcall;
asm
    push eax
    push eax
    movss [esp], xmm0

    mov eax, wpn
    movss xmm0, [eax+$390]
    movss @result, xmm0

    movss xmm0, [esp]
    add esp, 4
    pop eax
end;


function GetOneShotTime(wpn:pointer):single;stdcall;
asm
    push eax
    push eax
    movss [esp], xmm0

    mov eax, wpn
    movss xmm0, [eax+$35c]
    movss @result, xmm0

    movss xmm0, [esp]
    add esp, 4
    pop eax
end;

function GetCurrentCondition(wpn:pointer):single; stdcall;
asm
    push eax
    movss [esp], xmm0

    mov eax, wpn
    movss xmm0, [eax+$AC]
    movss @result, xmm0

    movss xmm0, [esp]
    add esp, 4
end;

procedure SetCondition(wpn:pointer; cond:single); stdcall;
asm
  pushad
  mov eax, wpn
  mov ebx, cond
  mov [eax+$AC], ebx
  popad
end;

function GetLevelVertexID(wpn:pointer):cardinal; stdcall;
asm
  mov eax, wpn
  mov eax, [eax+$208]
  mov eax, [eax]
  mov @result, eax
end;

function GetGameVertexID(wpn:pointer):cardinal; stdcall;
asm
  mov eax, wpn
  mov eax, [eax+$208]
  movzx eax, word ptr [eax+4]
  mov @result, eax
end;

function GetPosition(wpn:pointer):pointer; stdcall;
asm
  mov eax, wpn
  add eax, $168
  mov @result, eax
end;

function GetOrientation(wpn:pointer):pointer; stdcall;
asm
  mov eax, wpn
  add eax, $158
  mov @result, eax
end;

function WpnIsDetector(wpn:pointer):boolean;stdcall;
begin
//  result:=(cls='DET_SIMP') or (cls='DET_ADVA') or (cls='DET_ELIT') or (cls='DET_SCIE');
  result:=(dynamic_cast(wpn, 0, RTTI_CHudItemObject, RTTI_CCustomDetector, false)<>nil)
end;

function IsKnife(wpn:pointer):boolean;stdcall;
begin
//  result:=(cls='WP_KNIFE');
  result:=(dynamic_cast(wpn, 0, RTTI_CHudItemObject, RTTI_CWeaponKnife, false)<>nil)
end;

procedure CSE_SetPosition(swpn:pointer; pos:pointer); stdcall;
asm
  push eax
  push ebx

  mov eax, swpn
  mov ebx, pos
  
  mov ecx, [ebx]
  mov [eax+$54], ecx

  mov ecx, [ebx+4]
  mov [eax+$58], ecx

  mov ecx, [ebx+8]
  mov [eax+$5C], ecx

  pop ebx
  pop eax
end;

procedure CSE_SetAngle(swpn:pointer; ang:pointer); stdcall;
asm
  push eax
  push ebx

  mov eax, swpn
  mov ebx, ang
  
  mov ecx, [ebx]
  mov [eax+$60], ecx

  mov ecx, [ebx+4]
  mov [eax+$64], ecx

  mov ecx, [ebx+8]
  mov [eax+$68], ecx

  pop ebx
  pop eax
end;

procedure SetCurrentParticles(wpn:pointer; name:PChar; part_type:cardinal); stdcall;
asm
  pushad
    push name
    call str_container_dock
    test eax, eax
    je @finish
    add [eax], 1

    mov ebx, wpn
    add ebx, part_type
    cmp [ebx], 0
    je @writenewparticle
      mov ecx, [ebx]
      sub [ecx], 1
    @writenewparticle:
    mov [ebx], eax

    @finish:
  popad

end;

function GetMagCapacityInCurrentWeaponMode_LL(wpn:pointer):integer; stdcall;
asm
  mov eax, wpn
  mov eax, [eax+$694]
  mov @result, eax
end;

function GetMagCapacityInCurrentWeaponMode(wpn:pointer):integer; stdcall;
var
  ammotype:integer;
  param:string;
  sect:PChar;
begin
  result:=GetMagCapacityInCurrentWeaponMode_LL(wpn);
  ammotype:=GetAmmoTypeToReload(wpn);
  param:='ammo_mag_size_for_type_'+inttostr(ammotype);
  sect:=GetSection(wpn);
  result:=game_ini_r_int_def(GetSection(wpn), PAnsiChar(param), result);
  result:=FindIntValueInUpgradesDef(wpn, PAnsiChar(param), result);
end;

procedure SetMagCapacityInCurrentWeaponMode(wpn:pointer; cnt:integer); stdcall;
asm
  push eax
  push ebx
    mov eax, wpn
    mov ebx, cnt
    mov [eax+$694], ebx
  pop ebx
  pop eax
end;

function GetCurrentAmmoCount(wpn:pointer):integer; stdcall;
asm
  mov eax, wpn
  mov eax, [eax+$690]
  mov @result, eax
end;

procedure SetCurrentAmmoCount(wpn:pointer; cnt:integer); stdcall;
asm
  pushad
  mov eax, wpn
  mov ebx, cnt
  mov [eax+$690], ebx
  popad
end;

procedure SetWeaponMisfireStatus(wpn:pointer; status:boolean); stdcall;
asm
  push eax
  push ebx

  mov eax, wpn
  mov bl, status
  mov byte ptr [eax+$45A], bl

  pop ebx
  pop eax
end;

procedure ForceWpnHudBriefUpdate(wpn:pointer); stdcall;
asm
    mov eax, wpn
    mov [eax+$69c], 0
end;

function virtual_Action(wpn:pointer; cmd:cardinal; flags:cardinal):boolean; stdcall;
asm
  pushad
    mov ecx, wpn
    mov eax, [ecx]
    mov eax, [eax+$64]
    push flags
    push cmd
    call eax
    mov @result, al
  popad
end;

function IsAimToggle():boolean; stdcall;
begin
asm
  mov eax, xrgame_addr
  add eax, $64ec5c
  movzx eax, byte ptr [eax]
  mov @result, al
end;
end;

procedure PlayAnimIdle(wpn: pointer); stdcall;
asm
  pushad
    mov ecx, wpn
    add ecx, $2e0
    mov eax, [ecx]
    mov edx, [eax+$60]
    call edx
  popad
end;


function GetCurrentMotionDef(wpn:pointer):pCMotionDef; stdcall;
asm
  pushad
    mov eax, wpn
    mov eax, [eax+$2F8]
    mov @result, eax
  popad
end;

function GetPlayerHud():pointer; stdcall;
begin
asm
  pushad
    mov eax, xrgame_addr
    mov eax, [eax+$64f0e4]
    mov @result, eax
  popad
end;
end;

function GetAttachableHudItem(index:cardinal):pointer; stdcall;
asm
  pushad
    call GetPlayerHud
    mov ebx, index
    mov eax, [eax+4*ebx+$94]
    mov @result, eax
  popad
end;

function GetCHudItemFromAttachableHudItem(ahi:pointer):pointer; stdcall;
asm
  mov @result, 0
  cmp ahi, 0
  je @finish
  pushad
    mov eax, ahi
    mov eax, [eax+$4]
    sub eax, $2e0
    mov @result, eax
  popad
  @finish:
end;

procedure player_hud__attach_item(wpn:pointer); stdcall;
asm
  pushad
  call GetPlayerHud
  mov ecx, eax
  mov eax, xrgame_addr
  add eax, $2ffcd0

  mov ebx, wpn
  add ebx, $2e0
  push ebx
  
  call eax;

  popad
end;

function GetAimFactor(wpn:pointer):single; stdcall;
asm
  push eax
  mov eax, wpn
  mov eax, [eax+$4A8]
  mov @result, eax
  pop eax
end;

procedure SetAimFactor(wpn:pointer; f:single); stdcall;
asm
  push eax
  push ebx
  mov eax, wpn
  mov ebx, f

  mov [eax+$4A8], ebx
  pop ebx
  pop eax
end;

function IsZoomHideCrosshair(wpn:pointer):boolean; stdcall;
asm
  mov eax, wpn
  mov al, [eax+$495] //m_zoom_params.m_bHideCrosshairInZoom
  mov @result, al
end;

{function CountOfCurrentAmmoInRuck(wpn:pointer):cardinal; stdcall;
begin
end;


function CountOfOtherAmmoInRuck(wpn:pointer):cardinal; stdcall;
begin
end;   }

function virtual_IKinematicsAnimated__LL_MotionID(IKinematicsAnimated:pointer; name:PChar):integer; stdcall;
asm
  cmp IKinematicsAnimated, 0
  je @null
    mov eax, IKinematicsAnimated
    mov eax, [eax]
    mov eax, [eax+$40]


  @null:
  mov @result, 0
  @finish:
end;


procedure SetSubState(wpn:pointer; substate:byte); stdcall;
asm
  push eax
  push ebx
  mov ebx, wpn
  cmp ebx, 0
  je @finish

  movzx eax, substate
  mov [ebx+$459], eax
  @finish:
  pop ebx
  pop eax
end;

function GetSubState(wpn:pointer):byte; stdcall;
asm
  mov eax, wpn
  mov al, byte ptr [eax+$459]
  mov @result, al
end;


procedure virtual_CHudItem_SwitchState(Weapon:pointer; state:cardinal); stdcall;
//��� ���������� ����� CHudItem �� �������� 2e0, ��� ��� ������ ����� �� ����.
asm
  pushad

  mov ecx, Weapon
  add ecx, $2e0

  push state

  mov edx, [ecx]
  mov edx, [edx]
  call edx

  popad
end;

procedure virtual_CShootingObject_FireStart(Weapon:pointer); stdcall;
asm
  pushad

  mov ecx, Weapon
  add ecx, $338

  mov edx, [ecx]
  mov edx, [edx+$18]
  call edx

  popad
end;

procedure virtual_CHudItem_PlaySound(CHudItem:pointer; alias:PChar; position_ptr:pointer); stdcall;
asm
  pushad

  mov ecx, CHudItem

  push position_ptr
  push alias


  mov edx, [ecx]
  mov edx, [edx+$30]
  call edx

  popad
end;

function  CWeaponShotgun__HaveCartridgeInInventory(wpn:pointer; cnt:cardinal):boolean; stdcall; //������ �������� � ��� ���������� ������
asm
  pushad

    push cnt
    mov ecx, wpn

    mov eax, xrgame_addr
    add eax, $2de7b0
    call eax
    mov @result, al
  popad
end;

procedure virtual_CWeaponShotgun__AddCartridge(wpn:pointer; cnt:cardinal);stdcall;
asm

    pushad
    pushfd


    push cnt
    mov ecx, wpn

    mov edx, [ecx]
    mov edx, [edx+$248]
    call edx

    popfd
    popad
end;

procedure virtual_CWeaponMagazined__UnloadMagazine(wpn:pointer; spawn_ammo:boolean);stdcall;
asm
    pushad
    pushfd

    movzx eax, spawn_ammo
    push eax

    mov ecx, wpn

    mov edx, [ecx]
    mov edx, [edx+$20c]
    call edx

    popfd
    popad
end;

procedure virtual_CWeaponMagazined__ReloadMagazine(wpn:pointer);stdcall;
asm

    pushad
    pushfd

    mov ecx, wpn

    mov edx, [ecx]
    mov edx, [edx+$1FC]
    call edx

    popfd
    popad
end;

procedure virtual_CWeaponMagazined__OnEmptyClick(wpn:pointer);stdcall;
asm
    pushad
    pushfd

    mov ecx, wpn

    mov edx, [ecx]
    mov edx, [edx+$1F4]
    call edx

    popfd
    popad
end;

function CHudItem__HudItemData(CHudItem:pointer):{attachable_hud_item*}pointer; stdcall;
asm
    pushad
    pushf

    add CHudItem, $2e0
    mov ecx, CHudItem

    mov eax, xrgame_addr
    add eax, $2F97A0
    call eax
    mov @result, eax

    popf
    popad
end;

function CHudItem__GetHUDMode(CHudItem:pointer):boolean; stdcall;
asm
  pushad
    mov eax, xrgame_addr
    add eax, $2F9C80
    mov ecx, CHudItem
    add ecx, $2e0
    call eax      //CHudItem::GetHUDMode
    mov @result, al
  popad
end;

function GetAnimTimeState(wpn:pointer; what:cardinal=$2FC):cardinal; stdcall;
asm
  mov eax, wpn
  add eax, what
  mov eax, [eax]
  mov @result, eax
end;

procedure attachable_hud_item__GetBoneOffsetPosDir(this:pointer; bone:PChar;dest_pos:pFVector3; dest_dir:pFVector3; bone_offset:pFVector3);stdcall;stdcall;
const
  f_one:single=1.0;
asm
  pushad
  push bone
  mov ecx, this
  push 0
  mov eax, xrgame_addr
  add eax, $2fd430
  call eax

  mov esi, this
  push [esi+$0C]
  call IKinematics__LL_BoneID
  cmp ax, $FFFF
  je @allbad

  mov edi, dest_pos
  mov esi, this
  movzx edx, ax
  mov eax,[esi+$0C] //mov eax, this->m_model
  mov ecx,[eax]
  push edx
  push eax
  mov eax,[ecx+$3C]
  call eax         //call this->m_model->LL_GetTransform(bone_id)

  //Fmatrix& fire_mat = this->m_model->LL_GetTransform(bone_id)
  //fire_mat.transform_tiny(dest_pos, offset);
  mov esi, bone_offset

  movss xmm0,[eax+$10]
  mulss xmm0,[esi+$04]
  movss xmm1,[eax+$20]
  mulss xmm1,[esi+$08]
  addss xmm0,xmm1
  movss xmm1,[esi+$00]
  mulss xmm1,[eax]
  addss xmm0,xmm1
  addss xmm0,[eax+$30]
  movss [edi+$00],xmm0

  movss xmm0,[eax+$14]
  mulss xmm0,[esi+$04]
  movss xmm1,[eax+$04]
  mulss xmm1,[esi+$00]
  addss xmm0,xmm1
  movss xmm1,[eax+$24]
  mulss xmm1,[esi+$08]
  addss xmm0,xmm1
  addss xmm0,[eax+$34]
  movss [edi+$04],xmm0

  movss xmm0,[eax+$18]
  mulss xmm0,[esi+$04]
  movss xmm1,[eax+$08]
  mulss xmm1,[esi+$00]
  addss xmm0,xmm1
  movss xmm1,[eax+$28]
  mulss xmm1,[esi+$08]
  addss xmm0,xmm1
  addss xmm0,[eax+$38]
  movss [edi+$08],xmm0

  //m_item_transform.transform_tiny(dest_pos);
  mov esi, this
  movss xmm4,[edi+$04]
  movss xmm1,[esi+$116]
  movss xmm5,[edi+$00]
  movss xmm2,[esi+$10A]
  movaps xmm3,xmm0
  movss xmm0,[esi+$106]
  mulss xmm1,xmm3
  mulss xmm0,xmm4
  addss xmm0,xmm1
  movss xmm1,[esi+$F6]
  mulss xmm1,xmm5
  mulss xmm2,xmm4
  addss xmm0,xmm1
  movss xmm1,[esi+$FA]
  addss xmm0,[esi+$126]
  mulss xmm1,xmm5
  addss xmm1,xmm2
  movss xmm2,[esi+$11A]
  mulss xmm2,xmm3
  addss xmm1,xmm2
  movss xmm2,[esi+$FE]
  addss xmm1,[esi+$12A]
  mulss xmm2,xmm5
  movss xmm5,[esi+$10E]
  mulss xmm5,xmm4
  movss xmm4,[esi+$11E]
  addss xmm2,xmm5
  mulss xmm4,xmm3
  addss xmm2,xmm4
  addss xmm2,[esi+$12E]
  movss [edi+$00],xmm0
  movss [edi+$04],xmm1
  movss [edi+$08],xmm2

  //dest_dir.set(0.f,0.f,1.f);
  mov edi, dest_dir
  movss xmm4,f_one
  xorps xmm0,xmm0
  movss [edi+$00],xmm0
  movss [edi+$04],xmm0
  movss [edi+$08],xmm4

  //m_item_transform.transform_dir(dest_dir);
  movss xmm1,[esi+$106]
  movss xmm2,[esi+$116]
  movaps xmm6,xmm0
  movaps xmm5,xmm4
  movaps xmm7,xmm0
  mulss xmm1,xmm6
  movss xmm3,[esi+$10A]
  mulss xmm2,xmm5
  addss xmm1,xmm2
  movss xmm2,[esi+$F6]
  mulss xmm2,xmm7
  mulss xmm3,xmm6
  addss xmm1,xmm2
  movss xmm2,[esi+$FA]
  mulss xmm2,xmm7
  addss xmm2,xmm3
  movss xmm3,[esi+$11A]
  mulss xmm3,xmm5
  addss xmm2,xmm3
  movss xmm3,[esi+$FE]
  mulss xmm3,xmm7
  movss xmm7,[esi+$10E]
  mulss xmm7,xmm6
  movss xmm6,[esi+$11E]
  movss [edi+$00],xmm1
  movss [edi+$04],xmm2
  addss xmm3,xmm7
  mulss xmm6,xmm5
  addss xmm3,xmm6
  movss [edi+$08],xmm3 
  jmp @finish

  @allbad:
  mov eax, dest_pos;
  mov [eax], 0
  mov [eax+4], 0
  mov [eax+8], 0

  mov eax, dest_dir;
  xorps xmm0,xmm0
  movss [eax], xmm0
  movss [eax+4], xmm0
  movss xmm0, f_one
  movss [eax+8], xmm0

  @finish:
  popad
end;

procedure CShootingObject__UpdateParticles(wpn:pointer; CParticlesObject:pointer; pos:pFVector3; vel:pFVector3);stdcall;
asm
  pushad
  push vel
  push pos
  push CParticlesObject
  mov ecx, wpn
  add ecx, $338
  mov eax, xrgame_addr
  add eax, $2bb5d0
  call eax
  popad
end;

procedure CShootingObject__StartParticles(wpn:pointer; CParticlesObject:pointer; particles_name:PChar; pos:pFVector3; vel:pFVector3; auto_remove_flag:boolean);stdcall;
asm
  pushad
  movzx eax, auto_remove_flag
  push eax
  push vel
  push pos
  push particles_name
  push CParticlesObject
  mov ecx, wpn
  add ecx, $338
  mov eax, xrgame_addr
  add eax, $2bbaa0
  call eax
  popad
end;

procedure CShootingObject__StopParticles(wpn:pointer; CParticlesObject:pointer); stdcall;
asm
  pushad
  push CParticlesObject
  mov ecx, wpn
  add ecx, $338
  mov eax, xrgame_addr
  add eax, $2BA610
  call eax
  popad
end;

procedure SetParticlesHudStatus(CParticlesObject:pointer; status:boolean); stdcall;
asm
  pushad
    mov edi, CParticlesObject
    mov eax, [edi+$80] //this->renderable.visual
    test eax, eax
    je @finish
    push eax
    mov eax, xrgame_addr
    add eax, $348590
    call eax          //cast to IParticleCustom
    add esp, 4
    test eax, eax
    je @finish

    mov ecx, eax
    mov edx, [eax]
    mov edx, [edx+$30]
    movzx eax, status
    push eax
    call edx
    @finish:
  popad
end;

procedure AllowWeaponInertion(wpn:pointer; status:boolean);stdcall;
asm
  pushad
    mov esi, wpn
    add esi, $2f4
    mov al, status
    cmp al, 0
    je @noinert
    or dword ptr [esi], $4
    jmp @finish
    @noinert:
    and dword ptr [esi], $FFFB
    @finish:
  popad
end;

function GetLastFP(wpn:pointer):FVector3;
begin
  wpn:=pointer(cardinal(wpn)+$5B1);
  result:=FVector3_copyfromengine(wpn);
end;
function GetLastFD(wpn:pointer):FVector3;
begin
  wpn:=pointer(cardinal(wpn)+$5C9);
  result:=FVector3_copyfromengine(wpn);
end;

function GetXFORM(wpn:pointer):pFMatrix4x4; stdcall;
asm
  mov eax, wpn
  add eax, $138
  mov @result, eax
end;

procedure ChangeParticles(wpn:pointer; name:PChar; particle_type:cardinal); stdcall;
asm
  pushad
  push name
  call str_container_dock

  mov ecx, wpn
  add ecx, particle_type

  mov edx, [ecx]
  cmp edx, 0
  je @addcnt
  sub [edx], 1

  @addcnt:
  cmp eax, 0
  je @dochange
  add [eax], 1

  @dochange:
  mov [ecx], eax
  
  @finish:
  popad
end;


procedure SetHandsPosOffset(attachable_hud_item:pointer; v:pFVector3);
var rb:cardinal;
begin
  writeprocessmemory(hndl, PChar(attachable_hud_item)+$9e, v, sizeof(FVector3), rb);
end;

procedure SetHandsRotOffset(attachable_hud_item:pointer; v:pFVector3);
var rb:cardinal;
begin
  writeprocessmemory(hndl, PChar(attachable_hud_item)+$AA, v, sizeof(FVector3), rb);
end;

function GetHandsPosOffset(attachable_hud_item:pointer):FVector3;
begin
  result:=FVector3_copyfromengine(PChar(attachable_hud_item)+$9e);
end;

function GetHandsRotOffset(attachable_hud_item:pointer):FVector3;
begin
  result:=FVector3_copyfromengine(PChar(attachable_hud_item)+$AA);
end;

procedure SetZoomFactor(wpn:pointer; factor:single); stdcall;
asm
  push eax
  push eax
  movss [esp], xmm0

  mov eax, wpn
  movss xmm0, factor

  movss [eax+$498], xmm0
  movss xmm0, [esp]
  add esp, 4
  pop eax
end;

function IsPending(wpn:pointer):boolean; stdcall;
asm
  push eax
  mov eax, wpn
  mov eax, [eax+$2F4]
  and eax, 1
  mov @result, al
  pop eax
end;

procedure StartPending(wpn:pointer); stdcall;
asm
  push eax
  mov eax, wpn
  or byte ptr [eax+$2F4], 1
  pop eax
end;

procedure EndPending(wpn:pointer); stdcall;
asm
  push eax
  mov eax, wpn
  and byte ptr [eax+$2F4], $FE
  pop eax
end;

function GetSoundCollection(wpn:pointer):pHUD_SOUND_COLLECTION; stdcall;
asm
  mov eax, wpn
  add eax, $324
  mov @result, eax
end;

function PlaySoundByAnimName(wpn:pointer; anm:string):boolean;
var
  hud_sect:PChar;
  snd_name:string;
  is_exclusive:cardinal;

  root_cobject:pointer;
  hud_mode:boolean;
  is_looped:boolean;
begin
  hud_sect:=GetHUDSection(wpn);
  snd_name:='snd_'+anm;
  if IsSoundPatchNeeded and game_ini_line_exist(hud_sect, PChar(snd_name)) then begin
    if game_ini_r_bool_def(hud_sect, PChar('snd_exclusive_'+anm), true) then
      is_exclusive:=1
    else
      is_exclusive:=0;
    HUD_SOUND_COLLECTION__LoadSound(GetSoundCollection(wpn), hud_sect, PChar(snd_name), PChar(snd_name), is_exclusive, game_ini_r_int_def(hud_sect, PChar('snd_type_'+anm), -1));

    hud_mode:=(CHudItem__HudItemData(wpn)<>nil) and (GetActorActiveItem()=wpn);
    is_looped:=game_ini_r_bool_def(hud_sect, PChar('snd_looped_'+anm), false);
    root_cobject:=GetOwner(wpn);
    if root_cobject=nil then begin
      root_cobject:=CastHudItemToCObject(wpn);
    end;

    PlayHudSoundEx(wpn, PChar(snd_name), GetPosition(wpn), root_cobject, hud_mode, is_looped, $FF);
    result:=true;
  end else begin
    result:=false;
  end;
end;

function IsGrenadeMode(wpn:pointer):boolean; stdcall;
var
  status:cardinal;
begin
  status:=GetGLStatus(wpn);
  result:=((status=1) or ( (status=2) and IsGLAttached(wpn))) and IsGLEnabled(wpn);
end;

procedure PerformSwitchGL(wpn:pointer); stdcall;
asm
  pushad
      mov ecx, wpn
      mov eax, xrgame_addr
      add eax, $2d3740
      call eax                 //PerformSwitchGL
  popad
end;

function SetQueueFired(wpn:pointer; status:boolean):cardinal; stdcall;
asm
  pushad
      movzx eax, status;
      mov ecx, wpn
      mov byte ptr [ecx+$79c], al
  popad
end;

function HasBinocularVision(wpn:pointer):boolean; stdcall;
asm
  mov eax, wpn
  mov eax, [eax+$4b8]
  cmp eax, 0
  je @finish
  mov eax, 1
  @finish:
end;

function GetHudFlags():cardinal; stdcall;
begin
  result:=_pps_HudFlags^;
end;

function GetWeaponZoomUI(wpn:pointer):pCUIWindow; stdcall;
asm
  mov eax, wpn
  mov eax, [eax+$4c4] // m_UIScope
  mov @result, eax
end;

function GetWeaponNightVisionPPName(wpn:pointer):pshared_str; stdcall;
asm
  mov eax, wpn
  lea eax, [eax+$4b0] // m_sUseZoomPostprocess
  mov @result, eax
end;

function IsWeaponNightVisionPPExist(wpn:pointer):boolean; stdcall;
asm
  mov eax, wpn
  mov eax, [eax+$4bc] // m_pNight_vision
  test eax, eax
  je @finish
  mov eax, 1
  @finish:
end;

procedure virtual_FireTrace(wpn:pointer; p:pFVector3; d:pFVector3); stdcall;
asm
  pushad
  push d
  push p
  mov ecx, wpn
  mov eax, [ecx]
  mov eax, [eax+$180]
  call eax
  popad
end;

function CSE_GetWpnState(swpn:pointer):byte; stdcall;
asm
  mov eax, swpn
  mov al, [eax+$1a1] // wpn_state
  mov @result, al
end;

procedure CSE_SetWpnState(swpn:pointer; s:byte); stdcall;
asm
  pushad
  mov eax, swpn
  mov cl, s
  mov [eax+$1a1], cl // wpn_state
  popad
end;

function CSE_GetAddonsFlags(swpn:pointer):byte; stdcall;
asm
  mov eax, swpn
  mov al, [eax+$1bc] // wpn_state
  mov @result, al
end;

procedure CSE_SetAddonsFlags(swpn:pointer; s:byte); stdcall;
asm
  pushad
  mov eax, swpn
  mov cl, s
  mov [eax+$1bc], cl // wpn_state
  popad
end;

end.
