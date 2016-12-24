unit DetectorUtils;

interface

function Init:boolean;
procedure SetDetectorForceUnhide(det:pointer; status:boolean); stdcall;
function GetActiveDetector(act:pointer):pointer; stdcall;    //Возвращает CScriptGameObject! Исправить!

implementation
uses BaseGameData, WeaponAdditionalBuffer, WpnUtils, ActorUtils, GameWrappers, sysutils, strutils;

function CanShowDetector():boolean; stdcall;
var
  itm:pointer;
begin
  result:=true;
  itm:=GetActorActiveItem();
  if itm<>nil then
    //играем аниму только если мы не бежим и не выполняем какое-либо действие, кроме отыгрывания анимы детектора
    result:= not ( GetActorActionState(GetActor, actModSprintStarted) or (IsActionProcessing(itm) and (leftstr(GetCurAnim(itm), length('anm_show_detector'))='anm_show_detector') ));
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

    SetDetectorForceUnhide(det, false);
    asm
      pushad
        push 01
        mov ecx, det
        mov eax, xrGame_addr
        add eax, $2ecda0
        call eax
      popad
    end;
    PlayCustomAnimStatic(itm, 'anm_show_detector');
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

function GetDetectorActiveStatus(det:pointer):boolean; stdcall
asm
  mov @result, 0
  cmp det, 0
  je @finish
  pushad
    mov eax, det
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
    //Если актор выбросил активный детектор и поднял его - то он формально находится в активном состоянии, а по факту не рисуется
    //Так что при обнаружении выбрасывания обманываем игру, выставляя неактивность детектора
    MakeUnActive(det);
  end;

{//фикс бага с повторным доставанием старого оружия
    itm:=GetActorActiveItem();
    if (itm<>nil) and WpnCanShoot(PChar(GetClassName(itm))) then begin
      hud_sect:=GetHUDSection(itm);
      if (GetCurrentState(itm) = 2) then begin
        if not(game_ini_line_exist(hud_sect, 'use_prepare_detector_anim')) or not (game_ini_r_bool(hud_sect, 'use_prepare_detector_anim')) then exit;
        SetActorActionState(act, actPreparingDetectorFinished, false);
        SetDetectorForceUnhide(det, false);
      end;
    end;  }
end;

procedure DetectorUpdatePatch();stdcall;
asm
  lea ecx, [esi+$E8];
  pushad
    push esi
    call DetectorUpdate
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
  result:=true;
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
    mov @result, eax

    jmp @finish

    @null:
    mov @result, 0
    jmp @finish
    
    @finish:
  popad
end;

end.
