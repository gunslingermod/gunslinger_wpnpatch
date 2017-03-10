unit ConsoleUtils;

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
  _unknown_vec_start:cardinal;
  _unknown_vec_end:cardinal;
  _unknown_vec_memend:cardinal;
end;

type pIConsole_Command = ^IConsole_Command;

type CCC_Mask = packed record
  base:IConsole_Command;
  value:pcardinal;
  mask:cardinal;  
end;
type pCCC_Mask = ^CCC_Mask;


procedure CCC_Mask__CCC_Mask(this:pCCC_Mask; name:PChar; value:pCardinal; mask:cardinal);stdcall;
procedure CConsole__AddCommand(C:pIConsole_Command); stdcall;


function IsDemoRecord():boolean; stdcall;
function IsConsoleShown():boolean;stdcall;

procedure Console__Execute(cmd:PChar); stdcall;

function Init():boolean;


implementation
uses BaseGameData, sysutils;
var
  console:pointer;

function IsDemoRecord():boolean; stdcall;
asm
  mov eax, xrEngine_addr;
  add eax, $92d7c
  mov al, [eax]
end;


function IsConsoleShown():boolean;stdcall;
asm
  mov eax, console
  cmp eax, 0
  je @finish
  mov al, [eax+$ac]
  @finish:
end;

function GetConsole():pointer; stdcall;
asm
  mov eax, xrengine_addr
  cmp eax, 0
  je @finish

  add eax, $92d5c
  mov eax, [eax] //получаем консоль

  @finish:
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


function Init():boolean;
begin
  result:=false;
  console:=GetConsole();

  if console=nil then exit;

  result:=true;
end;


end.
