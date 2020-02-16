unit ActorDOF;

interface
uses MatVectors;

type

DofValues = packed record
  dest:FVector3;
  current:FVector3;
  from:FVector3;
  original:FVector3;
end;
pDofValues = ^DofValues;

DofContext = record
  values:DofValues;
  change_speed_koef:single;
  change_speed_recalc:single;
  changed:boolean;
  valid:boolean;
end;
pDofContext = ^DofContext;

function Init():boolean; stdcall;
function GetGamePersistent():pointer; stdcall;
procedure SetDOF(dof_near:single; dof_focus:single; dof_far:single; speed:single); stdcall; overload;
procedure SetDOF(v:FVector3; speed:single); stdcall; overload;
function RefreshZoomDOF(wpn:pointer):boolean; stdcall;
procedure ResetDOF(speed:single); stdcall;
function ReadActionDOFVector(wpn:pointer; var v:FVector3; param:string; def:boolean=true):boolean; stdcall;
function ReadZoomDOFVector(wpn:pointer):FVector3; stdcall;
function ReadAlterZoomDOFVector(wpn:pointer):FVector3; stdcall;
function ReadGLDOFVector(wpn:pointer):FVector3; stdcall;
function ReadLensDOFVector(wpn:pointer):FVector3; stdcall;
function ReadActionDOFSpeed_In(wpn:pointer; param:string):single;
function ReadActionDOFSpeed_Out(wpn:pointer; param:string):single;
function ReadActionDOFTimeOffset(wpn:pointer; param:string):integer;


procedure SetDofSpeedfactor(speed:single); stdcall;
procedure GetCurrentDOF(v:pFVector3); stdcall;
function DOFChanged():boolean; stdcall;


procedure GetContext(context:pDofContext); stdcall;
procedure SetContext(context:pDofContext); stdcall;

function GetDOFState():pDofValues; stdcall;
procedure SetDOFState(values:pDofValues); stdcall;



implementation
uses BaseGameData, collimator, gunsl_config, HudItemUtils, ActorUtils, math, sysutils, LensDoubleRender;

var
  _dof_change_speed_koef:single;
  _dof_change_speed_recalc:single;

  _dof_changed:boolean;


//-----------------------------------------------------------------------------------------------------------
function DOFChanged():boolean; stdcall;
begin
  result:=_dof_changed;
end;

procedure SetPickableDofEffectorStatus(status:boolean); stdcall;
asm
  pushad
  call GetGamePersistent
  mov ecx, eax

  mov eax, xrgame_addr
  add eax, $230960
  movzx edx, status
  push edx
  call eax  //CGamePersistent::SetPickableEffecorDOF
  popad
end;

function IsPickableDofEffectorActive():boolean;
asm
  pushad
  call GetGamePersistent
  mov al, byte ptr [eax+$4e1] //m_bPickableDOF
  mov result, al
  popad
end;

function RefreshZoomDOF(wpn:pointer):boolean; stdcall;
begin
  if not IsDofEnabled() then begin
    result:=false;
  end else if LensConditions(true) and not IsAlterZoom(wpn) then begin
    //в режиме прицеливания с помощью линзы
    result:=false;
    if IsPickableDofEffectorActive() then begin
      //Если была активна "родная" схема дофа - сбросим ее, она мешает
      SetPickableDofEffectorStatus(false);
    end;
    
    SetDOF(ReadLensDOFVector(wpn), game_ini_r_single_def(GetHUDSection(wpn),'zoom_in_dof_speed', GetDefaultDOFSpeed_In()));
  end else if IsConstZoomDOF() then begin
    result:=false;  //в родном дофе не нуждаемся
    if IsPickableDofEffectorActive() then begin
      //Если была активна "родная" схема дофа - сбросим ее, она мешает
      SetPickableDofEffectorStatus(false);
    end;

    if IsGrenadeMode(wpn) and CHudItem__GetHUDMode(wpn) then begin
      SetDOF(ReadGLDOFVector(wpn), game_ini_r_single_def(GetHUDSection(wpn),'gl_in_dof_speed', GetDefaultDOFSpeed_In()));
    end else if IsAlterZoom(wpn) then begin
      SetDOF(ReadAlterZoomDOFVector(wpn), game_ini_r_single_def(GetHUDSection(wpn),'alter_zoom_in_dof_speed', GetDefaultDOFSpeed_In()));
    end else if (not IsScopeAttached(wpn)) and (GetScopeStatus(wpn)<>1) and CHudItem__GetHUDMode(wpn) then begin
      SetDOF(ReadZoomDOFVector(wpn), game_ini_r_single_def(GetHUDSection(wpn),'zoom_in_dof_speed', GetDefaultDOFSpeed_In()));
    end;
  end else begin
    if game_ini_r_bool_def(GetSection(wpn), 'disable_zoom_dof', false) then begin
      result:=false;
    end else if IsAlterZoom(wpn) then begin
      result:=true;
    end else begin
      // С коллиматором использовать нельзя - выглядит странно
      result:= (not IsCollimatorInstalled(wpn) and not IsLensedScopeInstalled(wpn));    
    end;
    if result then SetDofSpeedfactor(GetDefaultDOFSpeed());
  end;

  //Управляем необходимостью "оригинального" эффекта ДОФа, параметры которого зависят от точки, в которую смотрит игрок
  if result then begin
    SetPickableDofEffectorStatus(true);
  end;
end;

procedure CWeapon__OnZoomIn_needDOF_Patch(); stdcall;
asm
  pushad
    push esi
    call RefreshZoomDOF
  popad
end;


function GetGamePersistent():pointer; stdcall;
asm
  mov eax, xrgame_addr
  mov eax, [eax+$512c28]
  mov eax, [eax]
  mov @result, eax
end;

procedure SetDofSpeedfactor(speed:single); stdcall;  //default=5
begin
  _dof_change_speed_koef:=speed;
end;

procedure RecalcDofSpeed(); stdcall;
begin
  if GetActor<>nil then begin
    _dof_change_speed_recalc:=_dof_change_speed_koef;
  end else
   _dof_change_speed_recalc:=1000;
end;


procedure DOFLoadSpeed_Patch(); stdcall;
asm
  sub esp, $C
  movss [esp], xmm0
  movss [esp+4], xmm1
  movss [esp+8], xmm2
  pushad
    call RecalcDofSpeed
  popad
  movss xmm0, [esp]
  movss xmm1, [esp+4]
  movss xmm2, [esp+8]
  add esp, $c

  mulss xmm2, _dof_change_speed_recalc
end;

procedure SetDOF(dof_near:single; dof_focus:single; dof_far:single; speed:single); stdcall; overload;
asm
  pushad
    push speed
    call SetDofSpeedfactor

    call GetGamePersistent

    //сохраним текущее в предыдущее
    mov ebx, [eax+$4f8]
    mov [eax+$504], ebx

    mov ebx, [eax+$4fc]
    mov [eax+$508], ebx

    mov ebx, [eax+$500]
    mov [eax+$50c], ebx

    //запишем новое в целевое
    mov ebx, dof_near
    mov [eax+$4EC], ebx

    mov ebx, dof_focus
    mov [eax+$4F0], ebx

    mov ebx, dof_far
    mov [eax+$4F4], ebx

    mov _dof_changed, 1
  popad
end;

procedure SetDOF(v:FVector3; speed:single); stdcall; overload;
begin
  SetDOF(v.x, v.y, v.z, speed);
end;

procedure ResetDOF(speed:single); stdcall;
asm
  cmp _dof_changed, 0
  je @finish

  pushad

  push speed
  call SetDofSpeedfactor
  call GetGamePersistent

  //сохраним текущее в предыдущее
  mov ebx, [eax+$4f8]
  mov [eax+$504], ebx

  mov ebx, [eax+$4fc]
  mov [eax+$508], ebx

  mov ebx, [eax+$500]
  mov [eax+$50c], ebx


  //запишем дефаултовое в целевое
  mov ebx, [eax+$510]
  mov [eax+$4ec], ebx

  mov ebx, [eax+$514]
  mov [eax+$4f0], ebx

  mov ebx, [eax+$518]
  mov [eax+$4f4], ebx

  mov _dof_changed, 0

  popad

  @finish:
end;

procedure GetCurrentDOF(v:pFVector3); stdcall;
asm
  pushad
    call GetGamePersistent
    mov ecx, eax
    push v
    mov eax, xrgame_addr
    add eax, $2306f0
    call eax

  popad
end;

function ReadActionDOFVector(wpn:pointer; var v:FVector3; param:string; def:boolean=true):boolean; stdcall;
var
  sect:PChar;
begin
  sect:=GetHUDSection(wpn);
  result:=IsDynamicDOF() and CHudItem__GetHUDMode(wpn) and game_ini_r_bool_def(sect, PChar('use_dof_'+param), def);
  if result then begin
    v:=GetDefaultActionDOF();
    param:='dof_'+param;
    v.x:=game_ini_r_single_def(sect, PChar(param+'_near'), v.x);
    v.y:=game_ini_r_single_def(sect, PChar(param+'_focus'), v.y);
    v.z:=game_ini_r_single_def(sect, PChar(param+'_far'), v.z);
  end;
end;

function ReadActionDOFSpeed_In(wpn:pointer; param:string):single;
var
  sect:PChar;
begin
  sect:=GetHUDSection(wpn);
  result:=game_ini_r_single_def(sect, PChar('dof_speed_in_'+param), GetDefaultDOFSpeed_In());
end;

function ReadActionDOFSpeed_Out(wpn:pointer; param:string):single;
var
  sect:PChar;
begin
  sect:=GetHUDSection(wpn);
  result:=game_ini_r_single_def(sect, PChar('dof_speed_out_'+param), GetDefaultDOFSpeed_Out());
end;


function ReadActionDOFTimeOffset(wpn:pointer; param:string):integer;
var
  sect:PChar;
begin
  sect:=GetHUDSection(wpn);
  result:=floor(game_ini_r_single_def(sect, PChar('dof_time_offset_'+param), GetDefaultDOFTimeOffset())*1000);
end;

function ReadZoomDOFVector(wpn:pointer):FVector3; stdcall;
var
  sect:PChar;
begin
  sect:=GetHUDSection(wpn);
  result:=GetDefaultZoomDOF();
  result.x:=game_ini_r_single_def(sect, PChar('zoom_dof_near'), result.x);
  result.y:=game_ini_r_single_def(sect, PChar('zoom_dof_focus'), result.y);
  result.z:=game_ini_r_single_def(sect, PChar('zoom_dof_far'), result.z);
end;

function ReadAlterZoomDOFVector(wpn:pointer):FVector3; stdcall;
var
  sect:PChar;
begin
  sect:=GetHUDSection(wpn);
  result:=ReadZoomDOFVector(wpn);
  result.x:=game_ini_r_single_def(sect, PChar('alter_zoom_dof_near'), result.x);
  result.y:=game_ini_r_single_def(sect, PChar('alter_zoom_dof_focus'), result.y);
  result.z:=game_ini_r_single_def(sect, PChar('alter_zoom_dof_far'), result.z);
end;

function ReadGLDOFVector(wpn:pointer):FVector3; stdcall;
var
  sect:PChar;
begin
  sect:=GetHUDSection(wpn);
  result:=GetDefaultZoomDOF();
  result.x:=game_ini_r_single_def(sect, PChar('gl_dof_near'), result.x);
  result.y:=game_ini_r_single_def(sect, PChar('gl_dof_focus'), result.y);
  result.z:=game_ini_r_single_def(sect, PChar('gl_dof_far'), result.z);
end;

function ReadLensDOFVector(wpn:pointer):FVector3; stdcall;
var
  sect:PChar;
begin
  sect:=GetHUDSection(wpn);
  result:=GetDefaultZoomDOF();
  result.x:=game_ini_r_single_def(sect, PChar('lens_dof_near'), result.x);
  result.y:=game_ini_r_single_def(sect, PChar('lens_dof_focus'), result.y);
  result.z:=game_ini_r_single_def(sect, PChar('lens_dof_far'), result.z);

  if IsScopeAttached(wpn) then begin
    sect:=GetCurrentScopeSection(wpn);
    result.x:=game_ini_r_single_def(sect, PChar('lens_dof_near'), result.x);
    result.y:=game_ini_r_single_def(sect, PChar('lens_dof_focus'), result.y);
    result.z:=game_ini_r_single_def(sect, PChar('lens_dof_far'), result.z);
  end;
end;

function Init():boolean; stdcall;
var jmp_addr:cardinal;
begin
  result:=false;

  _dof_change_speed_koef:=GetDefaultDOFSpeed();
  _dof_changed:=false;

  jmp_addr:= xrgame_addr+$2C07FB;
  if not WriteJump(jmp_addr, cardinal(@CWeapon__OnZoomIn_needDOF_Patch), 7, true) then exit;

  jmp_addr:= xrgame_addr+$230ADE;
  if not WriteJump(jmp_addr, cardinal(@DOFLoadSpeed_Patch), 8, true) then exit;

  result:=true;
end;


procedure GetContext(context:pDofContext); stdcall;
var
  m_dof:pDofValues;
begin
  m_dof:=GetDOFState();
  if m_dof<>nil then begin
    context^.values:=m_dof^;
    context^.change_speed_koef:=_dof_change_speed_koef;
    context^.change_speed_recalc:=_dof_change_speed_recalc;
    context^.changed:=_dof_changed;
    context^.valid:=true;
  end else begin
    context^.valid:=false;
  end;
end;

procedure SetContext(context:pDofContext); stdcall;
var
  m_dof:pDofValues;
begin
  m_dof:=GetDOFState();
  if context^.valid and (m_dof<>nil) then begin
    m_dof^:=context^.values;
    _dof_change_speed_koef:=context^.change_speed_koef;
    _dof_change_speed_recalc:=context^.change_speed_recalc;
    _dof_changed:=context^.changed;
  end;
end;


function GetDOFState():pDofValues; stdcall;
var
  game_persistent:cardinal;
begin
  game_persistent:= cardinal(GetGamePersistent());
  if game_persistent<>0 then begin
    result:= pDofValues((cardinal(game_persistent)+$4EC))
  end else begin
    result:=nil;
  end;
end;

procedure SetDOFState(values:pDofValues); stdcall;
var
  m_dof:pDofValues;
begin
  m_dof:=GetDOFState();
  if m_dof<>nil then begin
    m_dof^:=values^;
  end;
end;

end.
