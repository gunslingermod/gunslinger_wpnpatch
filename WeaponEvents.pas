unit WeaponEvents;

interface
function Init:boolean;

procedure OnWeaponJam_AfterAnim(wpn:pointer; param:integer);stdcall;
procedure OnWeaponHide(wpn:pointer);stdcall;
procedure OnWeaponShow(wpn:pointer);stdcall;

implementation
uses BaseGameData, GameWrappers, WpnUtils, WeaponAnims, LightUtils, WeaponAdditionalBuffer, sysutils, ActorUtils;

var
  upgrade_weapon_addr:cardinal;

//-------------------------------Разряжание магазина-----------------------------
function OnUnloadMag(wpn:pointer):boolean; stdcall;
var hud_sect:PChar;
const param_name:PChar = 'use_unloadmag_anim';
begin
  result:=true;
  hud_sect:=GetHUDSection(wpn);
  if (not game_ini_line_exist(hud_sect, param_name)) or (not game_ini_r_bool(hud_sect, param_name)) then begin
    exit;
  end;
  WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_unload_mag', 'sndUnload');
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

begin
//  log('Detaching addon: '+inttostr(addontype));
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
    hud_sect:PChar;
begin
  log('Attaching addon: '+inttostr(addontype));

  param_name:=nil;
  snd_name:=nil;
  case addontype of
    1:begin
        addonname:=GetCurrentScopeSection(wpn);
        if addonname<>nil then begin
          param_name:='use_scopeattach_anim';
          anim_name:='anm_attach_scope_'+addonname;
          snd_name:='sndScopeAtt';
          addonname:=game_ini_read_string(addonname, 'scope_name');
        end;
      end;
    4:begin
        addonname:=GetSilencerSection(wpn);
        param_name:='use_silattach_anim';
        anim_name:='anm_attach_sil';
        snd_name:='sndSilAtt';
      end;
    2:begin
        addonname:=GetGLSection(wpn);
        param_name:='use_glattach_anim';
        anim_name:='anm_attach_gl';
        snd_name:='sndGLAtt';
      end;
    else begin
      log('WeaponEvents.OnAddonAttach: Invalid addontype!', true);
      result:=true;
      exit;
    end;
  end;

  hud_sect:=GetHUDSection(wpn);
  actor:=GetActor();
  if (actor=nil) or (actor<>GetOwner(wpn)) or (param_name=nil) or (not game_ini_line_exist(hud_sect, param_name)) or (not game_ini_r_bool(hud_sect, param_name)) then begin
    result:=true;
    exit;
  end;
  result:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, PChar(anim_name), snd_name);

  if (not result) then begin
    //Сейчас присоединять аддон нельзя. Отспавним его назад в инвентарь.
    if addontype = 1 then SetCurrentScopeType(wpn, 0);
    CreateObjectToActor(addonname);
  end;
end;

procedure AttachAddon_Patch(addontype:integer);stdcall;
asm
  push esi
  mov esi, [esp+4] //восстанавливаем из стека указатель на оружие
  push ecx
  mov ecx, addontype

  pushad
    push ecx
    push esi //CWeapon
    call OnAddonAttach
    test al, al
  popad

  je @finish
  or byte ptr [esi+$460], cl

  @finish:
  pop ecx
  pop esi
end;

function InitAttachAddon(address:cardinal; addontype:byte):boolean;
var buf:string;
begin
  result:=false;
  buf:=chr($6A)+chr(addontype);//формируем и записываем аргумент для патча
  if not WriteBufAtAdr(address, PChar(buf), 2) then exit;
  address:=address+2;//теперь записываем вызов патча и нопим лишнее, дабы аддон не исчез
  if not WriteJump(address, cardinal(@AttachAddon_Patch), 0, true) then exit;
  result:=true;
end;

//------------------------отключение хинтов при активном действии----------------

procedure AddonsDetach_UnloadMag_Hint_Patch(); stdcall;
asm
    //выполним оригинальное add esp, 4
    pop edx         //снимаем адрес возврата
    mov [esp], edx  //переносим его вверх по стеку

    mov esi, eax
    test esi, esi
    je @finish

    pushad
      push 0
      push [esp+$38]
      call WeaponAdditionalBuffer.CanStartAction
      cmp al, 0
    popad

    @finish:
end;

procedure AddonsAttach_Hint_Patch(); stdcall;
asm
  //оригинальный код
  mov ecx, eax

  //пистолет - в esi, винтовка - в ecx

  //проверяем пистолет
  cmp esi, 0
  je @rifle
  pushad
    push 0
    push esi
    call WeaponAdditionalBuffer.CanStartAction
    cmp al, 0
  popad
  jne @rifle
  xor esi, esi

  @rifle:
  //проверим винтовку
  cmp ecx, 0
  je @finish
  pushad
    push 0
    push ecx
    call WeaponAdditionalBuffer.CanStartAction
    cmp al, 0
  popad
  jne @finish
  xor ecx, ecx

  @finish:
  //оригинальный код
  mov [esp+$28], ecx
  test esi, esi
end;

//------------------------------------------------------------------------------
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
//function OnChangeFireMode(wpn:pointer):boolean; stdcall;
//var
//  hud_sect:PChar;
//begin
//  result:=true;
//  hud_sect:=GetHUDSection(wpn);
//  if (not game_ini_line_exist(hud_sect, 'use_firemode_change_anim')) or (not game_ini_r_bool(hud_sect, 'use_firemode_change_anim')) then exit;
//  result:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_changefiremode', 'sndChangeFireMode');
//end;

procedure OnChangeFireMode(wpn:pointer; new_mode:integer); stdcall;
var
  hud_sect:PChar;
  firemode:integer;
  anm_name:string;
begin
  hud_sect:=GetHUDSection(wpn);
  if (hud_sect=nil) or (not game_ini_line_exist(hud_sect, 'use_firemode_change_anim')) or (not game_ini_r_bool(hud_sect, 'use_firemode_change_anim')) then exit;

  firemode:=CurrentQueueSize(wpn);
  anm_name:='anm_changefiremode_from_';
  if firemode<0 then anm_name:=anm_name+'a' else anm_name:=anm_name+inttostr(firemode);
  anm_name:=anm_name+'_to_';
  if new_mode<0 then anm_name:=anm_name+'a' else anm_name:=anm_name+inttostr(new_mode);
  
  WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, PChar(anm_name), 'sndChangeFireMode');
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
procedure OnWeaponJam_AfterAnim(wpn:pointer; param:integer);stdcall;
begin
  log('AfterExplosion');
  alife_create('energetic_trash', GetPosition(wpn), GetLevelVertexID(wpn), GetGameVertexID(wpn));
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
      end;
    end; 
  end;
//
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

//---------------------Щелчки при осечках/пустом магазине-----------------------
procedure OnEmptyClick(wpn:pointer);stdcall;
begin
  //При патчинге мы вырезали воспроизведение звука. Исправим это недоразумение одновременно с проигрыванием анимы.
  if IsWeaponJammed(wpn) then begin
    if IsAimNow(wpn) or IsHolderInAimState(wpn) then begin
      WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_fakeshoot_aim', 'sndJammedClick', nil, 0, false, true)
    end else begin
      WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_fakeshoot', 'sndJammedClick', nil, 0, false, true);
    end;
  end else begin
    if IsAimNow(wpn) or IsHolderInAimState(wpn) then begin
      WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_fakeshoot_aim', 'sndEmptyClick', nil, 0, false, true)
    end else begin
      WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_fakeshoot', 'sndEmptyClick', nil, 0, false, true);
    end;
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
  //Отключение отображения хинтов об аттаче
  jmp_addr:= xrGame_addr+$46D6A3;
  if not WriteJump(jmp_addr, cardinal(@AddonsAttach_Hint_Patch), 8, true) then exit;

  //Аттач прицела
  InitAttachAddon(xrGame_addr+$2CEE33, 1);
  //Аттач подствола
  InitAttachAddon(xrGame_addr+$2CEEF5, 2);
  //Аттач глушителя
  InitAttachAddon(xrGame_addr+$2CEE5A, 4);

  //-----------------------------------------------------------------------------------------------------
  //Отключение отображения хинтов о детаче и разрядке магазина
  jmp_addr:= xrGame_addr+$46ca86;
  if not WriteJump(jmp_addr, cardinal(@AddonsDetach_UnloadMag_Hint_Patch), 7, true) then exit;

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

  result:=true;
end;

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
  act, owner:pointer;
begin
  act:=GetActor();
  owner:=GetOwner(wpn);
  if (owner<>nil) and (owner=act) then begin
    ResetActorFlags(act);
  end;
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
