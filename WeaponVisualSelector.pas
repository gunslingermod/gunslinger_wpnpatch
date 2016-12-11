unit WeaponVisualSelector;

interface
function Init:boolean;

implementation
uses BaseGameData, GameWrappers;
const
  hud:PChar='hud';
  visual:PChar='visual';

var
  cweaponmagazined_netspawn_patch_addr:cardinal;
  scope_attach_callback_addr:cardinal;
  upgrade_weapon_addr:cardinal;

procedure WeaponVisualChanger();
//в действительности - один аргумент, адрес оружия, с которым будем работать
begin
  asm
    pushad
    pushfd
    //извлечем аргумент-оружие и на всякий проверим на NULL
    mov edi, [esp+$28]
    test edi, edi
    je @finish
    //посмотрим, нужно ли вообще проводить какие-то манипуляции
    //прочитаем scope_status и убедимся, что там 2 - прицел съемный
    mov ebx, [edi+$464]
    cmp ebx, 2
    jne @finish
    //Убедимся, что на оружие можем ставить более одного прицела
    mov ebx, [edi+$6b0]
    cmp ebx, [edi+$6b4]
    je @finish

    //получим в ebx строку-объект, содержащую текущую секцию прицела
    movzx eax, byte ptr [edi+$6bc]
    lea ebx, [4*eax+ebx]
    //прочитаем название секции худа оружия для данного прицела
    push hud
    push ebx
    call game_ini_read_string_by_object_string
    //Найдем её в str_container'e
    push eax
    call str_container_dock
    test eax, eax
    je @finish

    //увеличим счетчик использования в новой строке худа и уменьшим в старой
    add [eax], 1
    mov ecx, [edi+$314]
    test ecx, ecx
    je @writehud
    sub [ecx], 1

    //Запишем новый худ в оружие
    @writehud:
    mov [edi+$314], eax

    //Теперь установим оружию новый визуал
    push visual
    push ebx
    call game_ini_read_string_by_object_string
    test eax, eax
    je @finish

    push eax
    push edi
    call set_weapon_visual

    @finish:
    popfd
    popad
    ret 4
  end;
end;

procedure CWeaponMagazined_NetSpawn_Patch();
begin
  asm
    pushad
    pushfd

    push esi
    call WeaponVisualChanger

    popfd
    popad

    test edi, edi
    mov [esp+$10], eax

    jmp cweaponmagazined_netspawn_patch_addr
    //ret 4
  end;
end;

procedure AttachScope_Callback_Patch();
begin
  asm
    or byte ptr [ebp+$460],01
    pushad
    pushfd
    push ebp
    call WeaponVisualChanger
    popfd
    popad
    jmp scope_attach_callback_addr
  end;
end;

procedure Upgrade_Weapon_Patch();
begin
  asm
    pushad
    pushfd
    push ebx
    call WeaponVisualChanger
    popfd
    popad
    push ecx
    lea edx, [esp+$1c]
    jmp upgrade_weapon_addr
  end;
end;


function Init:boolean;
begin
  result:=false;

  cweaponmagazined_netspawn_patch_addr:=xrGame_addr+$2C120B;
  if not WriteJump(cweaponmagazined_netspawn_patch_addr, cardinal(@CWeaponMagazined_NetSpawn_Patch),6) then exit;

  scope_attach_callback_addr:=xrGame_addr+$2CEE33;
  if not WriteJump(scope_attach_callback_addr, cardinal(@AttachScope_Callback_Patch), 7) then exit;

  upgrade_weapon_addr:=xrGame_addr+$2D09D6;
  if not WriteJump(upgrade_weapon_addr, cardinal(@Upgrade_Weapon_Patch), 5) then exit;

  result:=true;
end;

end.
