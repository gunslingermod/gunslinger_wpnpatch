unit collimator;


interface
function Init:boolean;
function IsCollimatorInstalled(wpn:pointer):boolean;stdcall;

implementation
uses BaseGameData, gunsl_config, HudItemUtils, sysutils, windows;

var
  IsAimingEdited:boolean;

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

procedure ChangeAimOffsets(wpn:pointer; hud_data:pointer; isrestore:boolean); stdcall;
var section:PChar;
    pos:array[0..2] of single;
    rot:array[0..2] of single;
    pos_str:string;
    rot_str:string;
    pos_vector, rot_vector, coord:string;
    i:integer;
    rb:cardinal;
begin
  if isrestore then begin
    if IsAimingEdited=false then exit;
    section:=GetHudSection(wpn);
    IsAimingEdited:=false;
  end else begin
    if (GetScopeStatus(wpn)<>2) or (not IsScopeAttached(wpn)) then begin
      IsAimingEdited:=false;
      exit;
    end;
    section:=GetCurrentScopeSection(wpn);
    IsAimingEdited:=true;
  end;

  pos_str:='aim_hud_offset_pos';
  rot_str:='aim_hud_offset_rot';
  if Is16x9 then begin
    pos_str:=pos_str+'_16x9';
    rot_str:=rot_str+'_16x9';
  end;

  if game_ini_line_exist(section, PChar(pos_str)) then
    pos_vector:=game_ini_read_string(section, PChar(pos_str))
  else
    pos_vector:='';

  if game_ini_line_exist(section, PChar(rot_str)) then
    rot_vector:=game_ini_read_string(section, PChar(rot_str))
  else
    rot_vector:='';

  for i:=0 to 2 do begin
   GetNextSubStr(pos_vector, coord, ',');
   pos[i]:=strtofloatdef(coord, 0);
   GetNextSubStr(rot_vector, coord, ',');
   rot[i]:=strtofloatdef(coord, 0);
  end;

  writeprocessmemory(hndl, PChar(hud_data)+$2b, @pos[0], 12, rb);
  writeprocessmemory(hndl, PChar(hud_data)+$4f, @rot[0], 12, rb);
end;

procedure CWeapon_UpdateHudAdditional_savedata_patch(); stdcall;
asm
    pushfd
    pushad

    push 0
    movzx eax, bl
    lea eax, [eax+eax*2]
    lea eax, [edi+eax*4]
    push eax

    sub esi, $2e0
    push esi
    call ChangeAimOffsets

    popad
    popfd
    movss xmm0, [esi+$1c8]

    ret
end;

procedure CWeapon_UpdateHudAdditional_restoredata_patch(); stdcall;
begin
  asm
    pushad
    pushfd

    push 1
    push eax
    sub esi, $2e0
    push esi
    call ChangeAimOffsets

    popfd
    popad
    mulss xmm0, [esp+$34]
    ret
  end;
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

  patch_addr:=xrGame_addr+$2C0A3D;
  if not WriteJump(patch_addr, cardinal(@CWeapon_UpdateHudAdditional_restoredata_patch), 6, true ) then exit;

  patch_addr:=xrGame_addr+$2BC773;
  if not WriteJump(patch_addr, cardinal(@CWeapon_show_indicators_Patch), 7, true) then exit;

  result:=true;
end;

end.
