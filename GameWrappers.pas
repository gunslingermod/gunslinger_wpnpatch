unit GameWrappers;



interface
  function Init:boolean;
  function str_container_dock(str:PChar):pointer; stdcall;
  procedure unload_magazine(wpn:pointer);stdcall;
  function game_ini_read_string_by_object_string(section:pointer; key:PChar):PChar;stdcall;
  function game_ini_read_string(section:PChar; key:PChar):PChar;stdcall;
  function get_server_object_by_id(id:cardinal):pointer;stdcall;
  function game_ini_line_exist(section:PChar; key:PChar):boolean;stdcall;
  function game_ini_r_single(section:PChar; key:PChar):single;stdcall;
  function game_ini_r_bool(section:PChar; key:PChar):boolean;stdcall;
  function GetNextSubStr(var data:string; var buf:string; separator:char=char($00)):boolean;
  procedure Log(text:string; IsError:boolean = false);stdcall;
  function Is16x9():boolean;stdcall;
  function alife():pointer;stdcall;
  function alife_create(section:PChar; pos:pointer; lvid:cardinal; gvid:cardinal):pointer;stdcall;
  function game_object_GetScriptGameObject(obj:pointer):pointer;stdcall;


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
  cweaponmagazined_unload_mag:cardinal;

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
  cweaponmagazined_unload_mag:=xrGame_addr+$2CF660;
  is16x9_addr:=xrGame_addr+$43c830;
  alife_ptr:=xrGame_addr+$97780;
  alife_create_ptr:=xrGame_addr+$96eb0;
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

procedure unload_magazine(wpn:pointer);stdcall;
begin
  asm
    pushad
    pushfd

    push 01
    mov ecx, wpn
    call cweaponmagazined_unload_mag

    popfd
    popad
  end;
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
end.
