unit Misc;

interface
//всячина, которую не особо понятно, в какие модули спихнуть

function Init():boolean;stdcall;
function dxGeomUserData__get_ph_ref_object(dxGeomUserData:pointer):pointer;
function PHRetrieveGeomUserData(dxGeom:pointer):pointer; stdcall;
function game_object_GetScriptGameObject(obj:pointer):pointer;stdcall;
function get_server_object_by_id(id:cardinal):pointer;stdcall;
function alife():pointer;stdcall;
function alife_create(section:PChar; pos:pointer; lvid:cardinal; gvid:cardinal):pointer;stdcall;
function alife_release(srv_obj:pointer):boolean;stdcall;


implementation

uses BaseGameData;

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

function alife_create(section:PChar; pos:pointer; lvid:cardinal; gvid:cardinal):pointer; stdcall;
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

function Init():boolean;stdcall;
var
  jmp_addr:cardinal;
begin
  //затычка от вылета mp_ranks
  result:=false;
  jmp_addr:=xrGame_addr+$4CCD0E;
  if not WriteJump(jmp_addr, cardinal(@get_rank_Patch), 47, true) then exit;
  result:=true;
end;
end.
