unit DetectorUtils;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

function Init:boolean;
procedure SetDetectorForceUnhide(det:pointer; status:boolean); stdcall;
function GetDetectorForceUnhideStatus(det:pointer):boolean; stdcall;
function GetDetectorFastMode(det:pointer):boolean; stdcall;
function GetActiveDetector(act:pointer):pointer; stdcall;
function CanUseDetectorWithItem(wpn:pointer):boolean; stdcall;
function GetDetectorActiveStatus(CCustomDetector:pointer):boolean; stdcall;
//procedure AssignDetectorAnim(det:pointer; anm_alias:PChar; bMixIn:boolean=true; use_companion_section:boolean=false); stdcall;
function WasLastDetectorHiddenManually():boolean; stdcall;
procedure ForgetDetectorAutoHide(); stdcall;
procedure AssignDetectorAutoHide(); stdcall;
function StartCompanionAnimIfNeeded(anim_name:string; wpn:pointer; show_msg_if_line_not_exist:boolean=true):boolean;
procedure ForceHideDetector(det:pointer); stdcall;

procedure MakeUnActive(det: pointer);stdcall;


implementation
uses BaseGameData, WeaponAdditionalBuffer, HudItemUtils, ActorUtils, Misc, sysutils, strutils, Messenger, gunsl_config, MatVectors, LightUtils, Math, ControllerMonster, UIUtils;

var
  _was_detector_hidden_manually:boolean; //должен быть всегда true, кроме случаев, когда идет быстрое использование какого-то предмета (юзейбла, грены, ножа),  не поддерживающего детектор-компаньон, а перед быстрым использованием детектор был активен и скрылся автоматом

procedure SwapAHI(ahi_c:pointer; ahi_d:pointer); stdcall;
asm
  //меняем местами player_hud_motion_container  m_hand_motions
  pushad

  mov eax, ahi_c;
  mov ebx, ahi_d;

  mov ecx, [eax+$138]
  mov edx, [ebx+$138]
  mov [eax+$138], edx
  mov [ebx+$138], ecx

  mov ecx, [eax+$13c]
  mov edx, [ebx+$13c]
  mov [eax+$13c], edx
  mov [ebx+$13c], ecx

  mov ecx, [eax+$140]
  mov edx, [ebx+$140]
  mov [eax+$140], edx
  mov [ebx+$140], ecx


  popad
end;

procedure AssignDetectorAnim(det:pointer; anm_alias:PChar; bMixIn:boolean=true; use_companion_section:boolean=false); stdcall;
var
  tmp:string;
  companion:pointer;
  section:PChar;
  ahi_d:pointer; //attachable_hud_item for detector
  ahi_c:pointer; //attachable_hud_item for companion
begin
  if (det=nil) or (GetCurrentState(det)<>EHudStates__eIdle) then exit;


  //проверяем, в руках ли этот детектор сейчас
  ahi_d:=GetAttachableHudItem(1);
  if GetCHudItemFromAttachableHudItem(ahi_d)<>det then begin
    ahi_c:=ahi_d;
    ahi_d:=GetAttachableHudItem(0);
    if GetCHudItemFromAttachableHudItem(ahi_d)<>det then exit;
  end else begin
    ahi_c:=GetAttachableHudItem(0);
  end;

  if not use_companion_section then begin
    section:=GetHUDSection(det);
  end else begin
    companion:=GetCHudItemFromAttachableHudItem(ahi_c);
    if companion=nil then exit;
    section:=GetHUDSection(companion);
  end;

  if Is16x9 then tmp:=anm_alias+'_16x9' else tmp:=anm_alias;

  if game_ini_line_exist(section, PChar(tmp)) then begin
    //подменим в нашем детекторе attachable_hud_item  m_animations детектора на компаньоновские
    if use_companion_section then SwapAHI(ahi_c, ahi_d);
    PlayHudAnim(det, PChar(anm_alias), bMixIn);
    if use_companion_section  then SwapAHI(ahi_c, ahi_d);
  end else begin
    log('Section ['+section+'] has no motion alias defined ['+tmp+']');
    if IsDebug then Messenger.SendMessage('Detector animation not found, see log!')
  end;
end;

function CanUseDetectorWithItem(wpn:pointer):boolean; stdcall;
var
  sect:PChar;
begin
  result:=true;
  if wpn=nil then exit;
  sect:=GetSection(wpn);
  if sect=nil then exit;

  result:=game_ini_r_bool_def(sect,'supports_detector', false);
  result:=FindBoolValueInUpgradesDef(wpn, 'supports_detector', result, true);
end;

function GetItemInSlotByWeapon(wpn:pointer; slot:integer):pointer; stdcall;
asm
  pushad
    mov eax, 0
    
    mov esi, wpn
    cmp esi, 0
    je @finish

    mov ecx, [esi+$8C]
    cmp ecx, 0
    je @finish

    push slot
    mov eax, xrgame_addr
    add eax, $2a7740
    call eax

    @finish:
    mov @result, eax
  popad
end;

function SelectSlotForDetector(curwpn:pointer):integer; stdcall;
var i:integer;
  wpn_in_slot:pointer;
begin
  result:=0;
  if curwpn=nil then exit;
  for i:=6 downto 1 do begin
    wpn_in_slot:=GetItemInSlotByWeapon(curwpn, i);
    if wpn_in_slot<>nil then begin
      if CanUseDetectorWithItem(wpn_in_slot) then begin
        result:=i;
        exit;
      end;
    end;
  end;
end;

function ParseDetector(wpn:pointer; slot:pinteger): boolean; stdcall;
//заменяем стандартную функцию, решающую, можно ли сейчас использовать детектор
//возвращаем false - вообще даже не пытаемся доставать детектор
//возвращаем true и ^slot = 0 - достает детектор, не меняя оружия
//возвращаем true и ^slot<>0 - сначала меняет слот на указанный, затем достает детектор
var
  state:integer;
begin
  if CanUseDetectorWithItem(wpn) then begin
    result:=true;
    if slot<>nil then slot^:=0;
  end else if slot<>nil then begin
    slot^:=SelectSlotForDetector(wpn);
    if slot^=0 then result:=false else result:=true;
  end else begin
    result:=false;
  end;

  if (not result) or (not WpnCanShoot(wpn)) then exit;
  state:=GetCurrentState(wpn);
  if (state=4) or (state=7) or (state=$A) or IsAimNow(wpn) then result:=false;
end;

procedure CanUseDetectorPatch; stdcall;
//патчит CCustomDetector::CheckCompatibility
//последний в свою очередь вызывается, когда мы нажимаем кнопку на смену оружия
asm
  push ebp
  mov ebp, esp
  mov eax, 1

  pushad
    mov eax, [ebp+$8]
    test eax, eax
    je @nowpn

    mov eax, [eax+$54]
    test eax, eax
    je @nowpn
    
    push [ebp+$c]
    push eax
    call ParseDetector
    cmp al, 1
    
    @nowpn:
  popad

  je @finish
  mov eax, 0

  @finish:
  pop ebp
  ret 8;
end;



function CanShowDetector():boolean; stdcall;
var
  itm:pointer;
  param:string;
begin
  itm:=GetActorActiveItem();
  result:=true;

  if itm<>nil then begin
      param := GetCurAnim(itm);
      if param = '' then param:=GetActualCurrentAnim(itm);
      param:='disable_detector_'+param;

{      if IsHolderInAimState(itm) or IsAimNow(itm) then begin
        result:=false;
      end else }if game_ini_line_exist(GetHUDSection(itm), PChar(param)) then begin
        result:=not game_ini_r_bool(GetHUDSection(itm), PChar(param));
      end else begin
        result:=true
      end;
  end;
end;

procedure HideDetectorInUpdateOnActionPatch; stdcall;
var
  itm:pointer;
asm
  //делаем вырезанное
  mov ecx, [eax+$2e4]
  //если игра уже решила скрыть детектор - то не вмешиваемся
  //отставить - перед врезаемой нами выполняется проверка на то, не находится ли оружие-компаньон в режиме прицеливания, а это мы проверим и сами.
  //jne @finish
  //Проверим, не выполняется ли какое-либо действие
  pushad
    call CanShowDetector
    cmp al, 1
  popad
  @finish:
end;

procedure UnHideDetectorInUpdateOnActionPatch; stdcall;
asm
  //делаем вырезанное
  cmp dword ptr [esi+$2e4], 3
  //если игра не решилась показать детектор - то не будем мешать
  jne @finish
  
  //Проверим, не выполняется ли какое-либо действие
  pushad
    call CanShowDetector
    cmp al, 1
  popad
  @finish:
end;

procedure OnDetectorPrepared(wpn:pointer; p:integer); stdcall;
var
  act:pointer;
  itm, det:pointer;
begin
  act:=GetActor;
  if (act=nil) or (act<>GetOwner(wpn)) then exit;

  itm:=GetActorActiveItem();
  det:=ItemInSlot(act, 9);
  if (itm <> nil) and (itm=wpn) and (det<>nil) then begin
    SetActorActionState(act, actShowDetectorNow, true);

    SetDetectorForceUnhide(det, true);
    SetActorActionState(act, actModDetectorSprintStarted, false);
    PlayCustomAnimStatic(itm, 'anm_draw_detector');
    asm
      pushad
        push 01
        mov ecx, det
        mov eax, xrGame_addr
        add eax, $2ecda0
        call eax
      popad
    end;

  end;

end;

procedure SetDetectorForceUnhide(det:pointer; status:boolean); stdcall;
asm
  cmp det, 0
  je @finish
  pushad
    mov eax, det
    movzx bx, status
    mov [eax+$33D], ebx
  popad
  @finish:
end;

procedure SetDetectorActiveStatus(det:pointer; status:boolean); stdcall;
asm
  cmp det, 0
  je @finish
  pushad
    mov eax, det
    mov bl, status
    mov [eax+$344], bl
  popad
  @finish:
end;

function GetDetectorForceUnhideStatus(det:pointer):boolean; stdcall;
asm
  mov @result, 0
  cmp det, 0
  je @finish
  pushad
    mov eax, det
    mov ebx, [eax+$33D] //m_bNeedActivation
    mov @result, bl
  popad
  @finish:
end;

function GetDetectorFastMode(det:pointer):boolean; stdcall;
asm
  mov @result, 0
  cmp det, 0
  je @finish
  pushad
    mov eax, det
    mov ebx, [eax+$33C] //m_bFastAnimMode
    mov @result, bl
  popad
  @finish:
end;

function GetDetectorActiveStatus(CCustomDetector:pointer):boolean; stdcall;
asm
  mov @result, 0
  cmp CCustomDetector, 0
  je @finish
  pushad
    mov eax, CCustomDetector
    mov ebx, [eax+$344]
    mov @result, bl
  popad
  @finish:
end;

function CanShowDetectorWithPrepareIfNeeded(det:pointer):boolean; stdcall;
var
  itm, act:pointer;
  hud_sect:PChar;
begin
  result:=false;
  act:=GetActor;
  if (act = nil) then exit;
  //проверяем принципиальную возможность доставания в данный момент
  if not CanShowDetector then exit;

  //теперь смотрим, игралась ли уже вводная анимация доставания детектора
  if GetActorActionState(act, actShowDetectorNow) then begin
    result:=true;
    SetActorActionState(act, actShowDetectorNow, false);
  end else begin
    //анима не игралась. Так воспроизведем её! Если сможем...
    itm:=GetActorActiveItem();
    if (itm<>nil) and WpnCanShoot(itm) then begin
      hud_sect:=GetHUDSection(itm);
      if (game_ini_line_exist(hud_sect, 'use_prepare_detector_anim')) and (game_ini_r_bool(hud_sect, 'use_prepare_detector_anim')) then begin
        PlayCustomAnimStatic(itm, 'anm_prepare_detector', 'sndPrepareDet', OnDetectorPrepared, 0);
        SetDetectorForceUnhide(det, true); 
      end else result:=true;
    end else begin
      result:=true;
      SetActorActionState(act, actShowDetectorNow, false);
    end;
  end;
end;

procedure ShowDetectorPatch; stdcall;
asm
  //делаем вырезанное
  push ecx
  push eax
  mov ecx, esi
  mov [esp+$14], 0

  mov eax, xrgame_addr
  add eax, $2ECC40
  call eax
  test al, al
{  pushad
    call SelectActorSlotForUsingWithDetector
    cmp eax, -1
    je @detector_forbidden
    mov [esp+$2C], eax
    @detector_forbidden:
  popad}

  je @finish
  //добавляем проверку

  pushad
    push esi
    call CanShowDetectorWithPrepareIfNeeded //записать здесь в esi+$33d 1, запустив циклический анхайд
    cmp al, 0
  popad

  @finish:
end;

procedure MakeUnActive(det: pointer);stdcall;
begin
    SetDetectorActiveStatus(det,false);
    if GetCurrentState(det)<>3 then begin
      //принудительно выставим неактивное состояние
      asm
        pushad
          mov eax, det
          mov [eax+$2E4], 3
          mov [eax+$2E8], 3
        popad
      end;
    end;
end;

procedure DetectorUpdate(det: pointer);stdcall;
var
  act:pointer;
  HID:pointer;
  pos, dir, tmp, zerovec, omnidir, omnipos, aim_offset:FVector3;
  params:lefthanded_torchlight_params;
  light_time_treshold_f:single;
  light_cur_time:cardinal;
  flag:boolean;
  anm:string;
  itm:pointer;
  state:cardinal;
begin
  act:=GetActor();
  if act=nil then exit;
  if (GetOwner(det)<>act) then begin
    //[bug] BUG: Если актор выбросил активный детектор и поднял его - то этот детектор в оригинале формально находится в активном состоянии, а по факту не рисуется
    //Так что при обнаружении выбрасывания обманываем игру, выставляя неактивность детектора
    // (лучше править в OnH_A_Independent)
    MakeUnActive(det);
  end else if (GetActiveDetector(act)=det) and game_ini_r_bool_def(GetSection(det), 'torch_installed', false) then begin
    //в руках у актора фонарь
    if GetLefthandedTorchLinkedDetector()<>det then begin
      RecreateLefthandedTorch(GetSection(det), det);
      //log('light created');
    end;
    //выставляем позицию
    HID:=CHudItem__HudItemData(det);
    params:=GetLefthandedTorchParams();
    if (HID<>nil) then begin
      itm:=GetActorActiveItem();
      if (itm<>nil) and WpnCanShoot(itm) and (GetAimFactor(itm) > 0.001) then begin
        aim_offset:=params.aim_offset;
        v_mul(@aim_offset, GetAimFactor(itm));
        v_add(@params.base.offset, @aim_offset);
        v_add(@params.base.omni_offset, @aim_offset);
      end;

      attachable_hud_item__GetBoneOffsetPosDir(HID, params.base.light_bone, @pos, @dir, @params.base.offset);
      if params.base.is_lightdir_by_bone then begin
        //направление света задается через разность позиций 2х костей оружия
        zerovec.x:=0;
        zerovec.y:=0;
        zerovec.z:=0;
        attachable_hud_item__GetBoneOffsetPosDir(HID, params.base.lightdir_bone_name, @dir, @tmp, @zerovec);
        v_sub(@dir, @pos);
        v_normalize(@dir);
      end;

      attachable_hud_item__GetBoneOffsetPosDir(HID, params.base.light_bone, @omnipos, @omnidir, @params.base.omni_offset);
      SetTorchlightPosAndDir(@params.base, @pos, @dir, true, @omnipos, @dir);
    end else begin
      SetTorchlightPosAndDir(@params.base, GetPosition(det), GetOrientation(det), false)
    end;

    if (GetHudFlags() and HUD_WEAPON_RT2) = 0 then begin
      //weapon hud render is disabled - probably cut-scene, we shouldn't draw torchlight
      SwitchLefthandedTorch(false);
    end else if leftstr(GetActualCurrentAnim(det), length('anm_show'))='anm_show' then begin
      light_time_treshold_f:=game_ini_r_single_def(GetHUDSection(det), PChar('torch_enable_time_'+GetActualCurrentAnim(det)), 0)*1000;
      if light_time_treshold_f>=0 then begin
        light_cur_time:=GetTimeDeltaSafe(GetAnimTimeState(det, ANM_TIME_START), GetAnimTimeState(det, ANM_TIME_CUR));
        if light_cur_time>=light_time_treshold_f then begin
          SwitchLefthandedTorch(true);
        end else begin
          SwitchLefthandedTorch(false);
        end;
      end else begin
        light_time_treshold_f:=-1*light_time_treshold_f;
        light_cur_time:=GetTimeDeltaSafe(GetAnimTimeState(det, ANM_TIME_CUR), GetAnimTimeState(det, ANM_TIME_END));
        if light_cur_time<=light_time_treshold_f then begin
          SwitchLefthandedTorch(true);
        end else begin
          SwitchLefthandedTorch(false);
        end;
      end;
    end else if leftstr(GetActualCurrentAnim(det), length('anm_hide'))='anm_hide' then begin
      light_time_treshold_f:=game_ini_r_single_def(GetHUDSection(det), PChar('torch_disable_time_'+GetActualCurrentAnim(det)), 0)*1000;
      if light_time_treshold_f>=0 then begin
        light_cur_time:=GetTimeDeltaSafe(GetAnimTimeState(det, ANM_TIME_START), GetAnimTimeState(det, ANM_TIME_CUR));
        if light_cur_time>=light_time_treshold_f then begin
          SwitchLefthandedTorch(false);
        end else begin
          SwitchLefthandedTorch(true);
        end;
      end else begin
        light_time_treshold_f:=-1*light_time_treshold_f;
        light_cur_time:=GetTimeDeltaSafe(GetAnimTimeState(det, ANM_TIME_CUR), GetAnimTimeState(det, ANM_TIME_END));
        if light_cur_time<=light_time_treshold_f then begin
          SwitchLefthandedTorch(false);
        end else begin
          SwitchLefthandedTorch(true);
        end;
      end;
    end else begin
      SwitchLefthandedTorch(true);
    end;
  end else if GetLefthandedTorchParams().base.render<>nil then begin
    SwitchLefthandedTorch(false);
  end;

{  if (GetCurrentState(det)=EHudStates__eHiding) and (leftstr(GetActualCurrentAnim(det), length('anm_hide'))<>'anm_hide') then begin
    flag:=true;
    if GetOwner(det)=GetActor() then begin
      itm:=GetActorActiveItem();
      if itm<>nil then begin
        state:=GetCurrentState(itm);
        if (GetActorActiveSlot()<>GetActorTargetSlot()) and ((state<>EHudStates__eHidden) and (state<>EHudStates__eHiding)) and (leftstr(GetActualCurrentAnim(det), length('anm_idle'))<>'anm_idle') then begin
          flag:=false;
        end;
      end;    
    end;

    if (flag) then begin
      if GetDetectorFastMode(det) then begin
        anm:='anm_hide_fast';
      end else begin
        anm:='anm_hide';
      end;
      CHudItem_Play_Snd(det, 'sndHide');
      CHudItem__PlayHUDMotion(det, PChar(anm), true, GetCurrentState(det));
      StartPending(det);
    end;

  end;}
end;

procedure DetectorUpdatePatch();stdcall;
asm
  lea ecx, [esi+$E8];
  pushad
    push esi
    call DetectorUpdate
  popad
end;

function ReadDispersionMultiplier(wpn:pointer):single;stdcall;
var
  sect:PChar;
begin
  result:=1;
  if wpn=nil then exit;
  sect:=GetSection(wpn);
  if (sect<>nil) and (GetActorActiveItem = wpn) and (GetActiveDetector(GetActor)<>nil) then begin
    if game_ini_line_exist(sect, 'detector_disp_factor') then begin
      result:= game_ini_r_single(sect, 'detector_disp_factor')
    end;
  end;
end;

procedure WeaponDispersionPatch();stdcall;
//увеличим дисперсию оружия, если в руках детектор
asm
  mulss xmm1, [ecx+$38c]
  pushad
    push eax
    push ecx
    call ReadDispersionMultiplier
    fstp [esp]
    mulss xmm1, [esp]
    add esp, 4
  popad
end;

procedure CCustomDetector__OnAnimationEnd(det:pointer); stdcall;
var
  companion, act:pointer;
  state:cardinal;
begin
  act:=GetActor();
  if (act<>nil) and (act=GetOwner(det)) and (leftstr(GetActualCurrentAnim(det), length('anm_show'))='anm_show') and GetActorActionState(act, actModDetectorSprintStarted, mstate_REAL) and GetActorActionState(act, actSprint, mstate_REAL) then begin
    SetActorActionState(act, actModNeedMoveReassign, true);
  end;
  
  PlayAnimIdle(det);
  //PlayHudAnim(det, GetActualCurrentAnim(det), true); //для отключения микшера

  //проверка на необходимость играть идловую аниму с замахом
  if (act<>nil) and (GetOwner(det)=act) then begin
    companion:= GetActorActiveItem();
    if (companion<>nil) and IsThrowable(companion) then state:=GetCurrentState(companion) else state:=0;
    if (state<>0) and ((state=EMissileStates__eThrowStart) or (state=EMissileStates__eReady)) then begin
      AssignDetectorAnim(det, PChar(ANM_LEFTHAND+GetSection(det)+'_wpn_throw_idle'), true, true);
    end else if (leftstr(GetActualCurrentAnim(det), length('anm_idle'))='anm_idle') and GetActorActionState(act, actModDetectorSprintStarted, mstate_REAL) and GetActorActionState(act, actSprint, mstate_REAL) then begin
      SetActorActionState(act, actModNeedMoveReassign, true);
    end;
  end;
end;

procedure CCustomDetector__OnAnimationEnd_Patch(); stdcall;
asm
  pushad
    sub esi, $2e0
    push esi
    call CCustomDetector__OnAnimationEnd
  popad
  pop edi
  pop esi
  ret 4
end;



function GetActiveDetector(act:pointer):pointer; stdcall;
asm
  pushad
    push act
    call game_object_GetScriptGameObject
    cmp eax, 0
    je @null
    mov ecx, eax
    mov eax, xrGame_addr
    add eax, $1c92a0
    call eax
    cmp eax, 0
    je @null

    mov eax, [eax+4]
    cmp eax, 0
    je @null
    sub eax, $e8

    mov @result, eax

    jmp @finish

    @null:
    mov @result, 0
    jmp @finish

    @finish:
  popad
end;

function StartCompanionAnimIfNeeded(anim_name:string; wpn:pointer; show_msg_if_line_not_exist:boolean=true):boolean;
var
  det, act:pointer;
  det_anm:string;
begin
  result:=false;
  act:=GetActor();
  if (act=nil) or (act<>GetOwner(wpn)) or (wpn<>GetActorActiveItem()) then exit;

  det:=GetActiveDetector(act);

  if det<>nil then begin
    det_anm:=ANM_LEFTHAND+GetSection(det)+'_wpn_'+anim_name;
    if not show_msg_if_line_not_exist then begin
      if not game_ini_line_exist(GetHUDSection(wpn), PChar(det_anm)) then exit;
    end;

    //if (leftstr(GetActualCurrentAnim(wpn), length('anm_idle'))<>'anm_idle') or (leftstr(GetActualCurrentAnim(wpn), length('anm_idle_sprint'))<>'anm_idle_sprint') then exit;
    AssignDetectorAnim(det, PChar(det_anm), true, true);
    result:=true;
  end;
end;

procedure OnDetectorShow(det:pointer); stdcall;
begin
  if (GetActor()<>nil) and (GetOwner(det)=GetActor()) then ForgetDetectorAutoHide();
end;


procedure CCustomDetector__OnStateSwitch_Patch; stdcall;
asm
  pushad
    sub esi, $2e0
    push esi
    call OnDetectorShow
  popad
  movss [esp+$30], xmm0;
  ret
end;


procedure OnDetectorForceHiding(det:pointer); stdcall;
//вызывается при принудительном сокрытии детектора
begin
  if (GetActor()<>nil) and (GetOwner(det)=GetActor()) then _was_detector_hidden_manually:=false;
end;

procedure CCustomDetector__CheckCompatibility_Patch; stdcall;
asm
  //запоминаем, что детектор скрыт принудительно
  pushad
    push esi
    call OnDetectorForceHiding
  popad
  //делаем вырезанное
  push 01
  mov ecx, esi
  mov eax, xrgame_addr
  add eax, $2ECDA0
  call eax //CCustomDetector__ToggleDetector
  ret
end;

function WasLastDetectorHiddenManually():boolean; stdcall;
begin
  result:=_was_detector_hidden_manually;
end;

procedure AssignDetectorAutoHide(); stdcall;
begin
  _was_detector_hidden_manually:=false;
end;

procedure ForgetDetectorAutoHide(); stdcall;
begin
  _was_detector_hidden_manually:=true;
end;

procedure ForceHideDetector(det:pointer); stdcall;
begin
  if (det <> nil) and (GetActor()<>nil) and (GetOwner(det)=GetActor()) and (GetCurrentState(det)<>EHudStates__eHidden) then begin
    virtual_CHudItem_SwitchState(det, EHudStates__eHiding);
    OnDetectorForceHiding(det);
  end;
end;

function Init:boolean;
var
  jmp_addr:cardinal;
begin
  result:=false;

  ForgetDetectorAutoHide();
  
  jmp_addr:=xrGame_addr+$2ECFA1;
  if not WriteJump(jmp_addr, cardinal(@DetectorUpdatePatch), 6, true) then exit;
  jmp_addr:=xrGame_addr+$2ECDF0;
  if not WriteJump(jmp_addr, cardinal(@ShowDetectorPatch), 19, true) then exit;
  jmp_addr:=xrGame_addr+$2ECF0A;
  if not WriteJump(jmp_addr, cardinal(@HideDetectorInUpdateOnActionPatch), 6, true) then exit;
  jmp_addr:=xrGame_addr+$2ECF78;
  if not WriteJump(jmp_addr, cardinal(@UnHideDetectorInUpdateOnActionPatch), 7, true) then exit;
  jmp_addr:=xrGame_addr+$2ECC40;
  if not WriteJump(jmp_addr, cardinal(@CanUseDetectorPatch), 5, false) then exit;
  jmp_addr:=xrGame_addr+$2C2B87;
  if not WriteJump(jmp_addr, cardinal(@WeaponDispersionPatch), 8, true) then exit;
  jmp_addr:=xrGame_addr+$2ECB6F;
  if not WriteJump(jmp_addr, cardinal(@CCustomDetector__OnAnimationEnd_Patch), 5, false) then exit;

  //отключим убирание детектора при перезарядке и переключении режимов подствола
  if not nop_code(xrGame_addr+$2ECF12, 8) then exit;
  jmp_addr:=$EB;
  if not WriteBufAtAdr(xrGame_addr+$2ECF1A, @jmp_addr, 1) then exit;

  //[bug] миксовка для сокрытия детектора - включаем ее
  if not nop_code(xrGame_addr+$2EC966, 1, chr(1)) then exit;

  //отключаем назначение анимы сокрытия детектора в CCustomDetector::OnStateSwitch - оно у нас теперь идет в UpdateCL
  //jmp_addr:=xrGame_addr+$2EC8E8;
  //if not WriteJump(jmp_addr, cardinal(xrgame_addr+$2ECA3C), 6, false) then exit;

  //функции, обеспечивающие работу определения принудительного сокрытия детектора
  jmp_addr:=xrGame_addr+$2EC9CB;
  if not WriteJump(jmp_addr, cardinal(@CCustomDetector__OnStateSwitch_Patch), 6, true) then exit;

  jmp_addr:=xrGame_addr+$2ED002;
  if not WriteJump(jmp_addr, cardinal(@CCustomDetector__CheckCompatibility_Patch), 9, true) then exit;

  result:=true;
end;


end.
