unit HudItemUtils;

interface
function Init():boolean;

function GetPlayerHud():pointer; stdcall;
procedure player_hud__attach_item(wpn:pointer); stdcall;

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
function IsWeaponJammed(wpn:pointer):boolean; stdcall;
function CurrentQueueSize(wpn:pointer):integer; stdcall;
function GetInstalledUpgradesCount(wpn:pointer):cardinal; stdcall;
function GetInstalledUpgradeSection(wpn:pointer; index:cardinal):PChar; stdcall;
function GetSection(wpn:pointer):PChar; stdcall;
function GetID(wpn:pointer):word; stdcall;
function GetHUDSection(wpn:pointer):PChar; stdcall;
function GetScopeStatus(wpn:pointer):cardinal; stdcall;
function GetSilencerStatus(wpn:pointer):cardinal; stdcall;
function GetGLStatus(wpn:pointer):cardinal; stdcall;
function GetCurrentScopeSection(wpn:pointer):PChar; stdcall;
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

procedure SetSubState(wpn:pointer; substate:byte); stdcall;
function GetSubState(wpn:pointer):byte; stdcall;

{function CountOfCurrentAmmoInRuck(wpn:pointer):cardinal; stdcall;
function CountOfOtherAmmoInRuck(wpn:pointer):cardinal; stdcall;}

procedure SetCurrentState(wpn:pointer; status:cardinal); stdcall;
procedure SetNextState(wpn:pointer; status:cardinal); stdcall;

procedure SetZoomStatus(wpn:pointer; status:boolean); stdcall;
function IsAimToggle():boolean; stdcall;

function virtual_Action(wpn:pointer; cmd:cardinal; flags:cardinal):boolean; stdcall;
function virtual_IKinematicsAnimated__LL_MotionID(IKinematicsAnimated:pointer; name:PChar):integer; stdcall;
procedure virtual_CHudItem_PlaySound(CHudItem:pointer; alias:PChar; position_ptr:pointer); stdcall;
procedure virtual_CHudItem_SwitchState(Weapon:pointer; state:cardinal); stdcall;

procedure virtual_CWeaponMagazined__UnloadMagazine(wpn:pointer);stdcall;
procedure virtual_CWeaponMagazined__ReloadMagazine(wpn:pointer);stdcall;
procedure virtual_CWeaponShotgun__AddCartridge(wpn:pointer; cnt:cardinal);stdcall;
function  CWeaponShotgun__HaveCartridgeInInventory(wpn:pointer; cnt:cardinal):boolean; stdcall; //должно работать и для остального оружия

function CHudItem__HudItemData(CHudItem:pointer):{attachable_hud_item*}pointer; stdcall;

const
  OFFSET_PARTICLE_WEAPON_CURFLAME:cardinal = $42C;
  OFFSET_PARTICLE_WEAPON_CURSHELLS:cardinal = $410;
  OFFSET_PARTICLE_WEAPON_CURSMOKE:cardinal = $438;

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


//procedure SetCollimatorStatus(wpn:pointer; status:boolean); stdcall;


implementation
uses BaseGameData, gunsl_config, sysutils, ActorUtils, Misc;
var
  PlayHudAnim_Func:cardinal;


procedure SetHUDSection(wpn:pointer; new_hud_section:PChar); stdcall;
begin
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
begin
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
  end
end;

function GetInstalledUpgradeSection(wpn:pointer; index:cardinal):PChar; stdcall;
begin
  asm
    mov eax, wpn
    mov eax, [eax+$D8]
    mov ecx, index
    lea eax, [eax+4*ecx]
    mov eax, [eax]
    add eax, $10
    mov @result, eax;
  end;
end;

function GetInstalledUpgradesCount(wpn:pointer):cardinal; stdcall;
begin
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
end;

function GetAmmoInMagCount(wpn:pointer):cardinal; stdcall;
begin
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
end;

function IsAimNow(wpn:pointer):boolean; stdcall;
asm
    mov ecx, wpn
    mov al, [ecx+$496]
    mov @result, al
end;

function GetOwner(wpn:pointer):pointer; stdcall;
begin
  asm
    mov eax, wpn
    mov eax, [eax+$19c]
    mov @result, eax
  end;
end;

function GetCurrentScopeSection(wpn:pointer):PChar;
begin
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
end;

function GetGLStatus(wpn:pointer):cardinal; stdcall;
begin
  asm
    mov eax, wpn
    mov eax, [eax+$46c]
    mov @result, eax
  end;
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
  result:=(cls='WP_AK74') or (cls='WP_LR300') or (cls='WP_BM16') or (cls='WP_PM') or (cls='WP_GROZA') or (cls='WP_SVD') or (cls='WP_HPSA') or (cls='WP_ASHTG') or (cls='WP_RG6') or (cls='WP_RPG7') or (cls='WP_VAL') or (cls='WP_SHOTG');
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

end.
