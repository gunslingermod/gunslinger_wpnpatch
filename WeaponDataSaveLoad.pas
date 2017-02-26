unit WeaponDataSaveLoad;

interface
function Init:boolean;

implementation
uses GameWrappers, BaseGameData, WpnUtils, WeaponAdditionalBuffer, sysutils;

var
  cweapon_loaddata_in_netspawn_patch_addr:cardinal;
  cweapon_netdestroy_patch_addr:cardinal;
  cweapon_netdestroy_clipped_function_addr:cardinal;
//-----------------------------------------------------------------------------------------------------------
procedure WriteToPacket(packet:pointer; data:pointer; bytes_count:cardinal); stdcall;
asm
  pushad
    mov eax, xrgame_addr
    mov eax, [eax+$5127cc] //NET_Packet::w

    push bytes_count
    push data

    mov ecx, packet
    call eax;
  popad
end;


procedure ReadFromReader(IReader:pointer; buf:pointer; bytes_count:cardinal); stdcall;
asm
  pushad
    mov eax, xrgame_addr
    mov eax, [eax+$5127D4]

    push bytes_count
    push buf

    mov ecx, IReader
    call eax;
  popad
end;


//-----------------------------------------------------------------------------------------------------------
//загрузка/сохранение игры
procedure CWeapon__load(wpn:pointer; packet:pointer); stdcall;
var
  buf:WpnBuf;
  tmp_bool:boolean;
begin

  if not WpnCanShoot(PChar(GetClassName(wpn))) then exit;

  if (GetBuffer(wpn)=nil) then begin
    buf:=WpnBuf.Create(wpn);
  end;

  ReadFromReader(packet, @tmp_bool, sizeof(tmp_bool));
  buf.SetLaserEnabledStatus(tmp_bool);

  ReadFromReader(packet, @tmp_bool, sizeof(tmp_bool));
  buf.SetExplosed(tmp_bool);
end;

procedure CWeapon__save(wpn:pointer; packet:pointer); stdcall;
var
  buf:WpnBuf;
  tmp_bool:boolean;
begin
  if not WpnCanShoot(PChar(GetClassName(wpn))) then exit;
  buf:=GetBuffer(wpn);
  if buf = nil then exit;
  tmp_bool:=buf.IsLaserEnabled();
  WriteToPacket(packet, @tmp_bool, sizeof(tmp_bool));
  tmp_bool:=buf.IsExplosed();
  WriteToPacket(packet, @tmp_bool, sizeof(tmp_bool));
end;


procedure CWeapon__load_Patch(); stdcall;
asm
  sub esi, $741
  push edi
  push esi
  call CWeapon__load
  pop edi
  pop esi
  pop ebp
  pop ebx
  ret 4
end;


procedure CWeapon__save_Patch(); stdcall;
asm
  sub esi, $741
  push edi
  push esi
  call CWeapon__save
  pop edi
  pop esi
  ret 4
end;
//-----------------------------------------------------------------------------------------------------------
procedure CWeapon_Load_Data_In_NetSpawn_Patch(); stdcall;
asm
    pushad
    pushfd
    //здесь инициализация объекта еще толком не произведена - пишем что хотим
    //обнулим место, куда будет записываться указатель на WpnBuf
    xor ax, ax
    mov word ptr [ecx+$6a2], ax
    mov word ptr [ecx+$6be], ax    
    //Загрузим тип прицела, установленный ранее
    mov eax, [esp+$3C]
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
    mov eax, [esp+$3C]
    and byte ptr [eax+$1bc], 3
    popfd
    popad


    fstp dword ptr [esi+$4C0]
    ret
end;


procedure CWeapon_NetDestroy_SaveData_Patch(); stdcall;
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

    mov eax, xrgame_addr;
    add eax, $2C4770
    call eax          //parent net_Destroy

    ret
end;
//-----------------------------------------------------------------------------------------------------------
function Init:boolean;
var jmp_addr:cardinal;
begin
  result:=false;
  jmp_addr:=xrGame_addr+$2C1200;
  if not WriteJump(jmp_addr, cardinal(@CWeapon_Load_Data_In_NetSpawn_Patch),6, true) then exit;

  jmp_addr:=xrGame_addr+$2BEFE4;
  if not WriteJump(jmp_addr, cardinal(@CWeapon_NetDestroy_SaveData_Patch), 5, true) then exit;


  jmp_addr:=xrGame_addr+$2BF195;
  if not WriteJump(jmp_addr, cardinal(@CWeapon__load_Patch), 7, false) then exit;

  jmp_addr:=xrGame_addr+$2BF104;
  if not WriteJump(jmp_addr, cardinal(@CWeapon__save_Patch), 5, false) then exit;

    
  result:=true;
end;

end.
