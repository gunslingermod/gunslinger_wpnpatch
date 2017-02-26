unit Level;

interface
function GetLevel():pointer; stdcall;
function Level_to_CObjectSpace(l:pointer):pointer; stdcall;

implementation
uses BaseGameData;

function GetLevel():pointer; stdcall;
asm
  mov eax, xrEngine_addr
  add eax, $92d2c
  mov eax, [eax]
  mov @result, eax
end;

function Level_to_CObjectSpace(l:pointer):pointer; stdcall;
asm
  mov eax, l
  add eax, $40094
  mov @result, eax
end;

end.
