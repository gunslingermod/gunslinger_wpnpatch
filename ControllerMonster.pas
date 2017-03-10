unit ControllerMonster;

interface

function Init():boolean; stdcall;
function IsActorControlled():boolean; stdcall;
function IsActorSuicideNow():boolean; stdcall;
function IsSuicideAnimPlaying(wpn:pointer):boolean; stdcall;
function IsActorPlanningSuicide():boolean; stdcall;
function IsSuicideInreversible():boolean; stdcall;
function IsKnifeSuicideExit():boolean; stdcall;
function SetExitKnifeSuicide(status:boolean):boolean; stdcall;  //установить флаг необходимости проиграть аниму выхода из суицида ножом
procedure ResetActorControl(); stdcall;
procedure Update(dt:cardinal); stdcall;
procedure DoSuicideShot(); stdcall;
function CanUseItemForSuicide(wpn:pointer):boolean;
function GetCurrentSuicideWalkKoef():single;


implementation
uses BaseGameData, ActorUtils, HudItemUtils, WeaponAdditionalBuffer, DetectorUtils, gunsl_config, math, sysutils, uiutils, Level, MatVectors;

var
  _controlled_time_remains:cardinal;
  _suicide_now:boolean;
  _planning_suicide:boolean;
  _lastshot_done_time:cardinal;
  _death_action_started:boolean;
  _inventory_disabled_set:boolean;
  _knife_suicide_exit:boolean;

function IsPsiBlocked(act:pointer):boolean;
asm
  mov @result, 0
  pushad
    mov eax, act
    mov eax, [eax+$26C]
    mov eax, [eax+$E4]

    cmp eax, 0
    je @finish
    mov @result, 1

    @finish:
  popad
end;

function GetCurrentSuicideWalkKoef():single;
var
  itm:pointer;
begin
  result:=1.0;
  if IsActorControlled() or IsActorSuicideNow() then begin
    result:=GetControlledActorSpeedKoef();
    exit;
  end;

  itm:=GetActorActiveItem();
  if (itm<>nil) and IsSuicideAnimPlaying(itm) then begin
    result:=GetControlledActorSpeedKoef();
    exit;
  end;
end;

function IsActorControlled():boolean;stdcall;
begin
  result:=_controlled_time_remains>0
end;

function IsSuicideAnimPlaying(wpn:pointer):boolean; stdcall;
var
  anm:PChar;
begin
  anm:=GetActualCurrentAnim(wpn);
  result:=(anm='anm_prepare_suicide') or (anm='anm_suicide');
end;

function IsActorSuicideNow():boolean; stdcall;
begin
  result:=_suicide_now;
end;

function IsActorPlanningSuicide():boolean; stdcall;
begin
  result:=_planning_suicide;
end;

procedure ResetActorControl(); stdcall;
begin
  _controlled_time_remains:=0;
  _suicide_now:=false;
  _lastshot_done_time:=0;
  _planning_suicide:=false;
  _death_action_started:=false;
  _knife_suicide_exit:=false;
end;

function IsSuicideInreversible():boolean; stdcall;
begin
  result:=(_lastshot_done_time>0) or _death_action_started;
end;

function CanUseItemForSuicide(wpn:pointer):boolean;
begin
  result:= (wpn<>nil) and (IsKnife(PChar(GetClassName(wpn))) or ( WpnCanShoot(PChar(GetClassName(wpn))) and not (IsWeaponJammed(wpn)) and not (GetAmmoInMagCount(wpn)=0))) and not game_ini_r_bool_def(GetHUDSection(wpn), 'prohibit_suicide', false);
end;

procedure Update(dt:cardinal); stdcall;
var
  wpn, act, det:pointer;
  last_contr_time:cardinal;
begin
  act:=GetActor();
  wpn:=GetActorActiveItem();
  if act<>nil then det:=GetActiveDetector(act) else det:=nil;

  last_contr_time:=_controlled_time_remains;
  if _controlled_time_remains>dt then _controlled_time_remains:=_controlled_time_remains-dt else _controlled_time_remains:=0;
  if (_controlled_time_remains=0) and (_lastshot_done_time=0) and not _death_action_started then begin
    if _inventory_disabled_set then begin
      CActor__set_inventory_disabled(act, false);
      _inventory_disabled_set:=false;
    end;

    if last_contr_time>0 then SetHandsJitterTime(GetShockTime());
    ResetActorControl();
  end else if (wpn<>nil) and IsKnife(PChar(GetClassName(wpn))) then begin
    if _planning_suicide and (GetActualCurrentAnim(wpn)='anm_prepare_suicide') then begin
      _suicide_now:=true;
    end else if _suicide_now and (GetActualCurrentAnim(wpn)='anm_selfkill') then begin
      _death_action_started:=true;
    end;
  end else if _lastshot_done_time>0 then begin
    if (act<>nil) then begin
      SetActorActionState(act, actMovingForward, false, mState_WISHFUL);
      SetActorActionState(act, actMovingBack, false, mState_WISHFUL);
      SetActorActionState(act, actMovingLeft, false, mState_WISHFUL);
      SetActorActionState(act, actMovingRight, false, mState_WISHFUL);
    end;
    if (wpn=nil) or (GetTimeDeltaSafe(_lastshot_done_time, GetGameTickCount()) > floor(1000*game_ini_r_single_def(GetHUDSection(wpn), 'suicide_delay', 0.1))) then begin
      CActor__Die(act, act);
      _lastshot_done_time:=0;
    end;
  end;

  if (act<>nil) and (_controlled_time_remains>0)  then begin
    if (det<>nil) then begin
      if (GetCurrentState(det)<>EHudStates__eHiding) and (GetCurrentState(det)<>EHudStates__eHidden) then virtual_CHudItem_SwitchState(det, EHudStates__eHiding);
    end;

    if (wpn<>nil) and (WpnCanShoot(PChar(GetClassName(wpn))) or IsBino(PChar(GetClassName(wpn)))) and (IsAimNow(wpn)) then begin
      SetActorKeyRepeatFlag(kfUNZOOM, true, true);
    end;

    if (wpn<>nil) and IsThrowable(PChar(GetClassName(wpn))) and CanUseItemForSuicide(ItemInSlot(act, 1)) then begin
      _planning_suicide:=true;
      ActivateActorSlot__CInventory(1, false);
    end else begin
      _planning_suicide:=CanUseItemForSuicide(wpn);
      if (GetActorActiveSlot()<>0) and not _planning_suicide then begin
        if (GetCurrentDifficulty()>=gd_veteran) and CanUseItemForSuicide(ItemInSlot(act, 1)) then begin
          ActivateActorSlot__CInventory(1, false);
          _planning_suicide:=true;
        end else begin
          ActivateActorSlot__CInventory(0, false);
        end;
      end else if (wpn=nil) and (GetCurrentDifficulty()>=gd_master) and CanUseItemForSuicide(ItemInSlot(act, 1)) then begin
        _planning_suicide:=true;
        ActivateActorSlot__CInventory(1, false);
      end;
    end;
  end;  
end;

procedure DoSuicideShot(); stdcall;
var
  wpn:pointer;
begin
  wpn:=GetActorActiveItem();
  if (wpn=nil) then exit;
  if (_lastshot_done_time>0) then begin
    exit;
  end;

  SetDisableInputStatus(true);
  _lastshot_done_time:=GetGameTickCount();
  _death_action_started:=true;
//  virtual_CHudItem_SwitchState(wpn, EWeaponStates__eFire);
  virtual_CShootingObject_FireStart(wpn);
end;


procedure OnSuicideAnimEnd(wpn:pointer; param:integer);stdcall;
begin

  if (wpn<>GetActorActiveItem()) then exit;
  if not IsPsiBlocked(GetActor()) and (_suicide_now or _planning_suicide) then begin
    DoSuicideShot();
  end else begin
    _suicide_now:=false;
    _planning_suicide:=false;
    WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_stop_suicide', 'sndStopSuicide');
    SetHandsJitterTime(GetShockTime());
  end;
end;

function PsiEffects():boolean; stdcall;
var
  act, det, wpn:pointer;
  buf:WpnBuf;
begin
  //true в результате означает, что мы использовали кастомный эффект и обычную атаку играть не надо
  result:=true;

  act:=GetActor();
  if GetActor=nil then exit;
  //Если активен бустер псиблокады, то суицид не делаем
  if IsPsiBlocked(act) and not IsActorSuicideNow() and not IsSuicideInreversible() then begin
    result:=false;
    _planning_suicide:=false;
    _suicide_now:=false;
    SetHandsJitterTime(GetControllerBlockedTime());
    exit;
  end;

  _controlled_time_remains:=GetControllerTime();

  det:=GetActiveDetector(act);
  wpn:=GetActorActiveItem();

  if (det<>nil) or ((wpn<>nil) and not CanUseItemForSuicide(wpn)) then begin
    _planning_suicide:=CanUseItemForSuicide(wpn);
    _suicide_now:=false;
    result:=not ((GetCurrentState(wpn)=EHudStates__eHidden) or (GetCurrentState(wpn)=EHudStates__eHiding));
    exit;
  end;

  if (wpn=nil) then begin
    if (GetCurrentDifficulty()>=gd_master) and CanUseItemForSuicide(ItemInSlot(act, 1)) then begin
      _planning_suicide:=true;
       result:=true;
    end else begin
      _planning_suicide:=false;
      result:=false;
    end;

    _suicide_now:=false;
    exit;
  end;  

  //Если в руках сейчас нож - режемся им
  if IsKnife(PChar(GetClassName(wpn))) then begin
    _controlled_time_remains:=floor(game_ini_r_single_def(GetHUDSection(wpn), 'controller_time', _controlled_time_remains/1000)*1000);
    _planning_suicide:=true;
    //если до сих пор анима суицида не стартовала - форсируем событие
    if not _suicide_now and ((GetCurrentState(wpn)<>EWeaponStates__eFire) or (GetCurrentState(wpn)<>EWeaponStates__eFire2)) then virtual_CHudItem_SwitchState(wpn, EWeaponStates__eFire);
    exit;
  end;


  buf:=GetBuffer(wpn);

  //а теперь займемся стреляющим оружием

  if ((GetGLStatus(wpn)=1) or IsGLAttached(wpn)) and IsGLEnabled(wpn) and CanStartAction(wpn) then begin
    virtual_CHudItem_SwitchState(wpn, EWeaponStates__eSwitch);
    _planning_suicide:=true;
    _suicide_now:=false;
    exit;
  end;

  _planning_suicide:=false; //хак - чтобы функция определения возможности действия не учитывала это
  _suicide_now:=false;

  if game_ini_r_bool_def(GetHUDSection(wpn), 'suicide_by_animation', false) then begin
    _suicide_now:=IsSuicideAnimPlaying(wpn) or (_lastshot_done_time>0);
    if not _suicide_now then _suicide_now:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_suicide', 'sndSuicide', OnSuicideAnimEnd);
    if _suicide_now then _controlled_time_remains:=floor(game_ini_r_single_def(GetHUDSection(wpn), 'controller_time', _controlled_time_remains/1000)*1000);
    _planning_suicide:=true;
  end else begin
    if CanStartAction(wpn) then begin
      _suicide_now:=true;
      _controlled_time_remains:=floor(game_ini_r_single_def(GetHUDSection(wpn), 'controller_time', _controlled_time_remains/1000)*1000);
    end;
    if GetCurrentState(wpn)=EWeaponStates__eFire then SetWorkingState(wpn, false);
    _planning_suicide:=true;
  end;
end;

function PsiStart():boolean; stdcall;
var
  wpn, act:pointer;
  scream:string;
  v, va:FVector3;
  i,j:cardinal;
  radius:single;
  p:phantoms_params;
begin
  result:=PsiEffects;
  act:=GetActor();
  if (act<>nil) and not CActor__get_inventory_disabled(act) then begin
    HideShownDialogs();
    CActor__set_inventory_disabled(act, true);
    _inventory_disabled_set:=true;
  end;
  if result then begin
    wpn:=GetActorActiveItem();
    if (wpn<>nil) and not game_ini_r_bool_def(GetHUDSection(wpn), 'suicide_by_animation', false) and (IsKnife(PChar(GetClassName(wpn))) or WpnCanShoot(PChar(GetClassName(wpn)))) then begin
      scream:='sndScream'+inttostr(random(3)+1);
      CHudItem_Play_Snd(wpn, PChar(scream));
    end;
  end;

  //фантомчики
  if GetCurrentDifficulty()>=gd_stalker then begin
    p:=GetControllerPhantomsParams();
    i:=random(p.max_cnt-p.min_cnt)+p.min_cnt;
    va:=FVector3_copyfromengine(CRenderDevice__GetCamPos());

    for j:=1 to i do begin
      v.x:=random(1000)-500;
      v.y:=random(200);
      v.z:=random(1000)-500;
      radius:= ((p.max_radius-p.min_radius)*random(1000)/1000)+p.min_radius;
      v_setlength(@v, radius);
      v_add(@v, @va);
      spawn_phantom(@v);
    end;
  end;
end;

function IsNeedPsiHitOverride():boolean;
begin
  //вызывается, если контролер решил не бить актора пси-ударом по причине малой дистанции
  //при возвращении true он меняет свое решение...
  result:=(GetActorActiveItem()<>nil);
end;

procedure CControllerPsyHit__check_start_conditions_distance_patch(); stdcall;
asm
jna @std_psihit //уже решили наносить телепатический удар
  pushad
    call IsNeedPsiHitOverride
    cmp al, 0
  popad
  jne @std_psihit
  xor eax, eax
  pop esi
  ret

@std_psihit:
  mov al, 1
  pop esi
  ret
end;


procedure CControllerPsyHit__check_conditions_final_distance_patch(); stdcall;
asm
jna @std_psihit //уже решили наносить телепатический удар
  pushad
    call IsNeedPsiHitOverride
    cmp al, 0
  popad
  jne @std_psihit
  xor eax, eax
  pop esi
  ret

@std_psihit:
  mov ecx, esi
  pop esi
  mov eax, xrgame_addr
  add eax, $131250 //CControllerPsyHit::see_enemy
  jmp eax
end;

procedure CControllerPsyHit__death_glide_start_Patch; stdcall;
asm
  mov eax, xrgame_addr
  add eax, $131270
  call eax //CControllerPsyHit::check_conditions_final
  je @finish
  pushad
    call PsiStart
    cmp al, 1
  popad
  @finish:
end;


function NeedContinueSoundPlayingOnIndependent(wpn:pointer):boolean; stdcall;
begin
  result:= (GetActor()<>nil) and (GetActor()=GetOwner(wpn)) and (IsSuicideInreversible());// and IsActorSuicideNow();
end;

procedure CHudItem__OnH_B_Independent_Patch_Sound; stdcall;
//показывает, будет ли звук продолжвать играться после обретения независимости оружием, или нет
asm
  pushad
    sub esi, $2e0
    push esi
    call NeedContinueSoundPlayingOnIndependent
    cmp al, 1
  popad
  je @finish
  mov eax, xrgame_addr
  add eax, $2FA560
  call eax
  @finish:
end;

function IsKnifeSuicideExit():boolean; stdcall;
begin
  result:=_knife_suicide_exit;
end;

function SetExitKnifeSuicide(status:boolean):boolean; stdcall;
begin
  _knife_suicide_exit:=status;
end;


function Init():boolean; stdcall;
var
  addr:cardinal;
begin
  result:=false;

  addr:=xrgame_addr+$131A3D;
  if not WriteJump(addr, cardinal(@CControllerPsyHit__death_glide_start_Patch), 7, true) then exit;

  addr:=xrgame_addr+$1314A5;
  if not WriteJump(addr, cardinal(@CControllerPsyHit__check_start_conditions_distance_patch), 6, false) then exit;
  addr:=xrgame_addr+$12A6C6;
  if not WriteJump(addr, cardinal(@CControllerPsyHit__check_start_conditions_distance_patch), 6, false) then exit;
  addr:=xrgame_addr+$131302;
  if not WriteJump(addr, cardinal(@CControllerPsyHit__check_conditions_final_distance_patch), 6, false) then exit;


  addr:=xrgame_addr+$2f9716;
  if not WriteJump(addr, cardinal(@CHudItem__OnH_B_Independent_Patch_Sound), 5, true) then exit;

  result:=true;
end;

end.
