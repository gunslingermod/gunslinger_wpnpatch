unit GameWrappers;



interface
  function Init:boolean;
  function str_container_dock(str:PChar):pointer; stdcall;
  procedure set_weapon_visual(weapon_addr:cardinal; name:pchar);stdcall;
  procedure unload_magazine(weapon_addr:cardinal);stdcall;
  function game_ini_read_string_by_object_string(section:PChar; key:PChar):PChar;stdcall;
  function get_server_object_by_id(id:cardinal):pointer;stdcall;

implementation
uses BaseGameData;
var
  //игровые глобальные переменные/объекты
  game_ini_ptr:cardinal;
  str_container_ptr:cardinal;

  //Указатели на игровые функции
  CIniFile_ReadStringByObjectStringPtr:cardinal;
  str_container_dock_ptr:cardinal;
  
  game_object_set_visual_name:cardinal;
  game_object_GetScriptGameObject:cardinal;
  alife_object_ptr:cardinal;
  cweaponmagazined_unload_mag:cardinal;

function Init:boolean;
begin
  game_ini_ptr:=xrGame_addr+$5127E8;
  str_container_ptr:=xrGame_addr+$512814;

  //Сразу получим адреса стандартных игровых функций, врапперы для которых написаны выше
  CIniFile_ReadStringByObjectStringPtr:=xrCore_addr+$2BE0;
  str_container_dock_ptr:=xrCore_addr+$20690;

  game_object_set_visual_name:=xrGame_addr+$1BFF60;
  game_object_GetScriptGameObject:= xrGame_addr+$27FD40;
  alife_object_ptr:=xrGame_addr+$99450;
  cweaponmagazined_unload_mag:=xrGame_addr+$2CF660;

  result:=true;
end;


function str_container_dock(str:PChar):pointer; stdcall
begin
  asm
    pushad
    pushfd

    push str
    mov ecx, str_container_ptr
    mov ecx, [ecx]
    mov ecx, [ecx]
    call str_container_dock_ptr
    mov @Result, eax

    popfd
    popad
  end
end;


procedure set_weapon_visual (weapon_addr:cardinal; name:pchar);stdcall;
begin
  //Будем мимикрировать под скрипт
  asm
    pushad
    pushfd

    mov ecx, weapon_addr
    add ecx, $000000E8
    call game_object_GetScriptGameObject
    mov ecx, eax
    push name
    call game_object_set_visual_name

    popfd
    popad
  end
end;

function game_ini_read_string_by_object_string(section:PChar; key:PChar):PChar;stdcall;

begin
  asm
    pushad
    pushfd

    push key
    push section
    mov ecx, game_ini_ptr
    mov ecx, [ecx]
    mov ecx, [ecx]
    call CIniFile_ReadStringByObjectStringPtr
    mov @result, eax

    popfd
    popad
  end
end;

function get_server_object_by_id(id:cardinal):pointer;stdcall;
//!!Changes ECX!!
begin
  asm
    pushad
    pushfd

    mov ecx, xrGame_addr
    mov ecx, [ecx+$64DA98]
    mov ecx, [ecx+$14]

    push id
    push ecx
    call alife_object_ptr
    add esp,8
    mov @Result, eax

    popfd
    popad
  end
end;

procedure unload_magazine(weapon_addr:cardinal);stdcall;
begin
  asm
    pushad
    pushfd

    push 01
    mov ecx, weapon_addr
    call cweaponmagazined_unload_mag

    popfd
    popad
  end;
end;


end.
