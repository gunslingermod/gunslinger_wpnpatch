unit WeaponInertion;

interface
function Init():boolean;
procedure UpdateInertion (wpn:pointer);
procedure UpdateWeaponOffset(act:pointer);
procedure ResetWpnOffset();
procedure ResetCamHeight();

implementation
uses BaseGameData, gunsl_config, HudItemUtils, windows, strutils, MatVectors, ActorUtils, DetectorUtils, sysutils, math, WeaponAdditionalBuffer;

var
  i_p:weapon_inertion_params;
  last_update_time:cardinal;
  time_accumulator:cardinal;

  _last_camera_height:single;
  _last_cam_update_time:cardinal;

  tocrouch_time_remains, fromcrouch_time_remains:cardinal;
  toslowcrouch_time_remains, fromslowcrouch_time_remains:cardinal;

procedure ResetWpnOffset();
begin
  last_update_time:=0;
  time_accumulator:=0;
  tocrouch_time_remains:=0;
  fromcrouch_time_remains:=0;

  toslowcrouch_time_remains:=0;
  fromslowcrouch_time_remains:=0;
end;

procedure ResetCamHeight();
begin
  _last_camera_height:=0;
  _last_cam_update_time:=0;
end;

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
  sect, scp:PChar;
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

      if (GetScopeStatus(wpn)=2) and IsScopeAttached(wpn) then begin
        scp:=GetCurrentScopeSection(wpn);
        aim_inert.pitch_offset_r:=game_ini_r_single_def(scp, 'inertion_aim_pitch_offset_r', aim_inert.pitch_offset_r);
        aim_inert.pitch_offset_n:=game_ini_r_single_def(scp, 'inertion_aim_pitch_offset_n', aim_inert.pitch_offset_n);
        aim_inert.pitch_offset_d:=game_ini_r_single_def(scp, 'inertion_aim_pitch_offset_d', aim_inert.pitch_offset_d);
        aim_inert.origin_offset:=game_ini_r_single_def(scp, 'inertion_aim_origin_offset', aim_inert.origin_offset);
        aim_inert.speed:=game_ini_r_single_def(scp, 'inertion_aim_speed', aim_inert.speed);
      end;

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

procedure GetCurrentTargetOffset(act:pointer; section:PChar; pos:pFVector3; rot:pFVector3; factor:pSingle);
var
  zerovec, tmp:FVector3;
  koef:single;
begin
  factor^:=game_ini_r_single_def(section, 'hud_move_stabilize_factor', 2.0);

  v_zero(pos);
  v_zero(rot);
  v_zero(@zerovec);

  if GetActorActionState(act, actCrouch) and GetActorActionState(act, actSlow) then begin
    koef:=game_ini_r_single_def(section, 'hud_move_slow_crouch_factor', 1.0);
  end else if GetActorActionState(act, actCrouch) then begin
    koef:=game_ini_r_single_def(section, 'hud_move_crouch_factor', 1.0);
  end else if GetActorActionState(act, actSlow) then begin
    koef:=game_ini_r_single_def(section, 'hud_move_slow_factor', 1.0);  
  end else begin
    koef:=1;
  end;

  if tocrouch_time_remains>0 then begin
    if Is16x9() then begin
      tmp:=game_ini_read_vector3_def(section, 'hud_move_to_crouch_offset_pos_16x9', @zerovec);
      v_mul(@tmp, koef);
      v_add(pos, @tmp);
      tmp:=game_ini_read_vector3_def(section, 'hud_move_to_crouch_offset_rot_16x9', @zerovec);
      v_mul(@tmp, koef);
      v_add(rot, @tmp);
    end else begin
      tmp:=game_ini_read_vector3_def(section, 'hud_move_to_crouch_offset_pos', @zerovec);
      v_mul(@tmp, koef);
      v_add(pos, @tmp);
      tmp:=game_ini_read_vector3_def(section, 'hud_move_to_crouch_offset_rot', @zerovec);
      v_mul(@tmp, koef);
      v_add(rot, @tmp);
    end;
    factor^:=1;
  end;

  if fromcrouch_time_remains>0 then begin
    if Is16x9() then begin
      tmp:=game_ini_read_vector3_def(section, 'hud_move_from_crouch_offset_pos_16x9', @zerovec);
      v_mul(@tmp, koef);
      v_add(pos, @tmp);
      tmp:=game_ini_read_vector3_def(section, 'hud_move_from_crouch_offset_rot_16x9', @zerovec);
      v_mul(@tmp, koef);
      v_add(rot, @tmp);
    end else begin
      tmp:=game_ini_read_vector3_def(section, 'hud_move_from_crouch_offset_pos', @zerovec);
      v_mul(@tmp, koef);
      v_add(pos, @tmp);
      tmp:=game_ini_read_vector3_def(section, 'hud_move_from_crouch_offset_rot', @zerovec);
      v_mul(@tmp, koef);
      v_add(rot, @tmp);
    end;
    factor^:=1;
  end;

  if toslowcrouch_time_remains>0 then begin
    if Is16x9() then begin
      tmp:=game_ini_read_vector3_def(section, 'hud_move_to_slow_crouch_offset_pos_16x9', @zerovec);
      v_mul(@tmp, koef);
      v_add(pos, @tmp);
      tmp:=game_ini_read_vector3_def(section, 'hud_move_to_slow_crouch_offset_rot_16x9', @zerovec);
      v_mul(@tmp, koef);
      v_add(rot, @tmp);
    end else begin
      tmp:=game_ini_read_vector3_def(section, 'hud_move_to_slow_crouch_offset_pos', @zerovec);
      v_mul(@tmp, koef);
      v_add(pos, @tmp);
      tmp:=game_ini_read_vector3_def(section, 'hud_move_to_slow_crouch_offset_rot', @zerovec);
      v_mul(@tmp, koef);
      v_add(rot, @tmp);
    end;
    factor^:=1;
  end;

  if fromslowcrouch_time_remains>0 then begin
    if Is16x9() then begin
      tmp:=game_ini_read_vector3_def(section, 'hud_move_from_slow_crouch_offset_pos_16x9', @zerovec);
      v_mul(@tmp, koef);
      v_add(pos, @tmp);
      tmp:=game_ini_read_vector3_def(section, 'hud_move_from_slow_crouch_offset_rot_16x9', @zerovec);
      v_mul(@tmp, koef);
      v_add(rot, @tmp);
    end else begin
      tmp:=game_ini_read_vector3_def(section, 'hud_move_from_slow_crouch_offset_pos', @zerovec);
      v_mul(@tmp, koef);
      v_add(pos, @tmp);
      tmp:=game_ini_read_vector3_def(section, 'hud_move_from_slow_crouch_offset_rot', @zerovec);
      v_mul(@tmp, koef);
      v_add(rot, @tmp);
    end;
    factor^:=1;
  end;

  if GetActorActionState(act, actMovingLeft) and not GetActorActionState(act, actMovingRight) then begin
    if Is16x9() then begin
      tmp:=game_ini_read_vector3_def(section, 'hud_move_left_offset_pos_16x9', @zerovec);
      v_mul(@tmp, koef);
      v_add(pos, @tmp);
      tmp:=game_ini_read_vector3_def(section, 'hud_move_left_offset_rot_16x9', @zerovec);
      v_mul(@tmp, koef);
      v_add(rot, @tmp);
    end else begin
      tmp:=game_ini_read_vector3_def(section, 'hud_move_left_offset_pos', @zerovec);
      v_mul(@tmp, koef);
      v_add(pos, @tmp);
      tmp:=game_ini_read_vector3_def(section, 'hud_move_left_offset_rot', @zerovec);
      v_mul(@tmp, koef);
      v_add(rot, @tmp);
    end;
    factor^:=1;
  end;

  if GetActorActionState(act, actMovingRight) and not GetActorActionState(act, actMovingLeft) then begin
    if Is16x9() then begin
      tmp:=game_ini_read_vector3_def(section, 'hud_move_right_offset_pos_16x9', @zerovec);
      v_mul(@tmp, koef);
      v_add(pos, @tmp);
      tmp:=game_ini_read_vector3_def(section, 'hud_move_right_offset_rot_16x9', @zerovec);
      v_mul(@tmp, koef);
      v_add(rot, @tmp);
    end else begin
      tmp:=game_ini_read_vector3_def(section, 'hud_move_right_offset_pos', @zerovec);
      v_mul(@tmp, koef);
      v_add(pos, @tmp);
      tmp:=game_ini_read_vector3_def(section, 'hud_move_right_offset_rot', @zerovec);
      v_mul(@tmp, koef);
      v_add(rot, @tmp);
    end;
    factor^:=1;
  end;

  if GetActorActionState(act, actMovingForward) and not GetActorActionState(act, actMovingBack) then begin
    if Is16x9() then begin
       tmp:=game_ini_read_vector3_def(section, 'hud_move_forward_offset_pos_16x9', @zerovec);
       v_mul(@tmp, koef);
       v_add(pos, @tmp);
       tmp:=game_ini_read_vector3_def(section, 'hud_move_forward_offset_rot_16x9', @zerovec);
       v_mul(@tmp, koef);
       v_add(rot, @tmp);
     end else begin
       tmp:=game_ini_read_vector3_def(section, 'hud_move_forward_offset_pos', @zerovec);
       v_mul(@tmp, koef);
       v_add(pos, @tmp);
       tmp:=game_ini_read_vector3_def(section, 'hud_move_forward_offset_rot', @zerovec);
       v_mul(@tmp, koef);
       v_add(rot, @tmp);
     end;
     factor^:=1;
  end;

  if GetActorActionState(act, actMovingBack) and not GetActorActionState(act, actMovingForward) then begin
    if Is16x9() then begin
       tmp:=game_ini_read_vector3_def(section, 'hud_move_back_offset_pos_16x9', @zerovec);
       v_mul(@tmp, koef);
       v_add(pos, @tmp);
       tmp:=game_ini_read_vector3_def(section, 'hud_move_back_offset_rot_16x9', @zerovec);
       v_mul(@tmp, koef);
       v_add(rot, @tmp);
     end else begin
       tmp:=game_ini_read_vector3_def(section, 'hud_move_back_offset_pos', @zerovec);
       v_mul(@tmp, koef);
       v_add(pos, @tmp);
       tmp:=game_ini_read_vector3_def(section, 'hud_move_back_offset_rot', @zerovec);
       v_mul(@tmp, koef);
       v_add(rot, @tmp);
     end;
     factor^:=1;
  end;

  if GetActorActionState(act, actJump) and not GetActorActionState(act, actFall) and not GetActorActionState(act, actLanding) and not GetActorActionState(act, actLanding2) then begin
    if Is16x9() then begin
       tmp:=game_ini_read_vector3_def(section, 'hud_move_jump_offset_pos_16x9', @zerovec);
       v_mul(@tmp, koef);
       v_add(pos, @tmp);
       tmp:=game_ini_read_vector3_def(section, 'hud_move_jump_offset_rot_16x9', @zerovec);
       v_mul(@tmp, koef);
       v_add(rot, @tmp);
     end else begin
       tmp:=game_ini_read_vector3_def(section, 'hud_move_jump_offset_pos', @zerovec);
       v_mul(@tmp, koef);
       v_add(pos, @tmp);
       tmp:=game_ini_read_vector3_def(section, 'hud_move_jump_offset_rot', @zerovec);
       v_mul(@tmp, koef);
       v_add(rot, @tmp);
     end;
     factor^:=1;
  end;

  if GetActorActionState(act, actFall) and not GetActorActionState(act, actJump) and not GetActorActionState(act, actLanding) and not GetActorActionState(act, actLanding2) then begin
    if Is16x9() then begin
       tmp:=game_ini_read_vector3_def(section, 'hud_move_fall_offset_pos_16x9', @zerovec);
       v_mul(@tmp, koef);
       v_add(pos, @tmp);
       tmp:=game_ini_read_vector3_def(section, 'hud_move_fall_offset_rot_16x9', @zerovec);
       v_mul(@tmp, koef);
       v_add(rot, @tmp);
     end else begin
       tmp:=game_ini_read_vector3_def(section, 'hud_move_fall_offset_pos', @zerovec);
       v_mul(@tmp, koef);
       v_add(pos, @tmp);
       tmp:=game_ini_read_vector3_def(section, 'hud_move_fall_offset_rot', @zerovec);
       v_mul(@tmp, koef);
       v_add(rot, @tmp);
     end;
     factor^:=1;
  end;

  if GetActorActionState(act, actLanding) and not GetActorActionState(act, actJump) and not GetActorActionState(act, actFall)  and not GetActorActionState(act, actLanding2) then begin
    if Is16x9() then begin
       tmp:=game_ini_read_vector3_def(section, 'hud_move_landing_offset_pos_16x9', @zerovec);
       v_mul(@tmp, koef);
       v_add(pos, @tmp);
       tmp:=game_ini_read_vector3_def(section, 'hud_move_landing_offset_rot_16x9', @zerovec);
       v_mul(@tmp, koef);
       v_add(rot, @tmp);
     end else begin
       tmp:=game_ini_read_vector3_def(section, 'hud_move_landing_offset_pos', @zerovec);
       v_mul(@tmp, koef);
       v_add(pos, @tmp);
       tmp:=game_ini_read_vector3_def(section, 'hud_move_landing_offset_rot', @zerovec);
       v_mul(@tmp, koef);
       v_add(rot, @tmp);
     end;
     factor^:=1;
  end;

  if GetActorActionState(act, actLanding2) and not GetActorActionState(act, actJump) and not GetActorActionState(act, actFall)  and not GetActorActionState(act, actLanding) then begin
    if Is16x9() then begin
       tmp:=game_ini_read_vector3_def(section, 'hud_move_landing2_offset_pos_16x9', @zerovec);
       v_mul(@tmp, koef);
       v_add(pos, @tmp);
       tmp:=game_ini_read_vector3_def(section, 'hud_move_landing2_offset_rot_16x9', @zerovec);
       v_mul(@tmp, koef);
       v_add(rot, @tmp);
     end else begin
       tmp:=game_ini_read_vector3_def(section, 'hud_move_landing2_offset_pos', @zerovec);
       v_mul(@tmp, koef);
       v_add(pos, @tmp);
       tmp:=game_ini_read_vector3_def(section, 'hud_move_landing2_offset_rot', @zerovec);
       v_mul(@tmp, koef);
       v_add(rot, @tmp);
     end;
     factor^:=1;
  end;
//  log(floattostr(rot.x)+', '+floattostr(rot.y)+', '+floattostr(rot.z));
end;



procedure UpdateWeaponOffset(act:pointer);
var
  itm, HID:pointer;
  section:PChar;
  cur_time, delta:cardinal;
  factor, speed_pos, speed_rot:single;
  targetpos, targetrot, cur_pos, cur_rot, pos, rot, zerovec:FVector3;
begin
  if not IsWeaponmoveEnabled() then exit;
  itm:=GetActorActiveItem();
  if itm=nil then itm:=GetActiveDetector(act);
  if itm=nil then exit;
  HID:=CHudItem__HudItemData(itm);
  if HID=nil then exit;

  cur_time:=BaseGameData.GetGameTickCount();
  if last_update_time=0 then last_update_time:=cur_time;

  delta:=GetTimeDeltaSafe(last_update_time, cur_time);
  time_accumulator:=time_accumulator+delta;

  section:=GetHUDSection(itm);
  v_zero(@zerovec);  

  if GetActorActionState(act, actCrouch, mState_WISHFUL) and not  GetActorActionState(act, actCrouch, mState_REAL) then begin
    //начали присяд
    tocrouch_time_remains:=floor(game_ini_r_single_def(section, 'to_crouch_time', 0)*1000);
    fromcrouch_time_remains:=0;
  end else if not GetActorActionState(act, actCrouch, mState_WISHFUL) and GetActorActionState(act, actCrouch, mState_REAL) then begin
    //закончили присяд
    fromcrouch_time_remains:=floor(game_ini_r_single_def(section, 'from_crouch_time', 0)*1000);
    tocrouch_time_remains:=0;
  end;

  if GetActorActionState(act, actCrouch, mState_WISHFUL) and GetActorActionState(act, actSlow, mState_WISHFUL) and not GetActorActionState(act, actSlow, mState_REAL) then begin
    //начали присяд
    toslowcrouch_time_remains:=floor(game_ini_r_single_def(section, 'to_slow_crouch_time', 0)*1000);
    fromslowcrouch_time_remains:=0;
  end else if GetActorActionState(act, actCrouch, mState_WISHFUL) and not GetActorActionState(act, actSlow, mState_WISHFUL) and GetActorActionState(act, actSlow, mState_REAL) then begin
    //закончили присяд
    fromslowcrouch_time_remains:=floor(game_ini_r_single_def(section, 'from_slow_crouch_time', 0)*1000);
    toslowcrouch_time_remains:=0;
  end;

  //вычислим целевое смещение от равновесия
  if cardinal(GetCurrentState(itm))=CHUDState__eHiding then begin
    v_zero(@targetpos);
    v_zero(@targetrot);
    factor:=game_ini_r_single_def(section, 'hud_move_weaponhide_factor', 1.0);
  end else if (WpnCanShoot(PChar(HudItemUtils.GetClassName(itm))) or IsBino(PChar(HudItemUtils.GetClassName(itm)))) and (IsAimNow(itm) or IsHolderInAimState(itm) or (GetAimFactor(itm)>0)) then begin
    v_zero(@targetpos);
    v_zero(@targetrot);
    factor:=game_ini_r_single_def(section, 'hud_move_unzoom_factor', 1.0);  
  end else begin
    GetCurrentTargetOffset(act, section, @targetpos, @targetrot, @factor);
  end;

  //находим целевую позицию
  if Is16x9() then begin
    pos:=game_ini_read_vector3_def(section, 'hands_position_16x9', @zerovec);
    rot:=game_ini_read_vector3_def(section, 'hands_orientation_16x9', @zerovec);
  end else begin
    pos:=game_ini_read_vector3_def(section, 'hands_position', @zerovec);
    rot:=game_ini_read_vector3_def(section, 'hands_orientation', @zerovec);
  end;
  v_add(@targetpos, @pos);
  v_add(@targetrot, @rot);


  //смотрим на скорость сдвига
  speed_rot:=game_ini_r_single_def(section, 'hud_move_speed_rot', 0.4)*factor/100;
  speed_pos:=game_ini_r_single_def(section, 'hud_move_speed_pos', 0.1)*factor/100;

  //120 коррекций в секунду к вычисленному положению
  while (time_accumulator>8) do begin
    //смотрим, куда будем двигать худ
    pos:=targetpos;
    rot:=targetrot;

    
    cur_pos:=GetHandsPosOffset(hid);
    cur_rot:=GetHandsRotOffset(hid);
//log(floattostr(cur_pos.x)+', '+floattostr(cur_pos.y)+', '+floattostr(cur_pos.z));

    v_sub(@pos, @cur_pos);
    v_sub(@rot, @cur_rot);

    //пересчитываем вектор сдвига с учетом скорости
    if v_length(@pos)>0.0001 then v_mul(@pos, speed_pos);
    if v_length(@rot)>0.0001 then v_mul(@rot, speed_rot);

    //добавляем пересчитанный сдвиг к текущему положению и записываем его
    v_add(@cur_pos, @pos);
    v_add(@cur_rot, @rot);
    SetHandsPosOffset(hid, @cur_pos);    
    SetHandsRotOffset(hid, @cur_rot);

    time_accumulator:=time_accumulator-8;
  end;

  last_update_time:=cur_time;
  if fromcrouch_time_remains>delta then fromcrouch_time_remains:=fromcrouch_time_remains-delta else fromcrouch_time_remains:=0;
  if tocrouch_time_remains>delta then tocrouch_time_remains:=tocrouch_time_remains-delta else tocrouch_time_remains:=0;
  if fromslowcrouch_time_remains>delta then fromslowcrouch_time_remains:=fromslowcrouch_time_remains-delta else fromslowcrouch_time_remains:=0;
  if toslowcrouch_time_remains>delta then toslowcrouch_time_remains:=toslowcrouch_time_remains-delta else toslowcrouch_time_remains:=0;
end;

procedure CorrectActorCameraHeight(h:psingle); stdcall;
var
  delta, curtime:cardinal;
  max_offset, offset, speed:single;
  act, wpn:pointer;
  buf:WpnBuf;
begin
  if _last_camera_height = 0 then begin
    _last_camera_height:=h^;
    _last_cam_update_time:=GetGameTickCount();
    exit;
  end;

  curtime:=GetGameTickCount();
  delta:=GetTimeDeltaSafe(_last_cam_update_time, curtime);
  _last_cam_update_time:=curtime;


  speed:=GetCamSpeedDef();
  act:=GetActor();
  if act<>nil then begin
    wpn := GetActorActiveItem();
    if wpn<>nil then begin
      buf:=GetBuffer(wpn);
      if buf<>nil then begin
        speed:=buf.GetCameraSpeed();
      end;
    end;
  end;
  
  max_offset:=delta*speed/1000;

  offset:=h^-_last_camera_height;

  if abs(offset)>max_offset then begin
    if offset>0 then begin
      h^:=_last_camera_height+max_offset
    end else begin
      h^:=_last_camera_height-max_offset
    end;
  end;

  _last_camera_height:=h^;
end;

procedure CActor__CameraHeight_Patch(); stdcall;
asm
  addss xmm0, [esi+$52c]

  pushad
  
  push eax
  movss [esp], xmm0

  push esp
  call CorrectActorCameraHeight

  movss xmm0, [esp]
  add esp, 4
  
  popad
  fldz
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


  //CActor::cam_Update - в инлайне CActor::CameraHeight подменяем результирующее значение высоты камеры (для плавности)
  addr:=xrgame_addr+$274359;
  if not WriteJump(addr, cardinal(@CActor__CameraHeight_Patch), 8, true) then exit;

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
