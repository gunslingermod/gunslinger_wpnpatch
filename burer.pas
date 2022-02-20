unit burer;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

function Init():boolean; stdcall;
function GetLastSuperStaminaHitTime():cardinal; stdcall;

implementation
uses BaseGameData, Misc, MatVectors, ActorUtils, gunsl_config, sysutils, HudItemUtils, RayPick, dynamic_caster, WeaponAdditionalBuffer, HitUtils, Throwable, KeyUtils, math, ScriptFunctors, UIUtils, vector, physics;

var
  _gren_count:cardinal; //по-хорошему - надо сделать членом класса, но и так сойдет - однопоточность же
  _gren_timer:cardinal;
  _last_superstamina_hit_time:cardinal;

const
  ACTOR_HEAD_CORRECTION_HEIGHT:single = 2;
  BURER_HEAD_CORRECTION_HEIGHT:single = 1;
  UNCONDITIONAL_VISIBLE_DIST:single=3; //чтобы не фейлится, когда актор вплотную
  MIN_ANTIAIM_LOCK_TIME_BEFORE_SHOT:single=0.2;
  MIN_GRAVI_LOCK_TIME_BEFORE_SHOT:single=1.5;
  MAX_TELE_GREN_COUNT:cardinal=3;


function IsLongRecharge(itm:pointer; min_time:single):boolean;
var
  buf:WpnBuf;
const
  SAFETY_PERIOD:cardinal = 100;
begin
  result:=false;
  if itm=nil then exit;
  buf:=GetBuffer(itm);
  if buf = nil then begin
    result:=GetShootLockTime(itm)>min_time;
  end else begin
    result:= (buf.GetLastShotTimeDelta() > SAFETY_PERIOD) and (buf.GetTimeBeforeNextShot()>min_time);
  end;
end;

procedure LogBurerLogic(t:string); stdcall;
begin
  //Log(t);
end;

function GetLastSuperStaminaHitTime():cardinal; stdcall;
begin
  result:=_last_superstamina_hit_time;
end;

function IsActorTooClose(burer:pointer; close_dist:single):boolean; stdcall;
var
  act:pointer;
  act_pos, dist:FVector3;
  len:single;
begin
  result:=false;
  act:=GetActorIfAlive();
  if act = nil then exit;

  act_pos:=FVector3_copyfromengine(GetEntityPosition(act));
  dist:=act_pos;
  v_sub(@dist, GetEntityPosition(burer));
  len:=v_length(@dist);
  if (len < close_dist) then begin
    act_pos.y:=act_pos.y+ACTOR_HEAD_CORRECTION_HEIGHT;
    result:=IsObjectSeePoint(burer, act_pos, UNCONDITIONAL_VISIBLE_DIST, BURER_HEAD_CORRECTION_HEIGHT, true);
  end;
end;

function IsActorLookTurnedAway(burer:pointer):boolean; stdcall;
var
  burer_v, look_v:FVector3;
begin
  burer_v:=FVector3_copyfromengine(GetEntityPosition(burer));
  look_v:=FVector3_copyfromengine(CRenderDevice__GetCamPos());
  v_sub(@burer_v, @look_v);
  look_v:=FVector3_copyfromengine(CRenderDevice__GetCamdir());
  result:=GetAngleCos(@burer_v, @look_v) < 0;
end;

function IsWeaponDangerous(itm:pointer; burer:pointer):boolean; stdcall;
var
  gl_status:cardinal;
  in_gl:boolean;
begin
  result:=false;
  if itm=nil then begin
    exit;
  end else if (IsKnife(itm) or (GetKickAnimator() = GetSection(itm))) and IsActorTooClose(burer, GetBurerForceantiaimDist()) then begin
    result:=true;
  end else if IsBino(itm) then begin
    result:=false;
  end else if IsThrowable(itm) then begin
    result:=false;
  end else if WpnCanShoot(itm) and (GetCurrentAmmoCount(itm) > 0) then begin
    gl_status:=GetGLStatus(itm);
    in_gl:= ((gl_status=1) or ((gl_status=2) and IsGLAttached(itm))) and IsGLEnabled(itm);
    if in_gl then begin
      result:=true;
    end else if IsWeaponJammed(itm) or (GetCurrentState(itm) = EWeaponStates__eReload) then begin
      result:=false;
    end else begin
      result:=true;
    end;
  end;
end;

function IsWeaponReadyForBigBoom(itm:pointer; was_shot:pboolean):boolean; stdcall;
var
  gl_status:cardinal;
  buf:WpnBuf;
const
  SHOT_SAFETY_TIME_DELTA:cardinal=2000;
begin
  result:=false;
  if was_shot<>nil then begin
    was_shot^:=false;
  end;

  if itm<>nil then begin
    result:=(dynamic_cast(itm, 0, RTTI_CHudItemObject, RTTI_CWeaponRG6, false)<>nil) or (dynamic_cast(itm, 0, RTTI_CHudItemObject, RTTI_CWeaponRPG7, false)<>nil);
    if not result and WpnCanShoot(itm) then begin
      gl_status:=GetGLStatus(itm);
      if ((gl_status=1) or ((gl_status=2) and IsGLAttached(itm))) and IsGLEnabled(itm) then begin
        result:=true;
      end;
    end;

    if result then begin
      buf:=GetBuffer(itm);
      if (buf <> nil) then begin
        if (buf.GetLastShotTimeDelta() > SHOT_SAFETY_TIME_DELTA) then begin
          if (GetCurrentAmmoCount(itm) = 0) then begin
            result:=false;
          end;
        end else begin
          if was_shot<>nil then begin
            was_shot^:=true;
          end;
        end;
      end;
    end;
  end;
end;

function IsSniperWeapon(wpn:pointer):boolean; stdcall;
begin
  result:=(wpn<>nil) and game_ini_r_bool_def(GetSection(wpn), 'is_burer_see_sniper_weapon', false);
end;

type
  TBurerUnderAimType = (BurerUnderAimExact, BurerUnderAimNear, BurerUnderAimWide);

function IsBurerUnderAim(burer:pointer; aimtype:TBurerUnderAimType):boolean; stdcall;
var
  rqr:rq_result;
  cam_dir, cam_pos, burer_dir, burer_pos:FVector3;
  dist_to_burer, treasure:single;
const
  TREASURE_WIDE:single = 0.88;
  TREASURE_NEAR:single = 0.94;
begin
  result:=false;
  if IsWeaponDangerous(GetActorActiveItem(), burer) then begin
    cam_dir:=FVector3_copyfromengine(CRenderDevice__GetCamDir());
    cam_pos:=FVector3_copyfromengine(CRenderDevice__GetCamPos());
    rqr:=TraceAsView_RQ(@cam_pos, @cam_dir, GetActor());
    if rqr.O = burer then begin
      result:=true;
      exit;
    end;

    if aimtype <> BurerUnderAimExact then begin
      burer_pos:=FVector3_copyfromengine(GetEntityPosition(burer));
      burer_pos.y:=burer_pos.y + BURER_HEAD_CORRECTION_HEIGHT;

      if aimtype = BurerUnderAimNear then begin
        treasure:=TREASURE_NEAR;
      end else begin
        treasure:=TREASURE_WIDE;
      end;

      burer_dir:=burer_pos;
      v_sub(@burer_dir, @cam_pos);

      if GetAngleCos(@burer_dir, @cam_dir) > treasure then begin
        v_sub(@burer_pos, @cam_pos);
        dist_to_burer:=v_length(@burer_pos);
        if rqr.range > dist_to_burer/2 then begin
          result:=true;
          exit;
        end;
      end;
    end;
  end;
end;

function NeedCloseProtectionShield(burer:pointer):boolean; stdcall;
var
  act:pointer;
  itm:pointer;
  actor_very_close:boolean;

begin
  result:=false;
  act:=GetActorIfAlive();
  if act=nil then exit;
  itm:=GetActorActiveItem();
  if itm=nil then exit;

  actor_very_close:=IsActorTooClose(burer, GetBurerForceshieldDist());

  if actor_very_close then begin
    result:=IsWeaponDangerous(itm, burer) and not IsActorLookTurnedAway(burer);
  end;
end;

procedure CorrectBurerAttackReadyStatuses(burer:pointer; phealthloss:pboolean; panti_aim_ready:pboolean; pgravi_ready:pboolean; ptele_ready:pboolean; pshield_ready:pboolean; previous_state:pbyte); stdcall;
var
  actor_close, actor_very_close:boolean;
  itm:pointer;
  force_antiaim, force_shield, force_tele, force_gravi:boolean;
  weapon_for_big_boom, big_boom_shooted, eatable_with_hud, sniper_weapon:boolean;
  burer_see_actor:boolean;
  campos:FVector3;
const
  eStateBurerAttack_Tele:byte=6;
  eStateBurerAttack_AntiAim:byte=12;
  eStateBurerAttack_Gravi:byte=7;
  eStateBurerAttack_Shield:byte=11;
begin
  LogBurerLogic('Start burer attack selector');
  LogBurerLogic('antiaim_ready = '+booltostr(panti_aim_ready^));
  LogBurerLogic('gravi_ready = '+booltostr(pgravi_ready^));
  LogBurerLogic('tele_ready = '+booltostr(ptele_ready^));
  LogBurerLogic('shield_ready = '+booltostr(pshield_ready^));
  LogBurerLogic('gren_count = '+inttostr(_gren_count));
  LogBurerLogic('gren_timer = '+inttostr(_gren_timer));

  force_antiaim:=false;
  force_shield:=false;
  force_tele:=false;
  force_gravi:=false;

  itm:=GetActorActiveItem();
  weapon_for_big_boom:=IsWeaponReadyForBigBoom(itm, @big_boom_shooted);
  sniper_weapon:=IsSniperWeapon(itm);

  campos:=FVector3_copyfromengine(CRenderDevice__GetCamPos());
  burer_see_actor:=(GetActorIfAlive()<>nil) and IsObjectSeePoint(burer, campos, UNCONDITIONAL_VISIBLE_DIST, BURER_HEAD_CORRECTION_HEIGHT, true);
  LogBurerLogic('see_actor = '+booltostr(burer_see_actor));

  eatable_with_hud:=(itm<>nil) and game_ini_line_exist(GetSection(itm), 'gwr_changed_object');

  // Не юзаем телекинез подряд, если можем разнообразить поведение
  if (previous_state^ = eStateBurerAttack_Tele) and (panti_aim_ready^ or pgravi_ready^) then begin
    ptele_ready^:=false;
  end;

  // Если в руках у актора нет ничего, равно как рядом нет ничего опасного - смысла в щите тоже нет.
  if (itm=nil) and (_gren_count = 0) and not big_boom_shooted then begin
    LogBurerLogic('Disable shield in safe conditions');  
    pshield_ready^:=false;
  end;

  // Если мы ранее рискнули выйти из щита с подбрасыванием камеры - временно отключаем щит
  if (pshield_ready^) and script_bool_call('gunsl_burer.need_disable_shield', '', GetCObjectID(burer), '') then begin
    if big_boom_shooted then begin
      LogBurerLogic('Script disable shield');
      pshield_ready^:=false;
    end else begin
      LogBurerLogic('Skip disable shield - big_boom_shooted');
    end;
  end;

  // Отдаём предпочтение вырыванию оружия из рук в опасных ситуациях
  if (panti_aim_ready^) and not IsActorLookTurnedAway(burer) and (itm<>nil) and not IsLongRecharge(itm, MIN_GRAVI_LOCK_TIME_BEFORE_SHOT) and (random < 0.85) and IsWeaponDangerous(itm, burer) then begin
    LogBurerLogic('Disable gravi because aim ready');
    pgravi_ready^:=false;
  end;

  if NeedCloseProtectionShield(burer) and (pshield_ready^) then begin
    LogBurerLogic('NeedCloseProtectionShield+ready');
    // Актор слишком близко, оружие готово к выстрелу
    ptele_ready^:=false;
    if (_gren_count>0) and (_gren_timer < GetBurerMinGrenTimer()) and (pshield_ready^) then begin
      force_shield:=true;
    end else if eatable_with_hud and (panti_aim_ready^) then begin
      force_antiaim:=true;
    end else if phealthloss^ then begin
      force_shield:=true;
    end else if sniper_weapon then begin
      pgravi_ready^:=false;
      if ((GetCurrentAmmoCount(itm) = 0) or (GetCurrentState(itm) = EWeaponStates__eReload)) and panti_aim_ready^ then begin
        force_antiaim:=true
      end else if (IsLongRecharge(itm, MIN_ANTIAIM_LOCK_TIME_BEFORE_SHOT) or IsActorLookTurnedAway(burer) or (random < 0.3)) and panti_aim_ready^ then begin
        force_antiaim:=true
      end else begin
        if (previous_state^ = eStateBurerAttack_Shield) and not IsBurerUnderAim(burer, BurerUnderAimWide) and panti_aim_ready^ then begin
          force_antiaim:=true;
        end else if pshield_ready^ then begin
          force_shield:=true;
        end;
      end;
    end else if (panti_aim_ready^) and (previous_state^=eStateBurerAttack_Shield) then begin
      if (itm<>nil) and (GetKickAnimator() = GetSection(itm)) then begin
        force_shield:=true;
      end else begin
        LogBurerLogic('AntiCloseKnife');
        script_call('gunsl_burer.on_close_antiknife_prepare', '', GetCObjectID(burer));
        force_antiaim:=true;
      end;
    end else begin
      force_shield:=true;
    end;
  end else if (GetCurrentDifficulty()>=gd_stalker) and eatable_with_hud and panti_aim_ready^ and (random < 0.95) then begin
    // Попытка отхилиться - предотвращаем
    if (_gren_count>0) and (_gren_timer < GetBurerMinGrenTimer()) and (pshield_ready^) and (random < 0.8) then begin
      LogBurerLogic('AntiHeal - GrenShield');
      force_shield:=true;
    end else begin
      LogBurerLogic('AntiHeal');
      force_antiaim:=true;
    end;
  end else if (itm<>nil) and (_gren_count = 0) and (IsKnife(itm) or (GetKickAnimator() = GetSection(itm))) and pgravi_ready^ then begin
    LogBurerLogic('AntiKnifeGravi');
    force_gravi:=true;
  end else if IsInventoryShown() and not big_boom_shooted and (_gren_count = 0) and (panti_aim_ready^) then begin
    LogBurerLogic('AntiInventory');
    force_antiaim:=true;
  end else if weapon_for_big_boom or big_boom_shooted then begin
    LogBurerLogic('AntiBigBoom');
    pgravi_ready^:=false;

    if (IsActorLookTurnedAway(burer) or not burer_see_actor) and (random < 0.1) then begin
      LogBurerLogic('Temp skip disable tele');
    end else begin
      ptele_ready^:=false;
    end;

    if (_gren_count>0) and (_gren_timer < GetBurerMinGrenTimer()) and (pshield_ready^) and (random < 0.8) then begin
      LogBurerLogic('AntiBigBoom - GrenShield');
      force_shield:=true;
    end else if (not big_boom_shooted) and (previous_state^ = eStateBurerAttack_Shield) and (panti_aim_ready^) then begin
      force_antiaim:=true;
    end else if (IsBurerUnderAim(burer, BurerUnderAimWide) or ((panti_aim_ready^) and (random < 0.4))) and (pshield_ready^) then begin
      force_shield:=true;
    end else if (not big_boom_shooted or not pshield_ready^) and panti_aim_ready^ then begin
      force_antiaim:=true;
    end else if (pshield_ready^) then begin
      force_shield:=true;
    end
  end else if sniper_weapon then begin
    LogBurerLogic('AntiSniper');

    if (IsActorLookTurnedAway(burer) or not burer_see_actor) and (random < 0.1) then begin
      LogBurerLogic('Temp skip disable tele');
    end else begin
      ptele_ready^:=false;
    end;

    if (_gren_count>0) and pshield_ready^ then begin
      LogBurerLogic('Grenades');    
      force_shield:=true;
    end else if IsLongRecharge(itm, MIN_GRAVI_LOCK_TIME_BEFORE_SHOT) and (random<0.6) and pgravi_ready^ then begin
      LogBurerLogic('LongRecharge - Gravi');
      force_gravi:=true;
    end else if IsLongRecharge(itm, MIN_ANTIAIM_LOCK_TIME_BEFORE_SHOT) and panti_aim_ready^ then begin
      LogBurerLogic('LongRecharge - AntiAim');
      force_antiaim:=true;
    end else if IsActorLookTurnedAway(burer) and panti_aim_ready^ then begin
      LogBurerLogic('LookAway - AntiAim');
      force_antiaim:=true;
    end else if ((previous_state^ <> eStateBurerAttack_Shield) or (random < 0.75) ) and pshield_ready^ then begin
      LogBurerLogic('ShieldAllowed');
      force_shield:=true;
    end else begin
      if IsBurerUnderAim(burer, BurerUnderAimWide) then begin
        pgravi_ready^:=false;
      end;

      if not IsBurerUnderAim(burer, BurerUnderAimNear) and panti_aim_ready^ then begin
        force_antiaim:=true;
      end else if pshield_ready^ then begin
        force_shield:=true;
      end;
    end;
  end else if IsActorTooClose(burer, GetBurerForceantiaimDist()) then begin
    LogBurerLogic('AntiMiddleDistance');
    // Актор недалеко, но не слишком близко пока
    if (_gren_count>0) and (_gren_timer < GetBurerMinGrenTimer()) and (pshield_ready^) then begin
      force_shield:=true;
    end else if (itm<>nil) and panti_aim_ready^ then begin
      force_antiaim:=true;
    end else if IsActorLookTurnedAway(burer) and (pgravi_ready^) then begin
      if (_gren_count > MAX_TELE_GREN_COUNT) and (pshield_ready^) then begin
        force_shield:=true;
      end else if (_gren_count>0) and (_gren_timer > GetBurerMinGrenTimer()) and (ptele_ready^) and (random < 0.75) then begin
        force_tele:=true;
      end else if (_gren_count>0) and (pshield_ready^) then begin
        force_shield:=true;
      end else begin
        force_gravi:=true;
      end;
    end else if (_gren_count>0) and (pshield_ready^) then begin
      force_shield:=true;
    end else if (itm<>nil) and IsThrowable(itm) and (_gren_count=0) then begin
      pshield_ready^:=false;
      if (GetCurrentState(itm) <> EHudStates__eIdle) then begin
        pgravi_ready^:=false;
       //TODO:Принудительный спуск гранаты, если актор удерживает ее на изготовке
      end;
    end else if (itm<>nil) and (IsKnife(itm) or (GetKickAnimator() = GetSection(itm))) and (pshield_ready^) then begin
      force_shield:=true;
    end;
  end else if IsBurerUnderAim(burer, BurerUnderAimNear) then begin
    LogBurerLogic('AntiDirectAim');
    // Бюрер под прицелом, оружие может стрелять
    if (_gren_count>0) and pshield_ready^ then begin
      force_shield:=true;
    end else if (itm<>nil) and panti_aim_ready^ then begin
      force_antiaim:=true;
    end else if (previous_state^ <> eStateBurerAttack_Shield) and pshield_ready^ then begin
      force_shield:=true;
    end else begin
      pgravi_ready^:=false;
    end;
  end else if (_gren_count>0) and (random < 0.9) then begin
    LogBurerLogic('AntiGrenade');
    // Где-то валяется взведенная граната
    if pshield_ready^ and ((_gren_count > MAX_TELE_GREN_COUNT) or not (ptele_ready^) or (_gren_timer <= GetBurerMinGrenTimer()) or (random < 0.8)) then begin
      force_shield:=true;
    end else if (ptele_ready^) then begin
      force_tele:=true;
    end;
  end else if (itm<>nil) and IsThrowable(itm) then begin
    LogBurerLogic('AntiThrowable');
    //Актор достал гранату, скоро может прилететь. Запрещаем вход в щит до броска или смена оружия
    pshield_ready^:=false;
    //на всякий - отключаем и грави, если актор что-то делает с греной
    if (GetCurrentState(itm) <> EHudStates__eIdle) then begin
      pgravi_ready^:=false;
    end;
  end else if (itm<>nil) and WpnCanShoot(itm) and (GetCurrentState(itm) = EWeaponStates__eReload) and panti_aim_ready^ and (random < 0.9) then begin
    LogBurerLogic('AntiReload');
    force_antiaim:=true;
  end else if (itm<>nil) and WpnCanShoot(itm) and (GetCurrentAmmoCount(itm) = 0) and panti_aim_ready^ and (random < 0.6) then begin
    LogBurerLogic('AntiEmpty');
    force_antiaim:=true;
  end;

  if force_antiaim and panti_aim_ready^ then begin
    LogBurerLogic('force_antiaim');
    pgravi_ready^:=false;
    ptele_ready^:=false;
    pshield_ready^:=false;
    phealthloss^:=false;
  end else if force_shield and (pshield_ready^) then begin
    LogBurerLogic('force_shield');
    panti_aim_ready^:=false;
    pgravi_ready^:=false;
    ptele_ready^:=false;
    phealthloss^:=true;
  end else if force_tele and ptele_ready^ then begin
    LogBurerLogic('force_tele');
    pgravi_ready^:=false;
    pshield_ready^:=false;
    panti_aim_ready^:=false;
    phealthloss^:=false;
  end else if force_gravi and (pgravi_ready^) then begin
    LogBurerLogic('force_gravi');
    pshield_ready^:=false;
    panti_aim_ready^:=false;
    ptele_ready^:=false;
    phealthloss^:=false;
  end;
  LogBurerLogic('End burer attack selector');
end;

procedure CStateBurerAttack__execute_Patch(); stdcall;
asm
  //Original code
  mov eax, [edx+$24]
  call eax   //check_start_conditions

  //save current esp to unused register
  mov edx, esp

  movzx eax, al
  push eax // save copy of tele_ready

  movzx ebx, bl
  push ebx // save copy of gravi_ready

  pushad

  lea ecx, [esi+$08]
  push ecx //prev_substate

  lea ecx, [edx+$16] //shield_ready
  push ecx

  lea ecx, [edx-$4] //tele_ready copy
  push ecx

  lea ecx, [edx-$8] //gravi_ready copy
  push ecx

  lea ecx, [edx+$17]
  push ecx //anti_aim_ready

  lea ecx, [esi+$31]
  push ecx //m_lost_delta_health

  push [esi+$10]  // object (burer)
  call CorrectBurerAttackReadyStatuses

  popad

  pop ebx // restore new gravi_ready
  pop eax //restore new tele_ready
  ret
end;

procedure OverrideBurerStaminaHit(burer:pointer; phit:psingle); stdcall;
var
  itm, wpn:pointer;
  burer_see_actor, eatable_with_hud, wpn_aim_now:boolean;
  campos:FVector3;
  ss_params:burer_superstamina_hit_params;
  cond_dec:single;
begin
  itm:=GetActorActiveItem();
  eatable_with_hud:=false;
  wpn_aim_now:=false;

  if (itm<>nil) then begin
    eatable_with_hud:= game_ini_line_exist(GetSection(itm), 'gwr_changed_object');
    wpn:=dynamic_cast(itm, 0, RTTI_CHudItemObject, RTTI_CWeapon, false);
    if wpn<>nil then begin
      wpn_aim_now:=IsAimNow(wpn);
    end;
  end;

  ss_params:=GetBurerSuperstaminaHitParams();

  campos:=FVector3_copyfromengine(CRenderDevice__GetCamPos());
  burer_see_actor:= (GetActorIfAlive()<>nil) and IsObjectSeePoint(burer, campos, UNCONDITIONAL_VISIBLE_DIST, BURER_HEAD_CORRECTION_HEIGHT, false);

  if (burer_see_actor and (IsActorTooClose(burer, ss_params.distance) or IsInventoryShown() or ((GetCurrentDifficulty()>=gd_stalker) and eatable_with_hud and (random < 0.95)) or IsWeaponReadyForBigBoom(itm, nil) or IsSniperWeapon(itm) or (wpn_aim_now and not IsActorLookTurnedAway(burer)))) or IsBurerUnderAim(burer, BurerUnderAimNear) then begin
    phit^:=ss_params.stamina_decrease;
    if (itm<>nil) and (dynamic_cast(itm, 0, RTTI_CHudItemObject, RTTI_CWeaponMagazined, false)<>nil) then begin
      cond_dec:=ss_params.condition_dec_min + random * (ss_params.condition_dec_max - ss_params.condition_dec_min);
      cond_dec:=GetCurrentCondition(wpn)-cond_dec;
      if cond_dec < 0 then cond_dec:=0;
      SetCondition(wpn, cond_dec);
    end;
  end;
end;

procedure CBurer__StaminaHit_Patch(); stdcall;
asm
  //original
  movss [esp+$3c], xmm0

  lea eax, [esp+$3c]
  pushad
  push eax
  push edi
  call OverrideBurerStaminaHit
  popad
  ret
end;


procedure StaminaHit_ActionsInBeginning(burer:pointer); stdcall;
var
  itm:pointer;
  ss_params:burer_superstamina_hit_params;
  campos:FVector3;
  burer_see_actor:boolean;
  hit:SHit;
  state:cardinal;
  CGrenade:pointer;
begin
  itm:=GetActorActiveItem();
  ss_params:=GetBurerSuperstaminaHitParams();
  campos:=FVector3_copyfromengine(CRenderDevice__GetCamPos());
  burer_see_actor:= (GetActorIfAlive()<>nil) and IsObjectSeePoint(burer, campos, UNCONDITIONAL_VISIBLE_DIST, BURER_HEAD_CORRECTION_HEIGHT, false);
  _last_superstamina_hit_time:=GetGameTickCount();

  if itm<>nil then begin
    if IsKnife(itm) or (GetKickAnimator() = GetSection(itm)) then begin
      if ss_params.force_hide_items_prob < random then begin
        script_call('gunsl_burer.on_close_antiknife', '', GetCObjectID(burer));
        ActivateActorSlot__CInventory(0, true);
        PlanActorKickAnimator('burer_kicks');
      end;
    end else if IsThrowable(itm) then begin
      state:=GetCurrentState(itm);
      CGrenade:=dynamic_cast(itm, 0, RTTI_CHudItemObject, RTTI_CGrenade, false);
      if (CGrenade<>nil) and (state=EMissileStates__eReady) then begin
        PrepareGrenadeForSuicideThrow(CGrenade, 5);
        virtual_Action(itm, kWPN_ZOOM, kActRelease);
      end else if (CGrenade<>nil) and (state=EMissileStates__eThrowStart) then begin
        PrepareGrenadeForSuicideThrow(CGrenade, 5);
        SetImmediateThrowStatus(CGrenade, true);
      end else if (CGrenade<>nil) and (state=EHudStates__eIdle) then begin
        ActivateActorSlot__CInventory(0, false);
        DropItem(GetActor(), itm);
      end;
    end;
  end;

  if (itm<>nil) and IsActorTooClose(burer, GetBurerForceshieldDist()) and (ss_params.power>0) and burer_see_actor then begin
    hit:=MakeDefaultHitForActor();
    hit.power:=ss_params.power;
    hit.impulse:=ss_params.impulse;
    hit.hit_type:=ss_params.hit_type;
    SendHit(@hit);
  end;
end;

procedure CBurer__StaminaHit_ParseThrowableInBeginning_Patch(); stdcall;
asm
  lea ecx, [esp+$28+$8]
  pushad
  push [ecx]
  call StaminaHit_ActionsInBeginning
  popad

  add eax, $2c8;
end;

function CStateBurerShield__check_start_conditions_MayIgnoreCooldown(burer:pointer):boolean; stdcall;
begin
  result:=NeedCloseProtectionShield(burer) or IsBurerUnderAim(burer, BurerUnderAimWide);
end;

procedure CStateBurerShield__check_start_conditions_Patch(); stdcall;
asm
  pushad
  push [ecx+$10]
  call CStateBurerShield__check_start_conditions_MayIgnoreCooldown
  cmp al, 1
  popad
  jne @orig
  ret

  //original code
  @orig:
  add edx, [ecx+$30]
  cmp [eax+$28], edx
  ret
end;

function CStateBurerShield__check_completion_MayIgnoreShieldTime(burer:pointer; last_shield_started:pcardinal):boolean; stdcall;
var
  itm:pointer;
  big_boom_ready, big_boom_shooted, sniper_danger:boolean;
begin
  //вообще не снимаем щит, если рядом грены.
  //более того, после взрыва грены щит может сняться слишком рано, и бюрер успеет получить урон. Чтобы этого не происходило, продлеваем действие щита
  if _gren_count > 0 then begin
    last_shield_started^:=GetGameTickCount();
    result:=true;
    exit;
  end;

  itm:=GetActorActiveItem();
  if (itm<>nil) and IsLongRecharge(itm, 1.5*MIN_ANTIAIM_LOCK_TIME_BEFORE_SHOT) then begin
    result:=false;
    exit;
  end;

  big_boom_ready:=false;
  big_boom_shooted:=false;
  if itm<>nil then begin
    big_boom_ready:=IsWeaponReadyForBigBoom(itm, @big_boom_shooted);
  end;

  sniper_danger:=IsSniperWeapon(itm) and not IsActorLookTurnedAway(burer);
  result:= NeedCloseProtectionShield(burer) or IsBurerUnderAim(burer, BurerUnderAimNear) or sniper_danger or big_boom_shooted or (big_boom_ready and (GetCurrentState(itm) <> EWeaponStates__eReload) and not IsActorLookTurnedAway(burer));

  if result and not big_boom_shooted and (GetCurrentState(itm)=EHudStates__eIdle) then begin
    //TODO: не снимать щит без проверки возможности anti-aim

    result:= random > GetBurerShieldedRiskyFactor();
    if not result and (IsBurerUnderAim(burer, BurerUnderAimExact) or sniper_danger) then begin
      // Если решено рискнуть, но мы под прицелом
      result := not script_bool_call('gunsl_burer.on_risky_under_aim', '', GetCObjectID(burer),'');
    end;

    if not result then begin
      LogBurerLogic('Risky!');
    end;
  end;
end;

procedure CStateBurerShield__check_completion_Patch(); stdcall;
asm
  pushad
  lea eax, [edi+$30] // m_last_shield_started
  push eax
  push [edi+$10]
  call CStateBurerShield__check_completion_MayIgnoreShieldTime
  cmp al, 1
  popad
  jne @orig
  ret

  //original code:
  @orig:
  add ecx, [edi+$30]
  cmp [edx+$28], ecx
  ret
end;

/////////////////////////////////// Телекинез гранатами ////////////////////////////////////////////////

procedure CStateBurerAttack__execute_RefreshGrenCount_Patch(); stdcall;
asm
  pushad
  push $40040006  //target state ID
  push ecx        //buffer for result
  lea ecx, [esp+4]
  push ecx
  lea ecx, [esp+4]
  push ecx
  lea edi,[esi+$18]
  mov ecx, edi //this
  mov eax, xrgame_addr
  add eax, $D29E0
  call eax  //get_state(eStateBurerAttack_Tele)

  mov eax, [esp] //CStateBurerAttackTele instance
  mov ecx, [eax+$14]
  mov edx, [ecx]
  mov eax, [edx+$24]
  call eax //CStateBurerAttackTele::check_start_conditions

  add esp, 8
  popad

  //original
  mov edx, [ecx]
  mov eax, [edx+$20]
end;


procedure CStateBurerAttackTele__CheckTeleStart_callFindObjects_Patch(); stdcall;
asm
  pushad
  mov _gren_count, 0
  mov _gren_timer, $FFFFFFFF
    
  mov ecx, esi
  mov eax, xrgame_addr
  add eax, $109cb0  //CStateBurerAttackTele::FindObjects
  call eax
  popad

  //original
  mov eax,[ecx+$5B8]
end;

procedure OnActiveGrenadeFound(CGrenade:pointer); stdcall;
var
  destroy_time, expl_timer, curr_time:cardinal;
begin
  _gren_count:=_gren_count+1;

  destroy_time:=CMissile__GetDestroyTime(CGrenade);
  curr_time:=GetGameTickCount();

  if destroy_time<=curr_time then begin
    _gren_timer:=0;
  end else begin
    expl_timer:=destroy_time - curr_time;

    if game_ini_r_bool_def(GetSection(CGrenade), 'explosion_on_kick', false) then begin
      _gren_timer:=1;
    end else if expl_timer < _gren_timer then begin
      _gren_timer:=expl_timer;
    end;
  end;
end;


procedure CalcGrenades(v_objects:pxr_vector; reset_counter:boolean); stdcall;
var
  o, g:pointer;
  i, cnt:integer;
begin
  if reset_counter then begin
    _gren_count:=0;
    _gren_timer:=$FFFFFFFF;
  end;

  cnt:=items_count_in_vector(v_objects, sizeof(o));
  for i:=0 to cnt-1 do begin
    o:= pointer(pcardinal(get_item_from_vector(v_objects, i, sizeof(o)))^);
    if o=nil then exit;
    g:=dynamic_cast(o, 0, RTTI_CObject, RTTI_CGrenade, false);
    if (g=nil) or (IsGrenadeDeactivated(g)) then continue;
    OnActiveGrenadeFound(g);
  end;

  LogBurerLogic('CalcGrenades performed, reset='+booltostr(reset_counter, true)+', cnt='+inttostr(_gren_count));
end;

procedure CStateBurerAttackTele__HandleGrenades_RecalcGrenades_Patch(); stdcall;
asm
  pushad
  push 1
  push ebp
  call CalcGrenades
  popad
  //original code
  mov ecx, [ebp+$04]
  sub ecx, [ebp]
  ret
end;

procedure CStateBurerAttackTele__FindFreeObjects_CalcGrenades_Patch(); stdcall;
asm
  pushad
  push 0
  push ebp
  call CalcGrenades
  popad
  //original code
  mov eax, [ebp]
  mov ecx, [ebp+4]
  ret
end;

function IsObjectForbiddenForTele(cpsh:pointer):boolean; stdcall;
begin
  if cpsh = nil then begin
    result:=true;
  end else begin
    result:=not script_bool_call('gunsl_burer.can_tele_object', '', GetCObjectID(cpsh), '');
  end;
end;


procedure CStateBurerAttackTele__FindFreeObjects_CheckTeleObjects_Patch(); stdcall;
asm
  mov ecx, [esp+$1c]
  mov ecx, [ecx+$10]

  pushad
  push esi
  call IsObjectForbiddenForTele
  cmp al, 0
  popad
  je @original

  pop edx       //адрес возврата из врезки
  add esp, $14  //вырезанная инструкция
  cmp edx, 0    //форсируем jne в оригинальном коде
  jmp edx

  @original:
  pop edx //адрес возврата из врезки
  //вырезанные инструкции и уход
  add esp, $14
  test eax, eax
  jmp edx
end;

function IsGrenadeSkipForTele(CGrenade:pointer; burer:pointer):boolean; stdcall;
var
  act:pointer;
  dist:FVector3;
const
  MAX_DIST_TO_ACTOR:single = 5.0;
  MIN_DIST_TO_BURER:single = 5.0;
begin
  result:=IsGrenadeDeactivated(CGrenade);
  if not result then begin
    act:=GetActorIfAlive();
    dist:=FVector3_copyfromengine(GetEntityPosition(act));
    v_sub(@dist, GetPosition(CGrenade));
    if v_length(@dist) < MIN_DIST_TO_BURER then begin
      result:=false;
    end else if act <> nil then begin;
      dist:=FVector3_copyfromengine(GetEntityPosition(act));
      v_sub(@dist, GetPosition(CGrenade));
      LogBurerLogic('gren_dist '+floattostr(v_length(@dist)));
      result:= (v_length(@dist) <= MAX_DIST_TO_ACTOR);
    end;
  end;
  LogBurerLogic('skip grenade: '+booltostr(result, true));
end;

procedure CStateBurerAttackTele__HandleGrenades_OnGrenadeFound_Patch(); stdcall;
asm
  test edi, edi
  je @original //если не граната

  pushad
  mov eax, [esi+$10] //this->object
  push eax
  push edi
  call IsGrenadeSkipForTele
  test al, al
  popad
  je @original
  
  pop eax //адрес возврата из врезки
  //вырезанные инструкции и уход
  add esp, $14
  cmp eax, eax //форсируем переход je в оригинальном коде для пропуска грены
  jmp eax

  @original:
  pop eax //адрес возврата из врезки
  //вырезанные инструкции и уход
  add esp, $14
  test edi,edi
  jmp eax
end;

procedure CStateBurerAttackTele__CheckTeleStart_AfterObjectsSearch_Patch(); stdcall;
asm
  pop esi
  pop ecx
  setne al

  cmp _gren_count, 0
  je @finish
  mov al, 1
  @finish:
  ret
end;

function NeedStopTeleAttack(burer:pointer; time_start:cardinal; time_end:cardinal):boolean; stdcall;
var
  itm:pointer;
  eatable_with_hud:boolean;
  curtime, dtime:cardinal;
  is_long_tele, burer_see_actor:boolean;
  campos:FVector3;
begin
  itm:=GetActorActiveItem();
  result:=false;
  curtime:=GetGameTickCount();
  dtime:=GetTimeDeltaSafe(time_start);
  is_long_tele:=dtime > GetBurerForceTeleFireMinDelta();
  campos:=FVector3_copyfromengine(CRenderDevice__GetCamPos());
  burer_see_actor:=(GetActorIfAlive()<>nil) and IsObjectSeePoint(burer, campos, UNCONDITIONAL_VISIBLE_DIST, BURER_HEAD_CORRECTION_HEIGHT, true);

  //если у нас есть граната, готовая вот-вот взорваться - срочно прекращаем телекинез и уходим в щит!
  if _gren_timer < GetBurerCriticalGrenTimer() then begin
    LogBurerLogic('NeedStopTeleAttack - gren_timer');
    result:=true;
  end else if NeedCloseProtectionShield(burer) then begin
    LogBurerLogic('NeedStopTeleAttack - NeedCloseProtectionShield');
    result:=true;
  end else if WpnCanShoot(itm) and (GetCurrentState(itm) = EWeaponStates__eReload) and burer_see_actor and (random < 0.4) then begin
    LogBurerLogic('NeedStopTeleAttack - Reload');
    result:=true;
  end else if WpnCanShoot(itm) and (GetCurrentAmmoCount(itm) = 0) and burer_see_actor and (random < 0.003) then begin
    LogBurerLogic('NeedStopTeleAttack - Empty');
    result:=true;
  end else if IsSniperWeapon(itm) and not IsActorLookTurnedAway(burer) and burer_see_actor then begin
    LogBurerLogic('NeedStopTeleAttack - Sniper');
    result:=true;
  end else if IsBurerUnderAim(burer, BurerUnderAimNear) then begin
    LogBurerLogic('NeedStopTeleAttack - UnderAim');
    result:=true;
  end else if IsWeaponReadyForBigBoom(itm, nil) and not IsActorLookTurnedAway(burer) and burer_see_actor then begin
    LogBurerLogic('NeedStopTeleAttack - BigBoom');
    result:=true;
  end else if is_long_tele and (itm<>nil) and game_ini_line_exist(GetSection(itm), 'gwr_changed_object') then begin
    LogBurerLogic('NeedStopTeleAttack - eatable');
    result:=true;
  end else if is_long_tele and (itm<>nil) and IsThrowable(itm) and (GetCurrentState(itm) <> EHudStates__eIdle) then begin
    LogBurerLogic('NeedStopTeleAttack - throw_suspect');  
    result:=true;
  end;
end;

procedure CStateBurerAttackTele__check_completion_ForceCompletion_Patch(); stdcall;
asm
  //original
  mov eax, [edx+$28]
  cmp eax, [ecx+$5c]
  ja @finish //прыгаем, если уже решили закончить

  pushad
  push [ecx+$5c] // m_end_tick
  push [ecx+$4c] // time_started
  push [ecx+$10]
  call NeedStopTeleAttack
  cmp al, 0
  popad

  @finish:
  ret
end;

////////////////////////////////////////////////////////////////////////////////////////////////////////
procedure GetOverriddenBoneWeightForVisual(visual:PAnsiChar; weight:psingle); stdcall;
var
  new_mass:single;
begin
  new_mass:=GetOverriddenBoneMassForVisual(visual, weight^);
  if new_mass > 0 then begin
    weight^:=new_mass;
  end;
end;

procedure CKinematics__Load_Patch(); stdcall;
asm
  pushad
  mov ebx, [esp+$578+$20]
  lea eax, [edi+$18c]
  push eax
  push ebx
  call GetOverriddenBoneWeightForVisual
  popad

  //original
  add edi, $190
end;

procedure CStateAbstract__select_state_Patch(); stdcall;
asm
  //original
  mov edi, [esp+$10+4]
  cmp eax, edi
  jne @finish

  //вызываем get_state(current_substate)->check_completion()
  //в eax - current_substate
  cmp eax, -1
  je @finish

  mov [esp+$10+4], eax
  lea eax, [esp+$10+4]
  push eax
  lea ecx, [esp+$0c+4]
  push ecx
  lea ecx, [esi+$18]
  mov eax, xrgame_addr
  add eax, $d29e0
  call eax //get_state
  mov edx, [esp+$8+4]
  mov ecx, [edx+$14]
  mov eax, [ecx]
  mov edx, [eax+$20]
  call edx    //check_completion
  test al, al

  @finish:
  mov eax, [esi+4] // restore current_substate in eax
  ret
end;

function IsWeaponAllowAntiAim(itm:pointer):boolean; stdcall;
var
 curitm:pointer;
begin
  result:=false;
  //чтобы не гадать над типом itm - лучше возьмем сами
  curitm:=GetActorActiveItem();
  if curitm = nil then exit;

  result:= (dynamic_cast(curitm, 0, RTTI_CHudItemObject, RTTI_CWeapon, false)<>nil) or (dynamic_cast(curitm, 0, RTTI_CHudItemObject, RTTI_CGrenade, false)<>nil)
end;

procedure anti_aim_ability__check_update_condition_allowgrenades_Patch(); stdcall;
asm
  // вернуть в eax 0, если антиаим запрещен, и 1 иначе
  pushad
  push eax
  call IsWeaponAllowAntiAim
  test al, al
  popad
  mov eax, 0
  je @finish
  inc eax
  @finish:
  ret
end;

procedure TelekineticObjectKeepUpdate(CTelekinesis:pointer; cpsh:pointer); stdcall;
var
  wpn, act, grenade, burer:pointer;
  buf:WpnBuf;
  burer_pos, act_pos, fp, fp_inv, fd, target_dir, mass_center, v_shoulder, vdiff:FVector3;
  ang_cos:single;
  teleparams:burer_teleweapon_params;
  queue_time:cardinal;
  block_shoot:boolean;
const
  BURER_TREASURE_ANGLE_COS:single = 0.26;
begin
  burer:=dynamic_cast(CTelekinesis, 0, RTTI_CTelekinesis, RTTI_CBurer, false);
  if burer=nil then exit; //не даем стрелять полтергейстам и прочим

  wpn:=dynamic_cast(cpsh, 0, RTTI_CPhysicsShellHolder, RTTI_CWeaponMagazined, false);
  grenade:=dynamic_cast(cpsh, 0, RTTI_CPhysicsShellHolder, RTTI_CGrenade, false);
  act:=GetActorIfAlive();
  block_shoot:=false;


  if (wpn<>nil) and (act<>nil) then begin
    buf:=GetBuffer(wpn);
    if (buf<>nil) then begin
      teleparams:=GetBurerTeleweaponShotParams();
      queue_time:=floor(random*(teleparams.max_shoot_time-teleparams.min_shoot_time) + teleparams.min_shoot_time);

      //Вычисляем вектор от оружия на актора
      fp:=GetLastFP(wpn);
      fd:=GetLastFD(wpn);
      act_pos:=FVector3_copyfromengine(GetEntityPosition(act));
      target_dir:=act_pos;
      v_sub(@target_dir, @fp);

      //Смотрим, куда стреляем, и блокируем стрельбу по самому бюреру
      if (burer<>nil) then begin
        burer_pos:=FVector3_copyfromengine(GetEntityPosition(burer));
        vdiff:=burer_pos;
        v_sub(@vdiff, @fp);
        ang_cos:=GetAngleCos(@vdiff, @fd);
        if ang_cos > BURER_TREASURE_ANGLE_COS then begin
          block_shoot:=true;
        end;
      end;

      ang_cos:=GetAngleCos(@target_dir, @fd);
      if (ang_cos > cos(teleparams.allowed_angle)) and (teleparams.shot_probability>0) then begin
        //Если угол меньше порогового - стреляем
        if not buf.IsShootingWithoutParent() and not block_shoot then begin
          buf.StartShootingWithoutParent(queue_time);
        end;
      end else begin
        //Иначе - вращаем

        //Точка центра масс
        mass_center:=FVector3_copyfromengine(GetPosition(wpn));
        //плечо силы от центра масс до точки приложения fp
        v_shoulder:=fp; v_sub(@v_shoulder, @mass_center);
        //Вторая точка приложения - противосилы
        fp_inv:=mass_center;
        v_sub(@fp_inv, @v_shoulder);

        //Направление перемещения fp
        vdiff.x:=random*2-1;
        vdiff.y:=random*2-1;
        vdiff.z:=random*2-1;
        v_normalize(@vdiff);
        
        ApplyImpulseTrace(cpsh, @fp, @vdiff, teleparams.impulse);
        v_mul(@vdiff, -1);
        ApplyImpulseTrace(cpsh, @fp_inv, @vdiff, teleparams.impulse);

        if not block_shoot and (random < teleparams.shot_probability) and not buf.IsShootingWithoutParent() then begin
          buf.StartShootingWithoutParent(queue_time);
        end;
      end;
    end;
  end else if grenade<>nil then begin
    if CMissile__GetDestroyTime(grenade)<>CMISSILE_NOT_ACTIVATED then begin
      CMissile__SetDestroyTime(grenade, GetGameTickCount()+2000);
    end;
  end;
end;

procedure CTelekineticObject__keep_update_Patch(); stdcall;
asm
  pushad
  mov eax, [ecx+8]
  mov ecx, [ecx+$c]
  push eax
  push ecx
  call TelekineticObjectKeepUpdate
  popad
  ret
end;

procedure TelekineticObjectRaise(cpsh:pointer); stdcall;
var
  grenade:pointer;
begin
  grenade:=dynamic_cast(cpsh, 0, RTTI_CPhysicsShellHolder, RTTI_CGrenade, false);
  if grenade<>nil then begin
    if CMissile__GetDestroyTime(grenade)<>CMISSILE_NOT_ACTIVATED then begin
      CMissile__SetDestroyTime(grenade, GetGameTickCount()+2000);
    end;
  end;
end;

procedure CTelekineticObject__raise_update_Patch(); stdcall;
asm
  mov esi, ecx
  mov eax, [esi+8]
  pushad
  push eax
  call TelekineticObjectRaise
  popad
end;

procedure TelekineticObjectFire(cpsh:pointer); stdcall;
var
  wpn:pointer;
  buf:WpnBuf;
begin
  wpn:=dynamic_cast(cpsh, 0, RTTI_CPhysicsShellHolder, RTTI_CWeaponMagazined, false);
  if wpn<>nil then begin
    buf:=GetBuffer(wpn);
    if (buf<>nil) and buf.IsShootingWithoutParent() then begin
      buf.StopShootingWithoutParent();
    end;
  end;
end;

procedure CTelekineticObject__fire_update_Patch(); stdcall;
asm
  pushad
  mov eax, [ecx+8]
  push eax
  call TelekineticObjectFire
  popad
  add eax, $BB8
  ret
end;

procedure TelekineticObjectPhUpdate (CPhysicsElement:pointer); stdcall;
begin
end;

procedure CTelekineticObject__keep_Patch(); stdcall;
asm
  pushad
  push eax
  call TelekineticObjectPhUpdate
  popad
  mov ecx, [eax]
  lea edx, [esp+$14]
  ret
end;

function ForceFireGraviNow(burer:pointer):boolean; stdcall;
var
  itm:pointer;
begin
  result:=false;
  itm:=GetActorActiveItem();
  if IsBurerUnderAim(burer, BurerUnderAimWide) or ((itm<>nil) and IsWeaponReadyForBigBoom(itm, nil)) then begin
    result:=true;
  end;
end;

procedure CStateBurerAttackGravi__ExecuteGraviContinue_delay_Patch(); stdcall;
asm
  fldcw [esp+4]

  pushad
  mov eax, [ecx+$10]
  push eax
  call ForceFireGraviNow
  cmp al, 1
  popad
  je @force
  cmp edx, [eax+$28]
  ret

  @force:
  xor eax, eax
  cmp al, 2 //to fail jae
  ret
end;

procedure CStateBurerAttackGravi__execute_Patch(); stdcall;
asm
  mov ecx,[eax+$28] //original
  cmp ecx,[esi+$3C] //original
  ja @finish
  pushad
  push [esi+$10] //burer
  call ForceFireGraviNow
  cmp al, 0
  popad
  @finish:
end;

procedure OnGraviAttackFire(enemy:pointer; burer:pointer); stdcall;
var
  actpos:FVector3;
begin
  if (GetActorIfAlive()=nil) or (enemy <> GetActor) then exit;

  actpos:=FVector3_copyfromengine(GetEntityPosition(GetActor()));
  actpos.y:=actpos.y+ACTOR_HEAD_CORRECTION_HEIGHT;
  if IsObjectSeePoint(burer, actpos, UNCONDITIONAL_VISIBLE_DIST, BURER_HEAD_CORRECTION_HEIGHT, true) then begin
    script_call('gunsl_burer.on_gravi_attack_when_burer_see_actor', '', GetCObjectID(burer));
  end;
end;

procedure CStateBurerAttackGravi__ExecuteGraviFire_Patch(); stdcall;
asm
  pushad
  mov ecx, [esi+$10]
  push ecx
  mov ecx, [ecx+$a1c]
  push ecx
  call OnGraviAttackFire
  popad
  pop edi
  pop esi
  pop ebp
  pop ebx
  add esp, $1c
  ret
end;


procedure CBurer__StopTeleObjectParticle(burer:pointer; CGameObject:pointer); stdcall;
asm
  pushad
  mov eax, xrgame_addr
  add eax, $1029b0
  mov ecx, burer
  push CGameObject
  call eax
  popad
end;

procedure OnRemoveObjectFromTelekinesis(CTelekinesis:pointer; cpsh:pointer); stdcall;
var
  cgameobject, burer:pointer;
begin
  if (CTelekinesis=nil) or (cpsh=nil) then exit;
  burer:=dynamic_cast(CTelekinesis, 0, RTTI_CTelekinesis, RTTI_CBurer, false);
  cgameobject:=dynamic_cast(cpsh, 0, RTTI_CPhysicsShellHolder, RTTI_CGameObject, false);
  if (burer<>nil) and (cgameobject<>nil) then begin
    CBurer__StopTeleObjectParticle(burer, cgameobject);
  end;
end;

procedure RemovePred_Patch(); stdcall;
asm
  mov eax, [esp+8] //CTelekineticObject* tele_object
  pushad
  mov ecx, [eax+$c] // CTelekinesis*
  mov ebx, [eax+8] //CPhysicsShellHolder *object
  push ebx
  push ecx
  call OnRemoveObjectFromTelekinesis
  popad
  mov eax, 1
  ret
end;

procedure CTelekinesis__init_savetelekinesis_Patch(); stdcall;
asm

  mov eax, [esp+$10]  //CTelekinesis* tele
  mov [esi+$c], eax   //telekinesis = tele;

  //original
  mov eax, [esi]
  mov edx, [eax+$24]
end;

function CheckGraviHitCondition(burer:pointer; enemy:pointer):boolean; stdcall;
var
  burer_pos, enemy_pos:FVector3;
begin
  result:=false;
  burer_pos:=FVector3_copyfromengine(GetEntityPosition(burer));
  enemy_pos:=FVector3_copyfromengine(GetEntityPosition(enemy));
  v_sub(@enemy_pos, @burer_pos);
  if v_length(@enemy_pos) < UNCONDITIONAL_VISIBLE_DIST then begin
    script_call('gunsl_burer.on_gravi_attack_unconditional', '', GetCObjectID(burer));
    result:=true;
  end;
end;

procedure CBurer__UpdateGraviObject_ForceHit_Patch(); stdcall;
asm
  pop eax //ret addr

  pushad
  push [edi+$a1c]
  push edi
  call CheckGraviHitCondition
  cmp al, 0
  popad

  je @original
  mov [esp+$20], 0 // нулим место вектора visible_objects, чтобы тот не попытался освободиться
  mov eax, xrgame_addr
  add eax, $1037eb
  jmp eax

  @original:
  cmp [esp+$a0], ebx //original
  jmp eax
end;

procedure ProcessGraviHitEffects(burer:pointer; CEntityAlive:pointer); stdcall;
var
  cphmc:pointer;
  dir:FVector3;
begin
  if CEntityAlive = GetActorIfAlive() then begin
    script_call('gunsl_burer.on_gravi_attack_actor_hit', '', GetCObjectID(burer));
    cphmc:=GetCharacterPhysicsSupport(CEntityAlive);
    if (GetBurerGraviImpulseForActor() > 0) and (cphmc<>nil) then begin
      cphmc:=GetCPHMovementControl(cphmc);
      if cphmc<>nil then begin
        dir:=FVector3_copyfromengine(GetEntityPosition(CEntityAlive));
        v_sub(@dir, GetEntityPosition(burer));
        dir.y:=dir.y+0.1;
        v_normalize(@dir);

        CPHMovementControl_ApplyImpulse(cphmc, @dir, GetBurerGraviImpulseForActor());
      end;
    end;
  end;
end;

procedure CBurer__UpdateGraviObject_ActorEffects_Patch(); stdcall;
asm
  mov byte ptr [edi+$9F0],00 //original

  pushad
  mov ecx,[edi+$A1C]
  push ecx
  push edi
  call ProcessGraviHitEffects
  popad
  ret
end;

procedure OverrideTeleAttackTargetPoint(coords:pFVector3; target_object:pointer); stdcall;
var
  bone:PAnsiChar;
begin
  if (target_object<>nil) and (GetActorIfAlive() = target_object) then begin
    bone:=GetBoneNameForBurerTeleFire();
    if length(bone)>0 then begin
      get_bone_position(target_object, bone,  coords);
    end;
  end;
end;

procedure CStateBurerAttackTele__FireAllToEnemy_selecttargetpatch(); stdcall;
asm
  push [esp+8] //дублируем аргумент с указателем на цель
  push [esp+8] //дублируем аргумент с указателем на выходной вектор

  mov eax, xrgame_addr
  add eax, $cf0d0 //get_head_position
  call eax;
  add esp, 8 // снимаем аргументы

  mov edx, [esp+8]
  pushad
  push edx // указатель на цель
  push eax // указатель на буфер с координатами 
  call OverrideTeleAttackTargetPoint
  popad

  pop edx //ret addr
  jmp edx
end;

procedure anti_aim_ability__check_start_condition__candetect_Patch(); stdcall;
asm
  mov eax, 1
  ret
end;

procedure RestoreMinimalStamina(); stdcall;
var
  act, wpn:pointer;
  wpn_dangerous:boolean;
  ss_params:burer_superstamina_hit_params;
const
  SUPERSTAMINA_HIT_PERIOD:cardinal=100;
begin
  act:=GetActorIfAlive();
  wpn := GetActorActiveItem();
  wpn_dangerous:=(wpn<>nil) and (IsSniperWeapon(wpn) or IsWeaponReadyForBigBoom(wpn, nil));
  if (act <> nil) and (not wpn_dangerous) and (GetTimeDeltaSafe(GetLastSuperStaminaHitTime()) < SUPERSTAMINA_HIT_PERIOD) then begin
    ss_params:=GetBurerSuperstaminaHitParams();
    if (GetActorStamina(act) < ss_params.minimal_stamina) and (GetActorHealth(act) > ss_params.minimal_stamina_health) then begin
      SetActorStamina(act, ss_params.minimal_stamina);
    end;
  end;
end;

procedure CBurer__StaminaHit_RestoreMinimalStamina_Patch(); stdcall;
asm
  pushad
    call RestoreMinimalStamina
  popad
  ret 4  //original overwritten return
end;

function CanForceTeleFireOnDeactivate(tele_start_time:cardinal; tele_end_time:cardinal):boolean; stdcall;
var
  curtime, dt:cardinal;
const
  MIN_TELE_INTERVAL:cardinal = 500;
begin
  curtime:=GetGameTickCount();
  LogBurerLogic('tele_start '+inttostr(tele_start_time)+', tele_end '+inttostr(tele_end_time)+', cur '+inttostr(curtime));

  dt:=0;
  if (tele_start_time > 0) then begin
    dt:=GetTimeDeltaSafe(tele_start_time);
  end;

  if (curtime > tele_end_time) or ((_gren_count > 0) and (dt > MIN_TELE_INTERVAL))  then begin
    result:=true;
  end else begin
    result:= (dt > GetBurerForceTeleFireMinDelta());
  end;
  LogBurerLogic('telefire = '+booltostr(result, true));
end;

procedure CStateBurerAttackTele__deactivate_conditionalfireall_Patch(); stdcall;
asm
  pushad
  push [ecx+$5c] // m_end_tick
  push [ecx+$4c] // time_started
  call CanForceTeleFireOnDeactivate
  test al, al
  popad
  je @finish

  pushad
  mov eax, xrgame_addr
  add eax, $104d80
  call eax
  popad

  @finish:
end;

var
  last_fly_impulse_time:cardinal;
  last_fly_period:cardinal;

procedure ActorFly(burer:pointer); stdcall;
var
  act:pointer;
  cphmc:pointer;
  v, v_up, burer_pos, act_pos:FVector3;

  dist_xz, dist_y:single;
  can_fly:boolean;
  params:burer_fly_params;

const
  EPS = 0.0001;

begin
  act:=GetActorIfAlive();
  if (act<>nil) and (GetActorHealth(act)>0)  then begin
    params:=GetBurerFlyParams();

    burer_pos:=FVector3_copyfromengine(GetEntityPosition(burer));
    act_pos:=FVector3_copyfromengine(GetEntityPosition(act));

    v:=burer_pos;
    v_sub(@v, @act_pos);
    dist_xz:= sqrt(v.x*v.x + v.z*v.z);
    can_fly:=(dist_xz < params.critical_dist) or
             (GetTimeDeltaSafe(last_fly_impulse_time) < params.visibility_period) or
             ((GetTimeDeltaSafe(last_fly_impulse_time) > params.cooldown_period) and IsActorTooClose(burer, params.max_dist));


    if (last_fly_period < params.max_time) then begin
      if can_fly and (dist_xz < params.max_dist) then begin
        if dist_xz > params.preferred_dist*1.1 then begin
          v_normalize(@v);
        end else if dist_xz < params.preferred_dist*0.9 then begin
          v_normalize(@v);
          v_mul(@v, -1);
        end else begin
          v_zero(@v);
        end;

        if TraceAsView(@act_pos, @v, dynamic_cast(act, 0, RTTI_CActor, RTTI_CObject, false)) < 3 then begin
          v_zero(@v);
        end;

        dist_y:= abs(burer_pos.y - act_pos.y);
        if (dist_y < params.preferred_height) then begin
         v_up.x:=0; v_up.y:=1; v_up.z:=0;
         if TraceAsView(@act_pos, @v_up, dynamic_cast(act, 0, RTTI_CActor, RTTI_CObject, false)) > 3 then begin
            v.y:= params.vertical_accel;
          end else begin
            v.y:= 0
          end;
        end;

        v_normalize(@v);
        cphmc:=GetCharacterPhysicsSupport(act);
        if (cphmc<>nil) and ((v.x > EPS) or (v.y > EPS) or (v.z > EPS)) then begin
          cphmc:=GetCPHMovementControl(cphmc);
          if cphmc <> nil then begin
            CPHMovementControl_ApplyImpulse(cphmc, @v, params.impulse);

            if last_fly_period = 0 then begin
              last_fly_period:=1;
            end else begin
              last_fly_period:=last_fly_period + GetTimeDeltaSafe(last_fly_impulse_time)
            end;

            last_fly_impulse_time:=GetGameTickCount();
          end;
        end;
      end else if GetTimeDeltaSafe(last_fly_impulse_time) > params.visibility_period then begin
        last_fly_period:=0;
      end;
    end else begin
      last_fly_period:=0;
      last_fly_impulse_time:=GetGameTickCount() - params.visibility_period;
    end;
  end;
end;

procedure CStateBurerAttackTele__execute_ActorFly_Patch(); stdcall;
asm
  pushad
  mov eax, [esi+$10] //this->object
  push eax
  call ActorFly
  popad

  mov eax, [esi+$50] // original
  cmp ax, 03
end;

function NeedForceAttackState(burer:pointer):boolean; stdcall;

begin
  result:=false;
end;

procedure CStateManagerBurer__execute_ForceAttack_Patch(); stdcall;
asm
   // Внимание! Некоторые стейты атаки ожидают, что get_enemy<>nil!

   pushad
   push eax
   call NeedForceAttackState
   cmp al, 0
   popad

   jne @finish
   cmp dword ptr [eax+$5B8],00 // original
   @finish:
end;

procedure CStateBurerAttackTele__check_completion_enemyexist_Patch(); stdcall;
asm
  mov eax,[edx+$5B8] // original
  test eax, eax
  jne @finish
  mov eax, edx //врага нет, берем для расчетов самого бюрера
  @finish:
end;

type
  CTelekineticObject = packed record
    vtable:pointer;
    state:cardinal;
    CPhysicsShellHolder_object:pointer;
    telekinesis:pointer;
    target_height:single;
    time_keep_started:cardinal;
		time_keep_updated:cardinal;
    time_raise_started:cardinal;
    time_to_keep:cardinal;
    time_fire_started:cardinal;
    strength:single;
	  m_rotate:byte;
    _unused1:byte;
    _unused2:word;
    sound_hold:pointer;
    sound_throw:pointer;
  end;
  pCTelekineticObject = ^CTelekineticObject;
  ppCTelekineticObject = ^pCTelekineticObject;
const
  ETelekineticState_TS_Keep:cardinal = 2;

procedure OverrideObjectToThrow(teleobjects:pxr_vector; tele_object:pCTelekineticObject); stdcall;
var
  i:integer;
  o:pCTelekineticObject;
  g:pointer;
begin
  for i:=0 to items_count_in_vector(teleobjects, sizeof(pCTelekineticObject))-1 do begin
    o:=ppCTelekineticObject(get_item_from_vector(teleobjects, i, sizeof(pCTelekineticObject)))^;
    if (o.CPhysicsShellHolder_object <> nil) and (o.state = ETelekineticState_TS_Keep) and (GetTimeDeltaSafe(o.time_keep_started) > 100) and (random < 0.9) then begin
      g:=dynamic_cast(o.CPhysicsShellHolder_object, 0, RTTI_CPhysicsShellHolder, RTTI_CGrenade, false);
      if (g<>nil) then begin
        tele_object.CPhysicsShellHolder_object:=o.CPhysicsShellHolder_object;
        break;
      end;
    end;
  end;
end;

procedure CStateBurerAttackTele__ExecuteTeleContinue_selectgrenades_Patch();stdcall;
asm
  lea ecx,[esp+$0c] // original

  pushad
    mov edx,[esi+$10] // object (burer)
    lea ebx, [edx+$9C0] // telekinetic objects vector

    push ecx // pCTelekineticObject tele_object
    push ebx
    call OverrideObjectToThrow
  popad

  mov eax,[esp+$14] // original
end;

procedure OnTeleFire(o:pointer); stdcall;
var
  g:pointer;
begin
  if o = nil then exit;
  g:=dynamic_cast(o, 0, RTTI_CPhysicsShellHolder, RTTI_CGrenade, false);
  if g<>nil then begin
    if CMissile__GetDestroyTime(g)<>CMISSILE_NOT_ACTIVATED then begin
      CMissile__SetDestroyTime(g, GetGameTickCount()+GetBurerCriticalGrenTimer()-1);
    end;
  end;
end;

procedure CStateBurerAttackTele__ExecuteTeleFire_OnTeleFire_Patch(); stdcall;
asm
  mov eax,[esi+$3C] // original
  mov ecx,[esi+$10]

  pushad
  push eax // selected_object
  call OnTeleFire
  popad
end;

procedure OnTeleFireAll(o:pointer); stdcall;
begin
  OnTeleFire(o);
end;

procedure CStateBurerAttackTele__FireAllToEnemy_OnTeleFire_Patch(); stdcall;
asm
  lea ecx,[eax+$9B0]

  pushad
  push esi // cur_object
  call OnTeleFireAll
  popad
end;

procedure CalcTotalObjectsCount (v:pxr_vector; res:pinteger); stdcall;
begin
  res^:=items_count_in_vector(v, sizeof(pCTelekineticObject));
end;

//ре-имплементация получения полного числа контролируемых объектов для замены неверных вызовов функции
procedure CTelekinesis__get_objects_count_total_reimpl_Patch(); stdcall;
asm
  push eax
  mov eax, esp
  pushad
  push eax // result buffer
  add  ecx, $10
  push ecx // this
  call CalcTotalObjectsCount
  popad
  pop eax
end;

function IsFireAllowed(o:pCTelekineticObject):boolean; stdcall;
begin
  if o = nil then begin
    result:=false;
  end else if (o.state <> ETelekineticState_TS_Keep) then begin
    result:=false;
  end else if (dynamic_cast(o.CPhysicsShellHolder_object, 0, RTTI_CPhysicsShellHolder, RTTI_CGrenade, false) <> nil) then begin
    result:=true;
  end else begin
    result:=random < GetSkipFireAllProbability();
  end;

end;

procedure CStateBurerAttackTele__FireAllToEnemy_CheckSkipTeleFire_Patch(); stdcall;
asm
  mov esi, [esp+$34] //original
  lea ecx, [esp+$2C] //original

  pushad
  push ecx // current pCTelekineticObject
  call IsFireAllowed
  test al, al
  popad
  jne @finish
  xor esi, esi
  @finish:
end;

procedure CStateBurerShield__returntrue_Patch(); stdcall;
asm
  mov eax, 1
end;

function NeedSkipStaminaHit(burer:pointer):boolean; stdcall;
var
  burer_see_actor:boolean;
  campos:FVector3;
begin
  result:=false;

  campos:=FVector3_copyfromengine(CRenderDevice__GetCamPos());
  burer_see_actor:=(GetActorIfAlive()<>nil) and IsObjectSeePoint(burer, campos, UNCONDITIONAL_VISIBLE_DIST, BURER_HEAD_CORRECTION_HEIGHT, true);
  if burer_see_actor then exit;

  if IsBurerUnderAim(burer, BurerUnderAimNear) then exit;

  LogBurerLogic('Skip stamina hit');
  result:=true;
end;

procedure CBurer__StaminaHit_needskip_Patch(); stdcall;
asm
  mov eax, xrgame_addr
  add  eax, $274be0 // GodMode() - original
  call eax
  test eax, eax
  jne @finish

  lea ecx, [esp+$28+$8]
  pushad
  push dword ptr [ecx]
  call NeedSkipStaminaHit
  test al, al
  popad
  je @finish
  mov eax, 1


  @finish:
end;

procedure RunBurerDropAnimator(burer:pointer; do_weapon_drop:byte); stdcall;
begin
  if do_weapon_drop<>0 then begin
    script_call('gunsl_burer.on_drop_animator', '', GetCObjectID(burer));
    PlanActorKickAnimator('burer_kicks');
  end else begin
    script_call('gunsl_burer.on_stamina_hit_nodrop', '', GetCObjectID(burer));
  end;
end;

procedure CBurer__StaminaHit_animateddrop_Patch(); stdcall;
asm
   mov ecx,[eax+$97C]
   fstp dword ptr [esp+4] //original

  pushad
    movzx ebx, bl  // do_weapon_drop
    push ebx
    push edi
    call RunBurerDropAnimator
  popad
end;

procedure anti_aim_ability__start_camera_effector_disablecameffector_Patch(); stdcall;
asm
   //original
   sub edi,[esi+$38]
   sar edi,02

   cmp edi, 0  // m_effectors.size() == 0
//   jne @finish

   mov eax, [esi+$60] // m_animation_end_tick
   mov [esi+$64],eax  // m_camera_effector_end_tick = m_animation_end_tick

   mov [esi+$68], 1 // m_effector_id = 1  - чтобы игра думала, что анима камеры всё-таки проигрывается

   pop eax //ret addr
   mov eax, xrgame_addr
   add eax, $cf9b1
   jmp eax  //skip code before m_callback call

   @finish:
end;


function Init():boolean; stdcall;
var
  jmp_addr:cardinal;
begin
  result:=false;

  //в CBurer::StaminaHit (xrgame+102730) - увеличивает урон стамине, если актор слишком близко
  jmp_addr:=xrGame_addr+$1027a2;
  if not WriteJump(jmp_addr, cardinal(@CBurer__StaminaHit_Patch), 6, true) then exit;

  //в конце CBurer::StaminaHit восстанавливаем минимальную стамину актору
  jmp_addr:=xrGame_addr+$1028e3;
  if not WriteJump(jmp_addr, cardinal(@CBurer__StaminaHit_RestoreMinimalStamina_Patch), 6, false) then exit;

  //в CStateBurerAttack<Object>::execute (xrgame.dll+10ab20) меняем приоритеты, чтобы при приближении актора с наличием стамины эту стамину отнимало
  jmp_addr:=xrGame_addr+$10acb5;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttack__execute_Patch), 5, true) then exit;

  //в CStateBurerShield::check_completion(xrgame+105fc0) не снимаем щит, если актор вплотную, а также переносим время старта щита m_last_shield_started на текущее
  jmp_addr:=xrGame_addr+$105fd2;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerShield__check_completion_Patch), 6, true) then exit;

  //в CStateBurerShield::check_start_conditions (xrgame+105f80) разрешаем уходить в щит всегда, когда актор подобрался слишком близко
  jmp_addr:=xrGame_addr+$105f94;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerShield__check_start_conditions_Patch), 6, true) then exit;

/////
  // в CStateBurerAttackTele<Object>::CheckTeleStart вставляем вызов FindObjects перед проверкой дистанции, чтобы пересчитались гранаты
  jmp_addr:=xrGame_addr+$10a43e;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__CheckTeleStart_callFindObjects_Patch), 6, true) then exit;

  //в CStateBurerAttackTele<Object>::FindFreeObjects (xrgame+1097e0) инкрементим счетчик гранат (это делается на старте стейта, чтобы понять, есть объекты для телекинеза или нет)
  jmp_addr:=xrGame_addr+$109814;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__FindFreeObjects_CalcGrenades_Patch), 6, true) then exit;
  //убираем оригинальный вызов FindObjects в CStateBurerAttackTele<Object>::CheckTeleStart
  if not nop_code(xrGame_addr+$10a497, 5) then exit;

  //в CStateBurerAttackTele<Object>::FindFreeObjects (xrgame+1097e0) проверяем возможность телекинеза объекта
  jmp_addr:=xrGame_addr+$10989b;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__FindFreeObjects_CheckTeleObjects_Patch), 5, true) then exit;

  // в конце CStateBurerAttackTele<Object>::CheckTeleStart проверяем, нашлись ли грены, и если нашлись - разрешаем телекинез
  jmp_addr:=xrGame_addr+$10a4a2;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__CheckTeleStart_AfterObjectsSearch_Patch), 6, false) then exit;
/////

  //Принудительный выход из телекинеза в CStateBurerAttackTele<Object>::check_completion (xrgame+1046b0) (например, в случае, если актор близко или достал РПГ)
  jmp_addr:=xrGame_addr+$104724;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__check_completion_ForceCompletion_Patch), 6, true) then exit;

  //физический хит приходит из CActor::g_Physics через gcontact_HealthLost. ‚ него попадает в CPHMovementControl::UpdateCollisionDamage(xrgame.dll+4feddc)
  //Влияет на величину хита масса кости в модели (которой ударило актора?). Пропишем для костей выбранных моделей СВОЮ массу там, где модель грузится (в CKinematics::Load). Это позволит бюреру использовать визуалы для атаки телекинезом
  if xrRender_R1_addr<>0 then begin
    jmp_addr:=xrRender_R1_addr+$74822;
    if not WriteJump(jmp_addr, cardinal(@CKinematics__Load_Patch), 6, true) then exit;
  end else if xrRender_R2_addr<>0 then begin
    jmp_addr:=xrRender_R2_addr+$9cbe2;
    if not WriteJump(jmp_addr, cardinal(@CKinematics__Load_Patch), 6, true) then exit;
  end else if xrRender_R3_addr<>0 then begin
    jmp_addr:=xrRender_R3_addr+$a9610;
    if not WriteJump(jmp_addr, cardinal(@CKinematics__Load_Patch), 6, true) then exit;
  end else if xrRender_R4_addr<>0 then begin
    jmp_addr:=xrRender_R4_addr+$b3810;
    if not WriteJump(jmp_addr, cardinal(@CKinematics__Load_Patch), 6, true) then exit;
  end;

  // [bug] В CStateAbstract::select_state - если мы захотим войти в тот же стейт, что бы раньше (после его окончания), то сделать этого мы не сможем
  // Для исправления добавим проверку на get_state(current_substate)->check_completion()
  jmp_addr:=xrGame_addr+$11e098;
  if not WriteJump(jmp_addr, cardinal(@CStateAbstract__select_state_Patch), 6, true) then exit;

  // В CStateBurerAttack<Object>::execute перед get_state_current()->check_completion() вызовем get_state(eStateBurerAttack_Tele)->check_start_conditions()
  // Нужно для обновления счетчика гранат  перед проверками на возможность завершения действия в check_completion() (надо в первую очередь чтобы не снимался щит, когда они у нас вокруг грены)
  jmp_addr:=xrGame_addr+$10abf6;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttack__execute_RefreshGrenCount_Patch), 5, true) then exit;

  // в CStateBurerAttackTele<Object>::HandleGrenades увеличиваем частоту сканирования на гранаты
  nop_code(xrgame_addr+$10502e, 1, chr($64));
  nop_code(xrgame_addr+$10502f, 1, chr($00));
  // и уменьшаем максимальное время левитирования гранат
  nop_code(xrgame_addr+$10512b, 1, chr($88));
  nop_code(xrgame_addr+$10512c, 1, chr($13));
  //также в CStateBurerAttackTele<Object>::HandleGrenades после получения списка предметов считаем гранаты для наших нужд
  jmp_addr:=xrGame_addr+$10508b;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__HandleGrenades_RecalcGrenades_Patch), 6, true) then exit;
  //также в CStateBurerAttackTele<Object>::HandleGrenades перерабатываем логику для отсечения неопасных грен и грен под ногами актора
  jmp_addr:=xrGame_addr+$1050c5;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__HandleGrenades_OnGrenadeFound_Patch), 5, true) then exit;

  // [bug] anti_aim_ability::check_update_condition (xrgame+cf750) не позволяет использовать анти-аим с гранатами из-за явного каста к CWeapon. Переделываем.
  jmp_addr:=xrGame_addr+$cf7c1;
  if not WriteJump(jmp_addr, cardinal(@anti_aim_ability__check_update_condition_allowgrenades_Patch), 5, true) then exit;

  //еще одна подстава с анти-аимом  для гранат в CBurer::StaminaHit (xrgame+102730) - не хитует с гранатами в руках
  jmp_addr:=xrGame_addr+$102745;
  if not WriteJump(jmp_addr, cardinal(@CBurer__StaminaHit_ParseThrowableInBeginning_Patch), 5, true) then exit;

  //в CTelekineticObject::keep_update(xrgame.dll+da5f0) добавляем в самый конец включение стрельбы из оружия
  jmp_addr:=xrGame_addr+$da608;
  if not WriteJump(jmp_addr, cardinal(@CTelekineticObject__keep_update_Patch), 5, false) then exit;

  //в начало CTelekineticObject::raise_update(xrgame.dll+da720) добавляем наш обработчик
  jmp_addr:=xrGame_addr+$da721;
  if not WriteJump(jmp_addr, cardinal(@CTelekineticObject__raise_update_Patch), 5, true) then exit;

  //в начало CTelekineticObject::fire_update(xrgame.dll+da610) добавляем наш обработчик
  jmp_addr:=xrGame_addr+$da619;
  if not WriteJump(jmp_addr, cardinal(@CTelekineticObject__fire_update_Patch), 5, true) then exit;

  //Обработчик физического апдейта во время удержания левитирующего предмета
  jmp_addr:=xrGame_addr+$dae09;
  if not WriteJump(jmp_addr, cardinal(@CTelekineticObject__keep_Patch), 6, true) then exit;

  //в CStateBurerAttackGravi::ExecuteGraviContinue добавляем возможность досрочного старта грави-волны
  jmp_addr:=xrGame_addr+$1057E6;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackGravi__ExecuteGraviContinue_delay_Patch), 6, true) then exit;

  //Колбэк на грави-волну в CStateBurerAttackGravi<Object>::ExecuteGraviFire
  jmp_addr:=xrGame_addr+$105666;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackGravi__ExecuteGraviFire_Patch), 8, false) then exit;

  //[bug] баг - в CTelekineticObject есть указатель на бюрера (член telekinesis), но в конструкторе инициализируется нулём и не используется больше нигде (включая CTelekineticObject::init)
  //Присвоим в CTelekineticObject::init (xrgame+da3c0), благо, туда он передается
  jmp_addr:=xrGame_addr+$da3c8;
  if not WriteJump(jmp_addr, cardinal(@CTelekinesis__init_savetelekinesis_Patch), 5, true) then exit;

  //[bug] баг - если схватить парящий предмет в полете, то партикл телекинеза не сбрасывается
  //из вектора телекинетический объект удаляется в CTelekinesis::clear_notrelevant (xrgame.dll+da240)
  //Правим RemovePred (xrgame.dll+d9cc6) - вызываем telekinesis->StopTeleObjectParticle(object);
  jmp_addr:=xrGame_addr+$d9cc6;
  if not WriteJump(jmp_addr, cardinal(@RemovePred_Patch), 5, true) then exit;

  //В CBurer::UpdateGraviObject проверяем, не находится ли цель в "радиусе поражения", и если это так - игнорируем всякие RayPick и переходим к нанесению хита
  jmp_addr:=xrGame_addr+$10349d;
  if not WriteJump(jmp_addr, cardinal(@CBurer__UpdateGraviObject_ForceHit_Patch), 7, true) then exit;

  //В CBurer::UpdateGraviObject после вызова HitEntity добавляем врезку для дополнительных эффектов хита актора
  jmp_addr:=xrGame_addr+$103852;
  if not WriteJump(jmp_addr, cardinal(@CBurer__UpdateGraviObject_ActorEffects_Patch), 7, true) then exit;

  //В CStateBurerAttackGravi::execute при наличии опасности сразу переходим из ACTION_WAIT_ANIM_END в ACTION_COMPLETED
  jmp_addr:=xrGame_addr+$105833;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackGravi__execute_Patch), 6, true) then exit;

  //В anti_aim_ability::check_start_condition удаляем проверку на can_detect, чтобы бюрер мог вырывать ствол в любое время
  jmp_addr:=xrGame_addr+$cf88d;
  if not WriteJump(jmp_addr, cardinal(@anti_aim_ability__check_start_condition__candetect_Patch), 5, true) then exit;

  //В CStateBurerAttackTele<Object>::FireAllToEnemy рандомизируем выбор кости, по которой идёт бросок
  jmp_addr:=xrGame_addr+$104db0;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__FireAllToEnemy_selecttargetpatch), 5, true) then exit;

  //В CStateBurerAttackTele<Object>::deactivate берем контроль на вызовом FireAllToEnemy
  jmp_addr:=xrGame_addr+$1085b7;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__deactivate_conditionalfireall_Patch), 5, true) then exit;

  //В CStateBurerAttackTele::execute управляем полётом актора
  jmp_addr:=xrGame_addr+$107a7b;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__execute_ActorFly_Patch), 6, true) then exit;

  //В CStateManagerBurer::execute форсируем состояние атаки при наличии рядом грен и прочих ништяков
  jmp_addr:=xrGame_addr+$1039ea;
  if not WriteJump(jmp_addr, cardinal(@CStateManagerBurer__execute_ForceAttack_Patch), 7, true) then exit;

  //В CStateBurerAttackTele::check_completion добавляем проверку, что EnemyMan.get_enemy не nil
  jmp_addr:=xrGame_addr+$1046b4;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__check_completion_enemyexist_Patch), 6, true) then exit;

  //В CStateBurerAttackTele::ExecuteTeleContinue стараемся выбирать для броска в первую очередь грены
  jmp_addr:=xrGame_addr+$10545c;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__ExecuteTeleContinue_selectgrenades_Patch), 8, true) then exit;

  //в CStateBurerAttackTele::ExecuteTeleFire обрабатываем событие броска телекинетического предмета
  jmp_addr:=xrGame_addr+$1047bf;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__ExecuteTeleFire_OnTeleFire_Patch), 6, true) then exit;

  //в CStateBurerAttackTele::FireAllToEnemy обрабатываем событие их броска
  jmp_addr:=xrGame_addr+$104e68;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__FireAllToEnemy_OnTeleFire_Patch), 6, true) then exit;

  //////////////////////////////
  //[bug] баг - в CStateBurerAttackTele get_objects_count подразумевается как полное число телекинетируемых объектов, но на самом деле он возвращает число объектов, находящихся сейчас в состоянии raise или keep
  //Из-за этого в CStateBurerAttackTele::FireAllToEnemy при переходе объекта в состояние TS_Fire возвращаемое get_objects_count значение уменьшается на 1, но в реальности вектор не изменяется
  //Итог - цикл перебирает один и тот же предмет в векторе. Решение - надо использовать get_objects_total_count и проверять состояние предмета на TS_Keep

  //Заменяем вызовы get_objects_count в CStateBurerAttackTele::FireAllToEnemy
  jmp_addr:=xrGame_addr+$104dd7;
  if not WriteJump(jmp_addr, cardinal(@CTelekinesis__get_objects_count_total_reimpl_Patch), 5, true) then exit;
  jmp_addr:=xrGame_addr+$104df9;  
  if not WriteJump(jmp_addr, cardinal(@CTelekinesis__get_objects_count_total_reimpl_Patch), 5, true) then exit;
  jmp_addr:=xrGame_addr+$104e7c;  
  if not WriteJump(jmp_addr, cardinal(@CTelekinesis__get_objects_count_total_reimpl_Patch), 5, true) then exit;
  jmp_addr:=xrGame_addr+$104e94;  
  if not WriteJump(jmp_addr, cardinal(@CTelekinesis__get_objects_count_total_reimpl_Patch), 5, true) then exit;
  //в CStateBurerAttackTele::ExecuteTeleContinue
  jmp_addr:=xrGame_addr+$1053b9;  
  if not WriteJump(jmp_addr, cardinal(@CTelekinesis__get_objects_count_total_reimpl_Patch), 5, true) then exit;
  jmp_addr:=xrGame_addr+$105417;  
  if not WriteJump(jmp_addr, cardinal(@CTelekinesis__get_objects_count_total_reimpl_Patch), 5, true) then exit;
  jmp_addr:=xrGame_addr+$105429;
  if not WriteJump(jmp_addr, cardinal(@CTelekinesis__get_objects_count_total_reimpl_Patch), 5, true) then exit;
  //в CStateBurerAttackTele::SelectObjects
  jmp_addr:=xrGame_addr+$109c7b;
  if not WriteJump(jmp_addr, cardinal(@CTelekinesis__get_objects_count_total_reimpl_Patch), 5, true) then exit;
  //в CStateBurerAttackTele::HandleGrenades
  jmp_addr:=xrGame_addr+$105188;
  if not WriteJump(jmp_addr, cardinal(@CTelekinesis__get_objects_count_total_reimpl_Patch), 5, true) then exit;
  //в CStateBurerAttackTele::IsActiveObjects
  jmp_addr:=xrGame_addr+$1045c9;
  if not WriteJump(jmp_addr, cardinal(@CTelekinesis__get_objects_count_total_reimpl_Patch), 5, true) then exit;
  //в CStateBurerAttackTele<Object>::CheckTeleStart (инлайновый IsActiveObjects)
  jmp_addr:=xrGame_addr+$10a42d;
  if not WriteJump(jmp_addr, cardinal(@CTelekinesis__get_objects_count_total_reimpl_Patch), 5, true) then exit;

  //В CStateBurerAttackTele<Object>::FireAllToEnemy добавляем проверку на то, что объект в TS_Keep
  jmp_addr:=xrGame_addr+$104e16;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__FireAllToEnemy_CheckSkipTeleFire_Patch), 8, true) then exit;
  //////////////////////////////

  //в CStateBurerShield::check_start_conditions (xrgame+105f80) убираем проверку на то, что нас видит враг
  jmp_addr:=xrGame_addr+$105f9f;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerShield__returntrue_Patch), 9, false) then exit;

  //в начале CBurer::StaminaHit проверяем, нужно ли пропустить нанесение хита стамине
  jmp_addr:=xrGame_addr+$102733;
  if not WriteJump(jmp_addr, cardinal(@CBurer__StaminaHit_needskip_Patch), 5, true) then exit;

  //в CBurer::StaminaHit запускаем аниматор броска при выхватывании оружия
  jmp_addr:=xrGame_addr+$1027d9;
  if not WriteJump(jmp_addr, cardinal(@CBurer__StaminaHit_animateddrop_Patch), 9, true) then exit;

  //в anti_aim_ability::start_camera_effector отключаем воспроизведение анимации камеры в случае, когда прописан пустой вектор m_effectors
  jmp_addr:=xrGame_addr+$cf8ab;
  if not WriteJump(jmp_addr, cardinal(@anti_aim_ability__start_camera_effector_disablecameffector_Patch), 6, true) then exit;

  //CPHCollisionDamageReceiver::CollisionHit - xrgame+28f970
  //xrgame+$101c60 - CBurer::DeactivateShield

  //CTelekineticObject::keep - xrgame.dll+dac50
  //CTelekinesis::PhDataUpdate - xrgame.dll+d9dd0
  //CTelekineticObject::release - xrgame.dll+da4f0
  //CTelekineticObject::switch_state - xrgame.dll+da4b0
  //CTelekineticObject::init - xrgame.dll+da3c0
  //CTelekineticObject::fire_t - xrgame.dll+da770
  //CTelekineticObject::raise_update - xrgame.dll+da720
  //CTelekineticObject::update_state - xrgame.dll+da480
  //CTelekinesis::schedule_update - xrgame.dll+da0f0
  //CStateBurerAttackGravi::execute - xrgame.dll+105800
  //CStateBurerAttackGravi::ExecuteGraviContinue - xrgame.dll+105730
  //CStateBurerAttackTele::critical_finalize - xrgame.dll+1092a0
  //CStateBurerAttackTele::deactivate - xrgame.dll+1083f0
  //CStateBurerAttackTele::ExecuteTeleFire - xrgame.dll+104740
  //CStateBurerAttackTele::FireAllToEnemy - xrgame.dll+104d80
  //CStateBurerAttackTele::initialize - xrgame.dll+10a40b
  //CStateBurerAttackTele::SelectObjects - xrgame.dll+109b50
  //CStateBurerAttackTele::execute - xrgame.dll+107a70
  //CStateBurerAttackTele::ExecuteTeleContinue - xrgame.dll+105370
  //CTelekinesis::activate - xrgame.dll+da250
  //CTelekinesis::alloc_tele_object - xrgame.dll+da050
  //CBurer::StartTeleObjectParticle - xrgame.dll+1028f0
  //CBurer::StopTeleObjectParticle - xrgame.dll+1029b0
  //CTelekineticObject::init - xrgame.dll+da3c0
  //CBurer::UpdateGraviObject - xrgame.dll+103210
  //CStateBurerAntiAim::check_start_conditions - xrgame.dll+106130
  //anti_aim_ability::check_start_condition - xrgame.dll+cf7e0
  //anti_aim_ability::update_schedule - xrgame.dll+cf9d0
  //anti_aim_ability::load_from_ini - xrgame.dll+cfeb0
  //CStateManagerBurer::execute - xrGame.dll+1039e0

  result:=true;
end;

end.
