unit collimator;


interface
function Init:boolean;
function IsCollimatorInstalled(wpn:pointer):boolean;stdcall;
procedure ResetHudMoveOffset();

implementation
uses BaseGameData, gunsl_config, HudItemUtils, sysutils, windows, MatVectors, ActorUtils, strutils;

var
  last_aim_factor:single;
  last_hud_data:pointer;
  last_move_rot_offset:FVector3;
  last_move_pos_offset:FVector3;


procedure ResetHudMoveOffset();
begin
  last_move_rot_offset.x:=0;
  last_move_rot_offset.y:=0;
  last_move_rot_offset.z:=0;

  last_move_pos_offset.x:=0;
  last_move_pos_offset.y:=0;
  last_move_pos_offset.z:=0;
end;

function IsCollimatorInstalled(wpn:pointer):boolean;stdcall;
var
  scope:PChar;
begin
  result:=false;
  if not IsScopeAttached(wpn) then exit;
  scope:=GetCurrentScopeSection(wpn);
  scope:=game_ini_read_string(scope, 'scope_name');
  result:=game_ini_r_bool_def(scope, 'collimator', false)
end;

procedure PatchHudVisibility(); stdcall;
asm
    pushfd
    pushad


    push esi
    call IsCollimatorInstalled;
    and eax, 1
    mov [esp+$1C], eax //загоним сохрaненные значения

    popad
    popfd

    pop edi
    pop esi
    ret
end;

procedure GetCurrentTargetOffset(section:PChar; pos:pFVector3; rot:pFVector3; factor:pSingle);
var
  act:pointer;
  zerovec, tmp:FVector3;
  koef:single;
begin
  factor^:=game_ini_r_single_def(section, 'hud_move_stabilize_factor', 2.0);

  v_zero(pos);
  v_zero(rot);
  v_zero(@zerovec);
  act:=GetActor;
  if act=nil then exit;
  if GetActorActionState(act, actCrouch) and GetActorActionState(act, actSlow) then begin
    koef:=game_ini_r_single_def(section, 'hud_move_slow_crounch_factor', 1.0);
  end else if GetActorActionState(act, actCrouch) then begin
    koef:=game_ini_r_single_def(section, 'hud_move_crounch_factor', 1.0);
  end else if GetActorActionState(act, actSlow) then begin
    koef:=game_ini_r_single_def(section, 'hud_move_slow_factor', 1.0);  
  end else begin
    koef:=1;
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

procedure ChangeHudOffsets(wpn:pointer; hud_data:pointer); stdcall;
var
  section, pos_str, rot_str:PChar;
  pos, rot, zerovec:FVector3;
  factor:single;
  speed:single;
  rb:cardinal;
begin
  v_zero(@zerovec);
  section:=GetHudSection(wpn);
  last_aim_factor:=GetAimFactor(wpn);
  last_hud_data:=hud_data;  
  if IsAimNow(wpn) or IsHolderInAimState(wpn) or (last_aim_factor>0) then begin
    if (GetScopeStatus(wpn)=2) and IsScopeAttached(wpn) then begin
      section:=GetCurrentScopeSection(wpn);
    end;
    if Is16x9() then begin
      pos_str:='aim_hud_offset_pos_16x9';
      rot_str:='aim_hud_offset_rot_16x9';
    end else begin
      pos_str:='aim_hud_offset_pos';
      rot_str:='aim_hud_offset_rot';
    end;
    pos:=game_ini_read_vector3_def(section, pos_str, @zerovec);
    rot:=game_ini_read_vector3_def(section, rot_str, @zerovec);

    if GetAimFactor(wpn)<0.001 then SetAimFactor(wpn, 0.001);

    v_sub(@pos, @last_move_pos_offset);
    v_sub(@rot, @last_move_rot_offset);

    factor:=game_ini_r_single_def(section, 'hud_move_unzoom_speed_pos', 0.8)*get_device_timedelta();
    if v_length(@pos)>factor then v_setlength(@pos, factor);
    factor:=game_ini_r_single_def(section, 'hud_move_unzoom_speed_rot', 0.8)*get_device_timedelta();
    if v_length(@rot)>factor then v_setlength(@rot, factor);

    v_add(@last_move_pos_offset, @pos);
    v_add(@last_move_rot_offset, @rot);    

    //компенсируем вход в зум (в двиге пойдет домножение, потому разделим на это значение!)
    pos:=last_move_pos_offset;
    rot:=last_move_rot_offset;
    v_mul(@pos, 1/GetAimFactor(wpn));
    v_mul(@rot, 1/GetAimFactor(wpn));    

  end else begin
    if GetCurrentState(wpn)=CHUDState__eHiding then begin
      //если играется убирание оружия - летим в центр, чтобы не иметь потом сюрпризов с телепортами
      v_zero(@pos);
      v_zero(@rot);
      factor:=game_ini_r_single_def(section, 'hud_move_weaponhide_factor', 1.0);
    end else begin
      GetCurrentTargetOffset(section, @pos, @rot, @factor);
    end;
    SetAimFactor(wpn, 1.0); //обязательно сделать - в двиге будет на него домножаться!

    v_sub(@pos, @last_move_pos_offset);
    v_sub(@rot, @last_move_rot_offset);

    speed:=game_ini_r_single_def(section, 'hud_move_speed_rot', 0.4);
    if v_length(@rot)>0.0001 then v_mul(@rot, factor*speed*get_device_timedelta());
    speed:=game_ini_r_single_def(section, 'hud_move_speed_pos', 0.1);
    if v_length(@pos)>0.0001 then v_mul(@pos, factor*speed*get_device_timedelta());

    v_add(@last_move_pos_offset, @pos);
    v_add(@last_move_rot_offset, @rot);

    pos:=last_move_pos_offset;
    rot:=last_move_rot_offset;
  end;

  writeprocessmemory(hndl, PChar(hud_data)+$2b, @pos, 12, rb);
  writeprocessmemory(hndl, PChar(hud_data)+$4f, @rot, 12, rb);

end;

procedure RestoreHudOffsets(wpn:pointer); stdcall;
var
  section, pos_str, rot_str:PChar;
  pos, rot, zerovec:FVector3;
  rb:cardinal;

begin
  section:=GetHudSection(wpn);
  v_zero(@zerovec);

  if Is16x9() then begin
    pos_str:='aim_hud_offset_pos_16x9';
    rot_str:='aim_hud_offset_rot_16x9';
  end else begin
    pos_str:='aim_hud_offset_pos';
    rot_str:='aim_hud_offset_rot';
  end;
  
  pos:=game_ini_read_vector3_def(section, pos_str, @zerovec);
  rot:=game_ini_read_vector3_def(section, rot_str, @zerovec);

  writeprocessmemory(hndl, PChar(last_hud_data)+$2b, @pos, 12, rb);
  writeprocessmemory(hndl, PChar(last_hud_data)+$4f, @rot, 12, rb);

  SetAimFactor(wpn, last_aim_factor);
end;

procedure CWeapon_UpdateHudAdditional_savedata_patch(); stdcall;
asm
    pushfd
    pushad


    movzx eax, bl
    lea eax, [eax+eax*2]
    lea eax, [edi+eax*4]
    push eax

    sub esi, $2e0
    push esi
    call ChangeHudOffsets

    popad
    popfd
    movss xmm0, [esi+$1c8]

    ret
end;

procedure CWeapon_UpdateHudAdditional_restoredata_patch(); stdcall;
asm
    push eax
    movss [esp], xmm1
    pushad

    sub esi, $2e0
    push esi
    call RestoreHudOffsets

    popad
    movss xmm1, [esp]
    add esp, 4
    cmp byte ptr [ebp+$5D4], 00
end;


procedure CWeapon_show_indicators_Patch(); stdcall;
asm
  pushad
    push esi
    call IsCollimatorInstalled
    cmp al, 1
  popad
  je @finish
  cmp byte ptr [esi+$496],00
  @finish:
end;


function Init:boolean;
var
  patch_addr:cardinal;
begin
  result:=false;
  ResetHudMoveOffset();  
  patch_addr:=xrGame_addr+$2BCB01;
  if not WriteJump(patch_addr, cardinal(@PatchHudVisibility), 0) then exit;
  patch_addr:=xrGame_addr+$2C09A2;
  if not WriteJump(patch_addr, cardinal(@CWeapon_UpdateHudAdditional_savedata_patch), 8, true) then exit;

  patch_addr:=xrGame_addr+$2C0FDE;
  if not WriteJump(patch_addr, cardinal(@CWeapon_UpdateHudAdditional_restoredata_patch), 7, true) then exit;

  patch_addr:=xrGame_addr+$2BC773;
  if not WriteJump(patch_addr, cardinal(@CWeapon_show_indicators_Patch), 7, true) then exit;

  //заставляем CWeapon::UpdateHudAdditional работать всегда, убивая условные переходы
  nop_code(xrgame_addr+$2c08f7, 6);
  nop_code(xrgame_addr+$2c0908, 6);
  nop_code(xrgame_addr+$2c091c, 6);
  nop_code(xrgame_addr+$2c0954, 6);

  result:=true;
end;

end.
