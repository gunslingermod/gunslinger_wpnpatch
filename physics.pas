unit physics;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}


interface

uses MatVectors;

function GetCharacterPhysicsSupport(CGameObject:pointer):pointer; stdcall;
function GetCPHMovementControl(CCharacterPhysicsSupport:pointer):pointer; stdcall;
procedure CPHMovementControl_SetApplyGravity(cphmc:pointer; val:boolean); stdcall;
procedure CPHMovementControl_SetForcedPhysicsControl(cphmc:pointer; val:boolean); stdcall;
function CPHMovementControl_Environment(cphmc:pointer):cardinal; stdcall;
procedure CPHMovementControl_GroundNormal(cphmc:pointer; gn:pFVector3); stdcall;
procedure CPHMovementControl_ApplyImpulse(cphmc:pointer; dir:pFVector3; p:single); stdcall;
procedure CPHMovementControl_AddControlVel(cphmc:pointer; vel:pFVector3); stdcall;


procedure ApplyImpulseTrace(CPhysicsShellHolder:pointer; pos:pFVector3; dir:pFVector3; val:single); stdcall;
procedure GetLinearVel(CPhysicsShellHolder:pointer; vel:pFVector3); stdcall;
function GetPhysicsElementMassCenter(CPhysicsElement:pointer):pFVector3; stdcall;
procedure ApplyElementImpulseTrace(CPhysicsElement:pointer; pos:pFVector3; dir:pFVector3; val:single); stdcall;
procedure CPHMovementControl_SetVelocity(cphmc:pointer; vel:pFVector3); stdcall;

implementation
uses BaseGameData;

procedure ApplyImpulseTrace(CPhysicsShellHolder:pointer; pos:pFVector3; dir:pFVector3; val:single); stdcall;
asm
  pushad
  mov ecx, CPhysicsShellHolder
  mov ecx, [ecx+$1ec] //m_pPhysicsShell
  test ecx, ecx
  je @finish

  push val
  push dir
  push pos

  mov edx, [ecx] //vtable
  mov edx, [edx+$148] //ptr to xrPhysics + 3dba0
  call edx   //applyImpulseTrace

  @finish:
  popad
end;

procedure GetLinearVel(CPhysicsShellHolder:pointer; vel:pFVector3); stdcall;
asm
  pushad
  mov ecx, CPhysicsShellHolder
  mov ecx, [ecx+$1ec] //m_pPhysicsShell
  test ecx, ecx
  je @finish

  mov eax, [ecx]
  mov eax, [eax+$15c]
  push vel
  call eax //m_pPhysicsShell->get_LinearVel(velocity)

  @finish:
  popad
end;

procedure ApplyElementImpulseTrace(CPhysicsElement:pointer; pos:pFVector3; dir:pFVector3; val:single); stdcall;
asm
  pushad
  mov ecx, CPhysicsElement

  push 0
  push val
  push dir
  push pos

  mov edx, [ecx] //vtable
  mov edx, [edx+$124] //ptr to xrPhysics + 2eff0
  call edx   //applyImpulseTrace

  popad
end;

function GetPhysicsElementMassCenter(CPhysicsElement:pointer):pFVector3; stdcall;
asm
  pushad
  mov esi, CPhysicsElement
  mov eax, [esi+$44]
  mov edx, [eax+$10]
  lea ecx, [esi+$44]
  call edx //mass_Center
  mov result, eax
  popad
end;


procedure SetWeaponPhysicMass(wpn:pointer; mass:single); stdcall;
asm
  pushad
  mov esi, wpn
  mov ecx, [esi+$2d4]
  test ecx, ecx
  je @finish
  mov edx, [ecx]
  mov eax, [edx+$4c]
  push mass
  call eax
  @finish:
  popad
end;

function GetWeaponPhysicMass(wpn:pointer):single; stdcall;
asm
  mov result, $BF800000 //-1
  pushad
  mov esi, wpn
  mov ecx, [esi+$2d4]
  test ecx, ecx
  je @finish
  mov edx, [ecx]
  mov eax, [edx+$54]
  call eax
  fstp [result]
  @finish:
  popad
end;

function GetCharacterPhysicsSupport(CGameObject:pointer):pointer; stdcall;
asm
  pushad
  mov eax, CGameObject
  push eax
  mov ebx, xrgame_addr
  add ebx, $3483f0
  call ebx
  add esp, 4

  mov edx, [eax]
  mov ecx, eax
  mov eax, [edx+$194]
  call eax
  
  mov @result, eax
  popad
end;

function GetCPHMovementControl(CCharacterPhysicsSupport:pointer):pointer; stdcall;
asm
  mov eax, CCharacterPhysicsSupport
  mov eax, [eax+$a4]
  mov @result, eax
end;

procedure CPHMovementControl_SetApplyGravity(cphmc:pointer; val:boolean); stdcall;
asm
  pushad
  movzx ebx, val
  push ebx

  mov ecx, cphmc
  mov edx, xrgame_addr
  add edx, $4fe9a0
  call edx

  popad
end;

procedure CPHMovementControl_SetForcedPhysicsControl(cphmc:pointer; val:boolean); stdcall;
asm
  pushad
  movzx ebx, val
  push ebx

  mov ecx, cphmc
  mov edx, xrgame_addr
  add edx, $4febe0
  call edx

  popad
end;

function CPHMovementControl_Environment(cphmc:pointer):cardinal; stdcall;
asm
  mov eax, cphmc
  mov eax, [eax+$34]
  mov @result, eax
end;

procedure CPHMovementControl_GroundNormal(cphmc:pointer; gn:pFVector3); stdcall;
asm
  pushad
  push gn

  mov ecx, cphmc
  mov edx, xrgame_addr
  add edx, $4fe390
  call edx

  popad
end;

procedure CPHMovementControl_ApplyImpulse(cphmc:pointer; dir:pFVector3; p:single); stdcall;
asm
  pushad
  push p
  push dir

  mov ecx, cphmc
  mov edx, xrgame_addr
  add edx, $4fec60
  call edx

  popad
end;

procedure CPHMovementControl_AddControlVel(cphmc:pointer; vel:pFVector3); stdcall;
asm
  pushad
  push vel

  mov ecx, cphmc
  mov edx, xrgame_addr
  add edx, $4fec10
  call edx

  popad
end;

procedure CPHMovementControl_SetVelocity(cphmc:pointer; vel:pFVector3); stdcall;
asm
  pushad
  push vel

  mov ecx, cphmc
  mov edx, xrgame_addr
  add edx, $4fead0
  call edx

  popad
end;

// CPHMovementControl::Calculate - xrgame.dll+5012d0
// CPHActorCharacter::Jump - xrphysics.dll+1db60
end.
