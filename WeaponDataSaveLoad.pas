unit WeaponDataSaveLoad;

interface
function Init:boolean;


implementation
uses BaseGameData, HudItemUtils, WeaponAdditionalBuffer, sysutils, xr_Cartridge, Misc, WeaponEvents, ActorUtils, dynamic_caster;


//загрузка/сохранение игры
procedure CWeapon__load(wpn:pointer; packet:pointer); stdcall;
var
  buf:WpnBuf;
  tmp_bool:boolean;
  tmp_byte,tmp_byte2:byte;
  tmp_cardinal:cardinal;  
  tmp_single:single;
  tmp_int:integer;
  ammos_in_mag, i, cnt, cnt_total:word;
  ammotype:byte;
  so:pointer;

  lens_params:lens_zoom_params;
begin

  if not WpnCanShoot(wpn) then exit;

  buf:=GetBuffer(wpn);
  if (buf=nil) then begin
    buf:=WpnBuf.Create(wpn);
  end;

  ReadFromReader(packet, @tmp_bool, sizeof(tmp_bool));
  buf.SetLaserEnabledStatus(tmp_bool);

  ReadFromReader(packet, @tmp_bool, sizeof(tmp_bool));
  buf.SwitchTorch(tmp_bool);

  ReadFromReader(packet, @tmp_bool, sizeof(tmp_bool));
  SetWeaponMisfireStatus(wpn, tmp_bool);

  ReadFromReader(packet, @tmp_bool, sizeof(tmp_bool));
  buf.SetExplosed(tmp_bool);


  lens_params:=buf.GetLensParams();
  ReadFromReader(packet, @lens_params.target_position, sizeof(tmp_single));
  lens_params.real_position:=lens_params.target_position;
  buf.SetLensParams(lens_params);

  ReadFromReader(packet, @tmp_single, sizeof(tmp_single));
  buf.SetOffsetDir(tmp_single);

  //ReloadNightBrightnessParams и подобные ему вызывать здесь нельз€ - у нас еще не прогрузились и не установились апгрейды, прицела c нужным индексом может тупо не быть!
  ReadFromReader(packet, @tmp_int, sizeof(tmp_int));
  buf.SetNightBrightnessSavedStep(tmp_int);

  ReadFromReader(packet, @ammos_in_mag, sizeof(ammos_in_mag));
  SetLength(buf.ammos, ammos_in_mag);

  cnt_total:=0;
  while cnt_total<ammos_in_mag do begin
    ReadFromReader(packet, @cnt, sizeof(cnt));
    ReadFromReader(packet, @ammotype, sizeof(ammotype));
    for i:=cnt_total to cnt_total+cnt-1 do begin
      buf.ammos[i]:=ammotype;
    end;
    cnt_total:=cnt_total+cnt;
  end;

  if (IsExplosed(wpn)) then begin
    OnWeaponExplode_AfterAnim(wpn, 0);
  end;
end;

procedure CWeapon__save(wpn:pointer; packet:pointer); stdcall;
var
  buf:WpnBuf;
  tmp_bool:boolean;
  tmp_byte:byte;
  tmp_cardinal:cardinal;
  tmp_single:single;
  tmp_stepped:stepped_params;

  i, cnt, max_in_mag:word;
  ammotype:byte;
  c:pCCartridge;
  lens_params:lens_zoom_params;
begin
  if not WpnCanShoot(wpn) then exit;
  buf:=GetBuffer(wpn);
  if buf = nil then exit;

  tmp_bool:=buf.IsLaserEnabled();
  WriteToPacket(packet, @tmp_bool, sizeof(tmp_bool));
  tmp_bool:=buf.IsTorchEnabled();
  WriteToPacket(packet, @tmp_bool, sizeof(tmp_bool));
  tmp_bool:=IsWeaponJammed(wpn);
  WriteToPacket(packet, @tmp_bool, sizeof(tmp_bool));
  tmp_bool:=buf.IsExplosed();
  WriteToPacket(packet, @tmp_bool, sizeof(tmp_bool));

  lens_params:=buf.GetLensParams();
  WriteToPacket(packet, @lens_params.target_position, sizeof(lens_params.target_position));

  tmp_single:=buf.GetLensOffsetDir();
  WriteToPacket(packet, @tmp_single, sizeof(tmp_single));
  tmp_stepped:=buf.GetCurBrightness();
  WriteToPacket(packet, @tmp_stepped.cur_step, sizeof(tmp_stepped.cur_step));


  //сохран€ем типы патронов в магазине, про подствол забываем
  max_in_mag:=GetAmmoInMagCount(wpn);
  WriteToPacket (packet, @max_in_mag, sizeof(max_in_mag));
  if max_in_mag>0 then begin
    max_in_mag:=max_in_mag-1;
    c:=GetCartridgeFromMagVector(wpn, 0);
    cnt:=1;
    ammotype:=c^.m_local_ammotype;

    for i:=1 to max_in_mag do begin
      c:=GetCartridgeFromMagVector(wpn, i);
      //if wpn = GetActorActiveItem() then log(inttostr(c^.m_local_ammotype));
      if ammotype<>c^.m_local_ammotype then begin
        WriteToPacket(packet, @cnt, sizeof(cnt));
        WriteToPacket(packet, @ammotype, sizeof(ammotype));

        ammotype:=c^.m_local_ammotype;
        cnt:=1;
      end else begin
        cnt:=cnt+1;
      end;
    end;

    WriteToPacket(packet, @cnt, sizeof(cnt));
    WriteToPacket(packet, @ammotype, sizeof(ammotype));
  end;
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
    //здесь инициализаци€ объекта еще толком не произведена - пишем что хотим
    //обнулим место, куда будет записыватьс€ указатель на WpnBuf
    xor ax, ax
    mov word ptr [ecx+$6a2], ax
    mov word ptr [ecx+$6be], ax    
    //«агрузим тип прицела, установленный ранее
    mov eax, [esp+$3C]
    test eax, eax
    je @finish
    movzx eax, byte ptr [eax+$1bc]
    shr eax, 3
    //проверим, поддерживаетс€ ли вообще прицел с таким индексом данным оружием
    mov ebx, [ecx+$6b4]
    sub ebx, [ecx+$6b0]
    lea edx, [eax*4]
    cmp edx, ebx
    jge @finish
    //«апишем тип прицела
    mov [ecx+$6bc], al
    @finish:
    //на вс€кий сбросим "лишние" данные в байте флагов аддонов
    mov eax, [esp+$3C]
    and byte ptr [eax+$1bc], 7
    popfd
    popad


    fstp dword ptr [esi+$4C0]
    ret
end;

procedure CWeapon_NetDestroy_SaveData(wpn:pointer; so:pointer); stdcall;
var
  wpn_gl:pointer;
  gl_status:byte;
  gl_ammocnt:byte;
  gl_ammotype:byte;
begin
  wpn_gl:=dynamic_cast(wpn, 0, RTTI_CWeapon, RTTI_CWeaponMagazinedWGrenade, false);
  if wpn_gl<>nil then begin
    //[bug] баг - при активном подствольнике число грен в нем отправл€етс€ в основной магазин патронов
    if IsGrenadeMode(wpn_gl) then begin
      //log('Switching GL on '+inttohex(cardinal(so), 8));
      PerformSwitchGL(wpn_gl);
    end;


    //[bug] баг - отсутствует выставление a_elapsed_grenades в серверном объекте после удалени€, из-за чего грены прогружаютс€ некорректно. ѕо-хорошему, надо править не так топорно, а модифицированием методов экспорта и импорта нетпакетов
    gl_ammocnt:=GetAmmoInGLCount(wpn_gl);
    if gl_ammocnt>0 then begin
      gl_ammotype:=GetGrenadeCartridgeFromGLVector(wpn_gl, gl_ammocnt-1).m_local_ammotype;
    end else begin
      gl_ammotype:=GetAmmoTypeIndex(wpn_gl, not IsGrenadeMode(wpn_gl))
    end;
    gl_status:= (gl_ammotype shl 6) + (gl_ammocnt and $3F);
    //log('gl_status ='+inttohex(gl_status, 2));

    pbyte(cardinal(so)+$1A8)^:=gl_status;

  end;


end;


procedure CWeapon_NetDestroy_SaveData_Patch(); stdcall;
asm
    pushad
    pushfd

    //ѕолучим серверный объект
    push ecx
    movzx eax, word ptr [ecx+$18c]
    push eax
    call get_server_object_by_id
    pop ecx

    test eax, eax
    je @finish

    pushad
      push eax
      push ecx
      call CWeapon_NetDestroy_SaveData
    popad

    //[bug] баг с прицелами - «апихнем в старшие 5 бит байта с флагами аддонов у серверного объекта номер текущего типа прицелов
    //TODO: переделать сохранение напр€мую в серверный объект на запись в пакет
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

procedure CWeapon__net_Export_ammocnt_Patch(); stdcall;
asm
  push ecx
  lea ecx, [esp]
  
  pushad
  push ecx

  push esi
  call GetAmmoInMagCount

  pop ecx
  mov [ecx], eax

  popad

  pop ecx
end;

procedure CWeapon__net_Export_ammotype_Patch(); stdcall;
asm
  pushad
  push esi
  call IsGrenadeMode
  cmp al, 0
  popad


  je @not_gl
  movzx eax, byte ptr [esi+$7E4]
  jmp @finish

  @not_gl:
  movzx eax, byte ptr [esi+$6C4]
  
  @finish:

end;


procedure CWeaponMagazinedWGrenade__save_GLAmmo(wpn:pointer; dest:pCardinal); stdcall;
begin
  dest^:=GetAmmoInGLCount(wpn);
end;

procedure CWeaponMagazinedWGrenade__save_GLAmmo_Patch(); stdcall;
asm
  lea edx, [esp+$14]

  pushad
    push edx
    push esi
    call CWeaponMagazinedWGrenade__save_GLAmmo
  popad
end;

procedure CWeaponMagazinedWGrenade__load_saveglstatus(wpn:pointer; status:boolean); stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if buf<>nil then begin
    buf.loaded_gl_state:=status;
  end;
end;

procedure CWeaponMagazinedWGrenade__load_saveglstatus_Patch(); stdcall;
asm
  pushad
    push ecx
    push esi
    call CWeaponMagazinedWGrenade__load_saveglstatus
  popad
  cmp cl, [esi+$7F8] //original
end;

procedure CWeaponMagazinedWGrenade__net_Spawn_applyglstatus(wpn:pointer); stdcall;
var
  buf:WpnBuf;
  gl_status:cardinal;
begin
  buf:=GetBuffer(wpn);
  if buf.loaded_gl_state<>IsGLEnabled(wpn) then begin
    gl_status:=GetGLStatus(wpn);
    if (gl_status=1) or ((gl_status=2) and IsGLAttached(wpn)) then begin
      PerformSwitchGL(wpn);
    end;
  end;
end;

procedure CWeaponMagazinedWGrenade__net_Spawn_applyglstatus_Patch(); stdcall;
asm
  pushad
    push esi
    call CWeaponMagazinedWGrenade__net_Spawn_applyglstatus
  popad

  pop eax //ret  addr
  pop edi
  pop esi
  pop ebp
  push eax //ret addr
  mov eax, ebx
end;

procedure CWeaponMagazinedWGrenade__net_Spawn_restorewpnptr_Patch(); stdcall;
asm
  sub esi, $E8
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

  //[bug] баг - в CWeapon::net_Export сохран€етс€ не число патронов в основном магазине, а число в активном
  jmp_addr:=xrGame_addr+$2BC03F;
  if not WriteJump(jmp_addr, cardinal(@CWeapon__net_Export_ammocnt_Patch), 7, true) then exit;
  //аналогично с типом
  jmp_addr:=xrGame_addr+$2BC05F;
  if not WriteJump(jmp_addr, cardinal(@CWeapon__net_Export_ammotype_Patch), 7, true) then exit;

  //правим сохранение числа подствольных грен
  jmp_addr:=xrGame_addr+$2D2850;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazinedWGrenade__save_GLAmmo_Patch), 8, true) then exit;
  if not nop_code(xrgame_addr+$2D3C3D, 1, CHR($EB)) then exit;
  if not nop_code(xrgame_addr+$2D3CB2, 1, CHR($EB)) then exit;

  //запомним загруженное из сейва состо€ние подствола
  jmp_addr:=xrGame_addr+$2D3C37;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazinedWGrenade__load_saveglstatus_Patch), 6, true) then exit;

  //и загрузим его в самом конце net_Spawn'ов
  jmp_addr:=xrGame_addr+$2D35E1;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazinedWGrenade__net_Spawn_applyglstatus_Patch), 5, true) then exit;

  jmp_addr:=xrGame_addr+$2D35B9;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazinedWGrenade__net_Spawn_restorewpnptr_Patch), 13, true) then exit;
  result:=true;
end;

end.
