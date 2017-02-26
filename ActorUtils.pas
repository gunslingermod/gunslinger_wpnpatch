unit ActorUtils;


//xrgame+4e212a - менять условия для включения коллизии

{$define USE_SCRIPT_USABLE_HUDITEMS}  //на всякий - потом все равно в двиг надо перекинуть, но влом - и так отлично работает

interface
uses LightUtils;
const
  actMovingForward:cardinal = $1;
  actMovingBack:cardinal = $2;
  actMovingLeft:cardinal = $4;
  actMovingRight:cardinal = $8;
  actCrouch:cardinal = $10;
  actSlow:cardinal = $20;
  actSprint:cardinal = $1000;
  actJump:cardinal = $80;
  actFall:cardinal = $100;
  actLanding:cardinal = $200;
  actLanding2:cardinal = $400;


  actAimStarted:cardinal = $4000000;
  actShowDetectorNow:cardinal = $8000000; //преддоставание проигралoсь, можно показывать детектор
  actModSprintStarted:cardinal = $10000000;
  actModNeedMoveReassign:cardinal = $20000000;
  actModDetectorSprintStarted:cardinal = $40000000;
  actModDetectorAimStarted:cardinal = $80000000;

  mState_WISHFUL:cardinal = $58c;
  mState_OLD:cardinal = $590;
  mState_REAL:cardinal = $594;


  kfUNZOOM:cardinal=$1;
  kfRELOAD:cardinal=$2;
  kfNEXTFIREMODE:cardinal=$8;
  kfPREVFIREMODE:cardinal=$10;
  kfGLAUNCHSWITCH:cardinal=$20;
  kfWPNHIDE:cardinal=$40;
  kfDETECTOR:cardinal=$80;
  kfZOOM:cardinal=$100;
  kfFIRE:cardinal=$200;
  kfLASER:cardinal=$400;
  kfTACTICALTORCH:cardinal=$800;
  kfNEXTAMMO:cardinal = $1000;





function GetActor():pointer; stdcall;
function GetActorTargetSlot():integer; stdcall;
function GetActorActiveSlot():integer; stdcall;
//для быстрого использования
function GetActorPreviousSlot():integer; stdcall;
procedure RestoreLastActorDetector(); stdcall;
function GetActorActionState(stalker:pointer; mask:cardinal; state:cardinal=$594):boolean; stdcall;
function GetActorActionStateInt(stalker:pointer; mask:cardinal; state:cardinal=$594):integer; stdcall;
procedure CreateObjectToActor(section:PChar); stdcall;
function IsHolderInSprintState(wpn:pointer):boolean; stdcall; //работает только для актора, для других всегда вернет false!
function IsHolderHasActiveDetector(wpn:pointer):boolean; stdcall;
function IsHolderInAimState(wpn:pointer):boolean;stdcall;
procedure SetActorActionState(stalker:pointer; mask:cardinal; set_value:boolean; state:cardinal=$594); stdcall;
function GetActorActiveItem():pointer; stdcall;
function ItemInSlot(act:pointer; slot:integer):pointer; stdcall;
procedure DropItem(act:pointer; item:pointer); stdcall;
function Init():boolean; stdcall;
function CheckActorWeaponAvailabilityWithInform(wpn:pointer):boolean;
procedure SetActorKeyRepeatFlag(mask:cardinal; state:boolean; ignore_suicide:boolean=false);
procedure ClearActorKeyRepeatFlags();
procedure ResetActorFlags(act:pointer);
procedure UpdateSlots(act:pointer);
procedure UpdateFOV(act:pointer);
function GetSlotOfActorHUDItem(act:pointer; itm:pointer):integer; stdcall;
procedure ActivateActorSlot(slot:cardinal); stdcall;
procedure ActivateActorSlot__CInventory(slot:word; forced:boolean); stdcall;
function GetActorSlotBlockedCounter(slot:cardinal):cardinal; stdcall;

procedure SetFOV(fov:single); stdcall;
function GetFOV():single; stdcall;
procedure SetHudFOV(fov:single); stdcall;

function CRenderDevice__GetCamPos():pointer;stdcall;
function CRenderDevice__GetCamDir():pointer;stdcall;
function GetTargetDist():single;stdcall;
function GetActorThirst():single;stdcall;

procedure SwitchLefthandedTorch(status:boolean); stdcall;
procedure RecreateLefthandedTorch(params_section:PChar; det:pointer); stdcall;
function GetLefthandedTorchLinkedDetector():pointer; stdcall;
function GetLefthandedTorchParams():torchlight_params; stdcall;

procedure CActor__Die(this:pointer; who:pointer); stdcall;
procedure CEntity__KillEntity(this:pointer; who:word); stdcall;

procedure CActor__set_inventory_disabled(this:pointer; status:boolean); stdcall;
function CActor__get_inventory_disabled(this:pointer):boolean; stdcall;

function CInventory__CalcTotalWeight(this:pointer):single; stdcall;
function CInventoryOwner__GetInventory(this:pointer):pointer; stdcall;


implementation
uses Messenger, BaseGameData, HudItemUtils, Misc, DetectorUtils,WeaponAdditionalBuffer, sysutils, UIUtils, KeyUtils, gunsl_config, WeaponEvents, Throwable, dynamic_caster, WeaponUpdate, ActorDOF, WeaponInertion, strutils, Math, collimator, xr_BoneUtils, ControllerMonster;

var
  _keyflags:cardinal;
  _last_act_slot:integer;
  _prev_act_slot:integer;


  _thirst_value:single;

{$ifdef USE_SCRIPT_USABLE_HUDITEMS}
  _was_unprocessed_use_of_usable_huditem:boolean;
{$endif}

  _lefthanded_torch:torchlight_params;
  _torch_linked_detector:pointer;

  _last_update_time:cardinal;


function CInventory__CalcTotalWeight(this:pointer):single; stdcall;
asm
  pushad
    mov eax, xrgame_addr
    add eax, $2A7460
    call eax
  popad
  fstp @result
end;

function CInventoryOwner__GetInventory(this:pointer):pointer; stdcall;
asm
  mov eax, this
  mov eax, [eax+$1c]
  mov @result, eax
end;

procedure CActor__set_inventory_disabled(this:pointer; status:boolean); stdcall;
asm
  push eax
  push ebx
  mov eax, this
  movzx ebx, status

  mov byte ptr [eax+$9CB], bl

  pop ebx
  pop eax
end;  


function CActor__get_inventory_disabled(this:pointer):boolean; stdcall;
asm
  mov eax, this
  movzx eax, byte ptr [eax+$9CB]
  mov @result, al
end;

function GetActor():pointer; stdcall;
begin
  asm
    mov eax, xrgame_addr
    add eax, $64e2c0;
    mov eax, [eax]
    mov @result, eax
  end;
end;

function GetActorActionState(stalker:pointer; mask:cardinal; state:cardinal=$594):boolean; stdcall;
asm
  push ecx
  push edx
  mov edx, state

  @body:
  mov ecx, mask
  mov @result, 0
  mov eax, stalker
  mov eax, [eax+edx]
  test eax, ecx
  je @finish
  mov @result, 1

  @finish:
  pop edx
  pop ecx
end;

function GetActorActionStateInt(stalker:pointer; mask:cardinal; state:cardinal=$594):integer; stdcall;
asm
  push ecx
  push edx
  mov edx, state

  @body:
  mov ecx, mask
  mov @result, 0
  mov eax, stalker
  mov eax, [eax+edx]
  and eax, ecx
  mov @result, eax


  @finish:
  pop edx
  pop ecx
end;



procedure SetActorActionState(stalker:pointer; mask:cardinal; set_value:boolean; state:cardinal=$594); stdcall;
asm
  pushad
  mov edx, state

  @body:
  mov eax, stalker
  mov ecx, mask

  cmp set_value, 0
  je @clear_flag
    or [eax+edx], ecx
    jmp @finish
  @clear_flag:
    not ecx
    and [eax+edx], ecx
  @finish:
  popad
end;

function IsActorAim(stalker:pointer):boolean; stdcall;
begin
  asm
    mov eax, stalker
    mov al, [eax+$5D4]
    mov @result, al
  end;
end;

procedure CreateObjectToActor(section:PChar); stdcall;
var act:pointer;
begin
  act:=GetActor();
  if (act=nil) then exit;

  asm
    pushad
      call alife
      
      push 0
      push 0
      push 0
      mov ecx, act
      add ecx, $80
      push ecx      //position
      push section
      push eax      //alife simulator ptr

      mov ebx, xrgame_addr
      add ebx, $99490
      call ebx      //call create

      add esp, $18
    popad
  end;
end;

procedure CEntity__KillEntity(this:pointer; who:word); stdcall;
asm
  pushad
    movzx eax, who
    push eax
    mov eax, xrgame_addr
    add eax, $2796B0
    mov ecx, this
    call eax
  popad
end;


procedure CActor__Die(this:pointer; who:pointer); stdcall;
asm
  pushad
    mov eax, xrgame_addr
    add eax, $261700
    mov ecx, this
    push who
    call eax
  popad
end;

function IsHolderInSprintState(wpn:pointer):boolean;stdcall;
var actor:pointer;
    holder:pointer;
begin
  holder:=GetOwner(wpn);
  actor:=GetActor();
  if (actor<>nil) and (actor=holder) and (GetActorActionState(holder, actSprint) or GetActorActionState(holder, actModSprintStarted)) then begin
    result:=true;
  end else
    result:=false;
end;

function IsHolderInAimState(wpn:pointer):boolean;stdcall;
var actor:pointer;
    holder:pointer;
begin
  holder:=GetOwner(wpn);
  actor:=GetActor();
  if (actor<>nil) and (actor=holder) and (GetActorActionState(holder, actAimStarted)) then begin
    result:=true;
  end else
    result:=false;
end;

function IsHolderHasActiveDetector(wpn:pointer):boolean; stdcall;
var
  holder:pointer;
begin
  holder:=GetOwner(wpn);
  if (holder<>nil) then begin
    result:=(DetectorUtils.GetActiveDetector(holder)<>nil);
  end else
    result:=false;
end;

function GetActorActiveItem():pointer; stdcall;
var
  act:pointer;
begin
  result:=nil;
  act:=GetActor;
  if act=nil then exit;
  result:=ItemInSlot(act, GetActorActiveSlot());
end;


{asm
  pushfd

  mov eax, xrGame_addr
  add eax, $64F0E4
  mov eax, [eax]              //g_player_hud
  mov eax, [eax+$94]          //first attachable_item
  cmp eax, 0
  je @finish
  mov eax, [eax+4]
  sub eax, $2e0

  @finish:
  popfd
  mov @result, eax
end; }

function GetActorActiveSlot():integer; stdcall;
asm
  mov @result, -1;
  pushfd

  call GetActor        //получаем актора

  test eax, eax
  je @finish

  mov eax, [eax+$2e4]   //получаем его CInventory
  test eax, eax
  je @finish

  mov ax, [eax+$40]     //получаем текущий активный слот актора
  movzx eax, ax
  mov @result, eax

  @finish:
  popfd
end;

function GetActorSlotBlockedCounter(slot:cardinal):cardinal; stdcall;
asm
  mov @result, 0;
  pushfd
  sub slot, 1
  cmp slot, 12
  jge @finish

  call GetActor        //получаем актора

  test eax, eax
  je @finish

  mov eax, [eax+$2e4]   //получаем его CInventory
  test eax, eax
  je @finish

  lea eax, [eax+$135]
  add eax, slot
  movzx eax, byte ptr [eax]
  mov @result, eax

  @finish:
  popfd
end;

procedure ActivateActorSlot__CInventory(slot:word; forced:boolean); stdcall;
asm
  pushad

  call GetActor        //получаем актора

  test eax, eax
  je @finish

  mov eax, [eax+$2e4]   //получаем его CInventory
  test eax, eax
  je @finish

  movzx ebx, forced
  push ebx
  movzx ebx, slot
  push ebx
  mov ecx, eax
  mov eax, xrgame_addr
  add eax, $2a8070
  call eax

  @finish:
  popad
end;


function GetActorTargetSlot():integer; stdcall;
asm
  mov @result, -1;
  pushfd

  call GetActor        //получаем актора

  test eax, eax
  je @finish

  mov eax, [eax+$2e4]   //получаем его CInventory
  test eax, eax
  je @finish

  mov ax, [eax+$42]     //получаем целевой слот актора
  movzx eax, ax
  mov @result, eax

  @finish:
  popfd
end;

procedure ResetActorFlags(act:pointer);
begin
  SetActorActionState(act, actAimStarted, false);
  SetActorActionState(act, actModSprintStarted, false);
  SetActorActionState(act, actModNeedMoveReassign, false);  
end;

procedure ProcessKeys(act:pointer);
var
  wpn, det:pointer;
  action:cardinal;
begin

  if act = nil then exit;
  wpn:=GetActorActiveItem();
  det:=GetActiveDetector(act);

  
  if (wpn = nil) then begin
    ClearActorKeyRepeatFlags();
    ResetActorFlags(act);
  end else if (not WpnCanShoot(PChar(GetClassName(wpn)))) then begin
    //Реактивация после блока у болта, грены, ножа, вызванного доставанием детектора.
    if (IsThrowable(PChar(GetClassName(wpn))) or IsKnife(PChar(GetClassName(wpn)))) then begin
      if ((_keyflags and kfFIRE)<>0) then
        action:=kWPN_FIRE
      else if ((_keyflags and kfZOOM)<>0) then
        action:=kWPN_ZOOM
      else
        action:=0;
        
      if action>0 then begin
        if cardinal(GetCurrentState(det))<>CHUDState__eShowing then begin
          virtual_Action(wpn, action, kActPress);
          if (action=kWPN_ZOOM) and not IsActionKeyPressedInGame(kWPN_ZOOM) then virtual_Action(wpn, action, kActRelease);
          SetActorKeyRepeatFlag(kfFIRE, false);
          SetActorKeyRepeatFlag(kfZOOM, false);
        end;
      end;

    end;

    wpn:=nil;
  end else begin
    if not IsActionProcessing(wpn) and ((_keyflags and kfFIRE)<>0) then begin
      virtual_Action(wpn, kWPN_FIRE, kActPress);
      SetActorKeyRepeatFlag(kfFIRE, false);
    end;
  end;

  if IsSprintOnHoldEnabled() and (IsAimToggle() or (not IsActionKeyPressedInGame(kWPN_ZOOM)) and (not IsActionKeyPressedInGame(kWPN_ZOOM_ALTER))) and (_keyflags=0) and (CDialogHolder__TopInputReceiver()=nil) then begin
    if IsActionKeyPressedInGame(kSPRINT_TOGGLE) and ((wpn=nil) or CanSprintNow(wpn)) then begin
      SetActorActionState(act, actSprint, true, mState_WISHFUL);
    end else begin
      SetActorActionState(act, actSprint, false, mState_WISHFUL);
    end;
  end;

  if ((_keyflags and kfWPNHIDE)<>0) then begin
    if (wpn=nil) or CanStartAction(wpn) then begin
      SetActorKeyRepeatFlag(kfWPNHIDE, false);
    end;
  end;

  if ((_keyflags and kfDETECTOR)<>0) then begin
    if (wpn=nil) or CanStartAction(wpn) then begin
      SetActorKeyRepeatFlag(kfDETECTOR, false);
    end;
  end;  

  if (wpn=nil) then exit;


  if IsActionKeyPressedInGame(kWPN_ZOOM) then begin
    if not IsAimToggle() and CanAimNow(wpn) and not IsAimNow(wpn) then begin
      virtual_Action(wpn, kWPN_ZOOM, kActPress);
      SetActorKeyRepeatFlag(kfUNZOOM, false);
    end;
  end else if IsActionKeyPressedInGame(kWPN_ZOOM_ALTER) then begin
    if not IsAimToggle() and CanAimNow(wpn) and not IsAimNow(wpn) then begin
      virtual_Action(wpn, kWPN_ZOOM_ALTER, kActPress);
      SetActorKeyRepeatFlag(kfUNZOOM, false);
    end;
  end;

  if (_keyflags and kfUNZOOM)<>0 then begin
    if IsAimNow(wpn) then begin
      if CanLeaveAimNow(wpn) then begin
        if IsAimToggle() then begin
          virtual_Action(wpn, kWPN_ZOOM, kActPress);
        end else begin
          virtual_Action(wpn, kWPN_ZOOM, kActRelease);
        end;
      end;
    end else begin
      SetActorKeyRepeatFlag(kfUNZOOM, false);
    end;
  end;

  if (_keyflags and kfRELOAD)<>0 then begin
    if CanStartAction(wpn) then begin
      virtual_Action(wpn, kWPN_RELOAD, kActPress);
      SetActorKeyRepeatFlag(kfRELOAD, false);
    end;
  end;

  if (_keyflags and kfNEXTAMMO)<>0 then begin
    if CanStartAction(wpn) then begin
      virtual_Action(wpn, kWPN_NEXT, kActPress);
      SetActorKeyRepeatFlag(kfNEXTAMMO, false);
    end;
  end;

  if (_keyflags and kfGLAUNCHSWITCH)<>0 then begin
    if CanStartAction(wpn) then begin
      virtual_Action(wpn, kWPN_FUNC, kActPress);
      SetActorKeyRepeatFlag(kfGLAUNCHSWITCH, false);
    end;
  end;

  if (_keyflags and kfNEXTFIREMODE)<>0 then begin
    if CanStartAction(wpn) then begin
      virtual_Action(wpn, kWPN_FIREMODE_NEXT, kActPress);
      SetActorKeyRepeatFlag(kfNEXTFIREMODE, false);
    end;
  end;

  if (_keyflags and kfPREVFIREMODE)<>0 then begin
    if CanStartAction(wpn) then begin
      virtual_Action(wpn, kWPN_FIREMODE_PREV, kActPress);
      SetActorKeyRepeatFlag(kfPREVFIREMODE, false);
    end;
  end;

  if (_keyflags and kfLASER)<>0 then begin
    if CanStartAction(wpn) then begin
      virtual_Action(wpn, kLASER, kActPress);
      SetActorKeyRepeatFlag(kfLASER, false);
    end;
  end;

  if (_keyflags and kfTACTICALTORCH)<>0 then begin
    if CanStartAction(wpn) then begin
      virtual_Action(wpn, kTACTICALTORCH, kActPress);
      SetActorKeyRepeatFlag(kfTACTICALTORCH, false);
    end;
  end;


{  //принудительный сброс бега во время действия
  if not (IsSprintOnHoldEnabled()) and GetActorActionState(act, actSprint, mstate_WISHFUL) and (not CanSprintNow(wpn)) then begin
    SetActorActionState(act, actSprint, false, mstate_WISHFUL);
  end; }

end;

procedure RestoreLastActorDetector(); stdcall;
var
  detector, act:pointer;
begin
  act:=GetActor();
  if not (WasLastDetectorHiddenManually()) then begin
    detector:=ItemInSlot(act, 9);
    if (detector<>nil) and (not GetDetectorActiveStatus(detector)) then begin
      SetDetectorForceUnhide(detector, true);
      SetActorActionState(act, actShowDetectorNow, true);
    end;
  end;
end;


procedure OnActorNewSlotActivated(act:pointer; slot:integer); stdcall;
begin
  ResetWpnOffset();
  ResetActorFlags(act);
  ResetActivationHoldState();
  if slot<>4 then SetForcedQuickthrow(false);

  //TODO: перенести еду

{$ifdef USE_SCRIPT_USABLE_HUDITEMS}
  if _was_unprocessed_use_of_usable_huditem then begin
    //произошла смена итейбла, восстановим детектор
    //скриптово активировать детектор в юзабельных предметах нельзя - активируем движково
    RestoreLastActorDetector();
    _was_unprocessed_use_of_usable_huditem:=false;
  end;
{$endif}
end;

procedure UpdateSlots(act:pointer);
var
  sect:PChar;
  itm:pointer;
begin
  if _last_act_slot<>-1 then begin                      //проверка на инициализацию переменной на прошлых апдейтах
    if _last_act_slot<>GetActorActiveSlot() then begin
      _prev_act_slot:=_last_act_slot;
      OnActorNewSlotActivated(act, GetActorActiveSlot());
    end;
  end;

{$ifdef USE_SCRIPT_USABLE_HUDITEMS}
  //если в руках худовый юзабельный предмет, то выставим флаг для последующей обработки детектора

  itm:=GetActorActiveItem();
  if itm<>nil then begin
    sect:=GetSection(itm);
      if game_ini_line_exist(sect, 'gwr_changed_object') and game_ini_line_exist(sect, 'gwr_eatable_object') then begin
        _was_unprocessed_use_of_usable_huditem:=true;
      end;
  end;
{$endif}

  _last_act_slot:=GetActorActiveSlot();
end;

procedure ActorUpdate(act:pointer); stdcall;
var
  itm, det, wpn:pointer;
  hud_sect:PChar;
  dt, ct:cardinal;
begin
  ct:=GetGameTickCount();
  dt:=GetTimeDeltaSafe(_last_update_time, ct);
  _last_update_time:=ct;

//  log(inttohex(cardinal(dynamic_cast(act, 0, RTTI_CActor, RTTI_CInventoryItemOwner, false)), 8));

  UpdateSlots(act);

  det:=ItemInSlot(act, 9);

  if det <> nil then begin
    if GetActorActionState(act, actShowDetectorNow) and (GetActiveDetector(act)=nil) then begin
      SetDetectorForceUnhide(det, true);
    end else if (GetCurrentState(det)=2) then begin //мы собрались убирать детектор. Назначим аниму рукам, если оружие не выполняет сейчас какое-то действие.
      itm:=GetActorActiveItem();
      if (itm<>nil) and WpnCanShoot(PChar(GetClassName(itm))) then begin
        hud_sect:=GetHUDSection(itm);
        if (game_ini_line_exist(hud_sect, 'use_finish_detector_anim')) and (game_ini_r_bool(hud_sect, 'use_finish_detector_anim')) then begin
          if CanStartAction(itm) and (not IsHolderInSprintState(itm)) then
            PlayCustomAnimStatic(itm, 'anm_finish_detector', 'sndFinishDet');
        end;
      end;
    end;
  end else begin
    SetActorActionState(act, actShowDetectorNow, false);
  end;


  ProcessKeys(act);
  UpdateFOV(act);
  UpdateInertion(GetActorActiveItem());
  UpdateWeaponOffset(act, dt);
  ControllerMonster.Update(dt);

  if (_lefthanded_torch.render<>nil) and ((GetActiveDetector(act) = nil) or not game_ini_r_bool_def(GetSection(GetActiveDetector(act)), 'torch_installed', false)) then begin
//    log('Destroy lefthand light');
    SwitchLefthandedTorch(false);
    DelTorchlight(@_lefthanded_torch);
    _torch_linked_detector:=nil;
  end;

end;

procedure ActorUpdate_Patch(); stdcall
asm
  pushad
    push ecx
    call ActorUpdate
  popad
  mov eax, [esi+$200]
end;

function ItemInSlot(act:pointer; slot:integer):pointer; stdcall;
asm
  pushad
    mov @result, 0
    cmp act, 0
    je @finish

    push act
    call game_object_GetScriptGameObject
    cmp eax, 0
    je @finish

    mov ecx, eax
    push slot
    mov ebx, xrGame_addr
    add ebx, $1C87f0
    call ebx
    cmp eax, 0
    je @finish

    mov eax, [eax+4]
    cmp eax, 0
    je @finish
    
    sub eax, $e8
    mov @result, eax

    @finish:
  popad
end;


function CheckActorWeaponAvailabilityWithInform(wpn:pointer):boolean;
begin
  result:=false;
  if (GetActorActiveItem()<>wpn) then begin
    Messenger.SendMessage('gunsl_msg_take_wpn_into_hands');
    exit;
  end;

  if not (CanStartAction(wpn)) then begin
    Messenger.SendMessage('gunsl_msg_stop_actions');
    exit;
  end;
  result:=true;
end;

procedure SetActorKeyRepeatFlag(mask:cardinal; state:boolean; ignore_suicide:boolean=false);
begin
  if not ignore_suicide and IsActorSuicideNow() then exit;

  if state then begin
    _keyflags:=_keyflags or mask;
  end else begin
    _keyflags:=_keyflags and (not mask);
  end;
end;


procedure ClearActorKeyRepeatFlags();
begin
  _keyflags:=0;
end;

function CActor__OnKeyboardPress(dik:cardinal):boolean; stdcall;
var
  act:pointer;
  wpn, det, itm:pointer;
  iswpnthrowable, canshoot, is_bino:boolean;
  state:cardinal;
  cls:PChar;
begin

  //возвратить false, чтобы забыть про данное нажатие
  result:=true;

  act:=GetActor();
  if act = nil then exit;
  det:=GetActiveDetector(act);
  wpn:=GetActorActiveItem();
  if (wpn<>nil) then begin
    iswpnthrowable:=IsThrowable(PChar(GetClassName(wpn)));
    canshoot:=WpnCanShoot(PChar(GetClassName(wpn)));
    is_bino:=IsBino(PChar(GetClassName(wpn)));
    state:=GetCurrentState(wpn);
  end;

  if dik = kDETECTOR then begin
      if (wpn<>nil) then begin
        if
          (iswpnthrowable and ((state=EMissileStates__eReady) or (state=EMissileStates__eThrowStart) or (state=EMissileStates__eThrow) or (state=EMissileStates__eThrowEnd)))
          or
          (not iswpnthrowable and ((state=EWeaponStates__eReload) or (state=EWeaponStates__eSwitch) or (state=EWeaponStates__eFire) or (state=EWeaponStates__eFire2)))
          or
          (IsActionProcessing(wpn))
          or
          (canshoot or is_bino) and (IsAimNow(wpn) or IsHolderinAimState(wpn))
          or
          GetActorActionState(act, actModDetectorSprintStarted)
        then begin
          result:=false;
        end;
      end;

      {if (GetActorActionState(act, actSprint) or GetActorActionState(act, actModSprintStarted)) then begin
        SetActorKeyRepeatFlag(kfDETECTOR, true);  //не сработает с детектором :(
        SetActorActionState(act, actSprint, false, mState_WISHFUL);
      end;}
  end else if ((dik=kWPN_FIRE) or (dik=kWPN_ZOOM)) then begin
    if (det<>nil) and (wpn<>nil) then begin
      cls:=PChar(GetClassName(wpn));
      if (IsKnife(cls) or IsThrowable(cls)) then begin
        if (GetCurrentState(det)=CHUDState__eShowing) then begin
          result:=false;
          if dik=kWPN_FIRE then SetActorKeyRepeatFlag(kfFIRE, true) else SetActorKeyRepeatFlag(kfZOOM, true);
        end else if GetActorActionState(act, actModDetectorSprintStarted) then begin
          SetActorActionState(act, actModDetectorSprintStarted, false);
        end;
      end;
    end;
  end else if ((dik=kWPN_1) or (dik=kWPN_2) or (dik=kWPN_3) or (dik=kWPN_4) or (dik=kWPN_5) or (dik=kWPN_6) or (dik=kARTEFACT)) then begin
    if (IsActorSuicideNow()) or IsActorPlanningSuicide() then begin
      result:=false;
    end else if IsActorControlled() then begin
      result:=CanUseItemForSuicide(ItemInSlot(act, dik-kWPN_1+1));
    end else if (det<>nil) and (wpn<>nil) then begin
      if iswpnthrowable then begin
        if (state=EMissileStates__eReady) or (state=EMissileStates__eThrowStart) or (state=EMissileStates__eThrow) or (state=EMissileStates__eThrowEnd) then result:=false;
      end else if canshoot or is_bino then begin
        if IsAimNow(wpn) or IsHolderinAimState(wpn) then result:=false;
      end else begin
        if GetActorActionState(act, actModDetectorSprintStarted) then result:=false;
      end;
    end;
  end else if (dik=kQUICK_GRENADE) then begin
    if (GetActorActiveSlot()=4) or (GetActorSlotBlockedCounter(4)>0) or (IsActorSuicideNow()) or (IsActorPlanningSuicide()) then exit;

    itm:=ItemInSlot(act, 4);
    if (itm<>nil) and game_ini_r_bool_def(GetSection(itm), 'supports_quick_throw', false) then begin
      SetForcedQuickthrow(true);
      ActivateActorSlot__CInventory(4, false);
    end;
  end;

end;

procedure OnKeyPressPatch1();stdcall;
asm
  pushad
    push ebp
    call CActor__OnKeyboardPress
    cmp  al, 1
  popad
  jne @ignore

  mov ebx, 00000001
  test bl, cl
  @ignore:
end;


function GetActorPreviousSlot():integer; stdcall;
begin
  result:=_prev_act_slot;
end;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
procedure CActor__netSpawn(CActor:pointer); stdcall;
begin
  ResetCamHeight();
  ResetWpnOffset();
  ResetActorControl();
  ClearActorKeyRepeatFlags();
  ResetActorFlags(CActor);
  ResetActivationHoldState();
  SetForcedQuickthrow(false);
{$ifdef USE_SCRIPT_USABLE_HUDITEMS}
  _was_unprocessed_use_of_usable_huditem:=false;
{$endif}  
  _prev_act_slot:=-1;
  _last_act_slot:=-1;
  ResetDOF(1000);
  _thirst_value:=1;

  _last_update_time:=GetGameTickCount();
end;

procedure CActor__netSpawn_Patch(); stdcall;
asm
  pushad
    push esi
    call CActor__netSpawn
  popad

  pop edi //оригинальный код завершения метода
  pop esi
  pop ebp
  mov eax, 1
  pop ebx
  add esp, 8
  ret 4
end;


procedure CActor__net_Destroy(CActor:pointer); stdcall;
begin
  if _lefthanded_torch.render<>nil then begin
    SwitchLefthandedTorch(false);
    DelTorchlight(@_lefthanded_torch);
    _torch_linked_detector:=nil;
  end;
end;

procedure CActor__net_Destroy_Patch(); stdcall;
asm
  pushad
    push esi
    call CActor__net_Destroy
  popad
  movzx eax, word ptr [esi+$9c8]
end;
//-----------------------------------------------------------------------------------
function GetSlotOfActorHUDItem(act:pointer; itm:pointer):integer; stdcall;
begin
  for result:=1 to 9 do begin
    if ItemInSlot(act, result)=itm then exit;
  end;
  result:=-1;
end;

procedure ActivateActorSlot(slot:cardinal); stdcall;
asm
  pushad
  pushfd

  call GetActor        //получаем актора

  test eax, eax
  je @finish

  mov eax, [eax+$2e4]   //получаем его CInventory
  test eax, eax
  je @finish

  mov ecx, slot
  mov [eax+$42], cx     //пишем желаемый слот актора

  @finish:
  popfd  
  popad
end;

function RecalcZoomFOV(scope_factor:single):single; stdcall;
var
  fov:single;
begin
  fov:=(GetBaseFOV()/2)*pi/180;
  result:=2*arctan(tan(fov)/scope_factor)*180/pi;
  //log(floattostr(fov));
  //log(floattostr(result));
end;

procedure ZoomFOV_Patch(); stdcall;
asm
  pushad
    push [esi+$498]
    call RecalcZoomFOV
  popad

  pop edi
  pop esi
  push edi
end;

procedure ResetZoomFov_Patch(); stdcall;
asm
  mov [esi+$498], $3F800000; //m_zoom_params.m_fCurrentZoomFactor = 1.0
end;


procedure UpdateFOV(act:pointer);
var
    fov, zoom_fov, hud_fov, af:single;
    wpn:pointer;
    buf:WpnBuf;
begin
  //Можно манипулировать FOV и HudFOV

  wpn:=GetActorActiveItem();

  if not game_ini_line_exist('gunslinger_base', 'fov') then exit;
  fov:=GetBaseFOV();
  if (wpn<>nil) and game_ini_line_exist(GetSection(wpn), 'fov_factor') then fov := fov*game_ini_r_single(GetSection(wpn), 'fov_factor');
  SetFOV(fov);

  fov:=GetBaseHudFOV();
  if (wpn<>nil) then begin
    hud_fov:=game_ini_r_single_def(GetHUDSection(wpn), 'hud_fov_factor', 1.0);
    if IsAimNow(wpn) or (leftstr(GetActualCurrentAnim(wpn), length('anm_idle_aim'))='anm_idle_aim') then begin
      buf:=GetBuffer(wpn);
      if ((GetGLStatus(wpn)=1) or ((GetGLStatus(wpn)=2) and IsGLAttached(wpn))) and IsGLEnabled(wpn) then begin
          zoom_fov:=game_ini_r_single_def(GetCurrentScopeSection(wpn), 'hud_fov_gl_zoom_factor', hud_fov);
      end else if (GetScopeStatus(wpn)=2) and IsScopeAttached(wpn) then begin
          zoom_fov:=game_ini_r_single_def(GetCurrentScopeSection(wpn), 'hud_fov_zoom_factor', hud_fov);
          if (buf<>nil) and buf.IsAlterZoomMode() then begin
            zoom_fov:=game_ini_r_single_def(GetCurrentScopeSection(wpn), 'hud_fov_alter_zoom_factor', zoom_fov);
          end;
      end else begin
          zoom_fov:=game_ini_r_single_def(GetHUDSection(wpn), 'hud_fov_zoom_factor', hud_fov);
          if (buf<>nil) and buf.IsAlterZoomMode() then begin
            zoom_fov:=game_ini_r_single_def(GetHUDSection(wpn), 'hud_fov_alter_zoom_factor', zoom_fov);
          end;
      end;
      af :=GetAimFactor(wpn);
      hud_fov:=hud_fov-(hud_fov-zoom_fov)*af;
    end;
    fov := fov*hud_fov;
  end;
  SetHudFOV(fov);
end;

procedure SetFOV(fov:single); stdcall;
asm
  push eax
  push ebx

  mov eax, fov
  mov ebx, xrgame_addr
  add ebx, $635C44
  mov [ebx], eax

  pop ebx
  pop eax
end;

function GetFOV():single; stdcall;
asm
  mov eax, xrgame_addr
  add eax, $635C44
  mov eax, [eax]
  mov @result, eax
end;

procedure SetHudFOV(fov:single); stdcall;
var
  koef:single;
begin
  koef:=fov/GetFOV;
  asm
    push eax
    push ebx

    mov eax, koef
    mov ebx, $490624
    mov [ebx], eax

    pop ebx
    pop eax
  end;
end;

procedure DropItem(act:pointer; item:pointer); stdcall;
asm
  pushad
  mov edx, act
  cmp edx, 0
  je @finish

  mov ebx, item
  cmp ebx, 0
  je @finish

  push edx
  call game_object_GetScriptGameObject
  mov edx, eax

  add ebx, $E8
  push ebx
  call game_object_GetScriptGameObject

  push eax
  mov ecx, edx  
  mov eax, xrgame_addr
  add eax, $1c7460
  call eax
  
  @finish:
  popad
end;

function CRenderDevice__GetCamPos():pointer; stdcall;
asm
  mov eax, xrEngine_addr
  lea eax, [eax+$92ed8+$30]
  mov @result, eax
end;

function CRenderDevice__GetCamDir():pointer; stdcall;
asm
  mov eax, xrEngine_addr
  lea eax, [eax+$92ed8+$3C]
  mov @result, eax
end;

function GetTargetDist():single; stdcall;
asm
  pushad
  mov @result, 0
  call g_hud
  cmp eax, 0
  je @finish
  mov ecx, eax
  mov eax, xrgame_addr
  add eax, $4afe40
  call eax                 //CHudManager::GetCurrentRayQuery
  cmp eax, 0
  je @finish
  
  mov eax, [eax+4]
  mov @result, eax

  @finish:
  popad
end;


function GetActorThirst():single; stdcall;
begin
  result:=_thirst_value;
end;


procedure RecreateLefthandedTorch(params_section:PChar; det:pointer); stdcall;
begin
  if _lefthanded_torch.render<>nil then begin
    DelTorchlight(@_lefthanded_torch);
  end;
  NewTorchlight(@_lefthanded_torch, params_section);
  SwitchTorchlight(@_lefthanded_torch, false);
  SetWeaponMultipleBonesStatus(det, _lefthanded_torch.light_cone_bones, false);
  _torch_linked_detector:=det;
end;

function GetLefthandedTorchLinkedDetector():pointer; stdcall;
begin
  result:=_torch_linked_detector;
end;

procedure SwitchLefthandedTorch(status:boolean); stdcall;
var
  act, det:pointer;
begin
  if _lefthanded_torch.render=nil then exit;

  if _lefthanded_torch.enabled<>status then begin
    SwitchTorchlight(@_lefthanded_torch, status);
  end;

  act:=GetActor;
  if act=nil then exit;
  det:=GetActiveDetector(act);
  if det<>nil then begin
    SetWeaponMultipleBonesStatus(det, _lefthanded_torch.light_cone_bones, status);
  end;
end;

function GetLefthandedTorchParams():torchlight_params; stdcall;
begin
  result:=_lefthanded_torch;
end;

function HitMarkCondition():boolean;
begin
  //если false, то хитмарки отключаются
  result := GetCurrentDifficulty()<gd_master;
end;

procedure CActor__Hit_HitmarkCondition_Patch(); stdcall;
asm
  pushad
    call HitMarkCondition;
    cmp al, 1
  popad
  jne @finish
  cmp byte ptr[esi+$9ca], 0
  @finish:
end;


function ZoneMapCondition():boolean; stdcall;
begin
  result := GetCurrentDifficulty()<gd_veteran;
end;

procedure CUIMainIngameWnd__Draw_zonemap_Patch(); stdcall;
asm
  pop eax
  pop edx
  push eax

  pushad
  push esi
  call ZoneMapCondition
  pop esi
  mov ecx, [esi+$60]
  mov [ecx+4], al //UIZoneMap->visible = al
  cmp al, 0
  popad

  je @finish

  push edx
  mov eax, xrgame_addr
  add eax, $45c300
  call eax   //UIMotionIcon->SetNoise

  mov ecx, [esi+$5c]
  mov edx, [ecx]
  mov eax, [edx+$60]
  call eax //UIMotionIcon->Draw();

  mov ecx, [esi+$60]

  mov eax, xrgame_addr
  add eax, $45ce90
  call eax //UIZoneMap->Render();

  @finish:
end;

function drawingame_conditions():boolean; stdcall;
begin
  result := GetCurrentDifficulty()<gd_master;
end;

procedure CUIGameCustom__Render_drawingame_Patch; stdcall;
asm
  pushad
    call drawingame_conditions
    cmp al, 0
  popad
  je @finish
  mov edx, [eax+$60]
  call edx
  @finish:
end;

procedure CActor__g_cl_CheckControls_disable_cam_anms_Patch; stdcall;
asm
  mov eax, xrgame_addr
  comiss xmm0, [eax+$54d270]
  jbe @finish
  pushad
    call IsMoveCamAnmsEnabled
    cmp al, 0
  popad
  @finish:
end;

procedure CActor__ActorUse_Patch_deadbodies(); stdcall;
//чтобы инвентарь не открывался при попытке тащить труп
asm
  mov edi, [esi+$54c]
  cmp byte ptr [edi+$71], 0
  jne @finish
  pushad
    push $2A //DIK_LSHIFT
    call IsKeyPressed
    cmp al, 00
  popad

  @finish:
end;

function CanMoveItem(CObject:pointer):boolean; stdcall;
begin
  result:=true;
  CObject:=dynamic_cast(CObject, 0, RTTI_CObject, RTTI_CInventoryItemOwner, false);
  if CObject=nil then exit;
  CObject:=CInventoryOwner__GetInventory(CObject);
  if CObject=nil then exit;
  result:=(CInventory__CalcTotalWeight(CObject)<GetMaxCorpseWeight);
  if not result then SendMessage('gunsl_corpse_overweighted', gd_stalker);

end;

procedure CActor__ActorUse_Patch_deadbodies_weight(); stdcall;
//чтобы нельзя было накидать кучу лута в труп, а потом тащить
asm
  mov eax, xrgame_addr
  add eax, $4fec00
  call eax
  test eax, eax
  jne @finish
  pushad
    push ebp
    call CanMoveItem
    cmp al, 01
  popad
  @finish:
end;

function Init():boolean; stdcall;
var jmp_addr:cardinal;
begin
  ClearActorKeyRepeatFlags();

  _prev_act_slot:=-1;
  _last_act_slot:=-1;

{$ifdef USE_SCRIPT_USABLE_HUDITEMS}
  _was_unprocessed_use_of_usable_huditem:=false;
{$endif}

  _lefthanded_torch.render:=nil;
  _lefthanded_torch.omni:=nil;
  _lefthanded_torch.glow:=nil;
  _lefthanded_torch.enabled:=false;


  result:=false;
  jmp_addr:=xrGame_addr+$261DF6;
  if not WriteJump(jmp_addr, cardinal(@ActorUpdate_Patch), 6, true) then exit;

  jmp_addr:= xrgame_addr+$2783F9;  //CActor::IR_OnKeyboardPress
  if not WriteJump(jmp_addr, cardinal(@OnKeyPressPatch1), 7, true) then exit;

  jmp_addr:= xrgame_addr+$26D115;
  if not WriteJump(jmp_addr, cardinal(@CActor__netSpawn_Patch), 8) then exit;

  jmp_addr:= xrgame_addr+$26F04B;
  if not WriteJump(jmp_addr, cardinal(@CActor__net_Destroy_Patch), 7, true) then exit;

  jmp_addr:= xrgame_addr+$2637BE;
  if not WriteJump(jmp_addr, cardinal(@CActor__Hit_HitmarkCondition_Patch), 7, true) then exit;

  jmp_addr:= xrgame_addr+$45A0D7;
  if not WriteJump(jmp_addr, cardinal(@CUIMainIngameWnd__Draw_zonemap_Patch), 29, true) then exit;

  jmp_addr:= xrgame_addr+$4b1b59;
  if not WriteJump(jmp_addr, cardinal(@CUIGameCustom__Render_drawingame_Patch), 5, true) then exit;

  //фов в прицеливании
  jmp_addr:= xrgame_addr+$2605d0;
  if not WriteJump(jmp_addr, cardinal(@ZoomFOV_Patch), 13, true) then exit;

  //отключение анимаций камеры в движении
  jmp_addr:= xrgame_addr+$269b97;
  if not WriteJump(jmp_addr, cardinal(@CActor__g_cl_CheckControls_disable_cam_anms_Patch), 7, true) then exit;


  //[bug] баг - чтобы при попытке тащить труп не открывался инвентарь
  //внимание - подозрение на то, что приводит к другому багу: в скрипты подается сигнал об открытии инвентаря трупа, когда сам инвентарь не открывался!
  jmp_addr:= xrgame_addr+$27820d;
  if not WriteJump(jmp_addr, cardinal(@CActor__ActorUse_Patch_deadbodies), 10, true) then exit;

  //баг - возможность таскать тяжелые трупы
  jmp_addr:= xrgame_addr+$27832e;
  if not WriteJump(jmp_addr, cardinal(@CActor__ActorUse_Patch_deadbodies_weight), 7, true) then exit;

  //включаем коллизию
  if IsCorpseCollisionEnabled() then begin
    nop_code(xrgame_addr+$4e2160, 2);
    nop_code(xrgame_addr+$4e20c0, 2);
  end;

  //теперь в обычном состоянии m_zoom_params.m_fCurrentZoomFactor должен инициализироваться не g_fov, а 1.0
  //в CWeapon::OnZoomOut
  jmp_addr:= xrgame_addr+$2BEE26;
  if not WriteJump(jmp_addr, cardinal(@ResetZoomFov_Patch), 16, true) then exit;
  //и в CWeapon::CWeapon
  jmp_addr:= xrgame_addr+$2BF6F7;
  if not WriteJump(jmp_addr, cardinal(@ResetZoomFov_Patch), 16, true) then exit;

  result:=true;
end;

end.
