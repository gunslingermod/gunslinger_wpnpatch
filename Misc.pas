unit Misc;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface
uses MatVectors, windows, xr_strings, BaseGameData, vector;
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


type CSE_ALifeInventoryItem = packed record
  vftable:pointer;
  m_fCondition:single;
  //offset: 0x8
  m_fMass:single;
  m_dwCost:cardinal;
  m_iHealthValue:integer;
  m_iFoodValue:integer;
  m_fDeteriorationValue:single;
  m_self:pointer {CSE_ALifeObject};
  m_last_update_time:cardinal;
  //offset: 0x24
  m_upgrades:xr_vector; {shared_str}

  //to be continued...  
end;

type pCSE_ALifeInventoryItem = ^CSE_ALifeInventoryItem;

type xr_list_entry_base = packed record
  _Next:pointer; //really xr_list_entry_base or child
  _Prev:pointer; //really xr_list_entry_base or child
  //Next should be item of template type T. Use derived records for it emulation.
end;

NET_Buffer = packed record
  data: array[0..16383] of Byte;
  count:cardinal;
end;
pNET_Buffer=^NET_Buffer;

NET_Packet = packed record
  inistream:pointer;         //0x0
  B:NET_Buffer;              //0x4
  r_pos:cardinal;            //0x4008
  timeReceive:cardinal;      //0x400C
  w_allow:boolean;           //0x4010
  _unused1:byte;
  _unused2:word;    
end;
pNET_Packet = ^NET_Packet;

pxr_list_entry_base = ^xr_list_entry_base;

const
  M_EVENT:word = 8;
  GE_HIT:word = 5;
  GEG_PLAYER_ITEM2RUCK:word = 40;

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
function GetDeviceWidth():cardinal; stdcall;
function GetDeviceHeight():cardinal; stdcall;

procedure DrawSphere(parent: pFMatrix4x4; center:pFVector3; radius:single; clr_s:cardinal; clr_w:cardinal; bSolid:boolean; bWire:boolean); stdcall;

function IsMainMenuActive():boolean; stdcall;

procedure ClearNetPacket(packet:pNET_Packet); stdcall;
procedure WriteToPacket(packet:pNET_Packet; data:pointer; bytes_count:cardinal); stdcall;
procedure SendNetPacket(packet:pNET_Packet); stdcall;

procedure ReadFromReader(r:pIReader; buf:pointer; bytes_count:cardinal); stdcall;
function ReaderLength(r:pIReader):cardinal; stdcall;
function ReaderElapsed(r:pIReader):cardinal; stdcall;
procedure IWriter__w_u32(this:pointer; value:cardinal); stdcall;
procedure IWriter__w_stringZ(this:pointer; value:PAnsiChar); stdcall;

function CastHudItemToCObject(wpn:pointer):pointer; stdcall;
function GetCObjectID(CObject:pointer):word; stdcall;
function GetCObjectXForm(CObject:pointer):pFMatrix4x4; stdcall;
function GetCObjectVisual(CObject:pointer):pointer; stdcall;
function GetCObjectSection(CObject:pointer):pshared_str; stdcall;
function GetCObjectUpdateFrame(CObject:pointer):cardinal; stdcall;
procedure CObject__processing_activate(o:pointer); stdcall;
procedure CObject__processing_deactivate(o:pointer); stdcall;

function get_time_hours():cardinal; stdcall;
function get_time_minutes():cardinal; stdcall;
function get_split_time(years:pcardinal; months:pcardinal; days:pcardinal; hours:pcardinal; minutes:pcardinal; seconds:pcardinal; milliseconds:pcardinal):boolean; stdcall;

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

function IsObjectSeePoint(CObject:pointer; point:FVector3; unconditional_vision_dist:single; object_y_correction_value:single; can_backsee:boolean):boolean; stdcall;
procedure DropItemAndTeleport(CObject:pointer; pos:pFVector3); stdcall;

function IsHardUpdates():boolean; stdcall;

function GetHudNearClipPtr():psingle; stdcall;
function GetNegHudNearClipPtr():psingle; stdcall;
procedure get_bone_position(obj:pointer; bone_name:pAnsiChar; res:pFVector3); stdcall;

type MouseCoord = TPoint;
function GetSysMousePoint():MouseCoord;
procedure SetSysMousePoint(c:MouseCoord);

procedure CSE_ALifeInventoryItem__add_upgrade(itm:pCSE_ALifeInventoryItem; up:pshared_str); stdcall;
procedure CSE_ALifeInventoryItem__clone_upgrades(itm_to:pCSE_ALifeInventoryItem; itm_from:pCSE_ALifeInventoryItem); stdcall;

implementation
uses ActorUtils, gunsl_config, Math, HudItemUtils, dynamic_caster, sysutils, raypick, level, LensDoubleRender, throwable;
var
  cscriptgameobject_restoreweaponimmediatly_addr:pointer;
  previous_electronics_problems_counter:single;
  current_electronics_problems_counter:single;
  target_electronics_problems_counter:single;
  last_problems_update_was_decrease:boolean;

  get_addons_state_ptr:pointer;
  set_addons_state_ptr:pointer;
  set_scope_idx_ptr:pointer;

  clone_upgrades_ptr:pointer;

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
begin
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
  ChangeSlotsBlockStatus(false);
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
begin
asm
  mov eax, xrEngine_addr
  mov eax, [eax+$92EF0]
  mov @result, eax
end;
end;

procedure DecDevicedwFrame(); stdcall;
asm
  push eax
  mov eax, xrEngine_addr
  dec [eax+$92EF0]
  pop eax
end;

function IsMainMenuActive():boolean; stdcall;
begin
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
end;

function GetDeviceView():pFMatrix4x4; stdcall;
begin
asm
  mov eax, xrEngine_addr
  lea eax, [eax+$92ED8+$60]
  mov @result, eax
end;
end;

function GetDeviceProjection():pFMatrix4x4; stdcall;
begin
asm
  mov eax, xrEngine_addr
  lea eax, [eax+$92ED8+$A0]
  mov @result, eax
end;
end;

function GetDeviceFullTransform():pFMatrix4x4; stdcall;
begin
asm
  mov eax, xrEngine_addr
  lea eax, [eax+$92ED8+$E0]
  mov @result, eax
end;
end;

//-----------------------------------------------------------------------------------------------------------
procedure ClearNetPacket(packet:pNET_Packet); stdcall;
begin
  packet^.inistream:=nil;
  packet^.B.count:=0;
  packet^.r_pos:=0;
  packet^.timeReceive:=0;
  packet^.w_allow:=true;
end;

procedure WriteToPacket(packet:pNET_Packet; data:pointer; bytes_count:cardinal); stdcall;
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

procedure SendNetPacket(packet:pNET_Packet); stdcall;
asm
  pushad
  call GetLevel
  push 0
  push 8
  push packet
  mov edx,[eax+$40110]
  mov edx,[edx+$10]
  lea ecx,[eax+$40110]
  call edx
  popad
end;

procedure ReadFromReader(r:pIReader; buf:pointer; bytes_count:cardinal); stdcall;
asm
  pushad
    mov eax, xrgame_addr
    mov eax, [eax+$5127D4]

    push bytes_count
    push buf

    mov ecx, r
    call eax;
  popad
end;

function ReaderLength(r:pIReader):cardinal; stdcall;
asm
  pushad
    mov eax, xrgame_addr
    mov eax, [eax+$512970]

    mov ecx, r
    call eax
    mov @result, eax
  popad
end;

function ReaderElapsed(r:pIReader):cardinal; stdcall;
asm
  push ecx
  mov ecx, r
  mov eax, [ecx+$10]
  sub eax, [ecx+$c]
  mov @result, eax
  pop ecx
end;

procedure IWriter__w_u32(this:pointer; value:cardinal); stdcall;
asm
  pushad
  push value
  mov ecx, this
  mov eax, xrgame_addr
  add eax, $5129e8   //IWriter::w_u32
  call [eax]
  popad
end;

procedure IWriter__w_stringZ(this:pointer; value:PAnsiChar); stdcall;
asm
  pushad
  push value
  mov ecx, this
  mov eax, xrgame_addr
  add eax, $5128b4   //IWriter::w_stringZ
  call [eax]
  popad
end;

function GetDeviceTimeDelta():single; stdcall;
begin
asm
  mov eax, xrEngine_addr
  mov eax, [eax+$92ED8+$1C]
  mov @result, eax
end;
end;

function GetDeviceWidth():cardinal; stdcall;
begin
asm
  mov eax, xrEngine_addr
  mov eax, [eax+$92ED8+$04]
  mov @result, eax
end;
end;

function GetDeviceHeight():cardinal; stdcall;
begin
asm
  mov eax, xrEngine_addr
  mov eax, [eax+$92ED8+$08]
  mov @result, eax
end;
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

function GetCObjectSection(CObject:pointer):pshared_str; stdcall;
asm
  mov eax, [CObject]
  lea eax, [eax+$ac]
  mov @result, eax
end;


function GetCObjectUpdateFrame(CObject:pointer):cardinal; stdcall;
asm
  mov eax, [CObject]
  mov eax, [eax+$FC]
  mov @result, eax
end;

function CastHudItemToCObject(wpn:pointer):pointer; stdcall;
asm
  mov eax, [wpn]
  add eax, $e8 //nonportable - cast to CObject
  mov [result], eax
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
begin
asm
  mov eax, xrengine_addr
  add eax, $9032B
  mov al, byte ptr [eax]
  mov @result, al
end;
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


procedure CGameObject_x_axis(v:pFVector3); stdcall;
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

procedure CGameObject_y_axis(v:pFVector3); stdcall;
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

procedure CGameObject_z_axis(v:pFVector3); stdcall;
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

  lea edx, dword ptr [CGameObject_x_axis]
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

  lea edx, dword ptr [CGameObject_y_axis]
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

  lea edx, dword ptr [CGameObject_z_axis]
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

function get_addons_state_adapter():cardinal;
begin
asm
  pushad
  mov eax, [ecx+4] //CScriptGameObject.m_game_object
  mov @result, 0

  push 0
  push RTTI_CWeapon
  push RTTI_CGameObject
  push 0
  push eax
  call dynamic_cast
  test eax, eax
  je @finish

  push eax
  call get_addons_state
  mov @result, eax

  @finish:
  popad
end;
end;

procedure set_addons_state_adapter(state:cardinal); stdcall;
asm
  pushad
  mov eax, [ecx+4] //CScriptGameObject.m_game_object
  mov ebx, state

  push 0
  push RTTI_CWeapon
  push RTTI_CGameObject
  push 0
  push eax
  call dynamic_cast
  test eax, eax
  je @finish

  push ebx
  push eax
  call set_addons_state

  @finish:
  popad
end;

procedure set_scope_idx_adapter(state:cardinal); stdcall;
asm
  pushad
  mov eax, [ecx+4] //CScriptGameObject.m_game_object
  mov ebx, state

  push 0
  push RTTI_CWeapon
  push RTTI_CGameObject
  push 0
  push eax
  call dynamic_cast
  test eax, eax
  je @finish

  push ebx
  push eax
  call SetCurrentScopeType

  @finish:
  popad
end;

procedure script_register_game_object1_patch(); stdcall;
const
  get_addons_state_name:PChar = 'get_addons_state';
  set_addons_state_name:PChar = 'set_addons_state';
  set_scope_idx_name:PChar = 'set_scope_idx';
asm
//---
  mov [esp+$24], bl
  mov edx, [esp+$24]
  push edx
  mov [esp+$1c], bl
  mov ecx, [esp+$1c]
  push ecx
  lea edx, [esp+$1c]
  push edx
  lea ecx, [esp+$28]
  push ecx //esp+$28 - pointer to function, will be filled below
  push get_addons_state_name
  mov ecx, eax
  mov edx, get_addons_state_ptr
  mov [esp+$30], edx // write actual pointer to function
  mov edx, xrgame_addr
  add edx, $1d3990
  call edx
//---
  mov [esp+$24], bl
  mov edx, [esp+$24]
  push edx
  mov [esp+$1c], bl
  mov ecx, [esp+$1c]
  push ecx
  lea edx, [esp+$1c]
  push edx
  lea ecx, [esp+$28]
  push ecx //esp+$28 - pointer to function, will be filled below
  push set_addons_state_name
  mov ecx, eax
  mov edx, set_addons_state_ptr
  mov [esp+$30], edx // write actual pointer to function
  mov edx, xrgame_addr
  add edx, $1d4a10
  call edx
//---
  mov [esp+$24], bl
  mov edx, [esp+$24]
  push edx
  mov [esp+$1c], bl
  mov ecx, [esp+$1c]
  push ecx
  lea edx, [esp+$1c]
  push edx
  lea ecx, [esp+$28]
  push ecx //esp+$28 - pointer to function, will be filled below
  push set_scope_idx_name
  mov ecx, eax
  mov edx, set_scope_idx_ptr
  mov [esp+$30], edx // write actual pointer to function
  mov edx, xrgame_addr
  add edx, $1d4a10
  call edx
//---

  //Original
  mov [esp+$24], bl
  mov edx, [esp+$24]
end;

function IsObjectSeePoint(CObject:pointer; point:FVector3; unconditional_vision_dist:single; object_y_correction_value:single; can_backsee:boolean):boolean; stdcall;
var
  vdiff, object_point, object_dir:FVector3;
  o_dist, o_cos:single;
begin
  result:=false;

  object_point:=FVector3_copyfromengine(GetEntityPosition(CObject));
  object_dir:=FVector3_copyfromengine(GetEntityDirection(CObject));
  object_point.y:=object_point.y+object_y_correction_value; //Коррекция на высоту глаз

  vdiff:=point;
  v_sub(@vdiff, @object_point); //вектор от объекта к проверяемой точке
  o_dist:=v_length(@vdiff); //расстояние от объекта до  проверяемой точки
  v_normalize(@vdiff);

  if not can_backsee then begin
    // Объект не должен видеть то, что у него в "задней полусфере"
    o_cos:=GetAngleCos(@object_dir, @vdiff);
    if o_cos < 0 then exit;
  end;

  if (o_dist<=unconditional_vision_dist) or ((TraceAsView(@object_point, @vdiff, CObject)*1.01) >= o_dist) then begin
    result:=true;
  end;
end;

procedure DropItemAndTeleport(CObject:pointer; pos:pFVector3); stdcall;
asm
  pushad

  push CObject
  call game_object_GetScriptGameObject
  mov ecx, eax

  mov eax, pos
  push [eax+FVector3.z]
  push [eax+FVector3.y]
  push [eax+FVector3.x]
  push ecx

  mov edx, xrgame_addr
  add edx, $1c7520
  call edx

  popad
end;

procedure CObject__processing_activate(o:pointer); stdcall;
asm
  pushad
  mov ecx, o
  mov eax, xrgame_addr
  mov eax, [eax+$512d7c]
  call eax 
  popad
end;

procedure CObject__processing_deactivate(o:pointer); stdcall;
asm
  pushad
  mov ecx, o
  mov eax, xrgame_addr
  mov eax, [eax+$512c44]
  call eax
  popad
end;


function get_time_hours():cardinal; stdcall;
asm
  pushad
  mov eax, xrgame_addr
  add eax, $23e850
  call eax
  mov result, eax
  popad
end;

function get_time_minutes():cardinal; stdcall;
asm
  pushad
  mov eax, xrgame_addr
  add eax, $23e900
  call eax
  mov result, eax
  popad
end;

function get_split_time(years:pcardinal; months:pcardinal; days:pcardinal; hours:pcardinal; minutes:pcardinal; seconds:pcardinal; milliseconds:pcardinal):boolean; stdcall;
asm
  mov result, 0
  pushad
  call GetLevel
  test eax, eax
  je @finish
  mov ecx, eax
  cmp [ecx+$486F8],0 // Level().game
  je @finish

  mov eax, xrgame_addr
  add eax, $232d40 // Level().GetGameTime()
  call eax

  push milliseconds
  push seconds
  push minutes
  push hours
  push days
  push months
  push years
  push edx //part of u64 result from GetGameTime
  push eax //part of u64 result from GetGameTime
  mov eax, xrgame_addr
  add eax, $33bfe0 // split_time
  call eax
  add esp, $24

  mov @result, 1

  @finish:
  popad
end;



function GetSysMousePoint():MouseCoord;
begin
  if not GetCursorPos(result) then begin
    result.x:=0;
    result.Y:=0;
  end;
end;

procedure SetSysMousePoint(c:MouseCoord);
begin
  SetCursorPos(c.X, c.Y);
end;

procedure ProcessPhysicsContact(IPhysicsShellHolder1:pointer; IPhysicsShellHolder2:pointer; vel:single); stdcall;
var
  wpns:array[0..1] of pointer;
  params:weapon_physics_damage_params;
  i:cardinal;
  factor, cond:single;  
begin
  params:=GetWeaponPhysicsDamageParams();
  if vel < params.treshold then exit; 

  wpns[0]:=dynamic_cast(IPhysicsShellHolder1, 0, RTTI_IPhysicsShellHolder, RTTI_CWeapon, false);
  wpns[1]:=dynamic_cast(IPhysicsShellHolder2, 0, RTTI_IPhysicsShellHolder, RTTI_CWeapon, false);

  for i:=0 to length(wpns) do begin
    if wpns[i] = nil then continue;
    factor:= (vel - params.treshold)*params.speed;
    cond:=GetCurrentCondition(wpns[i]);
    if cond > factor then begin
      SetCondition(wpns[i], cond-factor);
    end else begin
      SetCondition(wpns[i], 0);
    end;
  end;
end;

procedure CPHSimpleCharacter__UpdateDynamicDamage_Patch(); stdcall;
asm
  mov esi, [esp+$74] //c_vel

  pushad
  push esi

  mov esi, [ebp+$54]  // c->geom.g1
  mov eax, xrphysics_addr
  add eax, $227f0
  call eax // retrieveRefObject
  push eax

  mov esi, [ebp+$50]  // c->geom.g2
  mov eax, xrphysics_addr
  add eax, $227f0
  call eax // retrieveRefObject
  push eax

  call ProcessPhysicsContact

  popad
  //original
  cmp byte ptr [esp+$74], 0
end;

var
  _update_start_perfcnt:TLargeInteger;
  _update_dist_koef:single;

procedure StartUpdateTimeCount(); stdcall;
begin
  QueryPerformanceCounter(_update_start_perfcnt);
end;

procedure CObjectList__Update_StartCountUpdateTime_Patch(); stdcall;
asm
  add ebx,$198 //original
  pushad
  call StartUpdateTimeCount
  popad
end;

procedure ParseUpdateTimeCounter(); stdcall;
var
  upd_time:single;

  update_end_perfcnt, freq:TLargeInteger;
  min_koef:single;
const
  MIN_UPD_DIST_KOEF_NEG:single=-0.1;
  MIN_UPD_DIST_KOEF:single=0;
  MAX_UPD_DIST_KOEF:single=1;

  UPDATE_DIST_STEP = 0.05;
  UPDATE_TIME_TREASURE:cardinal = 7;
  UPDATE_TIME_TREASURE_NEGATIVE:cardinal = 10;
begin
  QueryPerformanceCounter(update_end_perfcnt);
  QueryPerformanceFrequency(freq);

  upd_time:= (update_end_perfcnt - _update_start_perfcnt) / freq * 1000;
  if upd_time >= UPDATE_TIME_TREASURE then begin
    // Слишком долгий апдейт, постараемся снизить число предметов в нем
    if _update_dist_koef > MIN_UPD_DIST_KOEF then begin
      // Уменьшаем радиус апдейта
      _update_dist_koef:= _update_dist_koef - UPDATE_DIST_STEP;
      if upd_time > UPDATE_TIME_TREASURE_NEGATIVE then begin
        min_koef:=MIN_UPD_DIST_KOEF_NEG;
      end else begin
        min_koef:=MIN_UPD_DIST_KOEF;
      end;

      if _update_dist_koef < min_koef then _update_dist_koef := min_koef;
    end;
  end else begin
    // Время апдейта в норме, пробуем увеличить зону
    if _update_dist_koef < MAX_UPD_DIST_KOEF then begin
      _update_dist_koef:= _update_dist_koef + UPDATE_DIST_STEP;
      if _update_dist_koef > MAX_UPD_DIST_KOEF then _update_dist_koef := MAX_UPD_DIST_KOEF;
    end;
  end;

//  Log('Update time = '+floattostr(upd_time)+', koef = '+floattostr(_update_dist_koef));
end;

procedure CObjectList__Update_UpdateTimeCounter_Patch(); stdcall;
asm
  lea ebx,[esi+$0003FFFC] //original
  pushad
  call ParseUpdateTimeCounter
  popad
end;

function IsHardUpdates():boolean; stdcall;
begin
  result:=(_update_dist_koef<0);
end;

function CanSkipUpdate():boolean; stdcall;
begin
{$ifdef EXPERIMENTAL_UPDRATE}
  result:=IsLensFrameNow() or (IsDynamicUpdrate() and IsHardUpdates() and (GetCurrentFrame() mod 2 = 1));
{$else}
  result:=IsLensFrameNow();
{$endif}
end;

procedure CObjectList__Update_SkipUpdate_Patch(); stdcall;
asm
  pop eax //ret addr

  pushad
  call CanSkipUpdate
  test al, al
  popad
  je @continue
  ret 4;

  @continue:
  //original
  push ebp
  mov ebp, esp
  sub esp, $c

  jmp eax
end;


procedure CorrectSecondaryHitType(zone:pointer; orig_hit_type:cardinal; pNewHitType:pcardinal); stdcall;
var
  s:PAnsiChar;
begin
  pNewHitType^:=orig_hit_type;
  if zone = nil then exit;

  s:=get_string_value(GetCObjectSection(zone));
  pNewHitType^:=game_ini_r_int_def(s, 'secondary_hit_type', orig_hit_type);
end;


procedure CMosquitoBald__UpdateSecondaryHit_SecondaryHitType_Patch(); stdcall;
asm
  push 0 //buffer for hit type
  mov ecx, esp

  pushad
  push ecx
  push [esi+$228] // m_eHitTypeBlowout
  push esi
  call CorrectSecondaryHitType
  popad

  pop ecx // get new hit type from buffer
end;


procedure OnObjectInZone(zone:pointer; obj:pointer); stdcall;
var
  missile:pointer;
const
  REMOVE_DELTA:cardinal=100;
begin
  missile:=dynamic_cast(obj, 0, RTTI_CGameObject, RTTI_CBolt, false);
  if missile<>nil then begin
    if game_ini_r_bool_def(get_string_value(GetCObjectSection(zone)), 'delete_bolts', true) then begin
      if CMissile__GetDestroyTime(missile) > GetGameTickCount()+REMOVE_DELTA then begin
        CMissile__SetDestroyTime(missile, GetGameTickCount()+REMOVE_DELTA);
      end;
    end;
  end;
end;

procedure clone_upgrades_adapter(src:pointer); stdcall;
asm
  pushad
  //ecx - dest (this)
  //cast CSE_ALifeItemWeapon to CSE_ALifeInventoryItem
  add ecx, $e0
  mov eax, src
  add eax, $e0

  push eax
  push ecx
  call CSE_ALifeInventoryItem__clone_upgrades

  popad
end;

procedure CSE_ALifeItemWeapon_exports_Patch(); stdcall;
const
  clone_upgrades_name:PChar = 'clone_upgrades';
asm
  pop edi //ret addr

  //original call
  mov eax, xrgame_addr
  add eax, $3efbd3
  call eax


  //new method
  mov ecx, eax
  mov eax, xrgame_addr
  add eax, $3efbd3

  push 0
  push [clone_upgrades_ptr]
  push clone_upgrades_name
  
  call eax

  jmp edi;
end;

procedure CCustomZone__feel_touch_new_detectbolts_Patch(); stdcall;
asm
  pushad
  push edi //bolt
  push esi // zone
  call OnObjectInZone
  popad

  // original
  mov eax,[esp+$1c]
  cmp eax,ebx
end;

function Init():boolean;stdcall;
var
  jmp_addr, jmp_addr_to:cardinal;
begin
  _update_dist_koef:=1.0;

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


  get_addons_state_ptr:=@get_addons_state_adapter;
  set_addons_state_ptr:=@set_addons_state_adapter;
  set_scope_idx_ptr:=@set_scope_idx_adapter;
  jmp_addr:=xrgame_addr+$1d813d;
  if not WriteJump(jmp_addr, cardinal(@script_register_game_object1_patch), 8, true) then exit;

  // в CPHSimpleCharacter::UpdateDynamicDamage (xrPhysics+22980) добавляем повреждение оружия от ударов
  jmp_addr:=xrphysics_addr+$22b57;
  if not WriteJump(jmp_addr, cardinal(@CPHSimpleCharacter__UpdateDynamicDamage_Patch), 5, true) then exit;

  //в CObjectList::Update перед вызовом CStatTimer::Begin добавляем наш код, стартующий замер времени апдейта
  jmp_addr:=xrEngine_addr+$1b4c5;
  if not WriteJump(jmp_addr, cardinal(@CObjectList__Update_StartCountUpdateTime_Patch), 6, true) then exit;
  //в CObjectList::Update после вызова CStatTimer::End добавляем наш код, обрабатывающий время апдейта
  jmp_addr:=xrEngine_addr+$1b5f5;
  if not WriteJump(jmp_addr, cardinal(@CObjectList__Update_UpdateTimeCounter_Patch), 6, true) then exit;

  // в CObjectList::Update отключаем апдейт для кадра линзы
  jmp_addr:=xrEngine_addr+$1b3c0;
  if not WriteJump(jmp_addr, cardinal(@CObjectList__Update_SkipUpdate_Patch), 6, true) then exit;

  // в CMosquitoBald::UpdateSecondaryHit добавляем возможность задавать тип "вторичного" урона
  jmp_addr:=xrGame_addr+$30ed2d;
  if not WriteJump(jmp_addr, cardinal(@CMosquitoBald__UpdateSecondaryHit_SecondaryHitType_Patch), 6, true) then exit;

  // в CCustomZone::feel_touch_new удаляем болты при воспроизведении партикла
  jmp_addr:=xrGame_addr+$30c01b;
  if not WriteJump(jmp_addr, cardinal(@CCustomZone__feel_touch_new_detectbolts_Patch), 6, true) then exit;

  // экспорт метода CSE_ALifeItemWeapon::clone_upgrades на основе CSE_ALifeItemWeapon::clone_addons
  clone_upgrades_ptr:=@clone_upgrades_adapter;
  jmp_addr:=xrGame_addr+$3f0e35;
  if not WriteJump(jmp_addr, cardinal(@CSE_ALifeItemWeapon_exports_Patch), 5, true) then exit;

  // отключаем кеширование шейдеров в CRender::shader_compile
  if not IsShadersCacheNeeded() then begin
    // меняем test eax, eax на xor eax, eax после FS.exist(file_name), заставляя игру думать, что файл не кеширован
    if xrRender_R1_addr<>0 then begin
      nop_code(xrRender_R1_addr+$6999, 1, chr($31));
    end else if xrRender_R2_addr<>0 then begin
      nop_code(xrRender_R2_addr+$7fb6, 1, chr($31));
    end else if xrRender_R3_addr<>0 then begin
      nop_code(xrRender_R3_addr+$18af6, 1, chr($31));
    end else if xrRender_R4_addr<>0 then begin
      nop_code(xrRender_R4_addr+$18ad6, 1, chr($31));
    end;

    //отключаем попытки записать скомпилированный шейдер в кеш
    if xrRender_R1_addr<>0 then begin
      nop_code(xrRender_R1_addr+$6ac6, $CB);
    end else if xrRender_R2_addr<>0 then begin
      nop_code(xrRender_R2_addr+$811e, $CC);
    end else if xrRender_R3_addr<>0 then begin
      nop_code(xrRender_R3_addr+$18c1f, $CC);
    end else if xrRender_R4_addr<>0 then begin
      nop_code(xrRender_R4_addr+$18c1c, $CA);
      nop_code(xrRender_R4_addr+$18c1c, 1, chr($58));
    end;
  end;

  result:=true;
end;


var
  g_hudNearClip:single;
  g_negHudNearClip:single;

function GetHudNearClipPtr():psingle; stdcall;
begin
  g_hudNearClip:=0.02;
  result:=@g_hudNearClip;
end;

function GetNegHudNearClipPtr():psingle; stdcall;
begin
  g_negHudNearClip:=-0.02;
  result:=@g_negHudNearClip;
end;

procedure get_bone_position(obj:pointer; bone_name:pAnsiChar; res:pFVector3); stdcall;
asm
  pushad
    push bone_name
    push obj
    push res
    mov eax, xrgame_addr
    add eax, $cef70
    call eax
    add esp, $c
  popad
end;

procedure CSE_ALifeInventoryItem__add_upgrade(itm:pCSE_ALifeInventoryItem; up:pshared_str); stdcall;
asm
  pushad
    push up
    mov ecx, itm
    mov eax, xrgame_addr
    add eax, $3e1f90
    call eax
  popad
end;

procedure CSE_ALifeInventoryItem__clone_upgrades(itm_to:pCSE_ALifeInventoryItem; itm_from:pCSE_ALifeInventoryItem); stdcall;
var
  cnt, i:integer;
  up:pshared_str;
begin
  cnt:=items_count_in_vector(@itm_from.m_upgrades, sizeof(shared_str));

  for i:=0 to cnt-1 do begin
    up:=get_item_from_vector(@itm_from.m_upgrades, i, sizeof(shared_str));
    CSE_ALifeInventoryItem__add_upgrade(itm_to, up);
  end;
end;

// CInventory::Update - xrgame.dll+2a83a0
// CScriptGameObject::buy_supplies - xrgame.dll+1c3df0
// CMosquitoBald::UpdateSecondaryHit - xrgame.dll+30ea90
// CShootingObject::StartShotParticles - xrgame.dll+2bbee0
// CShootingObject::StartFlameParticles - xrgame.dll+2bbdb0


end.
