unit burer;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

function Init():boolean; stdcall;
function GetLastSuperStaminaHitTime():cardinal; stdcall;

implementation
uses BaseGameData, Misc, MatVectors, ActorUtils, gunsl_config, sysutils, HudItemUtils, RayPick, dynamic_caster, WeaponAdditionalBuffer, HitUtils, Throwable, KeyUtils, math, ScriptFunctors, UIUtils;

var
  _gren_count:cardinal; //��-�������� - ���� ������� ������ ������, �� � ��� ������ - �������������� ��
  _gren_timer:cardinal;
  _last_superstamina_hit_time:cardinal;
  _last_state_select_time:cardinal;

const
  ACTOR_HEAD_CORRECTION_HEIGHT:single = 2;
  BURER_HEAD_CORRECTION_HEIGHT:single = 1;
  UNCONDITIONAL_VISIBLE_DIST:single=3; //����� �� ��������, ����� ����� ��������
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
  act:=GetActor();
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
  act:=GetActor();
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

  force_antiaim:=false;
  force_shield:=false;
  force_tele:=false;
  force_gravi:=false;

  itm:=GetActorActiveItem();
  weapon_for_big_boom:=IsWeaponReadyForBigBoom(itm, @big_boom_shooted);
  sniper_weapon:=IsSniperWeapon(itm);

  eatable_with_hud:=(itm<>nil) and game_ini_line_exist(GetSection(itm), 'gwr_changed_object');

  // �� ����� ��������� ������, ���� ����� ������������� ���������
  if (previous_state^ = eStateBurerAttack_Tele) and (panti_aim_ready^ or pgravi_ready^) then begin
    ptele_ready^:=false;
  end;

  // ���� � ����� � ������ ��� ������, ����� ��� ����� ��� ������ �������� - ������ � ���� ���� ���.
  if (GetActorActiveItem()=nil) and (_gren_count = 0) and not big_boom_shooted then begin
    LogBurerLogic('Disable shield in safe conditions');  
    pshield_ready^:=false;
  end;

  // ���� �� ����� �������� ����� �� ���� � �������������� ������ - �������� ��������� ���
  if (pshield_ready^) and script_bool_call('gunsl_burer.need_disable_shield', '', GetCObjectID(burer), '') then begin
    LogBurerLogic('Script disable shield');
    pshield_ready^:=false;
  end;

  // ����� ������������ ��������� ������ �� ��� � ������� ���������
  if (panti_aim_ready^) and not IsActorLookTurnedAway(burer) and (itm<>nil) and not IsLongRecharge(itm, MIN_GRAVI_LOCK_TIME_BEFORE_SHOT) and (random < 0.85) and IsWeaponDangerous(itm, burer) then begin
    LogBurerLogic('Disable gravi because aim ready');
    pgravi_ready^:=false;
  end;

  if NeedCloseProtectionShield(burer) and (pshield_ready^) then begin
    LogBurerLogic('NeedCloseProtectionShield+ready');
    // ����� ������� ������, ������ ������ � ��������
    if eatable_with_hud and (panti_aim_ready^) then begin
      force_antiaim:=true;
    end else if phealthloss^ then begin
      force_shield:=true;
    end else if sniper_weapon then begin
      pgravi_ready^:=false;
      if (IsLongRecharge(itm, MIN_ANTIAIM_LOCK_TIME_BEFORE_SHOT) or IsActorLookTurnedAway(burer) or (random < 0.3)) and panti_aim_ready^ then begin
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
    LogBurerLogic('AntiHeal');
    // ������� ���������� - �������������
    force_antiaim:=true;
  end else if (itm<>nil) and (IsKnife(itm) or (GetKickAnimator() = GetSection(itm))) and pgravi_ready^ then begin
    LogBurerLogic('AntiKnifeGravi');
    force_gravi:=true;
  end else if IsInventoryShown() and not big_boom_shooted and (_gren_count = 0) and (panti_aim_ready^) then begin
    LogBurerLogic('AntiInventory');
    force_antiaim:=true;
  end else if weapon_for_big_boom or big_boom_shooted then begin
    LogBurerLogic('AntiBigBoom');
    pgravi_ready^:=false;    
    if (not big_boom_shooted) and (previous_state^ = eStateBurerAttack_Shield) and (panti_aim_ready^) then begin
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
    // ����� ��������, �� �� ������� ������ ����
    if (itm<>nil) and panti_aim_ready^ then begin
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
       //TODO:�������������� ����� �������, ���� ����� ���������� �� �� ���������
      end;
    end else if (itm<>nil) and (IsKnife(itm) or (GetKickAnimator() = GetSection(itm))) and (pshield_ready^) then begin
      force_shield:=true;
    end;
  end else if IsBurerUnderAim(burer, BurerUnderAimNear) then begin
    LogBurerLogic('AntiDirectAim');
    // ����� ��� ��������, ������ ����� ��������
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
    // ���-�� �������� ���������� �������
    if pshield_ready^ and ((_gren_count > MAX_TELE_GREN_COUNT) or not (ptele_ready^) or (_gren_timer <= GetBurerMinGrenTimer()) or (random < 0.8)) then begin
      force_shield:=true;
    end else if (ptele_ready^) then begin
      force_tele:=true;
    end;
  end else if (itm<>nil) and IsThrowable(itm) then begin
    LogBurerLogic('AntiThrowable');
    //����� ������ �������, ����� ����� ���������. ��������� ���� � ��� �� ������ ��� ����� ������
    pshield_ready^:=false;
    //�� ������ - ��������� � �����, ���� ����� ���-�� ������ � ������
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
  _last_state_select_time:=GetGameTickCount();
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
  burer_see_actor:= (GetActor()<>nil) and IsObjectSeePoint(burer, campos, UNCONDITIONAL_VISIBLE_DIST, BURER_HEAD_CORRECTION_HEIGHT, false);

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
  burer_see_actor:= (GetActor()<>nil) and IsObjectSeePoint(burer, campos, UNCONDITIONAL_VISIBLE_DIST, BURER_HEAD_CORRECTION_HEIGHT, false);
  _last_superstamina_hit_time:=GetGameTickCount();

  if itm<>nil then begin
    if IsKnife(itm) or (GetKickAnimator() = GetSection(itm)) then begin
      if ss_params.force_hide_items_prob < random then begin
        script_call('gunsl_burer.on_close_antiknife', '', GetCObjectID(burer));
        ActivateActorSlot__CInventory(0, true);
      end;
    end else if IsThrowable(itm) then begin
      state:=GetCurrentState(itm);
      CGrenade:=dynamic_cast(itm, 0, RTTI_CHudItemObject, RTTI_CGrenade, false);
      if (CGrenade<>nil) and (state=EMissileStates__eReady) and not IsBurerUnderAim(burer, BurerUnderAimNear) then begin
        PrepareGrenadeForSuicideThrow(CGrenade, 5);
        virtual_Action(itm, kWPN_ZOOM, kActRelease);
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
  //������ �� ������� ���, ���� ����� �����.
  //����� ����, ����� ������ ����� ��� ����� ������� ������� ����, � ����� ������ �������� ����. ����� ����� �� �����������, ���������� �������� ����
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
    //TODO: �� ������� ��� ��� �������� ����������� anti-aim

    result:= random > GetBurerShieldedRiskyFactor();
    if not result and (IsBurerUnderAim(burer, BurerUnderAimExact) or sniper_danger) then begin
      // ���� ������ ��������, �� �� ��� ��������
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

/////////////////////////////////// ��������� ��������� ////////////////////////////////////////////////

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


procedure CStateBurerAttackTele__CheckTeleStart_BeforeObjectsSearch_Patch(); stdcall;
asm
  mov _gren_count, 0
  mov _gren_timer, $FFFFFFFF
  //original
  add ecx, $9b0
  ret
end;

function IsGrenadeSkipForTele(CGrenade:pointer):boolean; stdcall;
var
  act:pointer;
  act_dist:FVector3;
const
  MAX_DIST_TO_ACTOR:single = 6.0;
begin
  result:=IsGrenadeDeactivated(CGrenade);
  if not result then begin
    act:=GetActor();
    if act <> nil then begin;
      act_dist:=FVector3_copyfromengine(GetEntityPosition(act));
      v_sub(@act_dist, GetPosition(CGrenade));
//      log('gren_dist '+floattostr(v_length(@act_dist)));
      result:= (v_length(@act_dist) <= MAX_DIST_TO_ACTOR);
    end;      
  end;
end;

procedure CStateBurerAttackTele__FindFreeObjects_OnGrenadeFound_ParseDestroyTime(CGrenade:pointer); stdcall;
var
  destroy_time, expl_timer, curr_time:cardinal;
begin
  destroy_time:=CMissile__GetDestroyTime(CGrenade);
  curr_time:=GetGameTickCount();

  if destroy_time<=curr_time then begin
    _gren_timer:=0;
  end else begin
    expl_timer:=destroy_time - curr_time;
    if expl_timer < _gren_timer then begin
      _gren_timer:=expl_timer;
    end;
  end;
end;

function IsObjectForbiddenForTele(burer:pointer; cpsh:pointer):boolean; stdcall;
begin
  result:=false;
end;

procedure CStateBurerAttackTele__FindFreeObjects_OnGrenadeFound_Patch(); stdcall;
asm
  mov ecx, [esp+$1c]
  mov ecx, [ecx+$10]
  test eax, eax
  je @not_grenade

  //���������, ������ �� �������, ��� ��� ���
  pushad
  push eax

  push eax
  call IsGrenadeSkipForTele
  test al, al
  jne @safe
  add _gren_count, 1

  //������, ������� �� ����� �� ������
  push [esp]
  call CStateBurerAttackTele__FindFreeObjects_OnGrenadeFound_ParseDestroyTime

  @safe:
  pop eax
  popad

  @not_grenade:
  pop edx //ret addr
  add esp, $14 //cut action

  pushad
  push esi
  push ecx
  call IsObjectForbiddenForTele
  cmp al, 0
  popad
  je @original
  jmp edx


  @original:
  //perform cut action
  test eax, eax
  jmp edx
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

function NeedStopTeleAttack(burer:pointer):boolean; stdcall;
var
  itm:pointer;
  eatable_with_hud:boolean;
begin
  itm:=GetActorActiveItem();

  //���� � ��� ���� �������, ������� ���-��� ���������� - ������ ���������� ��������� � ������ � ���!
  if _gren_timer < GetBurerMinGrenTimer() / 2 then begin
    result:=true;
    exit;
  end;

  if GetTimeDeltaSafe(_last_state_select_time) < GetBurerForceTeleFireMinDelta() then begin
    result:=false;
    exit;
  end;

  eatable_with_hud:=(itm<>nil) and game_ini_line_exist(GetSection(itm), 'gwr_changed_object');
  result:=(eatable_with_hud and (GetCurrentDifficulty()>=gd_veteran)) or NeedCloseProtectionShield(burer) or (IsSniperWeapon(itm) and not IsActorLookTurnedAway(burer)) or IsBurerUnderAim(burer, BurerUnderAimNear) or (IsWeaponReadyForBigBoom(itm, nil) and not IsActorLookTurnedAway(burer)) or ((itm<>nil) and IsThrowable(itm) and (GetCurrentState(itm) <> EHudStates__eIdle));
end;

procedure CStateBurerAttackTele__check_completion_ForceCompletion_Patch(); stdcall;
asm
  //original
  mov eax, [edx+$28]
  cmp eax, [ecx+$5c]
  ja @finish //�������, ���� ��� ������ ���������

  pushad
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

  //�������� get_state(current_substate)->check_completion()
  //� eax - current_substate
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
  //����� �� ������ ��� ����� itm - ����� ������� ����
  curitm:=GetActorActiveItem();
  if curitm = nil then exit;

  result:= (dynamic_cast(curitm, 0, RTTI_CHudItemObject, RTTI_CWeapon, false)<>nil) or (dynamic_cast(curitm, 0, RTTI_CHudItemObject, RTTI_CGrenade, false)<>nil)
end;

procedure anti_aim_ability__check_update_condition_allowgrenades_Patch(); stdcall;
asm
  // ������� � eax 0, ���� ������� ��������, � 1 �����
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
  if burer=nil then exit; //�� ���� �������� ������������� � ������

  wpn:=dynamic_cast(cpsh, 0, RTTI_CPhysicsShellHolder, RTTI_CWeaponMagazined, false);
  grenade:=dynamic_cast(cpsh, 0, RTTI_CPhysicsShellHolder, RTTI_CGrenade, false);
  act:=GetActor();
  block_shoot:=false;


  if (wpn<>nil) and (act<>nil) then begin
    buf:=GetBuffer(wpn);
    if (buf<>nil) then begin
      teleparams:=GetBurerTeleweaponShotParams();
      queue_time:=floor(random*(teleparams.max_shoot_time-teleparams.min_shoot_time) + teleparams.min_shoot_time);

      //��������� ������ �� ������ �� ������
      fp:=GetLastFP(wpn);
      fd:=GetLastFD(wpn);
      act_pos:=FVector3_copyfromengine(GetEntityPosition(act));
      target_dir:=act_pos;
      v_sub(@target_dir, @fp);

      //�������, ���� ��������, � ��������� �������� �� ������ ������
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
        //���� ���� ������ ���������� - ��������
        if not buf.IsShootingWithoutParent() and not block_shoot then begin
          buf.StartShootingWithoutParent(queue_time);
        end;
      end else begin
        //����� - �������

        //����� ������ ����
        mass_center:=FVector3_copyfromengine(GetPosition(wpn));
        //����� ���� �� ������ ���� �� ����� ���������� fp
        v_shoulder:=fp; v_sub(@v_shoulder, @mass_center);
        //������ ����� ���������� - �����������
        fp_inv:=mass_center;
        v_sub(@fp_inv, @v_shoulder);

        //����������� ����������� fp
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
  fldcw [esp]
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

procedure OnGraviAttackFire(burer:pointer); stdcall;
var
  actpos:FVector3;
begin
  if GetActor()=nil then exit;

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
  mov [esp+$20], 0 // ����� ����� ������� visible_objects, ����� ��� �� ��������� ������������
  mov eax, xrgame_addr
  add eax, $1037eb
  jmp eax

  @original:
  cmp [esp+$a0], ebx //original
  jmp eax
end;

procedure anti_aim_ability__check_start_condition__candetect_Patch(); stdcall;
asm
  mov eax, 1
  ret
end;

function Init():boolean; stdcall;
var
  jmp_addr:cardinal;
begin
  result:=false;

  //� CBurer::StaminaHit (xrgame+102730) - ����������� ���� �������, ���� ����� ������� ������
  jmp_addr:=xrGame_addr+$1027a2;
  if not WriteJump(jmp_addr, cardinal(@CBurer__StaminaHit_Patch), 6, true) then exit;

  //� CStateBurerAttack<Object>::execute (xrgame.dll+10ab20) ������ ����������, ����� ��� ����������� ������ � �������� ������� ��� ������� ��������
  jmp_addr:=xrGame_addr+$10acb5;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttack__execute_Patch), 5, true) then exit;

  //� CStateBurerShield::check_completion(xrgame+105fc0) �� ������� ���, ���� ����� ��������, � ����� ��������� ����� ������ ���� m_last_shield_started �� �������
  jmp_addr:=xrGame_addr+$105fd2;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerShield__check_completion_Patch), 6, true) then exit;

  //� CStateBurerShield::check_start_conditions (xrgame+105f80) ��������� ������� � ��� ������, ����� ����� ���������� ������� ������
  jmp_addr:=xrGame_addr+$105f94;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerShield__check_start_conditions_Patch), 6, true) then exit;

  // � ������ CStateBurerAttackTele<Object>::CheckTeleStart ���������� ������� ������ ������ ����� ���, ��� ������������ �������
  jmp_addr:=xrGame_addr+$10a427;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__CheckTeleStart_BeforeObjectsSearch_Patch), 6, true) then exit;

  // � ����� CStateBurerAttackTele<Object>::CheckTeleStart ���������, ������� �� �����, � ���� ������� - ��������� ���������
  jmp_addr:=xrGame_addr+$10a4a2;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__CheckTeleStart_AfterObjectsSearch_Patch), 6, false) then exit;

  //� CStateBurerAttackTele<Object>::FindFreeObjects (xrgame+1097e0) ����������� ������� ������
  jmp_addr:=xrGame_addr+$10989b;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__FindFreeObjects_OnGrenadeFound_Patch), 5, true) then exit;

  //�������������� ����� �� ���������� � CStateBurerAttackTele<Object>::check_completion (xrgame+1046b0) (��������, � ������, ���� ����� ������ ��� ������ ���)
  jmp_addr:=xrGame_addr+$104724;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__check_completion_ForceCompletion_Patch), 6, true) then exit;

  //���������� ��� �������� �� CActor::g_Physics ����� gcontact_HealthLost. � ���� �������� � CPHMovementControl::UpdateCollisionDamage(xrgame.dll+4feddc)
  //������ �� �������� ���� ����� ����� � ������ (������� ������� ������?). �������� ��� ������ ��������� ������� ���� ����� ���, ��� ������ �������� (� CKinematics::Load). ��� �������� ������ ������������ ������� ��� ����� �����������
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

  // [bug] � CStateAbstract::select_state - ���� �� ������� ����� � ��� �� �����, ��� �� ������ (����� ��� ���������), �� ������� ����� �� �� ������
  // ��� ����������� ������� �������� �� get_state(current_substate)->check_completion()
  jmp_addr:=xrGame_addr+$11e098;
  if not WriteJump(jmp_addr, cardinal(@CStateAbstract__select_state_Patch), 6, true) then exit;

  // � CStateBurerAttack<Object>::execute ����� get_state_current()->check_completion() ������� get_state(eStateBurerAttack_Tele)->check_start_conditions()
  // ����� ��� ���������� �������� ������  ����� ���������� �� ����������� ���������� �������� � check_completion() (���� � ������ ������� ����� �� �������� ���, ����� ��� � ��� ������ �����)
  jmp_addr:=xrGame_addr+$10abf6;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttack__execute_RefreshGrenCount_Patch), 5, true) then exit;

  // � CStateBurerAttackTele<Object>::HandleGrenades ����������� ������� ������������ �� �������
  nop_code(xrgame_addr+$10502e, 1, chr($64));
  nop_code(xrgame_addr+$10502f, 1, chr($00));
  // � ��������� ������������ ����� ������������� ������  
  nop_code(xrgame_addr+$10512b, 1, chr($88));
  nop_code(xrgame_addr+$10512c, 1, chr($13));

  // [bug] anti_aim_ability::check_update_condition (xrgame+cf750) �� ��������� ������������ ����-��� � ��������� ��-�� ������ ����� � CWeapon. ������������.
  jmp_addr:=xrGame_addr+$cf7c1;
  if not WriteJump(jmp_addr, cardinal(@anti_aim_ability__check_update_condition_allowgrenades_Patch), 5, true) then exit;

  //��� ���� �������� � ����-�����  ��� ������ � CBurer::StaminaHit (xrgame+102730) - �� ������ � ��������� � �����
  jmp_addr:=xrGame_addr+$102745;
  if not WriteJump(jmp_addr, cardinal(@CBurer__StaminaHit_ParseThrowableInBeginning_Patch), 5, true) then exit;

  //� CTelekineticObject::keep_update(xrgame.dll+da5f0) ��������� � ����� ����� ��������� �������� �� ������
  jmp_addr:=xrGame_addr+$da608;
  if not WriteJump(jmp_addr, cardinal(@CTelekineticObject__keep_update_Patch), 5, false) then exit;

  //� ������ CTelekineticObject::raise_update(xrgame.dll+da720) ��������� ��� ����������
  jmp_addr:=xrGame_addr+$da721;
  if not WriteJump(jmp_addr, cardinal(@CTelekineticObject__raise_update_Patch), 5, true) then exit;

  //� ������ CTelekineticObject::fire_update(xrgame.dll+da610) ��������� ��� ����������
  jmp_addr:=xrGame_addr+$da619;
  if not WriteJump(jmp_addr, cardinal(@CTelekineticObject__fire_update_Patch), 5, true) then exit;

  //���������� ����������� ������� �� ����� ��������� ������������� ��������
  jmp_addr:=xrGame_addr+$dae09;
  if not WriteJump(jmp_addr, cardinal(@CTelekineticObject__keep_Patch), 6, true) then exit;

  //� CStateBurerAttackGravi::ExecuteGraviContinue ��������� ����������� ���������� ������ �����-�����
  jmp_addr:=xrGame_addr+$1057E6;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackGravi__ExecuteGraviContinue_delay_Patch), 6, true) then exit;

  //������ �� �����-����� � CStateBurerAttackGravi<Object>::ExecuteGraviFire
  jmp_addr:=xrGame_addr+$105666;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackGravi__ExecuteGraviFire_Patch), 8, false) then exit;

  //[bug] ��� - � CTelekineticObject ���� ��������� �� ������ (���� telekinesis), �� � ������������ ���������������� ���� � �� ������������ ������ ����� (������� CTelekineticObject::init)
  //�������� � CTelekineticObject::init (xrgame+da3c0), �����, ���� �� ����������
  jmp_addr:=xrGame_addr+$da3c8;
  if not WriteJump(jmp_addr, cardinal(@CTelekinesis__init_savetelekinesis_Patch), 5, true) then exit;

  //[bug] ��� - ���� �������� ������� ������� � ������, �� ������� ���������� �� ������������
  //�� ������� ���������������� ������ ��������� � CTelekinesis::clear_notrelevant (xrgame.dll+da240)
  //������ RemovePred (xrgame.dll+d9cc6) - �������� telekinesis->StopTeleObjectParticle(object);
  jmp_addr:=xrGame_addr+$d9cc6;
  if not WriteJump(jmp_addr, cardinal(@RemovePred_Patch), 5, true) then exit;

  //� CBurer::UpdateGraviObject ���������, �� ��������� �� ���� � "������� ���������", � ���� ��� ��� - ���������� ������ RayPick � ��������� � ��������� ����
  jmp_addr:=xrGame_addr+$10349d;
  if not WriteJump(jmp_addr, cardinal(@CBurer__UpdateGraviObject_ForceHit_Patch), 7, true) then exit;

  //� CStateBurerAttackGravi::execute ��� ������� ��������� ����� ��������� �� ACTION_WAIT_ANIM_END � ACTION_COMPLETED
  jmp_addr:=xrGame_addr+$105833;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackGravi__execute_Patch), 6, true) then exit;

  //� anti_aim_ability::check_start_condition ������� �������� �� can_detect, ����� ����� ��� �������� ����� � ����� �����
  jmp_addr:=xrGame_addr+$cf88d;
  if not WriteJump(jmp_addr, cardinal(@anti_aim_ability__check_start_condition__candetect_Patch), 5, true) then exit;

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
  //CStateBurerAttackTele::initialize - xrgame.dll+10a40b
  //CStateBurerAttackTele::SelectObjects - xrgame.dll+109b50
  //CTelekinesis::activate - xrgame.dll+da250
  //CTelekinesis::alloc_tele_object - xrgame.dll+da050
  //CBurer::StartTeleObjectParticle - xrgame.dll+1028f0
  //CBurer::StopTeleObjectParticle - xrgame.dll+1029b0
  //CTelekineticObject::init - xrgame.dll+da3c0
  //CBurer::UpdateGraviObject - xrgame.dll+103210
  //CStateBurerAntiAim::check_start_conditions - xrgame.dll+106130
  //anti_aim_ability::check_start_condition - xrgame.dll+cf7e0

  result:=true;
end;

end.
