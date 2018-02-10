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

type xr_list_entry_base = packed record
  _Next:pointer; //really xr_list_entry_base or child
  _Prev:pointer; //really xr_list_entry_base or child
  //Next should be item of template type T. Use derived records for it emulation.
end;

pxr_list_entry_base = ^xr_list_entry_base;

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

procedure DrawSphere(parent: pFMatrix4x4; center:pFVector3; radius:single; clr_s:cardinal; clr_w:cardinal; bSolid:boolean; bWire:boolean); stdcall;

function IsMainMenuActive():boolean; stdcall;

procedure WriteToPacket(packet:pointer; data:pointer; bytes_count:cardinal); stdcall;
procedure ReadFromReader(IReader:pointer; buf:pointer; bytes_count:cardinal); stdcall;

function GetCObjectID(CObject:pointer):word; stdcall;
function GetCObjectXForm(CObject:pointer):pFMatrix4x4; stdcall;
function GetCObjectVisual(CObject:pointer):pointer; stdcall;

function GetAngleByLegs(x,y:single):single;

function IsInputExclusive:boolean; stdcall;

procedure set_name_replace(swpn:pointer; name:PChar); stdcall;

function is_object_has_health(obj:pointer):boolean;
function is_visible_by_thermovisor(cobject:pointer):boolean; stdcall;

procedure ResetElectronicsProblems(); stdcall;
procedure ResetElectronicsProblems_Full(); stdcall;
function ElectronicsProblemsDec():boolean; stdcall;
function ElectronicsProblemsInc():boolean; stdcall;
function TargetElectronicsProblemsCnt():single; stdcall;
function CurrentElectronicsProblemsCnt():single; stdcall;
function PreviousElectronicsProblemsCnt():single; stdcall;
function ElectronicsProblemsImmediateApply():boolean; stdcall;
procedure UpdateElectronicsProblemsCnt(dt:cardinal); stdcall;

function IsElectronicsProblemsDecreasing():boolean; stdcall;

implementation
uses BaseGameData, ActorUtils, gunsl_config, Math, HudItemUtils, dynamic_caster, sysutils;
var
  cscriptgameobject_restoreweaponimmediatly_addr:pointer;
  previous_electronics_problems_counter:single;
  current_electronics_problems_counter:single;
  target_electronics_problems_counter:single;
  last_problems_update_was_decrease:boolean;

procedure ResetElectronicsProblems(); stdcall;
begin
  target_electronics_problems_counter:=0;
end;

procedure ResetElectronicsProblems_Full(); stdcall;
begin
  ResetElectronicsProblems();
  current_electronics_problems_counter:=0;
  previous_electronics_problems_counter:=0;
  last_problems_update_was_decrease:=false;
end;

function PreviousElectronicsProblemsCnt():single; stdcall;
begin
  result:=previous_electronics_problems_counter;
end;

function ElectronicsProblemsImmediateApply():boolean; stdcall;
begin
  current_electronics_problems_counter:=target_electronics_problems_counter;
  result:=true;
end;

function ElectronicsProblemsInc():boolean; stdcall;
begin
  target_electronics_problems_counter:=target_electronics_problems_counter+1;
  result:=true;
end;

function TargetElectronicsProblemsCnt():single; stdcall;
begin
  result:=target_electronics_problems_counter;
end;

function CurrentElectronicsProblemsCnt():single; stdcall;
begin
  result:=current_electronics_problems_counter;
end;

function ElectronicsProblemsDec():boolean; stdcall;
begin
  if target_electronics_problems_counter > 0 then begin
    target_electronics_problems_counter:=target_electronics_problems_counter-1;
    result:=true;
  end else begin
    result:=false;
  end;
end;

function IsElectronicsProblemsDecreasing():boolean; stdcall;
begin
  result:=last_problems_update_was_decrease;
end;

procedure UpdateElectronicsProblemsCnt(dt:cardinal); stdcall;
var
  delta, max_delta:single;
begin
  previous_electronics_problems_counter := current_electronics_problems_counter;
  if target_electronics_problems_counter = current_electronics_problems_counter then begin
    exit;
  end;

  max_delta:= dt/2000;
  delta:=target_electronics_problems_counter-current_electronics_problems_counter;

  if abs(delta) <= abs(max_delta) then begin
    current_electronics_problems_counter:=target_electronics_problems_counter;
  end else begin
    current_electronics_problems_counter:=current_electronics_problems_counter+sign(delta)*max_delta;
    last_problems_update_was_decrease := (delta<0)
  end;
//  Log(floattostr(current_electronics_problems_counter));
end;

procedure set_name_replace(swpn:pointer; name:PChar); stdcall;
asm
  pushad
    mov edx, swpn
    mov edx, [edx]
    mov eax, [edx+$14]
    push name
    push swpn
    call eax
  popad
end;

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

function is_object_has_health(obj:pointer):boolean;
asm
  mov @result, false
  pushad
    push obj
    call game_object_GetScriptGameObject
    cmp eax, 0
    je @finish
    mov ecx, eax
    mov ebx, xrgame_addr
    add ebx, $1EF870
    call ebx
    mov @result, al

    @finish:
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

procedure register_cscriptgameobject_methods();stdcall;
const
  name_restore:PChar='restore_weapon_immediatly';
asm
  //restore_weapon_immediatly
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

  push name_restore
  mov ecx, eax

  mov edx, cscriptgameobject_restoreweaponimmediatly_addr
  mov [esp+$30], edx

  mov edx, xrgame_addr
  add edx, $1D4350
  call edx

  //restore cut
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


procedure CGameObject_x_axis(v:pFVector3); stdcall
asm
  pushad

  mov eax, [ecx+4]
  sub eax, $e8      //nonportable - cast to CWeapon
  push eax
  call GetXFORM

  mov esi, [eax+FMatrix4x4.i.x]
  mov edi, [eax+FMatrix4x4.i.y]
  mov ebx, [eax+FMatrix4x4.i.z]

  mov edx, v  
  mov [edx+FVector3.x], esi
  mov [edx+FVector3.y], edi
  mov [edx+FVector3.z], ebx

  popad

  mov eax, v
end;

procedure CGameObject_y_axis(v:pFVector3); stdcall
asm
  pushad

  mov eax, [ecx+4]
  sub eax, $e8      //nonportable - cast to CWeapon
  push eax
  call GetXFORM

  mov esi, [eax+FMatrix4x4.j.x]
  mov edi, [eax+FMatrix4x4.j.y]
  mov ebx, [eax+FMatrix4x4.j.z]

  mov edx, v
  mov [edx+FVector3.x], esi
  mov [edx+FVector3.y], edi
  mov [edx+FVector3.z], ebx

  popad

  mov eax, v
end;

procedure CGameObject_z_axis(v:pFVector3); stdcall
asm
  pushad

  mov eax, [ecx+4]
  sub eax, $e8      //nonportable - cast to CWeapon
  push eax
  call GetXFORM

  mov esi, [eax+FMatrix4x4.k.x]
  mov edi, [eax+FMatrix4x4.k.y]
  mov ebx, [eax+FMatrix4x4.k.z]

  mov edx, v
  mov [edx+FVector3.x], esi
  mov [edx+FVector3.y], edi
  mov [edx+FVector3.z], ebx

  popad

  mov eax, v
end;

procedure CScriptGameObject_ExportAxisVectors; stdcall;
const
  get_x:PChar='get_x_axis';
  get_y:PChar='get_y_axis';
  get_z:PChar='get_z_axis';    
asm
  mov [esp+$24], 0
  mov edx, [esp+$24]
  push edx

  mov [esp+$1C], 0
  mov ecx, [esp+$1C]
  push ecx

  lea edx, [esp+$1C]
  push edx

  lea ecx, [esp+$28]
  push ecx
  push get_x
  mov ecx, eax

  lea edx, dword ptr CGameObject_x_axis
  mov [esp+$30], edx

  mov edx, xrgame_addr
  add edx, $1D6D20
  call edx


  mov [esp+$24], 0
  mov edx, [esp+$24]
  push edx

  mov [esp+$1C], 0
  mov ecx, [esp+$1C]
  push ecx

  lea edx, [esp+$1C]
  push edx

  lea ecx, [esp+$28]
  push ecx
  push get_y
  mov ecx, eax

  lea edx, dword ptr CGameObject_y_axis
  mov [esp+$30], edx

  mov edx, xrgame_addr
  add edx, $1D6D20
  call edx

  mov [esp+$24], 0
  mov edx, [esp+$24]
  push edx

  mov [esp+$1C], 0
  mov ecx, [esp+$1C]
  push ecx

  lea edx, [esp+$1C]
  push edx

  lea ecx, [esp+$28]
  push ecx
  push get_z
  mov ecx, eax

  lea edx, dword ptr CGameObject_z_axis
  mov [esp+$30], edx

  mov edx, xrgame_addr
  add edx, $1D6D20
  call edx

  mov [esp+$24], 0
  mov edx, [esp+$20]
end;

function is_visible_by_thermovisor(cobject:pointer):boolean; stdcall;
begin
  if dynamic_cast(cobject, 0, RTTI_CObject, RTTI_CAI_Crow, false)<>nil then begin
    result:=true;
    exit;
  end;

  if dynamic_cast(cobject, 0, RTTI_CObject, RTTI_CAI_Bloodsucker, false)<>nil then begin
    result:=false;
    exit;
  end;

  result := dynamic_cast(cobject, 0, RTTI_CObject, RTTI_CEntityAlive, false)<>nil;
end;

procedure xrMemory__mem_free(mem_ptr:pointer); stdcall;
asm
   pushad
   mov eax, xrEngine_addr
   mov ecx, [eax+$6f538]
   mov edx, [eax+$6f53c]
   push mem_ptr
   call edx
   popad
end;

procedure list_entry_delete(entry:pxr_list_entry_base); stdcall;
var
  next, prev:pxr_list_entry_base;
begin
  next := entry._Next;
  prev := entry._Prev;

  next._Prev := prev;
  prev._Next := next;

  xrMemory__mem_free(entry);
end;

procedure CCameraManager__UpdateCamEffectors_removefinishedeff_Patch(); stdcall;
asm
  cmp al, 0
  jne @next_eff

  pushad
  mov ecx, [edi+04]
  mov edx, [ecx+08] //(CEffectorCam*) (*rit).value
  push edx

  mov eax, xrEngine_addr
  add eax, $2c650
  mov ecx, esi //mov ecx, CCameraManager* this
  call eax//CCameraManager::OnEffectorReleased
  popad

  pushad
  push [edi+04]
  call list_entry_delete
  popad

  jmp @finish

@next_eff:
  mov edi, [edi+4] //rit++

@finish:
  cmp edi, [ebx]
  ret
end;


{ Use for DX8\DX9. Sample code:
  m.i.x := 0;
  m.i.y := 0;
  m.i.z := 0;
  m.i.w := 0;

  m.j := m.i;
  m.k := m.i;
  m.c := m.i;

  m.i.x := 1;
  m.j.y := 1;
  m.k.z := 1;
  m.c.w := 1;
  DrawSphere(@m, pos, 1, $FFFFFFFF, $FFFFFFFF, true, false); }
procedure DrawSphere(parent: pFMatrix4x4; center:pFVector3; radius:single; clr_s:cardinal; clr_w:cardinal; bSolid:boolean; bWire:boolean); stdcall;
asm
  pushad
    mov eax, [xrAPI_addr]
    mov ecx, [eax+$3350] //DU
    mov eax, [ecx] //vtable
    mov eax, [eax+$80] //CDrawUtilities::DrawSphere

    movzx edx, bWire
    push edx
    movzx edx, bSolid
    push edx
    push clr_w
    push clr_s
    push radius
    push center
    push parent
    push ecx
    call eax
  popad
end;

function Init():boolean;stdcall;
var
  jmp_addr, jmp_addr_to:cardinal;
begin
  //затычка от вылета mp_ranks
  result:=false;
  jmp_addr:=xrGame_addr+$4CCD0E;
  if not WriteJump(jmp_addr, cardinal(@get_rank_Patch), 47, true) then exit;

  //экспорт функций получения локальных осей CScriptGameObject
  jmp_addr:=xrGame_addr+$1D8D9D;
  if not WriteJump(jmp_addr, cardinal(@CScriptGameObject_ExportAxisVectors), 8, true) then exit;



  //[bug] баг -в CLevel::ClientSend исправляем if (GameID() == eGameIDSingle || OnClient()) на if (GameID() != eGameIDSingle || OnClient()) - thanks to Shoker
  if not nop_code(xrGame_addr+$238D55, 1, CHR($75)) then exit;

  //[bug] баг - забытый дефайн на DX11 в void dxFontRender::OnRender(CGameFont &owner), строка 120, приводит к мылу
  if xrRender_R4_addr<>0 then begin
    if not nop_code(xrRender_R4_addr+$C7345, 4) then exit;
    if not nop_code(xrRender_R4_addr+$C735F, 4) then exit;    
  end;

  jmp_addr:=xrGame_addr+$1ECFF6;
  cscriptgameobject_restoreweaponimmediatly_addr := @CScriptgameobject__restoreweaponimmediatly;
  if not WriteJump(jmp_addr, cardinal(@register_cscriptgameobject_methods), 8, true) then exit;


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

  //[bug] Баг с некорректным поведением камеры - когда эффектор заканчивает работу, он удаляется в CCameraManager::ProcessCameraEffector
  //Но цикл в CCameraManager::UpdateCamEffectors ничего об этом не знает, и смещает reverse iterator, пропуская обработку одного эффектора
  //для фикса: 1) заставим CCameraManager::ProcessCameraEffector возвращать true, когда удалять эффектор не надо, и false в противном случае
  nop_code(xrEngine_addr+$2cb4d, 2);
  // 2) Вырежем удаление эффектора из CCameraManager::ProcessCameraEffector
  jmp_addr := xrEngine_addr+$2cb52;
  jmp_addr_to := xrEngine_addr+$2cbc8;
  if not WriteJump(jmp_addr, jmp_addr_to, 5, false) then exit;
  // 3) Добавим удаление эффектора в CCameraManager::UpdateCamEffectors когда ProcessCameraEffector возвращает false
  jmp_addr:=xrEngine_addr+$2cc10;
  if not WriteJump(jmp_addr, cardinal(@CCameraManager__UpdateCamEffectors_removefinishedeff_Patch), 5, true) then exit;

  result:=true;
end;


end.
