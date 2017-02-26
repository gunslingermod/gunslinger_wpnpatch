unit dynamic_caster;

interface

function dynamic_cast(inptr:pointer; vfdelta:cardinal; srctype:cardinal; targettype:cardinal; isreference:boolean):pointer; stdcall;

const
  //all xrGame-based

  RTTI_CGrenade:cardinal = $61ad4c;
  RTTI_CMissile:cardinal = $61ad00;
  RTTI_CInventoryItem:cardinal = $61842c;
  RTTI_IPhysicsShellHolder:cardinal = $61d560;
  RTTI_CCustomRocket:cardinal = $6361cc;
  RTTI_CHudItem:cardinal = $635F48;
  RTTI_CWeapon:cardinal = $637268;
  RTTI_CObject:cardinal = $616020;
  RTTI_CActor:cardinal = $635AB8;
  RTTI_CTorch:cardinal = $61844C;
  RTTI_CAttachableItem:cardinal = $6274B4;
  RTTI_CInventoryItemOwner:cardinal = $618484;      

implementation
uses BaseGameData;

function dynamic_cast(inptr:pointer; vfdelta:cardinal; srctype:cardinal; targettype:cardinal; isreference:boolean):pointer; stdcall;
asm
  pushad

  movzx eax, isreference
  push eax

  mov eax, xrgame_addr
  add eax, targettype
  push eax

  mov eax, xrgame_addr
  add eax, srctype
  push eax

  push vfdelta
  push inptr

  mov eax, xrgame_addr
  add eax, $509d9a
  call eax

  mov @result, eax
  add esp, $14
  
  popad
end;


end.
