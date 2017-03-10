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


implementation
uses BaseGameData, ActorUtils;
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

function Init():boolean;stdcall;
var
  jmp_addr:cardinal;
begin
  //затычка от вылета mp_ranks
  result:=false;
  jmp_addr:=xrGame_addr+$4CCD0E;
  if not WriteJump(jmp_addr, cardinal(@get_rank_Patch), 47, true) then exit;

  jmp_addr:=xrGame_addr+$1ECFF6;
  cscriptgameobject_restoreweaponimmediatly_addr := @CScriptgameobject__restoreweaponimmediatly;
  if not WriteJump(jmp_addr, cardinal(@register_cscriptgameobject_restoreweaponimmediatly), 8, true) then exit;
  result:=true;
end;
end.
