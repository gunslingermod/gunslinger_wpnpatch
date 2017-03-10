unit LensDoubleRender;

interface
function Init():boolean; stdcall;
function IsLensFrameNow():boolean; stdcall;
function NeedLensFrameNow():boolean; stdcall;


implementation
uses BaseGameData, Windows, SysUtils, CRT, Misc, gunsl_config, ActorUtils, HudItemUtils;

var
  pD3DXLoadSurfaceFromSurface:pointer;
  pHW_Device:cardinal;

  is_lens_frame:boolean;      //flag

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


function LoadSurfaceFromSurface(from, dest:pointer):cardinal; stdcall;
asm
  pushad
    push 0
    push $FFFFFFFF
    push 0
    push 0
    push from
    push 0
    push 0
    push dest
    mov eax, pD3DXLoadSurfaceFromSurface
    call eax
    mov @result, eax
  popad
end;
/////////////////////////////////////////////

// До рендера
procedure BeginSecondVP( ); stdcall;
begin
  // TODO: Делать проверку, что двойной рендер и изменять матрицу проекции рендера
end;

// После рендера мира и до UI
procedure EndSecondVP( ); stdcall;
var
  rb:           Cardinal;
  backbuffer:   {IDirect3DSurface9} pointer;
begin
// TODO: Делать проверку, что двойной рендер и восстанавливать матрицу проекции рендера


  GetBackBuffer(0, 0, D3DBACKBUFFER_TYPE_MONO, @backbuffer);
  if backbuffer = nil then exit;
  LoadSurfaceFromSurface(backbuffer, GetScoperenderRT());
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
  result:=is_lens_frame;
end;

function NeedLensFrameNow():boolean; stdcall;
var
  wpn:pointer;
begin
  result:=(GetDevicedwFrame() mod GetLensRenderFactor())=0;
  if result then begin
    wpn:=GetActorActiveItem();
    result:= (wpn<>nil) and (IsAimNow(wpn) or IsHolderInAimState(wpn));
  end;
end;


function Init():boolean; stdcall;
var
 jmp_addr:cardinal;
 dHandle:cardinal;
begin
  result:=false;
  is_lens_frame:=false;
  
  if xrRender_R2_addr<>0 then begin
    dHandle := LoadLibrary('d3dx9_42.dll');
    pHW_Device:=xrRender_R2_addr+$CBB88;
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

  pD3DXLoadSurfaceFromSurface:=GetProcAddress(dHandle, 'D3DXLoadSurfaceFromSurface');
  FreeLibrary(dHandle);

  log('pD3DXLoadSurfaceFromSurface = '+inttohex(cardinal(pD3DXLoadSurfaceFromSurface),8));

  result:=true;
end;

end.
