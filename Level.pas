unit Level;

interface
uses MatVectors;
function GetLevel():pointer; stdcall;
function Level_to_CObjectSpace(l:pointer):pointer; stdcall;
procedure spawn_phantom(pos:pFVector3);

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

procedure spawn_phantom(pos:pFVector3);
asm
  pushad
    mov eax, pos
    push eax
    mov eax, xrgame_addr
    add eax, $23cdd0
    call eax
    add esp, 4
  popad
end;

end.
