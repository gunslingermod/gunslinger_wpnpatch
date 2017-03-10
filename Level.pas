unit Level;

interface
uses MatVectors, xr_Cartridge;
function GetLevel():pointer; stdcall;
function Level_to_CObjectSpace(l:pointer):pointer; stdcall;
procedure spawn_phantom(pos:pFVector3);
procedure AddBullet(position:pFVector3; direction:pFVector3; starting_speed:single; power:single; impulse:single; sender_id:word; sendersweapon_id:word; e_hit_type:cardinal; maximum_distance:single; cartridge:pCCartridge;  air_resistance_factor:single; SendHit:boolean; AimBullet:boolean); stdcall;
procedure MakeWeaponKick(pos:pFVector3; dir:pFVector3; wpn:pointer); stdcall;

implementation
uses BaseGameData, gunsl_config, HudItemUtils, Misc, HitUtils;

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

procedure MakeWeaponKick(pos:pFVector3; dir:pFVector3; wpn:pointer); stdcall;
var
  c:CCartridge;
  sect:PChar;
  material:PChar;
begin
  sect:=GetSection(wpn);

  if game_ini_line_exist(sect, 'kick_material') then begin
    material:=game_ini_read_string(sect, 'kick_material')
  end else begin
    material:='objects\knife';
  end;

  c.m_ammo_sect:=nil;

  InitCartridge(@c);
  c.SCartridgeParam__kAP:=0.001;
  c.SCartridgeParam__fWallmarkSize:=game_ini_r_single_def(sect, 'kick_wallmark_size', 0.05);
  c.bullet_material_idx:=GetMaterialIdx(material);

  AddBullet(pos, dir, 10000,
    game_ini_r_single_def(sect, 'kick_hit_power', 1.0),
    game_ini_r_single_def(sect, 'kick_hit_impulse', 1.0),
    0,
    GetID(wpn),
    game_ini_r_int_def(sect, 'kick_hit_type', EHitType__eHitTypeWound),
    game_ini_r_single_def(sect, 'kick_distance', 2.0),
    @c,
    1.0,
    true,
    false);
end;

end.
