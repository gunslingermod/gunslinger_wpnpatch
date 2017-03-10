unit LensDoubleRender;

interface

{type uuid = packed record
  f1:cardinal;
  f2:word;
  f3:word;
  r4:word;
  r51:word;
  r52:cardinal;
end;        }


function Init():boolean; stdcall;
function IsLensFrameNow():boolean; stdcall;
function NeedLensFrameNow():boolean; stdcall;
function GetLensFOV(default:single):single;stdcall;


implementation
uses BaseGameData, Windows, SysUtils, CRT, Misc, gunsl_config, ActorUtils, HudItemUtils, dynamic_caster, WeaponAdditionalBuffer, MatVectors, math, ConsoleUtils;

var
  pD3DXLoadSurfaceFromSurface:pointer;
  pHW_Device:cardinal;
  pSwapchain:cardinal;
  pIID_ID3DTexture2D:cardinal;

  _is_lens_frame:boolean;      //flag

  _restore_fov_after_lens_frame:single;
  _last_fov_changed_frame:cardinal; //кадр, в котором последний раз меняли фов
  _copyframe:procedure; stdcall;
  _copyresource_vftable_index:cardinal;

const
  D3DBACKBUFFER_TYPE_MONO:cardinal = 0;

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

procedure CopyFrame_R1_R2(); stdcall;
var
  backbuffer:   {IDirect3DSurface9} pointer;
begin
    GetBackBuffer(0, 0, D3DBACKBUFFER_TYPE_MONO, @backbuffer);
    if backbuffer = nil then exit;
    LoadSurfaceFromSurface(backbuffer, GetScoperenderRT());
    IUnknown(backbuffer)._Release();
end;

procedure CopyFrame_R3_R4(); stdcall;
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

    mov edx, [esp]
    push edx //Buffer

    call GetScoperenderT2D
    push eax


    mov eax, pHW_Device
    mov eax, [eax]
    push eax

    mov ecx, [eax]
    mov eax, ecx
    add eax, _copyresource_vftable_index

    call [eax]

    mov ecx, [esp]
    mov eax, [ecx]
    mov eax, [eax+$8]
    call eax          //release

    //add esp, 4 //kill buffer address
  popad
end;

/////////////////////////////////////////////

// До рендера
procedure BeginSecondVP( ); stdcall;
begin
  _is_lens_frame:=NeedLensFrameNow();

end;

// После рендера мира и до UI
procedure EndSecondVP( ); stdcall;
var
  backbuffer:   {IDirect3DSurface9} pointer;
begin
  if _is_lens_frame then begin
    _copyframe();
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

function IsLensFrameNow():boolean; stdcall;
begin
  result:=_is_lens_frame;
end;

function NeedLensFrameNow():boolean; stdcall;
var
  wpn:pointer;
  buf:WpnBuf;
  scope_sect:PChar;
begin
  result:=(GetDevicedwFrame() mod GetLensRenderFactor())=0;
  if result then begin
    //если в меню - не рендерим
    if IsMainMenuActive() or IsDemoRecord() then begin
      result:=false;
      exit;    
    end;

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
    min:=game_ini_r_int_def(scope_sect, 'min_lens_factor', 1);
    max:=game_ini_r_int_def(scope_sect, 'max_lens_factor', 1);
  end;
  factor:=min+(max-min)*pos;

  fov:=(GetBaseFOV()/2)*pi/180;
  result:=2*arctan(tan(fov)/factor)*180/pi;
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
    end;
  end else begin
    //Мы ранее уже изменили фов. Если до сих пор нужно делать кадр линзы - просто выставим его фов, иначе - восстановим то, что изменили
    if NeedLensFrameNow() then begin
      value^:=GetLensFOV(value^);
      _last_fov_changed_frame:=GetDevicedwFrame();
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
////////////////////////////////////////////////////////////////////////


function Init():boolean; stdcall;
var
 jmp_addr:cardinal;
 dHandle:cardinal;
begin
  result:=false;
  _is_lens_frame:=false;
  _restore_fov_after_lens_frame:=0;
  _last_fov_changed_frame:=0;

{  ID3D10RenderTargetView_id.f1:=$9b7e4c08;
  ID3D10RenderTargetView_id.f2:=$342c;
  ID3D10RenderTargetView_id.f3:=$4106;
  ID3D10RenderTargetView_id.r4:=$9fa1;
  ID3D10RenderTargetView_id.r51:=$274f;
  ID3D10RenderTargetView_id.r52:=$f089f604;  }
  
  if xrRender_R1_addr<>0 then begin
    dHandle := LoadLibrary('d3dx9_42.dll');
    pD3DXLoadSurfaceFromSurface:=GetProcAddress(dHandle, 'D3DXLoadSurfaceFromSurface');
    FreeLibrary(dHandle);
    log('pD3DXLoadSurfaceFromSurface = '+inttohex(cardinal(pD3DXLoadSurfaceFromSurface),8));

    pHW_Device:=xrRender_R1_addr+$A4900;
    _copyframe:=@CopyFrame_R1_R2;
    jmp_addr:=xrRender_R1_addr+$4774F;
    if not WriteJump(jmp_addr, cardinal(@dxRenderDeviceRender__End__R1_R2), 11, false) then exit;

  end else if xrRender_R2_addr<>0 then begin
    dHandle := LoadLibrary('d3dx9_42.dll');
    pD3DXLoadSurfaceFromSurface:=GetProcAddress(dHandle, 'D3DXLoadSurfaceFromSurface');
    FreeLibrary(dHandle);
    log('pD3DXLoadSurfaceFromSurface = '+inttohex(cardinal(pD3DXLoadSurfaceFromSurface),8));
    
    pHW_Device:=xrRender_R2_addr+$CBB88;
    _copyframe:=@CopyFrame_R1_R2;
    jmp_addr:=xrRender_R2_addr+$AF06C;
    if not WriteJump(jmp_addr, cardinal(@dxRenderDeviceRender__End__R1_R2), 11, false) then exit;

  end else if xrRender_R3_addr<>0 then begin
    pHW_Device:=xrrender_r3_addr+$E7E38;
    pSwapchain:=xrRender_R3_addr+$E7E44;
    pIID_ID3DTexture2D:=xrRender_r3_addr+$D7104;
    _copyresource_vftable_index:=$84;
    _copyframe:=@CopyFrame_R3_R4;
    jmp_addr:=xrRender_R3_addr+$BB920;
    if not WriteJump(jmp_addr, cardinal(@dxRenderDeviceRender__End__R3_R4), 7, false) then exit;
  end else if xrRender_R4_addr<>0 then begin
    pHW_Device:=xrrender_R4_addr+$106C10;
    pSwapchain:=xrRender_R4_addr+$106C14;
    pIID_ID3DTexture2D:=xrRender_R4_addr+$E3950;
    _copyresource_vftable_index:=$BC;
    _copyframe:=@CopyFrame_R3_R4;
    jmp_addr:=xrRender_R4_addr+$C63B0;
    if not WriteJump(jmp_addr, cardinal(@dxRenderDeviceRender__End__R3_R4), 7, false) then exit;
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

  result:=true;
end;

end.
