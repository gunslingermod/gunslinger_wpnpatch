unit WeaponDataSaveLoad;

interface
function Init:boolean;

implementation
uses GameWrappers, BaseGameData;

var
  cweaponmagazined_loaddata_in_netspawn_patch_addr:cardinal;
  cweaponmagazined_netdestroy_patch_addr:cardinal;
  cweaponmagazined_netdestroy_clipped_function_addr:cardinal;

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

function Init:boolean;
begin
  result:=false;
  cweaponmagazined_loaddata_in_netspawn_patch_addr:=xrGame_addr+$2C1200;
  if not WriteJump(cweaponmagazined_loaddata_in_netspawn_patch_addr, cardinal(@CWeaponMagazined_Load_Data_In_NetSpawn_Patch),6) then exit;

  cweaponmagazined_netdestroy_patch_addr:=xrGame_addr+$2BEFE4;
  cweaponmagazined_netdestroy_clipped_function_addr:=xrGame_addr+$2C4770;
  if not WriteJump(cweaponmagazined_netdestroy_patch_addr, cardinal(@CWeaponMagazined_NetDestroy_Patch), 5) then exit;

  result:=true;
end;

end.
