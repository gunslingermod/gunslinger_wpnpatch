unit DetectorUtils;

interface

function Init:boolean;
procedure SetDetectorForceUnhide(det:pointer; status:boolean); stdcall;
function GetActiveDetector(act:pointer):pointer; stdcall;   
function CanUseDetectorWithItem(wpn:pointer):boolean; stdcall;
function GetDetectorActiveStatus(CCustomDetector:pointer):boolean; stdcall

implementation
uses BaseGameData, WeaponAdditionalBuffer, WpnUtils, ActorUtils, GameWrappers, sysutils, strutils;


function CanUseDetectorWithItem(wpn:pointer):boolean; stdcall;
var
  sect:PChar;
begin
  result:=true;
  if wpn=nil then exit;
  sect:=GetSection(wpn);
  if sect=nil then exit;
  if not(game_ini_line_exist(sect, 'supports_detector') and game_ini_r_bool(sect,'supports_detector')) then begin
    result:=false;
  end;  
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

  if (not result) or (not WpnCanShoot(PChar(GetClassName(wpn)))) then exit;
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
  result:=true;
  itm:=GetActorActiveItem();
  if itm<>nil then begin
      param := GetCurAnim(itm);
      if param = '' then param:=GetActualCurrentAnim(itm);
      param:='disable_detector_'+param;
      if IsHolderInAimState(itm) or (WpnCanShoot(PChar(GetClassName(itm))) and IsAimNow(itm)) then begin
        result:=false;
      end else if game_ini_line_exist(GetHUDSection(itm), PChar(param)) then begin
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
  jne @finish
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
  cmp[esi+$2e4], 3
  //если игра не решилась показать детектор - то не будем мешать
  jne @finish
  
  //Проверим, не выполняется ли какое-либо действие
  pushad
    call CanShowDetector
    cmp al, 1
  popad
  @finish:
end;

procedure OnDetectorPrepared(wpn:pointer; p:integer); stdcall
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

procedure SetDetectorForceUnhide(det:pointer; status:boolean); stdcall
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

procedure SetDetectorActiveStatus(det:pointer; status:boolean); stdcall
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

function GetDetectorForceUnhideStatus(det:pointer):boolean; stdcall
asm
  mov @result, 0
  cmp det, 0
  je @finish
  pushad
    mov eax, det
    mov ebx, [eax+$33D]
    mov @result, bl
  popad
  @finish:
end;

function GetDetectorActiveStatus(CCustomDetector:pointer):boolean; stdcall
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
    if (itm<>nil) and WpnCanShoot(PChar(GetClassName(itm))) then begin
      hud_sect:=GetHUDSection(itm);
      if (game_ini_line_exist(hud_sect, 'use_prepare_detector_anim')) and (game_ini_r_bool(hud_sect, 'use_prepare_detector_anim')) then begin
        PlayCustomAnimStatic(itm, 'anm_prepare_detector', 'sndPrepareDet', OnDetectorPrepared, 0);
        SetDetectorForceUnhide(det, true); 
      end else result:=true;
    end else begin
      result:=true;
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
  itm, act:pointer;
  hud_sect:PChar;
begin
  act:=GetActor();
  if act=nil then exit;
  if (GetOwner(det)<>act) then begin
    //Если актор выбросил активный детектор и поднял его - то этот детектор в оригинале формально находится в активном состоянии, а по факту не рисуется
    //Так что при обнаружении выбрасывания обманываем игру, выставляя неактивность детектора
    MakeUnActive(det);
  end;
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
begin
  PlayAnimIdle(det);
  //PlayHudAnim(det, GetActualCurrentAnim(det), true); //для отключения микшера
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



function GetActiveDetector(act:pointer):pointer; stdcall
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

function Init:boolean;
var jmp_addr:cardinal;
begin
  result:=false;
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
  result:=true;
end;


end.
