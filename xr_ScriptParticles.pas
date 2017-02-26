unit xr_ScriptParticles;

interface
uses MatVectors;

type CScriptParticles = packed record
  vftable:pointer;
  m_particles_object:pointer;
end;

function CScriptParticles__constructor(this:pointer; name:PChar):pointer; stdcall;
procedure CScriptParticles__destructor(this:pointer);stdcall;
procedure CScriptParticles__PlayAtPos(this:pointer; Fvector_position:pointer);stdcall;
procedure CScriptParticles__MoveTo(this:pointer; Fvector_pos:pointer; Fvector_vel:pointer);stdcall;
function CScriptParticles__IsPlaying(this:pointer):boolean;stdcall;
procedure CScriptParticles__Stop(this:pointer);stdcall;
function PlayCScriptParticleAtPosSafe(this:pointer; pos:pointer):boolean;stdcall;

procedure InitCScriptParticles(var this:CScriptParticles);

implementation
uses BaseGameData;

function CScriptParticles__constructor(this:pointer; name:PChar):pointer; stdcall;
asm
  pushad
    mov ecx, this

    push name

    mov eax, xrgame_addr
    add eax, $21ad40
    call eax

    mov @result, eax
  popad
end;

procedure CScriptParticles__destructor(this:pointer);stdcall;
asm
  pushad
    mov ecx, this
    push 00 //говорим, что память освобождать не надо

    mov eax, xrgame_addr
    add eax, $21ADE0
    call eax

  popad
end;

procedure CScriptParticles__PlayAtPos(this:pointer; Fvector_position:pointer);stdcall;
asm
  pushad
    mov ecx, this

    push Fvector_position

    mov eax, xrgame_addr
    add eax, $21AA90
    call eax

  popad
end;

procedure CScriptParticles__MoveTo(this:pointer; Fvector_pos:pointer; Fvector_vel:pointer);stdcall;
asm
  pushad
    mov ecx, this

    push Fvector_vel
    push Fvector_pos

    mov eax, xrgame_addr
    add eax, $21AE10
    call eax

  popad
end;

function PlayCScriptParticleAtPosSafe(this:pointer; pos:pointer):boolean;stdcall;
var
  zerovec:FVector3;
begin
  if CScriptParticles__IsPlaying(this) then begin
    zerovec.x:=0;
    zerovec.y:=0;
    zerovec.z:=0;
    CScriptParticles__MoveTo(this, pos, @zerovec);
  end else begin
    CScriptParticles__PlayAtPos(this, pos);
  end;

end;

function CScriptParticles__IsPlaying(this:pointer):boolean;stdcall;
asm
  pushad
    mov ecx, this

    mov eax, xrgame_addr
    add eax, $21AAD0
    call eax

    mov @result, al
  popad
end;

procedure InitCScriptParticles(var this:CScriptParticles);
begin
  this.vftable:=nil;
  this.m_particles_object:=nil;
end;

procedure CScriptParticles__Stop(this:pointer);stdcall;
asm
  pushad
    mov ecx, this

    mov eax, xrgame_addr
    add eax, $21AAB0
    call eax

  popad
end;

end.
