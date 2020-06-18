unit WeaponAnims;

//Не уверен - не лезь. Sin!

interface
function Init:boolean;
function ModifierStd(wpn:pointer; base_anim:string; disable_noanim_hint:boolean=false):string;stdcall;
function ModifierAlterSprint(wpn:pointer; base_anim:string):string;stdcall;
function CanReloadNow(wpn:pointer):boolean; stdcall;

function anm_shots_selector(wpn:pointer; play_breech_snd:boolean):pchar;stdcall;

implementation
uses BaseGameData, HudItemUtils, ActorUtils, WeaponAdditionalBuffer, math, WeaponEvents, sysutils, strutils, DetectorUtils, WeaponAmmoCounter, Throwable, gunsl_config, messenger, xr_Cartridge, ActorDOF, MatVectors, WeaponUpdate, WeaponInertion, ControllerMonster, Misc, Level, dynamic_caster, UIUtils, xr_strings, ScriptFunctors;

var
  anim_name:string;   //из-за того, что все нужное в одном потоке - имем право заглобалить переменную, куда будем писать измененное название анимы
  jump_addr:cardinal;

  movreass_last_update:cardinal;
  movreass_remain_time:cardinal;


procedure ModifierGL(wpn:pointer; var anm:string);
var
  status:cardinal;
begin
  status:=GetGLStatus(wpn);
  if (status=1) or ((status = 2) and IsGLAttached(wpn)) then begin
    if IsGLEnabled(wpn) then
      anm:=anm+'_g'
    else
      anm:=anm+'_w_gl';
  end;
end;

function GetFireModeStateMark(wpn:pointer):string;
var
  hud_sect:PChar;
  firemode:integer;
  tmpstr:string;
begin
  result:='';
  hud_sect:=GetHUDSection(wpn);
  if hud_sect=nil then exit;
  firemode:=CurrentQueueSize(wpn);
  if firemode<0 then tmpstr:='a' else tmpstr:=inttostr(firemode);
  tmpstr:='mask_firemode_'+tmpstr;
  if game_ini_line_exist(hud_sect, PChar(tmpstr)) then begin
    result:=game_ini_read_string(hud_sect,PChar(tmpstr));
  end;
end;

procedure ModifierMoving(wpn:pointer; actor:pointer; var anm:string; config_enabler_directions:string; config_enabler_main:string='');
var hud_sect:PChar;
begin
  hud_sect:=GetHUDSection(wpn);
  if GetSection(wpn)=GetPDAShowAnimator() then begin
    anm:=anm+GetPDAJoystickAnimationModifier();
  end;

  if (config_enabler_main<>'') then begin
     if not game_ini_line_exist(hud_sect, PChar(config_enabler_main)) or not game_ini_r_bool(hud_sect, PChar(config_enabler_main)) then exit;
  end;
  if GetActorActionState(actor, actMovingForward or actMovingBack or actMovingLeft or actMovingRight) then begin
    anm:=anm+'_moving';
    
    if not game_ini_line_exist(hud_sect, PChar(config_enabler_directions)) or not game_ini_r_bool(hud_sect, PChar(config_enabler_directions)) then exit;
    if GetActorActionState(actor, actMovingForward) then begin
      anm:=anm+'_forward';
    end;
    if GetActorActionState(actor, actMovingBack) then begin
      anm:=anm+'_back';
    end;
    if GetActorActionState(actor, actMovingLeft) then begin
      anm:=anm+'_left';
    end;
    if GetActorActionState(actor, actMovingRight) then begin
      anm:=anm+'_right';
    end;
  end;
end;

procedure ModifierBM16(wpn:pointer; var anm:string);
var cnt:integer;
begin
  if IsBM16(wpn) then begin
    cnt:=GetAmmoInMagCount(wpn);
    if cnt<=0 then
      anm:=anm+'_0'
    else if cnt=1 then
      anm:=anm+'_1'
    else
      anm:=anm+'_2';
  end;
end;

//------------------------------------------------------------------------------anm_idle(_sprint, _moving, _aim)---------------------------------------
function anm_idle_selector(wpn:pointer):pchar;stdcall;
var
  hud_sect:PChar;
  actor:pointer;
  canshoot, isdetector, isgrenorbolt, is_knife, is_bino:boolean;
  companion:pointer;
  assign_detector_anim:boolean;
  snd_label:PChar;

begin
  snd_label:=nil;
  hud_sect:=GetHUDSection(wpn);
  anim_name:='anm_idle';
  actor:=GetActor();
  canshoot:=WpnCanShoot(wpn);
  isgrenorbolt:=IsThrowable(wpn);
  isdetector :=WpnIsDetector(wpn);
  is_knife:=IsKnife(wpn);
  is_bino:=IsBino(wpn);
  assign_detector_anim:=false;
  //Если у нас владелец - не актор, то и смысла работать дальше нет
  if (actor<>nil) and (actor=GetOwner(wpn)) then begin
    if isdetector then companion:=GetActorActiveItem() else companion:=GetActiveDetector(actor);
    //--------------------------Модификаторы движения/состояния актора---------------------------------------

    //если актор в режиме прицеливания
    if (canshoot or is_bino) and IsAimNow(wpn) then begin
      anim_name:=anim_name+'_aim';
      if GetActorActionState(actor, actAimStarted) then begin
        if (GetScopeStatus(wpn)=2) and IsScopeAttached(wpn) and game_ini_r_bool_def(hud_sect, 'aim_scope_anims', true) and game_ini_r_bool_def(GetCurrentScopeSection(wpn), 'use_scope_anims', false) and game_ini_r_bool_def(GetCurrentScopeSection(wpn), 'use_scope_anims', false) then anim_name:=anim_name+'_scope';
        ModifierMoving(wpn, actor, anim_name, 'enable_directions_'+anim_name);
      end else begin
        anim_name:=anim_name+'_start';
        if canshoot then snd_label:='sndAimStart';
        SetActorActionState(actor, actAimStarted, true);
      end;
      if companion<>nil then assign_detector_anim:=true;
    end else if (canshoot or is_bino) and GetActorActionState(actor, actAimStarted) then begin
      anim_name:=anim_name+'_aim_end';
      if (GetSection(wpn)=GetPDAShowAnimator()) and (not IsPDAWindowVisible() or (GetActorTargetSlot()<>GetActorActiveSlot())) then begin
        SetCurrentState(wpn,EHudStates__eHiding);
        SetNextState(wpn, EHudStates__eHiding);
        anim_name:=anim_name+'_hide';
      end;
      if canshoot then snd_label:='sndAimEnd';
      SetActorActionState(actor, actAimStarted, false);
      if companion<>nil then assign_detector_anim:=true;

    //посмотрим на передвижение актора:
    end else if GetActorActionState(actor, actSprint) then begin
      anim_name:=anim_name+'_sprint';
      anim_name:=ModifierAlterSprint(wpn, anim_name);
      if (isdetector and not GetActorActionState(actor, actModDetectorSprintStarted)) or (not isdetector and not GetActorActionState(actor, actModSprintStarted)) then begin
        anim_name:=anim_name+'_start';
        if (canshoot or isgrenorbolt or is_knife) then snd_label:='sndSprintStart';
        if isdetector then
          SetActorActionState(actor, actModDetectorSprintStarted, true)
        else
          SetActorActionState(actor, actModSprintStarted, true);
      end;

    end else if (isdetector and GetActorActionState(actor, actModDetectorSprintStarted)) or (not isdetector and GetActorActionState(actor, actModSprintStarted)) then begin;
      anim_name:=anim_name+'_sprint';
      anim_name:=ModifierAlterSprint(wpn, anim_name);
      anim_name:=anim_name+'_end';
      if (canshoot or isgrenorbolt or is_knife) then
        snd_label:='sndSprintEnd';

      if isdetector then
        SetActorActionState(actor, actModDetectorSprintStarted, false)
      else
        SetActorActionState(actor, actModSprintStarted, false);

    end else begin
      if is_knife and (GetActualCurrentAnim(wpn)='anm_prepare_suicide') then begin
        anim_name:='anm_stop_suicide';

      end else begin
        ModifierMoving(wpn, actor, anim_name, 'enable_directions_'+anim_name);
        if GetActorActionState(actor, actCrouch) then begin
          anim_name:=anim_name+'_crouch';
        end;
        if GetActorActionState(actor, actSlow) then begin
          anim_name:=anim_name+'_slow';
        end;
      end;
    end;
  //----------------------------------Модификаторы состояния оружия----------------------------------------------------

    if canshoot then begin
        anim_name:=anim_name + GetFireModeStateMark(wpn);
        //Если оружие заклинило - всегда пытаемся отыграть это состояние
        if IsWeaponJammed(wpn) then begin
          anim_name:=anim_name+'_jammed';
        end else if (GetAmmoInMagCount(wpn)<=0) and not IsBM16(wpn) then begin
          anim_name:=anim_name+'_empty';
        end;

        ModifierGL(wpn, anim_name);
    end;
  end;
  //Двустволки имеют собственный суффикс
  ModifierBM16(wpn, anim_name);

  //Если мы работаем с детектором
  if (isdetector and Is16x9 and not game_ini_line_exist(hud_sect, PChar(anim_name+'_16x9'))) then begin
    log('Section ['+hud_sect+'] has no motion alias defined ['+anim_name+'_16x9]');
    if IsDebug then Messenger.SendMessage('Animation not found, see log!');
    anim_name:='anm_idle';
  end;

  if (not game_ini_line_exist(hud_sect, PChar(anim_name))) then begin
    log('Section ['+hud_sect+'] has no motion alias defined ['+anim_name+']');
    if IsDebug then Messenger.SendMessage('Animation not found, see log!');
    anim_name:='anm_idle';
    ModifierBM16(wpn, anim_name);
  end;

  if assign_detector_anim then begin
//    log('assigning ');
    StartCompanionAnimIfNeeded(rightstr(anim_name, length(anim_name)-4), wpn, true);
  end;
    
  result:=PChar(anim_name);
  MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_'+anim_name));


  if not PlaySoundByAnimName(wpn, anim_name) and (snd_label<>nil) then begin
    CHudItem_Play_Snd(wpn, snd_label);
  end;
end;


procedure anm_idle_std_patch();stdcall;
begin
  asm
    push 0                  //забиваем место под название анимы
    pushad
    pushfd
    push esi
    call anm_idle_selector  //получаем строку с именем анимы
    mov ecx, [esp+$28]      //запоминаем адрес возврата
    mov [esp+$28], eax      //кладем на его место результирующую строку
    mov [esp+$24], ecx      //перемещаем адрес возврата на 4 байта выше в стеке
    popfd
    popad
    ret
  end;
end;

procedure anm_idle_sub_patch();stdcall;
begin
  asm

    sub esi, $2E0
    call anm_idle_std_patch
    add esi, $2E0

    push eax
    push ebx
    mov eax, [esp+8]
    mov ebx, [esp+$c]
    mov [esp+8], ebx
    mov [esp+$c], eax
    pop ebx
    pop eax

  end;
end;

function ModifierAlterSprint(wpn:pointer; base_anim:string):string;stdcall;
var
  hud_sect:PChar;
  buf:WpnBuf;
begin
  result:=base_anim;
  hud_sect:=GetHUDSection(wpn);
  if game_ini_r_bool_def(hud_sect, 'use_alter_sprint_anims', false) then begin
    buf := GetBuffer(wpn);
    if IsSilencerAttached(wpn) or ((buf<>nil) and (buf.IsLaserInstalled() or buf.IsTorchInstalled() )) then begin
      result:=result+'_alter';
    end;
  end;
end;

//------------------------------------------------------------------------------anm_show/hide/bore/switch_*-----------------------
function ModifierStd(wpn:pointer; base_anim:string; disable_noanim_hint:boolean=false):string;stdcall;
var
  hud_sect:PChar;
  actor:pointer;
begin
  hud_sect:=GetHUDSection(wpn);
  actor:=GetActor();
  //Если у нас владелец - не актор, то и смысла работать дальше нет
  if (actor<>nil) and (actor=GetOwner(wpn)) then begin
  //----------------------------------Модификаторы состояния оружия----------------------------------------------------
    //Если магазин пуст - всегда играем empty, если можем
    if WpnCanShoot(wpn) then begin
      if leftstr(base_anim, 18)<>'anm_changefiremode' then base_anim:=base_anim + GetFireModeStateMark(wpn);
      if IsWeaponJammed(wpn) then begin
        base_anim:=base_anim+'_jammed';
      end else if (GetAmmoInMagCount(wpn)<=0) and (not IsBM16(wpn)) then begin
        base_anim:=base_anim+'_empty';
      end;

      if IsHolderHasActiveDetector(wpn) and game_ini_line_exist(hud_sect, PChar(base_anim+'_detector')) then begin
        //log ('det+rel');
        base_anim:=base_anim+'_detector';
      end;

      if game_ini_line_exist(hud_sect, PChar('disable_detector_'+base_anim)) and game_ini_r_bool(hud_sect, PChar('disable_detector_'+base_anim)) and game_ini_line_exist(hud_sect, PChar('immediate_unhide_'+base_anim)) and game_ini_r_bool(hud_sect, PChar('immediate_unhide_'+base_anim)) then begin
        SetActorActionState(actor, actShowDetectorNow, true);
      end;

      ModifierMoving(wpn, actor, base_anim, 'enable_directions_'+base_anim, 'enable_moving_'+base_anim);
    end;
  end;
  
  ModifierGL(wpn, base_anim);
  ModifierBM16(wpn, base_anim);
  if not disable_noanim_hint then begin
    if not game_ini_line_exist(hud_sect, PChar(base_anim)) then begin
      log('Section ['+hud_sect+'] has no motion alias defined ['+base_anim+']');
      if IsDebug then Messenger.SendMessage('Animation not found, see log!');
      base_anim:='anm_reload';
      ModifierBM16(wpn, base_anim);
    end;
  end;
  result:=base_anim;
end;

function anm_std_selector(wpn:pointer; base_anim:PChar):pchar;stdcall;
var
  v:FVector3;
begin
  anim_name := ModifierStd(wpn, base_anim);
  if ReadActionDOFVector(wpn, v, anim_name, false) then begin
    SetDOF(v, ReadActionDOFSpeed_In(wpn, anim_name));
  end;
  result:=PChar(anim_name);
  MakeLockByConfigParam(wpn, GetHUDSection(wpn), PChar('lock_time_'+anim_name));
  PlaySoundByAnimName(wpn, result)
end;

function anm_show_selector(wpn:pointer):pchar;stdcall;
var
  anm_show:PChar;
begin
  anm_show := 'anm_show';
  if (GetActor()<>nil) and (GetActor()=GetOwner(wpn)) then begin
    ResetItmHudOffset(wpn);
    if not game_ini_line_exist(GetSection(wpn), 'gwr_changed_object') and not game_ini_line_exist(GetSection(wpn), 'gwr_eatable_object') and not game_ini_r_bool_def(GetSection(wpn), 'action_animator', false) then begin
      ForgetDetectorAutoHide();
    end;
  end;

  if IsActorPlanningSuicide() or IsActorSuicideNow() then begin
    if game_ini_r_bool_def(GetHUDSection(wpn), 'enable_anm_show_suicide', false) then begin
      anm_show:='anm_show_suicide';
    end;
  end;
  result:=anm_std_selector(wpn, anm_show);
end;

function anm_bore_selector(wpn:pointer; base_anim:PChar):pchar;stdcall;
var
  snd:PChar;
begin
  snd:=nil;
  if (GetActor<>nil) and (GetActor()=GetOwner(wpn)) and (GetActorActionState(GetActor(), actModNeedBlowoutAnim)) then begin
    result:=anm_std_selector(wpn, 'anm_blowout');
    snd:='sndBlowout';
    SetActorActionState(GetActor(), actModNeedBlowoutAnim, false);
  end else begin
    result:=anm_std_selector(wpn, base_anim);
    snd:='sndBore';
  end;

  if GetActorActiveItem()=wpn then begin
    CHudItem_Play_Snd(wpn, snd);
  end;
end;

procedure anm_show_std_patch();stdcall;
begin
  asm
    push 0                  //забиваем место под название анимы

    pushad
    pushfd
      push esi
      call WeaponEvents.OnWeaponShow
    popfd
    popad


    pushad
    pushfd
    push esi
    call anm_show_selector  //получаем строку с именем анимы
    mov ecx, [esp+$28]      //запоминаем адрес возврата
    mov [esp+$28], eax      //кладем на его место результирующую строку
    mov [esp+$24], ecx      //перемещаем адрес возврата на 4 байта выше в стеке
    popfd
    popad
    ret
  end;
end;

procedure anm_show_sub_patch();stdcall;
begin
  asm

    sub esi, $2E0
    call anm_show_std_patch
    add esi, $2E0

    push eax
    push ebx
    mov eax, [esp+8]
    mov ebx, [esp+$c]
    mov [esp+8], ebx
    mov [esp+$c], eax
    pop ebx
    pop eax

  end;
end;

procedure anm_hide_std_patch();stdcall;
const anm_hide:PChar = 'anm_hide';
begin
  asm
    push 0                  //забиваем место под название анимы

    pushad
      push esi
      call OnWeaponHideAnmStart
    popad

    pushad
    pushfd
      push anm_hide
      push esi
      call anm_std_selector   //получаем строку с именем анимы
      mov ecx, [esp+$28]      //запоминаем адрес возврата
      mov [esp+$28], eax      //кладем на его место результирующую строку
      mov [esp+$24], ecx      //перемещаем адрес возврата на 4 байта выше в стеке
    popfd
    popad
    ret
  end;
end;

procedure anm_hide_sub_patch();stdcall;
begin
  asm

    sub esi, $2E0
    call anm_hide_std_patch
    add esi, $2E0

    push eax
    push ebx
    mov eax, [esp+8]
    mov ebx, [esp+$c]
    mov [esp+8], ebx
    mov [esp+$c], eax
    pop ebx
    pop eax

  end;
end;

procedure anm_bore_edi_patch();stdcall;
const anm_bore:PChar = 'anm_bore';
begin
  asm
    push 0                  //забиваем место под название анимы
    pushad
    pushfd
    push anm_bore
    sub edi, $2E0
    push edi
    call anm_bore_selector  //получаем строку с именем анимы
    mov ecx, [esp+$28]      //запоминаем адрес возврата
    mov [esp+$28], eax      //кладем на его место результирующую строку
    mov [esp+$24], ecx      //перемещаем адрес возврата на 4 байта выше в стеке
    popfd
    popad
    ret
  end;
end;

procedure anm_bore_std_patch();stdcall;
const anm_bore:PChar = 'anm_bore';
begin
  asm
    push 0                  //забиваем место под название анимы
    pushad
    pushfd
    push anm_bore
    push esi
    call anm_bore_selector  //получаем строку с именем анимы
    mov ecx, [esp+$28]      //запоминаем адрес возврата
    mov [esp+$28], eax      //кладем на его место результирующую строку
    mov [esp+$24], ecx      //перемещаем адрес возврата на 4 байта выше в стеке
    popfd
    popad
    ret
  end;
end;

procedure anm_bore_sub_patch();stdcall;
begin
  asm

    sub esi, $2E0
    call anm_bore_std_patch
    add esi, $2E0

    push eax
    push ebx
    mov eax, [esp+8]
    mov ebx, [esp+$c]
    mov [esp+8], ebx
    mov [esp+$c], eax
    pop ebx
    pop eax

  end;
end;

procedure anm_switch_sub_patch();stdcall;
const anm_switch:PChar = 'anm_switch';
begin
  asm
    push 0                  //забиваем место под название анимы
    pushad
    pushfd
    sub esi, $2E0
    push anm_switch
    push esi
    call anm_std_selector  //получаем строку с именем анимы
    mov ecx, [esp+$28]      //запоминаем адрес возврата
    mov [esp+$28], eax      //кладем на его место результирующую строку
    mov [esp+$24], ecx      //перемещаем адрес возврата на 4 байта выше в стеке
    popfd
    popad
    ret
  end;
end;

function anm_shoot_g_selector(wpn:pointer; base_anim:PChar):pchar;stdcall;
var
  tmpstr:string;
  actor:pointer;
  hud_sect:PChar;
begin
  tmpstr:=base_anim;
  actor:=GetActor();
  //Если у нас владелец - не актор, то и смысла работать дальше нет
  if (actor<>nil) and (actor=GetOwner(wpn)) and (IsAimNow(wpn) or IsHolderInAimState(wpn)) then begin
    tmpstr:=tmpstr+'_aim';
  end;

  hud_sect:=GetHUDSection(wpn);
  if (actor<>nil) and (actor=GetOwner(wpn)) and (IsActorSuicideNow() or IsSuicideInreversible()) and game_ini_r_bool_def(hud_sect, 'custom_suicide_shot', false) then begin
    tmpstr:=tmpstr+'_suicide';
  end;

  result:=anm_std_selector(wpn, PChar(tmpstr));
end;

procedure anm_shoot_g_std_patch();stdcall;
const anm_shoot_g:PChar = 'anm_shoot';
begin
  asm
    push 0                  //забиваем место под название анимы
    pushad
    pushfd
    push anm_shoot_g
    push esi
    call anm_shoot_g_selector  //получаем строку с именем анимы
    mov ecx, [esp+$28]      //запоминаем адрес возврата
    mov [esp+$28], eax      //кладем на его место результирующую строку
    mov [esp+$24], ecx      //перемещаем адрес возврата на 4 байта выше в стеке
    popfd
    popad
    ret
  end;
end;

function anm_close_selector(wpn:pointer):pchar; stdcall;
var
  buf:WpnBuf;
  hud_sect:PChar;
  v:FVector3;
  preload:boolean;
begin
  preload:=false;
  anim_name := ModifierStd(wpn, 'anm_close');

  buf:=GetBuffer(wpn);
  if buf <> nil then begin
    if (buf.IsPreloadMode()) and (buf.IsPreloaded()) then begin
      preload:=true;
      anim_name:=anim_name+'_preloaded';
      buf.SetPreloadedStatus(false);
    end;

    buf.SetReloaded(false);
    hud_sect:=GetHUDSection(wpn);
    MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_'+anim_name));
  end;

  if ReadActionDOFVector(wpn, v, anim_name, true) then begin
    SetDOF(v, ReadActionDOFSpeed_In(wpn, anim_name));
  end;

  result:=PChar(anim_name);
  if PlaySoundByAnimName(wpn, result) then begin
  end else if preload then begin
    CHudItem_Play_Snd(wpn, 'sndClosePreloaded');
  end else if GetCurrentAmmoCount(wpn)>0 then begin
    CHudItem_Play_Snd(wpn, 'sndClose');
  end else begin
    CHudItem_Play_Snd(wpn, 'sndCloseEmpty');
  end;
end;



procedure anm_close_std_patch();stdcall;
begin
  asm
    push 0                  //забиваем место под название анимы
    pushad
    pushfd
    push esi
    call anm_close_selector  //получаем строку с именем анимы
    mov ecx, [esp+$28]      //запоминаем адрес возврата
    mov [esp+$28], eax      //кладем на его место результирующую строку
    mov [esp+$24], ecx      //перемещаем адрес возврата на 4 байта выше в стеке
    popfd
    popad
    ret
  end;
end;
//------------------------------------------------------------add_cartridge-----------------------------------------
procedure OnAddCartridge(wpn:pointer; param:integer);stdcall;
var
  hud_sect:PChar;
begin
  if (GetActor()<>nil) and (GetOwner(wpn)=GetActor()) and (leftstr(GetCurAnim(wpn), length('anm_add_cartridge'))='anm_add_cartridge') then begin
    hud_sect:=GetHUDSection(wpn);
    GetBuffer(wpn).SetReloaded(false);
    CWeaponShotgun__OnAnimationEnd_OnAddCartridge(wpn);
    GetBuffer(wpn).SetReloaded(true);
    MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_end_'+GetCurAnim(wpn)));
  end;
end;


function anm_add_cartridge_selector(wpn:pointer):pchar;stdcall;
var
  buf:WpnBuf;
  hud_sect:PChar;
  v:FVector3;
  preload:boolean;
begin
  preload:=false;
  anim_name := ModifierStd(wpn, 'anm_add_cartridge');

  buf:=GetBuffer(wpn);
  if buf <> nil then begin
    if (buf.IsPreloadMode()) and (buf.IsPreloaded()) then begin
      preload:=true;
      anim_name:=anim_name+'_preloaded';
      buf.SetPreloadedStatus(false);
    end;

    buf.SetReloaded(false);
    hud_sect:=GetHUDSection(wpn);
    if game_ini_line_exist(hud_sect, PChar('lock_time_start_'+anim_name)) then begin
      MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_start_'+anim_name), false, OnAddCartridge);
    end else begin
      MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_'+anim_name));
    end;
  end;

  if ReadActionDOFVector(wpn, v, anim_name, true) then begin
    SetDOF(v, ReadActionDOFSpeed_In(wpn, anim_name));
  end;  

  result:=PChar(anim_name);
  if PlaySoundByAnimName(wpn, result) then begin
  end else if preload then begin
    CHudItem_Play_Snd(wpn, 'sndAddCartridgePreloaded');
  end else if GetCurrentAmmoCount(wpn)>0 then begin
    CHudItem_Play_Snd(wpn, 'sndAddCartridge');
  end else begin
    CHudItem_Play_Snd(wpn, 'sndAddCartridgeEmpty');
  end;
end;


procedure anm_add_cartridge_std_patch();stdcall;
asm
    push 0                  //забиваем место под название анимы
    pushad
    pushfd
    push esi
    call anm_add_cartridge_selector  //получаем строку с именем анимы
    mov ecx, [esp+$28]      //запоминаем адрес возврата
    mov [esp+$28], eax      //кладем на его место результирующую строку
    mov [esp+$24], ecx      //перемещаем адрес возврата на 4 байта выше в стеке
    popfd
    popad
    ret
end;

//------------------------------------------------------------anm_open-----------------------------------------------

procedure OnAddCartridgeInOpen(wpn:pointer; param:integer);stdcall;
var
  hud_sect:PChar;
begin
  if (GetActor()<>nil) and (GetOwner(wpn)=GetActor()) and (leftstr(GetCurAnim(wpn), length('anm_open'))='anm_open') then begin
    hud_sect:=GetHUDSection(wpn);
    GetBuffer(wpn).SetReloaded(false);
    CWeaponShotgun__OnAnimationEnd_OnAddCartridge(wpn);
    GetBuffer(wpn).SetReloaded(true);
    MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_end_'+GetCurAnim(wpn)));
  end;
end;

function anm_open_selector(wpn:pointer):pchar;stdcall;
var
  buf:WpnBuf;
  hud_sect:PChar;
  v:FVector3;
begin
  if IsWeaponJammed(wpn) then begin
    anim_name := ModifierStd(wpn, 'anm_reload');
    if GetAmmoInMagCount(wpn)=0 then anim_name:=anim_name+'_last';
    result:=PChar(anim_name);

    if PlaySoundByAnimName(wpn, result) then begin
    end else if GetAmmoInMagCount(wpn)>0 then begin
      CHudItem_Play_Snd(wpn, 'sndReloadJammed');
    end else begin
      CHudItem_Play_Snd(wpn, 'sndReloadJammedLast');
    end;

    if ReadActionDOFVector(wpn, v, anim_name, true) then begin
      SetDOF(v, ReadActionDOFSpeed_In(wpn, anim_name));
    end;
    exit;
  end;

  anim_name := ModifierStd(wpn, 'anm_open');
  result:=PChar(anim_name);

  if PlaySoundByAnimName(wpn, result) then begin
  end else if GetCurrentAmmoCount(wpn)>0 then begin
    CHudItem_Play_Snd(wpn, 'sndOpen');
  end else begin
    CHudItem_Play_Snd(wpn, 'sndOpenEmpty');
  end;

  buf:=GetBuffer(wpn);
  if buf <> nil then begin
    buf.SetPreloadedStatus((GetCurrentAmmoCount(wpn)=0) and buf.IsPreloadMode());
    buf.SetReloaded(false);
    hud_sect:=GetHUDSection(wpn);
    if buf.AddCartridgeAfterOpen() then begin
      MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_start_'+anim_name), false, OnAddCartridgeInOpen);
    end else begin
      MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_'+anim_name));
    end;
  end;

  if ReadActionDOFVector(wpn, v, anim_name, true) then begin
    SetDOF(v, ReadActionDOFSpeed_In(wpn, anim_name));
  end;
end;

procedure anm_open_std_patch();stdcall;
begin
  asm
    push 0                  //забиваем место под название анимы
    pushad
    pushfd
    push esi
    call anm_open_selector  //получаем строку с именем анимы
    mov ecx, [esp+$28]      //запоминаем адрес возврата
    mov [esp+$28], eax      //кладем на его место результирующую строку
    mov [esp+$24], ecx      //перемещаем адрес возврата на 4 байта выше в стеке
    popfd
    popad
    ret
  end;
end;

//----------------------------------------------------------anm_shots------------------------------------------------
procedure SpawnShells(wpn:pointer); stdcall;
var
  ammo_sect:PChar;
  buf:WpnBuf;
  off, pos:FVector3;
  sitm:pCSE_Abstract;
  wpn_id:string;
begin
  buf:=GetBuffer(wpn);
  if (buf=nil) or not buf.IsShellsNeeded() then exit;
  ammo_sect:=GetMainCartridgeSectionByType(wpn, GetCartridgeType(GetCartridgeFromMagVector(wpn, GetAmmoInMagCount(wpn)-1)));
  if not game_ini_line_exist(ammo_sect, 'shell_sect') then exit;
  ammo_sect:=game_ini_read_string(ammo_sect, 'shell_sect');

  off:=buf.GetShellsOffset();
  transform_tiny(GetXFORM(wpn), @pos, @off);
  off:=GetLastFD(wpn);


  sitm := CLevel__SpawnItem(GetLevel(), ammo_sect, @pos, $FFFFFFFF, $FFFF, true);

  if sitm<>nil then begin
    CSE_SetAngle(sitm, @off);
    set_name_replace(sitm, PChar(inttostr(GetID(wpn))));
    CLevel__AfterSpawnSendAndFree (GetLevel(), sitm);
  end;

end;
    
function anm_shots_selector(wpn:pointer; play_breech_snd:boolean):pchar;stdcall;
var
  hud_sect:PChar;
  actor:pointer;
  fun:TAnimationEffector;
  modifier:string;
  v:FVector3;
  buf:WpnBuf;

begin
  fun:=nil;

  if play_breech_snd then begin
    if IsExplosed(wpn) then begin
      CHudItem_Play_Snd(wpn, 'sndExplose');
    end else if IsWeaponJammed(wpn) then begin
      CHudItem_Play_Snd(wpn, 'sndJam');
    end else begin
      CHudItem_Play_Snd(wpn, 'sndBreechblock');
    end
  end;

  hud_sect:=GetHUDSection(wpn);
  anim_name:='anm_shoot';
  modifier:='';

  SpawnShells(wpn);
  buf:=GetBuffer(wpn);
  if buf<>nil then begin
    buf.RegisterShot();
  end;

  ProcessAmmo(wpn, true);
  actor:=GetActor();
  //Если у нас владелец - не актор, то и смысла работать дальше нет
  if (actor<>nil) and (actor=GetOwner(wpn)) then begin
    //----------------------------------Модификаторы состояния актора----------------------------------------------------
    if IsAimNow(wpn) or IsHolderInAimState(wpn) then begin
      modifier:=modifier+'_aim';
      if (GetScopeStatus(wpn)=2) and IsScopeAttached(wpn) and game_ini_r_bool_def(hud_sect, 'aim_scope_anims', true) and game_ini_r_bool_def(GetCurrentScopeSection(wpn), 'use_scope_anims', false) then modifier:=modifier+'_scope';
      if buf<>nil then begin
        buf.ApplyLensRecoil(buf.GetShootRecoil);
      end;
    end;
    //----------------------------------Модификаторы состояния оружия----------------------------------------------------
    modifier:=modifier + GetFireModeStateMark(wpn);
    if IsExplosed(wpn) then begin
      modifier:=modifier+'_explose';
      fun:=OnWeaponExplode_AfterAnim;
    end else if IsWeaponJammed(wpn) then begin
      modifier:=modifier+'_jammed';
    end else if (GetAmmoInMagCount(wpn)=1) and (not IsBM16(wpn)) then begin
      modifier:=modifier+'_last';
    end;

    if (IsActorSuicideNow() or IsSuicideInreversible()) and game_ini_r_bool_def(hud_sect, 'custom_suicide_shot', false) then begin
      modifier:=modifier+'_suicide';
    end;

    if (GetSilencerStatus(wpn)=1) or ((GetSilencerStatus(wpn)=2) and IsSilencerAttached(wpn)) then modifier:=modifier+'_sil';
    ModifierMoving(wpn, actor, modifier, 'enable_directions_anm_shoot_directions', 'enable_moving_anm_shoot');
    ModifierGL(wpn, modifier);

  end;

  ModifierBM16(wpn, modifier);


  //Теперь воспроизведем все

  StartCompanionAnimIfNeeded('shoot'+modifier, wpn, true);


  anim_name:=anim_name+modifier;
  if not game_ini_line_exist(hud_sect, PChar(anim_name)) then begin
    log('Section ['+hud_sect+'] has no motion alias defined ['+anim_name+']');
    if IsDebug then Messenger.SendMessage('Animation not found, see log!');
    anim_name:='anm_reload';
    ModifierBM16(wpn, anim_name);
  end;

  if ReadActionDOFVector(wpn, v, anim_name, false) then begin
    SetDOF(v, ReadActionDOFSpeed_In(wpn, anim_name));
  end;
  result:=PChar(anim_name);
  MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_'+anim_name), true, fun, 0);

  PlaySoundByAnimName(wpn, result);
  SetAnimForceReassignStatus(wpn, true);
end;

procedure anm_shots_std_patch();stdcall;
asm
    push 0                  //забиваем место под название анимы
    pushad
    pushfd
    push 1
    push esi
    call anm_shots_selector  //получаем строку с именем анимы
    mov ecx, [esp+$28]      //запоминаем адрес возврата
    mov [esp+$28], eax      //кладем на его место результирующую строку
    mov [esp+$24], ecx      //перемещаем адрес возврата на 4 байта выше в стеке
    popfd
    popad
    ret
end;

//---------------------------------------------------------anm_reload------------------------------------------------
procedure OnAmmoTimer(wpn:pointer; param:integer);stdcall;
var
  hud_sect:PChar;
begin
  //TODO: предусмотреть механизм разряжания оружия при неоконченной аниме
  if (GetCurrentState(wpn)=7) and (GetActor()<>nil) and (GetOwner(wpn)=GetActor()) and (leftstr(GetCurAnim(wpn), length('anm_reload'))='anm_reload') then begin
    hud_sect:=GetHUDSection(wpn);
    GetBuffer(wpn).SetReloaded(false);
    CWeaponMagazined__OnAnimationEnd_DoReload(wpn);
    GetBuffer(wpn).SetReloaded(true);
    MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_end_'+GetCurAnim(wpn)));
  end;
end;

function anm_reload_selector(wpn:pointer):pchar;stdcall;
var
  hud_sect:PChar;
  actor:pointer;
  buf:WpnBuf;
  v:FVector3;
begin
  hud_sect:=GetHUDSection(wpn);
  anim_name:='anm_reload';
  actor:=GetActor();
  buf:=GetBuffer(wpn);

  if buf=nil then begin
    log('anm_reload_selector: buf=nil!!! wpn '+GetClassName(wpn)+', '+GetSection(wpn)+', state='+inttostr(GetCurrentState(wpn)), true);
    result:=PChar(anim_name);
    exit;
  end;

  if not IsBM16(wpn) then begin
    buf.ammo_cnt_to_reload:=-1;
  end else begin
    buf.ammo_cnt_to_reload:=2; //не более 2х
  end;

  //Если у нас владелец - не актор, то и смысла работать дальше нет
  if (actor<>nil) and (actor=GetOwner(wpn)) then begin
    //----------------------------------Модификаторы состояния оружия----------------------------------------------------
    anim_name:=anim_name + GetFireModeStateMark(wpn);
    if IsWeaponJammed(wpn) then begin
      anim_name:=anim_name+'_jammed';
      if GetAmmoInMagCount(wpn)=0 then anim_name:=anim_name+'_last';
      SetAmmoTypeChangingStatus(wpn, $FF);
    end else if GetAmmoInMagCount(wpn)<=0 then begin
      if not IsBM16(wpn) then begin
        anim_name:=anim_name+'_empty'; //у двустволок и так _0 потом модификатор прибавит
      end else if(CWeapon__GetAmmoCount(wpn, GetAmmoTypeToReload(wpn))<2) then begin
        if GetAmmoTypeChangingStatus(wpn)=$FF then begin
          anim_name:=anim_name+'_only';
        end else begin
          anim_name:=anim_name+'_only_ammochange';
        end;
        buf.ammo_cnt_to_reload:=1;
      end;
    end else if GetAmmoTypeChangingStatus(wpn)<>$FF then begin
      anim_name:=anim_name+'_ammochange';
      if IsBM16(wpn) and (CWeapon__GetAmmoCount(wpn, GetAmmoTypeToReload(wpn))<2) then begin
        anim_name:=anim_name+'_only';
        buf.ammo_cnt_to_reload:=1;      
      end;
    end;

    if IsHolderHasActiveDetector(wpn) and game_ini_line_exist(hud_sect, PChar(anim_name+'_detector')) then begin
       //log ('det+rel');
      anim_name:=anim_name+'_detector';
    end;

    if game_ini_r_bool_def(hud_sect, PChar('immediate_unhide_'+anim_name), false) then begin
      //если выставлен такой параметр - не надо проигрывать аниму преддоставания детектора, тупо достаем его после окончания анимы (?)
      SetActorActionState(actor, actShowDetectorNow, true);
    end;

    ModifierGL(wpn, anim_name);
  end;

  ModifierBM16(wpn, anim_name);

  StartCompanionAnimIfNeeded(rightstr(anim_name, length(anim_name)-4), wpn, false);

  if game_ini_line_exist(hud_sect, PChar(anim_name+'_noscope')) then begin
    //кастомная анимация перезарядки при отсутсвующем прицеле
    if (GetScopeStatus(wpn)<>2) or not IsScopeAttached(wpn) then
      anim_name:=anim_name+'_noscope';
  end;
  
  if not game_ini_line_exist(hud_sect, PChar(anim_name)) then begin
    log('Section ['+hud_sect+'] has no motion alias defined ['+anim_name+']');
    if IsDebug then Messenger.SendMessage('Animation not found, see log!');
    anim_name:='anm_reload';
    ModifierBM16(wpn, anim_name);
  end;
  result:=PChar(anim_name);

  if buf <> nil then buf.SetReloaded(false);
  if game_ini_line_exist(hud_sect, PChar('lock_time_start_'+anim_name)) then begin
    MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_start_'+anim_name), false, OnAmmoTimer);
    //log('lock-start, anm = '+anim_name);
  end else begin
    MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_'+anim_name));
  end;

  if ReadActionDOFVector(wpn, v, anim_name, true) then begin
    SetDOF(v, ReadActionDOFSpeed_In(wpn, anim_name));
  end;

  PlaySoundByAnimName(wpn, result);
end;


function anm_reload_g_selector(wpn:pointer):pchar;stdcall;
var
  hud_sect:PChar;
  actor:pointer;
  snd:string;
  buf:WpnBuf;
  v:FVector3;
begin
  hud_sect:=GetHUDSection(wpn);
  anim_name:='anm_reload';
  actor:=GetActor();
  buf:=GetBuffer(wpn);
  snd := 'sndLoadGrenade';
  //Если у нас владелец - не актор, то и смысла работать дальше нет
  if (actor<>nil) and (actor=GetOwner(wpn)) then begin
    //----------------------------------Модификаторы состояния оружия----------------------------------------------------
    anim_name:=anim_name + GetFireModeStateMark(wpn);

    if IsWeaponJammed(wpn) then begin
      anim_name:=anim_name+'_jammed';
    end else if (GetAmmoInMagCount(wpn)<=0) then begin
      anim_name:=anim_name+'_empty';
    end;   

    if (GetCurrentAmmoCount(wpn)>0) and  (GetAmmoTypeChangingStatus(wpn)<>$FF) then begin
      anim_name:=anim_name+'_ammochange';
      snd:='sndChangeGrenade';
    end;

    if IsHolderHasActiveDetector(wpn) and game_ini_line_exist(hud_sect, PChar(anim_name+'_detector')) then begin
      //log ('det+rel');
      anim_name:=anim_name+'_detector';
      snd:=snd+'Detector';
    end;

    if game_ini_line_exist(hud_sect, PChar('immediate_unhide_'+anim_name)) and game_ini_r_bool(hud_sect, PChar('immediate_unhide_'+anim_name)) then begin
      //если выставлен такой параметр - не надо проигрывать аниму преддоставания детектора, тупо достаем его после окончания анимы (?)
      SetActorActionState(actor, actShowDetectorNow, true);
    end;


    ModifierGL(wpn, anim_name);
    //назначим аниму детектору при необходимости
    StartCompanionAnimIfNeeded(rightstr(anim_name, length(anim_name)-4), wpn, false);
  end;

  if not game_ini_line_exist(hud_sect, PChar(anim_name)) then begin
    log('Section ['+hud_sect+'] has no motion alias defined ['+anim_name+']');
    if IsDebug then Messenger.SendMessage('Animation not found, see log!');
    anim_name:='anm_reload';
    ModifierBM16(wpn, anim_name);
  end;
  result:=PChar(anim_name);

  if not PlaySoundByAnimName(wpn, anim_name) then CHudItem_Play_Snd(wpn, PChar(snd));


  if ReadActionDOFVector(wpn, v, anim_name, true) then begin
    SetDOF(v, ReadActionDOFSpeed_In(wpn, anim_name));
  end;

  if buf <> nil then buf.SetReloaded(false);
  if game_ini_line_exist(hud_sect, PChar('lock_time_start_'+anim_name)) then begin
    MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_start_'+anim_name), false, OnAmmoTimer);
    //log('lock-start, anm = '+anim_name);
  end else begin
    MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_'+anim_name));
  end;
end;


procedure anm_reload_std_patch();stdcall;
begin
  asm
    push 0                  //забиваем место под название анимы
    pushad
    pushfd
    push esi
    call anm_reload_selector  //получаем строку с именем анимы
    mov ecx, [esp+$28]      //запоминаем адрес возврата
    mov [esp+$28], eax      //кладем на его место результирующую строку
    mov [esp+$24], ecx      //перемещаем адрес возврата на 4 байта выше в стеке
    popfd
    popad
    ret
  end;
end;


procedure anm_reload_g_std_patch();stdcall;
const anm_reload_g:PChar = 'anm_reload';
begin
  asm
    push 0                  //забиваем место под название анимы
    pushad
    pushfd
//    push anm_reload_g
    push esi
//    call anm_std_selector  //получаем строку с именем анимы
    call anm_reload_g_selector
    mov ecx, [esp+$28]      //запоминаем адрес возврата
    mov [esp+$28], eax      //кладем на его место результирующую строку
    mov [esp+$24], ecx      //перемещаем адрес возврата на 4 байта выше в стеке
    popfd
    popad
    ret
  end;
end;
//--------------------------------------------Фикс для перехода анимаций подствола------------------------------
procedure GrenadeLauncherBugFix(); stdcall;
asm
    //Заменяем один аргумент в стеке
    mov [esp+4], 1
    // делаем вырезанное
    mov ecx, [esp]
    push ecx
    lea ecx, [esp+$1C];
    mov [esp+4], ecx
end;

procedure GrenadeAimBugFix(); stdcall;
asm
    //Заменяем один аргумент в стеке
    mov [esp+4], 1
    // делаем вырезанное
    mov ecx, [esp]
    push ecx
    lea ecx, [esp+$18];
    mov [esp+4], ecx
end;
//---------------------------------Фикс для недопущения расклинивания при перезарядке подствола-----------------------
procedure JammedBugFix(); stdcall;
asm
    //cmp byte ptr [esi+$7f8], 1
    pushad
      push esi
      call IsGrenadeMode
      cmp al, 1
    popad
    je @finish
    mov [esi+$45a], 0
    @finish:
end;
//------------Фикс для перезарядки - чтобы он даже не пытался перезарядиться когда не надо------

function CanReloadNow(wpn:pointer):boolean; stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if (buf<>nil) and (buf.GetLastShotTimeDelta()<floor(buf.GetLastRechargeTime()*1000)) then begin
    result:=false;
  end else begin
    result:=Weapon_SetKeyRepeatFlagIfNeeded(wpn, kfRELOAD);
  end;
end;

procedure ReloadAnimPlayingPatch; stdcall;
asm
    pushad
      push esi
      call CanReloadNow
      cmp al, 1
    popad
    jne @finish

    mov edx, [esi]
    mov eax, [edx+$188]
    mov ecx, esi
    call eax
    @finish:
    ret
end;

function CanAmmoChangeNow(wpn:pointer):boolean; stdcall;
begin
    result:=Weapon_SetKeyRepeatFlagIfNeeded(wpn, kfNEXTAMMO);
end;

procedure AmmoChangePlayingPatch; stdcall;
asm
    test bl, 01
    jne @cmd_start
    mov eax, 0
    ret 4


    @cmd_start:

    pushad
//      push 0
      push esi
      call CanAmmoChangeNow //WeaponAdditionalBuffer.CanStartAction
      cmp al, 1
    popad
    mov eax, 1
    jne @finish

    mov eax, xrgame_addr
    add eax, $2bdcd0
    push [esp+4]
    call eax

    @finish:
    ret 4
end;
//--------------------------Аналогичный фикс для аним переключения режимов подствола----------------------------------
//Выставляем состояние идла вручную и сразу
//чтобы не было переназначения анимы идла
procedure CWeaponMagazined__OnStateSwitch_Patch; stdcall;
asm
    lea esi, [esi-$2e0];
    mov [esi+$2e8], 0
    mov [esi+$2e4], 0
    ret
end;

function CanSwitchGL(wpn:pointer):boolean; stdcall;
var
  gl_status:cardinal;
begin
  gl_status:=GetGLStatus(wpn);
  if (gl_status=0) or ((gl_status=2) and not (IsGLAttached(wpn))) then begin
    result:=false;
  end else begin
    result:=Weapon_SetKeyRepeatFlagIfNeeded(wpn,kfGLAUNCHSWITCH);
  end;
end;

//а этот -  не дает переключаться, когда не надо
procedure CWeaponMagazined__Action_Patch; stdcall;
asm
    pushad
      push esi
      call WeaponEvents.CanSwitchGL
      cmp al, 0
    popad
    je @finish
    lea ecx, [esi+$2E0]
    push $0A
    call edx  
    @finish:
end;

//-----------------------------------------Проверка на необходимость назначения идла----------------------------------
function CanReAssignIdleNow(CHudItem:pointer):boolean; stdcall;
var
  act, wpn:pointer;
  state:cardinal;
  iswpnthrowable, is_bino, canshoot:boolean;
begin
  result:=true;
  if WpnIsDetector(CHudItem) then begin
    act:=GetActor();
    if (act<>nil) and (GetOwner(CHudItem)=act) then begin
      wpn:=GetActorActiveItem();
      if wpn<>nil then begin
        iswpnthrowable:=IsThrowable(wpn);
        canshoot:=WpnCanShoot(wpn);
        is_bino:=IsBino(wpn);
        state:=GetCurrentState(wpn);

        if (iswpnthrowable and ((state=EMissileStates__eReady) or (state=EMissileStates__eThrowStart) or (state=EMissileStates__eThrow) or (state=EMissileStates__eThrowEnd))) then begin
          result:=false;
        end else if canshoot or is_bino then begin
          if IsAimNow(wpn) or IsHolderinAimState(wpn) then result:=false;
        end;
      end;
    end;
  end;
end;


procedure CHudItem__OnMovementChanged_Patch(); stdcall;
asm
  pushad
    sub esi, $2e0
    push esi
    call CanReAssignIdleNow
    cmp al, 0
  popad
  je @finish
    mov eax, [esi]
    mov edx, [eax+$60]
    call edx  // --> this->PlayAnimIdle()
    mov eax, xrgame_addr
    mov eax, [eax+$512bcc]    //CRenderDevice* Device
    mov ecx, [eax+$28]
    mov [esi+$10], ecx
  @finish:
  ret
end;


//-----------Фикс для idle_slow - чтобы двиг назначал анимацию после перехода из быстрого шага в медленный и т.п.-----
function NeedAssignAnim(act:pointer):boolean; stdcall;
begin
  result:=false;
  if GetActorActionState(act, actMovingForward)<>GetActorActionState(act, actMovingForward, mState_OLD)
    or GetActorActionState(act, actMovingBack)<>GetActorActionState(act, actMovingBack, mState_OLD)
    or GetActorActionState(act, actMovingLeft)<>GetActorActionState(act, actMovingLeft, mState_OLD)
    or GetActorActionState(act, actMovingRight)<>GetActorActionState(act, actMovingRight, mState_OLD)
    or GetActorActionState(act, actCrouch)<>GetActorActionState(act, actCrouch, mState_OLD)
    or GetActorActionState(act, actSlow)<>GetActorActionState(act, actSlow, mState_OLD)
  then begin
    result:=true;
  end;
end;

function CheckForceMoveReassign():boolean; stdcall;
var
  act:pointer;
begin
  result:=false;
  act:=GetActor;
  if act=nil then exit;
  result:=GetActorActionState(act, actModNeedMoveReassign);
  if result then SetActorActionState(act, actModNeedMoveReassign, false);
end;

procedure IdleSlowFixPatch(); stdcall;
begin
  asm
    //делаем вырезанное сравнение
    and eax, $0F
    cmp [esp+$2C], eax
    //если и так надо назначать новую аниму - ничего сами не делаем 
    jne @finish
    //Двиг сам не собирается назначать новую аниму движения... Посмотрим, не назначить ли НАМ её.
    push eax
    push ebx

    mov eax, [ebx+$590]
    mov ebx, [ebx+$594]
    and eax, $0000003F
    and ebx, $0000003F
    cmp eax, ebx

    pop ebx
    pop eax

    jne @already_need_updating

    pushad
      call CheckForceMoveReassign
      cmp al, 0
    popad

    @already_need_updating:

{    pushad
      push ebx
      call NeedAssignAnim //BUG IN THIS FUNCTION!!!
      cmp al, 0
    popad  }
    
    @finish:
    ret
  end;
end;
//-------------------------------Не даем назначить bore-------------------------------------
procedure BoreAnimLockFix; stdcall;
begin
  asm
    pushad
      sub esi, $2e0
      push esi
      call WeaponAdditionalBuffer.CanBoreNow
      cmp al, 1
    popad
    je @finish
    mov eax, 0
    cmp [esi-$2e0+$2e4], 4
    jne @finish
    cmp [esi-$2e0+$2e8], 4
    jne @finish
    mov [esi-$2e0+$2e4], 0
    mov [esi-$2e0+$2e8], 0
    @finish:
    not edx
    test dl, 01
    ret;
  end;
end;
//---------------------------------Не даем прятать оружие при активном локе у него------------------------------------
procedure HideAnimLockFix; stdcall;
begin
  asm
    lea ecx, [esi-$2e0]
    pushad
      push ecx
      call WeaponEvents.OnWeaponHide
      cmp al, 1
    popad
    je @no_lock
    mov [esi-$2e0+$2e4], 0
    mov [esi-$2e0+$2e8], 0
    ret
    @no_lock:
    call eax
    ret;
  end;
end;


procedure HideAnimLockFix_Knife; stdcall;
asm
    lea ecx, [esi-$2e0]
    pushad
      push ecx
      call OnWeaponHide
      cmp al, 1
    popad
    je @no_lock
    mov [esi-$2e0+$2e4], 05
    mov [esi-$2e0+$2e8], 05
    ret
    @no_lock: 
    call edx
    ret;
end;

procedure IdleStoppingSuicideLockFix_Knife; stdcall;
asm
    lea ecx, [esi-$2e0]
    pushad
      push ecx
      call IsSuicideAnimPlaying
      cmp al, 0
    popad
    je @no_lock
      pushad
        and byte ptr [esi+$14], $FE //SetPending(false)
        mov ecx, esi
        mov eax, xrgame_addr
        add eax, $2D5C50
        push 05
        call eax
      popad
    ret
    @no_lock:
    call edx
    ret;
end;
//------------------------------------------Отключаем стрельбу с подствола при локе-----------------------------------
procedure ShootGLAnimLockFix; stdcall;  //OLD - now rewritten the whole block (see WeaponEvents)
begin
  asm
    pushad
      push esi
      call WeaponAdditionalBuffer.OnShoot_CanShootNow
      cmp al, 1
    popad
    je @nolock
    //У нас лок - уходим отсюда и из вызвавшей нас процедуры
    xor al, al
    pop edi     //забываем текущий адрес возврата
    pop edi
    pop esi
    ret 8

    @nolock:
    cmp [esi+$690], 0
    ret
  end;
end;

//---------------------------------------Не даем прицелиться при локе-------------------------------------------------
procedure AimAnimLockFix; stdcall;
asm
    push eax
    //Установить ZF=0, если целиться не можем
    cmp byte ptr [esi+$494], 0
    je @finish
    cmp byte ptr [esi+$496], 0
    jne @finish
    xor al, al
    pushad
      push esi
      call WeaponEvents.OnWeaponAimIn
      cmp al, 1
    popad
    jne @compare
    mov al, 1
    @compare:
    cmp al, 0
    @finish:
    pop eax
    ret
end;

//-------------------------------Не даем выйти из прицеливания раньше времени--------------------------------------
procedure AimOutLockFix; stdcall;
asm
  pushad
    push esi
    call WeaponEvents.OnWeaponAimOut
    cmp al, 0
  popad
  je @finish

    mov eax, [esi]
    mov edx, [eax+$168]
    mov ecx, esi
    call edx //wpn->OnZoomOut()
  @finish:
  ret
end;
//---------------------------------------Не даем стрелять при локе-------------------------------------------------
procedure ShootAnimLockFix; stdcall;
begin
  //выставить ZF = 1, если нельзя стрелять
  asm
    pushad
      sub esi, $338
      push esi
      call WeaponAdditionalBuffer.OnShoot_CanShootNow
      cmp al, 0
    popad
    je @finish
    cmp [esi+$358], eax
    @finish:
    ret
  end;
end;
//---------------------------------------Отучим перезаряжаться (и не только) на бегу-------------------------------------------------
function ProcessAllowSprintRequest(wpn:pointer):boolean;
var
  act:pointer;
begin
  result:=WeaponAdditionalBuffer.CanSprintNow(wpn);
  act:=GetActor();
  if not result and (act<>nil) and (act=GetOwner(wpn)) then begin
    SetActorActionState(act, actSprint, false, mState_WISHFUL);
    SetActorActionState(act, actSprint, false, mState_REAL);
    SetActorActionState(act, actSprint, false, mState_OLD);
  end;
end;

procedure SprintAnimLockFix; stdcall;
asm
    pushad
      push ecx
      call WeaponAdditionalBuffer.CanSprintNow
      cmp al, 0
    popad
    je @finish
      mov eax, [edx+$dc]
      call eax
      test al, al
    @finish:
    ret
end;
//---------------------------------------Отключение автоматической перезарядки, когда она не нужна-------------------------------------------------

procedure CWeaponMagazined__switch2_Empty_Patch(); stdcall;
asm
  pushad
    push 00
    push esi
    call virtual_CHudItem_SwitchState
  popad
  mov eax, 0
end;


procedure CWeaponMagazined__FireEnd_Patch(); stdcall;
asm
  //делаем сравнение всегда истинным
  xor esi, esi
  test esi, esi
end;

//--------------------------------------------------------------------------------------------------------------------
//Микширование аним выстрела
function NeedShootMix(wpn:pointer):boolean; stdcall;
var
  act: pointer;
  hud_sect:pchar;
  cur_anim:pchar;
begin
  result:=false;

  act:=GetActor();
  if (act=nil) or (GetOwner(wpn)<>act) then exit;
  hud_sect:=GetHUDSection(wpn);

  cur_anim:=GetActualCurrentAnim(wpn);

  if game_ini_r_bool_def(hud_sect, 'mix_shoot_after_idle', false) and (leftstr(cur_anim, length('anm_idle')) = 'anm_idle') then result:=true;
  if game_ini_r_bool_def(hud_sect, 'mix_shoot_after_reload', false) and (leftstr(cur_anim, length('anm_reload')) = 'anm_reload') then result:=true;
  if game_ini_r_bool_def(hud_sect, 'mix_shoot_after_shoot_in_queue', false) and (CurrentQueueSize(wpn)<0) and (leftstr(cur_anim, length('anm_shoot')) = 'anm_shoot') then result:=true;

end;



procedure ShootAnimMixPatch(); stdcall;
asm
  pop edx //запоминаем адрес возврата, про регистр не беспокоимся

  mov ecx, [esi+$2e4] //оригинальный вырезанный код
  push ecx
  push edi

  pushad
    push esi
    call NeedShootMix
    cmp al, 0
  popad
  je @nomix

  push 1
  jmp @finish

  @nomix:
  push 0

  @finish:
  push edx
  ret
end;

//----------------------------Общий фикс многократного сокрытия при беспорядочной смене слотов-------------------------
function MultiHideFix_IsHidingNow(wpn:pointer): boolean; stdcall;
begin
  if (GetActor()<>nil) and (GetActor()=GetOwner(wpn)) and (cardinal(GetCurrentState(wpn))=EHudStates__eHiding) and (GetAnimTimeState(wpn, ANM_TIME_CUR)<GetAnimTimeState(wpn, ANM_TIME_END))  and (leftstr(GetActualCurrentAnim(wpn), length('anm_hide')) = 'anm_hide') then
    result:=true
  else
    result:=false;
end;

procedure MultiHideFix(); stdcall;
asm
  //Посмотрим, какая анима сейчас играется
  //Если уже убирание - то забываем про аргументы процедуры, если еще нет - то вызовем убирание.

  //поместим адрес возврата над аргументами CHudItem::PlayHUDMotion
  push [esp]
  push eax
  push ebx
  mov eax, [esp+$c] //ret addr
  mov ebx, [esp+$1c] // arg4
  mov [esp+$1c], eax   // ret --> arg4
  mov eax, [esp+$18] //arg3
  mov [esp+$18], ebx // arg4-->arg3
  mov ebx, [esp+$14] //arg2
  mov [esp+$14], eax // arg3 -->arg2
  mov eax, [esp+$10] //arg1
  mov [esp+$10], ebx //arg2 --> arg1
  mov [esp+$c], eax  //arg1 --> ret
  pop ebx
  pop eax
  add esp, 4

  //смотрим, играется ли уже анима
  pushad
    sub ecx, $2e0
    push ecx
    call MultiHideFix_IsHidingNow
    test eax, eax
  popad
  jne @already_playing_anim

  mov eax, xrgame_addr
  add eax, $2F9A60// CHudItem::PlayHUDMotion
  call eax

  jmp @finish
  @already_playing_anim:
  //играть не надо, снимаем аргументы
  add esp, $10
  @finish:
end;

//---------------------------------------Фикс преждевременного прекращения анимации стрельбы---------------------------
//Предотвращает назначение анимации идла в CWeaponMagazined::OnStateSwitch, если предыдущая анимация из разряда "стрельбовых" и в MotionDef не null

function CanAssignIdleAnimNow(wpn:pointer):boolean; stdcall;
const
  anm:string = 'anm_shoot';
begin
  result := ((GetAimFactor(wpn)>0.001) and (GetAimFactor(wpn)<0.999)) or (GetCurrentMotionDef(wpn)=nil) or (leftstr(GetActualCurrentAnim(wpn), length(anm))<>anm);
end;

procedure CWeaponMagazined__OnStateSwitch_IdlePatch(); stdcall;
asm
  pushad
    push ecx
    call CanAssignIdleAnimNow
    cmp al, 0
  popad
  
  je @finish
    call edx
  @finish:
  pop edi
  pop esi
  pop ebx
  ret 4
end;

//---------------------Возможность открытия стрельбы до окончания анимации перезарядки------------------------------------------
function CWeapon__Action_PrepareEarlyShotInReload(wpn:pointer):boolean; stdcall;
var
  buf:WpnBuf;
begin
  result:=false;
  buf:=GetBuffer(wpn);
  if buf=nil then exit;

  if not IsReloaded(wpn) and not IsTriStateReload(wpn) then begin
    CWeaponMagazined__OnAnimationEnd_DoReload(wpn);
    SetReloaded(wpn, true);
  end;

  if GetCurrentAmmoCount(wpn)<=0 then exit;
  buf.SetLockTime(0);
  EndPending(wpn);

  result:=true;
end;


procedure CWeapon__Action_kWPNFire_Patch(); stdcall;
asm
  pushad
    push esi
    push esi
    call OnActWhileReload_CanActNow
    pop esi

    cmp al, 0
    je @no_act
      push esi
      call CWeapon__Action_PrepareEarlyShotInReload
    @no_act:
    cmp al, 1
  popad

  je @finish
  test byte ptr [esi+$2F4], 01
  @finish:
end;

procedure CWeaponMagazined__FireStart_EarlyReloadShot(); stdcall;
asm
  mov eax, [esi-$54]
  cmp eax, 07
  jne @finish

  pushad
    sub esi, $338
    push esi
    call OnActWhileReload_CanActNow
    cmp al, 0      
  popad
  je @finish

  pushad
    sub esi, $338
    push esi
    call CWeapon__Action_PrepareEarlyShotInReload
    cmp al, 0
  popad


  @finish:
end;

function IsCustomIdleAnimNow(anm:pshared_str):boolean; stdcall;
var
  n:PChar;
begin
  n:=get_string_value(anm);
  result := (leftstr(n, length('anm_idle'))<>'anm_idle') or (leftstr(n, length('anm_idle_aim'))='anm_idle_aim') or (leftstr(n, length('anm_idle_sprint'))='anm_idle_sprint');
end;

procedure player_hud__OnMovementChanged_stopmove_patch; stdcall;
asm
  //оригинальный код
  mov ecx, [eax+04]
  cmp dword ptr [ecx+04], 00

  //если мы не собираемся останавливать аниму - то ничего не меняется
  jne @finish
  
  //проверяем, играем ли мы кастомную аниму
  pushad
    lea ecx, [ecx+$1C]// shared_str
    push ecx
    call IsCustomIdleAnimNow
    cmp al, 0
  popad

  @finish:
end;


procedure StopQueueIfNeeded(wpn:pointer); stdcall;
var
  maxq:integer;
begin
  maxq:=game_ini_r_int_def(GetSection(wpn), 'max_queue_size', 0);
  maxq:=FindIntValueInUpgradesDef(wpn, 'max_queue_size', maxq);
  if (maxq<>0) and (QueueFiredCount(wpn)>=maxq) then begin
    SetWorkingState(wpn, false);
  end;
end;

procedure CWeaponMagazined__state_Fire_queue_Patch; stdcall;
asm
  pushad
  push esi
  call StopQueueIfNeeded
  popad
  mov edx, [eax+$1f8] //original
end;

/////////////////////////////////////
function Init:boolean;
var
  buf:byte;
begin
  result:=false;

  movreass_remain_time:=0;
  movreass_last_update:=0;

  //отключим звук движкового удара ножом, т.к. теперь полностью контролируем его в WeaponEvents.OnKnifeKick
  nop_code(xrGame_addr+$2d7503, 8);

  //аналогично, отключим звук движкового bore в CHudItem::OnStateSwitch
  nop_code(xrGame_addr+$2f9efb, 1);
  nop_code(xrGame_addr+$2f9efc, 1, CHR($E9));

  //фиксим баг (мгновенная смена) с анимой подствола
  jump_addr:=xrGame_addr+$2D33B9;
  if not WriteJump(jump_addr, cardinal(@GrenadeLauncherBugFix), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D332D;
  if not WriteJump(jump_addr, cardinal(@GrenadeLauncherBugFix), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D3271;
  if not WriteJump(jump_addr, cardinal(@GrenadeAimBugFix), 5, true) then exit;
  //теперь очередь бага с расклиниванием
  jump_addr:=xrGame_addr+$2D0F2C;
  if not WriteJump(jump_addr, cardinal(@JammedBugFix), 7, true) then exit;

  //Фикс миксовки релоада грены
  if not nop_code(xrGame_addr+$2D1E63, 1, CHR(1)) then exit;
  //переключение на грену
  if not nop_code(xrGame_addr+$2D19F1, 1, CHR(1)) then exit;
  if not nop_code(xrGame_addr+$2D1A2A, 1, CHR(1)) then exit;
  //микс выстрела с подствола
  if not nop_code(xrGame_addr+$2D1943, 1, CHR(1)) then exit;
  //микс выстрела с РПГ
  if not nop_code(xrGame_addr+$2D9518, 1, CHR(1)) then exit;  

  //Баг с повторением анимации сокрытия
  jump_addr:=xrGame_addr+$2D1860; //CWeaponMagazinedWGrenade
  if not WriteJump(jump_addr, cardinal(@MultiHideFix), 5, true) then exit;
  jump_addr:=xrGame_addr+$2CCF78; //CWeaponMagazined
  if not WriteJump(jump_addr, cardinal(@MultiHideFix), 5, true) then exit;
  jump_addr:=xrGame_addr+$2C552F; //CWeaponPistol
  if not WriteJump(jump_addr, cardinal(@MultiHideFix), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D4FED; //CWeaponKnife
  if not WriteJump(jump_addr, cardinal(@MultiHideFix), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E3A89; //артефакты
  if not WriteJump(jump_addr, cardinal(@MultiHideFix), 5, true) then exit;
  jump_addr:=xrGame_addr+$2C7649; //CMissile
  if not WriteJump(jump_addr, cardinal(@MultiHideFix), 5, true) then exit;
  jump_addr:=xrGame_addr+$2F38F3; //Flare
  if not WriteJump(jump_addr, cardinal(@MultiHideFix), 5, true) then exit;
  //CWeaponBM16 x 3
  jump_addr:=xrGame_addr+$2e036e;
  if not WriteJump(jump_addr, cardinal(@MultiHideFix), 5, true) then exit;
  jump_addr:=xrGame_addr+$2e03aa;
  if not WriteJump(jump_addr, cardinal(@MultiHideFix), 5, true) then exit;
  jump_addr:=xrGame_addr+$2e03e6;
  if not WriteJump(jump_addr, cardinal(@MultiHideFix), 5, true) then exit;

  //Не дадим прерывать анимацию выстрела при назначении идла
  jump_addr:=xrGame_addr+$2D0209;
  if not WriteJump(jump_addr, cardinal(@CWeaponMagazined__OnStateSwitch_IdlePatch), 8, false) then exit;

  //Не дадим перезаряжаться 
  jump_addr:=xrGame_addr+$2CE821;
  if not WriteJump(jump_addr, cardinal(@ReloadAnimPlayingPatch), 12, true) then exit;

//----------------------------------------------------------
  //Отключим автоматическую перезарядку, когда она не нужна
  jump_addr:=xrGame_addr+$2D07BF;
  if not WriteJump(jump_addr, cardinal(@CWeaponMagazined__switch2_Empty_Patch), 5, true) then exit;

  jump_addr:=xrGame_addr+$2CFFBE;
  if not WriteJump(jump_addr, cardinal(@CWeaponMagazined__FireEnd_Patch), 7, true) then exit;

//  if not nop_code(xrGame_addr+$2D3ACE, 10) then exit; //Этот блок кода в CWeaponMagazinedWGrenade полностью переписан при работе над подстволом

  //CWeaponMagazinedWGrenade::OnAnimationEnd - отключаем релоад после стрельбы
  if not nop_code(xrGame_addr+$2D15D2, 2) then exit;
//----------------------------------------------------------

  jump_addr:=xrGame_addr+$2becd9;
  if not WriteJump(jump_addr, cardinal(@AmmoChangePlayingPatch), 5, true) then exit;


  //аналогично с переключениями на подствол и обратно
  jump_addr:=xrGame_addr+$2D1545;
  if not WriteJump(jump_addr, cardinal(@CWeaponMagazined__OnStateSwitch_Patch), 10, true) then exit;

  jump_addr:=xrGame_addr+$2D3B26;
  if not WriteJump(jump_addr, cardinal(@CWeaponMagazined__Action_Patch), 10, true) then exit;

  //для скуки
  jump_addr:=xrGame_addr+$2F9ED1;
  if not WriteJump(jump_addr, cardinal(@BoreAnimLockFix), 5, true) then exit;

  //для убирания
  jump_addr:=xrGame_addr+$2D02FF;
  if not WriteJump(jump_addr, cardinal(@HideAnimLockFix), 8, true) then exit;
  jump_addr:=xrGame_addr+$2D5CAC;
  if not WriteJump(jump_addr, cardinal(@HideAnimLockFix_Knife), 8, true) then exit;

  //во время суицида нож не должен переходить в идл!
  jump_addr:=xrGame_addr+$2D5C7A;
  if not WriteJump(jump_addr, cardinal(@IdleStoppingSuicideLockFix_Knife), 8, true) then exit;


  //для выстрела с подствола - код переехал в WeaponEvents
  //jump_addr:=xrGame_addr+$2D3ABE;
  //if not WriteJump(jump_addr, cardinal(@ShootGLAnimLockFix), 7, true) then exit;


  //для прицеливания (CWeapon::Action)
  jump_addr:=xrGame_addr+$2BECE4;
  if not WriteJump(jump_addr, cardinal(@AimAnimLockFix), 7, true) then exit;
  jump_addr:=xrGame_addr+$2BED9B;
  if not WriteJump(jump_addr, cardinal(@AimOutLockFix), 12, true) then exit;

  //для выстрелов (CWeaponMagazined:FireStart)
  jump_addr:=xrGame_addr+$2CFE9A;
  if not WriteJump(jump_addr, cardinal(@ShootAnimLockFix), 5, true) then exit;

  //для спринта
  jump_addr:=xrGame_addr+$26AF60;
  if not WriteJump(jump_addr, cardinal(@SprintAnimLockFix), 10, true) then exit;

  //Фиксим назначение анимы медленного идла
  jump_addr:=xrGame_addr+$2727B3;
  if not WriteJump(jump_addr, cardinal(@IdleSlowFixPatch), 7, true) then exit;

  //Для невозможности назначения новой идловой анимы детектору, когда он в состояни идла проигрывает кастомную
  jump_addr:=xrGame_addr+$2F977F;
  if not WriteJump(jump_addr, cardinal(@CHudItem__OnMovementChanged_Patch), 18, true) then exit;

  //глушим звук sndOpen у дробовиков, т.к. теперь он полностью под нашим контролем
  nop_code(xrGame_addr+$2DE6D5, 8);
  //аналогично с sndAddCartridge
  nop_code(xrGame_addr+$2DE735, 8);
  //и sndClose
  nop_code(xrGame_addr+$2DE79E, 8);

  //теперь прописываем обработчики анимаций
  jump_addr:=xrGame_addr+$2F9FBC; //anm_idle
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D33A5; //anm_idle_w_gl
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D3319;//anm_idle_g
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2c5376;//anm_idle_empty
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;

  jump_addr:=xrGame_addr+$2F9B44;//anm_idle_sprint
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D33DB; //anm_idle_sprint_w_gl
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D334F;//anm_idle_sprint_g
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2c529c;//anm_idle_sprint_empty
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;


  jump_addr:=xrGame_addr+$2F9AC4;//anm_idle_moving
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D3370;//anm_idle_moving_g
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D33FC;//anm_idle_moving_w_gl
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2C530C;//anm_idle_moving_empty
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;

  jump_addr:=xrGame_addr+$2CD013;//anm_idle_aim
  if not WriteJump(jump_addr, cardinal(@anm_idle_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D3278;//anm_idle_w_gl_aim
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D325F;//anm_idle_g_aim
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2C53DC;//anm_idle_aim_empty
  if not WriteJump(jump_addr, cardinal(@anm_idle_std_patch), 5, true) then exit;

  //idles for WP_BM16
  ///////////////////////////////////////////////////////////////////////////////////
  jump_addr:=xrGame_addr+$2E08B7;//anm_idle_0
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E088F;//anm_idle_1
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E0867;//anm_idle_2
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E0679;//anm_idle_moving_0
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E0646;//anm_idle_moving_1
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E0613;//anm_idle_moving_2
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E082D;//anm_idle_aim_0
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E0802;//anm_idle_aim_1
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E07E2;//anm_idle_aim_2
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E0759;//anm_idle_sprint_0
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E0726;//anm_idle_sprint_1
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E06F3;//anm_idle_sprint_2
  if not WriteJump(jump_addr, cardinal(@anm_idle_sub_patch), 5, true) then exit;
  ///////////////////////////////////////////////////////////////////////////////////

  jump_addr:=xrGame_addr+$2C519D;//anm_show_empty
  if not WriteJump(jump_addr, cardinal(@anm_show_sub_patch), 5, true) then exit;
{  jump_addr:=xrGame_addr+$2C75A5;//anm_show - grenades  ; moved to throwable
  if not WriteJump(jump_addr, cardinal(@anm_show_std_patch), 5, true) then exit;}
  jump_addr:=xrGame_addr+$2CCED2;//anm_show - spas12, rg6, knife
  if not WriteJump(jump_addr, cardinal(@anm_show_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D176A;//anm_show - assault
  if not WriteJump(jump_addr, cardinal(@anm_show_std_patch), 5, true) then exit;
{  jump_addr:=xrGame_addr+$2E3A2B;//anm_show - artefacts
  if not WriteJump(jump_addr, cardinal(@anm_show_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2EC9F3;//anm_show - detectors - DON'T USE IT!
  if not WriteJump(jump_addr, cardinal(@anm_show_sub_patch), 5, true) then exit;}
  jump_addr:=xrGame_addr+$2D173E;//anm_show_g
  if not WriteJump(jump_addr, cardinal(@anm_show_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D1721;//anm_show_w_gl
  if not WriteJump(jump_addr, cardinal(@anm_show_std_patch), 5, true) then exit;
  //bm16
  jump_addr:=xrGame_addr+$2E024b;
  if not WriteJump(jump_addr, cardinal(@anm_show_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E0287;
  if not WriteJump(jump_addr, cardinal(@anm_show_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E02C3;
  if not WriteJump(jump_addr, cardinal(@anm_show_std_patch), 5, true) then exit;

  //фикс миксовки у анимы доставания ружья - выключаем ее
  if not nop_code(xrGame_addr+$2E0262, 1, CHR(0)) then exit;
  if not nop_code(xrGame_addr+$2E029E, 1, CHR(0)) then exit;
  if not nop_code(xrGame_addr+$2E02DA, 1, CHR(0)) then exit;
  ///////////////////////////////////////////////////////////////////////////////////
  jump_addr:=xrGame_addr+$2C54FD;//anm_hide_empty
  if not WriteJump(jump_addr, cardinal(@anm_hide_sub_patch), 5, true) then exit;
{  jump_addr:=xrGame_addr+$2C7624;//anm_hide - grenades
  if not WriteJump(jump_addr, cardinal(@anm_hide_std_patch), 5, true) then exit;}
  jump_addr:=xrGame_addr+$2CCF42;//anm_hide - spas12, rg6
  if not WriteJump(jump_addr, cardinal(@anm_hide_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D182A;//anm_hide - assault
  if not WriteJump(jump_addr, cardinal(@anm_hide_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D4FB5;//anm_hide - knife
  if not WriteJump(jump_addr, cardinal(@anm_hide_std_patch), 5, true) then exit;
{  jump_addr:=xrGame_addr+$2E3A6D;//anm_hide - artefacts
  if not WriteJump(jump_addr, cardinal(@anm_hide_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2EC951;//anm_hide - detectors - DON'T USE IT!
  if not WriteJump(jump_addr, cardinal(@anm_hide_sub_patch), 5, true) then exit;}
  jump_addr:=xrGame_addr+$2D17FE;//anm_hide_g
  if not WriteJump(jump_addr, cardinal(@anm_hide_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D17E1;//anm_show_w_gl
  if not WriteJump(jump_addr, cardinal(@anm_hide_std_patch), 5, true) then exit;
  //bm16
  jump_addr:=xrGame_addr+$2E034B;
  if not WriteJump(jump_addr, cardinal(@anm_hide_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E0387;
  if not WriteJump(jump_addr, cardinal(@anm_hide_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E03C3;
  if not WriteJump(jump_addr, cardinal(@anm_hide_std_patch), 5, true) then exit;
  //////////////////////////////////////////////////////////////////////////////////
  jump_addr:=xrGame_addr+$2F9BC4;//anm_bore
  if not WriteJump(jump_addr, cardinal(@anm_bore_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D1A7B;//anm_bore_g
  if not WriteJump(jump_addr, cardinal(@anm_bore_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D1A99;//anm_bore_w_gl
  if not WriteJump(jump_addr, cardinal(@anm_bore_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2C5227;//anm_bore_empty
  if not WriteJump(jump_addr, cardinal(@anm_bore_edi_patch), 5, true) then exit;
  ////////////////////////////////////////////////////////////////////////////////
  jump_addr:=xrGame_addr+$2D1A05;//anm_switch
  if not WriteJump(jump_addr, cardinal(@anm_switch_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D19D0;//anm_switch_g
  if not WriteJump(jump_addr, cardinal(@anm_switch_sub_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D191C;//anm_shoot_g
  if not WriteJump(jump_addr, cardinal(@anm_shoot_g_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D1E3D;//anm_shoot_g
  if not WriteJump(jump_addr, cardinal(@anm_reload_g_std_patch), 5, true) then exit;
  ////////////////////////////////////////////////////////////////////////////////
  jump_addr:=xrGame_addr+$2C5571;//anm_shots, anm_shots_l - pistols
  if not WriteJump(jump_addr, cardinal(@anm_shots_std_patch), 14, true) then exit;
  jump_addr:=xrGame_addr+$2CD0B2;//anm_shots - other
  if not WriteJump(jump_addr, cardinal(@anm_shots_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D196C;//anm_shots_w_gl
  if not WriteJump(jump_addr, cardinal(@anm_shots_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E0151;//anm_shot_1 - BM16
  if not WriteJump(jump_addr, cardinal(@anm_shots_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2E01AF;//anm_shot_2 - BM16
  if not WriteJump(jump_addr, cardinal(@anm_shots_std_patch), 5, true) then exit;
  ////////////////////////////////////////////////////////////////////////////////
  jump_addr:=xrGame_addr+$2DE462;//anm_open
  if not WriteJump(jump_addr, cardinal(@anm_open_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2DE542;//anm_close
  if not WriteJump(jump_addr, cardinal(@anm_close_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2DE4D2;//anm_add_cartridge
  if not WriteJump(jump_addr, cardinal(@anm_add_cartridge_std_patch), 5, true) then exit;

  jump_addr:=xrGame_addr+$2CCFB2;//anm_reload
  if not WriteJump(jump_addr, cardinal(@anm_reload_std_patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2D18AB;//anm_reload_w_gl
  if not WriteJump(jump_addr, cardinal(@anm_reload_std_patch), 5, true) then exit;

  jump_addr:=xrGame_addr+$2E057C;//anm_reload_1 - BM16
  if not WriteJump(jump_addr, cardinal(@anm_reload_std_patch), 5, true) then exit;

  jump_addr:=xrGame_addr+$2E0547;//anm_reload_2 - BM16
  if not WriteJump(jump_addr, cardinal(@anm_reload_std_patch), 5, true) then exit;

  jump_addr:=xrGame_addr+$2C5451;//reload - pistols
  if not WriteJump(jump_addr, cardinal(@anm_reload_std_patch), 14, true) then exit;

  jump_addr:=xrGame_addr+$2d94f2;//reload - RPG7
  if not WriteJump(jump_addr, cardinal(@anm_reload_std_patch), 5, true) then exit;


  //микшировние выстрелов:
  //CWeaponMagazined:PlayAnimShoot
  jump_addr:=xrGame_addr+$2CD0CF;
  if not WriteJump(jump_addr, cardinal(@ShootAnimMixPatch), 10, true) then exit;
  //CWeaponPistol::PlayAnimShoot
  jump_addr:=xrGame_addr+$2C5597;
  if not WriteJump(jump_addr, cardinal(@ShootAnimMixPatch), 10, true) then exit;
  //CWeaponBM16::PlayAnimShoot
  jump_addr:=xrGame_addr+$2E016E;
  if not WriteJump(jump_addr, cardinal(@ShootAnimMixPatch), 10, true) then exit;
  jump_addr:=xrGame_addr+$2E01CC;
  if not WriteJump(jump_addr, cardinal(@ShootAnimMixPatch), 10, true) then exit;


  //ранний выстрел (до окончания анимы релоада)
  jump_addr:=xrGame_addr+$2BEC9E;
  if not WriteJump(jump_addr, cardinal(@CWeapon__Action_kWPNFire_Patch), 7, true) then exit;
  jump_addr:=xrGame_addr+$2CFE8A;
  if not WriteJump(jump_addr, cardinal(@CWeaponMagazined__FireStart_EarlyReloadShot), 6, true) then exit;


  //т.к. при открытии главного меню вызывается player_hud::OnMovementChanged(0), то наши кастомные анимы сбрасываются
  //добавляем проверку на то, не играется ли кастомная анима

  jump_addr:=xrGame_addr+$2FBA16;
  if not WriteJump(jump_addr, cardinal(@player_hud__OnMovementChanged_stopmove_patch), 6, true) then exit;
  jump_addr:=xrGame_addr+$2FBA38;
  if not WriteJump(jump_addr, cardinal(@player_hud__OnMovementChanged_stopmove_patch), 7, true) then exit;

  //принудительный сброс автоматического режима огня у оружия (сделано для гаусса - компьютер сделан на режиме автоогня, но стрелять все равно должен одиночными)
  jump_addr:=xrGame_addr+$2d06c5;
  if not WriteJump(jump_addr, cardinal(@CWeaponMagazined__state_Fire_queue_Patch), 6, true) then exit;

  result:=true;
end;


end.
