unit WeaponInertion;

interface
function Init():boolean;
procedure UpdateInertion (wpn:pointer);
procedure UpdateWeaponOffset(act:pointer; delta:cardinal);
procedure ResetWpnOffset();
procedure ResetCamHeight();
procedure ResetItmHudOffset(itm:pointer); stdcall;

implementation
uses BaseGameData, gunsl_config, HudItemUtils, windows, strutils, MatVectors, ActorUtils, DetectorUtils, sysutils, math, WeaponAdditionalBuffer, ControllerMonster;

var
  i_p:weapon_inertion_params;
  time_accumulator:cardinal;

  _last_camera_height:single;
  _last_cam_update_time:cardinal;
  _landing_effect_time_remains:cardinal;
  _landing2_effect_time_remains:cardinal;
  _landing_effect_finish_time_remains:cardinal;
  
  tocrouch_time_remains, fromcrouch_time_remains:cardinal;
  toslowcrouch_time_remains, fromslowcrouch_time_remains:cardinal;

  torlookout_time_remains, fromrlookout_time_remains:cardinal;
  tollookout_time_remains, fromllookout_time_remains:cardinal;

procedure ResetWpnOffset();
begin
  time_accumulator:=0;
  tocrouch_time_remains:=0;
  fromcrouch_time_remains:=0;

  toslowcrouch_time_remains:=0;
  fromslowcrouch_time_remains:=0;

  torlookout_time_remains:=0;
  fromrlookout_time_remains:=0;
  tollookout_time_remains:=0;
  fromllookout_time_remains:=0;

end;

function ValueSineInterpolation_f(x:single; max_val:single; period:single):single;
begin
  result:=0.5*max_val*(1+sin(-pi/2 + x*pi/period));
end;

function ValueSineInterpolation_f_inverse(cur_val:single; max_val:single; period:single):single;
begin
  result:=(arcsin((2*cur_val/max_val) - 1)+pi/2)*(period/pi);
end;

function ValueSineInterpolation(cur_val:single; max_val:single; period:single; dt:single):single;
var
  x:single;
const
  EPS:single=0.00001;
begin
//1) получим х по f(x)
//2) вернем f(x+dt)
  if abs(dt)<EPS then begin
    result:=cur_val;
    exit;
  end else if (dt>0) and (abs(cur_val-max_val)<EPS) then begin
    result:=max_val;
    exit;
  end else if (dt<0) and (abs(cur_val-max_val)<EPS) then begin
    result:=0;
    exit;
  end;

  x:=ValueSineInterpolation_f_inverse(cur_val, max_val, period);
  if (dt>0) and (x+dt>period) then begin
    x:=period;
  end else if  (dt<0) and (x-dt<0) then begin
    x:=0;
  end else begin
    x:=x+dt;
  end;

  result:=ValueSineInterpolation_f(x, max_val, period);
end;

procedure ResetCamHeight();
begin
  _last_camera_height:=0;
  _last_cam_update_time:=0;
  _landing_effect_time_remains:=0;
  _landing2_effect_time_remains:=0;
  _landing_effect_finish_time_remains:=0;
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

function GradientClamp(target, current, koef, eps:single):single;
begin
  result:=(target-current)*koef;
  if abs(result)<eps then result:=(target-current);
end;

procedure UpdateInertion (wpn:pointer);
var
  koef:single;
  sect, scp:PChar;
  def_inert, aim_inert:weapon_inertion_params;
const
  eps:single = 0.0003;
  g_koef:single = 0.07;
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

    if (GetScopeStatus(wpn)=2) and IsScopeAttached(wpn) then begin
      //влияние установленного прицела на инерцию вне зума
      scp:=GetCurrentScopeSection(wpn);
      def_inert.pitch_offset_r:=def_inert.pitch_offset_r*game_ini_r_single_def(scp, 'inertion_pitch_offset_r_factor', 1.0);
      def_inert.pitch_offset_n:=def_inert.pitch_offset_n*game_ini_r_single_def(scp, 'inertion_pitch_offset_n_factor', 1.0);
      def_inert.pitch_offset_d:=def_inert.pitch_offset_d*game_ini_r_single_def(scp, 'inertion_pitch_offset_d_factor', 1.0);
      def_inert.origin_offset:=def_inert.origin_offset*game_ini_r_single_def(scp, 'inertion_origin_offset_factor', 1.0);
      def_inert.speed:=def_inert.speed*game_ini_r_single_def(scp, 'inertion_speed_factor', 1.0);
    end;

    if IsAimNow(wpn) or (leftstr(GetActualCurrentAnim(wpn), length('anm_idle_aim'))='anm_idle_aim')  then begin
      aim_inert:=GetStdInertion(true);

      if IsGrenadeMode(wpn) then begin
        aim_inert.pitch_offset_r:=game_ini_r_single_def(sect, 'inertion_gl_pitch_offset_r', aim_inert.pitch_offset_r);
        aim_inert.pitch_offset_n:=game_ini_r_single_def(sect, 'inertion_gl_pitch_offset_n', aim_inert.pitch_offset_n);
        aim_inert.pitch_offset_d:=game_ini_r_single_def(sect, 'inertion_gl_pitch_offset_d', aim_inert.pitch_offset_d);
        aim_inert.origin_offset:=game_ini_r_single_def(sect, 'inertion_gl_origin_offset', aim_inert.origin_offset);
        aim_inert.speed:=game_ini_r_single_def(sect, 'inertion_gl_speed', aim_inert.speed);      
      end else begin
        aim_inert.pitch_offset_r:=game_ini_r_single_def(sect, 'inertion_aim_pitch_offset_r', aim_inert.pitch_offset_r);
        aim_inert.pitch_offset_n:=game_ini_r_single_def(sect, 'inertion_aim_pitch_offset_n', aim_inert.pitch_offset_n);
        aim_inert.pitch_offset_d:=game_ini_r_single_def(sect, 'inertion_aim_pitch_offset_d', aim_inert.pitch_offset_d);
        aim_inert.origin_offset:=game_ini_r_single_def(sect, 'inertion_aim_origin_offset', aim_inert.origin_offset);
        aim_inert.speed:=game_ini_r_single_def(sect, 'inertion_aim_speed', aim_inert.speed);
      end;

      if (GetScopeStatus(wpn)=2) and IsScopeAttached(wpn) then begin
        //влияние установленного прицела на инерцию в зуме      
        scp:=GetCurrentScopeSection(wpn);
        if IsGrenadeMode(wpn) then begin
          aim_inert.pitch_offset_r:=game_ini_r_single_def(scp, 'inertion_gl_pitch_offset_r', aim_inert.pitch_offset_r);
          aim_inert.pitch_offset_n:=game_ini_r_single_def(scp, 'inertion_gl_pitch_offset_n', aim_inert.pitch_offset_n);
          aim_inert.pitch_offset_d:=game_ini_r_single_def(scp, 'inertion_gl_pitch_offset_d', aim_inert.pitch_offset_d);
          aim_inert.origin_offset:=game_ini_r_single_def(scp, 'inertion_gl_origin_offset', aim_inert.origin_offset);
          aim_inert.speed:=game_ini_r_single_def(scp, 'inertion_gl_speed', aim_inert.speed);        
        end else begin
          aim_inert.pitch_offset_r:=game_ini_r_single_def(scp, 'inertion_aim_pitch_offset_r', aim_inert.pitch_offset_r);
          aim_inert.pitch_offset_n:=game_ini_r_single_def(scp, 'inertion_aim_pitch_offset_n', aim_inert.pitch_offset_n);
          aim_inert.pitch_offset_d:=game_ini_r_single_def(scp, 'inertion_aim_pitch_offset_d', aim_inert.pitch_offset_d);
          aim_inert.origin_offset:=game_ini_r_single_def(scp, 'inertion_aim_origin_offset', aim_inert.origin_offset);
          aim_inert.speed:=game_ini_r_single_def(scp, 'inertion_aim_speed', aim_inert.speed);
        end;
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

{  i_p.pitch_offset_r:=i_p.pitch_offset_r-clamp(i_p.pitch_offset_r-def_inert.pitch_offset_r, -eps, eps);
  i_p.pitch_offset_n:=i_p.pitch_offset_n-clamp(i_p.pitch_offset_n-def_inert.pitch_offset_n, -eps, eps);
  i_p.pitch_offset_d:=i_p.pitch_offset_d-clamp(i_p.pitch_offset_d-def_inert.pitch_offset_d, -eps, eps);
  i_p.origin_offset:=i_p.origin_offset-clamp(i_p.origin_offset-def_inert.origin_offset, -eps, eps);
  i_p.speed:=def_inert.speed;

  i_p.pitch_offset_r:=i_p.pitch_offset_r+GradientClamp(def_inert.pitch_offset_r, i_p.pitch_offset_r, g_koef, eps);
  i_p.pitch_offset_n:=i_p.pitch_offset_n+GradientClamp(def_inert.pitch_offset_n, i_p.pitch_offset_n, g_koef, eps);
  i_p.pitch_offset_d:=i_p.pitch_offset_d+GradientClamp(def_inert.pitch_offset_d, i_p.pitch_offset_d, g_koef, eps);
  i_p.origin_offset:=i_p.origin_offset+GradientClamp(def_inert.origin_offset, i_p.origin_offset, g_koef, eps);
  i_p.speed:=def_inert.speed;

  i_p.pitch_offset_r:=i_p.pitch_offset_r-clamp(i_p.pitch_offset_r-def_inert.pitch_offset_r, -eps, eps);
  i_p.pitch_offset_n:=i_p.pitch_offset_n-clamp(i_p.pitch_offset_n-def_inert.pitch_offset_n, -eps, eps);
  i_p.pitch_offset_d:=i_p.pitch_offset_d-clamp(i_p.pitch_offset_d-def_inert.pitch_offset_d, -eps, eps);
  i_p.origin_offset:=i_p.origin_offset+GradientClamp(def_inert.origin_offset, i_p.origin_offset, g_koef, eps);
  i_p.speed:=def_inert.speed;  }
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

procedure AddOffsets(base:string; section:PChar; pos:pFVector3; rot:pFVector3; koef:single=1.0);
var
  tmp, zerovec:FVector3;

begin
  v_zero(@zerovec);
  if Is16x9() then begin
    tmp:=game_ini_read_vector3_def(section, PChar(base+'_pos_16x9'), @zerovec);
    v_mul(@tmp, koef);
    v_add(pos, @tmp);
    tmp:=game_ini_read_vector3_def(section, PChar(base+'_rot_16x9'), @zerovec);
    v_mul(@tmp, koef);
    v_add(rot, @tmp);
  end else begin
    tmp:=game_ini_read_vector3_def(section, PChar(base+'_pos'), @zerovec);
    v_mul(@tmp, koef);
    v_add(pos, @tmp);
    tmp:=game_ini_read_vector3_def(section, PChar(base+'_rot'), @zerovec);
    v_mul(@tmp, koef);
    v_add(rot, @tmp);
  end;
end;

procedure AddSuicideOffset(act:pointer; section:PChar; pos:pFVector3; rot:pFVector3);stdcall;
begin
  if game_ini_r_bool_def(section, 'prohibit_suicide', false) then exit;
  if game_ini_r_bool_def(section, 'no_other_hud_moving_while_suicide', false) then begin
    v_zero(rot);
    v_zero(pos);
  end;

  AddOffsets('hud_move_suicide_offset', section, pos, rot);
  //todo:разные скорости суицида в зависимости от пси-защищенности
end;


procedure GetCurrentTargetOffset_aim(act:pointer; section:PChar; pos:pFVector3; rot:pFVector3; factor:pSingle);
var
  zerovec:FVector3;
  koef:single;  
begin
  v_zero(pos);
  v_zero(rot);
  v_zero(@zerovec);
  factor^:=1;

  if GetActorActionState(act, actCrouch) and GetActorActionState(act, actSlow) then begin
    koef:=game_ini_r_single_def(section, 'hud_aim_move_slow_crouch_factor', 1.0);
  end else if GetActorActionState(act, actCrouch) then begin
    koef:=game_ini_r_single_def(section, 'hud_aim_move_crouch_factor', 1.0);
  end else if GetActorActionState(act, actSlow) then begin
    koef:=game_ini_r_single_def(section, 'hud_aim_move_slow_factor', 1.0);
  end else begin
    koef:=1;
  end;

  if tocrouch_time_remains>0 then begin
    AddOffsets('hud_aim_move_to_crouch_offset', section, pos, rot, koef);
  end;

  if fromcrouch_time_remains>0 then begin
    AddOffsets('hud_aim_move_from_crouch_offset', section, pos, rot, koef);
  end;

  if toslowcrouch_time_remains>0 then begin
    AddOffsets('hud_aim_move_to_slow_crouch_offset', section, pos, rot, koef);
  end;

  if fromslowcrouch_time_remains>0 then begin
    AddOffsets('hud_aim_move_from_slow_crouch_offset', section, pos, rot, koef);
  end;

  if torlookout_time_remains>0 then begin
    AddOffsets('hud_aim_move_to_rlookout_offset', section, pos, rot, koef);
  end;

  if fromrlookout_time_remains>0 then begin
    AddOffsets('hud_aim_move_from_rlookout_offset', section, pos, rot, koef);
  end;

  if tollookout_time_remains>0 then begin
    AddOffsets('hud_aim_move_to_llookout_offset', section, pos, rot, koef);
  end;

  if fromllookout_time_remains>0 then begin
    AddOffsets('hud_aim_move_from_llookout_offset', section, pos, rot, koef);
  end;

end;

procedure GetCurrentTargetOffset(act:pointer; section:PChar; pos:pFVector3; rot:pFVector3; factor:pSingle);
var
  zerovec:FVector3;
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
    AddOffsets('hud_move_to_crouch_offset', section, pos, rot, koef);
    factor^:=1;
  end;

  if fromcrouch_time_remains>0 then begin
    AddOffsets('hud_move_from_crouch_offset', section, pos, rot, koef);
    factor^:=1;
  end;

  if toslowcrouch_time_remains>0 then begin
    AddOffsets('hud_move_to_slow_crouch_offset', section, pos, rot, koef);
    factor^:=1;
  end;

  if fromslowcrouch_time_remains>0 then begin
    AddOffsets('hud_move_from_slow_crouch_offset', section, pos, rot, koef);
    factor^:=1;
  end;

  if torlookout_time_remains>0 then begin
    AddOffsets('hud_move_to_rlookout_offset', section, pos, rot, koef);
    factor^:=1;
  end;

  if fromrlookout_time_remains>0 then begin
    AddOffsets('hud_move_from_rlookout_offset', section, pos, rot, koef);
    factor^:=1;
  end;

  if tollookout_time_remains>0 then begin
    AddOffsets('hud_move_to_llookout_offset', section, pos, rot, koef);
    factor^:=1;
  end;

  if fromllookout_time_remains>0 then begin
    AddOffsets('hud_move_from_llookout_offset', section, pos, rot, koef);
    factor^:=1;
  end;

  if GetActorActionState(act, actRLookout) and not GetActorActionState(act, actLLookout) then begin
    AddOffsets('hud_move_rlookout_offset', section, pos, rot, koef);
    factor^:=game_ini_r_single_def(section, 'hud_move_rlookout_offset_speed_factor', 1);
  end;

  if GetActorActionState(act, actLLookout) and not GetActorActionState(act, actRLookout) then begin
    AddOffsets('hud_move_llookout_offset', section, pos, rot, koef);
    factor^:=game_ini_r_single_def(section, 'hud_move_llookout_offset_speed_factor', 1);
  end;

  if GetActorActionState(act, actMovingLeft) and not GetActorActionState(act, actMovingRight) then begin
    AddOffsets('hud_move_left_offset', section, pos, rot, koef);
    factor^:=1;
  end;

  if GetActorActionState(act, actMovingRight) and not GetActorActionState(act, actMovingLeft) then begin
    AddOffsets('hud_move_right_offset', section, pos, rot, koef);
    factor^:=1;
  end;

  if GetActorActionState(act, actMovingForward) and not GetActorActionState(act, actMovingBack) then begin
    AddOffsets('hud_move_forward_offset', section, pos, rot, koef);
    factor^:=1;
  end;

  if GetActorActionState(act, actMovingBack) and not GetActorActionState(act, actMovingForward) then begin
    AddOffsets('hud_move_back_offset', section, pos, rot, koef);
     factor^:=1;
  end;

  if GetActorActionState(act, actJump) and not GetActorActionState(act, actFall) and not GetActorActionState(act, actLanding) and not GetActorActionState(act, actLanding2) then begin
    AddOffsets('hud_move_jump_offset', section, pos, rot, koef);
    factor^:=1;
  end;

  if GetActorActionState(act, actFall) and not GetActorActionState(act, actJump) and not GetActorActionState(act, actLanding) and not GetActorActionState(act, actLanding2) then begin
    AddOffsets('hud_move_fall_offset', section, pos, rot, koef);
    factor^:=1;
  end;

  if GetActorActionState(act, actLanding) and not GetActorActionState(act, actJump) and not GetActorActionState(act, actFall)  and not GetActorActionState(act, actLanding2) then begin
    AddOffsets('hud_move_landing_offset', section, pos, rot, koef);
    factor^:=1;
  end;

  if GetActorActionState(act, actLanding2) and not GetActorActionState(act, actJump) and not GetActorActionState(act, actFall)  and not GetActorActionState(act, actLanding) then begin
    AddOffsets('hud_move_landing2_offset', section, pos, rot, koef);
    factor^:=1;
  end;
end;

procedure ResetItmHudOffset(itm:pointer); stdcall;
var
  pos, rot, zerovec:FVector3;
  hid:pointer;
  section:PChar;
begin
  hid:=CHudItem__HudItemData(itm);
  if hid=nil then exit;
  section:=GetHUDSection(itm);
  v_zero(@zerovec);
  if Is16x9() then begin
    pos:=game_ini_read_vector3_def(section, 'hands_position_16x9', @zerovec);
    rot:=game_ini_read_vector3_def(section, 'hands_orientation_16x9', @zerovec);
  end else begin
    pos:=game_ini_read_vector3_def(section, 'hands_position', @zerovec);
    rot:=game_ini_read_vector3_def(section, 'hands_orientation', @zerovec);
  end;

  SetHandsPosOffset(hid, @pos);
  SetHandsRotOffset(hid, @rot);
end;



procedure UpdateWeaponOffset(act:pointer; delta:cardinal);
var
  itm, det, HID:pointer;
  section:PChar;
  factor, speed_pos, speed_rot:single;
  jitter:jitter_params;
  targetpos, targetrot, cur_pos, cur_rot, pos, rot, zerovec:FVector3;
begin
  if not IsWeaponmoveEnabled() then exit;

  itm:=GetActorActiveItem();
  if itm=nil then begin
    itm:=GetActiveDetector(act);
    det:=nil;
  end else begin
    det:=GetActiveDetector(act);
  end;
  if itm=nil then exit;
  HID:=CHudItem__HudItemData(itm);
  if HID=nil then exit;

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

  if not (GetActorActionState(act, actRLookout, mState_REAL) and GetActorActionState(act, actLLookout, mState_REAL)) then begin
    //если одновременно выглядываем влево и вправо - что-то тут не так...
    if GetActorActionState(act, actRLookout, mState_WISHFUL) and not  GetActorActionState(act, actRLookout, mState_REAL) then begin
      //начали выглядывать вправо
      torlookout_time_remains:=floor(game_ini_r_single_def(section, 'to_rlookout_time', 0)*1000);
      fromrlookout_time_remains:=0;

    end else if not GetActorActionState(act, actRLookout, mState_WISHFUL) and GetActorActionState(act, actRLookout, mState_REAL) then begin
      //закончили выглядывать вправо
      fromrlookout_time_remains:=floor(game_ini_r_single_def(section, 'from_rlookout_time', 0)*1000);
      torlookout_time_remains:=0;
    end;

    if GetActorActionState(act, actLLookout, mState_WISHFUL) and not  GetActorActionState(act, actLLookout, mState_REAL) then begin
      //начали выглядывать влево
      tollookout_time_remains:=floor(game_ini_r_single_def(section, 'to_llookout_time', 0)*1000);
      fromllookout_time_remains:=0;
    end else if not GetActorActionState(act, actLLookout, mState_WISHFUL) and GetActorActionState(act, actLLookout, mState_REAL) then begin
      //закончили выглядывать влево
      fromllookout_time_remains:=floor(game_ini_r_single_def(section, 'from_llookout_time', 0)*1000);
      tollookout_time_remains:=0;
    end;
  end;

  //прочитаем конфиговые умолчания
  if Is16x9() then begin
    pos:=game_ini_read_vector3_def(section, 'hands_position_16x9', @zerovec);
    rot:=game_ini_read_vector3_def(section, 'hands_orientation_16x9', @zerovec);
  end else begin
    pos:=game_ini_read_vector3_def(section, 'hands_position', @zerovec);
    rot:=game_ini_read_vector3_def(section, 'hands_orientation', @zerovec);
  end;

  //вычислим целевое смещение от равновесия
  if (cardinal(GetCurrentState(itm))=CHUDState__eHiding) or ((det<>nil) and (cardinal(GetCurrentState(det))=CHUDState__eHiding)) then begin
    v_zero(@targetpos);
    v_zero(@targetrot);
    factor:=game_ini_r_single_def(section, 'hud_move_weaponhide_factor', 1.0);
  end else if (WpnCanShoot(itm) or IsBino(itm)) and (IsAimNow(itm) or IsHolderInAimState(itm) or (GetAimFactor(itm)>0)) then begin
    GetCurrentTargetOffset_aim(act, section, @targetpos, @targetrot, @factor);
    factor:=game_ini_r_single_def(section, 'hud_move_unzoom_factor', 1.0);
  end else begin
    GetCurrentTargetOffset(act, section, @targetpos, @targetrot, @factor);
    if IsActorSuicideNow() then begin
      AddSuicideOffset(act, section, @targetpos, @targetrot);
    end else if (hid<>nil) and (not GetActorActionState(act, actMovingForward)) and (not GetActorActionState(act, actMovingBack)) and (not GetActorActionState(act, actMovingLeft)) and (not GetActorActionState(act, actMovingRight)) and (not GetActorActionState(act, actMovingForward)) and (not GetActorActionState(act, actSprint)) and not GetActorActionState(act, actJump) and not GetActorActionState(act, actFall) and not GetActorActionState(act, actLanding) and not GetActorActionState(act, actLanding2) then begin
      //todo:смещение в идле
    end;
  end;

  //находим целевую позицию
  v_add(@targetpos, @pos);
  v_add(@targetrot, @rot);

  //смотрим на скорость сдвига
  if not IsActorSuicideNow() and not IsSuicideAnimPlaying(itm) then begin
    speed_rot:=game_ini_r_single_def(section, 'hud_move_speed_rot', 0.4)*factor/100;
    speed_pos:=game_ini_r_single_def(section, 'hud_move_speed_pos', 0.1)*factor/100;
  end else begin
    speed_rot:=game_ini_r_single_def(section, 'suicide_speed_rot', 0.002);
    speed_pos:=game_ini_r_single_def(section, 'suicide_speed_pos', 0.2);
  end;

  //120 коррекций в секунду к вычисленному положению
  while (time_accumulator>8) do begin
    //смотрим, куда будем двигать худ
    pos:=targetpos;
    rot:=targetrot;

    cur_pos:=GetHandsPosOffset(hid);
    cur_rot:=GetHandsRotOffset(hid);

    v_sub(@pos, @cur_pos);
    v_sub(@rot, @cur_rot);

    //пересчитываем вектор сдвига с учетом скорости
    if IsActorSuicideNow() then begin
      //идем линейно
      if v_length(@pos)>speed_pos then v_setlength(@pos, speed_pos);
      if v_length(@rot)>speed_rot then v_setlength(@rot, speed_rot);
    end else begin
      if v_length(@pos)>0.0001 then v_mul(@pos, speed_pos);
      if v_length(@rot)>0.0001 then v_mul(@rot, speed_rot);
    end;

    //добавляем пересчитанный сдвиг к текущему положению и записываем его
    v_add(@cur_pos, @pos);
    v_add(@cur_rot, @rot);


    //если актор в зоне действия контролера - добавим дрожание рук
    if IsHandJitter(itm) then begin;
      jitter:=GetCurJitterParams(section);

      pos.x:=random(1000)-500;
      pos.y:=random(500)-250;
      pos.z:=random(1000)-500;
      v_setlength(@pos, jitter.pos_amplitude*GetHandJitterScale(itm));
      v_add(@cur_pos, @pos);

      rot.x:=random(1000)-500;
      rot.y:=random(1000)-500;
      rot.z:=random(1000)-500;
      v_setlength(@rot, jitter.rot_amplitude*GetHandJitterScale(itm));
      v_add(@cur_rot, @rot);
    end;
    
    SetHandsPosOffset(hid, @cur_pos);
    SetHandsRotOffset(hid, @cur_rot);

    time_accumulator:=time_accumulator-8;
  end;

  if IsActorSuicideNow() and not (game_ini_r_bool_def(section, 'prohibit_suicide', false) or game_ini_r_bool_def(section, 'suicide_by_animation', false)) then begin
    jitter:=GetCurJitterParams(section);
    pos:=GetHandsPosOffset(hid);
    rot:=GetHandsRotOffset(hid);
    v_sub(@pos, @targetpos);
    v_sub(@rot, @targetrot);
    if (v_length(@pos)<jitter.pos_amplitude*2) and (v_length(@rot)<jitter.rot_amplitude*2) then begin
      DoSuicideShot();
    end;
  end;
  if fromcrouch_time_remains>delta then fromcrouch_time_remains:=fromcrouch_time_remains-delta else fromcrouch_time_remains:=0;
  if tocrouch_time_remains>delta then tocrouch_time_remains:=tocrouch_time_remains-delta else tocrouch_time_remains:=0;
  if fromslowcrouch_time_remains>delta then fromslowcrouch_time_remains:=fromslowcrouch_time_remains-delta else fromslowcrouch_time_remains:=0;
  if toslowcrouch_time_remains>delta then toslowcrouch_time_remains:=toslowcrouch_time_remains-delta else toslowcrouch_time_remains:=0;

  if fromrlookout_time_remains>delta then fromrlookout_time_remains:=fromrlookout_time_remains-delta else fromrlookout_time_remains:=0;
  if torlookout_time_remains>delta then torlookout_time_remains:=torlookout_time_remains-delta else torlookout_time_remains:=0;

  if fromllookout_time_remains>delta then fromllookout_time_remains:=fromllookout_time_remains-delta else fromllookout_time_remains:=0;
  if tollookout_time_remains>delta then tollookout_time_remains:=tollookout_time_remains-delta else tollookout_time_remains:=0;
end;


//h - и вход и выход. Вход - целевое, выход - фактическое к установке
procedure CorrectActorCameraHeight(h:psingle); stdcall;
var
  dt, curtime:cardinal;
  max_offset, speed, target_h, dh, delta, dh_pow:single;
  landing:landing_params;
  act, wpn:pointer;
  buf:WpnBuf;
begin
  act:=GetActor();
    
  if _last_camera_height = 0 then begin
    _last_camera_height:=h^;
    _last_cam_update_time:=GetGameTickCount();
    exit;
  end;

  curtime:=GetGameTickCount();
  dt:=GetTimeDeltaSafe(_last_cam_update_time, curtime);
  _last_cam_update_time:=curtime;

  landing:=GetCamLandingParams();
  if (act<>nil) and GetActorActionState(act, actLanding2) then begin
    _landing2_effect_time_remains:=landing.time_landing2;
    _landing_effect_time_remains:=0;
    _landing_effect_finish_time_remains:=0;
  end else if (act<>nil) and GetActorActionState(act, actLanding) then begin
    _landing2_effect_time_remains:=0;
    _landing_effect_time_remains:=landing.time_landing;
    _landing_effect_finish_time_remains:=0;
  end;

  dh_pow:=GetCamSpeedPow();
  speed:=GetCamSpeedDef();
  if act<>nil then begin
    wpn := GetActorActiveItem();
    if wpn<>nil then begin
      buf:=GetBuffer(wpn);
      if buf<>nil then begin
        speed:= buf.GetCameraSpeed();
      end;
    end;
  end;


  if _landing_effect_time_remains>0 then begin
    max_offset:=landing.offset_landing;
    speed:=speed*landing.cam_speed_factor;
    dh_pow:=dh_pow*landing.pow_factor;

  end else if _landing2_effect_time_remains>0 then begin
    max_offset:=landing.offset_landing2;
    speed:=speed*landing.cam_speed_factor2;
    dh_pow:=dh_pow*landing.pow_factor2;
    
  end else if _landing_effect_finish_time_remains>0 then begin
    speed:=speed*landing.cam_speed_finish_landing_factor;
    dh_pow:=dh_pow*landing.pow_finish_landing_factor;
    max_offset:=0;
    //log('Up');
  end else begin
    max_offset:=0;
  end;


  target_h:=h^+max_offset;
  dh:=target_h-_last_camera_height;
  delta:=abs(power(abs(dh), dh_pow)*dt*speed/1000);

  if dh<0 then begin
    delta:=delta*(-1);
  end;

  if abs(delta)>abs(dh) then begin
    delta:=dh;
    _landing_effect_finish_time_remains:=0;
  end;

  h^:=_last_camera_height+delta;
  _last_camera_height:=h^;

  if _landing_effect_time_remains>dt then begin
    _landing_effect_time_remains:=_landing_effect_time_remains-dt;
  end else if _landing_effect_time_remains > 0 then begin
    _landing_effect_finish_time_remains:=landing.time_finish_landing;
    _landing_effect_time_remains:=0;
  end;

  if _landing_effect_finish_time_remains>dt then _landing_effect_finish_time_remains:=_landing_effect_finish_time_remains-dt else _landing_effect_finish_time_remains:=0;

  if _landing2_effect_time_remains>dt then _landing2_effect_time_remains:=_landing2_effect_time_remains-dt else _landing2_effect_time_remains:=0;

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
end;

procedure LookoutFunctionReplace(act:pointer; cur_roll:psingle; tgt_roll:single; dt:single); stdcall;
var
  dx, delta:single;
  speed, koef, ampl_k, dx_pow:single;
  itm:pointer;
const
  EPS=0.0001;
begin
  speed:=GetBaseLookoutParams().speed;
  ampl_k:=GetBaseLookoutParams().ampl_k;
  dx_pow:=GetBaseLookoutParams().dx_pow;

  if (act<>nil) and (act=GetActor()) then begin
    itm:=GetActorActiveItem;
    if itm<>nil then begin
      koef:=game_ini_r_single_def(GetHUDSection(itm), 'lookout_speed_koef', 1.0);
      speed:=koef*speed;

      koef:=game_ini_r_single_def(GetHUDSection(itm), 'lookout_ampl_k', 1.0);
      ampl_k:=ampl_k*koef;
    end;
  end;

  tgt_roll:=tgt_roll*ampl_k;

  dx:=tgt_roll-cur_roll^;
  delta:=abs(power(abs(dx), dx_pow)*dt*speed);

  if dx<0 then begin
    delta:=delta*(-1);
  end;

  if abs(delta)>abs(dx) then begin
    delta:=dx;
  end;
  cur_roll^:=cur_roll^+delta;

end;

procedure LookoutFunctionReplace_Patch; stdcall
asm
  mov eax, esp
  pushad
  push [eax+$10]
  push [eax+$8]
  push [eax+$4]
  push esi
  call LookoutFunctionReplace;
  popad
end;

function Init():boolean;
var
  addr, rb:cardinal;
  ptr:pointer;
  b:byte;
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

  //меняем байт перехода в CActor::g_Physics на безусловный, чтобы не назначался эффектор падения актора (в моде своя схема)
  b:=$EB;
  addr:=xrgame_addr+$261BD2;
  writeprocessmemory(hndl, PChar(addr), @b, 1, rb);


  //Меняем линейный характер наклонов-выглядываний
  addr:=xrgame_addr+$26a10a;
  if not WriteJump(addr, cardinal(@LookoutFunctionReplace_Patch), 5, true) then exit;
  //убираем условие, чтобы наклоны обрабатывались всегда
  addr:=xrgame_addr+$26a0eb;
  nop_code(addr, 6);


  result:=true;
end;

end.
