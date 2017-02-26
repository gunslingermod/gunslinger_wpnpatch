unit Throwable;

//содержит основную часть правок на болты и грены.

interface

function Init():boolean;
procedure ResetActivationHoldState(); stdcall;

const
		EMissileStates__eThrowStart:cardinal = 5;
		EMissileStates__eReady:cardinal = 6;
		EMissileStates__eThrow:cardinal = 7;
		EMissileStates__eThrowEnd:cardinal = 8;

implementation
uses BaseGameData, WeaponSoundLoader, ActorUtils, WpnUtils, GameWrappers, KeyUtils, sysutils, strutils;

var _activate_key_state:TKeyHoldState;

procedure Throwable_Play_Snd(itm:pointer; alias:PChar); stdcall;
asm
  pushad
  mov esi, itm


  push esi
  call GetPosition
  push eax

  push alias

  add esi, $2e0
  push esi          //CHudItem

  call virtual_CHudItem_PlaySound

  popad
end;

function CMissile__GetFakeMissile(CMissile:pointer):pointer; stdcall;
asm
  mov eax, CMissile
  mov eax, [eax+$394]
end;


procedure CMissile__spawn_fake_missile(CMissile:pointer); stdcall;
asm
  pushad
    mov ecx, CMissile
    mov eax, xrgame_addr
    add eax, $2c7e20
    call eax
  popad
end;


procedure SetupQuickThrowForceParams(CMissile:pointer); stdcall;
asm
  push eax
  push ecx

    mov ecx, CMissile
    mov eax, [ecx+$39c]
    mov [ecx+$3ac], eax //выставим силу броска, использующуюся при нажатии ЛКМ 
  pop ecx
  pop eax
end;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
procedure CMissile__Load(CMissile:pointer; section:PChar; HUD_SOUND_COLLECTION:pointer);stdcall;
begin
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_draw', 'sndDraw', 0, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_holster', 'sndHide', 0, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_throw_begin', 'sndThrowBegin', 0, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_throw', 'sndThrow', 0, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_throw_quick', 'sndThrowQuick', 0, $80040000);
end;

procedure CMissile__Load_Patch();stdcall;
asm
  fstp[esi+$398]//вырезанное
  pushad
    lea edx, esi+$324
    push edx        // HUD_SOUND_COLLECTION
    push edi        //char* section
    push esi        //this
    call CMissile__Load
  popad
  ret
end;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function CMissile__State_anm_show_selector(CMissile:pointer):PChar; stdcall;
var
  act:pointer;
  snd, sect:PChar;
  curslot:integer;
begin
  result:='anm_show';
  snd:='sndDraw';

  act:=GetActor();
  if (act<>nil) and (GetOwner(CMissile)=act) then begin
    ResetActorFlags(act);
//    UpdateSlots(act);
    if _activate_key_state.IsActive and _activate_key_state.IsHoldContinued then begin
      _activate_key_state.IsActive:=false;
      sect:=GetSection(CMissile);
      if game_ini_line_exist(sect, 'supports_quick_throw') and game_ini_r_bool(sect,'supports_quick_throw') then begin
        //надо выполнить быстрый бросок
        result:='anm_throw_quick';
        snd:='sndThrowQuick';
        CMissile__spawn_fake_missile(CMissile);
        SetupQuickThrowForceParams(CMissile);
      end;
    end;
  end;
  Throwable_Play_Snd(CMissile, snd);
end;

function CMissile__State_anm_hide_selector(CMissile:pointer):PChar; stdcall;
var
  act:pointer;
begin
  result:='anm_hide';
  act:=GetActor();
  if (act<>nil) and (GetOwner(CMissile)=act) then begin
    ResetActorFlags(act);
  end;
  Throwable_Play_Snd(CMissile, 'sndHide');
end;



function CMissile__State_anm_selector_dispatcher(CMissile:pointer; ret_addr:cardinal):PChar; stdcall;
begin
  result:='anm_unknown';
  ret_addr:=ret_addr and $0000FFFF;
  case ret_addr of
    $75AA:result:=CMissile__State_anm_show_selector(CMissile);
    $7629:result:=CMissile__State_anm_hide_selector(CMissile);
    $76B4:begin
            result:='anm_throw_begin';
            Throwable_Play_Snd(CMissile, 'sndThrowBegin');
          end;
    $7740:begin
            result:='anm_throw';
            Throwable_Play_Snd(CMissile, 'sndThrow');
          end;
  else
    log('CMissile__State_anm_selector_dispatcher: unknown call detected!', true);
  end;
end;

procedure CMissile__State_anm_Patch(); stdcall;
asm
    push 0                  //забиваем место под название анимы
    pushad
    pushfd
      push [esp+$28]
      push esi
      call CMissile__State_anm_selector_dispatcher  //получаем строку с именем анимы
      mov ecx, [esp+$28]      //запоминаем адрес возврата
      mov [esp+$28], eax      //кладем на его место результирующую строку
      mov [esp+$24], ecx      //перемещаем адрес возврата на 4 байта выше в стеке
    popfd
    popad
    ret
end;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function CMissile__OnActiveItem(CMissile:pointer):boolean; stdcall;
//при возвращении true разрешаем переходить в состояние доставания и начинать проигрывать аниму
var
  curslot: integer;
  act:pointer;
const
  GRENADE_KEY_HOLD_TIME_DELTA:cardinal = 250; //период времени, нажатость клавиши в течение которого означает ее удержание в нажатом состоянии
begin

  result:=true;

  act:=GetActor();
  if (act=nil) or (act<>GetOwner(CMissile)) then exit;


  curslot:=GetActorActiveSlot();
  if curslot<>GetSlotOfActorHUDItem(act, CMissile) then begin
    ResetActivationHoldState();
    result:=false;         //дождемся смены текущего слота на слот грены
    exit;
  end;

  if (curslot<0) or (curslot>6) then begin
    ResetActivationHoldState();
    exit;
  end;

  UpdateSlots(act);

  if not _activate_key_state.IsActive then begin
    _activate_key_state.IsActive:=true;
    _activate_key_state.ActivationStart := GetGameTickCount();
    _activate_key_state.HoldDeltaTimePeriod:=GRENADE_KEY_HOLD_TIME_DELTA;
    _activate_key_state.IsHoldContinued:=true;
  end;

  if not IsActionKeyPressedInGame(kDETECTOR+cardinal(curslot)) then begin
    //актор отпустил клавишу, удержания нет
    _activate_key_state.IsHoldContinued:=false;
  end;

  if (GetActorPreviousSlot()>0) or ((GetTimeDeltaSafe(_activate_key_state.ActivationStart)>_activate_key_state.HoldDeltaTimePeriod) or not _activate_key_state.IsHoldContinued) then begin
    result:=true;
  end else begin
    result:=false;
  end;
end;

procedure CMissile__OnActiveItem_Patch(); stdcall;
asm
  push 0
  pushad
    mov edx, [esp+$24]      //запоминаем адрес возврата
    mov [esp+$24], esi      //оригинальное push esi
    mov [esp+$20], edx      //перемещаем адрес возврата на 4 байта выше в стеке

    sub ecx, $2e0
    push ecx
    call CMissile__OnActiveItem
    cmp al, 1
  popad
  je @allok
  add esp, 8                //сейчас  пока нельзя активироваться; забываем адрес возврата и уходим из OnActiveItem
  ret

  @allok:                   //переходим в состояние доставания
  mov esi, ecx
  mov eax, [esi]
  ret
end;

//не дадим прервать быстрый бросок грены
function CanHideGrenadeNow(CMissile:pointer):boolean; stdcall;
var
  state:cardinal;
begin
  result:=true;
  state:=GetCurrentState(CMissile);
  if (state=EMissileStates__eThrowStart) or (state=EMissileStates__eReady) or (state=EMissileStates__eThrow) or (state=EMissileStates__eThrowEnd) or ((state=CHUDState__eShowing) and (GetActualCurrentAnim(CMissile)='anm_throw_quick')) then result:=false;
end;

procedure CGrenade__SendHiddenItem_Patch();stdcall;
var
  act:pointer;
asm
  pushad
    sub esi, $2e0
    push esi
    call CanHideGrenadeNow
    cmp al, 0
  popad
  ret
end;

//DONE:выбор слота после броска грены
procedure CMissile__PutNextToSlot(this:pointer; IsSameItemFound:boolean); stdcall;
var
  act:pointer;
  curslot, prevslot:integer;
begin
  act:=GetActor();
  if (act=nil) or (act<>GetOwner(this)) then exit;
  curslot:=GetActorActiveSlot();
  prevslot:=GetActorPreviousSlot();
  if (curslot<=0) or (curslot>6) then curslot:=-1;

  if not IsSameItemFound or ((GetActualCurrentAnim(this)='anm_throw_quick') and ((curslot<0) or not IsActionKeyPressedInGame(kDETECTOR+cardinal(curslot)))) then begin
    if prevslot>=0 then
      ActivateActorSlot(prevslot)
    else
      ActivateActorSlot(0);
  end else begin
    //мы держим клавишу броска и схожие предметы в инвентаре еще есть; сделаем так, чтобы не было задержки перед следующим броском
    ActivateActorSlot(curslot);
    _activate_key_state.IsActive:=true;
    _activate_key_state.ActivationStart:=GetGameTickCount();
    _activate_key_state.HoldDeltaTimePeriod:=0;
  end
end;

procedure CMissile__PutNextToSlot_SameItemFound_Patch(); stdcall;
asm
  mov [ecx+$42], ax
  mov [ecx+$40], ax
  pushad
    push 01
    push esi
    call CMissile__PutNextToSlot
  popad
  ret
end;

procedure CMissile__PutNextToSlot_NoItem_Patch(); stdcall;
asm
  pushad
    push 00
    push esi
    call CMissile__PutNextToSlot
  popad
  ret
end;



//TODO: взрыв при касании поверхности

//TODO: сокрытие лишних костей у брошенной грены


function CMissile__OnMotionMark(CMissile:pointer; state:cardinal):boolean;stdcall;
//возвращением false не дадим сделать бросок сейчас
begin
  result:=false;
  if (state=EMissileStates__eThrow) or((state=CHUDState__eShowing) and (GetActualCurrentAnim(CMissile)='anm_throw_quick')) then begin
    result:=true;
  end;
end;

procedure CMissile__OnMotionMark_Patch;stdcall;
asm
  pushad
    push [esp+$24]          //push state
    sub ecx, $2e0
    push ecx
    call CMissile__OnMotionMark
    cmp al, 0
  popad
  ret
end;


//DONE: в CMissile::OnAnimationEnd сделать принудительное назначение нового идла, старую схему убрать
function CMissile__OnAnimationEnd(CMissile:pointer; state:cardinal):boolean;stdcall;
//если возвратим false - окончим на этом весь OnAnimationEnd;  если делать так, то надо не забывать выставлять новое состояние!
var
  act:pointer;
begin
  result:=true;
  act:=GetActor();
  if (state=CHUDState__eShowing) and (GetActualCurrentAnim(CMissile)='anm_throw_quick') then begin
    virtual_CHudItem_SwitchState(CMissile, EMissileStates__eThrowEnd);
    result:=false;
  end else if (act<>nil) and (act=GetOwner(CMissile)) and (leftstr(GetActualCurrentAnim(CMissile), length('anm_idle'))='anm_idle') then begin
    SetActorActionState(act, actModNeedMoveReassign, true);
  end;
end;

procedure CMissile__OnAnimationEnd_Patch;stdcall;
asm
  mov esi, [esp+$0C]  //просто запомним аргумент метода
  pushad
    push esi          //и передадим его нашему обработчику
    sub ecx, $2e0
    push ecx
    call CMissile__OnAnimationEnd
    cmp al, 1
  popad
  je @finish
  add esp, 4          //забываем про возврат в OnAnimationEnd
  pop esi             //воостанавливаем сохраненное оригинальным кодом
  ret 4               //Возвращаемся из OnAnimationEnd
  @finish:
  mov esi, ecx        //вырезанное
  mov ecx, [esp+$0C]
  ret                 //возврат в OnAnimationEnd
end;


procedure ResetActivationHoldState(); stdcall;
begin
  _activate_key_state.IsActive:=false;
end;


function Init():boolean;
var
  jump_addr:cardinal;
begin
  result:=false;
  ResetActivationHoldState();
  
  jump_addr:=xrGame_addr+$2C6C76;
  if not WriteJump(jump_addr, cardinal(@CMissile__Load_Patch), 6, true) then exit;
  jump_addr:=xrGame_addr+$2C75A5;
  if not WriteJump(jump_addr, cardinal(@CMissile__State_anm_Patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2C7624;
  if not WriteJump(jump_addr, cardinal(@CMissile__State_anm_Patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2C76AF;
  if not WriteJump(jump_addr, cardinal(@CMissile__State_anm_Patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2C773B;
  if not WriteJump(jump_addr, cardinal(@CMissile__State_anm_Patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2C6734;
  if not WriteJump(jump_addr, cardinal(@CGrenade__SendHiddenItem_Patch), 11, true) then exit;
  jump_addr:=xrGame_addr+$2C7FA1;
  if not WriteJump(jump_addr, cardinal(@CMissile__OnAnimationEnd_Patch), 6, true) then exit;
  jump_addr:=xrGame_addr+$2C6FD0;
  if not WriteJump(jump_addr, cardinal(@CMissile__OnMotionMark_Patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2C7500;
  if not WriteJump(jump_addr, cardinal(@CMissile__OnActiveItem_Patch), 5, true) then exit;
  jump_addr:=xrGame_addr+$2C6919;
  if not WriteJump(jump_addr, cardinal(@CMissile__PutNextToSlot_SameItemFound_Patch), 8, true) then exit;
  jump_addr:=xrGame_addr+$2C6958;
  if not WriteJump(jump_addr, cardinal(@CMissile__PutNextToSlot_NoItem_Patch), 12, true) then exit;
  result:=true;

end;

end.
