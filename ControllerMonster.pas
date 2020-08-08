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
function IsControllerPreparing():boolean; stdcall;

function CheckActorVisibilityForController():boolean; stdcall;

procedure NotifySuicideStopCallbackIfNeeded();
procedure NotifySuicideShotCallbackIfNeeded();


type controller_input_correction_params = packed record
  rotate_angle:single;
  sense_scaler_x:single;
  sense_scaler_y:single;
end;
function GetCurrentControllerInputCorrectionParams():controller_input_correction_params;

type controller_input_random_offset = packed record
  offset_x:integer;
  offset_y:integer;
end;
function GetControllerInputRandomOffset():controller_input_random_offset;

implementation
uses BaseGameData, ActorUtils, HudItemUtils, WeaponAdditionalBuffer, DetectorUtils, gunsl_config, math, sysutils, uiutils, Level, MatVectors, strutils, ScriptFunctors, misc, WeaponEvents, Throwable, dynamic_caster, KeyUtils;

var
  _controlled_time_remains:cardinal;
  _suicide_now:boolean;
  _planning_suicide:boolean;
  _lastshot_done_time:cardinal;
  _death_action_started:boolean;
  _inventory_disabled_set:boolean;
  _knife_suicide_exit:boolean;
  _controller_preparing_starttime:cardinal;
  IsPsiBlocked_adapter_ptr:pointer;
  _active_controllers:array of pointer;

  _psi_block_failed:boolean;
  _input_correction:controller_input_correction_params;

function DistToSelectedContr(controller_monster:pointer):single; stdcall;
var
  a_pos, c_pos:pFVector3;
  c_pos_cp:FVector3;
  act:pointer;
begin
  result:=1000;
  act:=GetActor();
  if act=nil then exit;

  a_pos:=GetEntityPosition(act);
  c_pos:=GetEntityPosition(controller_monster);
  c_pos_cp:=c_pos^;
  v_sub(@c_pos_cp, a_pos);
  result:=v_length(@c_pos_cp);
end;

function DistToContr():single; stdcall;
var
  dist:single;

  i:integer;
begin
  result:=1000;

  for i:=0 to length(_active_controllers)-1 do begin
    dist:=DistToSelectedContr(_active_controllers[i]);
    if dist < result then begin
      dist:=result;
    end;
  end;
end;

procedure UpdatePsiBlockFailedState(monster_controller:pointer);
var
  dist, prob:single;
  params:controller_psiunblock_params;
begin
  dist:=DistToSelectedContr(monster_controller);
  params:=GetControllerPsiUnblockProb();

  if dist <= params.min_dist then begin
    prob:=params.min_dist_prob;
  end else if dist >= params.max_dist then begin
    prob:=params.max_dist_prob;
  end else begin
    prob:= 1 - (dist-params.min_dist) / (params.max_dist - params.min_dist);
    prob:= prob * (params.min_dist_prob - params.max_dist_prob) + params.max_dist_prob; 
  end;

  _psi_block_failed:=random < prob;
  // Log('psi unblock prob '+floattostr(prob)+', dist '+floattostr(dist)+', state '+booltostr(_psi_block_failed, true));
end;

function IsPsiBlockFailed():boolean;
begin
  result:=_psi_block_failed;
end;

function IsPsiBlocked(act:pointer):boolean; stdcall;
asm
  mov @result, 0
  pushad
    mov eax, act
    cmp act, 0
    je @finish
    mov eax, [eax+$26C]
    mov eax, [eax+$E4]

    cmp eax, 0
    je @finish
    mov @result, 1

    @finish:
  popad
end;

procedure IsPsiBlocked_adapter(); stdcall;
asm
  pushad
    mov eax, [ecx+04]
    test eax, eax
    je @finish
      push eax
      call IsPsiBlocked
    @finish:
    cmp al, 0
  popad
  je @no_block
  mov eax, 1
  ret

  @no_block:
  mov eax, 0
  ret

end;

procedure CGameObject__script_export(); stdcall;
const
  is_psi_blocked_name:PChar = 'is_psi_blocked';
asm
  pop edx

  mov [esp+$54], bl
  mov ecx, [esp+$54]
  push ecx

  mov [esp+$24], bl
  mov ecx, [esp+$24]
  push ecx

  lea ecx, [esp+$5c]
  push ecx

  lea ecx, [esp+$24]
  push ecx

  push is_psi_blocked_name

  mov ecx,IsPsiBlocked_adapter_ptr
  mov [esp+$2c],ecx

  mov ecx, eax

  mov ebx, edx

  mov edx, xrgame_addr
  add edx, $1D4D10
  call edx

  mov edx, ebx
  xor ebx, ebx

  mov [esp+$54], bl
  mov ecx, [esp+$54]

  jmp edx
end;

procedure ChangeInputRotateAngle();
const
  MIN_ANGLE:single = 70/180*pi;
  MAX_ANGLE:single = 290/180*pi;

  MIN_SENSE:single = 0.1;
  MAX_SENSE:single = 0.5;
begin
  _input_correction.rotate_angle:=random * (MAX_ANGLE-MIN_ANGLE) + MIN_ANGLE;
  _input_correction.sense_scaler_x:=random * (MAX_SENSE - MIN_SENSE) + MIN_SENSE;
  _input_correction.sense_scaler_y:=random * (MAX_SENSE - MIN_SENSE) + MIN_SENSE;
end;

function GetCurrentControllerInputCorrectionParams():controller_input_correction_params;
var
  suicide_anm:boolean;
  itm:pointer;
begin
  itm:=GetActorActiveItem();
  suicide_anm := (itm<>nil) and IsSuicideAnimPlaying(itm);

  if IsActorPlanningSuicide() or IsActorSuicideNow() or suicide_anm then begin
    result:=_input_correction;
  end else begin
    result.rotate_angle:=0;
    result.sense_scaler_x:=1;
    result.sense_scaler_y:=1;
  end;
end;

function GetControllerInputRandomOffset():controller_input_random_offset;
var
  suicide_anm:boolean;
  itm:pointer;
const
  MIN_OFS:single=-5;
  MAX_OFS:single=5;
begin
  itm:=GetActorActiveItem();
  suicide_anm := (itm<>nil) and IsSuicideAnimPlaying(itm);

  if IsActorSuicideNow() or suicide_anm or (not IsPsiBlocked(GetActor) and ( IsActorControlled() or IsActorPlanningSuicide() or IsControllerPreparing())) then begin
    result.offset_x:=floor(random*(MAX_OFS-MIN_OFS)+MIN_OFS);
    result.offset_y:=floor(random*(MAX_OFS-MIN_OFS)+MIN_OFS);
  end else begin
    result.offset_x:=0;
    result.offset_y:=0;
  end;
end;

function GetCurrentSuicideWalkKoef():single;
var
  itm:pointer;
begin
  result:=1.0;
  if IsActorControlled() or IsActorSuicideNow() or IsActorPlanningSuicide() or IsControllerPreparing() then begin
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
  result:=(leftstr(anm, length('anm_prepare_suicide'))='anm_prepare_suicide') or (leftstr(anm, length('anm_suicide'))='anm_suicide');
end;

function IsActorSuicideNow():boolean; stdcall;
begin
  result:=_suicide_now;
end;

function IsActorPlanningSuicide():boolean; stdcall;
begin
  result:=_planning_suicide;
end;

procedure AddActiveController(monster_controller:pointer); stdcall;
begin
  if length(_active_controllers) = 0 then begin
    script_call('gunsl_controller.on_suicide_scheme_start', '', GetCObjectID(monster_controller));
  end;

  setlength(_active_controllers, length(_active_controllers)+1);
  _active_controllers[length(_active_controllers)-1] := monster_controller;
  script_call('gunsl_controller.on_suicide_selected_by_controller', '', GetCObjectID(monster_controller));
end;

procedure ClearActiveControllers(); stdcall;
begin
  if length(_active_controllers) > 0 then begin
    script_call('gunsl_controller.on_suicide_scheme_finish', '', 0);
  end;
  setlength(_active_controllers, 0);
end;

procedure ResetActorControl(); stdcall;
begin
  ClearActiveControllers();
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
var
  can_shoot, is_knife, can_switch_gl, can_shoot_gl:boolean;
begin
  result:=false;
  if (wpn=nil) then exit;

  can_shoot:=WpnCanShoot(wpn);
  is_knife:=IsKnife(wpn);
  if (not is_knife) and (not can_shoot) then exit;

  if game_ini_r_bool_def(GetHUDSection(wpn), 'prohibit_suicide', false) then exit;

  if IsGrenadeMode(wpn) then begin
    can_switch_gl:= game_ini_r_bool_def(GetHUDSection(wpn), 'controller_can_switch_gl', false); //контролер выключит подствол
    can_shoot_gl := game_ini_r_bool_def(GetHUDSection(wpn), 'controller_can_shoot_gl', false);  //контролер выстрелит из подствола под ноги
    if (GetAmmoInGLCount(wpn) > 0) then begin
      result:=can_switch_gl or can_shoot_gl;
    end else if GetAmmoInMagCount(wpn) > 0 then begin
      result:=can_switch_gl;
    end else begin
      result:=false;
    end;
  end else begin
    if can_shoot then begin
      result:= (GetAmmoInMagCount(wpn) > 0) and not IsWeaponJammed(wpn)
    end else begin
      result:=true;
    end;
  end;
end;

procedure Update(dt:cardinal); stdcall;
var
  wpn, act, det:pointer;
  last_contr_time:cardinal;
begin
  act:=GetActor();
  if (act = nil) or (GetActorHealthPtr(act)^ <= 0) then begin
    ResetActorControl();
    exit;
  end;

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

  end else if (wpn<>nil) and IsKnife(wpn) then begin
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
      KillActor(act, act);
      _lastshot_done_time:=0;
    end;
  end;

  if (act<>nil) and (_controlled_time_remains>0)  then begin
    if (det<>nil) then begin
      if (GetCurrentState(det)<>EHudStates__eHiding) and (GetCurrentState(det)<>EHudStates__eHidden) then virtual_CHudItem_SwitchState(det, EHudStates__eHiding);
    end;

    if (wpn<>nil) and (WpnCanShoot(wpn) or IsBino(wpn)) and (IsAimNow(wpn)) then begin
      SetActorKeyRepeatFlag(kfUNZOOM, true, true);
    end;

    if (wpn<>nil) and (WpnCanShoot(wpn)) then begin
      //Если стрельба "залипла", не допускаем исчерпания боезапаса (не ножом же резаться :) )
      if (GetCurrentState(wpn)=EWeaponStates__eFire) and (_lastshot_done_time=0) and (GetCurrentAmmoCount(wpn) <= 3) then begin
        SetWorkingState(wpn, false);
      end;
    end;

    if (wpn<>nil) and (GetSection(wpn)=GetPDAShowAnimator()) then begin 
      if IsPDAWindowVisible() then HidePDAMenu();
    end else if (wpn<>nil) and IsThrowable(wpn) then begin
      _planning_suicide:=true;
      _suicide_now:=false;
      if (GetCurrentState(wpn) = EMissileStates__eReady) then begin
        //делать нечего - придется кидать... Но кидаем под ноги и временем дестроя не манипулируем
        virtual_CHudItem_SwitchState(wpn, EMissileStates__eThrow);
        PrepareGrenadeForSuicideThrow(wpn, game_ini_r_single_def(GetSection(wpn), 'suicide_ready_force', 8));
        virtual_Action(wpn, kWPN_ZOOM, kActRelease);
      end else if (GetCurrentState(wpn) = EMissileStates__eThrowStart) then begin
        //Здесь может быть либо начало обычного броска, либо суицидного.
        //Если суицид - на всякий обновляем статусы для гарантированного срабатывания броска (хотя они и должны обновиться нами в OnAnimationEnd перед самим броском)
        if IsMissileInSuicideState(wpn) then begin
          SetConstPowerStatus(wpn, true);
          SetImmediateThrowStatus(wpn, true);
        end else begin
          PrepareGrenadeForSuicideThrow(wpn, game_ini_r_single_def(GetSection(wpn), 'suicide_ready_force', 8));
          virtual_Action(wpn, kWPN_ZOOM, kActRelease);
        end;
      end else if (dynamic_cast(wpn, 0, RTTI_CHudItemObject, RTTI_CGrenade, false)<>nil) and  (DistToContr()>game_ini_r_single_def(GetHUDSection(wpn), 'controller_g_attack_min_dist', 10)) and (GetCurrentState(wpn) = EHudStates__eIdle) and (not game_ini_r_bool_def(GetHUDSection(wpn), 'prohibit_suicide', false)) then begin
        //атакуем игрока его же греной
        virtual_CHudItem_SwitchState(wpn, EMissileStates__eThrowStart);
      end else if CanUseItemForSuicide(ItemInSlot(act, 1)) then begin
        ActivateActorSlot__CInventory(1, false);
      end else begin
        ActivateActorSlot__CInventory(0, false);
      end;

    end else begin
      _planning_suicide:=CanUseItemForSuicide(wpn);
      if not _planning_suicide then begin
        //этой штукой убиться нельзя...
        if (wpn<>nil) then begin
          PerformDrop(act);
        end;
        //А можно ли ножом?
        if CanUseItemForSuicide(ItemInSlot(act, 1)) then begin
          ActivateActorSlot__CInventory(1, false);
          _planning_suicide:=true;
          _suicide_now:=false;
        end else begin
          ActivateActorSlot__CInventory(0, false);
          _suicide_now:=false;
        end;
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

  if IsGrenadeMode(wpn) then begin
    TryShootGLFix(wpn);
  end else begin
    virtual_CShootingObject_FireStart(wpn);
  end;

  NotifySuicideShotCallbackIfNeeded();
  // ClearActiveControllers() вызовется на апдейте, увидев _lastshot_done_time
end;

function IsControllerSeeActor(contr:pointer; act:pointer):boolean; stdcall;
asm
  pushad
    mov ecx, contr
    add ecx, $5b4

    push act
    mov ebx, xrgame_addr
    add ebx, $D0C80 //CMonsterEnemyManager::see_enemy_now
    call ebx
    mov @result, al
  popad
end;


function CheckActorVisibilityForController():boolean; stdcall;
var
  act:pointer;
  i:integer;
begin
  if GetCurrentDifficulty >= gd_veteran then begin
    // на высокой сложности контролер всегда завершает свое...
    result:=true;
    exit;
  end;

  result:=false;
  act:=GetActor();
  if act=nil then exit;

//  Log('Check visibility for '+inttostr(length(_active_controllers))+'controllers');
  for i:=0 to length(_active_controllers)-1 do begin
    result:=IsControllerSeeActor(_active_controllers[i], act);
    if result then begin
//      log('Visible by #'+inttostr(i));
      exit;
    end;
  end;
end;

procedure OnSuicideAnimEnd(wpn:pointer; param:integer);stdcall;
begin
  if (wpn<>GetActorActiveItem()) then exit;
  if (not IsPsiBlocked(GetActor()) or IsPsiBlockFailed()) and (_suicide_now or _planning_suicide) and CheckActorVisibilityForController() then begin
    DoSuicideShot();
  end else begin
    _suicide_now:=false;
    _planning_suicide:=false;
    NotifySuicideStopCallbackIfNeeded();
    ClearActiveControllers();
    WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_stop_suicide', 'sndStopSuicide');
    SetHandsJitterTime(GetShockTime());
  end;
end;

function PsiEffects(monster_controller:pointer):boolean; stdcall;
var
  act, det, wpn:pointer;
  buf:WpnBuf;

  psi_blocked, not_seen, dist_forcer:boolean;
  c_pos, a_pos:pFVector3;
  c_pos_cp:FVector3;
  dist:single;
  contr_feel:controller_feel_params;

  can_switch_gl, can_shoot_gl:boolean;
begin
  //true в результате означает, что мы использовали кастомный эффект и обычную атаку играть не надо
  result:=true;

  act:=GetActor();
  if act=nil then exit;

  psi_blocked:=IsPsiBlocked(act) and not IsPsiBlockFailed();
  not_seen:= not IsControllerSeeActor(monster_controller, act);
  dist:=DistToSelectedContr(monster_controller);
  contr_feel:=GetControllerFeelParams();

  if dist < contr_feel.min_dist then begin
    dist_forcer:=true;
  end else if dist > contr_feel.max_dist then begin
    dist_forcer:=false;
  end else begin
    dist_forcer:= ((dist - contr_feel.min_dist) / (contr_feel.max_dist - contr_feel.min_dist)) > random;
  end;

  //Если активен бустер псиблокады, то суицид не делаем
  //Также не делаем, если актор свалил
  if ( psi_blocked or (not dist_forcer and not_seen) ) and not IsActorSuicideNow() and not IsSuicideInreversible() then begin
    result:=not_seen;
    _planning_suicide:=false;
    _suicide_now:=false;
    SetHandsJitterTime(GetControllerBlockedTime());
    exit;
  end;

  _controlled_time_remains:=GetControllerTime();

  det:=GetActiveDetector(act);
  wpn:=GetActorActiveItem();

  if IsPDAWindowVisible() or ((wpn<>nil) and (GetSection(wpn)=GetPDAShowAnimator())) then begin
    result:=false;            //бьем стандартным пси-хитом
    _planning_suicide:=false;
    _suicide_now:=false;
    SetHandsJitterTime(GetControllerTime());
    exit;
  end;

  if (det<>nil) or ((wpn<>nil) and not CanUseItemForSuicide(wpn)) then begin
    _planning_suicide:=CanUseItemForSuicide(wpn);
    _suicide_now:=false;
    result:= (wpn=nil) or (not ((GetCurrentState(wpn)=EHudStates__eHidden) or (GetCurrentState(wpn)=EHudStates__eHiding)));
    exit;
  end;

  if (wpn=nil) then begin
    {if (GetCurrentDifficulty()>=gd_master) and CanUseItemForSuicide(ItemInSlot(act, 1)) then begin
      _planning_suicide:=true;
       result:=true;
    end else begin
      _planning_suicide:=false;
      result:=false;
    end;}

    if CanUseItemForSuicide(ItemInSlot(act, 1)) then begin
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
  if IsKnife(wpn) then begin
    _controlled_time_remains:=floor(game_ini_r_single_def(GetHUDSection(wpn), 'controller_time', _controlled_time_remains/1000)*1000);
    _planning_suicide:=true;
    //если до сих пор анима суицида не стартовала - форсируем событие
    if ( not _suicide_now or not IsSuicideAnimPlaying(wpn) ) and ((GetCurrentState(wpn)<>EWeaponStates__eFire) or (GetCurrentState(wpn)<>EWeaponStates__eFire2)) then begin
      virtual_CHudItem_SwitchState(wpn, EWeaponStates__eFire);
    end;
    exit;
  end;


  buf:=GetBuffer(wpn);

  //а теперь займемся стреляющим оружием

  c_pos:=GetEntityPosition(monster_controller);
  c_pos_cp:=c_pos^;
  a_pos:=GetEntityPosition(act);
  v_sub(@c_pos_cp, a_pos);

  if IsGrenadeMode(wpn) then begin
    //если дошлю сюда - значит, с подстволом можем работать
    can_switch_gl:=game_ini_r_bool_def(GetHUDSection(wpn), 'controller_can_switch_gl', false);
    can_shoot_gl:=game_ini_r_bool_def(GetHUDSection(wpn), 'controller_can_shoot_gl', false);
    if can_shoot_gl and (GetAmmoInGLCount(wpn) > 0) and (game_ini_r_single_def(GetHUDSection(wpn), 'controller_shoot_gl_min_dist', 10) < v_length(@c_pos_cp)) then begin
      //дистанция до контры большая, можно стрелять из подствола
      //Ничего особенного делать тут не надо (пока?), просто идем дальше по if'ам
    end else if can_switch_gl and (GetAmmoInMagCount(wpn) > 0) and not IsWeaponJammed(wpn) then begin
      //выключаем подствол
      virtual_CHudItem_SwitchState(wpn, EWeaponStates__eSwitch);
     _planning_suicide:=true;
     _suicide_now:=false;
      exit;
    end else begin
      //выбрасываем ствол
      PerformDrop(act);
      exit;
    end;
  end else if (dynamic_cast(wpn, 0, RTTI_CHudItemObject, RTTI_CWeaponRG6, false)<>nil) or (dynamic_cast(wpn, 0, RTTI_CHudItemObject, RTTI_CWeaponRPG7, false)<>nil) then begin
    //РПГ или РГ-6
    if (game_ini_r_single_def(GetHUDSection(wpn), 'controller_shoot_expl_min_dist', 10)>v_length(@c_pos_cp)) then begin
      PerformDrop(act);
      exit;
    end;
  end;

  _planning_suicide:=false; //хак - чтобы функция определения возможности действия не учитывала это
  _suicide_now:=false;

  if game_ini_r_bool_def(GetHUDSection(wpn), 'suicide_by_animation', false) then begin
    _suicide_now:=IsSuicideAnimPlaying(wpn) or (_lastshot_done_time>0);
    if not _suicide_now then _suicide_now:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_suicide', 'sndSuicide', OnSuicideAnimEnd);
    if _suicide_now then begin
      _controlled_time_remains:=floor(game_ini_r_single_def(GetHUDSection(wpn), 'controller_time', _controlled_time_remains/1000)*1000);
      //log(inttostr(_controlled_time_remains));
    end;
    _planning_suicide:=true;
  end else begin
    if CanStartAction(wpn) then begin
      _suicide_now:=true;
      _controlled_time_remains:=floor(game_ini_r_single_def(GetHUDSection(wpn), 'controller_time', _controlled_time_remains/1000)*1000);
    end;
    _planning_suicide:=true;
  end;

  if (GetCurrentState(wpn)=EWeaponStates__eFire) then begin
    // Когда актор ведет огонь очередью, стрельба может либо прекратиться, либо "залипнуть". Это поведение by design
    if (GetControllerQueueStopProb() >= random) then begin
      SetWorkingState(wpn, false);
    end;
  end;
end;

function PsiStart(monster_controller:pointer):boolean; stdcall;
var
  wpn, act:pointer;
  scream:string;
  v, va:FVector3;
  i,j:cardinal;
  radius:single;
  p:phantoms_params;
  found:boolean;
  k:integer;
begin
//  _is_controller_preparing:=false;
  result:=PsiEffects(monster_controller);
  act:=GetActor();
  if (act<>nil) and not CActor__get_inventory_disabled(act) then begin
    HideShownDialogs();
    CActor__set_inventory_disabled(act, true);
    _inventory_disabled_set:=true;
  end;

  if result then begin
    wpn:=GetActorActiveItem();
    if (wpn<>nil) and not game_ini_r_bool_def(GetHUDSection(wpn), 'suicide_by_animation', false) and (IsKnife(wpn) or WpnCanShoot(wpn)) then begin
      scream:='sndScream'+inttostr(random(3)+1);
      CHudItem_Play_Snd(wpn, PChar(scream));
    end;

    found:=false;
    for k:=0 to length(_active_controllers)-1 do begin
      if _active_controllers[k]=monster_controller then begin
        found:=true;
        break;
      end;
    end;

    if not found then begin
      AddActiveController(monster_controller);
    end;

    if _planning_suicide or _suicide_now then begin
      script_call('gunsl_controller.on_suicide_attack', '', GetCObjectID(monster_controller));
    end;
  end else begin
    script_call('gunsl_controller.on_std_attack', '', GetCObjectID(monster_controller));
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
    push [esi+$8] //CBaseMonster* CControllerPsyHit.m_object
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

procedure OnPsyHitActivate(monster_controller:pointer); stdcall;
begin
  if (_controlled_time_remains = 0) then begin
    UpdatePsiBlockFailedState(monster_controller);
    ChangeInputRotateAngle();
  end;

  _controller_preparing_starttime:=GetGameTickCount();
  script_call('gunsl_controller.on_psi_attack_prepare', '', GetCObjectID(monster_controller));
  if (not IsPsiBlocked(GetActor()) or IsPsiBlockFailed()) and (_controlled_time_remains>0) then begin
    _controlled_time_remains:=GetControllerPrepareTime();
  end;
end;

procedure CControllerPsyHit__activate_Patch(); stdcall;
asm
  add edi, $AA0
  pushad
    push [esi+8] //CBaseMonster* CControllerPsyHit.m_object
    call OnPsyHitActivate
  popad
end;

function IsControllerPreparing():boolean; stdcall;
begin
  if IsPsiBlocked(GetActor()) and (not IsPsiBlockFailed()) then
    result:=false
  else
    result:=(GetTimeDeltaSafe(_controller_preparing_starttime)<GetControllerPrepareTime+1000);
end;

procedure NotifySuicideStopCallbackIfNeeded();
begin
  if length(_active_controllers) > 0 then begin
    script_call('gunsl_controller.on_stop_suicide', '', 0);
  end;
end;

procedure NotifySuicideShotCallbackIfNeeded();
begin
  if length(_active_controllers) > 0 then begin
    script_call('gunsl_controller.on_suicide_shot', '', 0);
  end;
end;

function Init():boolean; stdcall;
var
  addr:cardinal;
  addr2:cardinal;
begin
  result:=false;

  IsPsiBlocked_adapter_ptr:=@IsPsiBlocked_adapter;

  addr:=xrgame_addr+$1ED146;
  if not WriteJump(addr, cardinal(@CGameObject__script_export), 8, true) then exit;


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

  addr:=xrgame_addr+$1318DF;
  if not WriteJump(addr, cardinal(@CControllerPsyHit__activate_Patch), 6, true) then exit;

  //почему-то при обычных атаках контроля возникают рандомные вылеты вида
  //Expression    : assertion failed
  //Function      : CLensFlare::OnFrame
  //File          : D:\prog_repository\sources\trunk\xrEngine\xr_efflensflare.cpp
  //Line          : 330
  //Description   : _valid(vecX)
  //причина - NaN'ы в CRenderDevice, как они туда попадают - хз
  //Предполагаются особенности работы эффектора, возможно, из-за какой-то врезки
  //Отрубаем этот эффектор к чертям от греха подальше
  addr:=xrgame_addr+$131C20;
  addr2:=xrgame_addr+$131C94;
  if not WriteJump(addr, addr2, 9, false) then exit;
  nop_code(xrgame_addr+$131E93, 1);
  nop_code(xrgame_addr+$131E9B, 8);
  nop_code(xrgame_addr+$131F01, 5);
  nop_code(xrgame_addr+$131A5C, 6);
  nop_code(xrgame_addr+$131A69, 1, CHR($EB));  
  nop_code(xrgame_addr+$131F12, 1,chr(0));   
   

  result:=true;
end;

end.
