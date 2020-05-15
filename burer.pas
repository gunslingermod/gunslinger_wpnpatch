unit burer;

interface

function Init():boolean; stdcall;

implementation
uses BaseGameData, Misc, MatVectors, ActorUtils, gunsl_config, sysutils, HudItemUtils, RayPick, dynamic_caster, WeaponAdditionalBuffer;

var
  _gren_count:cardinal; //по-хорошему - надо сделать членом класса, но и так сойдет - однопоточность же

const
  ACTOR_HEAD_CORRECTION_HEIGHT:single = 2;
  BURER_HEAD_CORRECTION_HEIGHT:single = 1;
  UNCONDITIONAL_VISIBLE_DIST:single=2; //чтобы не фейлитс€, когда актор вплотную

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
  end else if IsKnife(itm) and IsActorTooClose(burer, GetBurerForceantiaimDist()) then begin
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

function IsWeaponReadyForBigBoom(itm:pointer):boolean; stdcall;
var
  gl_status:cardinal;
  buf:WpnBuf;
const
  SHOT_SAFETY_TIME_DELTA:cardinal=2000;
begin
  result:=false;
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
      if (buf<>nil) and (GetCurrentAmmoCount(itm) = 0) and (buf.GetLastShotTimeDelta() > SHOT_SAFETY_TIME_DELTA) then begin
        result:=false;
      end;
    end;
  end;
end;

function IsBurerUnderAim(burer:pointer):boolean; stdcall;
begin
  result:=false;
  if IsWeaponDangerous(GetActorActiveItem(), burer) then begin
    if TraceAsView_RQ(CRenderDevice__GetCamPos(), CRenderDevice__GetCamDir(), GetActor()).O = burer then begin
      result:=true;
    end;
  end;
end;

function NeedMandatoryShield(burer:pointer):boolean; stdcall;
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

procedure CorrectBurerAttackReadyStatuses(burer:pointer; pshieldcondition:pboolean; panti_aim_ready:pboolean; pgravi_ready:pboolean; ptele_ready:pboolean; pshield_ready:pboolean); stdcall;
var
  actor_close, actor_very_close:boolean;
  itm:pointer;
  force_antiaim, force_shield, force_tele, force_gravi:boolean;
  weapon_for_big_boom, eatable_with_hud:boolean;
begin
  force_antiaim:=false;
  force_shield:=false;
  force_tele:=false;
  force_gravi:=false;

  itm:=GetActorActiveItem();
  weapon_for_big_boom:=IsWeaponReadyForBigBoom(itm);

  eatable_with_hud:=(itm<>nil) and game_ini_line_exist(GetSection(itm), 'gwr_changed_object');

  if NeedMandatoryShield(burer) and (pshield_ready^) then begin
    force_shield:=true;
  end else if (itm<>nil) and IsThrowable(itm) and ptele_ready^  and (random < 0.9) then begin
    force_tele:=true;
  end else if (GetCurrentDifficulty()>=gd_stalker) and eatable_with_hud and panti_aim_ready^ and (random < 0.95) then begin
    force_antiaim:=true;
  end else if weapon_for_big_boom then begin
    if IsBurerUnderAim(burer) and (pshield_ready^) then begin
      force_shield:=true;
    end else if panti_aim_ready^ then begin
      force_antiaim:=true;
    end else if (pshield_ready^) then begin
      force_shield:=true;
    end
  end else if IsActorTooClose(burer, GetBurerForceantiaimDist()) then begin
    if (itm<>nil) and panti_aim_ready^ then begin
      force_antiaim:=true;
    end else if IsActorLookTurnedAway(burer) and (pgravi_ready^) then begin
      if (_gren_count>0) and (ptele_ready^) and (random < 0.8)  then begin
        force_tele:=true;
      end else begin
        force_gravi:=true;
      end;
    end else if (itm<>nil) and IsKnife(itm) and (pshield_ready^) then begin
      force_shield:=true;
    end;
  end else if IsBurerUnderAim(burer) then begin
    if (itm<>nil) and panti_aim_ready^ then begin
      force_antiaim:=true;
    end;
  end else if (_gren_count>0) and (random < 0.6) then begin
    if (ptele_ready^) then begin
      force_tele:=true;
    end else if pshield_ready^ then begin
      force_shield:=true;
    end;
  end;

  if force_antiaim and panti_aim_ready^ then begin
    pgravi_ready^:=false;
    ptele_ready^:=false;
    pshield_ready^:=false;
  end else if force_shield and (pshield_ready^) then begin
    panti_aim_ready^:=false;
    pgravi_ready^:=false;
    ptele_ready^:=false;
    pshieldcondition^:=true;
  end else if force_tele and ptele_ready^ then begin
    pgravi_ready^:=false;
    pshield_ready^:=false;
    panti_aim_ready^:=false;
  end else if force_gravi and (pgravi_ready^) then begin
    pshield_ready^:=false;
    panti_aim_ready^:=false;
    ptele_ready^:=false;
  end;
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
  itm, wpn, act:pointer;
  wpn_aim_now, burer_see_actor, eatable_with_hud:boolean;
  campos:FVector3;
begin
  wpn_aim_now:=false;
  itm:=GetActorActiveItem();
  eatable_with_hud:=game_ini_line_exist(GetSection(itm), 'gwr_changed_object');

  if itm<>nil then begin
    if IsKnife(itm) or IsThrowable(itm) then begin
      ActivateActorSlot__CInventory(0, true);
    end;

    wpn:=dynamic_cast(itm, 0, RTTI_CHudItemObject, RTTI_CWeapon, false);
    if wpn<>nil then begin
      wpn_aim_now:=IsAimNow(wpn);
    end;
  end;

  campos:=FVector3_copyfromengine(CRenderDevice__GetCamPos());
  burer_see_actor:= (GetActor()<>nil) and IsObjectSeePoint(burer, campos, UNCONDITIONAL_VISIBLE_DIST, BURER_HEAD_CORRECTION_HEIGHT, false);

  if (burer_see_actor and (IsActorTooClose(burer, GetBurerSuperstaminahitDist()) or ((GetCurrentDifficulty()>=gd_veteran) and eatable_with_hud and (random < 0.95)) or IsWeaponReadyForBigBoom(itm) or (wpn_aim_now and not IsActorLookTurnedAway(burer)))) or IsBurerUnderAim(burer) then begin
    phit^:=GetBurerSuperstaminahitValue;
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

function CStateBurerShield__check_start_conditions_MayIgnoreCooldown(burer:pointer):boolean; stdcall;
begin
  result:=NeedMandatoryShield(burer);
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

function CStateBurerShield__check_completion_MayIgnoreShieldTime(burer:pointer):boolean; stdcall;
var
  itm:pointer;
begin
  itm:=GetActorActiveItem();

  //TODO: не снимаем щит, если р€дом грены
  result:=NeedMandatoryShield(burer) or IsBurerUnderAim(burer) or (IsWeaponReadyForBigBoom(itm) and not IsActorLookTurnedAway(burer) and (GetCurrentState(itm) <> EWeaponStates__eReload) );

  if result then begin
    //TODO: не снимать щит без проверки возможности anti-aim
    result:= random > GetBurerShieldedRiskyFactor();
  end;
end;

procedure CStateBurerShield__check_completion_Patch(); stdcall;
asm
  pushad
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

/////////////////////////////////// “елекинез гранатами ////////////////////////////////////////////////

procedure CStateBurerAttackTele__CheckTeleStart_BeforeObjectsSearch_Patch(); stdcall;
asm
  mov _gren_count, 0
  //original
  add ecx, $9b0
  ret
end;

procedure CStateBurerAttackTele__FindFreeObjects_OnGrenadeFound_Patch(); stdcall;
asm
  test eax, eax
  je @not_grenade
  add _gren_count, 1

  @not_grenade:
  //perform cut actions
  pop edx //ret addr
  add esp, $14
  test eax, eax
  jmp edx
end;

function NeedForceBurerTele():boolean; stdcall;
var
  itm:pointer;
begin
  itm:=GetActorActiveItem();
  result:= (_gren_count > 0) or ((itm<>nil) and IsThrowable(itm) and (GetCurrentState(itm) <> EHudStates__eIdle));
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
  eatable_with_hud:=(itm<>nil) and game_ini_line_exist(GetSection(itm), 'gwr_changed_object');
  result:=(eatable_with_hud and (GetCurrentDifficulty()>=gd_veteran)) or NeedMandatoryShield(burer) or IsBurerUnderAim(burer) or (IsWeaponReadyForBigBoom(itm) and not IsActorLookTurnedAway(burer));
end;

procedure CStateBurerAttackTele__check_completion_ForceCompletion_Patch(); stdcall;
asm
  //original
  mov eax, [edx+$28]
  cmp eax, [ecx+$5c]
  ja @finish //прыгаем, если уже решили закончить

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


function Init():boolean; stdcall;
var
  jmp_addr:cardinal;
begin
  result:=false;

  //в CBurer::StaminaHit (xrgame+102730) - увеличивает урон стамине, если актор слишком близко
  jmp_addr:=xrGame_addr+$1027a2;
  if not WriteJump(jmp_addr, cardinal(@CBurer__StaminaHit_Patch), 6, true) then exit;

  //в CStateBurerAttack<Object>::execute (xrgame.dll+10ab20) мен€ем приоритеты, чтобы при приближении актора с наличием стамины эту стамину отнимало
  jmp_addr:=xrGame_addr+$10acb5;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttack__execute_Patch), 5, true) then exit;

  //в CStateBurerShield::check_completion(xrgame+105fc0) не снимаем щит, если актор вплотную, а также переносим врем€ старта щита m_last_shield_started на текущее
  jmp_addr:=xrGame_addr+$105fd2;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerShield__check_completion_Patch), 6, true) then exit;

  //в CStateBurerShield::check_start_conditions (xrgame+105f80) разрешаем уходить в щит всегда, когда актор подобралс€ слишком близко
  jmp_addr:=xrGame_addr+$105f94;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerShield__check_start_conditions_Patch), 6, true) then exit;

  // в начале CStateBurerAttackTele<Object>::CheckTeleStart сбрасываем счетчик гранат вокруг перед тем, как начатьискать объекты
  jmp_addr:=xrGame_addr+$10a427;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__CheckTeleStart_BeforeObjectsSearch_Patch), 6, true) then exit;

  // в конце CStateBurerAttackTele<Object>::CheckTeleStart провер€ем, нашлись ли грены, и если нашлись - разрешаем телекинез
  jmp_addr:=xrGame_addr+$10a4a2;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__CheckTeleStart_AfterObjectsSearch_Patch), 6, false) then exit;

  //в CStateBurerAttackTele<Object>::FindFreeObjects (xrgame+1097e0) инкрементим счетчик гранат
  jmp_addr:=xrGame_addr+$10989b;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__FindFreeObjects_OnGrenadeFound_Patch), 5, true) then exit;

  //ѕринудительный выход из телекинеза в CStateBurerAttackTele<Object>::check_completion (xrgame+1046b0) (например, в случае, если актор близко или достал –ѕ√)
  jmp_addr:=xrGame_addr+$104724;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__check_completion_ForceCompletion_Patch), 6, true) then exit;

  //физический хит приходит из CActor::g_Physics через gcontact_HealthLost. В него попадает в CPHMovementControl::UpdateCollisionDamage(xrgame.dll+4feddc)
  //¬ли€ет на величину хита масса кости в модели (которой ударило актора?). ѕропишем дл€ костей выбранных моделей —¬ќё массу там, где модель грузитс€ (в CKinematics::Load). Ёто позволит бюреру использовать визуалы дл€ атаки телекинезом
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

  // [bug] ¬ CStateAbstract::select_state - если мы захотим войти в тот же стейт, что бы раньше (после его окончани€), то сделать этого мы не сможем
  // ƒл€ исправлени€ добавим проверку на get_state(current_substate)->check_completion()
  jmp_addr:=xrGame_addr+$11e098;
  if not WriteJump(jmp_addr, cardinal(@CStateAbstract__select_state_Patch), 6, true) then exit;

  // ¬ CStateBurerAttack<Object>::execute перед get_state_current()->check_completion() вызовем get_state(eStateBurerAttack_Tele)->check_start_conditions() дл€ обновлени€ счетчика гранат (чтобы не снимать щит, когда они р€дом)


  //Ќа будущее:
  //todo:включаем грави только когда опасность минимальна (чтобы актор не успел подстрелить нас, пока мы кастуемс€)
  //TODO: при попадании в щит - продлеваем защиту

  //CPHCollisionDamageReceiver::CollisionHit - xrgame+28f970

  result:=true;
end;

end.
