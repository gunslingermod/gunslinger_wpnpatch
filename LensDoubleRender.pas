unit LensDoubleRender;

interface
uses CRT;

function Init():boolean; stdcall;
function IsLensFrameNow():boolean; stdcall;
function NeedLensFrameNow():boolean; stdcall;
function LensConditions():boolean; stdcall;
function GetLensFOV(default:single):single;stdcall;
function GetCurrentFrameGpuID():cardinal; stdcall;
procedure CopyRenderTargetData(src:pCRT_rec; dest:pCRT_rec); stdcall;


implementation
uses BaseGameData, Windows, SysUtils, Misc, gunsl_config, ActorUtils, HudItemUtils, dynamic_caster, WeaponAdditionalBuffer, MatVectors, math, ConsoleUtils, ActorDOF;

var

  //data from engine
  pD3DXLoadSurfaceFromSurface:pointer;
  _copyresource_vftable_index:cardinal;
  pHW_Device:cardinal;
  pSwapchain:cardinal;
  pIID_ID3DTexture2D:cardinal;
  _p_iGPUNum:pCardinal;


  _is_lens_frame:boolean;      //flag
  _scoped_frames:cardinal;
  _non_scoped_frames:cardinal;
  _buffer_index:cardinal;  

  _restore_fov_after_lens_frame:single;
  _last_fov_changed_frame:cardinal; //кадр, в котором последний раз меняли фов

  _scopeframe_renderspecific_end:procedure(); stdcall;

  _dof_context:DofContext;

const
  D3DBACKBUFFER_TYPE_MONO:cardinal = 0;
  LENS_DOF_NEAR:single = -9151;
  LENS_DOF_FOCUS:single = 0;
  LENS_DOF_FAR:single = 9151;
  LENS_DOF_SPEED:single = 2.16723;


//Exports////////////////////////////////////
function IsLensFrameNow():boolean; stdcall;
begin
  result:=_is_lens_frame;
end;

function LensConditions():boolean; stdcall;
var
  wpn:pointer;
  buf:WpnBuf;
  scope_sect:PChar;
begin
    wpn:=GetActorActiveItem();
    if (wpn=nil) then begin
      result:=false;
      exit;
    end;
    
    buf:=GetBuffer(wpn);
    if (buf<>nil) and buf.NeedPermanentLensRendering() then begin
      result:=true;
      exit;
    end;

    //работать пока надо только с CWeapon
    wpn:=dynamic_cast(wpn, 0, RTTI_CHudItemObject, RTTI_CWeapon, false);
    if (wpn=nil) then begin
      result:=false;
      exit;
    end;

    if IsAimNow(wpn) or IsHolderInAimState(wpn) or (GetAimFactor(wpn)>0.001) then begin
      if IsScopeAttached(wpn) and (GetScopeStatus(wpn)=2) then begin
        scope_sect:=game_ini_read_string(GetCurrentScopeSection(wpn), 'scope_name');
        result:=game_ini_r_bool_def(scope_sect, 'need_lens_frame', false);
      end else begin
        result:=game_ini_r_bool_def(GetHUDSection(wpn), 'need_lens_frame', false);
      end;
      exit;
    end;

    result:=false;
end;

function NeedLensFrameNow():boolean; stdcall;
begin
  //в режиме форсирования кадра линзы один "гпу" (нулевой) постоянно загружен рендером линзовых кадров
  if IsForcedLens() then begin
    result:= (GetCurrentFrameGpuID()=0);
    exit;
  end;

  //иначе рендер линзы активен не всегда
  result:=(GetDevicedwFrame() mod ( (_p_iGPUNum^)*GetLensRenderFactor()))=0;
  if result then begin
    //если в меню - не рендерим
    if IsMainMenuActive() or IsDemoRecord() then begin
      result:=false;
      exit;
    end;
    result:=LensConditions();
  end;
end;

function GetLensFOV(default:single):single; stdcall;
var
  min, max, pos, dt, factor, fov:single;
  scope_sect:PChar;
  buf:WpnBuf;
  wpn:pointer;
begin
  result:=default;
  wpn:=GetActorActiveItem();
  if wpn=nil then exit;

  buf:=GetBuffer(wpn);
  if buf=nil then exit;

  buf.GetLensParams(min, max, pos, dt);
  if IsScopeAttached(wpn) and (GetScopeStatus(wpn)=2) then begin
    scope_sect:=game_ini_read_string(GetCurrentScopeSection(wpn), 'scope_name');
    min:=game_ini_r_single_def(scope_sect, 'min_lens_factor', 1.0);
    max:=game_ini_r_single_def(scope_sect, 'max_lens_factor', 1.0);
  end;
  factor:=min+(max-min)*pos;

  fov:=(GetBaseFOV()/2)*pi/180;
  result:=2*arctan(tan(fov)/factor)*180/pi;
end;

function GetCurrentFrameGpuID():cardinal; stdcall;
begin
  result:=(GetDevicedwFrame() mod _p_iGPUNum^);
end;

/////////////////////////////////////////////
function GetBackBuffer(iSwapChain: LongWord; iBackBuffer: LongWord; _Type: cardinal; ppBackBuffer:pointer):cardinal; stdcall;
asm
  pushad
    mov ebx, pHW_Device
    mov ebx, [ebx]
    mov eax, [ebx]
    mov eax, [eax+$48]

    push ppBackBuffer
    push _Type
    push iBackBuffer
    push iSwapChain
    push ebx
    call eax

    mov @result, eax
  popad
end;


function LoadSurfaceFromSurface(this, dest:pointer):cardinal; stdcall;
asm
  pushad
    push 0
    push $FFFFFFFF
    push 0
    push 0
    push this
    push 0
    push 0
    push dest
    mov eax, pD3DXLoadSurfaceFromSurface
    call eax
    mov @result, eax
  popad
end;

procedure RenderSpecific_End_R1_R2(); stdcall;
var
  backbuffer:   {IDirect3DSurface9} pointer;
begin
    GetBackBuffer(0, 0, D3DBACKBUFFER_TYPE_MONO, @backbuffer);
    if backbuffer = nil then exit;
    LoadSurfaceFromSurface(backbuffer, GetScoperender().pRT);
    IUnknown(backbuffer)._Release();
end;


function CopyResource(this, dest:pointer):cardinal; stdcall;
asm
  pushad
    push this
    push dest

    mov eax, pHW_Device
    mov eax, [eax]
    push eax

    mov ecx, [eax]
    mov eax, ecx
    add eax, _copyresource_vftable_index

    call [eax]

    mov @result, eax  
  popad
end;


procedure RenderSpecific_End_R3_R4(); stdcall;
asm
  pushad

    mov eax, pSwapchain
    mov eax, [eax]
    mov ecx, [eax]

    push eax //buffer address will be written here
    lea edx, [esp]
    mov ebx, pIID_ID3DTexture2D //__uuidof( ID3D10Texture2D )

    push edx //pBuffer
    push ebx //guid
    push 0
    push eax //HW.m_pSwapChain
    mov eax, [ecx+$24]
    call eax //HW.m_pSwapChain->GetBuffer

    call GetScoperender
    push [eax+CRT_rec.pSurface]

    mov edx, [esp+4]
    push edx //Buffer

    call CopyResource

    mov ecx, [esp]
    mov eax, [ecx]
    mov eax, [eax+$8]
    call eax          //release

  popad
end;

procedure CopyRenderTargetData(src:pCRT_rec; dest:pCRT_rec); stdcall;
begin
  if (xrRender_R1_addr<>0) or (xrRender_R2_addr<>0) then begin
    LoadSurfaceFromSurface(src.pRT, dest.pRT);
  end else if (xrRender_R3_addr<>0) or (xrRender_R4_addr<>0) then begin
    CopyResource(src.pSurface, dest.pSurface);
  end;
end;

procedure dof_lens_on(); stdcall;
var
  local_dof:DofContext;
begin
    _dof_context.valid:=false;
    GetContext(@_dof_context);
    if _dof_context.valid then begin
      local_dof.values.dest.x:=LENS_DOF_NEAR;
      local_dof.values.dest.y:=LENS_DOF_FOCUS;
      local_dof.values.dest.z:=LENS_DOF_FAR;
      local_dof.values.current:=local_dof.values.dest;
      local_dof.values.from:=local_dof.values.dest;
      local_dof.values.original:=_dof_context.values.original;

      local_dof.change_speed_koef:=LENS_DOF_SPEED;
      local_dof.change_speed_recalc:=LENS_DOF_SPEED;
      local_dof.valid:=true;
      SetContext(@local_dof);
//      log('save dof');
    end;
end;

procedure dof_lens_off(); stdcall;
var
  local_dof:DofContext;
begin
  GetContext(@local_dof);
  if (_dof_context.valid) and (local_dof.valid) then begin
      //мы что-то сохранили, надо восстановить
      
    if
      (local_dof.values.dest.x=LENS_DOF_NEAR)
      and
      (local_dof.values.dest.y=LENS_DOF_FOCUS)
      and
      (local_dof.values.dest.z=LENS_DOF_FAR)
      and
      (local_dof.change_speed_koef=LENS_DOF_SPEED)
      and
      (local_dof.change_speed_recalc=LENS_DOF_SPEED)
    then begin
      //изменений не было, восстанавливаем старый
      _dof_context.values.original:=local_dof.values.original;   //на всякий, вдруг изменился...
      SetContext(@_dof_context);
//      log('restore dof');
    end else begin
      // не повезло - на этом кадре кто-то сменил целевой доф
//      log('dof changed! restoring known');
      local_dof.values.current:=_dof_context.values.current;
      local_dof.values.from:=_dof_context.values.from;
      SetContext(@local_dof);
    end;
  end;
  _dof_context.valid :=false
end;

/////////////////////////////////////////////
// До рендера
procedure BeginSecondVP( ); stdcall;
begin
  if _is_lens_frame then begin
    _scoped_frames:=_scoped_frames+1;
    dof_lens_on();
  end else begin
    _non_scoped_frames:=_non_scoped_frames+1;
  end;

  if IsForcedLens() then begin
    _buffer_index:=GetDevicedwFrame();
  end else begin
    _buffer_index:=_non_scoped_frames;
  end;
end;

// После рендера мира и до UI
procedure EndSecondVP( ); stdcall;
begin
  if _is_lens_frame then begin
    _scopeframe_renderspecific_end();
    dof_lens_off();
  end;
end;

procedure CLevel__OnRender_Before_Patch(); stdcall
asm
    pushad
    call BeginSecondVP
    popad

    mov eax, xrgame_addr
    call [eax+$512f30]
end;

procedure CLevel__OnRender_After_Patch(); stdcall
asm
   pushad
   call EndSecondVP
   popad

   mov ecx, xrgame_addr
   mov ecx, [ecx+$512D30]
end;

procedure CCameraManager__Update_Lens_FOV_manipulation(value:pSingle); stdcall;
begin

  if GetDevicedwFrame()=_last_fov_changed_frame then begin
    value^:=GetLensFOV(value^);
    exit;
  end;

  if _restore_fov_after_lens_frame = 0 then begin
    //мы не меняли ФОВ ранее. Если рисуется кадр линзы - сохраним и выставим фов линзы
    if NeedLensFrameNow() then begin
      _restore_fov_after_lens_frame:=value^;
      _last_fov_changed_frame:=GetDevicedwFrame();
      value^:=GetLensFOV(value^);
      _is_lens_frame:=true;
    end;
  end else begin
    //Мы ранее уже изменили фов. Если до сих пор нужно делать кадр линзы - просто выставим его фов, иначе - восстановим то, что изменили
    if NeedLensFrameNow() then begin
      value^:=GetLensFOV(value^);
      _last_fov_changed_frame:=GetDevicedwFrame();
      _is_lens_frame:=true;
    end else begin
      value^:= _restore_fov_after_lens_frame;
      _restore_fov_after_lens_frame:=0;
    end;
  end;
end;

procedure CCameraManager__Update_Lens_FOV_manipulation_Patch(); stdcall;
asm
  movss [esi+$3c], xmm1
  mov byte ptr [esi+$40], 0
  pushad
    add esi, $34
    push esi
    call CCameraManager__Update_Lens_FOV_manipulation
  popad
end;


procedure need_render_hud_patch(); stdcall;
asm
  mov al, 1
  cmp _is_lens_frame, 0
  je @finish
  xor al, al
  @finish:
  pop edi
  pop esi
  ret
end;

//Функции организации невывода кадра линзы на экран для каждого из рендеров////////////////////////////////////
// R2 -> Эта функция отвечает за вызов ->Present(), который обновляет картинку на экране
// Она есть в каждом рендере.
procedure dxRenderDeviceRender__End__R1_R2(); stdcall
label original;
asm
    // Проверяем, идёт ли сейчас рендер второго кадра
    cmp _is_lens_frame, 0
    je original

    // Если да, то не обновляем картинку на экране
    mov _is_lens_frame, 0
    ret

    // Если нет, то отрисовываем на экран (вызываем Present())
    original:
    push 00
    push 00
    push 00
    push 00
    push eax
    call edx
end;

procedure dxRenderDeviceRender__End__R3_R4(); stdcall
label original;
asm
    // Проверяем, идёт ли сейчас рендер второго кадра
    cmp _is_lens_frame, 0
    je original

    // Если да, то не обновляем картинку на экране
    mov _is_lens_frame, 0
    ret

    // Если нет, то отрисовываем на экран (вызываем Present())
    original:


    push 00
    push 00
    push eax
    call edx
end;


procedure CActor__UpdateCL_Crosshair_Patch(); stdcall;
//запрещаем обновлять дисперсию, когда рендерится кадр прицела
asm
  cmp _is_lens_frame, 0
  jne @finish
    sub esp, 8
    fstp dword ptr [esp+$4]
    fstp dword ptr [esp]
    mov eax, xrGame_addr
    add eax, $4b01e0
    call eax          //CHudManager::SetCrosshairDisp    
  @finish:
end;

//////////////////////////////////////////////////////////////////////
function Init():boolean; stdcall;
var
 jmp_addr:cardinal;
 dHandle:cardinal;
 buf:pCardinal;
begin
  result:=false;
  _is_lens_frame:=false;
  _restore_fov_after_lens_frame:=0;
  _last_fov_changed_frame:=0;
  _scoped_frames:=0;
  _non_scoped_frames:=0;
  _dof_context.valid:=false;
  
  if xrRender_R1_addr<>0 then begin
    dHandle := LoadLibrary('d3dx9_42.dll');
    pD3DXLoadSurfaceFromSurface:=GetProcAddress(dHandle, 'D3DXLoadSurfaceFromSurface');
    FreeLibrary(dHandle);
    log('pD3DXLoadSurfaceFromSurface = '+inttohex(cardinal(pD3DXLoadSurfaceFromSurface),8));

    pHW_Device:=xrRender_R1_addr+$A4900;
    _p_iGPUNum:=pointer(xrRender_R1_addr+$A491C);
    _scopeframe_renderspecific_end:=@RenderSpecific_End_R1_R2;

    jmp_addr:=xrRender_R1_addr+$4774F;
    if not WriteJump(jmp_addr, cardinal(@dxRenderDeviceRender__End__R1_R2), 11, false) then exit;

  end else if xrRender_R2_addr<>0 then begin
    dHandle := LoadLibrary('d3dx9_42.dll');
    pD3DXLoadSurfaceFromSurface:=GetProcAddress(dHandle, 'D3DXLoadSurfaceFromSurface');
    FreeLibrary(dHandle);
    log('pD3DXLoadSurfaceFromSurface = '+inttohex(cardinal(pD3DXLoadSurfaceFromSurface),8));
    
    pHW_Device:=xrRender_R2_addr+$CBB88;
    _p_iGPUNum:=pointer(xrRender_R2_addr+$CBBA4);
    _scopeframe_renderspecific_end:=@RenderSpecific_End_R1_R2;
    jmp_addr:=xrRender_R2_addr+$AF06C;
    if not WriteJump(jmp_addr, cardinal(@dxRenderDeviceRender__End__R1_R2), 11, false) then exit;

    buf:=@_buffer_index;
    //CRenderTarget::phase_combine
    nop_code(xrRender_R2_addr+$6CBEC, 9);
    nop_code(xrRender_R2_addr+$6CBEC, 1, CHR($A1)); //opcode 'mov eax, [xxxxxxxx]'
    if not WriteBufAtAdr(xrRender_R2_addr+$6CBED, @buf, sizeof(buf)) then exit;
    //CRenderTarget::phase_luminance
    nop_code(xrRender_R2_addr+$70575, 9);
    nop_code(xrRender_R2_addr+$70575, 1, CHR($A1)); //opcode 'mov eax, [xxxxxxxx]'
    if not WriteBufAtAdr(xrRender_R2_addr+$70576, @buf, sizeof(buf)) then exit;

  end else if xrRender_R3_addr<>0 then begin
    pHW_Device:=xrRender_R3_addr+$E7E38;
    pSwapchain:=xrRender_R3_addr+$E7E44;
    _p_iGPUNum:=pointer(xrRender_R3_addr+$E7E60);
    pIID_ID3DTexture2D:=xrRender_R3_addr+$D7104;
    _copyresource_vftable_index:=$84;
    _scopeframe_renderspecific_end:=@RenderSpecific_End_R3_R4;
    jmp_addr:=xrRender_R3_addr+$BB920;
    if not WriteJump(jmp_addr, cardinal(@dxRenderDeviceRender__End__R3_R4), 7, false) then exit;


    buf:=@_buffer_index;
    nop_code(xrRender_R3_addr+$7676F, 9);
    nop_code(xrRender_R3_addr+$7676F, 1, CHR($A1)); //opcode 'mov eax, [xxxxxxxx]'
    if not WriteBufAtAdr(xrRender_R3_addr+$76770, @buf, sizeof(buf)) then exit;

    nop_code(xrRender_R3_addr+$79BFD, 9);
    nop_code(xrRender_R3_addr+$79BFD, 1, CHR($A1)); //opcode 'mov eax, [xxxxxxxx]'
    if not WriteBufAtAdr(xrRender_R3_addr+$79BFE, @buf, sizeof(buf)) then exit;
  end else if xrRender_R4_addr<>0 then begin
    pHW_Device:=xrrender_R4_addr+$106C10;
    pSwapchain:=xrRender_R4_addr+$106C14;
    _p_iGPUNum:=pointer(xrRender_R4_addr+$106C30);
    pIID_ID3DTexture2D:=xrRender_R4_addr+$E3950;
    _copyresource_vftable_index:=$BC;
    _scopeframe_renderspecific_end:=@RenderSpecific_End_R3_R4;
    jmp_addr:=xrRender_R4_addr+$C63B0;
    if not WriteJump(jmp_addr, cardinal(@dxRenderDeviceRender__End__R3_R4), 7, false) then exit;

    buf:=@_buffer_index;
    //CRenderTarget::phase_combine
    nop_code(xrRender_R4_addr+$7AF1F, 9);
    nop_code(xrRender_R4_addr+$7AF1F, 1, CHR($A1)); //opcode 'mov eax, [xxxxxxxx]'
    if not WriteBufAtAdr(xrRender_R4_addr+$7AF20, @buf, sizeof(buf)) then exit;
    //CRenderTarget::phase_luminance
    nop_code(xrRender_R4_addr+$7ED43, 9);
    nop_code(xrRender_R4_addr+$7ED43, 1, CHR($A1)); //opcode 'mov eax, [xxxxxxxx]'
    if not WriteBufAtAdr(xrRender_R4_addr+$7ED44, @buf, sizeof(buf)) then exit;
  end else begin
    dHandle:=0;
    pD3DXLoadSurfaceFromSurface:=nil;
    log('LensDoubleRender.Init: No Render DLL!');
    exit;
  end;

  jmp_addr:=xrGame_addr+$232C03;
  if not WriteJump(jmp_addr, cardinal(@CLevel__OnRender_Before_Patch), 6, true) then exit;

  jmp_addr:=xrGame_addr+$232C34;
  if not WriteJump(jmp_addr, cardinal(@CLevel__OnRender_After_Patch), 6, true) then exit;

  jmp_addr:=xrEngine_addr+$2CAB9;
  if not WriteJump(jmp_addr, cardinal(@CCameraManager__Update_Lens_FOV_manipulation_Patch), 9, true) then exit;

  jmp_addr:=xrGame_addr+$4B061D;
  if not WriteJump(jmp_addr, cardinal(@need_render_hud_patch), 5, false) then exit;


  jmp_addr:=xrGame_addr+$26211C;
  if not WriteJump(jmp_addr, cardinal(@CActor__UpdateCL_Crosshair_Patch), 15, true) then exit;


  result:=true;
end;

end.
