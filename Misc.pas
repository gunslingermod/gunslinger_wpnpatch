unit Misc;

interface
uses MatVectors;
//всячина, которую не особо понятно, в какие модули спихнуть

type CSE_Abstract = packed record
  vftable:pointer;
  _flags_ISE:cardinal;

  vec_memend:pointer;
  vec_end:pointer;
  vec_start:pointer;

  unk1:cardinal;
  unk2:cardinal;
  unk3:cardinal;
  s_name_replace:PChar;
  net_Ready:integer;
  net_Processed:integer;
  m_wVersion:word;
  m_script_version:word;
  RespawnTime:word;
  ID:word;
  ID_Parent:word;

  //to be continued...
end;

type pCSE_Abstract = ^CSE_Abstract;

function Init():boolean;stdcall;
function dxGeomUserData__get_ph_ref_object(dxGeomUserData:pointer):pointer;
function PHRetrieveGeomUserData(dxGeom:pointer):pointer; stdcall;
function game_object_GetScriptGameObject(obj:pointer):pointer;stdcall;
function get_server_object_by_id(id:cardinal):pointer;stdcall;
function alife():pointer;stdcall;
function alife_create(section:PChar; pos:pointer; lvid:cardinal; gvid:cardinal):pCSE_Abstract;stdcall;
function alife_release(srv_obj:pointer):boolean;stdcall;
function xrMemory__allocate(count:cardinal):pointer;stdcall;
function xrMemory__release(addr:pointer):pointer;stdcall;

function CALifeSimulator__spawn_item2(section:PChar; position:pFVector3; level_vertex_id:cardinal; game_vertex_id:cardinal; id_parent:cardinal):{CSE_Abstract*}pointer; stdcall;
function GetMaterialIdx(name:PChar):word; stdcall;
function GetDevicedwFrame():cardinal; stdcall;
procedure DecDevicedwFrame(); stdcall;
function GetDeviceView():pFMatrix4x4; stdcall;
function GetDeviceProjection():pFMatrix4x4; stdcall;
function GetDeviceFullTransform():pFMatrix4x4; stdcall;
function GetDeviceTimeDelta():single; stdcall;

function IsMainMenuActive():boolean; stdcall;

procedure WriteToPacket(packet:pointer; data:pointer; bytes_count:cardinal); stdcall;
procedure ReadFromReader(IReader:pointer; buf:pointer; bytes_count:cardinal); stdcall;

function GetCObjectID(CObject:pointer):word; stdcall;
function GetCObjectXForm(CObject:pointer):pFMatrix4x4; stdcall;
function GetCObjectVisual(CObject:pointer):pointer; stdcall;

function GetAngleByLegs(x,y:single):single;

function IsInputExclusive:boolean; stdcall;


implementation
uses BaseGameData, ActorUtils, gunsl_config, Math;
var
  cscriptgameobject_restoreweaponimmediatly_addr:pointer;



function dxGeomUserData__get_ph_ref_object(dxGeomUserData:pointer):pointer;
asm
  mov eax, dxGeomUserData
  cmp eax, 0
  je @null
  mov eax, [eax+$20]
  mov @result, eax
  jmp @finish

  @null:
  mov @result, 0

  @finish:
end;

function PHRetrieveGeomUserData(dxGeom:pointer):pointer; stdcall;
asm
  pushad

  mov eax, dxGeom
  cmp eax, 0
  je @null

  push eax  //dxGeom
  mov eax, xrgame_addr
  add eax, $5131d4
  call [eax]
  add esp, 4
  mov @result, eax
  jmp @finish

  @null:
  mov @result, 0

  @finish:
  popad
end;


function game_object_GetScriptGameObject(obj:pointer):pointer;stdcall;
asm
  pushad
    mov ecx, obj
    mov eax, xrgame_addr
    add eax, $27FD40
    call eax
    mov @result, eax
  popad
end;

function get_server_object_by_id(id:cardinal):pointer;stdcall;
//!!Changes ECX!!
asm
    pushad
    pushfd

    mov ecx, xrGame_addr
    mov ecx, [ecx+$64DA98]
    mov ecx, [ecx+$14]

    push id
    push ecx

    mov eax, xrgame_addr
    add eax, $99450
    call eax
    add esp,8
    mov @Result, eax

    popfd
    popad
end;


function alife():pointer;
asm
  pushad
  pushfd

  mov eax, xrgame_addr
  add eax, $97780
  call eax
  mov @result, eax
  
  popfd
  popad
end;

function alife_create(section:PChar; pos:pointer; lvid:cardinal; gvid:cardinal):pCSE_Abstract; stdcall;
asm
  mov @result, 0
  pushad
    call alife
    cmp eax, 0
    je @finish
    push gvid
    push lvid
    push pos
    push section
    push eax

    mov eax, xrgame_addr
    add eax, $96eb0
    call eax
    
    add esp, $14
    mov @result, eax
    @finish:
  popad
end;

function CALifeSimulator__spawn_item2(section:PChar; position:pFVector3; level_vertex_id:cardinal; game_vertex_id:cardinal; id_parent:cardinal):{CSE_Abstract*}pointer; stdcall;
asm
  mov @result, 0
  pushad
    call alife
    cmp eax, 0
    je @finish

    push id_parent
    push game_vertex_id
    push level_vertex_id
    push position
    push section
    push eax

    mov eax, xrgame_addr
    add eax, $99490
    call eax

    mov @result, eax

    add esp, $18
    @finish:
  popad
end;



function alife_release(srv_obj:pointer):boolean;stdcall;
asm
  mov @result, 0
  pushad
    cmp srv_obj, 0
    je @finish
    call alife
    cmp eax, 0
    je @finish
    push 01
    push srv_obj
    push eax

    mov eax, xrgame_addr
    add eax, $98410
    call eax
    add esp, $C
    mov @result, al

    @finish:
  popad
end;


procedure get_rank_Patch(); stdcall;
asm
  xor esi, esi
end;


procedure CScriptgameobject__restoreweaponimmediatly_impl(act:pointer);stdcall;
var
  i:integer;
  cnt:cardinal;
begin
  if act<>GetActor() then exit;
  for i:=1 to 12 do begin
    cnt:=GetActorSlotBlockedCounter(i);
    if cnt>0 then SetActorSlotBlockedCounter(i, cnt-1)
  end;
end;

procedure CScriptgameobject__restoreweaponimmediatly();stdcall;
asm
  pushad
  push [ecx+4]
  call CScriptgameobject__restoreweaponimmediatly_impl
  popad
end;

procedure register_cscriptgameobject_restoreweaponimmediatly();stdcall;
const
  name:PChar='restore_weapon_immediatly';
asm
  mov [esp+$58], bl
  mov ecx, [esp+$58]
  push ecx

  mov [esp+$28], bl
  mov edx, [esp+$28]
  push edx

  lea ecx, [esp+$60]
  push ecx

  lea edx, [esp+$28]
  push edx

  push name
  mov ecx, eax

  mov edx, cscriptgameobject_restoreweaponimmediatly_addr
  mov [esp+$30], edx

  mov edx, xrgame_addr
  add edx, $1D4350
  call edx

  mov [esp+$58], bl
  mov ecx, [esp+$58]

end;

function GetMaterialIdx(name:PChar):word; stdcall;
asm
  pushad
    mov ecx, xrgame_addr
    mov ecx, [ecx+$512bd4]

    push name

    mov eax, [xrengine_addr]
    add eax, $34250

    call eax

    mov @result, ax
  popad
end;

function xrMemory__allocate(count:cardinal):pointer;stdcall;
asm
  pushad
  push count

  mov eax, xrCore_addr
  lea ecx, [eax+$3f854] //xrCore.Memory

  add eax, $1AF00
  call eax
  mov @result, eax
  popad
end;

function xrMemory__release(addr:pointer):pointer;stdcall;
asm
  pushad
  push addr

  mov eax, xrCore_addr
  lea ecx, [eax+$3f854] //xrCore.Memory

  add eax, $1AFF0
  call eax
  popad
end;

function GetDevicedwFrame():cardinal; stdcall;
asm
  mov eax, xrEngine_addr
  mov eax, [eax+$92EF0]
  mov @result, eax
end;

procedure DecDevicedwFrame(); stdcall;
asm
  push eax
  mov eax, xrEngine_addr
  dec [eax+$92EF0]
  pop eax
end;

function IsMainMenuActive():boolean; stdcall;
asm
  pushad
    mov @result, 0
    mov eax, xrEngine_addr
    mov eax, [eax+$92D30]
    test eax, eax
    je @finish
    mov ecx, [eax+$46C]
    mov edx, [ecx]
    mov eax, [edx+$08]
    call eax
    mov @result, al

    @finish:
  popad
end;

function GetDeviceView():pFMatrix4x4; stdcall;
asm
  mov eax, xrEngine_addr
  lea eax, [eax+$92ED8+$60]
  mov @result, eax
end;

function GetDeviceProjection():pFMatrix4x4; stdcall;
asm
  mov eax, xrEngine_addr
  lea eax, [eax+$92ED8+$A0]
  mov @result, eax
end;

function GetDeviceFullTransform():pFMatrix4x4; stdcall;
asm
  mov eax, xrEngine_addr
  lea eax, [eax+$92ED8+$E0]
  mov @result, eax
end;

//-----------------------------------------------------------------------------------------------------------
procedure WriteToPacket(packet:pointer; data:pointer; bytes_count:cardinal); stdcall;
asm
  pushad
    mov eax, xrgame_addr
    mov eax, [eax+$5127cc] //NET_Packet::w

    push bytes_count
    push data

    mov ecx, packet
    call eax;
  popad
end;


procedure ReadFromReader(IReader:pointer; buf:pointer; bytes_count:cardinal); stdcall;
asm
  pushad
    mov eax, xrgame_addr
    mov eax, [eax+$5127D4]

    push bytes_count
    push buf

    mov ecx, IReader
    call eax;
  popad
end;


function GetDeviceTimeDelta():single; stdcall;
asm
  mov eax, xrEngine_addr
  mov eax, [eax+$92ED8+$1C]
  mov @result, eax
end;

function GetCObjectID(CObject:pointer):word; stdcall;
asm
  mov eax, [CObject]
  movzx eax, word ptr [eax+$A4]
  mov @result, ax
end;

function GetCObjectXForm(CObject:pointer):pFMatrix4x4; stdcall;
asm
  mov eax, [CObject]
  lea eax, [eax+$50]
  mov @result, eax
end;

function GetCObjectVisual(CObject:pointer):pointer; stdcall;
asm
  mov eax, [CObject]
  mov eax, [eax+$90]
  mov @result, eax
end;

//-----------------------------------------------------------------------------------------------------------

procedure CHW__CreateDevice_VSync_R1_R2; stdcall;
asm
  pushad
    call IsVSyncEnabled
    cmp al, 0
    je @no_vsync
      mov [edi+$34], 0 //D3DPRESENT_INTERVAL_DEFAULT
      jmp @finish
    @no_vsync:
      mov [edi+$34], $80000000 //D3DPRESENT_INTERVAL_IMMEDIATE
    @finish:
  popad
end;


procedure CHW__Reset_VSync_R1_R2; stdcall;
asm
  pushad
    call IsVSyncEnabled
    cmp al, 0
    je @no_vsync
      mov [ebx+$A8], 0 //D3DPRESENT_INTERVAL_DEFAULT
      jmp @finish
    @no_vsync:
      mov [ebx+$A8], $80000000 //D3DPRESENT_INTERVAL_IMMEDIATE
    @finish:
  popad
end;

function IsInputExclusive:boolean; stdcall;
asm
  mov eax, xrengine_addr
  add eax, $9032B
  mov al, byte ptr [eax]
  mov @result, al
end;

function GetAngleByLegs(x,y:single):single;
var
  gyp, k:single;
begin
  gyp:=sqrt(x*x+y*y);
  k:=clamp(y/gyp, -1.0, 1.0);
  result:=arcsin(k);
  if (x<0) then begin
     result:=pi-result
  end;
  if result<0 then result:=result+2*pi;
end;


function Init():boolean;stdcall;
var
  jmp_addr:cardinal;
begin
  //затычка от вылета mp_ranks
  result:=false;
  jmp_addr:=xrGame_addr+$4CCD0E;
  if not WriteJump(jmp_addr, cardinal(@get_rank_Patch), 47, true) then exit;

  //[bug] баг -в CLevel::ClientSend исправляем if (GameID() == eGameIDSingle || OnClient()) на if (GameID() != eGameIDSingle || OnClient()) - thanks to Shoker
  if not nop_code(xrGame_addr+$238D55, 1, CHR($75)) then exit;

  //[bug] баг - забытый дефайн на DX11 в void dxFontRender::OnRender(CGameFont &owner), строка 120, приводит к мылу
  if xrRender_R4_addr<>0 then begin
    if not nop_code(xrRender_R4_addr+$C7345, 4) then exit;
    if not nop_code(xrRender_R4_addr+$C735F, 4) then exit;    
  end;

  jmp_addr:=xrGame_addr+$1ECFF6;
  cscriptgameobject_restoreweaponimmediatly_addr := @CScriptgameobject__restoreweaponimmediatly;
  if not WriteJump(jmp_addr, cardinal(@register_cscriptgameobject_restoreweaponimmediatly), 8, true) then exit;


  //[bug] баг с лампочками - thanks to SkyLoader; убираем условие в CHangingLamp::TurnOff, чтобы processing_deactivate срабатывал всегда
  if not nop_code(xrGame_addr+$2957e7, 2) then exit;

  //[bug] баг с VSync - thanks to SkyLoader; здесь правим для DirectX 8/9, исправления для DirectX 10/11 смотреть в LensDoubleRender
  if xrRender_R2_addr<>0 then begin
    jmp_addr:=xrRender_R2_addr+$73e86;
    if not WriteJump(jmp_addr, cardinal(@CHW__CreateDevice_VSync_R1_R2), 7, true) then exit;
    jmp_addr:=xrRender_R2_addr+$73718;
    if not WriteJump(jmp_addr, cardinal(@CHW__Reset_VSync_R1_R2), 10, true) then exit;

  end else if xrRender_R1_addr<>0 then begin
    jmp_addr:=xrRender_R1_addr+$4B6F6;
    if not WriteJump(jmp_addr, cardinal(@CHW__CreateDevice_VSync_R1_R2), 7, true) then exit;
    jmp_addr:=xrRender_R1_addr+$4AF88;
    if not WriteJump(jmp_addr, cardinal(@CHW__Reset_VSync_R1_R2), 10, true) then exit;
  end;

  result:=true;
end;


end.
