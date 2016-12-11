unit ActorUtils;

interface
function GetActor():pointer; stdcall;
function IsSprint(stalker:pointer):boolean; stdcall;
function IsAim(stalker:pointer):boolean; stdcall;
function IsCrounch(stalker:pointer):boolean; stdcall;
function IsSlowMoving(stalker:pointer):boolean; stdcall;
function IsMovingForward(stalker:pointer):boolean; stdcall;
function IsMovingBack(stalker:pointer):boolean; stdcall;
function IsMovingLeft(stalker:pointer):boolean; stdcall;
function IsMovingRight(stalker:pointer):boolean; stdcall;

implementation
uses BaseGameData;

function GetActor():pointer; stdcall;
begin
  asm
    mov eax, xrgame_addr
    add eax, $64e2c0;
    mov eax, [eax]
    mov @result, eax
  end;
end;

function IsSprint(stalker:pointer):boolean; stdcall;
begin
  asm
    mov @result, 0
    mov eax, stalker
    mov eax, [eax+$594]
    test eax, $1000
    je @finish
    mov @result, 1
    @finish:
  end;
end;

function IsCrounch(stalker:pointer):boolean; stdcall;
begin
  asm
    mov @result, 0
    mov eax, stalker
    mov eax, [eax+$594]
    test eax, $10
    je @finish
    mov @result, 1
    @finish:
  end;
end;

function IsSlowMoving(stalker:pointer):boolean; stdcall;
begin
  asm
    mov @result, 0
    mov eax, stalker
    mov eax, [eax+$594]
    test eax, $20
    je @finish
    mov @result, 1
    @finish:
  end;
end;

function IsMovingForward(stalker:pointer):boolean; stdcall;
begin
  asm
    mov @result, 0
    mov eax, stalker
    mov eax, [eax+$594]
    test eax, $1
    je @finish
    mov @result, 1
    @finish:
  end;
end;

function IsMovingBack(stalker:pointer):boolean; stdcall;
begin
  asm
    mov @result, 0
    mov eax, stalker
    mov eax, [eax+$594]
    test eax, $2
    je @finish
    mov @result, 1
    @finish:
  end;
end;

function IsMovingLeft(stalker:pointer):boolean; stdcall;
begin
  asm
    mov @result, 0
    mov eax, stalker
    mov eax, [eax+$594]
    test eax, $4
    je @finish
    mov @result, 1
    @finish:
  end;
end;

function IsMovingRight(stalker:pointer):boolean; stdcall;
begin
  asm
    mov @result, 0
    mov eax, stalker
    mov eax, [eax+$594]
    test eax, $8
    je @finish
    mov @result, 1
    @finish:
  end;
end;

function IsAim(stalker:pointer):boolean; stdcall;
begin
  asm
    mov eax, stalker
    mov al, [eax+$5D4]
    mov @result, al
  end;
end;

end.
