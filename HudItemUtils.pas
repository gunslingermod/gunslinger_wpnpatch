unit HudItemUtils;

interface
uses MatVectors;

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
function IsScopeAttached(wpn:pointer):boolean; stdcall;
function IsSilencerAttached(wpn:pointer):boolean; stdcall;
function IsGLAttached(wpn:pointer):boolean; stdcall;
function IsGLEnabled(wpn:pointer):boolean; stdcall;       //перед вызовом - обязательно убедиться, что гранатомет на оружии вообще ЕСТЬ! Некоторые классы оружия не поддерживают гранатомет, и тогда функция может возвратить мусор или даже сгенерировать вылет!
procedure SetGLEnabled(wpn:pointer; state:boolean); stdcall;
function IsWeaponJammed(wpn:pointer):boolean; stdcall;
function CurrentQueueSize(wpn:pointer):integer; stdcall;
function GetInstalledUpgradesCount(wpn:pointer):cardinal; stdcall;
function GetInstalledUpgradeSection(wpn:pointer; index:cardinal):PChar; stdcall;
function FindBoolValueInUpgradesDef(wpn:pointer; key:PChar; def:boolean):boolean; stdcall;
function GetSection(wpn:pointer):PChar; stdcall;
function GetID(wpn:pointer):word; stdcall;
function GetHUDSection(wpn:pointer):PChar; stdcall;
function GetScopeStatus(wpn:pointer):cardinal; stdcall;
function GetSilencerStatus(wpn:pointer):cardinal; stdcall;
function GetGLStatus(wpn:pointer):cardinal; stdcall;
function GetCurrentScopeSection(wpn:pointer):PChar; stdcall;
function GetScopesCount(wpn:pointer):cardinal; stdcall;
function GetCurrentScopeIndex(wpn:pointer):integer; stdcall;
function GetScopeSection(wpn:pointer; index:cardinal):PChar; stdcall;
procedure SetWpnVisual(obj:pointer; name:pchar);stdcall;
procedure SetHUDSection(wpn:pointer; new_hud_section:PChar); stdcall;
function GetAmmoInMagCount(wpn:pointer):cardinal; stdcall;
function GetCurrentAmmoCount(wpn:pointer):integer; stdcall;
function GetOwner(wpn:pointer):pointer; stdcall;
function IsAimNow(wpn:pointer):boolean; stdcall;
function GetAimFactor(wpn:pointer):single; stdcall;
procedure SetAimFactor(wpn:pointer; f:single); stdcall;
function GetClassName(wpn:pointer):string; stdcall;
function WpnCanShoot(cls:PChar):boolean;stdcall;
function WpnIsDetector(cls:PChar):boolean;stdcall;
function IsKnife(cls:PChar):boolean;stdcall;
function GetCurrentState(wpn:pointer):integer; stdcall;
procedure CHudItem_Play_Snd(itm:pointer; alias:PChar); stdcall;
function GetLevelVertexID(wpn:pointer):cardinal; stdcall
function GetGameVertexID(wpn:pointer):cardinal; stdcall
function GetSilencerSection(wpn:pointer):PChar; stdcall;
procedure DetachAddon(wpn:pointer; addon_type:integer);stdcall;
function GetGLSection(wpn:pointer):PChar; stdcall;
procedure SetShootLockTime(wpn:pointer; time:single);stdcall;
function GetShootLockTime(wpn:pointer):single;stdcall;
procedure SetCurrentScopeType(wpn:pointer; scope_type:byte); stdcall;
function GetCurrentCondition(wpn:pointer):single; stdcall;
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
function IsThrowable(cls:PChar):boolean;stdcall;
function IsBino(cls:PChar):boolean;stdcall;
procedure PlayCycle (obj:pointer; anim:PChar; mix_in:boolean);stdcall;
function QueueFiredCount(wpn:pointer):integer; stdcall;
function GetCurrentMotionDef(wpn:pointer):pointer; stdcall;

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

procedure virtual_CWeaponMagazined__UnloadMagazine(wpn:pointer);stdcall;
procedure virtual_CWeaponMagazined__ReloadMagazine(wpn:pointer);stdcall;
procedure virtual_CWeaponShotgun__AddCartridge(wpn:pointer; cnt:cardinal);stdcall;
function  CWeaponShotgun__HaveCartridgeInInventory(wpn:pointer; cnt:cardinal):boolean; stdcall; //должно работать и для остального оружия

function CHudItem__HudItemData(CHudItem:pointer):{attachable_hud_item*}pointer; stdcall;
function CHudItem__GetHUDMode(CHudItem:pointer):boolean; stdcall;

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

  CHUDState__eIdle:cardinal = 0;
	CHUDState__eShowing:cardinal = 1;
	CHUDState__eHiding:cardinal = 2;
	CHUDState__eHidden:cardinal = 3;
	CHUDState__eBore:cardinal = 4;
	CHUDState__eLastBaseState:cardinal = 4;


  EWeaponSubStates__eSubStateReloadBegin:byte = $0;
  EWeaponSubStates__eSubStateReloadInProcess:byte = $1;
  EWeaponSubStates__eSubStateReloadEnd:byte = $2;
  
  ANM_LEFTHAND:string='anm_lefthand_';

  CWEAPON_SHELL_PARTICLES:cardinal=$410;
  CWEAPON_FLAME_PARTICLES_CURRENT:cardinal=$42C;  
  CWEAPON_FLAME_PARTICLES:cardinal=$430;
  CWEAPON_SMOKE_PARTICLES_CURRENT:cardinal=$438;  
  CWEAPON_SMOKE_PARTICLES:cardinal=$43C;    


//procedure SetCollimatorStatus(wpn:pointer; status:boolean); stdcall;


implementation
uses BaseGameData, gunsl_config, sysutils, ActorUtils, Misc, xr_BoneUtils, windows, dynamic_caster;
var
  PlayHudAnim_Func:cardinal;


procedure SetHUDSection(wpn:pointer; new_hud_section:PChar); stdcall;
asm
    pushad
    pushfd
    mov edi, wpn
    //Поместим новую секцию в str_container
    push new_hud_section
    call str_container_dock
    test eax, eax
    je @finish
    mov ecx, [edi+$314]
    test ecx, ecx
    je @finish
    cmp eax, ecx
    je @finish
    //увеличим счетчик использования в новой строке худа и уменьшим в старой
    add [eax], 1
    sub [ecx], 1
    //Запишем новый худ в оружие
    mov [edi+$314], eax
    @finish:
    popfd
    popad
end;

procedure SetWpnVisual (obj:pointer; name:pchar);stdcall;
//Будем мимикрировать под скрипт
asm
    pushad
    pushfd

    add obj, $000000E8
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
    mov eax, [ecx+$DC] //Указатель конца массива апгрейдов
    mov ecx, [ecx+$D8] //Указатель начала массива апгрейдов
    sub eax, ecx
    shr eax, 2
    mov @result, eax
    @finish:
end;

function FindBoolValueInUpgradesDef(wpn:pointer; key:PChar; def:boolean):boolean; stdcall;
var
  i:integer;
  str:PChar;
begin
  for i:=0 to GetInstalledUpgradesCount(wpn)-1 do begin
    str:=GetInstalledUpgradeSection(wpn, i);
    str:=game_ini_read_string(str, 'section');
    if game_ini_line_exist(str, key) then begin
      result:=game_ini_r_bool(str, key);
      if result<>def then exit;
    end;
  end;
  result:=def;
end;

function GetAmmoInMagCount(wpn:pointer):cardinal; stdcall;
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
asm
    pushad
    pushfd
    mov @result, 0
    mov edi, wpn

    mov ebx, [edi+$6b0]
    cmp ebx, [edi+$6b4]
    je @finish    

    movzx eax, byte ptr [edi+$6bc]
    mov ebx, [edi+$6b0]
    mov ebx, [4*eax+ebx]
    add ebx, $10
    mov @result, ebx

    @finish:
    popfd
    popad
end;

function GetGLStatus(wpn:pointer):cardinal; stdcall;
asm
    mov eax, wpn
    mov eax, [eax+$46c]
    mov @result, eax
end;

function GetSilencerStatus(wpn:pointer):cardinal; stdcall;
asm
    mov eax, wpn
    mov eax, [eax+$468]
    mov @result, eax
end;

function GetScopeStatus(wpn:pointer):cardinal; stdcall;
asm
    mov eax, wpn
    mov eax, [eax+$464]
    mov @result, eax
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

function QueueFiredCount(wpn:pointer):integer; stdcall;
asm
    mov eax, wpn
    mov eax, [eax+$774]
    mov @result, eax
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

function IsScopeAttached(wpn:pointer):boolean; stdcall;
asm
    mov eax, wpn
    mov eax, [eax+$460]
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
    mov eax, wpn
    mov eax, [eax+$460]
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
    mov eax, wpn
    mov eax, [eax+$460]
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
    push edx              //резкий ли будет переход к ней
    push eax              //указатель на имя анимы
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

function WpnCanShoot(cls:PChar):boolean;stdcall;
begin
//  result:=not((cls='G_RGD5_S') or (cls='II_BOLT') or (cls='DET_SIMP') or (cls='DET_ADVA') or (cls = 'DET_ELIT') or (cls = 'G_F1_S') or (cls = 'DET_ELIT') or (cls = 'WP_BINOC') or (cls = 'WP_KNIFE') or (cls = 'ARTEFACT') or (cls='D_FLARE'));
  result:=(cls='WP_AK74') or (cls='WP_LR300') or (cls='WP_BM16') or (cls='WP_PM') or (cls='WP_GROZA') or (cls='WP_SVD') or (cls='WP_HPSA') or (cls='WP_ASHTG') or (cls='WP_RG6') or (cls='WP_RPG7') or (cls='WP_VAL') or (cls='WP_SHOTG') or (cls='WP_SVU');
end;

function IsThrowable(cls:PChar):boolean;stdcall;
begin
  result:=(cls='G_F1_S') or (cls='G_RGD5_S') or (cls='II_BOLT');
end;

function IsBino(cls:PChar):boolean;stdcall;
begin
  result:=(cls='WP_BINOC');
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
begin
  asm
    mov eax, wpn
    mov eax, [eax+$2E8]
    mov @result, eax
  end
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

////////////////////////////////////////////////////////////////////////////////

procedure DetachGLRight(wpn:pointer);stdcall;
//детач с учетом возможной активности подствола
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
      je @noactive_gl
      mov eax, [esi]
      mov edx, [eax+$20c]
      push 01
      mov ecx, esi
      call edx

      mov ecx, esi
      mov eax, xrgame_addr
      add eax, $2d3740
      call eax

      @noactive_gl:
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
begin
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
end;


function GetGLSection(wpn:pointer):PChar; stdcall;
begin
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
  result:=true;
end;

procedure SetCurrentScopeType(wpn:pointer; scope_type:byte); stdcall;
begin
  asm
    push eax
    push ecx

    mov eax, wpn
    mov cl, scope_type
    mov byte ptr [eax+$6BC], cl

    pop ecx
    pop eax
  end;
end;

function GetShootLockTime(wpn:pointer):single;stdcall;
begin
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

function GetLevelVertexID(wpn:pointer):cardinal; stdcall
asm
  mov eax, wpn
  mov eax, [eax+$208]
  mov eax, [eax]
  mov @result, eax
end;

function GetGameVertexID(wpn:pointer):cardinal; stdcall
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

function WpnIsDetector(cls:PChar):boolean;stdcall;
begin
  result:=(cls='DET_SIMP') or (cls='DET_ADVA') or (cls='DET_ELIT') or (cls='DET_SCIE');
end;

function IsKnife(cls:PChar):boolean;stdcall;
begin
  result:=(cls='WP_KNIFE');
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

function GetMagCapacityInCurrentWeaponMode(wpn:pointer):integer; stdcall;
asm
  mov eax, wpn
  mov eax, [eax+$694]
  mov @result, eax
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
begin
  asm
    mov eax, wpn
    mov [eax+$69c], 0
  end;
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
asm
  mov eax, xrgame_addr
  add eax, $64ec5c
  movzx eax, byte ptr [eax]
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


function GetCurrentMotionDef(wpn:pointer):pointer; stdcall;
asm
  pushad
    mov eax, wpn
    mov eax, [eax+$2F8]
    mov @result, eax
  popad
end;

function GetPlayerHud():pointer; stdcall;
asm
  pushad
    mov eax, xrgame_addr
    mov eax, [eax+$64f0e4]
    mov @result, eax
  popad
end;

function GetAttachableHudItem(index:cardinal):pointer; stdcall;
asm
  pushad
    call GetPlayerHud
    mov ebx, index
    mov eax, [eax+$94+4*ebx]
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
//все наследники имеют CHudItem по смещению 2e0, так что делаем сразу на всех.
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

function  CWeaponShotgun__HaveCartridgeInInventory(wpn:pointer; cnt:cardinal):boolean; stdcall; //должно работать и для остального оружия
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

procedure virtual_CWeaponMagazined__UnloadMagazine(wpn:pointer);stdcall;
begin
  asm
    pushad
    pushfd

    push 01
    mov ecx, wpn

    mov edx, [ecx]
    mov edx, [edx+$20c]
    call edx

    popfd
    popad
  end;
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
    mov edi, ecx
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

end.
