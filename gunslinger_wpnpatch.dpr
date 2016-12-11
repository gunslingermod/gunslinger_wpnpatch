library gunslinger_wpnpatch;
uses windows;

{$R *.res}
const
  xrGame:PChar='xrGame';
  xrCore:PChar='xrCore';
  ///////////////////////////////////////////////////////
  //Младшие слова адресов vftable различных классов объектов, надо для "самопальной" RTTI
  W_BM16:word=$4744;

  ///////////////////////////////////////////////////////
  anm_reload:PChar='anm_reload';
  anm_reload_w_gl:PChar='anm_reload_w_gl';
  anm_reload_empty:PChar='anm_reload_empty';
  anm_reload_empty_w_gl:PChar='anm_reload_empty_w_gl';
  anm_changecartridgetype:PChar='anm_changecartridgetype';
  anm_changecartridgetype_w_gl:PChar='anm_changecartridgetype_w_gl';

  sndReload:PChar='sndReload';
  sndReloadEmpty:PChar='sndReloadEmpty';
  snd_reload_empty:PChar='snd_reload_empty';
  snd_changecartridgetype:PChar = 'snd_changecartridgetype';
  sndChangeCartridgeType:PChar = 'sndChangeCartridgeType';

  //на будущее - можно реализовать, только не забыть при выключение перезарядки и лишний патрон
  snd_jamned:PChar = 'snd_jamned';
  sndJamned:PChar = 'sndJamned';
  hud:PChar='hud';

  visual:PChar='visual';
  //////////////////////////////////////////////////////
var
  //Адреса врезок
  xrGame_addr:cardinal;
  xrCore_addr:cardinal;
  hndl:cardinal;
  reload_pistols_patch_addr:cardinal;
  reload_nogl_patch_addr:cardinal;
  reload_withgl_patch_addr:cardinal;
  reload_empty_sound_load_addr:cardinal;
  reload_sound_select_patch_addr:cardinal;
  reload_process_remembercount_addr:cardinal;
  reload_process_addcartridge_addr:cardinal;

  cweaponmagazined_netspawn_patch_addr:cardinal;
  cweaponmagazined_loaddata_in_netspawn_patch_addr:cardinal;

  cweaponmagazined_netdestroy_patch_addr:cardinal;
  cweaponmagazined_netdestroy_clipped_function_addr:cardinal;
  scope_attach_callback_addr:cardinal;
  upgrade_weapon_addr:cardinal;
  //игровые глобальные переменные/объекты
  game_ini_ptr:cardinal;
  str_container_ptr:cardinal;

  //Указатели на игровые функции
  CIniFile_ReadStringByObjectStringPtr:cardinal;
  str_container_dock_ptr:cardinal;
  game_object_set_visual_name:cardinal;
  game_object_GetScriptGameObject:cardinal;
  alife_object_ptr:cardinal;

function WriteJump(var write_addr:cardinal; dest_addr:cardinal; addbytescount:cardinal=0; writecall:boolean=false):boolean;
var offsettowrite:cardinal;
    rb:cardinal;
    opcode:char;
begin
  result:=true;
  if writecall then opcode:=CHR($E8) else opcode:=CHR($E9);
  offsettowrite:=dest_addr-write_addr-5;
  writeprocessmemory(hndl, PChar(write_addr), @opcode, 1, rb);
  if rb<>1 then result:=false;
  writeprocessmemory(hndl, PChar(write_addr+1), @offsettowrite, 4, rb);
  if rb<>4 then result:=false;
  write_addr:=write_addr+addbytescount;
end;

function nop_code(addr:cardinal; count:cardinal):boolean;
const opcode:char=CHR($90);
var rb:cardinal;
    i:cardinal;
begin
  result:=true;
  for i:=addr to addr+count-1 do begin
    writeprocessmemory(hndl, PChar(i), @opcode, 1, rb);
    if rb<>1 then result:=false;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
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


////////////////////////////////////////////////////////////////////////////////
procedure AK74ReloadNoGLAnimationSelector;
begin
  asm
    //Если пусто - то проигрываем всегда анимацию для пустого магазина
    cmp [esi+$690], 0
    je @empty
    //Если идет смена патрона, и магазин непуст - играем уникальную аниму
    cmp byte ptr [esi+$6C7], $FF
    jne @changecartridgetype
    //отыгрываем стандарт в противном случае
    push anm_reload
    jmp @finish
  @changecartridgetype:
    push anm_changecartridgetype
    jmp @finish
  @empty:
    push anm_reload_empty
  @finish:
    jmp reload_nogl_patch_addr
  end;
end;

procedure AK74ReloadWithGLAnimationSelector;
begin
  asm
    //Если пусто - то проигрываем всегда анимацию для пустого магазина
    cmp [esi+$690], 0
    je @empty
    //Если идет смена патрона, и магазин непуст - играем уникальную аниму
    cmp byte ptr [esi+$6C7], $FF
    jne @changecartridgetype
    //отыгрываем стандарт в противном случае
    push anm_reload_w_gl
    jmp @finish
  @changecartridgetype:
    push anm_changecartridgetype_w_gl
    jmp @finish
  @empty:
    push anm_reload_empty_w_gl
  @finish:
    jmp reload_withgl_patch_addr
  end;
end;

procedure PistolReloadAnimationSelector;
begin
  asm
    //проверяем, не смена ли это типа патрона
    cmp byte ptr [esi+$6C7], $FF
    jne @changecartridgetype
    push anm_reload
    jmp @finish
  @changecartridgetype:
    push anm_changecartridgetype
  @finish:
    jmp reload_pistols_patch_addr
  end;
end;

function PatchWeaponReloadAnimationCall:boolean;
begin
  result:=false;
  reload_nogl_patch_addr:=xrGame_addr+$2CCFB2;
  reload_withgl_patch_addr:=xrGame_addr+$2D18AB;
  reload_pistols_patch_addr:=xrGame_addr+$2C545A;
  if not WriteJump(reload_nogl_patch_addr, cardinal(@AK74ReloadNoGLAnimationSelector), 5) then exit;
  if not WriteJump(reload_withgl_patch_addr, cardinal(@AK74ReloadWithGLAnimationSelector), 5) then exit;
  if not WriteJump(reload_pistols_patch_addr, cardinal(@PistolReloadAnimationSelector), 5) then exit;
  result:=true;
end;
////////////////////////////////////////////////////////////////////////////////

procedure WeaponSoundLoader;
begin
  asm
    //change cartridge type sound
    push ecx
    push 01
    push sndChangeCartridgeType
    push snd_changecartridgetype
    push ebx
    //rel empty sound
    push ecx
    push 01
    push sndReloadEmpty
    push snd_reload_empty
    push ebx
    //call it
    mov ecx, edi
    mov eax, xrGame_addr
    add eax, $2FB430
    call eax
    mov ecx, edi
    mov eax, xrGame_addr
    add eax, $2FB430
    call eax

    push sndReload
    jmp reload_empty_sound_load_addr
  end;
end;

function PatchWeaponSoundLoad:boolean;
begin
  result:=false;
  reload_empty_sound_load_addr:=xrGame_addr+$2CFADE;
  if not WriteJump(reload_empty_sound_load_addr, cardinal(@WeaponSoundLoader), 5) then exit;
  result:=true;
end;

////////////////////////////////////////////////////////////////////////////////
procedure WeaponReloadSoundSelector;
begin
  asm
    cmp[esi+$df], 0
    je @empty
    cmp byte ptr [esi+$116], $FF
    jne @changecartridgetype
    
    push sndReload
    jmp @final

    @changecartridgetype:
    push sndChangeCartridgeType
    jmp @final

    @empty:
    push sndReloadEmpty
    
    @final:
    jmp reload_sound_select_patch_addr
  end;
end;

function PatchReloadSoundSelect:boolean;
begin
  result:=false;
  reload_sound_select_patch_addr:=xrGame_addr+$2CCE6F;
  if not WriteJump(reload_sound_select_patch_addr, cardinal(@WeaponReloadSoundSelector), 5) then exit;
  result:=true;
end;
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
//Эти правки связаны с остающимся в патроннике патроном при неполной перезарядке
procedure RememberAmmoInMagCount;
begin
  asm
    lea ecx, [esi-$2E0]
    push ebx
    //сохраним число патронов в магазине перед релоадом
    //разбиваем на 2 слова, чтобы 4 байта влезли в 2 трехбайтовые дыры
    mov ebx, [ecx+$690]
    mov [ecx+$6A2], bx
    shr ebx,16
    mov [ecx+$6BE], bx
    //запишем флаг смены типа патронов при текущей перезарядке
    mov bl, [ecx+$6C7]
    mov [ecx+$6A1], bl
    pop ebx
    jmp reload_process_remembercount_addr
  end;
end;

procedure AddCartridgeIfNeeded;
begin
  asm
    push ecx
    push ebx
    //считаем вместимость магазина
    mov ebx, [esi+$694]
    //если у нас двустволка - то ничего не делаем
    mov cx, W_BM16
    cmp word ptr [esi], cx
    je @finish
    //Если мы меняем тип боеприпасов - то у нас в любом случае патрон в патроннике остаться не должен
    cmp byte ptr [esi+$6A1], $FF
    jne @finish
    //читаем число патронов в оружии перед релоадом
    mov cx, [esi+$6BE]
    shl ecx, 16
    add cx, word ptr [esi+$6A2]
    //если оружие было пустое - доп. патрону в патроннике взяться неоткуда
    cmp ecx, 0
    je @finish
    //а если полное, то доп. патрон должен остаться. Обманываем игру, сообщая, что в магазин входит на 1 патрон больше
    add ebx, 1
    @finish:
    cmp eax, ebx
    pop ebx
    pop ecx
    jmp reload_process_addcartridge_addr
  end;
end;

function PatchReloadMagProcess:boolean;
var rb:cardinal;
    debug_byte:byte;
    debug_addr:cardinal;
begin
  result:=false;
  ////////////////////////////////////////////////////
  //отключаем моментальную смену типа патронов при перезарядке, когда у нас не хватает патронов текущего типа до полного магазина
  //TODO: может, сделать это же для остальных видов оружия?
  //if not nop_code(xrGame_addr+$2D0183, 6) then exit;
  debug_byte:=$C7;
  debug_addr:=xrGame_addr+$2D0185;
  writeprocessmemory(hndl, PChar(debug_addr), @debug_byte, 1, rb);
  if rb<>1 then exit;
  ////////////////////////////////////////////////////
  
  reload_process_remembercount_addr:=xrGame_addr+$2CCDA0;
  reload_process_addcartridge_addr:=xrGame_addr+$2D11DA;
  if not WriteJump(reload_process_remembercount_addr, cardinal(@RememberAmmoInMagCount), 6) then exit;
  if not WriteJump(reload_process_addcartridge_addr, cardinal(@AddCartridgeIfNeeded), 6) then exit;
  result:=true;
end;


////////////////////////////////////////////////////////////////////////////////
//Здесь все, что связано с выбором визуала и худа оружия 

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

procedure CWeaponMagazined_Load_Data_In_NetSpawn_Patch();
begin
  asm
    pushad
    pushfd
    //Загрузим тип прицела, установленный ранее
    mov eax, [esp+$38]
    test eax, eax
    je @finish
    movzx eax, byte ptr [eax+$1bc]
    shr eax, 3
    //проверим, поддерживается ли вообще прицел с таким индексом данным оружием
    mov ebx, [ecx+$6b4]
    sub ebx, [ecx+$6b0]
    lea edx, [eax*4]
    cmp edx, ebx
    jge @finish
    //Запишем тип прицела
    mov [ecx+$6bc], al
    @finish:
    //на всякий сбросим "лишние" данные в байте флагов аддонов
    mov eax, [esp+$38]
    and byte ptr [eax+$1bc], 3
    popfd
    popad


    fstp dword ptr [esi+$4C0]
    jmp cweaponmagazined_loaddata_in_netspawn_patch_addr
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

procedure CWeaponMagazined_NetDestroy_Patch();

begin
  asm
    pushad
    pushfd

    //Получим серверный объект
    push ecx
    movzx eax, word ptr [ecx+$18c]
    push eax
    call get_server_object_by_id
    pop ecx

    test eax, eax
    je @finish

    //Запихнем в старшие 5 бит байта с флагами аддонов у серверного объекта номер текущего типа прицелов
    mov dl, [ecx+$6bc]
    shl dl,3
    mov bl, [ecx+$460]
    and bl, $7
    or dl, bl
    mov [eax+$1bc], dl

    @finish:
    popfd
    popad

    call cweaponmagazined_netdestroy_clipped_function_addr
    jmp cweaponmagazined_netdestroy_patch_addr
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


function PatchChangingHudVisual:boolean;
begin
  result:=false;
  cweaponmagazined_loaddata_in_netspawn_patch_addr:=xrGame_addr+$2C1200;
  if not WriteJump(cweaponmagazined_loaddata_in_netspawn_patch_addr, cardinal(@CWeaponMagazined_Load_Data_In_NetSpawn_Patch),6) then exit;


  cweaponmagazined_netspawn_patch_addr:=xrGame_addr+$2C120B;
  if not WriteJump(cweaponmagazined_netspawn_patch_addr, cardinal(@CWeaponMagazined_NetSpawn_Patch),6) then exit;

  cweaponmagazined_netdestroy_patch_addr:=xrGame_addr+$2BEFE4;
  cweaponmagazined_netdestroy_clipped_function_addr:=xrGame_addr+$2C4770;
  if not WriteJump(cweaponmagazined_netdestroy_patch_addr, cardinal(@CWeaponMagazined_NetDestroy_Patch), 5) then exit;

  scope_attach_callback_addr:=xrGame_addr+$2CEE33;
  if not WriteJump(scope_attach_callback_addr, cardinal(@AttachScope_Callback_Patch), 7) then exit;

  upgrade_weapon_addr:=xrGame_addr+$2D09D6;
  if not WriteJump(upgrade_weapon_addr, cardinal(@Upgrade_Weapon_Patch), 5) then exit;

  result:=true;
end;

////////////////////////////////////////////////////////////////////////////////


begin
  hndl:=GetCurrentProcess;
  xrGame_addr := GetModuleHandle(xrGame);
  xrCore_addr := GetModuleHandle(xrCore);
  if (xrGame_addr = 0) or (xrCore_addr = 0) then exit;
  xrGame_addr := (xrGame_addr shr 16) shl 16;
  xrCore_addr := (xrCore_addr shr 16) shl 16;

  game_ini_ptr:=xrGame_addr+$5127E8;
  str_container_ptr:=xrGame_addr+$512814;

  //Сразу получим адреса стандартных игровых функций, врапперы для которых написаны выше
  CIniFile_ReadStringByObjectStringPtr:=xrCore_addr+$2BE0;
  str_container_dock_ptr:=xrCore_addr+$20690;

  game_object_set_visual_name:=xrGame_addr+$1BFF60;
  game_object_GetScriptGameObject:= xrGame_addr+$27FD40;
  alife_object_ptr:=xrGame_addr+$99450;

  if not PatchWeaponReloadAnimationCall then exit;
  if not PatchWeaponSoundLoad then exit;
  if not PatchReloadSoundSelect then exit;
  if not PatchReloadMagProcess then exit;
  if not PatchChangingHudVisual then exit;
end.
