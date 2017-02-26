unit LightUtils;

interface
function Init():boolean;
function CreateLight:pointer; stdcall;
procedure Enable(light:pointer; state:boolean); stdcall;
procedure SetPos(light:pointer; x:single; y:single; z:single); stdcall;
procedure SetDir(light:pointer; x:single; y:single; z:single); stdcall;

implementation
uses BaseGameData;

var
  xrAPI_Render_ptr:cardinal;


function CreateLight:pointer; stdcall;
begin
  asm
    pushad
    pushfd
    mov eax, xrAPI_Render_ptr
    mov eax, [eax]
    mov ecx, [eax]
    mov edx, [ecx]
    mov eax, [edx+$7c]
    call eax
    mov @result, eax
    popfd
    popad
  end;
end;

procedure Enable(light:pointer; state:boolean); stdcall;
begin
  asm
    pushad
    pushfd

    movzx eax, state
    push eax

    mov ecx, light
    mov edx, [ecx]
    mov eax, [edx+4]
    call eax

    popfd
    popad
  end;
end;

procedure SetPos(light:pointer; x:single; y:single; z:single); stdcall;
begin
  asm
    pushad
    pushfd

    mov eax, z
    push eax
    mov eax, y
    push eax
    mov eax, x
    push eax

    push esp
    mov ecx, light
    mov eax, [ecx]
    mov eax, [eax+$24]
    call eax

    add esp, $C

    popfd
    popad
  end;
end;

procedure SetDir(light:pointer; x:single; y:single; z:single); stdcall;
begin
  asm
    pushad
    pushfd

    push 00
    push 00
    push 00

    mov eax, z
    push eax
    mov eax, y
    push eax
    mov eax, x
    push eax

    mov eax, esp
    add eax, $c
    push eax
    sub eax, $c
    push eax


    mov ecx, light
    mov eax, [ecx]
    mov eax, [eax+$28]
    call eax

    add esp, $18

    popfd
    popad
  end;
end;




function Init():boolean;
begin
  result:=false;
  xrAPI_Render_ptr:=xrGame_addr+$5124A8;
  result:=true;
end;

end.
