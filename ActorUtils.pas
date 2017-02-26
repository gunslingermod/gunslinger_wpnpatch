unit ActorUtils;

//xrgame+4e212a - менять условия для включения коллизии

{$define USE_SCRIPT_USABLE_HUDITEMS}  //на всякий - потом все равно в двиг надо перекинуть, но влом - и так отлично работает

interface
const
  actMovingForward:cardinal = $1;
  actMovingBack:cardinal = $2;
  actMovingLeft:cardinal = $4;
  actMovingRight:cardinal = $8;
  actCrouch:cardinal = $10;
  actSlow:cardinal = $20;
  actSprint:cardinal = $1000;

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
procedure SetActorKeyRepeatFlag(mask:cardinal; state:boolean);
procedure ClearActorKeyRepeatFlags();
procedure ResetActorFlags(act:pointer);
procedure UpdateSlots(act:pointer);
procedure UpdateFOV(act:pointer);
function GetSlotOfActorHUDItem(act:pointer; itm:pointer):integer; stdcall;
procedure ActivateActorSlot(slot:cardinal); stdcall;

procedure SetFOV(fov:single); stdcall;
function GetFOV():single; stdcall;
procedure SetHudFOV(fov:single); stdcall;

function CRenderDevice__GetCamPos():pointer;
function CRenderDevice__GetCamDir():pointer;
function GetTargetDist():single;


implementation
uses Messenger, BaseGameData, HudItemUtils, Misc, DetectorUtils,WeaponAdditionalBuffer, sysutils, KeyUtils, UIUtils, gunsl_config, WeaponEvents, Throwable, dynamic_caster, WeaponUpdate, ActorDOF;

var
  _keyflags:cardinal;
  _last_act_slot:integer;
  _prev_act_slot:integer;

  _last_act_item:pointer;

{$ifdef USE_SCRIPT_USABLE_HUDITEMS}
  _was_unprocessed_use_of_usable_huditem:boolean;
{$endif}


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

  if IsSprintOnHoldEnabled() and (not IsActionKeyPressedInGame(kWPN_ZOOM)) and (_keyflags=0) and (CDialogHolder__TopInputReceiver()=nil) then begin
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
  end;

  if (_keyflags and kfUNZOOM)<>0 then begin
    if IsAimNow(wpn) then begin
      if CanLeaveAimNow(wpn) then begin
        virtual_Action(wpn, kWPN_ZOOM, kActRelease);
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
  ResetActorFlags(act);
  ResetActivationHoldState();

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
  itm, det:pointer;
  hud_sect:PChar;
begin
  UpdateSlots(act);

  det:=ItemInSlot(act, 9);

  if det <> nil then begin
    if GetActorActionState(act, actShowDetectorNow) and (GetActiveDetector(act)=nil) then begin
      SetDetectorForceUnhide(det, true);
    end else if GetCurrentState(det)=2 then begin //мы собрались убирать детектор. Назначим аниму рукам, если оружие не выполняет сейчас какое-то действие.
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

  itm:=GetActorActiveItem();
  if (_last_act_item<>nil) and (_last_act_item<>itm) then begin
    if (GetBuffer(_last_act_item)<>nil) then CWeapon__ModUpdate(_last_act_item);
  end;
  _last_act_item:=itm;

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

procedure SetActorKeyRepeatFlag(mask:cardinal; state:boolean);
begin
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
  wpn, det:pointer;
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
    if (det<>nil) and (wpn<>nil) then begin
      if iswpnthrowable then begin
        if (state=EMissileStates__eReady) or (state=EMissileStates__eThrowStart) or (state=EMissileStates__eThrow) or (state=EMissileStates__eThrowEnd) then result:=false;
      end else if canshoot or is_bino then begin
        if IsAimNow(wpn) or IsHolderinAimState(wpn) then result:=false;
      end else begin
        if GetActorActionState(act, actModDetectorSprintStarted) then result:=false;
      end;
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
  ClearActorKeyRepeatFlags();
  ResetActorFlags(CActor);
  ResetActivationHoldState();
{$ifdef USE_SCRIPT_USABLE_HUDITEMS}
  _was_unprocessed_use_of_usable_huditem:=false;
{$endif}  
  _prev_act_slot:=-1;
  _last_act_slot:=-1;
  _last_act_item:=nil;
  ResetDOF(1000);
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


procedure UpdateFOV(act:pointer);
var
    fov:single;
    wpn:pointer;
begin
  //Можно манипулировать FOV и HudFOV

  wpn:=GetActorActiveItem();

  if not game_ini_line_exist('gunslinger_base', 'fov') then exit;
  fov:=GetBaseFOV();
  if (wpn<>nil) and game_ini_line_exist(GetSection(wpn), 'fov_factor') then fov := fov*game_ini_r_single(GetSection(wpn), 'fov_factor');
  SetFOV(fov);

  fov:=GetBaseHudFOV();
  if (wpn<>nil) and game_ini_line_exist(GetSection(wpn), 'hud_fov_factor') then fov := fov*game_ini_r_single(GetSection(wpn), 'hud_fov_factor');  
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

function CRenderDevice__GetCamPos():pointer;
asm
  mov eax, xrEngine_addr
  lea eax, [eax+$92ed8+$30]
  mov @result, eax
end;

function CRenderDevice__GetCamDir():pointer;
asm
  mov eax, xrEngine_addr
  lea eax, [eax+$92ed8+$3C]
  mov @result, eax
end;

function GetTargetDist():single;
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


function Init():boolean; stdcall;
var jmp_addr:cardinal;
begin
  ClearActorKeyRepeatFlags();

  _prev_act_slot:=-1;
  _last_act_slot:=-1;

{$ifdef USE_SCRIPT_USABLE_HUDITEMS}
  _was_unprocessed_use_of_usable_huditem:=false;
{$endif}

  result:=false;
  jmp_addr:=xrGame_addr+$261DF6;
  if not WriteJump(jmp_addr, cardinal(@ActorUpdate_Patch), 6, true) then exit;

  jmp_addr:= xrgame_addr+$2783F9;  //CActor::IR_OnKeyboardPress
  if not WriteJump(jmp_addr, cardinal(@OnKeyPressPatch1), 7, true) then exit;

  jmp_addr:= xrgame_addr+$26D115;
  if not WriteJump(jmp_addr, cardinal(@CActor__netSpawn_Patch), 8) then exit;

  result:=true;
end;

end.
