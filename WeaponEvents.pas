unit WeaponEvents;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface
uses Vector;

function Init:boolean;

procedure OnWeaponExplode_AfterAnim(wpn:pointer; param:integer);stdcall;
function OnWeaponHide(wpn:pointer):boolean;stdcall;
procedure OnWeaponHideAnmStart(wpn:pointer);stdcall;
procedure OnWeaponShow(wpn:pointer);stdcall;
function OnWeaponAimIn(wpn:pointer):boolean;stdcall;
function OnWeaponAimOut(wpn:pointer):boolean;stdcall;
function Weapon_SetKeyRepeatFlagIfNeeded(wpn:pointer; kfACTTYPE:cardinal):boolean;stdcall;
function CHudItem__OnMotionMark(wpn:pointer):boolean; stdcall;
procedure RPG7ReactiveHit(wpn:pointer); stdcall;

procedure TryShootGLFix(wpn:pointer); stdcall;

implementation
uses Messenger, BaseGameData, Misc, HudItemUtils, WeaponAnims, LightUtils, WeaponAdditionalBuffer, sysutils, ActorUtils, DetectorUtils, strutils, dynamic_caster, weaponupdate, KeyUtils, gunsl_config, xr_Cartridge, ActorDOF, MatVectors, ControllerMonster, collimator, level, WeaponAmmoCounter, xr_RocketLauncher, xr_strings, Throwable, UIUtils, BallisticsCorrection, RayPick, burer, HitUtils;

var
  upgrade_weapon_addr:cardinal;

//-------------------------------Разряжание магазина-----------------------------
procedure OnUnloadInEndOfAnim(wpn:pointer; param:integer);stdcall;
begin
  virtual_CWeaponMagazined__UnloadMagazine(wpn, true);
  ForceWpnHudBriefUpdate(wpn);
  SetAnimForceReassignStatus(wpn, true);
end;

procedure OnUnloadInMiddleAnim(wpn:pointer; param:integer);stdcall;
begin
  virtual_CWeaponMagazined__UnloadMagazine(wpn, true);
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

  if IsMandatoryAnimatedUnloadMag() and (not CheckActorWeaponAvailabilityWithInform(wpn)) then exit;

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
  end else begin
    //анима не стартовала - оружие занято
    result := true;
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
  key:cardinal;

begin
  act:=GetActor();
  if ((act=nil) or (GetOwner(wpn)<>act)) or (IsAnimatedAddons() and not CheckActorWeaponAvailabilityWithInform(wpn)) then exit;

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

        if IsAimNow(wpn) then begin
          if IsAlterZoom(wpn) then begin
            key:=kWPN_ZOOM_ALTER;
          end else begin
            key:=kWPN_ZOOM;
          end;

          if IsAimToggle() then
            virtual_Action(wpn, key, kActPress)
          else
            virtual_Action(wpn, key, kActRelease);
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

        if IsAimNow(wpn) then begin
          if IsAimToggle() then
            virtual_Action(wpn, kWPN_ZOOM, kActPress)
          else
            virtual_Action(wpn, kWPN_ZOOM, kActRelease);
        end;
      end;
    else begin
      log('WeaponEvents.OnAddonDetach: Invalid addontype!', true);
      exit;
    end;
  end;
  hud_sect:=GetHUDSection(wpn);

  CHudItem_Play_Snd(wpn, 'sndAddonDetach');  
  if (not IsAnimatedAddons()) or (param_name=nil) or (not game_ini_line_exist(hud_sect, param_name)) or (not game_ini_r_bool(hud_sect, param_name)) then begin
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

procedure SetNewScopeId(wpn:pointer; new_id:byte); stdcall;
var
  buf:WpnBuf;
  last_id:cardinal;
begin
  buf:=GetBuffer(wpn);
  if buf <> nil then begin
    if IsScopeAttached(wpn) then begin
      last_id:=GetCurrentScopeIndex(wpn);
    end else begin
      last_id:=$FFFFFFFF;
    end;
    buf.SetLastScopeId(last_id);
  end;

  SetCurrentScopeType(wpn, new_id);
end;

procedure CWeaponMagazined__Attach_saveprevscope_Patch(); stdcall;
asm
  pushad
  xor ecx, ecx
  mov cl, al
  push ecx
  push ebp
  call SetNewScopeId
  popad
end;

function OnAddonAttach(wpn:pointer; addontype:integer):boolean;stdcall;
var addonname:PChar;
    actor:pointer;
    snd_name:PChar;
    param_name:PChar;
    anim_name:string;
    hud_sect, sect:PChar;
    err_msg:PChar;
    key:cardinal;
    need_detach_gl, need_detach_sil:boolean;
    need_detach_scope_id, tmpid:cardinal;
    buf:WpnBuf;
begin
  param_name:=nil;
  snd_name:=nil;
  sect:=GetSection(wpn);
  err_msg:=nil;
  need_detach_scope_id:=$FFFFFFFF;
  need_detach_gl:=false;
  need_detach_sil:=false;

  buf:=GetBuffer(wpn);
  if buf <> nil then begin
    buf.need_update_icon:=true;
  end;

  case addontype of
    1:begin
        //log ('scope_att');
        addonname:=GetCurrentScopeSection(wpn);
        if addonname=nil then log('WpnEvents.OnAddonAttach: Scope has no section?!');
        addonname:=game_ini_read_string(addonname, 'scope_name');
        param_name:='use_scopeattach_anim';
        anim_name:='anm_attach_scope_'+addonname;
        snd_name:='sndScopeAtt';

        if IsScopeAttached(wpn) and (buf <> nil) then begin
          err_msg:='gunsl_msg_need_detach_scope';
          need_detach_scope_id:=buf.GetLastScopeId();
        end;

        if IsSilencerAttached(wpn) and game_ini_line_exist(sect, 'restricted_scope_and_sil') and game_ini_r_bool(sect, 'restricted_scope_and_sil')  then begin
          err_msg:='gunsl_msg_sil_restricts_scope';
          need_detach_sil:=true;
        end;

        if IsGLAttached(wpn) and game_ini_line_exist(sect, 'restricted_scope_and_gl') and game_ini_r_bool(sect, 'restricted_scope_and_gl') then begin
          err_msg:='gunsl_msg_gl_restricts_scope';
          need_detach_gl:=true;
        end;

        if IsAimNow(wpn) then begin
          if IsAlterZoom(wpn) then begin
            key:=kWPN_ZOOM_ALTER;          
          end else begin
            key:=kWPN_ZOOM;
          end;

          if IsAimToggle() then
            virtual_Action(wpn, key, kActPress)
          else
            virtual_Action(wpn, key, kActRelease);
        end;
      end;
    4:begin
        //log ('sil_att');
        param_name:='use_silattach_anim';
        anim_name:='anm_attach_sil';
        snd_name:='sndSilAtt';
        addonname:=GetSilencerSection(wpn);

        if IsSilencerAttached(wpn) then begin
          err_msg:='gunsl_msg_need_detach_silencer';
          need_detach_sil:=true;
        end;

        if IsScopeAttached(wpn) and game_ini_line_exist(sect, 'restricted_scope_and_sil') and game_ini_r_bool(sect, 'restricted_scope_and_sil')  then begin
          err_msg:='gunsl_msg_scope_restricts_sil';
          need_detach_scope_id:=GetCurrentScopeIndex(wpn);
        end;

        if IsGLAttached(wpn) and game_ini_line_exist(sect, 'restricted_gl_and_sil') and game_ini_r_bool(sect, 'restricted_gl_and_sil') then begin
          err_msg:='gunsl_msg_gl_restricts_sil';
          need_detach_gl:=true;
        end;
      end;
    2:begin
        //log('gl_att');
        param_name:='use_glattach_anim';
        anim_name:='anm_attach_gl';
        snd_name:='sndGLAtt';
        addonname:=GetGLSection(wpn);

        if IsGLAttached(wpn) then begin
          err_msg:='gunsl_msg_need_detach_gl';
          need_detach_gl:=true;
        end;

        if IsScopeAttached(wpn) and game_ini_line_exist(sect, 'restricted_scope_and_gl') and game_ini_r_bool(sect, 'restricted_scope_and_gl')  then begin
          err_msg:='gunsl_msg_scope_restricts_gl';
          need_detach_scope_id:=GetCurrentScopeIndex(wpn);
        end;

        if IsSilencerAttached(wpn) and game_ini_line_exist(sect, 'restricted_gl_and_sil') and game_ini_r_bool(sect, 'restricted_gl_and_sil') then begin
          err_msg:='gunsl_msg_sil_restricts_gl';
          need_detach_sil:=true;
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
  if not IsAnimatedAddons() then begin
    // про сброс флагов при детаче не беспокоимся - движок сам выставим нужный нам флаг после того, как мы отработаем
    if need_detach_scope_id <> $FFFFFFFF then begin
      tmpid:=GetCurrentScopeIndex(wpn);
      SetCurrentScopeType(wpn, need_detach_scope_id);
      DetachAddon(wpn, 1);
      SetCurrentScopeType(wpn, tmpid);
    end else if need_detach_gl then begin
      DetachAddon(wpn, 2);
    end else if need_detach_sil then begin
      DetachAddon(wpn, 4);
    end;

    result:=true;
  end else if (actor<>nil) and (actor=GetOwner(wpn)) and (not CheckActorWeaponAvailabilityWithInform(wpn)) then begin
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

  if result then begin
    CHudItem_Play_Snd(wpn, 'sndAddonAttach');
  end else begin
    CHudItem_Play_Snd(wpn, 'sndAddonAttachFail');
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
procedure OnCWeaponNetSpawn_middle(wpn:pointer; swpn:pointer);stdcall;
var
  scope_id, wpnstate:byte;
begin
  if WpnCanShoot(wpn) then begin
    //буфер может уже быть создан в load'e - проверим это
    if (GetBuffer(wpn)=nil) then begin
      WpnBuf.Create(wpn);
    end;
  end;

  //В 5 старших битах на стороне серверного объекта мы сохраняем индекс прицела
  wpnstate:=CSE_GetAddonsFlags(swpn);
  scope_id:=wpnstate shr 3;
  if scope_id<>0 then begin
    SetCurrentScopeType(wpn, scope_id);
    wpnstate := wpnstate and $7;
  end;
  CSE_SetAddonsFlags(swpn, wpnstate);

  //перенести в область движкового кода после вычитки m_flagsAddOnState
  if (IsScopeAttached(wpn) or (GetCurrentScopeIndex(wpn) > 0)) and (GetCurrentScopeIndex(wpn) >= GetScopesCount(wpn)) then begin
    //Проблема - прицел не существует! Сбрасываем флаг
    Log('Invalid scope ID '+inttostr(GetCurrentScopeIndex(wpn))+' for '+GetSection(wpn)+', reset ID', true);
    SetCurrentScopeType(wpn, 0);
  end;
end;

procedure OnCWeaponNetSpawn_end(wpn:pointer);stdcall;
var
  buf:WpnBuf;
  i:word;
  c:pointer;
  sect, scope_sect:PChar;
  slot:integer;

  visual:pchar;
  banned_visuals, banned_item:string;
begin

  banned_visuals:=game_ini_read_string_def(GetSection(wpn), 'banned_visuals', '');
  visual:=GetWeaponVisualName(wpn);
  if (visual<>nil) and (length(banned_visuals) > 0) then begin
    banned_visuals:=banned_visuals;
    while (GetNextSubStr(banned_visuals, banned_item, ',')) do begin
      if visual = banned_item then begin
        log('Found banned visual "'+visual+' for '+GetSection(wpn)+', reset it');
        visual:=game_ini_read_string_def(GetSection(wpn), 'visual', '');
        if length(visual) > 0 then begin
          SetWpnVisual(wpn, visual);
        end;
        break;
      end;
    end;
  end;

  //выставим сохраненные типы патронов
  if WpnCanShoot(wpn) then begin
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

      //Т.к. load выполняется раньше применения апгрейдов, то все вносимые ими изменения будут еще невалидны!
      //Из-за этого мы вынуждены выносить зависящую от них логику сюда - тут апгрейды уже есть.
      scope_sect:=GetSection(wpn);
      if IsScopeAttached(wpn) and (GetScopeStatus(wpn)=2) then begin
        scope_sect:=game_ini_read_string(GetCurrentScopeSection(wpn), 'scope_name');
      end;
      buf.LoadNightBrightnessParamsFromSection(scope_sect);
    end;
  end;
  SetAnimForceReassignStatus(wpn, true);

end;

procedure CWeapon_NetSpawn_Patch_middle();
asm

    pushad
    pushfd

    push edi
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
    mov byte ptr [esi+$6a0], al
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
var
  buf:WpnBuf;
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
procedure Upgrade_Weapon_Patch(); stdcall;
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
  sitm:pCSE_Abstract;
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

function IsJamProhibited(wpn:pointer):boolean; stdcall;
var
  c_cur, c_next:pCCartridge;
  ammoc:cardinal;
begin
  // Если реальный тип патрона в стволе и следующего патрона (того, который будет заряжен после выстрела) отличаются между собой - клинить нельзя!
  // Иначе на дробовиках гильза поменяет цвет после окончания анимации заклина
  result:=false;

  if IsGrenadeMode(wpn) then exit;

  ammoc:=GetAmmoInMagCount(wpn);
  if ammoc <= 0 then exit;
  c_cur:=GetCartridgeFromMagVector(wpn, ammoc-1);

  if ammoc=1 then begin
    result:=GetAmmoTypeIndex(wpn, false) <> GetCartridgeType(c_cur);
  end else begin
    c_next:=GetCartridgeFromMagVector(wpn, ammoc-2);
    result:=GetCartridgeType(c_cur)<>GetCartridgeType(c_next);
  end;
end;

function OnWeaponJam(wpn:pointer):boolean;stdcall;
//сейчас с оружием произойдет что-то нехорошее...
//вернуть false, если не стрелять перед клином, true - если стрелять
var sect:PChar;
    owner:pointer;
    startcond, endcond, curcond, startprob, endprob, curprob:single;
    anm:string;
    buf:WpnBuf;
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

  if FindBoolValueInUpgradesDef(wpn, 'can_explose', game_ini_r_bool_def(sect, 'can_explose', false), true) then begin
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
        if (GetScopeStatus(wpn)=2) and IsScopeAttached(wpn) and game_ini_r_bool_def(GetHUDSection(wpn), 'aim_scope_anims', true) then anm:=anm+'_scope';
        buf:=GetBuffer(wpn);
        if buf<>nil then begin
          if GetActorActiveItem()=wpn then begin
            buf.ApplyLensRecoil(buf.GetMisfireRecoil);
          end;
        end;        
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
    call IsJamProhibited
    cmp al, 0
  popad
  je @jam_allowed
  mov byte ptr [esi+$45A], 0 //сбрасываем возможный заклин
  xor eax, eax               //говорим, что осечки нет
  jmp @finish

  @jam_allowed:
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

procedure OnJammedHintShow(); stdcall;
//var
//  wpn:pointer;
begin
//  wpn:=GetActorActiveItem();
//  if (wpn=nil) or not WpnCanShoot(PChar(GetClassName(wpn))) then exit;
//  if not (IsExplosed(wpn) or (IsActionProcessing(wpn) and (leftstr(GetCurAnim(wpn), length('anm_fakeshoot'))<>'anm_fakeshoot'))) then begin
//    Messenger.SendMessage('gun_jammed', gd_novice);
//  end;
end;

procedure OnJammedHintShow_Patch(); stdcall;
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
  buf:WpnBuf;
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

    buf:=GetBuffer(wpn);
    if buf<>nil then begin
      buf.ApplyLensRecoil(buf.GetMisfireRecoil);
    end;
  end;
end;

procedure EmptyClick_Patch; stdcall;
asm
    pushad
    sub ecx, $2e0
    push ecx
    call OnEmptyClick
    popad
    ret
end;
//------------------------------------------------------------------------------

function OnWeaponHide(wpn:pointer):boolean;stdcall;
var
  act, owner, itm:pointer;
  state:cardinal;
begin

  //вернуть, можно скрывать или нет
  //работает для всех CHudItem! кроме детекторов (?)
  act:=GetActor();
  owner:=GetOwner(wpn);

  if (owner<>act) and (act<>nil) then begin
    result:=true;
    exit;
  end;


  if not (WpnCanShoot(wpn)) then begin
    result:=true;
    state:=GetCurrentState(wpn);

    if (IsActorSuicideNow() or IsSuicideAnimPlaying(wpn)) then begin
      result:=false;
      exit;
    end;

    if (act<>nil) and (owner=act) and IsThrowable(wpn) and ((state=EMissileStates__eReady) or (state=EMissileStates__eThrowStart) or (state=EMissileStates__eThrow) or (state=EMissileStates__eThrowEnd)) then begin
      result:=false;
    end;

    if IsBino(wpn) and (IsAimNow(wpn) or (leftstr(GetActualCurrentAnim(wpn), length('anm_idle_aim'))='anm_idle_aim')) then begin
      if IsAimNow(wpn) then begin
        if IsAimToggle() then virtual_Action(wpn, kWPN_ZOOM, kActPress) else virtual_Action(wpn, kWPN_ZOOM, kActRelease);
        SetActorActionState(act, actModNeedMoveReassign, true);
      end;
      result:=false
    end;
    exit;
  end;

  result:=CanHideWeaponNow(wpn);

  if (act<>nil) and (owner=act) then begin
    if result then begin
      if (GetBuffer(wpn)<>nil) and (not IsReloaded(wpn)) and OnActWhileReload_CanActNow(wpn) then begin
        CWeaponMagazined__OnAnimationEnd_DoReload(wpn);
        SetReloaded(wpn, false); //чтобы аверы не ругались, надо так :(
        SetReloaded(wpn, true);
      end;
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
  if IsKnife(wpn) then begin
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
  last_pdahide_state:boolean;
begin
  //У ножа нет звука доставания. Воспроизведем.
  if IsKnife(wpn) then begin
    CHudItem_Play_Snd(wpn, 'sndShow');
  end;

  act:=GetActor();
  owner:=GetOwner(wpn);

  if (owner<>nil) and (owner=act) then begin
    //фикс бага с доставанием предмета без смены худовой секции, когда анима доставания не игралась

    player_hud__attach_item(wpn);


    last_pdahide_state:=GetActorKeyRepeatFlag(kfPDAHIDE);
    ClearActorKeyRepeatFlags();
    ResetChangedGrenade();
    SetActorKeyRepeatFlag(kfPDAHIDE, last_pdahide_state);
    
    SetActorActionState(act, actSprint, false, mState_WISHFUL);
    ResetActorFlags(act);
    det:=ItemInSlot(act, 9);
    if (det<>nil) and not CanUseDetectorWithItem(wpn) then begin
      ForceHideDetector(det);
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

    if IsActorPlanningSuicide() and CheckActorVisibilityForController() then begin
      if not IsActorSuicideNow() then begin
        CHudItem_Play_Snd(knife, 'sndPrepareSuicide');
        result:='anm_prepare_suicide';
      end else begin
        SetDisableInputStatus(true);
        result:='anm_selfkill';
        CHudItem_Play_Snd(knife, 'sndSelfKill');
        NotifySuicideShotCallbackIfNeeded();
      end;
      exit;
    end else if IsSuicideAnimPlaying(knife) then begin
      SetExitKnifeSuicide(false);
      SetHandsJitterTime(GetShockTime());
      CHudItem_Play_Snd(knife, 'sndStopSuicide');
      result:='anm_stop_suicide';
      NotifySuicideStopCallbackIfNeeded();
      ResetActorControl();
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
  aim_now, alter_aim_now:boolean;
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

    aim_now:=IsAimNow(wpn);
    alter_aim_now:=IsAlterZoom(wpn);

    if IsAimToggle() then begin
      if flags=kActPress then begin
        if not aim_now then begin
          //Никакое прицеливание неактивно, начинаем альтернативное
          buf.SetAlterZoomMode(true);
          virtual_Action(wpn, kWPN_ZOOM, kActPress);
        end else if alter_aim_now then begin
          //Активно альтернативное прицеливание, нажали его кнопку снова - надо выходить из него
          buf.SetAlterZoomMode(false);
          virtual_Action(wpn, kWPN_ZOOM, kActPress);
        end else begin
          //Активно обычное прицеливание, нажали кнопку альтернативного - надо перейти в альтернативное
          buf.SetLastZoomAlter(true);
          buf.SetAlterZoomMode(true);
          buf.StartAlterZoomDirectSwitchMixup();
          RefreshZoomDOF(wpn);
        end;
      end;

    end else begin

      if flags=kActPress then begin
        if not aim_now then begin
          // Никакое прицеливание неактивно - начинаем альтернативное
          buf.SetAlterZoomMode(true);
          virtual_Action(wpn, kWPN_ZOOM, kActPress);
        end else if alter_aim_now then begin
          // Уже активно альтернативное прицеливание - ничего не делаем
        end else begin
          // Активно обычное прицеливание - переходим в альтернативное
          buf.SetLastZoomAlter(true);
          buf.SetAlterZoomMode(true);
          buf.StartAlterZoomDirectSwitchMixup();
          RefreshZoomDOF(wpn);
        end;
      end else begin
        if not aim_now then begin
          // Никакое прицеливание неактивно - странно, но ничего не делаем
        end else if alter_aim_now then begin
          // Активно альтернативное прицеливание - если зажата кнопка обычного, переходим в него, иначе - выходим из прицеливания
          if IsActionKeyPressedInGame(kWPN_ZOOM) then begin
            buf.SetLastZoomAlter(false);
            buf.SetAlterZoomMode(false);
            buf.StartAlterZoomDirectSwitchMixup();
            RefreshZoomDOF(wpn);
          end else begin
            buf.SetAlterZoomMode(false);
            virtual_Action(wpn, kWPN_ZOOM, kActRelease);
          end;
        end else begin
          // Активно обычное прицеливание - ничего не делаем
        end;
      end;
    end;
end;

function OnZoomButton(wpn:pointer; flags:cardinal):boolean;
var
  buf:WpnBuf;
  aim_now, alter_aim_now:boolean;  
begin
  //Если вернем true - нажатие будет считаться обработанным и дальше не пойдет
  result:=false;
  buf:=GetBuffer(wpn);
  if buf = nil then exit;

  aim_now:=IsAimNow(wpn);
  alter_aim_now:=IsAlterZoom(wpn);
  if IsAimToggle() then begin
    if flags=kActPress then begin
      if not aim_now then begin
        // На момент нажатия клавиши не было активно никакого прицеливания, теперь (очевидно) собираемся войти в какое-то (если alter_aim_now = true - значит, в альтернативное)
        // Все сделает штатный код
        result:=false;        
      end else if alter_aim_now then begin
        // Перед нажатием клавиши уже было активно альтернативное прицеливание. Переходим в обычное
        buf.SetLastZoomAlter(false);
        buf.SetAlterZoomMode(false);
        buf.StartAlterZoomDirectSwitchMixup();
        RefreshZoomDOF(wpn);
        result:=true;
      end else begin
        // Перед нажатием клавиши уже было активно обычное прицеливание. Выходим из прицеливания
        // Все сделает штатный код
        result:=false;
      end;
    end;

  end else begin
  
    if flags=kActPress then begin
      if not aim_now then begin
        // На момент нажатия клавиши не было активно никакого прицеливания, теперь (очевидно) собираемся войти в какое-то (если alter_aim_now = true - значит, в альтернативное)
        // Все сделает штатный код
        result:=false;
      end else if alter_aim_now then begin
        // Перед нажатием клавиши уже было активно альтернативное прицеливание. Переходим в обычное
        buf.SetLastZoomAlter(false);
        buf.SetAlterZoomMode(false);
        buf.StartAlterZoomDirectSwitchMixup();
        RefreshZoomDOF(wpn);
        result:=true;
      end else begin
        // Перед нажатием клавиши уже почему-то было активно обычное прицеливание. Ничего не делаем.
        result:=true;
      end;
    end else begin
      if not aim_now then begin
        // В момент отпускания клавиши прицеливания не было. Странно, но ничего не делаем.
        result:=true;
      end else if alter_aim_now then begin
        // В момент отпускания клавиши было активно альтернативное прицеливание. Оставляем его.
        result:=true;
      end else begin
        // В момент отпускания клавиши было активно обычное прицеливание. Если зажата кнопка альтернативного, и альтернативное поддерживается оружием, то переходим в него, иначе -  выходим из прицеливания
        if IsActionKeyPressedInGame(kWPN_ZOOM_ALTER) and CanUseAlterScope(wpn) then begin
          buf.SetLastZoomAlter(true);
          buf.SetAlterZoomMode(true);
          buf.StartAlterZoomDirectSwitchMixup();
          RefreshZoomDOF(wpn);
          result:=true;
        end else begin
          result:=false;
        end;
      end;
    end;
  end;
end;

//---------------------------------------------------------------------------------------------------------
function CWeapon__Action(wpn:pointer; id:cardinal; flags:cardinal):boolean; stdcall;
//вернуть true, если дальше обрабатывать нажатие не надо
var
  buf:WpnBuf;
  scope_sect:PChar;

  lens_params:lens_zoom_params;
  dt, oldpos:single;
  force_zoom_sound:boolean;

  is_rpm_limit:boolean;

const
  PROHIBIT_SHOOT_TIME:cardinal = 100;  
begin
  result:=false;
  buf:=GetBuffer(wpn);
  if (buf<>nil) and ((id=kWPN_ZOOM_ALTER) or (id= kWPN_ZOOM)) and (GetAimFactor(wpn)>0) and not IsAimNow(wpn) and (buf.IsAlterZoomMode()<>buf.IsLastZoomAlter())  then begin
    result:=true;
    exit;
  end;

  if (id=kWPN_NEXT) then begin
    if not CanReloadNow(wpn) then begin
      result:=true;
      exit;
    end;
  end;

  // Защита от "залипания" и повторных выстрелов при маленькой скорострельности
  is_rpm_limit:=false;
  if (buf <> nil) and (flags=kActPress) and (CurrentQueueSize(wpn) > 0) then begin
    is_rpm_limit:= (buf.GetTimeBeforeNextShot() > (PROHIBIT_SHOOT_TIME / 1000));
  end;

  if (id=kWPN_FIRE) and (IsActorControlled() or is_rpm_limit) then begin
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
    result:=OnZoomButton(wpn, flags);
  end else if ((id=kWPN_ZOOM_INC) or (id=kWPN_ZOOM_DEC) or (id=kBRIGHTNESS_PLUS) or (id=kBRIGHTNESS_MINUS)) and (flags=kActPress) then begin
    if (buf<>nil) and IsAimNow(wpn) and buf.IsAlterZoomMode() then begin
      result:=true;
    end else if (buf<>nil) and IsAimNow(wpn) then begin
      if (id=kWPN_ZOOM_INC) or (id=kWPN_ZOOM_DEC) then begin
        lens_params:=buf.GetLensParams();
        dt:=lens_params.delta;
        oldpos := lens_params.target_position;
        force_zoom_sound:=false;
        
        if IsScopeAttached(wpn) and (GetScopeStatus(wpn)=2) then begin
          scope_sect:=game_ini_read_string(GetCurrentScopeSection(wpn), 'scope_name');
          dt:=1/game_ini_r_int_def(scope_sect, 'lens_factor_levels_count', 5);
          force_zoom_sound:=game_ini_r_bool_def(scope_sect, 'force_zoom_sound', false);
        end;

        if id=kWPN_ZOOM_INC then begin
          lens_params.target_position:=lens_params.target_position+dt;
        end else begin
          lens_params.target_position:=lens_params.target_position-dt;
        end;
        buf.SetLensParams(lens_params);

        lens_params:=buf.GetLensParams();
        if (lens_params.target_position<>oldpos) and (force_zoom_sound or (lens_params.factor_min<>lens_params.factor_max)) and ( abs(oldpos-lens_params.target_position)>0.0001 ) then begin
          if id=kWPN_ZOOM_INC then begin
            CHudItem_Play_Snd(wpn, 'sndScopeZoomPlus');
          end else begin
            CHudItem_Play_Snd(wpn, 'sndScopeZoomMinus');
          end;
        end;

      end else begin
        buf.ReloadNightBrightnessParams();
        if id=kBRIGHTNESS_MINUS then begin
          buf.ChangeNightBrightness(-1);
        end else begin
          buf.ChangeNightBrightness(1);
        end;
      end;
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
  if (GetActorActiveItem()=wpn) and (not IsAimNow(wpn)) and (leftstr(anm, length('anm_idle'))<>'anm_idle') then ResetDOF(ReadActionDOFSpeed_Out(wpn, anm));

  //если у нас аниматор удара и мы продолжаем жать кнопку удара, то возвращаемся обратно в состояние доставания :)
  if (GetActorActiveItem()=wpn) and (GetActorKeyRepeatFlag(kfQUICKKICK) {or IsActionKeyPressed(kQUICK_KICK)}) and (GetSection(wpn)=GetKickAnimator()) and not IsActorControlled() then begin
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
    KillActor(act, act);
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
procedure CWeaponMagazined__OnAnimationEnd(wpn:pointer; state:cardinal); stdcall;
begin
  //Если закончилась анимация стрельбы, заставим играться анимацию идла
  if state = EWeaponStates__eFire then begin
    PlayAnimIdle(wpn);
  end;

  //тут что-то было... И может быть будет
  if (GetSection(wpn)=GetPDAShowAnimator()) and not IsPDAWindowVisible() then begin
     if (leftstr(GetActualCurrentAnim(wpn), length('anm_idle_aim_end'))='anm_idle_aim_end') then begin
       virtual_CHudItem_SwitchState(wpn, EHudStates__eHiding);
     end else if (leftstr(GetActualCurrentAnim(wpn), length('anm_hide_emerg'))='anm_hide_emerg') then begin
       virtual_CHudItem_SwitchState(wpn, EHudStates__eHidden);
     end;
  end;
end;

procedure CWeaponMagazined__OnAnimationEnd_Patch(); stdcall;
asm
  pushad
    sub ecx, $2e0
    push edi
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
    ResetDOF(game_ini_r_single_def(GetHUDSection(wpn),'zoom_out_dof_speed', GetDefaultDOFSpeed_Out()));
  end;

  if IsPDAWindowVisible() then begin
    ActorUtils._is_pda_lookout_mode:=true;
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
  scope_sect:PChar;
begin
  if IsGLAttached(wpn) and IsGLEnabled(wpn) then begin
    scope_sect:=GetSection(wpn);
    if game_ini_line_exist(scope_sect, 'gl_zoom_factor') then begin
      SetZoomFactor(wpn, game_ini_r_single(scope_sect, 'gl_zoom_factor'));
    end;

    if IsScopeAttached(wpn) then begin
      scope_sect:=GetCurrentScopeSection(wpn);
      if game_ini_line_exist(scope_sect, 'gl_zoom_factor') then begin
        SetZoomFactor(wpn, game_ini_r_single(scope_sect, 'gl_zoom_factor'));
      end;
    end;
  end else if not IsScopeAttached(wpn) then begin
    if game_ini_line_exist(GetSection(wpn), 'nonscoped_zoom_factor') then begin
      SetZoomFactor(wpn, game_ini_r_single(GetSection(wpn), 'nonscoped_zoom_factor'));
    end;
  end;

  buf:=GetBuffer(wpn);
  if (buf<>nil) then begin
    buf.SetLastZoomAlter(buf.IsAlterZoomMode());

    if buf.IsAlterZoomMode() then begin
      SetZoomFactor(wpn, GetAlterScopeZoomFactor(wpn));
    end;

    buf.ReloadNightBrightnessParams();
    buf.UpdateZoomCrosshairUI();
  end;

  if IsPDAWindowVisible() then begin
    ActorUtils._is_pda_lookout_mode:=false;
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

function CHudItem__OnMotionMark(wpn:pointer):boolean; stdcall;
var
  anm:pchar;
begin
  //работает для ножа и бросабельных
  result:=false;
  if dynamic_cast(wpn, 0, RTTI_CWeapon, RTTI_CWeaponKnife, false)<>nil then begin
    if (GetOwner(wpn)=GetActor()) and (GetActorActiveItem()<>wpn)  then begin
      // Нож был выбит из рук или почему-то уже не в слоте. Выходим, не нанося удара
      result:=true;      
    end else if GetCurrentState(wpn)=EWeaponStates__eFire then begin
      MakeWeaponKick(CRenderDevice__GetCamPos(), CRenderDevice__GetCamDir(), wpn);
      result:=true;
    end;
  end;
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
    cmp al, 00
  popad
  je @std
  //удар был сделан нами; уходим из вызывающей процедуры
  add esp, $1c
  ret 8

  @std:
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

procedure CWeapon__Action_zoomincdec_Patch(); stdcall;
asm
  test bl, 1 // if !flags&&CMD_START then return;
  je @finish

  cmp byte ptr [esi+$494], 00
  je @finish

  @finish:
end;

////////////////////////////////Фикс угла вылета грены в режиме прицеливания//////////////////////////////////////

procedure LaunchGrenade_Correct(v:pFVector3); stdcall;
var
  camdir:FVector3;
begin
  //цель слишком далеко... Стреляем грену под углом 45 градусов по направлению взгляда
  camdir:=FVector3_copyfromengine(CRenderDevice__GetCamDir());
  camdir.y:=0;
  v_normalize(@camdir);

  camdir.y:=1;
  v_normalize(@camdir);

  v^:=camdir;
end;

procedure CWeaponMagazinedWGrenade__LaunchGrenade_dir_Patch(); stdcall;
asm
  pop ecx // ret addr
  add esp, $10 //original
  push ecx //ret addr

  test al, al
  jne @finish //all OK

  lea ecx, [esp+$14]
  pushad
    push ecx
    call LaunchGrenade_Correct
  popad

  @finish:
  test al, al //original  
end;

////////////////////////////////Фикс угла вылета грены при самоубийстве//////////////////////////////////////

procedure LaunchGrenade_controller_Correct(wpn:pointer; v:pFVector3); stdcall;
var
  act:pointer;
begin
  act:=GetActor();
  if (act<>nil) and (act = GetOwner(wpn)) and (IsActorSuicideNow() or IsSuicideInreversible()) then begin
    v.x := 0;
    v.y := -2;
    v.z :=0;
  end;
end;

procedure CWeaponMagazinedWGrenade__LaunchGrenade_controller_Patch(); stdcall;
asm
  //original
  movss [esp+4+$24], xmm2

  pushad
    mov eax, [esp + 32 + 8]    //2nd arg
    push eax
    push esi
    call LaunchGrenade_controller_Correct
  popad
end;

////////////////////////////////Переделка кода в CWeaponMagazinedWGrenade__Action//////////////////////////////////////

procedure TryShootGLFix(wpn:pointer); stdcall;
var
  rl:pCRocketLauncher;
  g_name:PChar;
  buf:WpnBuf;
begin
  rl:=dynamic_cast(wpn,0, RTTI_CWeaponMagazinedWGrenade, RTTI_CRocketLauncher, false);
  buf:=GetBuffer(wpn);
  if buf = nil then exit;
  if not (OnShoot_CanShootNow(wpn)) or (rl=nil) or (GetRocketsCount(rl)>0)  then begin
    //стрелять нельзя, оружие занято
    exit;
  end else if GetCurrentAmmoCount(wpn)<=0 then begin
    //стрелять нельзя, нет боеприпасов
    virtual_CWeaponMagazined__OnEmptyClick(wpn);
  end else begin
    if buf.last_frame_rocket_loaded<>GetCurrentFrame() then begin
      //стрелять можно, спавним фейковую грену
      g_name:=game_ini_read_string(GetGLCartridgeSectionByType(wpn, GetGrenadeCartridgeFromGLVector(wpn, GetAmmoInGLCount(wpn)-1).m_local_ammotype),'fake_grenade_name');
      CRocketLauncher__SpawnRocket(rl, g_name);
      //уменьшаем счетчик патронов в магазине
      SetAmmoInGLCount(wpn, GetCurrentAmmoCount(wpn)-1);
      SetCurrentAmmoCount(wpn, GetCurrentAmmoCount(wpn)-1);

      buf.last_frame_rocket_loaded:=GetCurrentFrame();
    end;
  end;
end;

procedure TryShootGLFix_Patch(); stdcall;
asm
  pushad
    push esi
    call TryShootGLFix
  popad
end;
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

procedure CWeaponRG6__AddCartridge_Replace_Patch(); stdcall;
asm
  mov eax, xrgame_addr
  add eax, $2DEA80
  jmp eax
end;


function RL_SpawnRocket(rl:pCRocketLauncher):boolean; stdcall;
var
  wpn:pointer;
  g_name:PChar;
  buf:WpnBuf;
begin
  result:=true;

  wpn:=dynamic_cast(rl, 0, RTTI_CRocketLauncher, RTTI_CWeaponMagazined, false);
  if wpn=nil then exit;
  buf:=GetBuffer(wpn);

  if GetRocketsCount(rl)=0 then begin
    if (GetAmmoInMagCount(wpn)>0) and (buf<>nil) and (buf.last_frame_rocket_loaded<>GetCurrentFrame()) then begin
      g_name:=game_ini_read_string(GetMainCartridgeSectionByType(wpn, GetCartridgeFromMagVector(wpn, GetAmmoInMagCount(wpn)-1).m_local_ammotype),'fake_grenade_name');
      CRocketLauncher__SpawnRocket(rl, g_name);
      buf.last_frame_rocket_loaded:=GetCurrentFrame();
      buf.rocket_launched:=false;
      result:=false;
    end;
  end else begin
    result:=not buf.rocket_launched;
    if result then buf.rocket_launched:=true;
  end;
end;

procedure CWeaponRG6__FireStart_SpawnRocket_Patch(); stdcall;
asm
  pushad
  push ecx
  call RL_SpawnRocket
  cmp al, 0
  popad
  jne @continue
  //дальше не выполняем код! выходим из процедуры уровнем выше
  add esp, 4    //ret addr
  pop ebp
  add esp, $40a0
  ret

  @continue:
  //original
  mov eax, xrgame_addr
  add eax, $2CC650   //CRocketLauncher::getRocketCount
  call eax
end;

procedure CWeaponRPG7__FireStart_GrenadeLaunchPoint_Patch(); stdcall;
asm
  //original
  test edi, edi
  mov [esp+$1C+4],edi
  je @finish
  pushad
  push edi
  call GetActor    //if E == GetActor then skip E->g_fireParams
  pop edi
  cmp eax, edi
  popad
  @finish:
end;

procedure EmptyClickIfNeeded(wpn:pointer); stdcall;
begin
  if GetCurrentAmmoCount(wpn) = 0 then begin
    virtual_CWeaponMagazined__OnEmptyClick(wpn);
  end;
end;

procedure CWeaponRG6__FireStart_EmptyClicks_Patch(); stdcall;
asm
  pushad
  lea ecx, [ebp-$338]
  push ecx
  call EmptyClickIfNeeded
  popad

  //original
  lea ecx,[ebp-$358]  
end;

procedure RPG7ReactiveHit(wpn:pointer); stdcall;
var
  sect:PAnsiChar;
  dist, hit, impulse, buck_disp, rdisp, rdisp2, rdist, rhit, rhit_cur, revk:single;
  hittype:cardinal;
  bullet_material:PAnsiChar;
  buck_cnt, rbuck_cnt, i, j:integer;
  pos, point, dir, dir2, tgt_dir,tgt_dir2:FVector3;
  c:CCartridge;
  rqr:rq_result;
  id:word;

begin
  //При стрельбе НПС не применяем поражение реактивной струей
  if (GetOwner(wpn) <> GetActor()) and (GetOwner(wpn)<>nil) then begin
    exit;
  end;

  sect:=GetSection(wpn);
  dist:=game_ini_r_single_def(sect, 'reactive_hit_dist', 0);
  hit:=game_ini_r_single_def(sect, 'reactive_hit_power', 0);
  impulse:=game_ini_r_single_def(sect, 'reactive_hit_impulse', 0);
  buck_cnt:=game_ini_r_int_def(sect, 'reactive_hit_buck', 1);
  rbuck_cnt:=game_ini_r_int_def(sect, 'reactive_hit_reverse_buck', 1);
  buck_disp:=game_ini_r_single_def(sect, 'reactive_hit_buck_disp', 1);
  rdisp:=game_ini_r_single_def(sect, 'reactive_hit_reverse_disp', 0.1);
  rdisp2:=game_ini_r_single_def(sect, 'reactive_hit_reverse_disp2', 0.1);
  rhit:=game_ini_r_single_def(sect, 'reactive_hit_reverse_power', hit);
  hittype:=game_ini_r_int_def(sect, 'reactive_hit_type', EHitType__eHitTypeExplosion);
  revk:=game_ini_r_single_def(sect, 'reactive_hit_reverse_k', 1);
  if (dist <= 0) or (hit <= 0) or (impulse <= 0) or (buck_cnt <= 0) then exit;

  bullet_material:=game_ini_read_string_def(sect, 'reactive_hit_bullet_material', 'default');
  pos:=GetLastFP(wpn);
  dir:=GetLastFd(wpn);

  v_mul(@dir, -1);

  InitCartridge(@c);
  c.bullet_material_idx:=GetMaterialIdx(bullet_material);

  for i:=0 to buck_cnt-1 do begin
    // Хитуем тех, кто сзади
    random_dir(@tgt_dir, @dir, buck_disp);

    if GetOwner(wpn) = nil then begin
      id:=GetID(wpn);
    end else begin
      id:=GetCObjectID(GetOwner(wpn));
    end;
    AddBullet(@pos, @tgt_dir, 330, hit, impulse, id, GetID(wpn), hittype, dist, @c, 1, true, false);

    //имитируем отражение струи в стрелка при близком препятствии - для этого используем disp2
    random_dir(@tgt_dir, @dir, rdisp);
    if Level_RayPick(@pos, @tgt_dir, dist, rq_target__rqtStatic, @rqr, GetOwner(wpn)) then begin
      //За стрелком обнаружилось препятствие, хитуем стрелка
      for j:=0 to rbuck_cnt-1 do begin
        point := pos;
        dir2 := tgt_dir;

        v_mul(@dir2, rqr.range * 0.9);
        v_add(@point, @dir2);

        dir2:=pos;
        v_sub(@dir2, @point);
        v_normalize(@dir2);
        random_dir(@tgt_dir2, @dir2, rdisp2);

        // Вычисляем хит отраженной струи
        rdist:=(dist - rqr.range);
        if rdist < 0 then rdist:=0;
        rhit_cur:=rhit * rdist / dist;

        // Вычисляем дистанцию полета отраженной струи
        rdist:=dist - rqr.range;
        if rdist < 0 then rdist:=0;
        rdist:=rdist / dist;
        rdist:=dist * revk * rdist;

        AddBullet(@point, @tgt_dir2, 330, rhit_cur, impulse, GetID(wpn), GetID(wpn), hittype, rdist*(0.9 + random*0.15), @c, 1, true, true);
      end;
    end;
  end;

  FreeCartridge(@c);
end;


procedure CWeaponRPG7__FireStart_SpawnRocket_Replace_Patch(); stdcall;
asm
  {// Cтруя за стрелком - в том числе и во время осечек (полезно для отладки)
  pushad
  lea ecx, [ecx-$338]
  push ecx
  call RPG7ReactiveHit
  popad}

  pushad
  lea ecx, [ecx+$480]
  push ecx
  call RL_SpawnRocket
  cmp al, 0
  popad

  je @ret_noact

  //original
  mov eax, xrgame_addr
  add eax, $2CFE50  //CWeaponMagazined::FireStart
  jmp eax

  @ret_noact:
  ret
end;

procedure CWeaponRPG7__ReloadMagazine_Replace_Patch(); stdcall;
asm
  mov eax, xrgame_addr
  add eax, $2D0F10
  jmp eax
end;

procedure GetNewMotionSpeed(name:pshared_str; value:psingle); stdcall;
var
  act:pointer;
  wpn:pointer;
  str:string;
  anm_name:string;
const
  ANIMATOR_SLOT:cardinal =11;
  SUPERSTAMINA_HIT_PERIOD:cardinal=1000;
begin
  //TODO:учет МП, как в оригинале?
  value^:=1;
  act:=GetActor();
  if act=nil then exit;
  wpn:=GetActorActiveItem();
  if wpn=nil then exit;

  anm_name:=get_string_value(name);
  if (leftstr(anm_name, length('anm_hide'))='anm_hide') then begin
    if GetForcedQuickthrow() or (GetActorTargetSlot()=ANIMATOR_SLOT) then begin
      value^:=game_ini_r_single_def(GetHUDSection(wpn), 'hide_factor_common', 1.8);
      value^:=game_ini_r_single_def(GetHUDSection(wpn), PChar('hide_factor_'+anm_name), value^);
    end else if (GetTimeDeltaSafe(GetLastSuperStaminaHitTime()) < SUPERSTAMINA_HIT_PERIOD ) then begin
      value^:=100;
    end;
  end;
end;

procedure CalcMotionSpeed_QuickItems_Patch(); stdcall;
asm
  push ecx
  lea ecx, [esp]
  pushad
    push ecx    //buffer
    mov ecx, [esp+4]
    push ecx    //anim
    call GetNewMotionSpeed
  popad
  fld [esp]
  add esp, 4
  
  //original
  pop ecx
  ret
end;

procedure attachable_hud_item__anim_play_cameff_patch; stdcall;
asm
  //если эффектор анимации оружия уже назначен - принудительно завершаем
  test eax, eax
  je @finish
    push $12
    call CCameraManager__RemoveCamEffector
  @finish:
end;

function IsShotNeededNow(wpn:pointer):boolean; stdcall;
var
  buf:WpnBuf;
  pos, dir:FVector3;
  owner:pointer;
  rqr:rq_result;
  aimperiod:integer;
  is_aim_exist:boolean;
  is_shot_after_key_released:boolean;
  entity:pointer;
  act:pointer;
begin
  result:=true;
  buf:=GetBuffer(wpn);
  if (buf=nil) or (GetShootLockTime(wpn)>0) then exit;
  aimperiod:=(buf.GetAutoAimPeriod());
  if aimperiod=0 then exit;

  pos:=GetLastFP(wpn);
  dir:=GetLastFD(wpn);
  owner:=GetOwner(wpn);
  if owner<>nil then begin
    CorrectShooting(wpn, owner, @pos, @dir);
  end;

  is_aim_exist:=Level_RayPick(@pos, @dir, 1000, rq_target__rqtObject, @rqr, owner);

  if not is_visible_by_thermovisor(rqr.O) and FindBoolValueInUpgradesDef(wpn, 'autoaim_only_alive', game_ini_r_bool_def(GetSection(wpn), 'autoaim_only_alive', false), true) then begin
    is_aim_exist:=false;
  end;

  entity:=dynamic_cast(rqr.O, 0, RTTI_CObject, RTTI_CEntity, false);
  if is_aim_exist and FindBoolValueInUpgradesDef(wpn, 'autoaim_ignore_dead', game_ini_r_bool_def(GetSection(wpn), 'autoaim_ignore_dead', false), true) and not is_object_has_health(entity) then begin
    is_aim_exist:=false;  
  end;

  is_shot_after_key_released := FindBoolValueInUpgradesDef(wpn, 'autoaim_shot_after_key_released', game_ini_r_bool_def(GetSection(wpn), 'autoaim_shot_after_key_released', false), true);

  if aimperiod>0 then begin
    if (is_shot_after_key_released) then begin
      // Схема с выстрелом после отпускания кнопки - в каждом апдейте выставляем дельту заново
      if IsActionKeyPressedInGame(kWPN_FIRE) then begin
        buf.SetAutoAimStartTime(GetGameTickCount());
      end;
    end else if buf.GetAutoAimStartTime=0 then begin
      //схема с отложенным выстрелом - еще не стартовали.
      buf.SetAutoAimStartTime(GetGameTickCount());
    end;
    result:= is_aim_exist or (GetTimeDeltaSafe(buf.GetAutoAimStartTime())>=buf.GetAutoAimPeriod());

    if result then begin
      buf.SetAutoAimStartTime(0);
    end else begin
      //не даем выйти из состояния shoot
      if GetShootLockTime(wpn)<=0 then SetShootLockTime(wpn, 0);
    end;
  end else begin
    //схема с отменой выстрела
    result:=is_aim_exist;
    if (not result) then begin
     if FindBoolValueInUpgradesDef(wpn, 'autoaim_shot_cancellation', game_ini_r_bool_def(GetSection(wpn), 'autoaim_shot_cancellation', false), true) then begin
      //У нас автоматический предохранитель, прекращаем стрельбу
      SetShootLockTime(wpn, -1);
     end else if IsActionKeyPressedInGame(kWPN_FIRE) then begin
      //У нас система непрерывного автоспуска, не даем выйти из состояния shoot
      if GetShootLockTime(wpn)<=0 then SetShootLockTime(wpn, 0);
     end else begin
      //стрелять уже не надо
      SetShootLockTime(wpn, -1);
     end;
    end;
  end;


  act:=GetActor();
  if not result and (act<>nil) and (act=GetOwner(wpn)) then begin
    if GetActorActionStateInt(act, actTotalActions)<>GetActorActionStateInt(act, actTotalActions, mState_OLD) then begin
      SetCurrentState(wpn, EHudStates__eIdle);
      PlayAnimIdle(wpn);
      SetCurrentState(wpn, EWeaponStates__eFire);
    end;
  end;

end;

procedure CWeaponMagazined__state_Fire_autoaim_patch; stdcall;
asm
  comiss xmm0, [esi+$390]
  jbe @finish

  pushad
    push esi
    call IsShotNeededNow
    cmp al, 0
  popad

  @finish:
end;


{procedure CWeaponRPG7__OnEvent_RemoveAmmoAfterRocketShot(); stdcall;
asm
  //тут разряжаем магазин принудительно после вылета ракеты - так как оно однозарядное, там ничего не могло остаться
  //!!!к сожалению, теряется возможность создания многозарядного оружия!!!
  push 0
  push esi
  call virtual_CWeaponMagazined__UnloadMagazine
end; }


function CWeaponMagazined__CheckForMisfire_validate_NoMisfire(wpn:pointer):boolean; stdcall;
var
  buf:WpnBuf;
  problems_lvl:single;
begin
  //осечки было быть не должно. Но все еще можно изменить! Вернуть true, если не стрелять
  result:=false;

  if (GetOwner(wpn) = GetActor()) and (GetActor()<>nil) and not game_ini_r_bool_def(GetSection(wpn), 'actor_can_shoot', true) then begin
    result:=true;
  end;

  buf:=GetBuffer(wpn);
  problems_lvl:=buf.GetMisfireProblemsLevel();
  if (buf<>nil) and (problems_lvl>0) and (CurrentElectronicsProblemsCnt()>=problems_lvl) then begin
    SetWeaponMisfireStatus(wpn, true);
    virtual_CHudItem_SwitchState(wpn, EWeaponStates__eMisfire);
    result:= not OnWeaponJam(wpn);
  end;
end;

procedure CWeaponMagazined__CheckForMisfire_validate_NoMisfire_patch(); stdcall;
asm
  pushad
    push esi
    call CWeaponMagazined__CheckForMisfire_validate_NoMisfire
    cmp al, 0
  popad
  setnz al
  ret
end;

procedure Manager__upgrade_install_Patch(); stdcall;
asm
  test eax, eax
  jne @upgrade_found
  mov [esp+$30], 10
  mov esi, xrgame_addr
  add esi, $af60e
  jmp esi


  @upgrade_found:
  //original instructions
  mov ebx, [esp+$34]
  mov edi, [esp+$2c]
  mov esi, xrgame_addr
  add esi, $af4e9
  jmp esi
end;


function IsUpgradeBanned(item:pointer; upgrade_id:pshared_str; loading:boolean):boolean; stdcall;
var
  wpn:pointer;
  banned_ups, mask:string;
  sect:PAnsiChar;
const
  BANNED_UPGRADES:PAnsiChar='banned_upgrades';
begin
  result:=false;
  sect:=GetSection(item);
  if game_ini_line_exist(sect, BANNED_UPGRADES) then begin
    banned_ups:=game_ini_read_string(sect, BANNED_UPGRADES)+',';
    while GetNextSubStr(banned_ups, mask, ',') do begin
      if leftstr(get_string_value(upgrade_id), length(mask)) = mask then begin
        Log('Found banned upgrade "'+get_string_value(upgrade_id)+'" for item '+sect);
        result:=true;
        break;
      end;
    end;
  end;
end;

procedure Manager__upgrade_install_checkbanned_Patch(); stdcall;
asm

  mov eax, esp

  pushad
  movzx ebx, byte ptr [eax+$10]
  push ebx
  push [eax+$C] //pshared_str upgrade_id
  push [eax+$8] //CInventoryItem* item
  call IsUpgradeBanned
  test al, al
  popad
  je @orig


  pop eax //ret addr
  xor eax, eax
  ret $0c
@orig:
  pop eax //ret addr
  sub esp, $18 //original
  push ebx
  push ebp
  jmp eax
end;

procedure RegisterGrenadeShot(wpn:pointer); stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if buf <> nil then begin
    buf.RegisterShot();
  end;
end;

procedure CWeaponMagazinedWGrenade__LaunchGrenade_RegisterShot_Patch(); stdcall;
asm
  pushad
  push esi
  call RegisterGrenadeShot
  popad

  //original
  mov eax, [esi+$318]
  ret
end;

procedure FixNullParent_Patch(); stdcall;
asm
  push ecx
  mov eax, xrgame_addr
  add eax, $512be0
  call [eax]    //CObject::H_Parent
  pop ecx

  cmp eax, 0
  jne @finish
  mov eax, ecx

  @finish:
  ret
end;

procedure CWeapon__AddShotEffector_replace_Patch(); stdcall;
asm
  mov eax, ecx
  mov ecx, [eax+$8c]
  test ecx, ecx
  je @finish;
  mov ecx, [ecx+$48]
  mov edx, [ecx]
  push eax
  mov eax, [edx+$d0]
  call eax
  @finish:
  ret
end;

function GetAmmoMaterial(section:PAnsiChar):PAnsiChar; stdcall;
const
  DEFAULT_MATERIAL:PAnsiChar = 'objects\bullet';
begin
  result:=game_ini_read_string_def(section, 'material', DEFAULT_MATERIAL);
end;

procedure CCartridge__Load_material_Patch(); stdcall;
asm
  push [esp] // дублируем адрес возврата
  lea eax, [esp+4] //буфер, в который будем помещать аргумент, push'ащийся в оригинале

  pushad
  push eax //save ptr to buf

  push edi //ammo section
  call GetAmmoMaterial

  pop ecx //restore ptr to buf
  mov [ecx], eax
  popad
end;

function GetCartridgeMaterial(c:pCCartridge):PAnsiChar; stdcall;
begin
  result:=GetAmmoMaterial(get_string_value(@c.m_ammo_sect));
end;

procedure CWeaponAmmo__Get_material_Patch; stdcall;
asm
  push [esp] // дублируем адрес возврата
  lea eax, [esp+4] //буфер, в который будем помещать аргумент, push'ащийся в оригинале

  pushad
  push eax //save ptr to buf

  push ebp //cartridge
  call GetCartridgeMaterial

  pop ecx //restore ptr to buf
  mov [ecx], eax
  popad
end;

function GetCartridgeHitType(c:pCCartridge):cardinal; stdcall;
var
  s:PAnsiChar;
begin
  result:=6; // ALife::eHitTypeFireWound
  if c = nil then exit;

  s:=get_string_value(@c.m_ammo_sect);
  if (s=nil) then exit;

  result:=game_ini_r_int_def(s, 'hit_type', result)
end;

procedure CShootingObject__FireBullet_hittype_Patch();stdcall;
asm
  fstp dword ptr [esp+4]
  push [esp] // дублируем адрес возврата, создавая буфер
  lea ecx, [esp+4] //адрес буфера

  pushad
  push ecx //save buf
  push [ecx+8] //cartridge
  
  call GetCartridgeHitType
  pop ecx // restore buf
  mov [ecx], eax
  popad

  mov ecx, [esp+$4c] //восстанавливаем ecx

end;


function NeedSkipNewBullet(v:pxr_vector; sz:cardinal):boolean; stdcall;
const
  MAX_BULLETS_COUNT:cardinal = 1000;
begin
//  result:=items_count_in_vector(v, sz) >= MAX_BULLETS_COUNT;
  result:=false;
end;

procedure CBulletManager__RegisterEvent_CheckBulletCount_Patch(); stdcall;
asm
  pushad
  push $a0 //sizeof(CBulletManager::_event)
  lea ecx, [ecx+$34]
  push ecx
  call NeedSkipNewBullet
  test al, al
  popad

  je @original
  pop ebx //ret addr
  mov ebx, xrgame_addr
  add ebx, $24f0dd
  jmp ebx


  @original:
  mov edi, ecx
  mov ecx, [edi+$38]
end;

function Init:boolean;
var
  jmp_addr:cardinal;
begin
  result:=false;

  //Событие назначения клина ( внутри CWeapon::CheckForMisfire)
  jmp_addr:= xrGame_addr+$2BD0AF;
  if not WriteJump(jmp_addr, cardinal(@WeaponJammed_Patch),16, true) then exit;

  //Событие осечки/пустого магазина
  jmp_addr:=xrGame_addr+$2CCD75;
  if not WriteJump(jmp_addr, cardinal(@EmptyClick_Patch), 8, true) then exit;

  //-----------------------------------------------------------------------------------------------------
  //в CWeaponMagazined::Attach
  //Аттач прицела
  InitAttachAddon(xrGame_addr+$2CEE33, $11);
  //                           register^|^addon type  
  //Аттач подствола(мертвый?)
  InitAttachAddon(xrGame_addr+$2CEEF5, $12);
  //второй аттач подствола, живой
  InitAttachAddon(xrGame_addr+$2D26F7, $02);

  //Аттач глушителя
  InitAttachAddon(xrGame_addr+$2CEE5A, $14);

  //В CWeaponMagazined::CanAttach убираем проверку на уже присоединенный к оружию аддон такого типа, чтобы появлялось предложение присоединить его
  nop_code(xrgame_addr+$2cebcd, 6);
  nop_code(xrgame_addr+$2cec91, 2);
  nop_code(xrgame_addr+$2cecd5, 2);
  //в CWeaponMagazined::Attach - аналогично, убираем сравнения
  nop_code(xrgame_addr+$2ceda9, 6);
  nop_code(xrgame_addr+$2cee7a, 2);
  nop_code(xrgame_addr+$2ceeb7, 2);
  //в CWeaponMagazined::Attach во время аттача прицела m_cur_scope выставляется раньше нашего патча. Запоминаем предыдущий индекс прицела
  jmp_addr:=xrGame_addr+$2cee22;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazined__Attach_saveprevscope_Patch),6, true) then exit;

  //в CUIActorMenu::AttachAddon отключим проигрывание звука аттача аддонов

  //-----------------------------------------------------------------------------------------------------
  //CWeaponMagazined::Detach
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
  //[bug]поправим баг с недопереключением режима стрельбы во время апгрейда
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

  //[bug] баг - забыли проверить в CWeapon::Action на cmd_start приближение/отдаление прицела и смену типа патронов (она правится у нас отдельно)
  jmp_addr:=xrGame_addr+$2BEDAF;
  if not WriteJump(jmp_addr, cardinal(@CWeapon__Action_zoomincdec_Patch), 7, true) then exit;


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


  //Патчим направление стрельбы грены для самоубийства контролером
  jmp_addr:=xrGame_addr+$2D314A;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazinedWGrenade__LaunchGrenade_controller_Patch), 6, true) then exit;

  //[bug] баг стрельбы с подствола в режиме прицеливания - если цель слишком далеко, грена летит не на максимальную дальность, а как повезет
  jmp_addr:=xrGame_addr+$2D30A2;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazinedWGrenade__LaunchGrenade_dir_Patch), 5, true) then exit;
  if not nop_code(xrgame_addr+$2D3038, 6) then exit;
  //аналогично для РГ-6
  jmp_addr:=xrGame_addr+$2DFA7A;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazinedWGrenade__LaunchGrenade_dir_Patch), 5, true) then exit;
  if not nop_code(xrgame_addr+$2DFA10, 6) then exit;  

  //[bug]баг оружия с подстволом - при разрядке не разряжаются CCustomRocket'ы
  //Для фикса ПОЛНОСТЬЮ переписываем код внутри CWeaponMagazinedWGrenade::Action, выполняющийся при попытке стрельбы с подствола
  //меняем логику работы: спавним ракету не при перезарядке, а при выстреле
  jmp_addr:=xrGame_addr+$2D3ABE;
  if not WriteJump(jmp_addr, cardinal(@TryShootGLFix_Patch), 47, true) then exit;
  nop_code(xrgame_addr+$2D206F, 13);
//  nop_code(xrgame_addr+$2D35B9, 13); //переехало в WeaponDataSaveLoad как часть восстановления указателя на оружие
  //jmp_addr:=xrGame_addr+$2D35ED;
  //в CWeaponMagazinedWGrenade::net_Spawn обеспечиваем зарядку CCartridge
  //if not WriteJump(jmp_addr, xrGame_addr+$2D35E1, 5, false) then exit;
  nop_code(xrgame_addr+$2D3519, 6);
  nop_code(xrgame_addr+$2D31C0, 12);  

  //аналогично делаем для CWeaponRG6
  //заменяем CWeaponRG6::AddCartridge на предка
  jmp_addr:=xrGame_addr+$2DF5B0;
  if not WriteJump(jmp_addr, cardinal(@CWeaponRG6__AddCartridge_Replace_Patch), 6, false) then exit;
  nop_code(xrgame_addr+$2DF4A9, 2);
  jmp_addr:=xrGame_addr+$2DF6ED;
  if not WriteJump(jmp_addr, cardinal(@CWeaponRG6__FireStart_SpawnRocket_Patch), 5, true) then exit;
  //аналогично для CWeaponRPG7
  jmp_addr:=xrGame_addr+$2D9440;
  if not WriteJump(jmp_addr, cardinal(@CWeaponRPG7__ReloadMagazine_Replace_Patch), 9, false) then exit;
  nop_code(xrgame_addr+$2D973E, 1, CHR($EB));
  jmp_addr:=xrGame_addr+$2D94C0;
  if not WriteJump(jmp_addr, cardinal(@CWeaponRPG7__FireStart_SpawnRocket_Replace_Patch), 5, false) then exit;

  //[bug] баг - из-за dropCurrentRocket() в CWeaponRG6::FireStart после выстрела НПСом грена зависает в воздухе
  //но если этого не делать, в оригинале заспавнится 2 CCustomRocket! Из-за вызова FireStart 2 раза. Мы решаем аналогично РПГ-7
  nop_code(xrgame_addr+$2DFBDD, 5);

  //[bug] баг - в CWeaponRG6::FireStart не стоит вызывать E->g_fireParams, когда гранатомет в руках у актора, иначе грена полетит из центра камеры
  jmp_addr:=xrGame_addr+$2DF7C7;
  if not WriteJump(jmp_addr, cardinal(@CWeaponRPG7__FireStart_GrenadeLaunchPoint_Patch), 6, true) then exit;

  //[bug] баг - в CWeaponRG6::FireStart не реализованы щелчки при попытке выстрелить из пустого оружия. Добавляем вызов OnEmptyClick(); после проверки GetState() == eIdle и перед getRocketCount()
  jmp_addr:=xrGame_addr+$2DF6E7;
  if not WriteJump(jmp_addr, cardinal(@CWeaponRG6__FireStart_EmptyClicks_Patch), 6, true) then exit;

  //реализация изменения скорости доставания/убирания оружия при переключении на/со слота аниматоров и прочей юзабельной хрени
  jmp_addr:=xrGame_addr+$2FB5EA;
  if not WriteJump(jmp_addr, cardinal(@CalcMotionSpeed_QuickItems_Patch), 5, false) then exit;

  //фича, требующая задержки выстрелов(автоаим)
  jmp_addr:=xrGame_addr+$2D05E3;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazined__state_Fire_autoaim_patch), 7, true) then exit;

  // в CWeapon::CheckForMisfire - после того, как убедились, что осечки быть не должно, подумаем еще раз - а может, все-таки назначить?
  jmp_addr:=xrGame_addr+$2bd0c4;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazined__CheckForMisfire_validate_NoMisfire_patch), 5, false) then exit;

  //В Manager::upgrade_install добавляем проверку - если апгрейд не нашелся после upgrade_verify, то и не применяем его вообще
  jmp_addr:=xrGame_addr+$af4e1;
  if not WriteJump(jmp_addr, cardinal(@Manager__upgrade_install_Patch), 8, false) then exit;

  // В самом начале Manager::upgrade_install отсекаем невалидные апгрейды, оставшиеся от заглушек
  jmp_addr:=xrGame_addr+$af4d0;
  if not WriteJump(jmp_addr, cardinal(@Manager__upgrade_install_checkbanned_Patch), 5, true) then exit;

  // Регистрируем выстрел в   CWeaponMagazinedWGrenade::LaunchGrenade
  jmp_addr:=xrGame_addr+$2d2cc7;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazinedWGrenade__LaunchGrenade_RegisterShot_Patch), 6, true) then exit;

  // [bug] баг в CWeaponMagazinedWGrenade::LaunchGrenade - при установке ИД родителя гранаты не проверяется валидность H_Parent(). Если оружие было выброшено (например, из-за бюрера) - жди проблем
  jmp_addr:=xrGame_addr+$2d317f;
  if not WriteJump(jmp_addr, cardinal(@FixNullParent_Patch), 6, true) then exit;
  //аналогично в CWeaponRPG7::switch2_Fire
  jmp_addr:=xrGame_addr+$2d9d12;
  if not WriteJump(jmp_addr, cardinal(@FixNullParent_Patch), 6, true) then exit;
  // аналогично в CWeaponRG6::FireStart
  jmp_addr:=xrGame_addr+$2dfb57;
  if not WriteJump(jmp_addr, cardinal(@FixNullParent_Patch), 6, true) then exit;
  //todo: аналогично в CGrenade::Throw
  jmp_addr:=xrGame_addr+$2c6403;
  if not WriteJump(jmp_addr, cardinal(@FixNullParent_Patch), 6, true) then exit;

////////////////////////////////////////////////////////////////////////////////////
  //Правки на возможность стрельбы из оружия, не принадлежащего никому
  //В CWeapon::FireTrace в вызове FireBullet дописываем проверку на то, что H_Parent может быть нулевым
  jmp_addr:=xrGame_addr+$2c3281;
  if not WriteJump(jmp_addr, cardinal(@FixNullParent_Patch), 6, true) then exit;

  //Отключаем ассерт на наличие H_Parent в CWeaponMagazined::FireStart
  if not nop_code(xrgame_addr+$2cfec6, 1, chr($eb)) then exit;

  //в CWeaponMagazined::state_Fire разрешаем стрельбу при отсутствии владельца - отправляем je с xrgame.dll+2d0403 на xrgame.dll+2d0588 (условие на заполнение m_vStartPos и m_vStartDir) в обход проверок
  if not nop_code(xrgame_addr+$2d0405, 1, chr($7f)) then exit;
  if not nop_code(xrgame_addr+$2d0406, 1, chr($01)) then exit;
  if not nop_code(xrgame_addr+$2d0407, 1, chr($00)) then exit;
  if not nop_code(xrgame_addr+$2d0408, 1, chr($00)) then exit;

  // CWeapon::AddShotEffector (xrGame.dll+2c2ae0) - добавляем проверку на то, что inventory_owner существует, подменяя функцию
  jmp_addr:=xrGame_addr+$2c2ae0;
  if not WriteJump(jmp_addr, cardinal(@CWeapon__AddShotEffector_replace_Patch), 8, false) then exit;

  // CWeapon::SwitchState (xrGame.dll+2bc3e0) - разрешаем кидать сообщения при m_pInventory = nil
  if not nop_code(xrgame_addr+$2bc432, 6) then exit;

  // CWeapon::ParentMayHaveAimBullet (xrGame.dll+2c1070) - добавляем возможность parent'a быть нулевым
  if not nop_code(xrgame_addr+$2c1080, 2, chr($c3)) then exit;

  // в CEntityCondition::ConditionHit делаем обработку eHitTypeBurn так, чтобы bAddWound не сбрасывалось в false
  // Правим jmp, чтобы переходил в ветку, не сбрасывающую bAddWound
  jmp_addr:=$9e;
  if not WriteBufAtAdr(xrgame_addr+$27e932,@jmp_addr,sizeof(jmp_addr)) then exit;

  // в CCartridge::Load добавляем возможность указывать произвольный bullet_material_idx для пули
  jmp_addr:=xrGame_addr+$2c43c7;
  if not WriteJump(jmp_addr, cardinal(@CCartridge__Load_material_Patch), 5, true) then exit;

  // в CWeaponAmmo::Get - аналогично, надо откорректировать bullet_material_idx
  jmp_addr:=xrGame_addr+$2c486c;
  if not WriteJump(jmp_addr, cardinal(@CWeaponAmmo__Get_material_Patch), 5, true) then exit;

  // в CShootingObject::FireBullet (xrgame.dll+2bb920) даем возможность прописывать разные типы урона пулям
  jmp_addr:=xrGame_addr+$2bba26;
  if not WriteJump(jmp_addr, cardinal(@CShootingObject__FireBullet_hittype_Patch), 5, true) then exit;

  // [bug] В CBulletManager::RegisterEvent проверяем количество пуль на локации, и если их слишком много - дропаем пулю, которую хотели добавить
  jmp_addr:=xrGame_addr+$24ef7a;
  if not WriteJump(jmp_addr, cardinal(@CBulletManager__RegisterEvent_CheckBulletCount_Patch), 5, true) then exit;

  //В CWeaponMagazined::OnMagazineEmpty ликвидируем переход в стейт eMagEmpty
  if not nop_code(xrgame_addr+$2ccb20, 1, chr($eb)) then exit;

  result:=true;

  //Потенциальная проблема - при дропе оружия из CInventory::Activate вызывается SendDeactivateItem, который дергает SendHiddenItem (xrGame.dll+2dc9f0), отправляющий GE_WPN_STATE_CHANGE с eHiding
  //Далее эта штука ловится и заставляет вызываться CWeaponMagazined::switch2_Hiding, в котором зачем-то вызывает PlaySound, а потом дергает SetPending(true).
  //По логике pending должен сброситься в CWeaponMagazined::switch2_Hidden, но до его вызова дело не доходит, так как оружие выброшено и сообщения не проходят (фиксятся предыдущей правкой)

  //Некоторые полезные адреса на будущее:
  //CWeaponMagazined::state_Fire - xrgame.dll+2d0350
  //CWeaponMagazined::OnStateSwitch - xrgame.dll+2d01b0 -> CWeaponMagazined::switch2_Fire (xrgame.dll+2d0720)
  //CWeaponMagazined::Action - xrgame.dll+2ce7a0; CWeapon::Action - xrGame.dll+2bec70
  //CWeaponMagazined::OnShot - xrgame.dll+2ccc40
  //CWeaponMagazined::OnMagazineEmpty - xrgame.dll+2ccb00
  //CEntityAlive::Hit - xrgame.dll+27bdb0
  //CBaseMonster::Hit - xrgame.dll+c6440
  //CEntityAlive::StartFireParticles - xrgame.dll+27ba30
  //CEntityAlive::UpdateFireParticles - xrgame.dll+27b600
  //CEntityCondition::UpdateCondition - xrgame.dll+27def0
  //CEntityCondition::UpdateHealth - xrgame.dll+27dd70
  //CEntityCondition::BleedingSpeed - xrgame.dll+27dd00
  //CAI_Stalker::react_on_member_death - xrgame.dll+192430
  //CStalkerDangerPlanner::update - xrgame.dll+xrgame.dll+1785b0
////////////////////////////////////////////////////////////////////////////////////


  //Предотвращение повторных выстрелов из РПГ
  //!!!Ломает возможность многозарядных гранатометов!!!
//  jmp_addr:=xrGame_addr+$2D980B;
//  if not WriteJump(jmp_addr, cardinal(@CWeaponRPG7__OnEvent_RemoveAmmoAfterRocketShot), 5, true) then exit;

  //[bug] баг с неназначением нового эффектора камеры при неоконченном старом - thanks to SkyLoader
  //[upd ломается кой-чего еще... Отключаем, лучше уж так
  //jmp_addr:=xrGame_addr+$2FEC28;
  //if not WriteJump(jmp_addr, cardinal(@attachable_hud_item__anim_play_cameff_patch), 8, true) then exit;
end;


end.

