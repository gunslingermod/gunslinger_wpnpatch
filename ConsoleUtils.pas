unit ConsoleUtils;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

type IConsole_Command_vftable = packed record
  _destructor:pointer;
  Execute:pointer;
  Status:pointer;
  Info:pointer;
  Save:pointer;
  fill_tips:pointer;
  add_to_LRU:pointer;
end;

type pIConsole_Command_vftable = ^IConsole_Command_vftable;

type IConsole_Command = packed record
  vftable:pIConsole_Command_vftable;
  cName:PChar;
  bEnabled:byte;
  bLowerCaseArgs:byte;
  bEmptyArgsHandled:byte;
  _reserved:byte;
  m_LRU_start:cardinal;
  m_LRU_end:cardinal;
  m_LRU_memend:cardinal;
end;

type pIConsole_Command = ^IConsole_Command;

type CCC_Mask = packed record
  base:IConsole_Command;
  value:pcardinal;
  mask:cardinal;  
end;
type pCCC_Mask = ^CCC_Mask;

type CCC_Integer = packed record
  base:IConsole_Command;
  value:pinteger;
  min:integer;
  max:integer;
end;
type pCCC_Integer= ^CCC_Integer;

type CCC_Float = packed record
  base:IConsole_Command;
  value:psingle;
  min:single;
  max:single;
end;
type pCCC_Float= ^CCC_Float;


procedure CCC_Mask__CCC_Mask(this:pCCC_Mask; name:PChar; value:pCardinal; mask:cardinal);stdcall;
procedure CCC_Integer__CCC_Integer(this:pCCC_Integer; name:PChar; value:pInteger; min:integer; max:integer);stdcall;
procedure CCC_Float__CCC_Float(this:pCCC_Float; name:PChar; value:pSingle; min:single; max:single);stdcall;
procedure CConsole__AddCommand(C:pIConsole_Command); stdcall;
function CConsole__GetCommand(cmd:PAnsiChar):pIConsole_Command; stdcall;

function IsDemoRecord():boolean; stdcall;
function IsConsoleShown():boolean;stdcall;

procedure Console__Execute(cmd:PChar); stdcall;

type ConsoleCommandFixResult = (CONSOLE_FIX_RESULT_SUCCESS, CONSOLE_FIX_RESULT_ALREADY_FIXED, CONSOLE_FIX_RESULT_COMMAND_NOT_FOUND, CONSOLE_FIX_RESULT_ERROR);
function ConsoleCommandFixResultToString(r:ConsoleCommandFixResult):string;
function FixConsoleCommandValue(name:PAnsiChar; value:PAnsiChar):ConsoleCommandFixResult;

type
  ConsoleCommandLimitsSettings = cardinal;
const
  SET_CONSOLE_COMMAND_LIMIT_MIN:ConsoleCommandLimitsSettings = 1;
  SET_CONSOLE_COMMAND_LIMIT_MAX:ConsoleCommandLimitsSettings = 2;
function ChangeConsoleCommandLimits(cmd:PAnsiChar; settings:ConsoleCommandLimitsSettings; min:single; max:single):boolean;

function Init():boolean;

implementation
uses BaseGameData, sysutils, dynamic_caster, math;
type
  remapped_cmd = record
    cmd:pIConsole_Command;
    orig_ptr:pointer;
    new_ptr:pointer;
  end;
var
  console:pointer;
  remapped_commands:array of remapped_cmd;

function IsDemoRecord():boolean; stdcall;
begin
asm
  mov eax, xrEngine_addr;
  add eax, $92d7c
  mov al, [eax]
  mov @result, al
end;
end;


function IsConsoleShown():boolean;stdcall;
begin
asm
  mov eax, console
  cmp eax, 0
  je @finish
  mov al, [eax+$ac]
  mov @result, al
  @finish:
end;
end;

function GetConsole():pointer; stdcall;
begin
asm
  mov eax, xrengine_addr
  cmp eax, 0
  je @finish

  add eax, $92d5c
  mov eax, [eax] //получаем консоль
  mov @result, eax

  @finish:
end;
end;


procedure CCC_Mask__CCC_Mask(this:pCCC_Mask; name:PChar; value:pCardinal; mask:cardinal);stdcall;
asm
  pushad
    mov ecx, this
    push mask
    push value
    push name
    mov eax, xrengine_addr
    add eax, $77f0
    call eax //CCC_Mask::CCC_Mask(LPCSTR N, Flags32* V, u32 M);
  popad
end;

procedure CCC_Integer__CCC_Integer(this:pCCC_Integer; name:PChar; value:pInteger; min:integer; max:integer);stdcall;
asm
  pushad
    mov ecx, this
    push max
    push min    
    push value
    push name
    mov eax, xrengine_addr
    add eax, $8950
    call eax //CCC_Integer::CCC_Integer(LPCSTR N, int* V, int _min, int _max);
  popad
end;

procedure CCC_Float__CCC_Float(this:pCCC_Float; name:PChar; value:pSingle; min:single; max:single);stdcall;
asm
  pushad
    mov ecx, this
    push max
    push min    
    push value
    push name
    mov eax, xrengine_addr
    add eax, $7FA0
    call eax //CCC_Float::CCC_Float
  popad
end;

procedure CConsole__AddCommand(C:pIConsole_Command); stdcall;
asm
  pushad
    mov ecx, console
    push C
    mov eax, xrengine_addr
    add eax, $472b0
    call eax //CConsole::AddCommand(IConsole_Command* C);
  popad
end;

function CConsole__GetCommand(cmd:PAnsiChar):pIConsole_Command; stdcall;
asm
  pushad
    mov ecx, console
    push cmd
    mov eax, xrengine_addr
    add eax, $4abe0
    call eax //CConsole::GetCommand( LPCSTR cmd )
    mov @result, eax
  popad
end;

procedure Console__Execute(cmd:PChar); stdcall;
asm
  pushad
    call GetConsole
    test eax, eax
    je @finish
    push cmd

    mov ecx, eax
    mov ebx, xrengine_addr
    add ebx, $48560
    call ebx

    @finish:
  popad
end;

function ConsoleCommandFixResultToString(r:ConsoleCommandFixResult):string;
begin
  case r of
    CONSOLE_FIX_RESULT_SUCCESS: result:='command successfully fixed';
    CONSOLE_FIX_RESULT_ALREADY_FIXED: result:='command already fixed';
    CONSOLE_FIX_RESULT_COMMAND_NOT_FOUND: result:='command not found';
  else
    result:='error while fixing command';
  end
end;

function FixConsoleCommandValue(name:PAnsiChar; value:PAnsiChar):ConsoleCommandFixResult;
var
  i:integer;
  tmpstr:string;
  c:remapped_cmd;  
  c_float:pCCC_Float;
  c_int:pCCC_Integer;  
begin
  result:=CONSOLE_FIX_RESULT_ERROR;
  for i:=0 to length(remapped_commands)-1 do begin
    tmpstr:=remapped_commands[i].cmd.cName;
    if name = tmpstr then begin
      result:=CONSOLE_FIX_RESULT_ALREADY_FIXED;
      exit;
    end;
  end;

  c.cmd:=CConsole__GetCommand(name);
  if c.cmd = nil then begin
    result:=CONSOLE_FIX_RESULT_COMMAND_NOT_FOUND;
    exit;
  end;

  c_float:=dynamic_cast(c.cmd, 0, RTTI_IConsole_Command, RTTI_CCC_Float, false);
  if c_float<>nil then begin
    c.orig_ptr:=c_float.value;
    New(c_float.value);
    c.new_ptr:=c_float.value;
    c_float.value^:=(pSingle(c.orig_ptr))^;
    pSingle(c.orig_ptr)^:=StrToFloatDef(trim(value), c_float.value^);    
    result:=CONSOLE_FIX_RESULT_SUCCESS;
  end;

  c_int:=dynamic_cast(c.cmd, 0, RTTI_IConsole_Command, RTTI_CCC_Integer, false);
  if c_int<>nil then begin
    c.orig_ptr:=c_int.value;
    New(c_int.value);
    c.new_ptr:=c_int.value;
    c_int.value^:=(pInteger(c.orig_ptr))^;
    pInteger(c.orig_ptr)^:=StrToIntDef(trim(value), c_int.value^);    
    result:=CONSOLE_FIX_RESULT_SUCCESS;
  end;

  if result=CONSOLE_FIX_RESULT_SUCCESS then begin
    i:=length(remapped_commands);
    setlength(remapped_commands, i+1);
    remapped_commands[i]:=c;
  end;
end;

function ChangeConsoleCommandLimits(cmd:PAnsiChar; settings:ConsoleCommandLimitsSettings; min:single; max:single):boolean;
var
  c:pIConsole_Command;
  c_float:pCCC_Float;
  c_int:pCCC_Integer;
begin
  result:=false;

  c:=CConsole__GetCommand(cmd);
  if c = nil then exit;

  c_int:=dynamic_cast(c, 0, RTTI_IConsole_Command, RTTI_CCC_Integer, false);
  if c_int<>nil then begin
    if settings and SET_CONSOLE_COMMAND_LIMIT_MIN <> 0 then begin
      c_int.min:=floor(min);
      if c_int.min > c_int.value^ then c_int.value^:=c_int.min;
    end;
    if settings and SET_CONSOLE_COMMAND_LIMIT_MAX <> 0 then begin
      c_int.max:=floor(max);
      if c_int.max < c_int.value^ then c_int.value^:=c_int.max;
    end;
    result:=true;    
  end;
  if result then exit;

  c_float:=dynamic_cast(c, 0, RTTI_IConsole_Command, RTTI_CCC_Float, false);
  if c_float<>nil then begin
    if settings and SET_CONSOLE_COMMAND_LIMIT_MIN <> 0 then begin
      c_float.min:=min;
      if c_float.min > c_float.value^ then c_float.value^:=c_float.min;
    end;
    if settings and SET_CONSOLE_COMMAND_LIMIT_MAX <> 0 then begin
      c_float.max:=max;
      if c_float.max < c_float.value^ then c_float.value^:=c_float.max;
    end;
    result:=true;
  end;
end;

procedure ChangeConsoleLimits(); stdcall;
var
  max_grass_distance:single;
  min_grass_density:single;
begin
  max_grass_distance:=241;
  min_grass_density:=0.1;

  if xrRender_R2_addr<>0 then begin
    // На R2 не работает ключ -no_staging - текстуры из-за этого занимают оперативную память и приводят к вылетам по памяти. Делать нечего - ограничиваем качество текстур
    ChangeConsoleCommandLimits('texture_lod', SET_CONSOLE_COMMAND_LIMIT_MIN, 2, 4);
    max_grass_distance:=101;
    min_grass_density:=0.4;
  end else if xrRender_R1_addr<>0 then begin
    max_grass_distance:=101;
  end;
  ChangeConsoleCommandLimits('r__detail_radius', SET_CONSOLE_COMMAND_LIMIT_MAX, 49, max_grass_distance);
  ChangeConsoleCommandLimits('r__detail_density', SET_CONSOLE_COMMAND_LIMIT_MIN, min_grass_density, 0);
end;

procedure Startup_LimitConsoleCommands_Patch(); stdcall;
asm
  pushad
  call ChangeConsoleLimits
  popad
  // original
  add eax,$4D0
end;

function Init():boolean;
var
  jmp_addr:cardinal;
begin
  result:=false;
  setlength(remapped_commands, 0);

  console:=GetConsole();

  if console=nil then exit;

  //в Startup() после execUserScript добавляем изменение лимитов команд в меньшую сторону, чтобы движок не жрал слишком много памяти
  jmp_addr:=xrEngine_addr+$6fd8;
  if not WriteJump(jmp_addr, cardinal(@Startup_LimitConsoleCommands_Patch), 6, true) then exit;

  result:=true;
end;


end.

