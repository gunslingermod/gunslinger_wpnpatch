unit burer;

interface

function Init():boolean; stdcall;

implementation
uses BaseGameData, Misc, MatVectors, ActorUtils, gunsl_config, sysutils, HudItemUtils, RayPick, dynamic_caster, WeaponAdditionalBuffer;


function IsActorTooClose(burer:pointer; close_dist:single):boolean; stdcall;
var
  act:pointer;
  act_pos, dist:FVector3;
  len:single;
const
  ACTOR_HEAD_CORRECTION_HEIGHT:single = 2;
  BURER_HEAD_CORRECTION_HEIGHT:single = 1;
  UNCONDITIONAL_VISIBLE_DIST:single=2; //чтобы не фейлится, когда актор вплотную
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
      log('GetLastShotTimeDelta '+inttostr(buf.GetLastShotTimeDelta()));
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
  force_antiaim, force_shield, force_tele:boolean;
  weapon_for_big_boom:boolean;
begin
  force_antiaim:=false;
  force_shield:=false;
  force_tele:=false;


  itm:=GetActorActiveItem();
  weapon_for_big_boom:=IsWeaponReadyForBigBoom(itm);


  if NeedMandatoryShield(burer) and (pshield_ready^) then begin
    force_shield:=true;
  end else if (itm<>nil) and IsThrowable(itm) and ptele_ready^ then begin
    force_tele:=true;
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
    end else if (itm<>nil) and IsKnife(itm) and (pshield_ready^) then begin
      force_shield:=true;
    end;
  end else if IsBurerUnderAim(burer) then begin
    if (itm<>nil) and panti_aim_ready^ then begin
      force_antiaim:=true;
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
  itm:pointer;
begin
  itm:=GetActorActiveItem();
  if itm<>nil then begin
    if IsKnife(itm) or IsThrowable(itm) then begin
      ActivateActorSlot__CInventory(0, true);
    end;
  end;

  if IsActorTooClose(burer, GetBurerSuperstaminahitDist()) then begin
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
  result:=NeedMandatoryShield(burer) or IsBurerUnderAim(burer) or (IsWeaponReadyForBigBoom(itm) and not IsActorLookTurnedAway(burer) and (GetCurrentState(itm) <> EWeaponStates__eReload) );
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

/////////////////////////////////// Телекинез гранатами ////////////////////////////////////////////////
var
  _gren_count:cardinal; //по-хорошему - надо сделать членом класса, но и так сойдет - однопоточность же

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
////////////////////////////////////////////////////////////////////////////////////////////////////////
function CanIgnoreMinMassForObject(o:pointer):boolean; stdcall;
var
  wpn:pointer;
  sect:PAnsiChar;
begin
  result:=false;
  wpn:=dynamic_cast(o, 0, RTTI_CObject, RTTI_CWeapon, false);
  if wpn<>nil then begin
    sect:=GetSection(wpn);
    if game_ini_r_bool_def(sect, 'quest_item', false) or game_ini_r_bool_def(sect, 'not_for_telekinesis', false) then begin
      result:=false;
    end else begin
      result:=true;
    end;
  end;
end;
    
procedure CStateBurerAttackTele__FindFreeObjects_OverrideMinMassRestriction_Patch(); stdcall;
asm
  pushad
  push esi
  call CanIgnoreMinMassForObject
  cmp al, 1
  popad
  je @finish

  // original
  @check_mass:
  mov eax, [edx+$54]
  call eax

  @finish:
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

  //в CStateBurerAttack<Object>::execute (xrgame.dll+10ab20) меняем приоритеты, чтобы при приближении актора с наличием стамины эту стамину отнимало
  jmp_addr:=xrGame_addr+$10acb5;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttack__execute_Patch), 5, true) then exit;

  //в CStateBurerShield::check_completion(xrgame+105fc0) не снимаем щит, если актор вплотную, а также переносим время старта щита m_last_shield_started на текущее
  jmp_addr:=xrGame_addr+$105fd2;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerShield__check_completion_Patch), 6, true) then exit;

  //в CStateBurerShield::check_start_conditions (xrgame+105f80) разрешаем уходить в щит всегда, когда актор подобрался слишком близко
  jmp_addr:=xrGame_addr+$105f94;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerShield__check_start_conditions_Patch), 6, true) then exit;

  // в начале CStateBurerAttackTele<Object>::CheckTeleStart сбрасываем счетчик гранат вокруг перед тем, как начатьискать объекты
  jmp_addr:=xrGame_addr+$10a427;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__CheckTeleStart_BeforeObjectsSearch_Patch), 6, true) then exit;

  // в конце CStateBurerAttackTele<Object>::CheckTeleStart проверяем, нашлись ли грены, и если нашлись - разрешаем телекинез
  jmp_addr:=xrGame_addr+$10a4a2;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__CheckTeleStart_AfterObjectsSearch_Patch), 6, false) then exit;

  //в CStateBurerAttackTele<Object>::FindFreeObjects (xrgame+1097e0) инкрементим счетчик гранат
  jmp_addr:=xrGame_addr+$10989b;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__FindFreeObjects_OnGrenadeFound_Patch), 5, true) then exit;

  // в CStateBurerAttackTele<Object>::FindFreeObjects (xrgame+1097e0) - несмотря на то, что лежащее оружие не очень тяжелое, оно вполне пойдет для телекинеза ;)
  jmp_addr:=xrGame_addr+$1098f9;
  if not WriteJump(jmp_addr, cardinal(@CStateBurerAttackTele__FindFreeObjects_OverrideMinMassRestriction_Patch), 5, true) then exit;

  // Выходим из телекинеза в случае, если актор близко или достал РПГ


  //TODO: при попадании в щит - продлеваем защиту



  result:=true;
end;

end.
