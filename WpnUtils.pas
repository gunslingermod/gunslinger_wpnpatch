unit WpnUtils;

interface
function Init():boolean;
//function GetPositionVector(obj:pointer):pointer;
//function GetCurrentHud(wpn: pointer):pointer; stdcall;
procedure PlayHudAnim(wpn: pointer; anim_name:PChar; immediatly:boolean); stdcall;
procedure SetWorldModelBoneStatus(wpn: pointer; bone_name:PChar; status:boolean); stdcall;
procedure SetHudModelBoneStatus(wpn: pointer; bone_name:PChar; status:boolean); stdcall;
procedure SetWeaponModelBoneStatus(wpn: pointer; bone_name:PChar; status:boolean); stdcall;
procedure SetWeaponMultipleBonesStatus(wpn: pointer; bones:PChar; status:boolean); stdcall;
function IsScopeAttached(wpn:pointer):boolean; stdcall;
function IsSilencerAttached(wpn:pointer):boolean; stdcall;
function IsGLAttached(wpn:pointer):boolean; stdcall;
function IsGLEnabled(wpn:pointer):boolean; stdcall;       //перед вызовом - обязательно убедиться, что гранатомет на оружии вообще ЕСТЬ! Некоторые классы оружия не поддерживают гранатомет, и тогда функция может возвратить мусор или даже сгенерировать вылет!
function IsWeaponJammed(wpn:pointer):boolean; stdcall;
function CurrentQueueSize(wpn:pointer):integer; stdcall;
function GetInstalledUpgradesCount(wpn:pointer):cardinal; stdcall;
function GetInstalledUpgradeSection(wpn:pointer; index:cardinal):PChar; stdcall;
function GetSection(wpn:pointer):PChar; stdcall;
function GetHUDSection(wpn:pointer):PChar; stdcall;
function GetAmmoTypeChangingStatus(wpn:pointer):byte; stdcall;
procedure SetAmmoTypeChangingStatus(wpn:pointer; status:byte); stdcall;
function GetScopeStatus(wpn:pointer):cardinal; stdcall;
function GetSilencerStatus(wpn:pointer):cardinal; stdcall;
function GetGLStatus(wpn:pointer):cardinal; stdcall;
function GetCurrentScopeSection(wpn:pointer):PChar; stdcall;
procedure SetWpnVisual(obj:pointer; name:pchar);stdcall;
procedure SetHUDSection(wpn:pointer; new_hud_section:PChar); stdcall;
function GetAmmoInMagCount(wpn:pointer):integer; stdcall;
function GetOwner(wpn:pointer):pointer; stdcall;
function IsAimNow(wpn:pointer):boolean; stdcall;
function GetClassName(wpn:pointer):string; stdcall;
function WpnCanShoot(cls:PChar):boolean;stdcall;
function GetCurrentState(wpn:pointer):integer; stdcall;
procedure MagazinedWpnPlaySnd(wpn:pointer; sndLabel:PChar); stdcall;
function GetLevelVertexID(wpn:pointer):cardinal; stdcall
function GetGameVertexID(wpn:pointer):cardinal; stdcall
function GetSilencerSection(wpn:pointer):PChar; stdcall;
procedure DetachAddon(wpn:pointer; addon_type:integer);stdcall;
function GetGLSection(wpn:pointer):PChar; stdcall;
procedure SetShootLockTime(wpn:pointer; time:single);stdcall;
function GetShootLockTime(wpn:pointer):single;stdcall;
procedure SetCurrentScopeType(wpn:pointer; scope_type:byte); stdcall;
function GetCurrentCondition(wpn:pointer):single; stdcall;
function GetPosition(wpn:pointer):pointer; stdcall;


//procedure SetCollimatorStatus(wpn:pointer; status:boolean); stdcall;


implementation
uses BaseGameData, GameWrappers, sysutils, ActorUtils;
var
  GetCurrentHud_Func:cardinal;
  PlayHudAnim_Func:cardinal;
  SetWorldModelBoneStatus_internal1_func:cardinal;
  game_object_set_visual_name:cardinal;

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

procedure SetWpnVisual (obj:pointer; name:pchar);stdcall;
begin
  //Будем мимикрировать под скрипт
  asm
    pushad
    pushfd

    add obj, $000000E8
    push obj
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

function GetAmmoInMagCount(wpn:pointer):integer; stdcall;
begin
  asm
    pushad
    pushfd
    mov ebx, wpn

    push ebx
    call GetGLStatus
    cmp eax, 0
    je @use_main
    push ebx
    call IsGLEnabled
    cmp al, 0
    jne @use_alter

    @use_main:
    mov edx, [ebx+$6CC]
    sub edx, [ebx+$6C8]
    jmp @divide

    @use_alter:
    mov edx, [ebx+$7F0]
    sub edx, [ebx+$7EC]
    jmp @divide

    @divide:
    movzx eax, dx
    shr edx, 16
    mov ebx, $3c;
    div bx

    mov @result, eax

    popfd
    popad
  end;
end;

function IsAimNow(wpn:pointer):boolean; stdcall;
begin
  asm
    mov ecx, wpn
    mov al, [ecx+$496]
    mov @result, al
  end;
end;

function GetOwner(wpn:pointer):pointer; stdcall;
begin
  asm
    mov eax, wpn
    mov eax, [eax+$19c]
    mov @result, eax
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

function GetAmmoTypeChangingStatus(wpn:pointer):byte; stdcall;
begin
  asm
    mov eax, wpn
    mov al, byte ptr [eax+$6C7]
    mov @result, al
  end;
end;

procedure SetAmmoTypeChangingStatus(wpn:pointer; status:byte); stdcall;
begin
  asm
    push eax
    push ecx

    mov eax, wpn
    mov cl, status
    mov byte ptr [eax+$6C7], cl

    pop ecx
    pop eax
  end;
end;

function IsWeaponJammed(wpn:pointer):boolean; stdcall;
begin
  asm
    mov eax, wpn
    mov al, [eax+$45A]
    mov @result, al
  end;
end;

function CurrentQueueSize(wpn:pointer):integer; stdcall;
begin
  asm
    mov eax, wpn
    mov eax, [eax+$770]
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

function IsGLEnabled(wpn:pointer):boolean; stdcall;
begin
  asm
    mov @result, 0
    mov eax, wpn
    cmp byte ptr [eax+$7F8], 0;
    je @finish
    mov @result, 1
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

procedure SetWeaponMultipleBonesStatus(wpn: pointer; bones:PChar; status:boolean); stdcall;
var
  bones_string:string;
  bone:string;
begin
  bones_string:=bones;
  while (GetNextSubStr(bones_string, bone, ',')) do begin
    SetWeaponModelBoneStatus(wpn, PChar(bone), status);
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

procedure PlayHudAnim(wpn: pointer; anim_name:PChar; immediatly:boolean); stdcall;
begin
  asm
    pushad
    pushfd

    push anim_name
    call str_container_dock
    test eax, eax
    je @finish
    add [eax], 1
    push eax
    mov eax, esp


    mov ebx, wpn
    lea ecx, [ebx+$2E0]

    push 0
    push 0
    movzx edx, immediatly
    push edx              //резкий ли будет переход к ней
    push eax              //указатель на имя анимы
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
    mov esi, [edi+$178]   //Помещаем pVisual в esi
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

function GetClassName(wpn:pointer):string; stdcall;
var i:cardinal;
    c:char;
begin
  result:='';
  for i:=7 downto 0 do begin
    asm
      push eax
      mov eax, wpn
      add eax, $F0
      add eax, i
      mov al, [eax]
      mov c, al
      pop eax
    end;
    result:=result+c;
  end;
  result:=trim(result);
end;

function WpnCanShoot(cls:PChar):boolean;stdcall;
begin
//  result:=not((cls='G_RGD5_S') or (cls='II_BOLT') or (cls='DET_SIMP') or (cls='DET_ADVA') or (cls = 'DET_ELIT') or (cls = 'G_F1_S') or (cls = 'DET_ELIT') or (cls = 'WP_BINOC') or (cls = 'WP_KNIFE') or (cls = 'ARTEFACT') or (cls='D_FLARE'));
  result:=(cls='WP_AK74') or (cls='WP_LR300') or (cls='WP_BM16') or (cls='WP_PM') or (cls='WP_GROZA') or (cls='WP_SVD') or (cls='WP_HPSA') or (cls='WP_ASHTG') or (cls='WP_RG6') or (cls='WP_RPG7') or (cls='WP_VAL') or (cls='WP_VAL');
end;

function GetCurrentState(wpn:pointer):integer; stdcall;
begin
  asm
    mov eax, wpn
    mov eax, [eax+$2E4]
    mov @result, eax
  end
end;

procedure MagazinedWpnPlaySnd(wpn:pointer; sndLabel:PChar); stdcall;
begin
  asm
    pushad
    pushfd

    mov esi, wpn
    lea ecx, [esi+$2e0]
    mov edx, [ecx]
    mov edx, [edx+$30]

    lea eax, [esi+$5b1]
    push eax
    push sndLabel
    call edx

    popfd
    popad
  end;
end;

////////////////////////////////////////////////////////////////////////////////

procedure DetachGLRight(wpn:pointer);stdcall;
//детач с учетом возможной активности подствола
var addon_name:PChar;
begin
  addon_name:=GetGLSection(wpn);
  if addon_name = nil then begin;
    Log('WpnUtils.DetachGLRight: Weapon has no GL!', true);
    exit;
  end;
  asm
    pushad
      push addon_name
      call ActorUtils.CreateObjectToActor

      mov esi, wpn
      and [esi+$460], $FFFFFFFD
      cmp byte ptr [esi+$7f8], 0
      je @noactive_gl
      mov eax, [esi]
      mov edx, [eax+$20c]
      push 01
      mov ecx, esi
      call edx

      mov ecx, esi
      mov eax, xrgame_addr
      add eax, $2d3740
      call eax

      @noactive_gl:
      mov ebx, xrgame_addr
      add ebx, $2BD930
      mov ecx, esi
      call ebx                  //call CWeapon::UpdateAddonsVisibility

      cmp [esi+$2E4], 0
      jne @finish
      mov eax, [esi+$2e0]
      mov edx, [eax+$60]
      lea ecx, [esi+$2e0]
      call edx
      @finish:
      popad
  end;
end;


procedure DetachAddon(wpn:pointer; addon_type:integer);stdcall;
var addon_name:PChar;
begin
  case addon_type of
    1:addon_name:=game_ini_read_string(GetCurrentScopeSection(wpn), 'scope_name');
    4:addon_name:=GetSilencerSection(wpn);
    2: begin
        DetachGLRight(wpn);
        exit;
       end;
  else
    Log('WpnUtils.DetachAddon: Invalid addon type!', true);
    exit;
  end;
  if addon_name = nil then exit;
  asm
    pushad
      push addon_name
      call ActorUtils.CreateObjectToActor

      mov esi, wpn
      mov eax, addon_type
      not eax
      and [esi+$460], eax


      mov ebx, xrgame_addr
      add ebx, $2BD930
      mov ecx, esi
      call ebx                  //call CWeapon::UpdateAddonsVisibility

      mov eax, [esi]
      mov edx, [eax+$158]
      mov ecx, esi
      call edx

      cmp addon_type, 1
      jne @finish
      mov byte ptr [esi+$6bc], 0

      @finish:
    popad
  end;
end;

////////////////////////////////////////////////////////////////////////////////

function GetSilencerSection(wpn:pointer):PChar; stdcall;
begin
  asm
    push eax

    mov @result, 0
    mov eax, wpn
    mov eax, [eax+$474]
    cmp eax, 0
    je @finish
    add eax, $10
    mov @result, eax
    
    @finish:
    pop eax
  end;
end;


function GetGLSection(wpn:pointer):PChar; stdcall;
begin
  asm
    push eax

    mov @result, 0
    mov eax, wpn
    mov eax, [eax+$478]
    cmp eax, 0
    je @finish
    add eax, $10
    mov @result, eax
                               
    @finish:
    pop eax
  end;
end;

procedure SetShootLockTime(wpn:pointer; time:single);stdcall;
begin
  asm
    push eax
    push eax
    movss [esp], xmm0

    mov eax, wpn
    movss xmm0, time
    movss [eax+$390], xmm0

    movss xmm0, [esp]
    add esp, 4
    pop eax
  end;
end;

function Init():boolean;
begin
  GetCurrentHud_Func:=xrGame_addr+$2F97A0;
  PlayHudAnim_Func:=xrGame_addr+$2F9A60;
  SetWorldModelBoneStatus_internal1_func:=xrGame_addr+$3483C0;
  game_object_set_visual_name:=xrGame_addr+$1BFF60;

  result:=true;
end;

procedure SetCurrentScopeType(wpn:pointer; scope_type:byte); stdcall;
begin
  asm
    push eax
    push ecx

    mov eax, wpn
    mov cl, scope_type
    mov byte ptr [eax+$6BC], cl

    pop ecx
    pop eax
  end;
end;

function GetShootLockTime(wpn:pointer):single;stdcall;
begin
  asm
    push eax
    push eax
    movss [esp], xmm0

    mov eax, wpn
    movss xmm0, [eax+$390]
    movss @result, xmm0

    movss xmm0, [esp]
    add esp, 4
    pop eax
  end;
end;


function GetCurrentCondition(wpn:pointer):single; stdcall;
asm
    push eax
    movss [esp], xmm0

    mov eax, wpn
    movss xmm0, [eax+$AC]
    movss @result, xmm0

    movss xmm0, [esp]
    add esp, 4
end;

function GetLevelVertexID(wpn:pointer):cardinal; stdcall
asm
  mov eax, wpn
  mov eax, [eax+$208]
  mov eax, [eax]
  mov @result, eax
end;

function GetGameVertexID(wpn:pointer):cardinal; stdcall
asm
  mov eax, wpn
  mov eax, [eax+$208]
  movzx eax, word ptr [eax+4]
  mov @result, eax
end;

function GetPosition(wpn:pointer):pointer; stdcall;
asm
  mov eax, wpn
  add eax, $168
  mov @result, eax
end;

end.
