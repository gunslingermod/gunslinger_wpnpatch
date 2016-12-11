unit WpnUtils;

interface
function Init():boolean;
//function GetCurrentHud(wpn: pointer):pointer; stdcall;
function PlayHudAnim(anim:PChar; wpn: pointer):pointer; stdcall;  //TODO: не работает
procedure SetWorldModelBoneStatus(wpn: pointer; bone_name:PChar; status:boolean); stdcall;
procedure SetHudModelBoneStatus(wpn: pointer; bone_name:PChar; status:boolean); stdcall;
procedure SetWeaponModelBoneStatus(wpn: pointer; bone_name:PChar; status:boolean); stdcall;
function IsScopeAttached(wpn:pointer):boolean; stdcall;
function IsSilencerAttached(wpn:pointer):boolean; stdcall;
function IsGLAttached(wpn:pointer):boolean; stdcall;
function GetInstalledUpgradesCount(wpn:pointer):cardinal; stdcall;
function GetInstalledUpgradeSection(wpn:pointer; index:cardinal):PChar; stdcall;
function GetSection(wpn:pointer):PChar; stdcall;
function GetHUDSection(wpn:pointer):PChar; stdcall;
function GetScopeStatus(wpn:pointer):cardinal; stdcall;
function GetSilencerStatus(wpn:pointer):cardinal; stdcall;
function GetGLStatus(wpn:pointer):cardinal; stdcall;
function GetCurrentScopeSection(wpn:pointer):PChar; stdcall;
procedure SetVisual(obj:pointer; name:pchar);stdcall;
procedure SetHUDSection(wpn:pointer; new_hud_section:PChar); stdcall;
//procedure SetCollimatorStatus(wpn:pointer; status:boolean); stdcall;


implementation
uses BaseGameData, GameWrappers, sysutils;
var
  GetCurrentHud_Func:cardinal;
  PlayHudAnim_Func:cardinal;
  SetWorldModelBoneStatus_internal1_func:cardinal;
  game_object_set_visual_name:cardinal;
  game_object_GetScriptGameObject:cardinal;

procedure SetHUDSection(wpn:pointer; new_hud_section:PChar); stdcall;
begin
  asm
    pushad
    pushfd
    mov edi, wpn
    //Поместим новую секцию в str_container
    push new_hud_section
    call str_container_dock
    test eax, eax
    je @finish
    mov ecx, [edi+$314]
    test ecx, ecx
    je @finish
    cmp eax, ecx
    je @finish
    //увеличим счетчик использования в новой строке худа и уменьшим в старой
    add [eax], 1
    sub [ecx], 1
    //Запишем новый худ в оружие
    mov [edi+$314], eax
    @finish:
    popfd
    popad
  end;
end;

procedure SetVisual (obj:pointer; name:pchar);stdcall;
begin
  //Будем мимикрировать под скрипт
  asm
    pushad
    pushfd

    mov ecx, obj
    add ecx, $000000E8
    call game_object_GetScriptGameObject
    mov ecx, eax
    push name
    call game_object_set_visual_name

    popfd
    popad
  end
end;

function GetInstalledUpgradeSection(wpn:pointer; index:cardinal):PChar; stdcall;
begin
  asm
    mov eax, wpn
    mov eax, [eax+$D8]
    mov ecx, index
    lea eax, [eax+4*ecx]
    mov eax, [eax]
    add eax, $10
    mov @result, eax;
  end;
end;

function GetInstalledUpgradesCount(wpn:pointer):cardinal; stdcall;
begin
  asm
    mov ecx, wpn
{    mov eax, [ecx+$DE]
    cmp eax, 0
    je @finish}
    mov eax, [ecx+$DC] //Указатель конца массива апгрейдов
    mov ecx, [ecx+$D8] //Указатель начала массива апгрейдов
    sub eax, ecx
    shr eax, 2
    mov @result, eax
    @finish:
  end;
end;

function GetCurrentScopeSection(wpn:pointer):PChar;
begin
  asm
    pushad
    pushfd
    mov @result, 0
    mov edi, wpn

    mov ebx, [edi+$6b0]
    cmp ebx, [edi+$6b4]
    je @finish    

    movzx eax, byte ptr [edi+$6bc]
    mov ebx, [edi+$6b0]
    mov ebx, [4*eax+ebx]
    add ebx, $10
    mov @result, ebx

    @finish:
    popfd
    popad
  end;
end;

function GetGLStatus(wpn:pointer):cardinal; stdcall;
begin
  asm
    mov eax, wpn
    mov eax, [eax+$46c]
    mov @result, eax
  end;
end;

function GetSilencerStatus(wpn:pointer):cardinal; stdcall;
begin
  asm
    mov eax, wpn
    mov eax, [eax+$468]
    mov @result, eax
  end;
end;

function GetScopeStatus(wpn:pointer):cardinal; stdcall;
begin
  asm
    mov eax, wpn
    mov eax, [eax+$464]
    mov @result, eax
  end;
end;

function GetSection(wpn:pointer):PChar; stdcall;
begin
  asm
    mov eax, [wpn]
    mov eax, [eax+$90]
    add eax, $10
    mov @result, eax
  end;
end;

function GetHUDSection(wpn:pointer):PChar; stdcall;
begin
  asm
    mov eax, wpn
    mov eax, [eax+$314]
    add eax, $10
    mov @result, eax
  end;
end;

function IsScopeAttached(wpn:pointer):boolean; stdcall;
begin
  asm
    mov eax, wpn
    mov eax, [eax+$460]
    test eax, 1
    jz @noaddon
    mov @result, 1
    jmp @finish
    @noaddon:
    mov @result, 0
    @finish:
  end;
end;

function IsSilencerAttached(wpn:pointer):boolean; stdcall;
begin
  asm
    mov eax, wpn
    mov eax, [eax+$460]
    test eax, 4
    jz @noaddon
    mov @result, 1
    jmp @finish
    @noaddon:
    mov @result, 0
    @finish:
  end;
end;

function IsGLAttached(wpn:pointer):boolean; stdcall;
begin
  asm
    mov eax, wpn
    mov eax, [eax+$460]
    test eax, 2
    jz @noaddon
    mov @result, 1
    jmp @finish
    @noaddon:
    mov @result, 0
    @finish:
  end;
end;

function GetCurrentHud(wpn: pointer):pointer; stdcall;
begin
  asm
    pushad
    pushf

    add wpn, $2e0
    mov ecx, wpn
    call GetCurrentHud_Func
    mov @result, eax

    popf
    popad
  end;
end;

procedure SetWeaponModelBoneStatus(wpn: pointer; bone_name:PChar; status:boolean); stdcall;
begin
  SetHudModelBoneStatus(wpn, bone_name, status);
  SetWorldModelBoneStatus(wpn, bone_name, status);
end;

procedure SetHudModelBoneStatus(wpn: pointer; bone_name:PChar; status:boolean); stdcall;
begin
  asm
    pushad
    pushfd

    //Получим основной объект attachable_hud_item
    push wpn
    call GetCurrentHud
    test eax, eax
    je @finish
    mov esi, eax
    //Поместим bone_name в str_container
    push bone_name
    call str_container_dock
    test eax, eax
    je @finish
    push eax
    push esp //сразу загнали в стек аргумент - указатель на указатель на объект-строку с именем кости

    //Далее найдем и вызовем функцию определения индекса кости
    mov eax, [esi+$0C]
    mov ecx, [eax]
    mov edx, [ecx+$10]
    push eax
    call edx
    add esp, 4
    movzx edi, ax
    cmp di, $FFFF
    je @finish

    //Теперь вызовем функцию установки статуса для найденной кости
    push 00
    movzx eax, status
    push eax
    push edi
    mov ecx, [esi+$0C]
    mov eax, [ecx]
    mov edx, [eax+$60]
    call edx

    @finish:
    popfd
    popad
  end;
end;

function PlayHudAnim(anim:PChar; wpn: pointer):pointer; stdcall;
begin
  asm
    pushad
    pushfd

    push anim
    call str_container_dock
    test eax, eax
    je @finish
    add [eax], 1
    push eax

    mov ebx, wpn
    push ebx
    push 0
    lea eax, [esp+8]
    push eax
    lea ecx, [ebx+$2E0]
    call PlayHudAnim_Func

    pop eax

    @finish:
    popfd
    popad
  end;
end;

procedure SetWorldModelBoneStatus(wpn: pointer; bone_name:PChar; status:boolean); stdcall;
begin
  asm
    pushad
    pushfd
    //Получим индекс кости в скелете
    push bone_name
    call str_container_dock
    test eax, eax
    je @finish
    push eax
    push esp //сохранили указатель на указатель на объект-строку с именем кости

    mov edi, wpn
    test edi, edi
    je @before_finish
    mov esi, [edi+$178]
    test esi, esi
    je @before_finish
    push esi
    call SetWorldModelBoneStatus_internal1_func
    add esp, 4  //снимаем со стека аргумент функции
    mov esi, eax
    push esi
    mov edx, [esi]
    mov edx, [edx+$10]
    call edx  //получаем индекс интересующей нас кости (в ax)
    add esp, 4  //снимаем нашу сохраненную "строку"
    movzx ebx, ax
    cmp ebx, $FFFF //Проверяем, обнаружена ли такая кость вообще
    je @finish

    //получим адрес нашей функции, показывающей/скрывающей кость
    mov edx, [esi]
    mov edx, [edx+$60]
    //а теперь выполним операцию сокрытия\отображения
    movzx eax, status


    {neg eax
    add eax, 1
    push eax
    push 01
    push ebx}

    push 01
    push eax
    push ebx

    mov ecx, esi
    call edx

    jmp @finish

    @before_finish:
    add esp, 8

    @finish:
    popfd
    popad
  end;
end;

function Init():boolean;
begin
  result:=false;
  GetCurrentHud_Func:=xrGame_addr+$2F97A0;
  PlayHudAnim_Func:=xrGame_addr+$2F9880;
  SetWorldModelBoneStatus_internal1_func:=xrGame_addr+$3483C0;
  game_object_set_visual_name:=xrGame_addr+$1BFF60;
  game_object_GetScriptGameObject:= xrGame_addr+$27FD40;  

  result:=true;
end;

end.
