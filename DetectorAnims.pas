unit DetectorAnims;

interface

//Основное предназначение - сокрытие и показ детектора по аналогии с релоадом при попытке выполнения "нового" действия актором

function Init:boolean;

implementation
uses BaseGameData, WeaponAdditionalBuffer;

function IsDetectorNeedHideNow(detector: pointer; curwpn:pointer):boolean; stdcall;
begin
  result:=IsActionProcessing(curwpn);
end;

procedure HideDetectorOnActionPatch; stdcall;
asm
  //делаем вырезанное
  mov ecx, [eax+$2e4]
  //если игра уже решила скрыть детектор - то не вмешиваемся
  jne @finish
  //Проверим, не выполняется ли какое-либо действие
  pushad
    push eax
    push esi
    call IsDetectorNeedHideNow
    cmp al, 0
  popad
  @finish:
end;


function IsDetectorNeedUnHideNow(detector: pointer; curwpn:pointer):boolean; stdcall;
begin
  result:=true;
  if curwpn<>nil then result:=IsActionProcessing(curwpn);
end;

procedure UnHideDetectorOnActionPatch; stdcall;
asm
  //делаем вырезанное
  cmp[esi+$2e4], 3
  //если игра не решилась показать детектор - то не будем мешать
  jne @finish
  //Проверим, не выполняется ли какое-либо действие
  pushad
    mov eax, [edi+4]
    sub eax, $2e0
    push eax
    push esi
    call IsDetectorNeedUnHideNow
    cmp al, 0
  popad
  @finish:
end;


function Init:boolean;
var jmp_addr:cardinal;
begin
  jmp_addr:=xrGame_addr+$2ECF0A;
  if not WriteJump(jmp_addr, cardinal(@HideDetectorOnActionPatch), 6, true) then exit;
  jmp_addr:=xrGame_addr+$2ECF78;
  if not WriteJump(jmp_addr, cardinal(@UnHideDetectorOnActionPatch), 7, true) then exit;
end;

end.
