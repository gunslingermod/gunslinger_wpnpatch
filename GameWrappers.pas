unit GameWrappers;



interface

  type FVector3 = packed record
    x:single;
    y:single;
    z:single;
  end;

  type PFVector3 = ^FVector3;

  function FVector3_copyfromengine(v:pointer):FVector3;stdcall;

  function Init:boolean;
  function str_container_dock(str:PChar):pointer; stdcall;
  procedure virtual_CWeaponMagazined__UnloadMagazine(wpn:pointer);stdcall;
  procedure virtual_CWeaponMagazined__ReloadMagazine(wpn:pointer);stdcall;
  procedure virtual_CWeaponShotgun__AddCartridge(wpn:pointer; cnt:cardinal);stdcall;
  function  CWeaponShotgun__HaveCartridgeInInventory(wpn:pointer; cnt:cardinal):boolean; stdcall; //должно работать и для остального оружия


  function game_ini_read_string_by_object_string(section:pointer; key:PChar):PChar;stdcall;
  function game_ini_read_string(section:PChar; key:PChar):PChar;stdcall;
  function get_server_object_by_id(id:cardinal):pointer;stdcall;
  function game_ini_line_exist(section:PChar; key:PChar):boolean;stdcall;
  function game_ini_r_single(section:PChar; key:PChar):single;stdcall;
  function game_ini_r_bool(section:PChar; key:PChar):boolean;stdcall;
  function game_ini_r_bool_def(section:PChar; key:PChar; def:boolean):boolean;stdcall;
  function game_ini_r_int_def(section:PChar; key:PChar; def:integer):integer; stdcall;

  function GetNextSubStr(var data:string; var buf:string; separator:char=char($00)):boolean;
  procedure Log(text:string; IsError:boolean = false);stdcall;
  function Is16x9():boolean;stdcall;
  function alife():pointer;stdcall;
  function alife_create(section:PChar; pos:pointer; lvid:cardinal; gvid:cardinal):pointer;stdcall;
  function alife_release(srv_obj:pointer):boolean;stdcall;
  function game_object_GetScriptGameObject(obj:pointer):pointer;stdcall;
{  procedure ShowCustomMessage(message_name:PChar; b:boolean);stdcall; //старое, дублирует функционал UIUtils}
  function translate(text:PChar):PChar;stdcall;
  procedure virtual_CHudItem_PlaySound(CHudItem:pointer; alias:PChar; position_ptr:pointer); stdcall;
  procedure virtual_CHudItem_SwitchState(Weapon:pointer; state:cardinal); stdcall;
  function dxGeomUserData__get_ph_ref_object(dxGeomUserData:pointer):pointer;
  function PHRetrieveGeomUserData(dxGeom:pointer):pointer; stdcall;  

  const
		CHUDState__eIdle:cardinal = 0;
		CHUDState__eShowing:cardinal = 1;
		CHUDState__eHiding:cardinal = 2;
		CHUDState__eHidden:cardinal = 3;
		CHUDState__eBore:cardinal = 4;
		CHUDState__eLastBaseState:cardinal = 4;


implementation
uses BaseGameData, SysUtils, strutils, windows;
var
  //игровые глобальные переменные/объекты
  game_ini_ptr:cardinal;
  str_container_ptr:cardinal;

  //Указатели на игровые функции
  CIniFile_ReadStringByObjectStringPtr:cardinal;
  CIniFile_ReadStringPtr:cardinal;
  CIniFile_line_exist:cardinal;
  CIniFile_r_bool:cardinal;
  str_container_dock_ptr:cardinal;
  log_func_addr:cardinal;
  is16x9_addr:cardinal;

  alife_object_ptr:cardinal;
  alife_ptr:cardinal;
  alife_create_ptr:cardinal;
  alife_release_ptr:cardinal;

  game_object_GetScriptGameObject_ptr:cardinal;

function Init:boolean;
begin
  game_ini_ptr:=xrGame_addr+$5127E8;
  str_container_ptr:=xrGame_addr+$512814;

  //Сразу получим адреса стандартных игровых функций, врапперы для которых написаны выше
  log_func_addr:=xrCore_addr+$158B0;
  CIniFile_ReadStringByObjectStringPtr:=xrCore_addr+$2BE0;
  str_container_dock_ptr:=xrCore_addr+$20690;
  CIniFile_line_exist:=xrCore_addr+$182D0;
  CIniFile_r_bool:=xrCore_addr+$18970;
  CIniFile_ReadStringPtr:=xrCore_addr+$18530;
  alife_object_ptr:=xrGame_addr+$99450;
  is16x9_addr:=xrGame_addr+$43c830;
  alife_ptr:=xrGame_addr+$97780;
  alife_create_ptr:=xrGame_addr+$96eb0;
  alife_release_ptr:=xrGame_addr+$98410;
  game_object_GetScriptGameObject_ptr:= xrGame_addr+$27FD40;


  result:=true;
end;


function GetNextSubStr(var data:string; var buf:string; separator:char=char($00)):boolean;
var p, i:integer;
begin
  p:=0;
  for i:=1 to length(data) do begin
    if data[i]=separator then begin
      p:=i;
      break;
    end;
  end;

  if p>0 then begin
    buf:=leftstr(data, p-1);
    buf:=trim(buf);
    data:=rightstr(data, length(data)-p);
    data:=trim(data);
    result:=true;
  end else begin
    if trim(data)<>'' then begin
      buf:=trim(data);
      data:='';
      result:=true;
    end else result:=false;
  end;
end;


function str_container_dock(str:PChar):pointer; stdcall
begin
  asm
    pushad
    pushfd

    push str
    mov ecx, str_container_ptr
    mov ecx, [ecx]
    mov ecx, [ecx]
    call str_container_dock_ptr
    mov @Result, eax

    popfd
    popad
  end
end;




function game_ini_read_string_by_object_string(section:pointer; key:PChar):PChar;stdcall;

begin
  asm
    pushad
    pushfd

    push key
    push section
    mov ecx, game_ini_ptr
    mov ecx, [ecx]
    mov ecx, [ecx]
    call CIniFile_ReadStringByObjectStringPtr
    mov @result, eax

    popfd
    popad
  end
end;

function game_ini_line_exist(section:PChar; key:PChar):boolean;stdcall;
begin
  asm
    pushad
    pushfd

    push key
    push section
    mov ecx, game_ini_ptr
    mov ecx, [ecx]
    mov ecx, [ecx]
    call CIniFile_line_exist
    mov @result, al

    popfd
    popad
  end
end;

function game_ini_r_bool(section:PChar; key:PChar):boolean;stdcall;
begin
  asm
    pushad
    pushfd

    push key
    push section
    mov ecx, game_ini_ptr
    mov ecx, [ecx]
    mov ecx, [ecx]
    call CIniFile_r_bool
    mov @result, al

    popfd
    popad
  end
end;

function get_server_object_by_id(id:cardinal):pointer;stdcall;
//!!Changes ECX!!
begin
  asm
    pushad
    pushfd

    mov ecx, xrGame_addr
    mov ecx, [ecx+$64DA98]
    mov ecx, [ecx+$14]

    push id
    push ecx
    call alife_object_ptr
    add esp,8
    mov @Result, eax

    popfd
    popad
  end
end;

procedure virtual_CWeaponMagazined__UnloadMagazine(wpn:pointer);stdcall;
begin
  asm
    pushad
    pushfd

    push 01
    mov ecx, wpn

    mov edx, [ecx]
    mov edx, [edx+$20c]
    call edx

    popfd
    popad
  end;
end;

procedure virtual_CWeaponMagazined__ReloadMagazine(wpn:pointer);stdcall;
asm
    pushad
    pushfd

    mov ecx, wpn

    mov edx, [ecx]
    mov edx, [edx+$1FC]
    call edx

    popfd
    popad
end;

procedure virtual_CWeaponShotgun__AddCartridge(wpn:pointer; cnt:cardinal);stdcall;
asm
    pushad
    pushfd


    push cnt
    mov ecx, wpn

    mov edx, [ecx]
    mov edx, [edx+$248]
    call edx

    popfd
    popad
end;

function game_ini_r_single(section:PChar; key:PChar):single;stdcall;
begin
  result:= strtofloatdef(game_ini_read_string(section, key), 0);
end;

function game_ini_read_string(section:PChar; key:PChar):PChar;stdcall;
begin
  asm
    pushad
    pushfd

    push key
    push section
    mov ecx, game_ini_ptr
    mov ecx, [ecx]
    mov ecx, [ecx]
    call CIniFile_ReadStringPtr
    mov @result, eax

    popfd
    popad
  end
end;

procedure Log(text:string; IsError:boolean = false);stdcall;
var
  paramText:PChar;
begin
  try
    text:='GNSLWP: '+text;
    if IsError then
      text:= '! ' + text
    else
      text:= '~ ' + text;

    paramText:=PChar(text);
    asm
      pushad
      pushf

      push text
      call [log_func_addr]
      add esp, 4

      popf
      popad
    end;
  except
  end;
end;


function Is16x9():boolean;stdcall;
{var
  x,y:smallint;
  wsize:cardinal;
  delta:real;   }
begin
{   ReadProcessMemory(hndl, ptr($492edc), @x, SizeOf(x), wSize);
   ReadProcessMemory(hndl, ptr($492ee0), @y, SizeOf(y), wSize);
   delta:=x/y;
   if abs(delta-4/3)<abs(delta-16/9) then result:=false else result:=true;}
   asm
    pushad
    pushfd

    call is16x9_addr
    mov @result, al

    popfd
    popad
   end;
end;

function alife():pointer;
asm
  pushad
  pushfd

  call alife_ptr
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
    call alife_create_ptr
    add esp, $14
    mov @result, eax
    @finish:
  popad
end;

function game_object_GetScriptGameObject(obj:pointer):pointer;stdcall;
asm
  pushad
    mov ecx, obj
    call game_object_GetScriptGameObject_ptr
    mov @result, eax
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
    call alife_release_ptr
    add esp, $C
    mov @result, al

    @finish:
  popad
end;

{procedure ShowCustomMessage(message_name:PChar; b:boolean);stdcall;
asm
  pushad
    cmp message_name, 0
    je @finish

    mov eax, xrgame_addr
    add eax, $4AFD90
    call eax
    cmp eax, 0
    je @finish

    mov ecx, eax
    movzx eax, b
    push eax
    push message_name

    mov eax, xrgame_addr
    add eax, $4B1760
    call eax

    @finish:
  popad
end;   }


function translate(text:PChar):PChar;stdcall;
asm
  pushad
    mov eax, xrgame_addr
    add eax, $23d4f0
    push text
    call eax
    mov @result, eax
    add esp, 4
  popad
end;


procedure virtual_CHudItem_PlaySound(CHudItem:pointer; alias:PChar; position_ptr:pointer); stdcall;
asm
  pushad

  mov ecx, CHudItem

  push position_ptr
  push alias


  mov edx, [ecx]
  mov edx, [edx+$30]
  call edx

  popad
end;


procedure virtual_CHudItem_SwitchState(Weapon:pointer; state:cardinal); stdcall;
//все наследники имеют CHudItem по смещению 2e0, так что делаем сразу на всех.
asm
  pushad

  mov ecx, Weapon
  add ecx, $2e0

  push state

  mov edx, [ecx]
  mov edx, [edx]
  call edx

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

function FVector3_copyfromengine(v:pointer):FVector3;stdcall;
var
  a,b,c:single;
begin
  asm
    push eax
    push ebx
      mov eax, v

      mov ebx, [eax]
      mov a, ebx

      mov ebx, [eax+4]
      mov b, ebx

      mov ebx, [eax+8]
      mov c, ebx
    pop ebx
    pop eax
  end;
  result.x:=a;
  result.y:=b;
  result.z:=c;
end;


function game_ini_r_bool_def(section:PChar; key:PChar; def:boolean):boolean;stdcall;
begin
  if game_ini_line_exist(section, key) then
    result:=game_ini_r_bool(section, key)
  else
    result:=def;
end;

function game_ini_r_int_def(section:PChar; key:PChar; def:integer):integer; stdcall;
begin
  if game_ini_line_exist(section, key) then
    result:=strtointdef(game_ini_read_string(section, key), def)
  else
    result:=def;
end;


function  CWeaponShotgun__HaveCartridgeInInventory(wpn:pointer; cnt:cardinal):boolean; stdcall; //должно работать и для остального оружия
asm
  pushad

    push cnt
    mov ecx, wpn

    mov eax, xrgame_addr
    add eax, $2de7b0
    call eax
    mov @result, al
  popad
end;
end.
