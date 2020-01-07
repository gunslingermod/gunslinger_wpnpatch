unit collimator;


interface
function Init:boolean;
function IsCollimatorInstalled(wpn:pointer):boolean;stdcall;
function IsLensedScopeInstalled(wpn:pointer):boolean;stdcall;
function CanUseAlterScope(wpn:pointer):boolean;
function GetAlterScopeZoomFactor(wpn:pointer):single; stdcall;
function IsHudModelForceUnhide(wpn:pointer):boolean; stdcall;
function IsUIForceHiding(wpn:pointer): boolean;stdcall;
function IsUIForceUnhiding(wpn:pointer): boolean;stdcall;

implementation
uses BaseGameData, gunsl_config, HudItemUtils, sysutils, MatVectors, ActorUtils, strutils, messenger, WeaponAdditionalBuffer, windows, LensDoubleRender;

var
  last_hud_data:pointer;

function GetAlterScopeZoomFactor(wpn:pointer):single; stdcall;
begin
  if IsScopeAttached(wpn) then begin
    result:=game_ini_r_single_def(GetCurrentScopeSection(wpn), 'alter_scope_zoom_factor', 1.0);
  end else begin
    result:=game_ini_r_single_def(GetSection(wpn), 'alter_scope_zoom_factor', 1.0)
  end;
end;

function CanUseAlterScope(wpn:pointer):boolean;
var
  gl_status:cardinal;
begin
  result:=false;

  gl_status:=GetGLStatus(wpn);
  if ((gl_status=1) or ((gl_status=2) and IsGLAttached(wpn))) and IsGLEnabled(wpn) then exit;

  if IsScopeAttached(wpn) then begin
    result:=game_ini_r_bool_def(GetCurrentScopeSection(wpn), 'alter_zoom_allowed', false);
  end else begin
    result:=game_ini_r_bool_def(GetHudSection(wpn), 'alter_zoom_allowed', false);
    result:=FindBoolValueInUpgradesDef(wpn, 'alter_zoom_allowed', result, true);
  end;
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

function IsLensedScopeInstalled(wpn:pointer):boolean;stdcall;
var
  scope:PChar;
  scopestatus:cardinal;
begin
  result:=false;
  scopestatus:=GetScopeStatus(wpn);
  if (scopestatus = 2) then begin
    if IsScopeAttached(wpn) then begin
      scope:=GetCurrentScopeSection(wpn);
      scope:=game_ini_read_string(scope, 'scope_name');
      result:=game_ini_r_bool_def(scope, 'need_lens_frame', false)
    end;
  end else if (scopestatus = 1) then begin
    scope:=GetSection(wpn);
    result:=game_ini_r_bool_def(scope, 'need_lens_frame', false);
    result:=FindBoolValueInUpgradesDef(wpn, 'need_lens_frame', result, true);
  end;
end;   

function IsHudModelForceUnhide(wpn:pointer):boolean; stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  result:=IsCollimatorInstalled(wpn) or (IsLensedScopeInstalled(wpn) and IsLensEnabled()) or ((buf<>nil) and buf.IsAlterZoomMode());
end;

procedure PatchHudVisibility(); stdcall;
//CWeapon::need_renderable
asm
    xor eax, eax

    pushad
    push esi
    call IsHudModelForceUnhide;
    test al, al
    popad

    je @finish
    mov eax, 1

    @finish:
    pop edi
    pop esi
    ret
end;

procedure ChangeHudOffsets(wpn:pointer; hud_data:pointer); stdcall;
var
  section:PChar;
  pos_str, rot_str:string;
  pos, rot, zerovec:FVector3;
  rb:cardinal;

  buf:WpnBuf;
  is_alter:boolean;
begin
  if not IsCollimAimEnabled() then exit;
  is_alter:=false;
  last_hud_data:=nil;
  v_zero(@zerovec);
  section:=GetHudSection(wpn);

  buf:=GetBuffer(wpn);

  if (GetScopeStatus(wpn)=2) and IsScopeAttached(wpn) then begin
    section:=GetCurrentScopeSection(wpn);
    last_hud_data:=hud_data;
  end;
  
  if (buf<>nil) and CanUseAlterScope(wpn) and (buf.IsAlterZoomMode() or ((GetAimFactor(wpn)>0) and buf.IsLastZoomAlter())) then begin
    last_hud_data:=hud_data;
    is_alter:=true;
  end;

  if last_hud_data<>nil then begin
    if IsGrenadeMode(wpn) then begin
      pos_str := 'gl';
      rot_str := 'gl';
    end else begin
      pos_str := 'aim';
      rot_str := 'aim';    
    end;

    pos_str:=pos_str+'_hud_offset_pos';
    rot_str:=rot_str+'_hud_offset_rot';

    if Is16x9() then begin
      pos_str:=pos_str+'_16x9';
      rot_str:=rot_str+'_16x9';
    end;

    if is_alter then begin
      //log('alter_zoom');
      pos_str:='alter_' + pos_str;
      rot_str:='alter_' + rot_str;
    end;

    pos:=game_ini_read_vector3_def(section, PChar(pos_str), @zerovec);
    rot:=game_ini_read_vector3_def(section, PChar(rot_str), @zerovec);

    writeprocessmemory(hndl, PChar(last_hud_data)+$2b, @pos, 12, rb);
    writeprocessmemory(hndl, PChar(last_hud_data)+$4f, @rot, 12, rb);
  end;
end;

procedure RestoreHudOffsets(wpn:pointer); stdcall;
var
  section:PChar;
  pos_str, rot_str:string;
  pos, rot, zerovec:FVector3;
  rb:cardinal;

begin
  if not IsCollimAimEnabled() or (last_hud_data=nil) then exit;
  section:=GetHudSection(wpn);
  v_zero(@zerovec);

  if IsGrenadeMode(wpn) then begin
    pos_str := 'gl';
    rot_str := 'gl';
  end else begin
    pos_str := 'aim';
    rot_str := 'aim';
  end;

  pos_str:=pos_str+'_hud_offset_pos';
  rot_str:=pos_str+'_hud_offset_rot';


  if Is16x9() then begin
    pos_str:=pos_str+'_16x9';
    rot_str:=rot_str+'_16x9';
  end;
  
  pos:=game_ini_read_vector3_def(section, PChar(pos_str), @zerovec);
  rot:=game_ini_read_vector3_def(section, PChar(rot_str), @zerovec);

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

function IsUIForceUnhiding(wpn:pointer): boolean;stdcall;
var
  buf:WpnBuf;
begin
  result:=IsHudModelForceUnhide(wpn);

  //Дальнейшие проверки имеют смысл только если худовая модель оружия не скрыта
  if result then begin
    buf:=GetBuffer(wpn);
    if (buf<>nil) and buf.IsAlterZoomMode() then begin
      //Стрельба с резервных прицельных приспособлений. Не скрываем ничего
      result:=true;
    end else if (GetScopeStatus(wpn)=1) then begin
      result:= not game_ini_r_bool_def(GetSection(wpn), 'zoom_hide_ui', false);
    end else if (GetScopeStatus(wpn)=2) and IsScopeAttached(wpn) then begin
      result:= not game_ini_r_bool_def(game_ini_read_string(GetCurrentScopeSection(wpn), 'scope_name'), 'zoom_hide_ui', false);
    end;
  end;
end;

function IsUIForceHiding(wpn:pointer): boolean;stdcall;
begin
  if IsBino(wpn) and IsAimNow(wpn) then begin
    result:=game_ini_r_bool_def(GetSection(wpn), 'zoom_hide_ui', false);
  end else if (GetScopeStatus(wpn)=1) and IsAimNow(wpn) then begin
    result:= game_ini_r_bool_def(GetSection(wpn), 'zoom_hide_ui', false);
  end else if (GetScopeStatus(wpn)=2) and IsScopeAttached(wpn) and IsAimNow(wpn) then begin
    result:= game_ini_r_bool_def(game_ini_read_string(GetCurrentScopeSection(wpn), 'scope_name'), 'zoom_hide_ui', false);
  end else begin
    result:=false;
  end;
end;

procedure CWeapon_show_indicators_Patch(); stdcall;
asm
  pushad
    push esi
    call IsUIForceHiding
    cmp al, 0
  popad
  je @check_unhiding

  add esp, 4
  xor eax, eax
  pop esi
  ret


  @check_unhiding:
  pushad
    push esi
    call IsUIForceUnhiding
    cmp al, 1
  popad
  je @finish
  cmp byte ptr [esi+$496],00
  @finish:
end;

function IsAlterZoom(wpn:pointer):boolean; stdcall;
var
  buf:WpnBuf;
begin
  buf := GetBuffer(wpn);
  result:= (buf<>nil) and buf.IsAlterZoomMode();
end;

procedure CWeapon__OnZoomIn_PreExit_Patch();
asm
  pushad
  push esi
  call IsAlterZoom
  cmp al, 0
  popad
  je @notneed
  add esp, 4
  pop edi
  pop esi
  ret

  @notneed:
  mov eax, [esi+$4B4]
end;

procedure CWeapon__ZoomTexture_Patch();
asm
  pushad
  push esi
  call IsAlterZoom
  cmp al, 1
  popad
  je @disable
  mov eax, [esi+$4c4]
  ret
  @disable:
  xor eax, eax
end;


procedure CWeapon__render_item_ui_query_Patch();
asm
  pushad
  push esi
  call IsAlterZoom
  cmp al, 1
  popad
  je @finish
  cmp [esi+$4c4], 0
  @finish:
end;

procedure CWeapon__show_crosshair_Patch();
asm
  pushad
  push esi
  call IsAlterZoom
  cmp al, 0
  popad

  je @noalterzoom
  
  xor eax, eax
  cmp byte ptr [esi+$495], 01
  je @exit
  mov eax, 1

  @exit:
  add esp, 4
  pop esi
  ret

  @noalterzoom:
  cmp byte ptr [esi+$495], 00

end;

function CWeapon__render_item_ui_query_reimpl(wpn:pointer):boolean; stdcall;
begin
  result:=false;
  if (wpn=nil) or (wpn<>GetActorActiveItem()) then exit;
  if IsGrenadeMode(wpn) then exit;
  if not IsAimNow(wpn) then exit;
  if IsAlterZoom(wpn) then exit;
  if GetAimFactor(wpn) < 0.999 then exit;
  if IsLensEnabled() and IsLensedScopeInstalled(wpn) then begin
   // Если у нас прицел, детектящий все живое, то UI (а именно, рамку) придется отрисовать
   if HasBinocularVision(wpn) then result:=true;
   exit;
  end;
  result:=true;
end;

function CWeapon__render_item_ui_query_reimpl_patch():boolean; stdcall;
asm
  pushad
  push ecx
  call CWeapon__render_item_ui_query_reimpl
  mov @result, al
  popad
end;

function IsForceHideZoomTexture(wpn:pointer):boolean; stdcall;
begin
  result:=false;
  if IsLensEnabled() and IsLensedScopeInstalled(wpn) then begin
    result:=true;
  end;
end;

procedure CWeapon__render_item_ui__checkzoomtex_Patch(); stdcall;
asm
  cmp ecx, 0
  je @abandon_render_item_ui //Уходим, если сетки нет и рендерить нечего.
  pushad
  push esi
  call IsForceHideZoomTexture
  cmp al, 0
  popad
  je @finish_normal

  @abandon_render_item_ui:
  //Выходим из CWeapon__render_item_ui
  pop esi // ret_addr from patch
  pop esi // saved var from render_item_ui
  ret     // from render_item_ui

  @finish_normal:
  mov eax, [ecx]
  mov edx, [eax+$64]
end;

function NeedRenderBinocVision(wpn:pointer):boolean; stdcall;
begin
  // Если рисуем кадр линзы - ничего с рамками делать не надо!
  result:=not IsLensFrameNow();
end;

procedure CWeapon__needrenderbinocvision_Patch(); stdcall;
asm
  pushad
  push ecx
  call NeedRenderBinocVision
  cmp al, 0
  popad
  je @finish

  //original
  mov ecx, [esi+$4b8]
  test ecx, ecx

  @finish:
end;

function Init:boolean;
var
  patch_addr:cardinal;
  buf:pointer;
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

  patch_addr:=xrGame_addr+$2C0802;
  if not WriteJump(patch_addr, cardinal(@CWeapon__OnZoomIn_PreExit_Patch), 6, true) then exit;

  patch_addr:=xrGame_addr+$2BC3D1;
  if not WriteJump(patch_addr, cardinal(@CWeapon__ZoomTexture_Patch), 6, true) then exit;

  patch_addr:=xrGame_addr+$2BD1C5;
  if not WriteJump(patch_addr, cardinal(@CWeapon__show_crosshair_Patch), 7, true) then exit;

  // Заменяем реализацию метода CWeapon::render_item_ui_query своей
  patch_addr:=xrGame_addr+$2bd0d0;
  if not WriteJump(patch_addr, cardinal(@CWeapon__render_item_ui_query_reimpl_patch), 9, false) then exit;

  //в CWeapon::render_item_ui проверяем: если ZoomTexture() вернула NULL, то не рендерим сетку; если у нас 3д-прицел с детектором - тоже
  patch_addr:=xrGame_addr+$2bc73c;
  if not WriteJump(patch_addr, cardinal(@CWeapon__render_item_ui__checkzoomtex_Patch), 5, true) then exit;

  //в CWeapon::UpdateCL апдейтим рамки UI только в случае, если у нас сейчас НЕ идет рендер кадра линзы
  patch_addr:=xrGame_addr+$2c0706;
  if not WriteJump(patch_addr, cardinal(@CWeapon__needrenderbinocvision_Patch), 8, true) then exit;

  result:=true;
end;

end.
