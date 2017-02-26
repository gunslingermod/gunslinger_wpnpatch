unit collimator;


interface
function Init:boolean;
function IsCollimatorInstalled(wpn:pointer):boolean;stdcall;

implementation
uses BaseGameData, gunsl_config, HudItemUtils, sysutils, windows, MatVectors, ActorUtils, strutils, messenger;

var
  last_hud_data:pointer;


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

procedure ChangeHudOffsets(wpn:pointer; hud_data:pointer); stdcall;
var
  section, pos_str, rot_str:PChar;
  pos, rot,targetpos, targetrot, zerovec:FVector3;
  factor:single;
  speed:single;
  rb:cardinal;
begin
  if not IsCollimAimEnabled() then exit;
  v_zero(@zerovec);
  section:=GetHudSection(wpn);
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

  writeprocessmemory(hndl, PChar(hud_data)+$2b, @pos, 12, rb);
  writeprocessmemory(hndl, PChar(hud_data)+$4f, @rot, 12, rb);
end;

procedure RestoreHudOffsets(wpn:pointer); stdcall;
var
  section, pos_str, rot_str:PChar;
  pos, rot, zerovec:FVector3;
  rb:cardinal;

begin
  if not IsCollimAimEnabled() then exit;
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

  patch_addr:=xrGame_addr+$2BCB01;
  if not WriteJump(patch_addr, cardinal(@PatchHudVisibility), 0) then exit;
  patch_addr:=xrGame_addr+$2C09A2;
  if not WriteJump(patch_addr, cardinal(@CWeapon_UpdateHudAdditional_savedata_patch), 8, true) then exit;

  patch_addr:=xrGame_addr+$2C0FDE;
  if not WriteJump(patch_addr, cardinal(@CWeapon_UpdateHudAdditional_restoredata_patch), 7, true) then exit;

  patch_addr:=xrGame_addr+$2BC773;
  if not WriteJump(patch_addr, cardinal(@CWeapon_show_indicators_Patch), 7, true) then exit;

  result:=true;
end;

end.
