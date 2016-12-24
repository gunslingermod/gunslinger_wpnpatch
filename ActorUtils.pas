unit ActorUtils;

interface
function GetActor():pointer; stdcall;
function GetActorActionState(stalker:pointer; mask:cardinal; previous_state:boolean = false):boolean; stdcall;
procedure CreateObjectToActor(section:PChar); stdcall;
function IsHolderInSprintState(wpn:pointer):boolean; stdcall;
procedure SetActorActionState(stalker:pointer; mask:cardinal; set_value:boolean; previous_state:boolean = false); stdcall;
function GetActorActiveItem():pointer; stdcall;

const
  actMovingForward:cardinal = $1;
  actMovingBack:cardinal = $2;
  actMovingLeft:cardinal = $4;
  actMovingRight:cardinal = $8;
  actCrounch:cardinal = $10;
  actSlow:cardinal = $20;
  actSprint:cardinal = $1000;
  actPreparingDetectorFinished:cardinal = $8000000;
  actModSprintStarted:cardinal = $10000000;

implementation
uses BaseGameData, WpnUtils, GameWrappers;

function GetActor():pointer; stdcall;
begin
  asm
    mov eax, xrgame_addr
    add eax, $64e2c0;
    mov eax, [eax]
    mov @result, eax
  end;
end;

function GetActorActionState(stalker:pointer; mask:cardinal; previous_state:boolean = false):boolean; stdcall;
asm
  push ecx
  push edx
  mov edx, $594
  cmp previous_state, 0
  je @body
  mov edx, $590

  @body:
  mov ecx, mask
  mov @result, 0
  mov eax, stalker
  mov eax, [eax+edx]
  test eax, ecx
  je @finish
  mov @result, 1

  @finish:
  pop edx
  pop ecx
end;

procedure SetActorActionState(stalker:pointer; mask:cardinal; set_value:boolean; previous_state:boolean = false); stdcall;
asm
  pushad
  mov edx, $594
  cmp previous_state, 0
  je @body
  mov edx, $590

  @body:
  mov eax, stalker
  mov ecx, mask

  cmp set_value, 0
  je @clear_flag
    or [eax+edx], ecx
    jmp @finish
  @clear_flag:
    not ecx
    and [eax+edx], ecx
  @finish:
  popad
end;

function IsActorAim(stalker:pointer):boolean; stdcall;
begin
  asm
    mov eax, stalker
    mov al, [eax+$5D4]
    mov @result, al
  end;
end;

procedure CreateObjectToActor(section:PChar); stdcall;
var act:pointer;
begin
  act:=GetActor();
  if (act=nil) then exit;

  asm
    pushad
      call alife
      
      push 0
      push 0
      push 0
      mov ecx, act
      add ecx, $80
      push ecx      //position
      push section
      push eax      //alife simulator ptr

      mov ebx, xrgame_addr
      add ebx, $99490
      call ebx      //call create

      add esp, $18
    popad
  end;
end;

function IsHolderInSprintState(wpn:pointer):boolean;stdcall;
var actor:pointer;
    holder:pointer;
begin
  holder:=WpnUtils.GetOwner(wpn);
  actor:=GetActor();
  if (actor<>nil) and (actor=holder) and (GetActorActionState(holder, actSprint) or GetActorActionState(holder, actModSprintStarted)) then begin
    result:=true;
  end else
    result:=false;
end;

function GetActorActiveItem():pointer; stdcall;
asm
  pushfd
  
  mov eax, xrGame_addr
  add eax, $64F0E4
  mov eax, [eax]
  mov eax, [eax+$94]
  cmp eax, 0
  je @finish
  mov eax, [eax+4]
  sub eax, $2e0

  @finish:
  popfd
  mov @result, eax
end;

end.
