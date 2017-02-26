unit ConsoleUtils;

interface

function IsDemoRecord():boolean; stdcall;
function IsConsoleShown():boolean;stdcall;

function Init():boolean;

implementation
uses BaseGameData;
var console:pointer;

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

function Init():boolean;
begin
  console:=GetConsole();
  
  if console<>nil then
    result:=true
  else
    result:=false;

end;


end.
