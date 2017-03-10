unit WeaponEvents;

interface
function Init:boolean;

procedure OnWeaponExplode_AfterAnim(wpn:pointer; param:integer);stdcall;
function OnWeaponHide(wpn:pointer):boolean;stdcall;
procedure OnWeaponHideAnmStart(wpn:pointer);stdcall;
procedure OnWeaponShow(wpn:pointer);stdcall;
function OnWeaponAimIn(wpn:pointer):boolean;stdcall;
function OnWeaponAimOut(wpn:pointer):boolean;stdcall;
function Weapon_SetKeyRepeatFlagIfNeeded(wpn:pointer; kfACTTYPE:cardinal):boolean;stdcall;
procedure CHudItem__OnMotionMark(wpn:pointer); stdcall;

implementation
uses Messenger, BaseGameData, Misc, HudItemUtils, WeaponAnims, LightUtils, WeaponAdditionalBuffer, sysutils, ActorUtils, DetectorUtils, strutils, dynamic_caster, weaponupdate, KeyUtils, gunsl_config, xr_Cartridge, ActorDOF, MatVectors, ControllerMonster, collimator;

var
  upgrade_weapon_addr:cardinal;

//-------------------------------Разряжание магазина-----------------------------
procedure OnUnloadInEndOfAnim(wpn:pointer; param:integer);stdcall;
begin
  virtual_CWeaponMagazined__UnloadMagazine(wpn);
  ForceWpnHudBriefUpdate(wpn);
  SetAnimForceReassignStatus(wpn, true);
end;

procedure OnUnloadInMiddleAnim(wpn:pointer; param:integer);stdcall;
begin
  virtual_CWeaponMagazined__UnloadMagazine(wpn);
  ForceWpnHudBriefUpdate(wpn);
  MakeLockByConfigParam(wpn, GetHUDSection(wpn), PChar('lock_time_end_'+GetActualCurrentAnim(wpn)));
  SetAnimForceReassignStatus(wpn, true);
end;


function OnUnloadMag(wpn:pointer):boolean; stdcall;
var
  hud_sect: PChar;
  act:pointer;
  curanm:PChar;
const
  param_name:PChar = 'use_unloadmag_anim';
begin
  //возвратить false, если разряжать оружие сейчас нельзя
  result := false;

  hud_sect:=GetHUDSection(wpn);
  act:=GetActor();
  if ((act=nil) or (GetOwner(wpn)<>act)) then begin
    result:=true;
    exit;
  end;

  if not CheckActorWeaponAvailabilityWithInform(wpn) then exit;

  if (not game_ini_line_exist(hud_sect, param_name)) or (not game_ini_r_bool(hud_sect, param_name)) then begin
    result:=true;
    exit;
  end;

  if WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_unload_mag', 'sndUnload') then begin
    curanm:=GetActualCurrentAnim(wpn);
    StartCompanionAnimIfNeeded(rightstr(curanm, length(curanm)-4), wpn, false);
    //анима начала играться. Посмотрим, когда надо разряжаться
    if game_ini_line_exist(hud_sect, PChar('lock_time_start_'+GetActualCurrentAnim(wpn))) then begin
      //разряжание идет по схеме визуального отображения патронов (в середине анимации)
      MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_start_'+curanm), false, OnUnloadInMiddleAnim);
    end else if game_ini_line_exist(hud_sect, PChar('lock_time_end_'+curanm)) then begin
      //разряжание выполняется после анимации
      MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_end_'+curanm), false, OnUnloadInEndOfAnim);
    end else begin
      //никаких указаний нет, поэтому разряжаемся сразу
      result := true;
      SetAnimForceReassignStatus(wpn, true);
    end;
  end;
end;

procedure UnloadMag_Patch(); stdcall;
asm
  //делаем вырезанное: add esp, 4/test eax, eax
  push eax
  mov eax, [esp+4]
  mov [esp+8], eax
  pop eax
  add esp, 4
  test eax, eax
  je @finish
  pushad
    push ecx
    call OnUnloadMag
    cmp al, 0
  popad

  @finish:
end;  

//-----------------Общий обработчик события отсоединения аддонов----------------
procedure OnAddonDetach(wpn:pointer; addontype:integer);stdcall;
var
  param_name:PChar;
  anim_name:string;
  addon_name:PChar;
  snd_name:PChar;
  hud_sect:PChar;
  act:pointer;

begin
  act:=GetActor();
  if ((act=nil) or (GetOwner(wpn)<>act)) or not CheckActorWeaponAvailabilityWithInform(wpn) then exit;

  param_name:=nil;
  snd_name:=nil;
  case addontype of
    1:begin
        addon_name:=GetCurrentScopeSection(wpn);
        if addon_name<>nil then begin
          param_name:='use_scopedetach_anim';
          anim_name:='anm_detach_scope_'+addon_name;
          snd_name:='sndScopeDet';
        end;
      end;
    4:begin
        param_name:='use_sildetach_anim';
        anim_name:='anm_detach_sil';
        snd_name:='sndSilDet';
      end;
    2:begin
        param_name:='use_gldetach_anim';
        anim_name:='anm_detach_gl';
        snd_name:='sndGLDet';
      end;
    else begin
      log('WeaponEvents.OnAddonDetach: Invalid addontype!', true);
      exit;
    end;
  end;
  hud_sect:=GetHUDSection(wpn);
  if (param_name=nil) or (not game_ini_line_exist(hud_sect, param_name)) or (not game_ini_r_bool(hud_sect, param_name)) then begin
    DetachAddon(wpn, addontype);
    exit;
  end;
  WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, PChar(anim_name), snd_name, DetachAddon, addontype);
end;


procedure DetachAddon_Patch(addontype:integer);stdcall;
asm
  pushad
    push addontype
    push esi //CWeapon
    call OnAddonDetach
  popad
end;

function InitDetachAddon(address:cardinal; addontype:byte; nopcount:integer; writejustpush:boolean = false):boolean;
var buf:string;
begin
  result:=false;
  buf:=chr($6A)+chr(addontype);//формируем и записываем аргумент для патча
  if not WriteBufAtAdr(address, PChar(buf), 2) then exit;
  if not writejustpush then begin
    address:=address+2;//теперь записываем вызов патча и нопим лишнее, дабы аддон не исчез
    if not WriteJump(address, cardinal(@DetachAddon_Patch), nopcount, true) then exit;
  end;
  result:=true;
end;

//-----------------Общий обработчик события присоединения аддонов----------------

function OnAddonAttach(wpn:pointer; addontype:integer):boolean;stdcall;
var addonname:PChar;
    actor:pointer;
    snd_name:PChar;
    param_name:PChar;
    anim_name:string;
    hud_sect, sect:PChar;
    err_msg:PChar;
begin
  param_name:=nil;
  snd_name:=nil;
  sect:=GetSection(wpn);
  err_msg:=nil;
  case addontype of
    1:begin
        //log ('scope_att');
        addonname:=GetCurrentScopeSection(wpn);
        if addonname=nil then log('WpnEvents.OnAddonAttach: Scope has no section?!');
        addonname:=game_ini_read_string(addonname, 'scope_name');
        param_name:='use_scopeattach_anim';
        anim_name:='anm_attach_scope_'+addonname;
        snd_name:='sndScopeAtt';

        if IsSilencerAttached(wpn) and game_ini_line_exist(sect, 'restricted_scope_and_sil') and game_ini_r_bool(sect, 'restricted_scope_and_sil')  then begin
          err_msg:='gunsl_msg_sil_restricts_scope';
        end else if IsGLAttached(wpn) and game_ini_line_exist(sect, 'restricted_scope_and_gl') and game_ini_r_bool(sect, 'restricted_scope_and_gl') then begin
          err_msg:='gunsl_msg_gl_restricts_scope';
        end;
      end;
    4:begin
        //log ('sil_att');
        param_name:='use_silattach_anim';
        anim_name:='anm_attach_sil';
        snd_name:='sndSilAtt';
        addonname:=GetSilencerSection(wpn);
        if IsScopeAttached(wpn) and game_ini_line_exist(sect, 'restricted_scope_and_sil') and game_ini_r_bool(sect, 'restricted_scope_and_sil')  then begin
          err_msg:='gunsl_msg_scope_restricts_sil';
        end else if IsGLAttached(wpn) and game_ini_line_exist(sect, 'restricted_gl_and_sil') and game_ini_r_bool(sect, 'restricted_gl_and_sil') then begin
          err_msg:='gunsl_msg_gl_restricts_sil';
        end;
      end;
    2:begin
        //log('gl_att');
        param_name:='use_glattach_anim';
        anim_name:='anm_attach_gl';
        snd_name:='sndGLAtt';
        addonname:=GetGLSection(wpn);
        if IsScopeAttached(wpn) and game_ini_line_exist(sect, 'restricted_scope_and_gl') and game_ini_r_bool(sect, 'restricted_scope_and_gl')  then begin
          err_msg:='gunsl_msg_scope_restricts_gl';
        end else if IsSilencerAttached(wpn) and game_ini_line_exist(sect, 'restricted_gl_and_sil') and game_ini_r_bool(sect, 'restricted_gl_and_sil') then begin
          err_msg:='gunsl_msg_sil_restricts_gl';
        end;
      end;
    else begin
      log('WeaponEvents.OnAddonAttach: Invalid addontype!', true);
      result:=true;
      exit;
    end;
  end;

  hud_sect:=GetHUDSection(wpn);
  actor:=GetActor();
  if (actor<>nil) and (actor=GetOwner(wpn)) and not CheckActorWeaponAvailabilityWithInform(wpn) then begin
    //log('not_available');
    result:=false;
  end else if err_msg<>nil then begin
    //log('att_err');
    if (actor<>nil) and (actor=GetOwner(wpn)) then begin
      Messenger.SendMessage(err_msg);
    end;
    result:=false
  end else if (actor=nil) or (actor<>GetOwner(wpn)) then begin
    //log('actor_not_owner');
    result:=true;
  end else if (param_name=nil) or (not game_ini_line_exist(hud_sect, param_name)) or (not game_ini_r_bool(hud_sect, param_name)) then begin
    //log('no_param');
    result:=true;
  end else begin
    //log (anim_name);
    //log('playing...');
    result:= WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, PChar(anim_name), snd_name);
  end;

  if (not result) then begin
    //Сейчас присоединять аддон нельзя. Отспавним его назад в инвентарь.
    if addontype = 1 then SetCurrentScopeType(wpn, 0);
    if (actor<>nil) and (actor=GetOwner(wpn)) then CreateObjectToActor(addonname);
  end;
end;

procedure AttachAddon_Patch{(addontype:integer)}();stdcall;
asm
  push ecx
  mov ecx, [esp+8]

  
  push esi
  push ebx

  mov ebx, ecx

  //в младшем ниббле младшего байта addontype - тип аддона, в старшем ниббле - индекс регистра с адресом оружия
  //1 - ebp, 0 - esi

  and ecx, $0000000F
  and ebx, $000000F0
  shr ebx, 4

  //восстанавливаем из стека указатель на оружие

  cmp bx, 0
  je @wpnfound
  
  mov esi, ebp
  cmp bx, 1
  je @wpnfound

  @wpnfound:
  pushad
    push ecx
    push esi //CWeapon
    call OnAddonAttach
    test al, al
  popad

  je @finish
  or byte ptr [esi+$460], cl

  @finish:

  pop ebx
  pop esi
  pop ecx
  ret 4
end;

function InitAttachAddon(address:cardinal; addontype:byte):boolean;
var buf:string;
begin
  result:=false;
  buf:=chr($6A)+chr(addontype);//формируем и записываем аргумент для патча
  if not WriteBufAtAdr(address, PChar(buf), 2) then exit;
  address:=address+2;//теперь записываем вызов патча
  if not WriteJump(address, cardinal(@AttachAddon_Patch), 0, true) then exit;
  result:=true;
end;
//------------------------------------------------------------------------------
procedure OnCWeaponNetSpawn_middle(wpn:pointer);stdcall;
begin
  if WpnCanShoot(PChar(GetClassName(wpn))) then begin
    //буфер может уже быть создан в load'e - проверим это
    if (GetBuffer(wpn)=nil) then begin
      WpnBuf.Create(wpn);
    end;
  end;
end;

procedure OnCWeaponNetSpawn_end(wpn:pointer);stdcall;
var
  buf:WpnBuf;
  i:word;
  c:pointer;
  sect:PChar;
  slot:integer;
begin

  //выставим сохраненные типы патронов
  if WpnCanShoot(PChar(GetClassName(wpn))) then begin
    buf:=GetBuffer(wpn);
    if (buf<>nil) then begin
//      if (IsGLAttached(wpn))  then log(booltostr(ISGLEnabled(wpn), true));

      if (length(buf.ammos)>0) and (length(buf.ammos)=integer(GetAmmoInMagCount(wpn))) then begin
        for i:=0 to length(buf.ammos)-1 do begin
          sect:=GetMainCartridgeSectionByType(wpn, buf.ammos[i]);
          if sect<>nil then begin
            c:=GetCartridgeFromMagVector(wpn, i);
            CCartridge__Load(c, sect, buf.ammos[i]);
          end;
        end;
      end else begin
       if (GetAmmoInMagCount(wpn)>0) and (length(buf.ammos)>0) then begin
        log(PChar('There is NO ammotype data in the save??? Weapon '+GetSection(wpn)+':'+inttostr(GetID(wpn))), true)
       end else if (length(buf.ammos)<>0) and (length(buf.ammos)=integer(GetAmmoInMagCount(wpn))) then begin
        log(PChar('Count of ammotypes in the save is not equal to count of ammo in weapon '+GetSection(wpn)+':'+inttostr(GetID(wpn))), true);
       end;
      end;
      setlength(buf.ammos, 0);
    end;
  end;
  SetAnimForceReassignStatus(wpn, true);
end;

procedure CWeapon_NetSpawn_Patch_middle();
asm

    pushad
    pushfd

    push esi
    call OnCWeaponNetSpawn_middle

    popfd
    popad

    test edi, edi
    mov [esp+$14], eax

    ret
end;


procedure CWeapon_NetSpawn_Patch_end();
asm
    mov [esi+$6a0], al
    pushad
    pushfd

    push esi
    call OnCWeaponNetSpawn_end

    popfd
    popad
    ret
end;
//------------------------------------------------------------------------------
procedure OnCWeaponNetDestroy(wpn:pointer);stdcall;
var buf:WpnBuf;
begin
  buf:=WeaponAdditionalBuffer.GetBuffer(wpn);
  if buf<>nil then buf.Free;
end;

procedure CWeapon_NetDestroy_Patch();
asm

    pushad
    pushfd

    push esi
    call OnCWeaponNetDestroy

    popfd
    popad

    lea edi, [esi+$338];

    ret
end;



//---------------Действия при покупке какого-то апгрейда у механика-------------
procedure Upgrade_Weapon_Patch();
begin
  asm
    pushad
    pushfd
    //push ebx
    //call WeaponVisualChanger
    popfd
    popad

    push ecx
    lea edx, [esp+$1c]
    jmp upgrade_weapon_addr
  end;
end;

//-----------------------------------------Переключение режимов огня------------------------

function OnChangeFireMode(wpn:pointer; new_mode:integer; isPrev:boolean):boolean; stdcall;
var
  hud_sect:PChar;
  firemode:integer;
  anm_name:string;
  det_anim:PChar;
  res:boolean;
begin
  //возвратить false, если нельзя сейчас менять режим огня
  if isPrev then
    result:=Weapon_SetKeyRepeatFlagIfNeeded(wpn, kfPREVFIREMODE)
  else
    result:=Weapon_SetKeyRepeatFlagIfNeeded(wpn, kfNEXTFIREMODE);

  if not result then exit;


  hud_sect:=GetHUDSection(wpn);
  firemode:=CurrentQueueSize(wpn);
  if firemode=new_mode then exit; //обрабатываем срабатывание в случае единственного доступного режима стрельбы

  if (hud_sect=nil) or (not game_ini_line_exist(hud_sect, 'use_firemode_change_anim')) or (not game_ini_r_bool(hud_sect, 'use_firemode_change_anim')) then exit;


  anm_name:='anm_changefiremode_from_';
  if firemode<0 then anm_name:=anm_name+'a' else anm_name:=anm_name+inttostr(firemode);
  anm_name:=anm_name+'_to_';
  if new_mode<0 then anm_name:=anm_name+'a' else anm_name:=anm_name+inttostr(new_mode);

  if IsWeaponJammed(wpn) then begin
    res:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, PChar(anm_name), 'sndChangeFireModeJammed');
  end else if GetAmmoInMagCount(wpn)<=0 then begin
    res:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, PChar(anm_name), 'sndChangeFireModeEmpty');
  end else begin
    res:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, PChar(anm_name), 'sndChangeFireMode');
  end;

  if res then begin
    SetAnimForceReassignStatus(wpn, true);     //for world model
    det_anim:=GetActualCurrentAnim(wpn);
    StartCompanionAnimIfNeeded(rightstr(det_anim, length(det_anim)-4), wpn, false);
  end;
end;

procedure OnChangeFireMode_Patch(); stdcall;
asm
  push [esi+$7ac]       //сохраним текущий индекс режима стрельбы

  mov [esi+$7ac], edx   //запишем новый индекс (предполагаемый) режима стрельбы
  mov edx, [edi+$1a8]
  call edx              //определим размер очереди для нового режима стрельбы
  push eax              //поместим сразу размер очереди для вызова метода, его устанавливающего (удачный исход)


  mov ecx, [esp+$C]     //восстанавливаем тип переключения (вперед/назад, неявный аргумент)
  pushad
    push ecx
    push eax
    push esi
    call OnChangeFireMode
    cmp al, 1
  popad
  
  jne @nochange
    mov ecx, esi    //все нормально, выполняем переключение
    mov eax, [edi+$218]
    call eax        //устанавливаем новый размер очереди
    add esp, 4      //снимаем со стека не понадобившийся нам старый режим стрельбы
    jmp @finish

  @nochange:
                          //все плохо, сейчас переключаться не можем
      add esp, 4          //забываем, какую очередь собирались выставлять
      pop [esi+$7ac]      //восстанавливаем старый индекс

  @finish:
  ret 4
end;


function InitChangeFireMode(address:cardinal; changetype:byte):boolean;
var buf:string;
begin
  result:=false;
  buf:=chr($6A)+chr(changetype);//формируем и записываем аргумент для патча
  if not WriteBufAtAdr(address, PChar(buf), 2) then exit;
  address:=address+2;//теперь записываем вызов патча
  if not WriteJump(address, cardinal(@OnChangeFireMode_Patch), 23, true) then exit;
  result:=true;
end;


//-------------------------Событие назначения клина-----------------------------
procedure OnWeaponExplode_AfterAnim(wpn:pointer; param:integer);stdcall;
var
  hud_sect:PChar;
  trash, element:string;
  sitm:pointer;
begin
  hud_sect:=GetHUDSection(wpn);
  if game_ini_line_exist(hud_sect, 'explosion_trash') then begin
    trash:= game_ini_read_string(hud_sect, 'explosion_trash');
    while (GetNextSubStr(trash, element, ',')) do begin
      sitm:=alife_create(PChar(element), GetPosition(wpn), GetLevelVertexID(wpn), GetGameVertexID(wpn));
      if sitm<>nil then CSE_SetAngle(sitm, GetOrientation(wpn));
      if sitm<>nil then CSE_SetPosition(sitm, GetPosition(wpn));
    end;
  end;
  if IsScopeAttached(wpn) and (GetScopeStatus(wpn)=2) then alife_create(game_ini_read_string(GetCurrentScopeSection(wpn), 'scope_name'), GetPosition(wpn), GetLevelVertexID(wpn), GetGameVertexID(wpn));
  if IsSilencerAttached(wpn) and (GetSilencerStatus(wpn)=2) then alife_create(GetSilencerSection(wpn), GetPosition(wpn), GetLevelVertexID(wpn), GetGameVertexID(wpn));
  if IsGLAttached(wpn) and (GetGLStatus(wpn)=2) then alife_create(GetGLSection(wpn), GetPosition(wpn), GetLevelVertexID(wpn), GetGameVertexID(wpn));

  alife_release(get_server_object_by_id(GetID(wpn)));
end;

function OnWeaponJam(wpn:pointer):boolean;stdcall;
//сейчас с оружием произойдет что-то нехорошее...
//вернуть false, если не стрелять перед клином, true - если стрелять
var sect:PChar;
    owner:pointer;
    startcond, endcond, curcond, startprob, endprob, curprob:single;
    anm:string;
begin
  result:=true;
  SetWeaponMisfireStatus(wpn, true);
  SetAnimForceReassignStatus(wpn, true);
  owner := GetOwner(wpn);
  if (owner=nil) or (owner<>GetActor()) then exit;
  sect:=GetSection(wpn);
  curcond:=GetCurrentCondition(wpn);

  if IsActorSuicideNow() then begin
    SetWeaponMisfireStatus(wpn, false);
    result:=true;
  end;

  if game_ini_r_bool_def(sect, 'can_explose', false) then begin
    if curcond<game_ini_r_single_def(sect, 'explode_start_condition', 1) then begin
      if random < game_ini_r_single_def(sect, 'explode_probability', 1) then begin
        //Сейчас оружие взорвется в руках :)
        result:=true;
        SetExplosed(wpn, true);
        if game_ini_line_exist(sect, 'explode_flame_particles') then SetCurrentParticles(wpn, game_ini_read_string(sect, 'explode_flame_particles'), OFFSET_PARTICLE_WEAPON_CURFLAME);
        if game_ini_line_exist(sect, 'explode_shell_particles') then SetCurrentParticles(wpn, game_ini_read_string(sect, 'explode_shell_particles'), OFFSET_PARTICLE_WEAPON_CURSHELLS);
        if game_ini_line_exist(sect, 'explode_smoke_particles') then SetCurrentParticles(wpn, game_ini_read_string(sect, 'explode_smoke_particles'), OFFSET_PARTICLE_WEAPON_CURSMOKE);
        exit;
      end;
    end;
  end;

  if game_ini_r_bool_def(sect, 'use_light_misfire', false) and not (IsHolderHasActiveDetector(wpn) and game_ini_r_bool_def(GetHUDSection(wpn), 'disable_light_misfires_with_detector', false)) then begin
    startcond:=game_ini_r_single_def(sect, 'light_misfire_start_condition', 1);   //при каком состоянии начнутся осечки
    endcond:=game_ini_r_single_def(sect, 'light_misfire_end_condition', 0);       //при каком закончатся
    startprob:=game_ini_r_single_def(sect, 'light_misfire_start_probability', 1); //какую долю от клинов при начальном состоянии будут составлять осечки
    endprob:=game_ini_r_single_def(sect, 'light_misfire_end_probability', 0);     //какую долю от всех клинов осечки будут составлять в конце

    if (curcond<endcond) then
      curprob:=endprob
    else if (curcond>startcond) then
      curprob:=0
    else
      curprob:=endprob+curcond*(startprob-endprob)/(startcond-endcond);

    if (random<curprob) then begin
      //Осечка! Сбрасываем флаг клина, а стрелять не даем
      SetWeaponMisfireStatus(wpn, false);
      result:=false;

      //начало названия метки - обязательно anm_shoot, иначе будет отрубаться по таймеру выстрела - не сработает антибаг
      anm:='anm_shoot_lightmisfire';
      if IsAimNow(wpn) or IsHolderInAimState(wpn) then begin
        anm:=anm+'_aim';
        if (GetScopeStatus(wpn)=2) and IsScopeAttached(wpn) and game_ini_r_bool_def(GetHUDSection(wpn), 'aim_scope_anims', true) then anm:=anm+'_scope'
      end;
      anm:= ModifierStd(wpn, anm);
      PlayHUDAnim(wpn, PChar(anm), true);
      StartCompanionAnimIfNeeded(rightstr(anm, length(anm)-4), wpn, false);
      anm:='lock_time_'+anm;
      MakeLockByConfigParam(wpn, GetHUDSection(wpn), PChar(anm), true);
      CHudItem_Play_Snd(wpn, 'sndLightMisfire');
      SendMessage('gunsl_light_misfire', gd_novice);
      exit;
    end;
  end;

  //Клин оружия. Посмотрим, до выстрела он или после
  result:= not game_ini_r_bool_def(GetHUDSection(wpn), 'no_jam_fire', false);
  //если до выстрела - играем аниму перехода в клин вручную
  if not result then PlayHUDAnim(wpn, anm_shots_selector(wpn, true), true);
end;

procedure WeaponJammed_Patch(); stdcall;
//у нас оружие должно было заклинить при данном выстреле
//мы сделаем хитрее - если понадобится, то выставим флаг клина, но игре сообщим, что все нормально, и выстрел при этом произойдет
//Аниму выстрела в заклинившем состоянии выставляем отличную от обычного выстрела в WeaponAnims.pas
asm
  mov eax, 1
  pushad
    push esi
    call OnWeaponJam
    cmp al, 0
  popad

  je @finish    //если OnWeaponJam вернула false (не стрелять сейчас) - переходим
  xor eax, eax  //говорим, что осечки нет
  
  @finish:
end;

//--------------Отображение сообщения о клине----------------------------------

procedure OnJammedHintShow(); stdcall
//var
//  wpn:pointer;
begin
//  wpn:=GetActorActiveItem();
//  if (wpn=nil) or not WpnCanShoot(PChar(GetClassName(wpn))) then exit;
//  if not (IsExplosed(wpn) or (IsActionProcessing(wpn) and (leftstr(GetCurAnim(wpn), length('anm_fakeshoot'))<>'anm_fakeshoot'))) then begin
//    Messenger.SendMessage('gun_jammed', gd_novice);
//  end;
end;

procedure OnJammedHintShow_Patch(); stdcall
asm
  pushad
    call OnJammedHintShow
  popad
end;

//---------------------Щелчки при осечках/пустом магазине-----------------------
procedure OnEmptyClick(wpn:pointer);stdcall;
var
  anm_started:boolean;
  txt:PChar;
  act:pointer;
  det_anm:PChar;
begin
  anm_started:=false;

  //При патчинге мы вырезали воспроизведение звука. Исправим это недоразумение одновременно с проигрыванием анимы.
  if not (((GetGLStatus(wpn)=1) or IsGLAttached(wpn)) and IsGLEnabled(wpn)) and IsWeaponJammed(wpn) then begin
    txt := 'gunsl_msg_weapon_jammed';
    if IsAimNow(wpn) or IsHolderInAimState(wpn) then begin
      anm_started:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_fakeshoot_aim', 'sndJammedClick', nil, 0, false, true)
    end else begin
      anm_started:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_fakeshoot', 'sndJammedClick', nil, 0, false, true);
    end;
  end else begin
    txt := 'gunsl_msg_weapon_empty';
    if IsAimNow(wpn) or IsHolderInAimState(wpn) then begin
      anm_started:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_fakeshoot_aim', 'sndEmptyClick', nil, 0, false, true);
    end else begin
      anm_started:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_fakeshoot', 'sndEmptyClick', nil, 0, false, true);
    end;
  end;

  act:=GetActor();
  if (act<>nil) and (act=GetOwner(wpn)) and anm_started then begin
    det_anm:=GetActualCurrentAnim(wpn);
    StartCompanionAnimIfNeeded(rightstr(det_anm, length(det_anm)-4), wpn, true);
    Messenger.SendMessage(txt, gd_novice);
  end;
end;

procedure EmptyClick_Patch; stdcall;
begin
  asm
    pushad
    sub ecx, $2e0
    push ecx
    call OnEmptyClick
    popad
    ret
  end;
end;
//------------------------------------------------------------------------------

function OnWeaponHide(wpn:pointer):boolean;stdcall;
var
  act, owner:pointer;
  state:cardinal;
begin

  //вернуть, можно скрывать или нет
  //работает для всех CHudItem!
  act:=GetActor();
  owner:=GetOwner(wpn);

  if (owner<>act) and (act<>nil) then begin
    result:=true;
    exit;
  end;


  if not (WpnCanShoot(PChar(GetClassName(wpn)))) then begin
    result:=true;
    state:=GetCurrentState(wpn);

    if (IsActorSuicideNow() or IsSuicideAnimPlaying(wpn)) then begin
      result:=false;
      exit;
    end;

    if (act<>nil) and (owner=act) and IsThrowable(PChar(GetClassName(wpn))) and ((state=EMissileStates__eReady) or (state=EMissileStates__eThrowStart) or (state=EMissileStates__eThrow) or (state=EMissileStates__eThrowEnd)) then begin
      result:=false;
    end;
    exit;
  end;

  result:=CanHideWeaponNow(wpn);

  if (act<>nil) and (owner=act) then begin
    if result then begin
      ResetActorFlags(act);
    end else begin
      if ActorUtils.IsHolderInSprintState(wpn) then begin
        SetActorKeyRepeatFlag(kfWPNHIDE, true);
        SetActorActionState(act, actSprint, false, mState_WISHFUL);
      end;
    end;
  end;
end;

procedure OnWeaponHideAnmStart(wpn:pointer);stdcall;
var
  act, owner:pointer;
begin
  //У ножа нет звука убирания. Воспроизведем.
  if IsKnife(PChar(GetClassName(wpn))) then begin
    CHudItem_Play_Snd(wpn, 'sndHide');
  end;

  act:=GetActor();
  owner:=GetOwner(wpn);
  if (act<>nil) and (owner=act) then begin
    ResetActorFlags(act);
    SetActorActionState(act, actSprint, false, mState_WISHFUL);
    SetActorActionState(act, actSprint, false, mState_REAL);

    StartCompanionAnimIfNeeded('hide', wpn, false);
  end;
end;


procedure OnWeaponShow(wpn:pointer);stdcall;
var
  act, owner, det:pointer;
begin
  //У ножа нет звука доставания. Воспроизведем.
  if IsKnife(PChar(GetClassName(wpn))) then begin
    CHudItem_Play_Snd(wpn, 'sndShow');
  end;

  act:=GetActor();
  owner:=GetOwner(wpn);

  if (owner<>nil) and (owner=act) then begin
    //фикс бага с доставанием предмета без смены худовой секции, когда анима доставания не игралась

    player_hud__attach_item(wpn);

    ClearActorKeyRepeatFlags();
    SetActorActionState(act, actSprint, false, mState_WISHFUL);
    ResetActorFlags(act);
    det:=ItemInSlot(act, 9);
    if (det<>nil) and not CanUseDetectorWithItem(wpn) then begin
      SetDetectorForceUnhide(det, false);
      SetActorActionState(act, actShowDetectorNow, false);
    end;

    //если детектор не только в слоте, но и активен
    StartCompanionAnimIfNeeded('draw', wpn, false);
  end;
end;


function OnWeaponAimIn(wpn:pointer):boolean;stdcall;
var
  act:pointer;
begin
  result:=CanAimNow(wpn);
  act:=GetActor();
  if not result and (act<>nil) and not IsAimToggle() and (act = GetOwner(wpn)) and IsHolderInSprintState(wpn) then begin
    SetActorActionState(act, actSprint, false, mState_WISHFUL);
  end;

  if result and (GetAimFactor(wpn)< 0.002) then begin
    SetAimFactor(wpn, 0.002); //ставим по минимуму фактор входа, чтобы не отменилось переназначение анимы
  end;
end;


function OnWeaponAimOut(wpn:pointer):boolean;stdcall;
begin
  //При возврате false выход из зума произведен не будет
  //Если у нас выполняется какое-то действие в прицеливании (стрельба, например)
  //И в конфигах прописано запрещение выхода из зума/на оружии стоит прицел
  //то запоминаем, что мы хотели закончить прицеливание
  //Затем в апдейте актора ждем окончания действия и вручную вызываем повторную попытку выйти из зума
  result:=CanLeaveAimNow(wpn);
//  log(booltostr(result, true));
  if not result then SetActorKeyRepeatFlag(kfUNZOOM, true);

  if result and (GetAimFactor(wpn)> 0.998) then begin
    SetAimFactor(wpn, 0.998); //ставим по минимуму фактор выхода, чтобы не отменилось переназначение анимы
  end;  
end;


function Weapon_SetKeyRepeatFlagIfNeeded(wpn:pointer; kfACTTYPE:cardinal):boolean;stdcall;
var
  act:pointer;
begin
  result:=CanStartAction(wpn);
  if (not result) then begin
    act:=GetActor();
    if (act<>nil) and (act=GetOwner(wpn)) then begin

      if IsHolderInSprintState(wpn) then begin
        SetActorActionState(act, actSprint, false, mState_WISHFUL);
        SetActorKeyRepeatFlag(kfACTTYPE, true);
      end else if (IsWeaponJammed(wpn) and ( (kfACTTYPE = kfRELOAD) or (kfACTTYPE = kfNEXTAMMO)  )) then begin
        SetActorKeyRepeatFlag(kfACTTYPE, true);
      end;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------

procedure CHudItem__OnStateSwitch(chuditem:pointer); stdcall;
var
  wpn:pointer;
begin
  wpn:=dynamic_cast(chuditem, 0, RTTI_CHudItem, RTTI_CWeapon, false);
  if wpn<>nil then begin
    //для мирового оружия
    case GetNextState(wpn) of
      1,2,3,7,8,10: begin
        SetAnimForceReassignStatus(wpn, true);
        WeaponUpdate.ReassignWorldAnims(wpn);
      end;
    end;
  end;
end;

procedure CHudItem__SwitchState_Patch(); stdcall;
asm
  pushad
    push esi
    call CHudItem__OnStateSwitch
  popad
  pop esi
  add esp, $4014
  ret 4
end;
//----------------------------------------------------------------------------------------------------------
function anm_attack_selector(knife:pointer; kick_type:cardinal):PChar; stdcall;
var
  act:pointer;
  v:FVector3;
begin

  act:=GetActor();
  if (act<>nil) and (act=GetOwner(knife)) then begin
    SetActorActionState(act, actModSprintStarted, false);
    SetActorActionState(act, actModSprintStarted, false, mState_WISHFUL);

    if IsActorPlanningSuicide() then begin
      if not IsActorSuicideNow() then begin
        CHudItem_Play_Snd(knife, 'sndPrepareSuicide');
        result:='anm_prepare_suicide';
      end else begin
        SetDisableInputStatus(true);
        result:='anm_selfkill';
        CHudItem_Play_Snd(knife, 'sndSelfKill');
      end;
      exit;
    end else if IsSuicideAnimPlaying(knife) then begin
      SetExitKnifeSuicide(false);
      SetHandsJitterTime(GetShockTime());
      CHudItem_Play_Snd(knife, 'sndStopSuicide');
      result:='anm_stop_suicide';
      exit;
    end;
  end;

  case kick_type of
    1:begin
        result:='anm_attack';
        StartCompanionAnimIfNeeded('knife_attack', knife, true);
        CHudItem_Play_Snd(knife, 'sndKick1');
        if ReadActionDOFVector(knife, v, 'anm_attack', false) then begin
          SetDOF(v, ReadActionDOFSpeed_In(knife,'anm_attack'));
        end;
      end;
    2:begin
        result:='anm_attack2';
        StartCompanionAnimIfNeeded('knife_attack2', knife, true);
        CHudItem_Play_Snd(knife, 'sndKick2');
        if ReadActionDOFVector(knife, v, 'anm_attack2', false) then begin
          SetDOF(v, ReadActionDOFSpeed_In(knife, 'anm_attack2'));
        end;
      end;
  end;
end;

procedure OnKnifeKick_Patch(); stdcall;
asm
    push 0                  //забиваем место под название анимы
    pushad
    pushfd
    jne @second_type
      push 1
      jmp @call_proc
    @second_type:
      push 2
    @call_proc:
    push esi
    call anm_attack_selector  //получаем строку с именем анимы
    mov ecx, [esp+$28]      //запоминаем адрес возврата
    mov [esp+$28], eax      //кладем на его место результирующую строку
    mov [esp+$24], ecx      //перемещаем адрес возврата на 4 байта выше в стеке
    popfd
    popad
    ret
end;

{procedure OnKnifeKick_Patch(); stdcall;
asm
  //original
  mov ebp, [esp+$10]
  cmp ebp, 5


  pushad
  pushfd
  //select type
  jne @second_type
    push 1
    jmp @call_proc
  @second_type:
    push 2
  @call_proc:
  push esi
  call OnKnifeKick

  popfd
  popad
  ret
end; }
//---------------------------------------------------------------------------------------------------------
procedure LaserSwitch(wpn:pointer; param:integer); stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  buf.SetLaserEnabledStatus(not buf.IsLaserEnabled());
  MakeLockByConfigParam(wpn, GetHUDSection(wpn), PChar('lock_time_end_'+GetActualCurrentAnim(wpn)));
end;

procedure OnLaserButton(wpn:pointer);
var
  buf:WpnBuf;
  res:boolean;
  curanm:PChar;
begin
  buf:=GetBuffer(wpn);
  if (buf<>nil) and buf.IsLaserInstalled() then begin
    res:=Weapon_SetKeyRepeatFlagIfNeeded(wpn, kfLASER);
    if res then begin
      if buf.IsLaserEnabled() then begin
        res:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_laser_on', 'sndLaserOn');
      end else begin
        res:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_laser_off', 'sndLaserOff');
      end;
    end;

    curanm:=GetActualCurrentAnim(wpn);
    if res then  begin
      StartCompanionAnimIfNeeded(rightstr(curanm, length(curanm)-4), wpn, false);
      MakeLockByConfigParam(wpn, GetHUDSection(wpn), PChar('lock_time_start_'+curanm), false, LaserSwitch);
    end;
  end;
end;


//---------------------------------------------------------------------------------------------------------
procedure TacticalTorchSwitch(wpn:pointer; param:integer); stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  buf.SwitchTorch(not buf.IsTorchEnabled());
  MakeLockByConfigParam(wpn, GetHUDSection(wpn), PChar('lock_time_end_'+GetActualCurrentAnim(wpn)));
end;

procedure OnTorchButton(wpn:pointer);
var
  buf:WpnBuf;
  res:boolean;
  curanm:PChar;
begin
  buf:=GetBuffer(wpn);
  if (buf<>nil) and buf.IsTorchInstalled() then begin
    res:=Weapon_SetKeyRepeatFlagIfNeeded(wpn, kfTACTICALTORCH);
    if res then begin
      if buf.IsTorchEnabled() then begin
        res:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_torch_on', 'sndTorchOn');
      end else begin
        res:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_torch_off', 'sndTorchOff');
      end;
    end;

    //подобная схема назначения лока нужна из-за того, что анима после переключения должна продолжать играться
    curanm:=GetActualCurrentAnim(wpn);
    if res then  begin
      StartCompanionAnimIfNeeded(rightstr(curanm, length(curanm)-4), wpn, false);
      MakeLockByConfigParam(wpn, GetHUDSection(wpn), PChar('lock_time_start_'+curanm), false, TacticalTorchSwitch);
    end;
  end;
end;

//---------------------------------------------------------------------------------------------------------
procedure OnZoomAlterButton(wpn:pointer; flags:cardinal);
var
  buf:WpnBuf;
  act:pointer;
begin

    buf:=GetBuffer(wpn);
    if (buf=nil) or not CanUseAlterScope(wpn) then exit;
    
    act:=GetActor();
    if (act=nil) or (act<>GetOwner(wpn)) then exit;
    
    if not CanAimNow(wpn) then begin
     if IsHolderInSprintState(wpn) and not IsAimToggle() then begin
      SetActorActionState(act, actSprint, false, mState_WISHFUL);
     end;
     exit;
    end;

    if IsAimToggle() then begin
      if flags=kActPress then begin
        if not IsAimNow(wpn) then begin
          buf.SetAlterZoomMode(true);
          virtual_Action(wpn, kWPN_ZOOM, kActPress);
        end else if buf.IsAlterZoomMode() then begin
          buf.SetAlterZoomMode(false);
          virtual_Action(wpn, kWPN_ZOOM, kActPress);
        end;
      end;
    end else begin
      if (flags=kActPress) and not IsAimNow(wpn) then begin
          buf.SetAlterZoomMode(true);
          virtual_Action(wpn, kWPN_ZOOM, kActPress);
      end else if (flags=kActRelease) and IsAimNow(wpn) and buf.IsAlterZoomMode() then begin
          buf.SetAlterZoomMode(false);
          virtual_Action(wpn, kWPN_ZOOM, kActRelease);
      end;
    end;
end;
//---------------------------------------------------------------------------------------------------------
function CWeapon__Action(wpn:pointer; id:cardinal; flags:cardinal):boolean; stdcall;
//вернуть true, если дальше обрабатывать нажатие не надо
var
  buf:WpnBuf;
begin
  result:=false;
  buf:=GetBuffer(wpn);
  if (buf<>nil) and ((id=kWPN_ZOOM_ALTER) or (id= kWPN_ZOOM)) and (GetAimFactor(wpn)>0) and not IsAimNow(wpn) and (buf.IsAlterZoomMode()<>buf.IsLastZoomAlter())  then begin
    result:=true;
    exit;
  end;


  if (id=kLASER) and (flags=kActPress) then begin
    OnLaserButton(wpn);
  end else if (id=kTACTICALTORCH) and (flags=kActPress) then begin
    OnTorchButton(wpn);
  end else if (id=kWPN_ZOOM_ALTER) then begin
    OnZoomAlterButton(wpn, flags);
  end else if (id=kWPN_ZOOM) then begin
    if (buf<>nil) and IsAimNow(wpn) and buf.IsAlterZoomMode() then begin
      result:=true;
    end;
  end else if (id=kWPN_ZOOM_INC) or (id=kWPN_ZOOM_DEC) then begin
    if (buf<>nil) and IsAimNow(wpn) and buf.IsAlterZoomMode() then begin
      result:=true;
    end;  
  end;
end;

procedure CWeapon__Action_Patch(); stdcall;
asm
  mov esi, ecx
  pushad
    push ebx
    push edi
    push ecx
    call CWeapon__Action
    test al, al
  popad
end;

//---------------------------------------------------------------------------------------------------------------------

procedure CWeapon__OnAnimationEnd(wpn:pointer); stdcall;
var
  act:pointer;
  anm:PChar;
begin
  act:=GetActor();
  //пофиксим рассинхрон аним ствола и детектора в беге
  //делаем это принудительным переназначением аним идла
  if (act<>nil) and (act=GetOwner(wpn)) and (leftstr(GetActualCurrentAnim(wpn), length('anm_idle'))='anm_idle')
    //если бег уже кончился - то забываем
    and GetActorActionState(act, actModSprintStarted, mstate_REAL) and GetActorActionState(act, actSprint, mstate_REAL)
  then begin
    SetActorActionState(act, actModNeedMoveReassign, true);
  end;

  anm:=GetActualCurrentAnim(wpn);
  if (GetActorActiveItem()=wpn) and (leftstr(anm, length('anm_idle'))<>'anm_idle') then ResetDOF(ReadActionDOFSpeed_Out(wpn, anm));

  //если у нас аниматор удара и мы продолжаем жать кнопку удара, то возвращаемся обратно в состояние доставания :)
  if (GetActorActiveItem()=wpn) and GetActorKeyRepeatFlag(kfQUICKKICK) and (GetSection(wpn)=GetKickAnimator()) then begin
    SetActorKeyRepeatFlag(kfQUICKKICK, false);
    virtual_CHudItem_SwitchState(wpn, EHudStates__eShowing);
    SetActorActionCallback(@KickCallback);
  end;
end;

procedure CWeapon__OnAnimationEnd_Patch(); stdcall;
asm
  pushad
    sub ecx, $2e0
    push ecx
    call CWeapon__OnAnimationEnd
  popad

  mov eax, xrgame_addr //джампим на предка - исходное.
  add eax, $2F9640
  jmp eax
end;

//---------------------------------------------------------------------------------------------------------------------
procedure CWeaponKnife__OnAnimationEnd(wpn:pointer); stdcall;
var
  act:pointer;
begin
  act:=GetActor;
  if (wpn=GetActorActiveItem) and (GetActualCurrentAnim(wpn)='anm_selfkill') then begin
    CActor__Die(act, act);
  end;
  
  //ВНИМАНИЕ! Зачастую CWeapon__OnAnimationEnd и так вызовется из-за передачи управления методу родителя, см. код игры
  CWeapon__OnAnimationEnd(wpn);
end;

procedure CWeaponKnife__OnAnimationEnd_Patch(); stdcall;
asm
  pushad
    sub ecx, $2e0
    push ecx
    call CWeaponKnife__OnAnimationEnd
  popad
  mov eax, [esp+8]
  cmp eax, 6
  ret
end;


//---------------------------------------------------------------------------------------------------------------------


procedure CHudItem__SendHiddenItem_Patch(); stdcall;
asm
  pushad
    sub ecx, $2e0
    push ecx
    call WeaponEvents.OnWeaponHide
    cmp al, 1
  popad
  je @finish
    //выходим из текущей и вызывающей сразу
    pop eax
    ret
  @finish:
  mov eax, $4014
  ret
end;

//----------------------------------------------------------------------------------------------------------
procedure CWeaponMagazined__OnAnimationEnd(wpn:pointer); stdcall;
begin
  //тут что-то было... И может быть будет
end;

procedure CWeaponMagazined__OnAnimationEnd_Patch(); stdcall;
asm
  pushad
    sub ecx, $2e0
    push ecx
    call CWeaponMagazined__OnAnimationEnd
  popad
  cmp edi, $07
  mov esi, ecx
end;


procedure CWeaponShotgun__OnAnimationEnd_OnClose(wpn:pointer); stdcall;
var
  anm:PChar;
begin
  anm:=GetActualCurrentAnim(wpn);
  ResetDOF(ReadActionDOFSpeed_Out(wpn, anm));
end;

procedure CWeaponShotgun__OnAnimationEnd_OnClose_Patch(); stdcall;
asm
  pushad
    sub esi, $2e0
    push esi
    call CWeaponShotgun__OnAnimationEnd_OnClose
  popad
  mov [esi+$179], al
end;

procedure CEatableItemObject__OnH_A_Independent_Patch(); stdcall;
asm
  pushad
    lea ecx, [esi+$F0]
    mov eax, xrgame_addr
    call [eax+$512c88] //вырезанное - CPhysicItem::OnH_A_Independent
  popad
  pushad
    //скрываем бесполезный предмет
    mov ecx, esi
    mov eax, [esi]
    mov edx, [eax+$3c]
    call edx   //this->Useful()
    test al, al
    jne @finish
      mov ecx, [esi+$d4]
      push 00
      mov eax, xrEngine_addr
      add eax, $196b0
      call eax //SetVisible(false)

      mov ecx, [esi+$d4]
      push 00
      mov eax, xrEngine_addr
      add eax, $19670
      call eax //SetEnabled(false)
    @finish:
  popad

  pop esi //вырезанное
end;

procedure CWeaponMagazined__InitAddons_Patch; stdcall;
asm
  fstp dword ptr [esi+$4a4]
  mov eax, [esi+$4a4]
  mov [esi+$4C0], eax // m_fRTZoomFactor = m_zoom_params.m_fScopeZoomFactor
end;

//----------------------------------------------------------------------------------------------------------
procedure CWeapon__OnZoomOut(wpn:pointer); stdcall;
begin
  if IsDynamicDOF() then begin
    ResetDof(game_ini_r_single_def(GetHUDSection(wpn),'zoom_out_dof_speed', GetDefaultDOFSpeed_Out()));
  end;
end;

procedure CWeapon__OnZoomOut_Patch(); stdcall;
asm
  pushad
    push esi
    call CWeapon__OnZoomOut
  popad
  fld [esi+$498]
end;



procedure CWeapon__OnZoomIn(wpn:pointer); stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if (buf<>nil) then begin
    buf.SetLastZoomAlter(buf.IsAlterZoomMode());

    if buf.IsAlterZoomMode() then begin
      SetZoomFactor(wpn, GetAlterScopeZoomFactor(wpn));
    end;
  end;
end;

procedure CWeapon__OnZoomIn_Patch(); stdcall;
asm
  pushad
    push esi
    call CWeapon__OnZoomIn
  popad
  lea ecx, [esi+$2e0]
end;

//----------------------------------------------------------------------------------------------------------
procedure CHudItem__OnAnimationEnd(wpn:pointer); stdcall;
begin
  if (GetCurrentState(wpn) = EHudStates__eIdle) and IsPending(wpn) then begin
    EndPending(wpn);
  end;
end;

procedure CHudItem__OnAnimationEnd_Patch(); stdcall;
asm
  pushad
    sub ecx, $2e0
    push ecx
    call CHudItem__OnAnimationEnd
  popad
  cmp [esp+8], 4
end;

procedure CHudItem__OnMotionMark(wpn:pointer); stdcall;
var
  anm:pchar;
begin
  //работает для ножа и бросабельных
{  if IsPending(wpn) and (GetCurrentState(wpn)=EHudStates__eIdle) then begin
    anm:=GetActualCurrentAnim(wpn);
    if anm='anm_headlamp_on' then begin
    end else if anm='anm_headlamp_off' then begin
    end else if anm='anm_nv_on' then begin
    end else if anm='anm_nv_off' then begin
    end;
  end;  }
end;

procedure CWeaponKnife__OnMotionMark_Patch(); stdcall;
asm
  pushad
    sub ecx, $2e0
    push ecx
    call CHudItem__OnMotionMark
  popad
  push eax
  push eax


  //was original: cmp eax, 05 || push esi ||mov esi, ecx
  mov eax, [esp+8]
  mov [esp+4], eax
  mov [esp+8], esi

  pop eax
  cmp eax, 05
  mov esi, ecx
end;

//----------------------------------------------------------------------------------------------------------
procedure CWeaponKnife__OnStateSwitch_SetPending_Patch(); stdcall;
asm
  mov eax, [esi-$2e0]
  or word ptr [esi-$2e0+$2f4], 01 //SetPending(true)
end;
//----------------------------------------------------------------------------------------------------------
function Init:boolean;
var
  jmp_addr:cardinal;
begin
  result:=false;

  //Событие назначения клина
  jmp_addr:= xrGame_addr+$2BD0AF;
  if not WriteJump(jmp_addr, cardinal(@WeaponJammed_Patch),16, true) then exit;

  //Событие осечки/пустого магазина
  jmp_addr:=xrGame_addr+$2CCD75;
  if not WriteJump(jmp_addr, cardinal(@EmptyClick_Patch), 8, true) then exit;

  //-----------------------------------------------------------------------------------------------------
  //Аттач прицела
  InitAttachAddon(xrGame_addr+$2CEE33, $11);
  //                           register^|^addon type  
  //Аттач подствола(мертвый?)
  InitAttachAddon(xrGame_addr+$2CEEF5, $12);
  //второй аттач подствола, живой
  InitAttachAddon(xrGame_addr+$2D26F7, $02);

  //Аттач глушителя
  InitAttachAddon(xrGame_addr+$2CEE5A, $14);  

  //-----------------------------------------------------------------------------------------------------
  //Детач глушителя
  InitDetachAddon(xrGame_addr+$2CDB22, 4, 38);

  //детач подствола(мертвый?), содержит джамп на детач другого аддона, поэтому пишем только пуш типа аддона
  InitDetachAddon(xrGame_addr+$2CDBAE, 2, 0, true);
  //второй детач подствола, реально используемый
  InitDetachAddon(xrGame_addr+$2D3BA1, 2, 82);

  //Детач прицела
  InitDetachAddon(xrGame_addr+$2CDA89, 1, 38);
  if not nop_code(xrGame_addr+$2CDA1E, 6) then exit;//нопим вызов процедуры, сбрасывающей флаг прицела
  //-----------------------------------------------------------------------------------------------------
  //разрядка магазина
  jmp_addr:= xrGame_addr+$46E0C4;
  if not WriteJump(jmp_addr, cardinal(@UnloadMag_Patch), 5, true) then exit;
  //-----------------------------------------------------------------------------------------------------

  //спавн и дестрой
  jmp_addr:=xrGame_addr+$2C120B;
  if not WriteJump(jmp_addr, cardinal(@CWeapon_NetSpawn_Patch_middle),6, true) then exit;

  jmp_addr:=xrGame_addr+$2C1328;
  if not WriteJump(jmp_addr, cardinal(@CWeapon_NetSpawn_Patch_end),6, true) then exit;

  jmp_addr:=xrGame_addr+$2BEFE9;
  if not WriteJump(jmp_addr, cardinal(@CWeapon_NetDestroy_Patch),6, true) then exit;

  upgrade_weapon_addr:=xrGame_addr+$2D09D6;
  if not WriteJump(upgrade_weapon_addr, cardinal(@Upgrade_Weapon_Patch), 5) then exit;
  //поправим баг с недопереключением режима стрельбы во время апгрейда
  nop_code(xrGame_addr+$2d0abe, 6);


  //добавим анимы смены режима стрельбы
  if not InitChangeFireMode(xrGame_addr+$2CE2E0,0) then exit;
  if not InitChangeFireMode(xrGame_addr+$2CE340,1) then exit;


  //модифицированный обработчик отображения сообщения о клине
  jmp_addr:=xrGame_addr+$2CFF6B;
  if not WriteJump(jmp_addr, cardinal(@OnJammedHintShow_Patch), 19, true) then exit;

  //Обработчик OnSwitchState
  jmp_addr:=xrGame_addr+$2BC4D7;
  if not WriteJump(jmp_addr, cardinal(@CHudItem__SwitchState_Patch), 10, false) then exit;


  //селектор анимации удара + Анимация для детектора в паре с ножом
  jmp_addr:=xrGame_addr+$2d5491;
  if not WriteJump(jmp_addr, cardinal(@OnKnifeKick_Patch), 5, true) then exit;
  jmp_addr:=xrGame_addr+$2d54A6;
  if not WriteJump(jmp_addr, cardinal(@OnKnifeKick_Patch), 5, true) then exit;

  //обработка дополнительных клавиатурных действий
  jmp_addr:=xrGame_addr+$2BEC7B;
  if not WriteJump(jmp_addr, cardinal(@CWeapon__Action_Patch), 11, true) then exit;


  //исправляем рассинхрон с детектором
  jmp_addr:=xrGame_addr+$2bc7e0;
  if not WriteJump(jmp_addr, cardinal(@CWeapon__OnAnimationEnd_Patch), 5, false) then exit;

  //[bug] фикс убирания оружия для пианистов
  jmp_addr:=xrGame_addr+$2F96A0;
  if not WriteJump(jmp_addr, cardinal(@CHudItem__SendHiddenItem_Patch), 5, true) then exit;
  jmp_addr:=xrGame_addr+$2d4f30;
  if not WriteJump(jmp_addr, cardinal(@CWeaponKnife__OnAnimationEnd_Patch), 7, true) then exit;
  jmp_addr:=xrGame_addr+$2CCD86;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazined__OnAnimationEnd_Patch), 5, true) then exit;
  jmp_addr:=xrGame_addr+$2DE3DB;
  if not WriteJump(jmp_addr, cardinal(@CWeaponShotgun__OnAnimationEnd_OnClose_Patch), 6, true) then exit;

  jmp_addr:= xrgame_addr+$2BEE13;
  if not WriteJump(jmp_addr, cardinal(@CWeapon__OnZoomOut_Patch), 6, true) then exit;

  jmp_addr:= xrgame_addr+$2C07E5;
  if not WriteJump(jmp_addr, cardinal(@CWeapon__OnZoomIn_Patch), 6, true) then exit;

  //[bug] фикс показа в руке аптеки при съедении перед дестроем
  jmp_addr:=xrGame_addr+$2AC678;
  if not WriteJump(jmp_addr, cardinal(@CEatableItemObject__OnH_A_Independent_Patch), 14, false) then exit;

  //[bug] фикс неопределенного поведения при аттаче прицела с переменной кратностью к только что заспавненному оружию
  jmp_addr:=xrGame_addr+$2CDD6B;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazined__InitAddons_Patch), 6, true) then exit;
  //[bug] фикс возможности прервать анимацию доставания у ножа
  jmp_addr:=xrGame_addr+$2D5C87;
  if not WriteJump(jmp_addr, cardinal(@CWeaponKnife__OnStateSwitch_SetPending_Patch), 6, true) then exit;
  jmp_addr:=xrGame_addr+$2D5CA0;
  if not WriteJump(jmp_addr, cardinal(@CWeaponKnife__OnStateSwitch_SetPending_Patch), 6, true) then exit;

  jmp_addr:=xrGame_addr+$2F9640;
  if not WriteJump(jmp_addr, cardinal(@CHudItem__OnAnimationEnd_Patch), 5, true) then exit;

  jmp_addr:=xrGame_addr+$2D6B97;
  if not WriteJump(jmp_addr, cardinal(@CWeaponKnife__OnMotionMark_Patch), 6, true) then exit;

  result:=true;
end;


end.

