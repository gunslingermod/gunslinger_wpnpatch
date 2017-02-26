unit WeaponEvents;

interface
function Init:boolean;

procedure OnWeaponExplode_AfterAnim(wpn:pointer; param:integer);stdcall;
procedure OnWeaponHide(wpn:pointer);stdcall;
procedure OnWeaponShow(wpn:pointer);stdcall;

implementation
uses Messenger, BaseGameData, GameWrappers, WpnUtils, WeaponAnims, LightUtils, WeaponAdditionalBuffer, sysutils, ActorUtils, DetectorUtils, strutils;

var
  upgrade_weapon_addr:cardinal;

//-------------------------------Разряжание магазина-----------------------------
procedure OnUnloadInEndOfAnim(wpn:pointer; param:integer);stdcall;
begin
  unload_magazine(wpn);
  ForceWpnHudBriefUpdate(wpn);
end;

procedure OnUnloadInMiddleAnim(wpn:pointer; param:integer);stdcall;
begin
  unload_magazine(wpn);
  ForceWpnHudBriefUpdate(wpn);
  MakeLockByConfigParam(wpn, GetHUDSection(wpn), PChar('lock_time_end_'+WpnUtils.GetActualCurrentAnim(wpn)));
end;


function OnUnloadMag(wpn:pointer):boolean; stdcall;
var
  hud_sect: PChar;
  act:pointer;
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
    //анима начала играться. Посмотрим, когда надо разряжаться
    if game_ini_line_exist(hud_sect, PChar('lock_time_start_'+WpnUtils.GetActualCurrentAnim(wpn))) then begin
      //разряжание идет по схеме визуального отображения патронов (в середине анимации)
      MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_start_'+WpnUtils.GetActualCurrentAnim(wpn)), false, OnUnloadInMiddleAnim);
    end else if game_ini_line_exist(hud_sect, PChar('lock_time_end_'+WpnUtils.GetActualCurrentAnim(wpn))) then begin
      //разряжание выполняется после анимации
      MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_end_'+WpnUtils.GetActualCurrentAnim(wpn)), false, OnUnloadInEndOfAnim);
    end else begin
      //никаких указаний нет, поэтому разряжаемся сразу
      result := true;
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

function OnCWeaponMagazinedNetSpawn(wpn:pointer):boolean;stdcall;
begin
  if WpnCanShoot(PChar(GetClassName(wpn))) then WpnBuf.Create(wpn);
end;

procedure CWeaponMagazined_NetSpawn_Patch();
begin
  asm

    pushad
    pushfd

    push esi
    call OnCWeaponMagazinedNetSpawn

    popfd
    popad

    test edi, edi
    mov [esp+$14], eax

    ret
  end;
end;
//------------------------------------------------------------------------------
function OnCWeaponMagazinedNetDestroy(wpn:pointer):boolean;stdcall;
var buf:WpnBuf;
begin
  buf:=WeaponAdditionalBuffer.GetBuffer(wpn);
  if buf<>nil then buf.Free;
end;

procedure CWeaponMagazined_NetDestroy_Patch();
begin
  asm

    pushad
    pushfd

    push esi
    call OnCWeaponMagazinedNetDestroy

    popfd
    popad

    lea edi, [esi+$338];

    ret
  end;
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

procedure OnChangeFireMode(wpn:pointer; new_mode:integer); stdcall;
var
  hud_sect:PChar;
  firemode:integer;
  anm_name:string;
begin
  hud_sect:=GetHUDSection(wpn);
  firemode:=CurrentQueueSize(wpn);
  if firemode=new_mode then exit; //обрабатываем срабатывание в случае единственного доступного режима стрельбы

  if (hud_sect=nil) or (not game_ini_line_exist(hud_sect, 'use_firemode_change_anim')) or (not game_ini_r_bool(hud_sect, 'use_firemode_change_anim')) then exit;


  anm_name:='anm_changefiremode_from_';
  if firemode<0 then anm_name:=anm_name+'a' else anm_name:=anm_name+inttostr(firemode);
  anm_name:=anm_name+'_to_';
  if new_mode<0 then anm_name:=anm_name+'a' else anm_name:=anm_name+inttostr(new_mode);

  if IsWeaponJammed(wpn) then begin
    WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, PChar(anm_name), 'sndChangeFireModeJammed');
  end else if GetAmmoInMagCount(wpn)<=0 then begin
    WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, PChar(anm_name), 'sndChangeFireModeEmpty');
  end else begin
    WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, PChar(anm_name), 'sndChangeFireMode');
  end;
end;

procedure OnChangeFireMode_Patch(); stdcall;
asm
  pushad
  pushfd
    push eax
    push esi
    call OnChangeFireMode
  popfd
  popad
  mov eax, [edi+$218]
end;


procedure CanChangeFireMode_Patch(); stdcall;
asm
    cmp [esi+$2E4],00
    jne @finish

    pushad
    push 0
    push esi
    call WeaponAdditionalBuffer.CanStartAction
    cmp al, 1
    popad

    @finish:
    ret
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

procedure OnWeaponJam(wpn:pointer);stdcall;
var sect:PChar;
    owner:pointer;
begin
  owner := GetOwner(wpn);
  if (owner=nil) or (owner<>GetActor()) then exit;
  sect:=GetSection(wpn);
  if game_ini_line_exist(sect, 'can_explose') and game_ini_r_bool(sect, 'can_explose') then begin
    if GetCurrentCondition(wpn)<game_ini_r_single(sect, 'explode_start_condition') then begin
      if random < game_ini_r_single(sect, 'explode_probability') then begin
        SetExplosed(wpn, true);
        if game_ini_line_exist(sect, 'explode_flame_particles') then SetCurrentParticles(wpn, game_ini_read_string(sect, 'explode_flame_particles'), OFFSET_PARTICLE_WEAPON_CURFLAME);
        if game_ini_line_exist(sect, 'explode_shell_particles') then SetCurrentParticles(wpn, game_ini_read_string(sect, 'explode_shell_particles'), OFFSET_PARTICLE_WEAPON_CURSHELLS);
        if game_ini_line_exist(sect, 'explode_smoke_particles') then SetCurrentParticles(wpn, game_ini_read_string(sect, 'explode_smoke_particles'), OFFSET_PARTICLE_WEAPON_CURSMOKE);
      end;
    end;
  end;
end;

procedure WeaponJammed_Patch(); stdcall;
//у нас оружие должно было заклинить при данном выстреле
//мы сделаем хитрее - выставим флаг клина, но игре сообщим, что все нормально, и выстрел при этом произойдет
//Аниму выстрела в заклинившем состоянии выставляем отличную от обычного выстрела в WeaponAnims.pas
asm
  mov byte ptr [esi+$45A],01
  pushad
  pushfd
    push esi
    call OnWeaponJam
  popfd
  popad
  xor eax, eax
end;

//--------------Отображение сообщения о клине----------------------------------

procedure OnJammedHintShow(); stdcall
var
  wpn:pointer;
begin
{  wpn:=GetActorActiveItem();
  if (wpn=nil) or not WpnCanShoot(PChar(GetClassName(wpn))) then exit;
  if not (IsExplosed(wpn) or (IsActionProcessing(wpn) and (leftstr(GetCurAnim(wpn), length('anm_fakeshoot'))<>'anm_fakeshoot'))) then begin
    Messenger.SendMessage('gun_jammed');
  end;}
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
begin
  anm_started:=false;

  //При патчинге мы вырезали воспроизведение звука. Исправим это недоразумение одновременно с проигрыванием анимы.
  if IsWeaponJammed(wpn) then begin
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

  if (GetActor()<>nil) and (GetActor()=GetOwner(wpn)) and anm_started then Messenger.SendMessage(txt);
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

procedure ResetActorFlags(act:pointer);
begin
  SetActorActionState(act, actAimStarted, false);
  SetActorActionState(act, actModSprintStarted, false);
end;

procedure OnWeaponHide(wpn:pointer);stdcall;
var
  act, owner:pointer;
begin
  act:=GetActor();
  owner:=GetOwner(wpn);
  if (owner<>nil) and (owner=act) then begin
    ResetActorFlags(act);
  end;
end;

procedure OnWeaponShow(wpn:pointer);stdcall;
var
  act, owner, det:pointer;
begin
  act:=GetActor();
  owner:=GetOwner(wpn);
  if (owner<>nil) and (owner=act) then begin
    ResetActorFlags(act);
    det:=ItemInSlot(act, 9);
    if (det<>nil) and not CanUseDetectorWithItem(wpn) then begin
      SetDetectorForceUnhide(det, false);
      SetActorActionState(act, actShowDetectorNow, false);
    end;
  end;
end;

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
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazined_NetSpawn_Patch),6, true) then exit;

  jmp_addr:=xrGame_addr+$2BEFE9;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazined_NetDestroy_Patch),6, true) then exit;

  upgrade_weapon_addr:=xrGame_addr+$2D09D6;
  if not WriteJump(upgrade_weapon_addr, cardinal(@Upgrade_Weapon_Patch), 5) then exit;

  //добавим аниму смены режима стрельбы
  jmp_addr:=xrGame_addr+$2CE2AC;
  if not WriteJump(jmp_addr, cardinal(@CanChangeFireMode_Patch), 7, true) then exit;
  jmp_addr:=xrGame_addr+$2CE30C;
  if not WriteJump(jmp_addr, cardinal(@CanChangeFireMode_Patch), 7, true) then exit;

  jmp_addr:=xrGame_addr+$2CE2EF;
  if not WriteJump(jmp_addr, cardinal(@OnChangeFireMode_Patch), 6, true) then exit;
  jmp_addr:=xrGame_addr+$2CE34F;
  if not WriteJump(jmp_addr, cardinal(@OnChangeFireMode_Patch), 6, true) then exit;

  //модифицированный обработчик отображения сообщения о клине
  jmp_addr:=xrGame_addr+$2CFF6B;
  if not WriteJump(jmp_addr, cardinal(@OnJammedHintShow_Patch), 19, true) then exit;
  
  result:=true;
end;


end.


{  asm
    or byte ptr [ebp+$460],01

    pushad
    pushfd

    call CreateLight
    mov ebx, eax

    push [ebp+$170]
    push [ebp+$16C]
    push [ebp+$168]
    push ebx
    call LightUtils.SetPos

    push 01
    push ebx
    call LightUtils.Enable


    popfd
    popad
    ret
  end;}
