unit HitUtils;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface
uses MatVectors;
{function SHit__GetHitType(this:pointer):cardinal; stdcall;
function SHit__GetPower(this:pointer):single; stdcall;
function SHit__GetImpulse(this:pointer):single; stdcall;}

type
  SHit = packed record
    Time:cardinal;
    PACKET_TYPE:word;
    DestID:word;
    power:single;
    dir:FVector3;
    who:pointer;
    whoId:word;
    weaponID:word;
    boneID:word;
    p_in_bone_space:FVector3;
    unused:word;
    impulse:single;
    hit_type:cardinal;
    armor_piercing:single;
    add_wound:byte;
    aim_bullet:byte;
  end;
  pSHit = ^SHit;

const
    EHitType__eHitTypeBurn:cardinal = 0;
    EHitType__eHitTypeShock:cardinal = 1;
    EHitType__eHitTypeChemicalBurn:cardinal = 2;
    EHitType__eHitTypeRadiation:cardinal = 3;
    EHitType__eHitTypeTelepatic:cardinal = 4;
    EHitType__eHitTypeWound:cardinal = 5;
    EHitType__eHitTypeFireWound:cardinal = 6;
    EHitType__eHitTypeStrike:cardinal = 7;
    EHitType__eHitTypeExplosion:cardinal = 8;
    EHitType__eHitTypeWound_2:cardinal = 9;
    EHitType__eHitTypeLightBurn:cardinal = 10;
    EHitType__eHitTypeMax:cardinal = 11;

procedure SendHit(h:pSHit); stdcall;
function MakeDefaultHitForActor():SHit;

implementation
uses Misc, BaseGameData;

function SHit__GetHitType(this:pointer):cardinal; stdcall;
asm
  mov eax, this
  mov eax, [eax+$34]
  mov @result, eax
end;

function SHit__GetPower(this:pointer):single; stdcall;
asm
  mov eax, this
  mov eax, [eax+$8]
  mov @result, eax
end;

function SHit__GetImpulse(this:pointer):single; stdcall;
asm
  mov eax, this
  mov eax, [eax+$30]
  mov @result, eax
end;

procedure GenHitPacketHeader(h:pShit; packetype:cardinal; game_id:cardinal); stdcall;
asm
  pushad
  push game_id
  push packetype
  mov ecx, h
  mov eax, xrgame_addr
  add eax, $4e93a0
  call eax
  popad
end;

procedure DumpHitToPacket(h:pShit; p:pNET_Packet); stdcall;
asm
  pushad
  mov ecx, h
  push p
  mov eax, [xrgame_addr]
  add eax, $4e9570
  call eax
  popad
end;

procedure SendHit(h:pSHit); stdcall;
var
  p:NET_Packet;
begin
  ClearNetPacket(@p);
  GenHitPacketHeader(h, h.PACKET_TYPE, h.whoId);
  DumpHitToPacket(h, @p);
  SendNetPacket(@p);
end;

function MakeDefaultHitForActor():SHit;
begin
  result.PACKET_TYPE:=GE_HIT;
  result.DestID:=0;
  result.whoId:=0;
  result.weaponID:=0;
  result.boneID:=0;
  result.dir.x:=0;
  result.dir.y:=1;
  result.dir.z:=0;
  result.power:=1.0;
  result.p_in_bone_space.x:=0;
  result.p_in_bone_space.y:=0;
  result.p_in_bone_space.z:=0;
  result.impulse:=10;
  result.hit_type:=0;
end;

end.
