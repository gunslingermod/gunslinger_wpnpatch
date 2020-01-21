unit Level;

interface
uses MatVectors, xr_Cartridge, Misc;
function GetLevel():pointer; stdcall;
function Level_to_CObjectSpace(l:pointer):pointer; stdcall;
procedure spawn_phantom(pos:pFVector3);
procedure AddBullet(position:pFVector3; direction:pFVector3; starting_speed:single; power:single; impulse:single; sender_id:word; sendersweapon_id:word; e_hit_type:cardinal; maximum_distance:single; cartridge:pCCartridge;  air_resistance_factor:single; SendHit:boolean; AimBullet:boolean); stdcall;
procedure MakeWeaponKick(pos:pFVector3; dir:pFVector3; wpn:pointer); stdcall;
function CLevel__SpawnItem(this:pointer; section:PChar; pos:pFVector3; vertex_id:cardinal; parent_id:word; return_item:boolean):pCSE_Abstract; stdcall;
procedure CLevel__AfterSpawnSendAndFree(this:pointer; obj:pCSE_Abstract); stdcall;
function GetObjectById(id:word):pointer; stdcall;

implementation
uses BaseGameData, gunsl_config, HudItemUtils, HitUtils, math, sysutils, xr_strings;

function GetLevel():pointer; stdcall;
asm
  mov eax, xrEngine_addr
  mov eax, [eax+$92d2c]
  mov @result, eax
end;

function Level_to_CObjectSpace(l:pointer):pointer; stdcall;
asm
  mov eax, l
  add eax, $40094
  mov @result, eax
end;

procedure spawn_phantom(pos:pFVector3);
asm
  pushad
    mov eax, pos
    push eax
    mov eax, xrgame_addr
    add eax, $23cdd0
    call eax
    add esp, 4
  popad
end;

procedure AddBullet(position:pFVector3; direction:pFVector3; starting_speed:single; power:single; impulse:single; sender_id:word; sendersweapon_id:word; e_hit_type:cardinal; maximum_distance:single; cartridge:pCCartridge;  air_resistance_factor:single; SendHit:boolean; AimBullet:boolean); stdcall;
asm
  pushad
    movzx eax, AimBullet
    push eax

    movzx ebx, SendHit
    push ebx

    push air_resistance_factor
    push cartridge
    push maximum_distance
    push e_hit_type

    movzx eax, sendersweapon_id
    push eax

    movzx ebx, sender_id
    push ebx

    push impulse
    push power
    push starting_speed
    push direction
    push position

    call GetLevel
    mov ecx, [eax+$487c4]

    mov eax, xrgame_addr
    add eax, $24ef70
    call eax

  popad
end;

function CLevel__SpawnItem(this:pointer; section:PChar; pos:pFVector3; vertex_id:cardinal; parent_id:word; return_item:boolean):pCSE_Abstract; stdcall;
asm
  pushad
    xor eax, eax
    mov al, return_item
    push eax
    mov ax, parent_id
    push eax
    push vertex_id
    push pos
    push section
    mov ecx, this
    mov eax, xrgame_addr
    add eax, $23BB40
    call eax 
    mov @result, eax
  popad
end;

procedure CLevel__AfterSpawnSendAndFree(this:pointer; obj:pCSE_Abstract); stdcall;
asm
  //взято из CLevel::SpawnItem - фрагмент отправки сообщения серверу и уничтожения объекта
  sub esp, $4020
  lea ecx, [esp]
  mov eax, xrgame_addr
  add eax, $512818 //NET_Packet constructor
  call [eax]


  lea eax, [esp]
  mov esi, obj
  mov edx, [esi]
  mov ecx, [edx]

  push 01
  push eax  //packet
  push esi  //this
  call ecx  //obj->Spawn_Write

  lea eax, [esp]
  mov ecx, this
  add ecx, $40110
  mov edx, [ecx]
  mov edx, [edx+$10]
  push 0
  push 8
  push eax  //packet
  call edx  //CLevel->Send

  push esi
  mov eax, xrgame_addr
  add eax, $509DA6
  call eax

  lea ecx, [esi+$08]
  mov edi, eax
  mov eax, [ecx]
  mov edx, [eax+$14]
  add esp, 4

  push 0
  call edx

  mov ecx, xrgame_addr
  mov ecx, [ecx+$5127B4]
  push edi
  mov eax, xrgame_addr
  call [eax+$5127B8]

  add esp, $4020
end;

procedure MakeWeaponKick(pos:pFVector3; dir:pFVector3; wpn:pointer); stdcall;
var
  c:CCartridge;
  sect:PChar;
  material:PChar;

  cnt, i, htype:integer;
  hp, imp, hdist:single;
  tmpdir:FVector3;
  right, up:FVector3;

  disp_hor, disp_ver:single;
begin
  sect:=GetSection(wpn);

  if game_ini_line_exist(sect, 'kick_material') then begin
    material:=game_ini_read_string(sect, 'kick_material')
  end else begin
    material:='objects\knife';
  end;

  material:=FindStrValueInUpgradesDef(wpn, 'kick_material', material);

  init_string(@c.m_ammo_sect);

  InitCartridge(@c);
  c.SCartridgeParam__kAP:=0.001;
  c.SCartridgeParam__fWallmarkSize:=ModifyFloatUpgradedValue(wpn, 'kick_wallmark_size', game_ini_r_single_def(sect, 'kick_wallmark_size', 0.05));
  c.bullet_material_idx:=GetMaterialIdx(material);

  cnt:=FindIntValueInUpgradesDef(wpn, 'kick_hit_count', game_ini_r_int_def(sect, 'kick_hit_count', 1));
  hp:=ModifyFloatUpgradedValue(wpn, 'kick_hit_power', game_ini_r_single_def(sect, 'kick_hit_power', 0.0));
  imp:=ModifyFloatUpgradedValue(wpn, 'kick_hit_impulse', game_ini_r_single_def(sect, 'kick_hit_impulse', 0.0));
  htype:= FindIntValueInUpgradesDef(wpn, 'kick_hit_type', game_ini_r_int_def(sect, 'kick_hit_type', EHitType__eHitTypeWound));
  hdist:=ModifyFloatUpgradedValue(wpn, 'kick_distance', game_ini_r_single_def(sect, 'kick_distance', 0.0));

  disp_hor:=ModifyFloatUpgradedValue(wpn, 'kick_disp_hor', game_ini_r_single_def(sect, 'kick_disp_hor', 0.0));
  disp_ver:=ModifyFloatUpgradedValue(wpn, 'kick_disp_ver', game_ini_r_single_def(sect, 'kick_disp_ver', 0.0));

  //log(PChar(floattostr(hp)));
  //log(PChar(inttostr(htype)));

  //для одного волмарка
  AddBullet(pos, dir, 10000,
      0,
      0,
      0,
      GetID(wpn),
      htype,
      hdist,
      @c,
      1.0,
      true,
      false);


  //для хита

  c.bullet_material_idx:=GetMaterialIdx('objects\clothes');
  c.SCartridgeParam__fWallmarkSize:=0.0001;



  for i:=0 to cnt-1 do begin
    tmpdir:=dir^;
    generate_orthonormal_basis_normalized(@tmpdir, @up, @right);

    //посчитаем максимальное отклонение
    v_mul(@up, disp_ver);
    v_mul(@right, disp_hor);
    //выставим дирекцию в крайнее положение
    v_sub(@tmpdir, @up);
    v_sub(@tmpdir, @right);

    //посмотрим, насколько сместить дирекцию для текущего удара
    v_mul(@up, 2*i/cnt);
    v_mul(@right, 2*i/cnt);

    //выставим текущее смещение
    v_add(@tmpdir, @up);
    v_add(@tmpdir, @right);


    AddBullet(pos, @tmpdir, 10000,
      hp,
      imp,
      0,
      GetID(wpn),
      htype,
      hdist,
      @c,
      1.0,
      true,
      false);
  end;
end;

function GetObjectById(id:word):pointer; stdcall;
asm
  pushad
  movzx eax, id
  push eax
  mov eax, xrgame_addr;
  add eax, $23f5a0
  call eax // get_object_by_id
  pop ecx

  cmp eax, 0
  je @finish
  mov eax, [eax+$4]

  @finish:
  mov @result, eax
  popad 
end;

end.
