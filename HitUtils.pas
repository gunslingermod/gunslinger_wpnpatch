unit HitUtils;

interface
function SHit__GetHitType(this:pointer):cardinal; stdcall;
function SHit__GetPower(this:pointer):single; stdcall;
function SHit__GetImpulse(this:pointer):single; stdcall;

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

implementation

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

end.
