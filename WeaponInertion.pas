unit WeaponInertion;

interface
function Init():boolean;
procedure UpdateInertion (wpn:pointer);

implementation
uses BaseGameData, gunsl_config, HudItemUtils, windows, strutils;

var
  i_p:weapon_inertion_params;

procedure CWeapon__OnZoomOut_inertion(wpn:pointer); stdcall;
begin
  if game_ini_r_bool_def(GetHUDSection(wpn), 'zoom_inertion', false) and game_ini_r_bool_def(GetHUDSection(wpn), 'hud_inertion', true) then begin
    AllowWeaponInertion(wpn, true);
  end;
end;

procedure CWeapon__OnZoomOut_inertion_Patch(); stdcall;
asm
  pushad
    push esi
    call CWeapon__OnZoomOut_inertion
  popad
end;

procedure UpdateInertion (wpn:pointer);
var
  koef:single;
  sect:PChar;
  def_inert, aim_inert:weapon_inertion_params;
begin
  if (wpn<>nil) and not game_ini_r_bool_def(GetHUDSection(wpn), 'hud_inertion', true) then begin
    AllowWeaponInertion(wpn, false);
  end;

  def_inert:=GetStdInertion(false);
  if wpn<>nil then begin
    sect:=GetHUDSection(wpn); 
    def_inert.pitch_offset_r:=game_ini_r_single_def(sect, 'inertion_pitch_offset_r', def_inert.pitch_offset_r);
    def_inert.pitch_offset_n:=game_ini_r_single_def(sect, 'inertion_pitch_offset_n', def_inert.pitch_offset_n);
    def_inert.pitch_offset_d:=game_ini_r_single_def(sect, 'inertion_pitch_offset_d', def_inert.pitch_offset_d);
    def_inert.origin_offset:=game_ini_r_single_def(sect, 'inertion_origin_offset', def_inert.origin_offset);
    def_inert.speed:=game_ini_r_single_def(sect, 'inertion_speed', def_inert.speed);

    if IsAimNow(wpn) or (leftstr(GetActualCurrentAnim(wpn), length('anm_idle_aim'))='anm_idle_aim')  then begin
      aim_inert:=GetStdInertion(true);
      aim_inert.pitch_offset_r:=game_ini_r_single_def(sect, 'inertion_aim_pitch_offset_r', aim_inert.pitch_offset_r);
      aim_inert.pitch_offset_n:=game_ini_r_single_def(sect, 'inertion_aim_pitch_offset_n', aim_inert.pitch_offset_n);
      aim_inert.pitch_offset_d:=game_ini_r_single_def(sect, 'inertion_aim_pitch_offset_d', aim_inert.pitch_offset_d);
      aim_inert.origin_offset:=game_ini_r_single_def(sect, 'inertion_aim_origin_offset', aim_inert.origin_offset);
      aim_inert.speed:=game_ini_r_single_def(sect, 'inertion_aim_speed', aim_inert.speed);

      koef:=GetAimFactor(wpn);
      def_inert.pitch_offset_r:= def_inert.pitch_offset_r - (def_inert.pitch_offset_r-aim_inert.pitch_offset_r)*koef;
      def_inert.pitch_offset_n:= def_inert.pitch_offset_n - (def_inert.pitch_offset_n-aim_inert.pitch_offset_n)*koef;
      def_inert.pitch_offset_d:= def_inert.pitch_offset_d - (def_inert.pitch_offset_d-aim_inert.pitch_offset_d)*koef;
      def_inert.origin_offset:= def_inert.origin_offset - (def_inert.origin_offset-aim_inert.origin_offset)*koef;
      def_inert.speed:= def_inert.speed - (def_inert.speed-aim_inert.speed)*koef;
    end;
  end;

  i_p:=def_inert;
end;



procedure CWeapon__OnZoomIn_inertion(wpn:pointer); stdcall;
begin
  if game_ini_r_bool_def(GetHUDSection(wpn), 'zoom_inertion', false) then begin
    AllowWeaponInertion(wpn, false);
  end;
end;

procedure CWeapon__OnZoomIn_inertion_Patch(); stdcall;
asm
  pushad
    push esi
    call CWeapon__OnZoomIn_inertion
  popad
end;

function Init():boolean;
var
  addr, rb:cardinal;
  ptr:pointer;
begin
  result:=false;

  //CWeapon::OnZoomIn - отключаем AllowInertion(false);
  addr:=xrgame_addr+$2c07dc;
  if not WriteJump(addr, cardinal(@CWeapon__OnZoomOut_inertion_Patch), 9, true) then exit;

  //CWeapon::OnZoomOut - отключаем AllowInertion(true);
  addr:=xrgame_addr+$2BEE36;
  if not WriteJump(addr, cardinal(@CWeapon__OnZoomOut_inertion_Patch), 8, true) then exit;

  //переписываем указатель на предельное значение инерции
  addr:=xrgame_addr+$2fcbc8;
  ptr:=@i_p.pitch_offset_n;
  writeprocessmemory(hndl, PChar(addr), @ptr, 4, rb);

  addr:=xrgame_addr+$2fcbd0;
  ptr:=@i_p.pitch_offset_r;
  writeprocessmemory(hndl, PChar(addr), @ptr, 4, rb);

  addr:=xrgame_addr+$2fcba2;
  ptr:=@i_p.pitch_offset_d;
  writeprocessmemory(hndl, PChar(addr), @ptr, 4, rb);

  ptr:=@i_p.speed;
  addr:=xrgame_addr+$2fc98f;
  writeprocessmemory(hndl, PChar(addr), @ptr, 4, rb);

  ptr:=@i_p.origin_offset;
  addr:=xrgame_addr+$2fc9b2;
  writeprocessmemory(hndl, PChar(addr), @ptr, 4, rb);


  result:=true;
end;

end.
