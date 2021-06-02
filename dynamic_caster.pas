unit dynamic_caster;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

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
  RTTI_CHudItemObject:cardinal = $637280;  
  RTTI_CWeapon:cardinal = $637268;
  RTTI_CWeaponKnife:cardinal = $635EF0;  
  RTTI_CWeaponMagazined:cardinal = $635F0C;
  RTTI_CWeaponMagazinedWGrenade:cardinal = $636A7C;  
  RTTI_CWeaponBinoculars:cardinal = $6376D8;
  RTTI_CWeaponBM16:cardinal = $6377C8;
  RTTI_CWeaponRG6:cardinal = $63779C;  
  RTTI_CWeaponShotgun:cardinal = $637720;  
  RTTI_CCustomDetector:cardinal = $62C4B8;      
  RTTI_CObject:cardinal = $616020;
  RTTI_CGameObject:cardinal = $619C60;  
  RTTI_CActor:cardinal = $635AB8;
  RTTI_CTorch:cardinal = $61844C;
  RTTI_CAttachableItem:cardinal = $6274B4;
  RTTI_CInventoryItemOwner:cardinal = $618484;      
  RTTI_CCustomOutfit:cardinal = $62cd70;
  RTTI_CHelmet:cardinal = $635c9c;
  RTTI_CUIPdaWnd:cardinal = $63EF80;
  RTTI_CUIDialogWnd:cardinal = $6342C4;
  RTTI_CRocketLauncher:cardinal = $6373E8;
  RTTI_CShootingObject:cardinal = $62C4E8;
  RTTI_CMapSpot:cardinal = $63EFA0;
  RTTI_CUIWindow:cardinal = $62D6E8;
  RTTI_CEntity:cardinal = $61D4DC;
  RTTI_CEntityAlive:cardinal = $6196FC;
  RTTI_CAI_Crow:cardinal = $620204;
  RTTI_CAI_Bloodsucker:cardinal = $61E9AC;
  RTTI_CWeaponRPG7:cardinal = $637538;
  RTTI_CEatableItem:cardinal = $627498;
  RTTI_CAI_Boar:cardinal = $61F6F4;
  RTTI_CPhysicsShellHolder:cardinal = $61d4f4;
  RTTI_CTelekinesis:cardinal = $61dbec;
  RTTI_CBurer:cardinal = $620238;
  RTTI_CBaseMonster:cardinal = $61d7f0;
  RTTI_CUIActorMenu = $63ee68;
  RTTI_CUICustomMap = $63f030;
  RTTI_CUIMiniMap = $63f0a4;



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
