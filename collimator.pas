unit collimator;


interface
function Init:boolean;
function IsCollimatorInstalled(wpn:pointer):boolean;stdcall;
function IsLensedScopeInstalled(wpn:pointer):boolean;stdcall;
function CanUseAlterScope(wpn:pointer):boolean;
function GetAlterScopeZoomFactor(wpn:pointer):single; stdcall;
function IsAlterZoom(wpn:pointer):boolean; stdcall;
function GetZoomLensVisibilityFactor(wpn:pointer):single; stdcall;
function IsLastZoomAlter(wpn:pointer):boolean; stdcall;
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
    result:=game_ini_r_bool_def(GetSection(wpn), 'need_lens_frame', false);
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
  pos, rot, alt_pos, alt_rot, delta_pos, delta_rot, target_pos, target_rot, zerovec:FVector3;
  rb:cardinal;

  buf:WpnBuf;
  is_alter:boolean;
  mixup_factor:single;
const
  EPS = 0.0001;
begin
  if not IsCollimAimEnabled() then exit;
  is_alter:=false;
  last_hud_data:=nil;
  v_zero(@zerovec);
  section:=GetHudSection(wpn);

  buf:=GetBuffer(wpn);
  last_hud_data:=hud_data;

  if (GetScopeStatus(wpn)=2) and IsScopeAttached(wpn) then begin
    section:=GetCurrentScopeSection(wpn);
  end;

  if (buf<>nil) and CanUseAlterScope(wpn) and (buf.IsAlterZoomMode() or ((GetAimFactor(wpn)>0) and buf.IsLastZoomAlter())) then begin
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

    pos:=game_ini_read_vector3_def(section, PChar(pos_str), @zerovec);
    rot:=game_ini_read_vector3_def(section, PChar(rot_str), @zerovec);

    if buf <> nil then begin
      mixup_factor:=buf.GetAlterZoomDirectSwitchMixupFactor();
    end else begin
      mixup_factor:=0;
    end;

    alt_pos:=game_ini_read_vector3_def(section, PChar('alter_' + pos_str), @zerovec);
    alt_rot:=game_ini_read_vector3_def(section, PChar('alter_' + rot_str), @zerovec);

    if is_alter then begin
      if (mixup_factor > EPS) then begin
        //Переходим в альтернативное прицеливание из обычного
        delta_pos:=alt_pos;
        v_sub(@delta_pos, @pos);
        v_mul(@delta_pos, mixup_factor);
        v_sub(@alt_pos, @delta_pos);

        delta_rot:=alt_rot;
        v_sub(@delta_rot, @rot);
        v_mul(@delta_rot, mixup_factor);
        v_sub(@alt_rot, @delta_rot);
      end;
      target_pos:=alt_pos;
      target_rot:=alt_rot;
    end else begin
      if (mixup_factor > EPS) then begin
        //Переходим в обычное прицеливание из альтернативного
        delta_pos:=pos;
        v_sub(@delta_pos, @alt_pos);
        v_mul(@delta_pos, mixup_factor);
        v_sub(@pos, @delta_pos);

        delta_rot:=rot;
        v_sub(@delta_rot, @alt_rot);
        v_mul(@delta_rot, mixup_factor);
        v_sub(@rot, @delta_rot);
      end;
      target_pos:=pos;
      target_rot:=rot;
    end;

    writeprocessmemory(hndl, PChar(last_hud_data)+$2b, @target_pos, 12, rb);
    writeprocessmemory(hndl, PChar(last_hud_data)+$4f, @target_rot, 12, rb);
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

function GetZoomLensVisibilityFactor(wpn:pointer):single; stdcall;
var
  buf:WpnBuf;
  factor:single;
const
  EPS:single = 0.0001;
begin
  buf := GetBuffer(wpn);
  result:=1;
  if buf = nil then exit;

  factor:=buf.GetAlterZoomDirectSwitchMixupFactor();

  if factor > EPS then begin
    if buf.IsAlterZoomMode() then begin
      // Переходим к альтернативному прицеливанию
      result:=factor;
    end else begin
      // Переходим к обычному прицеливанию
      result:=1-factor;
    end;
  end else if not LensConditions(true) then begin
    result:=0;
  end;
end;

function IsLastZoomAlter(wpn:pointer):boolean; stdcall;
var
  buf:WpnBuf;
begin
  buf := GetBuffer(wpn);
  result:= (buf<>nil) and buf.IsLastZoomAlter();
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
  mov eax, [esi+$4c4] // m_UIScope
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
  cmp [esi+$4c4], 0 // m_UIScope
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

  // Если у нас прицел, детектящий все живое, то UI в нем надо отрисовать ради рамки
  if HasBinocularVision(wpn) then begin
    if IsLensEnabled() then begin
      result:=IsLensedScopeInstalled(wpn) and IsLensFrameNow();
    end else begin
      result:=true;
    end;
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

procedure UpdateWeaponZoomPpe(wpn:pointer); stdcall;
const
  effNightvision:cardinal=55;
var
  val:single;
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if (buf<>nil) and (GetOwner(wpn)<>nil) and (GetOwner(wpn)=GetActor()) and (IsWeaponNightVisionPPExist(wpn)) then begin
    val:=buf.GetNightPPEFactor();
    if val >= 0 then begin
      set_pp_effector_factor(effNightvision, val, 100000);
    end;
  end;
end;

function NeedUpdateBinocVision(wpn:pointer):boolean; stdcall;
begin
  // Обновляем только когда у нас НЕ кадр линзы
  result:=not IsLensFrameNow();
end;

procedure CWeapon__updateppe_and_needupdatebinocvision_Patch(); stdcall;
asm
  pushad
  push esi
  call UpdateWeaponZoomPpe
  popad

  pushad
  push esi
  call NeedUpdateBinocVision
  cmp al, 0
  popad
  je @finish

  //original
  mov ecx, [esi+$4b8]
  test ecx, ecx

  @finish:
end;

function SBinocVisibleObj__Update_check_target_position(target:pointer):boolean; stdcall;
var
  act:pointer;
  campos, camdir, targetpos:pFVector3;
  targetvec:FVector3;
  ang:single;
begin
  result:=false;
  act:=GetActor();
  if (act = nil) or (target = nil) then exit;

  campos:=CRenderDevice__GetCamPos();
  camdir:=CRenderDevice__GetCamDir();
  targetpos:=GetEntityPosition(target);

  //Получаем вектор на цель
  targetvec:=FVector3_copyfromengine(targetpos);
  v_sub(@targetvec, campos);

  //Считаем угол между вектором на цель и взглядом
  ang:=GetAngleCos(camdir, @targetvec);
  //Log('Target '+inttohex(cardinal(target), 8)+ '('+
  //    floattostr(targetpos.x)+', '+
  //    floattostr(targetpos.y)+', '+
  //    floattostr(targetpos.z)+') '+
  //    ', ang '+ floattostr(ang));

  //Если угол больше 90 - такую цель мы точно не должны рисовать
  if ang >0 then begin
    result:=true;
  end;

end;

procedure SBinocVisibleObj__Update_Patch(); stdcall;
asm
  pushad
  //в eax находится указатель на CObject цели, который надо проверить на предмет валидности для отрисовки
  push eax
  call SBinocVisibleObj__Update_check_target_position
  test al, al
  popad
  je @finish

  //Original code
  mov eax, [eax+$90]
  test eax, eax

  @finish:
end;

procedure CWeaponBinoculars__render_item_ui_Patch(); stdcall;
asm
  test ecx, ecx //m_binoc_vision
  je @finish
  mov esi, xrgame_addr
  add esi, $2dcd50
  call esi
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

  //в CWeapon::UpdateCL апдейтим интенсивность постпроцесса прицела, когда тот активен и добавляем условие на апдейт рамки UI только в случае, если у нас сейчас НЕ идет рендер кадра линзы
  patch_addr:=xrGame_addr+$2c0706;
  if not WriteJump(patch_addr, cardinal(@CWeapon__updateppe_and_needupdatebinocvision_Patch), 8, true) then exit;

  //Баг оригинала с метками автозахвата цели - показывает цели, которые уже позади тебя. Правим в SBinocVisibleObj::Update
  patch_addr:=xrGame_addr+$2dcf9f;
  if not WriteJump(patch_addr, cardinal(@SBinocVisibleObj__Update_Patch), 8, true) then exit;

  // В CWeaponBinoculars::render_item_ui_query удаляем проверку на наличие m_binoc_vision, чтобы нормально отрисовывалась сетка бинокля при его отсутствии
  nop_code(xrgame_addr+$2dc041, 2);

  // В CWeaponBinoculars::render_item_ui добавляем проверку на существование m_binoc_vision перед тем, как вызывать Draw
  patch_addr:=xrGame_addr+$2dc059;
  if not WriteJump(patch_addr, cardinal(@CWeaponBinoculars__render_item_ui_Patch), 5, true) then exit;

  result:=true;
end;

end.
