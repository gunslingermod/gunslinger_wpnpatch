unit ActorUtils;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}


//xrgame+4e212a - менять условия для включения коллизии

{$define USE_SCRIPT_USABLE_HUDITEMS}  //на всякий - потом все равно в двиг надо перекинуть, но влом - и так отлично работает

interface
uses LightUtils, WeaponAdditionalBuffer, MatVectors, HitUtils, vector, xr_map, physics;

const
  actMovingForward:cardinal = $1;
  actMovingBack:cardinal = $2;
  actMovingLeft:cardinal = $4;
  actMovingRight:cardinal = $8;
  actCrouch:cardinal = $10;
  actSlow:cardinal = $20;

  actJump:cardinal = $80;
  actFall:cardinal = $100;
  actLanding:cardinal = $200;
  actLanding2:cardinal = $400;
  actSprint:cardinal = $1000;
  actLLookout:cardinal = $2000;
  actRLookout:cardinal = $4000;

  actModNeedBlowoutAnim:cardinal = $02000000;
  actAimStarted:cardinal = $04000000;
  actShowDetectorNow:cardinal = $08000000; //преддоставание проигралoсь, можно показывать детектор
  actModSprintStarted:cardinal = $10000000;
  actModNeedMoveReassign:cardinal = $20000000;
  actModDetectorSprintStarted:cardinal = $40000000;
  actModDetectorAimStarted:cardinal = $80000000;

  actTotalActions:cardinal = $FFFFFFFF;

  mState_WISHFUL:cardinal = $58c;
  mState_OLD:cardinal = $590;
  mState_REAL:cardinal = $594;


  kfUNZOOM:cardinal=$1;
  kfRELOAD:cardinal=$2;
  kfNEXTFIREMODE:cardinal=$8;
  kfPREVFIREMODE:cardinal=$10;
  kfGLAUNCHSWITCH:cardinal=$20;
  kfWPNHIDE:cardinal=$40;
  kfDETECTOR:cardinal=$80;
  kfZOOM:cardinal=$100;
  kfFIRE:cardinal=$200;
  kfLASER:cardinal=$400;
  kfTACTICALTORCH:cardinal=$800;
  kfNEXTAMMO:cardinal = $1000;
  kfHEADLAMP:cardinal = $2000;
  kfNIGHTVISION:cardinal = $4000;
  kfQUICKKICK:cardinal = $8000;
  kfPDAHIDE:cardinal = $10000;
  kfPDASHOW:cardinal = $20000;


type
  lefthanded_torchlight_params = packed record
    base:torchlight_params;
    aim_offset:FVector3;
  end;

  CEntityConditionSimple = packed record
    vftable:pointer;
    m_fHealth:single;
    m_fHealthMax:single;
  end;

  SConditionChangeV = packed record //sizeof = 0x20
		m_fV_Radiation:single;
		m_fV_PsyHealth:single;
		m_fV_Circumspection:single;
		m_fV_EntityMorale:single;
		m_fV_RadiationHealth:single;
		m_fV_Bleeding:single;
		m_fV_WoundIncarnation:single;
		m_fV_HealthRestore:single;
  end;

  SBooster = packed record
	  fBoostTime:single;
	  fBoostValue:single;
	  m_type:cardinal;
  end;
  pSBooster = ^SBooster;

  BOOSTER_MAP = packed record // sizeof = 0x1c
    data:xr_integerindexed_map_base;
  end;

  CEntityCondition = packed record //xizeof = 0x140;
    base_CEntityConditionSimple:CEntityConditionSimple;
    base_CHitImmunity:CHitImmunity;
    //offset: 0x40
    m_use_limping_state:byte; {boolean}
    _unused1:byte;
    _unused2:word;
    m_object:pointer;
    m_WoundVector:xr_vector;
    m_fPower:single;
    m_fRadiation:single;
    m_fPsyHealth:single;
    m_fEntityMorale:single;
    //offset:0x64
    m_fPowerMax:single;
    m_fRadiationMax:single;
    m_fPsyHealthMax:single;
    m_fEntityMoraleMax:single;
    //offset:0x74
	  m_fDeltaHealth:single;
  	m_fDeltaPower:single;
  	m_fDeltaRadiation:single;
  	m_fDeltaPsyHealth:single;
    m_fDeltaCircumspection:single;
  	m_fDeltaEntityMorale:single;
    //offset:0x8c
    m_change_v:SConditionChangeV;
    //offset:0xac
    m_fMinWoundSize:single;
    //offset:0xb0
    m_bIsBleeding:boolean;
    _unused3:byte;
    _unused4:word;
    m_fHealthHitPart:single;
    m_fPowerHitPart:single;
    //offset:0xbc
    m_fBoostBurnImmunity:single;
    m_fBoostShockImmunity:single;
    m_fBoostRadiationImmunity:single;
    m_fBoostTelepaticImmunity:single;
    m_fBoostChemicalBurnImmunity:single;
    m_fBoostExplImmunity:single;
    m_fBoostStrikeImmunity:single;
    m_fBoostFireWoundImmunity:single;
    m_fBoostWoundImmunity:single;
    m_fBoostRadiationProtection:single;
    m_fBoostTelepaticProtection:single;
    m_fBoostChemicalBurnProtection:single;
    //offset:0xec
    m_fHealthLost:single;
    m_fKillHitTreshold:single;
  	m_fLastChanceHealth:single;
		m_fInvulnerableTime:single;
		m_fInvulnerableTimeDelta:single;
    //offset:0x100
    m_iLastTimeCalled:Int64;
    m_fDeltaTime:single;
    m_pWho:pointer;
    //offset:0x110
    m_iWhoID:word;
    _unused5:word;
    m_fHitBoneScale:single;
    m_fWoundBoneScale:single;
    m_limping_threshold:single;
    //offset:0x120
    m_bTimeValid:byte; {boolean}
    m_bCanBeHarmed:byte; {boolean}
    _unused6:word;
    m_booster_influences:BOOSTER_MAP;
  end;
  pCEntityCondition=^CEntityCondition;

  SMedicineInfluenceValues = packed record  //sizeof = 0x24
    fHealth:single;
    fPower:single;
    fSatiety:single;
    fRadiation:single;
    fWoundsHeal:single;
    fMaxPowerUp:single;
    fAlcohol:single;
    fTimeTotal:single;
    fTimeCurrent:single;  
  end;

  CActorCondition = packed record //sizeof = 0x224
    base_CEntityCondition:CEntityCondition;
    //offset:0x140
    m_condition_flags:cardinal;
    m_object:pointer;
    m_death_effector:pointer;
    //offset:0x14c
    m_curr_medicine_influence:SMedicineInfluenceValues;
    //offset:0x170
    m_fAlcohol:single;
    m_fV_Alcohol:single;
    m_fSatiety:single;
    m_fV_Satiety:single;
    m_fV_SatietyPower:single;
    m_fV_SatietyHealth:single;
    m_fSatietyCritical:single;
    m_fPowerLeakSpeed:single;
    //offset:0x190
    m_fJumpPower:single;
    m_fStandPower:single;
    m_fWalkPower:single;
    m_fJumpWeightPower:single;
    m_fWalkWeightPower:single;
    m_fOverweightWalkK:single;
    m_fOverweightJumpK:single;
    m_fAccelK:single;
    m_fSprintK:single;
    m_MaxWalkWeight:single;
    //offset:0x1b8
    m_zone_max_power: array [0..4] of single;
    m_zone_danger: array [0..4] of single;
    //offset:0x1e0
    m_f_time_affected:single;
    m_max_power_restore_speed:single;
    m_max_wound_protection:single;
    m_max_fire_wound_protection:single;
    //offset:0x1f0
    m_bLimping:byte; {boolean}
    m_bCantWalk:byte; {boolean}
    m_bCantSprint:byte; {boolean}
    _unused1:byte;
    //offset:0x1f4
    m_fLimpingPowerBegin:single;
    m_fLimpingPowerEnd:single;
    m_fCantWalkPowerBegin:single;
    m_fCantWalkPowerEnd:single;
    //offset:0x214
    m_fCantSprintPowerBegin:single;
    m_fCantSprintPowerEnd:single;
    m_fLimpingHealthBegin:single;
    m_fLimpingHealthEnd:single;
    m_use_sound:pointer;
  end;
  pCActorCondition = ^CActorCondition;


function GetActor():pointer; stdcall;
function GetActorIfAlive():pointer; stdcall;
function GetActorTargetSlot():integer; stdcall;
function GetActorActiveSlot():integer; stdcall;
//для быстрого использования
function GetActorPreviousSlot():integer; stdcall;
procedure RestoreLastActorDetector(); stdcall;
function GetActorActionState(stalker:pointer; mask:cardinal; state:cardinal=$594):boolean; stdcall;
function GetActorActionStateInt(stalker:pointer; mask:cardinal; state:cardinal=$594):integer; stdcall;
procedure CreateObjectToActor(section:PChar); stdcall;
function IsHolderInSprintState(wpn:pointer):boolean; stdcall; //работает только для актора, для других всегда вернет false!
function IsHolderHasActiveDetector(wpn:pointer):boolean; stdcall;
function IsHolderInAimState(wpn:pointer):boolean;stdcall;
procedure SetActorActionState(stalker:pointer; mask:cardinal; set_value:boolean; state:cardinal=$594); stdcall;
function GetActorActiveItem():pointer; stdcall;
function ItemInSlot(act:pointer; slot:integer):pointer; stdcall;
procedure DropItem(act:pointer; item:pointer); stdcall;
function Init():boolean; stdcall;
function CheckActorWeaponAvailabilityWithInform(wpn:pointer):boolean;
procedure SetActorKeyRepeatFlag(mask:cardinal; state:boolean; ignore_suicide:boolean=false);
function GetActorKeyRepeatFlag(mask:cardinal):boolean;
procedure ClearActorKeyRepeatFlags();
procedure ResetActorFlags(act:pointer);
procedure UpdateSlots(act:pointer);
procedure UpdateFOV(act:pointer);
function GetSlotOfActorHUDItem(act:pointer; itm:pointer):integer; stdcall;
procedure ActivateActorSlot(slot:cardinal); stdcall;
procedure ActivateActorSlot__CInventory(slot:word; forced:boolean); stdcall;
function GetActorSlotBlockedCounter(slot:cardinal):cardinal; stdcall;
procedure SetActorSlotBlockedCounter(slot:cardinal; cnt:byte); stdcall;
procedure ChangeSlotsBlockStatus(block:boolean); stdcall;

function IsHandJitter(itm:pointer):boolean; stdcall;
procedure SetHandsJitterTime(time:cardinal); stdcall;
function GetHandJitterScale(itm:pointer):single; stdcall;

procedure SetFOV(fov:single); stdcall;
function GetFOV():single; stdcall;
procedure SetHudFOV(fov:single); stdcall;

function CRenderDevice__GetCamPos():pointer;stdcall;
function CRenderDevice__GetCamDir():pointer;stdcall;
function CRenderDevice__GetCamTop():pointer;stdcall;
function CRenderDevice__GetCamRight():pointer;stdcall;
procedure CorrectDirFromWorldToHud(dir:pFVector3; pos:pFVector3; k:single); stdcall;
function GetTargetDist():single;stdcall;
function GetActorThirst():single;stdcall;

procedure SwitchLefthandedTorch(status:boolean); stdcall;
procedure RecreateLefthandedTorch(params_section:PChar; det:pointer); stdcall;
function GetLefthandedTorchLinkedDetector():pointer; stdcall;
function GetLefthandedTorchParams():lefthanded_torchlight_params; stdcall;

procedure KillActor(actor:pointer; who:pointer); stdcall;
procedure CEntity__KillEntity(this:pointer; who:word); stdcall;

procedure CActor__set_inventory_disabled(this:pointer; status:boolean); stdcall;
function CActor__get_inventory_disabled(this:pointer):boolean; stdcall;

function CInventory__CalcTotalWeight(this:pointer):single; stdcall;
function CInventoryOwner__GetInventory(this:pointer):pointer; stdcall;

procedure SetDisableInputStatus(status:boolean); stdcall;

procedure HeadlampCallback(wpn:pointer; param:integer); stdcall;
procedure NVCallback(wpn:pointer; param:integer); stdcall;
procedure KickCallback(wpn:pointer; param:integer); stdcall;
procedure SetActorActionCallback(cb:TAnimationEffector);
function GetActorActionCallback():TAnimationEffector;
function IsActorActionAnimatorAutoshow():boolean;


procedure add_pp_effector(fn:pchar; id:integer; cyclic:boolean); stdcall;
procedure set_pp_effector_factor2(id:integer; f:single); stdcall;
procedure set_pp_effector_factor(id:integer; f:single; f_sp:single); stdcall;
procedure remove_pp_effector(id:integer); stdcall;

function GetActorHealth(act:pointer):single; stdcall;
function GetActorStamina(act:pointer):single; stdcall;
procedure SetActorStamina(act:pointer; val:single); stdcall;

function GetCameraManager():pointer; stdcall;
function CCameraManager__GetCamEffector(index:cardinal):pointer; stdcall;
procedure CCameraManager__RemoveCamEffector(index:cardinal); stdcall;

function GetPDAJoystickAnimationModifier():string;
procedure CActor__OnKeyboardPress_initiate(dik:cardinal); stdcall;

procedure PerformDrop(act:pointer); stdcall;

procedure ResetChangedGrenade();
procedure SetChangedGrenade(itm:pointer);

function GetEntityDirection(e:pointer):pFVector3; stdcall;
function GetEntityPosition(e:pointer):pFVector3; stdcall;
function IsPickupMode():boolean; stdcall;

function IsPDAShowToZoomNow():boolean;

function GetBoosterFromConditions(cond:pCEntityCondition; booster_type:cardinal):pSBooster; stdcall;

function GetActorConditions(act:pointer):pCActorCondition; stdcall;

function CEntityCondition__BleedingSpeed_reimpl(pcond:pCEntityCondition; hit_type_mask:integer = -1):single; stdcall;
procedure CEntityCondition__ChangeBleeding_custom(cond:pCEntityCondition; percent:single; hit_type_mask:integer = -1); stdcall;

function IsItemActionAnimator(itm:pointer):boolean; stdcall;
procedure PlanActorKickAnimator(kick_types_section:string);

const
	eBoostHpRestore:cardinal=0;
	eBoostPowerRestore:cardinal=1;
	eBoostRadiationRestore:cardinal=2;
	eBoostBleedingRestore:cardinal=3;
	eBoostMaxWeight:cardinal=4;
	eBoostRadiationProtection:cardinal=5;
	eBoostTelepaticProtection:cardinal=6;
	eBoostChemicalBurnProtection:cardinal=7;
	eBoostBurnImmunity:cardinal=8;
	eBoostShockImmunity:cardinal=9;
	eBoostRadiationImmunity:cardinal=10;
	eBoostTelepaticImmunity:cardinal=11;
	eBoostChemicalBurnImmunity:cardinal=12;
	eBoostExplImmunity:cardinal=13;
	eBoostStrikeImmunity:cardinal=14;
	eBoostFireWoundImmunity:cardinal=15;
	eBoostWoundImmunity:cardinal=16;

var
  _is_pda_lookout_mode:boolean; //за что отвечает мышь: обзор или курсор


implementation
uses Messenger, BaseGameData, HudItemUtils, Misc, DetectorUtils, sysutils, UIUtils, KeyUtils, gunsl_config, WeaponEvents, Throwable, dynamic_caster, WeaponUpdate, ActorDOF, WeaponInertion, strutils, Math, collimator, xr_BoneUtils, ControllerMonster, Level, ScriptFunctors, Crows, LensDoubleRender, xr_strings, RayPick;

type
  TCursorDirection = (Idle, Up, Down, Left, Right, UpLeft, DownLeft, DownRight, UpRight, Click);
  TCursorState = packed record
    last_moving_time:cardinal;
    last_click_time:cardinal;
    dir_accumulator:FVector2;
    current_dir:TCursorDirection;
  end;

var
  _keyflags:cardinal;
  _last_act_slot:integer;
  _prev_act_slot:integer;

  _jitter_time_remains:cardinal;


  _thirst_value:single;

{$ifdef USE_SCRIPT_USABLE_HUDITEMS}
  _was_unprocessed_use_of_usable_huditem:boolean;
{$endif}

  _lefthanded_torch:lefthanded_torchlight_params;
  _torch_linked_detector:pointer;

  _last_update_time:cardinal;

  _action_animator_callback:TAnimationEffector;
  _action_animator_param:integer;
  _action_ppe:integer;
  _action_animator_autoshow:boolean;

  _sprint_tiredness:single; //как долго мы бежали

  _was_pda_animator_spawned:boolean;
  _pda_cursor_state:TCursorState;
  _changed_grenade:pointer;
  _actor_hands_length:single;

  _hud_update_sect:string;
  _slot_to_restore_after_outfit_change:integer;

  _last_mouse_coord:MouseCoord;
  _need_pda_zoom:boolean;
  _last_pda_zoom_state:boolean;
  _pda_blowout_anim_started:boolean;
  _planned_kick_animator:string;
  _need_fire_particle:boolean;

//-------------------------------------------------------------------------------------------------------------
procedure player_hud__load_fixpatched(); stdcall;
asm
  sub esp, 8
  push esi
  push edi
  mov edi, xrgame_addr
  add edi, $2fecf5
  jmp edi
end;

procedure player_hud__load(sect:pshared_str); stdcall;
asm
  mov ecx, xrgame_addr
  mov ecx, [ecx+$64f0e4] //g_player_hud
  push sect
  call player_hud__load_fixpatched
end;

procedure SetHudReloadRequest(sect:pshared_str); stdcall;
begin
  R_ASSERT(sect<>nil, 'sect == nil', 'SetHudReloadRequest');
  _hud_update_sect:=get_string_value(sect);
end;

procedure player_hud__onloadrequest(); stdcall;
asm
  mov eax, [esp+4]
  pushad
  call GetActor
  test eax, eax
  popad
  jne @registerrequest
  
  // если актора не существует - нужно установить худ
  pushad
  push eax
  call player_hud__load
  popad
  jmp @finish

  @registerrequest:
  // Если актор существует - зарегистрируем "запрос" на смену худа
  pushad
  push eax
  call SetHudReloadRequest
  popad

  @finish:
  // больше ничего не делаем
  ret 4
end;

//-------------------------------------------------------------------------------------------------------------
procedure SetChangedGrenade(itm:pointer);
begin
  _changed_grenade:=itm;
end;

procedure ResetChangedGrenade();
begin
  _changed_grenade:=nil;
end;

procedure ProcessChangedGrenade(act:pointer);
begin
  if _changed_grenade <> nil then begin
    virtual_Action(_changed_grenade, kWPN_NEXT, kActPress);
  end;
end;

procedure PerformDrop(act:pointer); stdcall;
asm
  pushad
    mov eax, act
    add eax, $2c8
    mov eax, [eax+$1c]
    push $02 // CMD_STOP
    push $27 // kDROP
    mov ecx, eax
    mov ebx, xrgame_addr
    add ebx, $2a9640
    call ebx // CInventory::Action
    test al, al
    jne @finish

    mov ecx, act
    mov edx, [ecx]
    mov eax, [edx+$28C]
    call eax

    @finish:
  popad
end;

procedure PerformDropFromActorHands(); stdcall;
var
  act, det, itm:pointer;
begin
  act:=GetActorIfAlive();
  if act=nil then exit;

  det:=GetActiveDetector(act);
  if det<>nil then begin
    DropItem(act, det);
  end;

  PerformDrop(act);
end;

//-------------------------------------------------------------------------------------------------------------
procedure CTorch__Switch(CTorch:pointer; status:boolean);stdcall;
asm
  pushad
    movzx eax, status
    push eax

    mov ecx, CTorch

    mov eax, xrgame_addr
    add eax, $2f13f0
    call eax
  popad
end;

function IsTorchSwitchedOn(CTorch:pointer):boolean; stdcall;
asm
  push eax
  mov eax, CTorch
  mov al, [eax+$2FC]
  mov @result, al
  pop eax
end;

procedure CTorch__StopNvEffector(CTorch:pointer; speed:single; use_sounds:boolean);stdcall;
asm
  pushad
    movzx eax, use_sounds
    push eax
    mov ebx, speed
    push ebx

    mov ecx,CTorch
    mov ecx, [ecx+$31c]
    mov eax, xrgame_addr
    add eax, $2f1080
    call eax
  popad
end;

procedure CTorch__SwitchNightVision(CTorch:pointer; status:boolean; use_sounds:boolean);stdcall;
asm
  pushad
    movzx eax, use_sounds
    push eax

    movzx eax, status
    push eax

    mov ecx, CTorch

    mov eax, xrgame_addr
    add eax, $2f26d0
    call eax
  popad
end;

function IsItemAllowsUsingTorch(itm:pointer):boolean; stdcall;
begin
  result:=false;
  if itm = nil then exit;

  result:=game_ini_r_bool_def(GetSection(itm), 'torch_available', false);
  result:=FindBoolValueInUpgradesDef(itm, 'torch_available', result, true);
end;

function CanUseTorch(CTorch:pointer):boolean; stdcall;
var
  act, outfit, helmet:pointer;
begin
  result:=true;
  act:=GetActor();
  if (act=nil) or (GetOwner(CTorch)<>act) then exit;
  
  helmet := ItemInSlot(act, 12);
  outfit := ItemInSlot(act, 7);
  result := IsItemAllowsUsingTorch(helmet) or IsItemAllowsUsingTorch(outfit);
end;
//--------------------------------------------------------------------------------------------------
function IsNVSwitchedOn(CTorch:pointer):boolean; stdcall;
asm
  mov eax, CTorch
  movzx eax, byte ptr [eax+$319] 
end;

function IsNVPostprocessOn(CTorch:pointer):boolean; stdcall;
asm
  mov @result, 0
  pushad
  mov ecx, CTorch
  cmp ecx, 0
  je @finish

  mov eax, [ecx+$31c]
  cmp eax, 0
  je @finish

  mov eax, [eax]      //m_pActor
  cmp eax, 0
  je @finish

  mov eax, [eax+$544]
  push $37

  mov ecx, eax

  mov eax, xrgame_addr
  call [eax+$512D80] //CCameraManager::GetPPEffector
  test eax, eax
  je @finish
  mov @result, 1

  @finish:
  popad
end;


function IsHelmetHasNV(CHelmet:pointer):boolean; stdcall;
asm
  mov @result, 0
  mov eax, CHelmet
  cmp eax, 0
  je @finish

  mov eax, [eax+$2e4]
  cmp eax, 0
  je @finish

  cmp [eax+4], 0
  je @finish
  
  mov @result, 1

  @finish:
end;

function IsOutfitHasNV(CCustomOutfit:pointer):boolean; stdcall;
asm
  mov @result, 0
  mov eax, CCustomOutfit
  cmp eax, 0
  je @finish

  mov eax, [eax+$348]
  cmp eax, 0
  je @finish

  cmp [eax+4], 0
  je @finish

  mov @result, 1

  @finish:
end;

function CanUseNV(CTorch:pointer):boolean; stdcall;
var
  act, helm, outfit:pointer;
begin
  result:=false;
  act:=GetActor();
  if (act=nil) or (GetOwner(CTorch)<>act) then exit;

  helm:=ItemInSlot(act, 12);
  outfit:=ItemInSlot(act, 7);

  if helm<>nil then helm:=dynamic_cast(helm, 0, RTTI_CInventoryItem, RTTI_CHelmet, false);
  if outfit<>nil then outfit:=dynamic_cast(outfit, 0, RTTI_CInventoryItem, RTTI_CCustomOutfit, false);

  result:= IsHelmetHasNV(helm) or IsOutfitHasNV(outfit);

end;


procedure OnOutfitOrHelmInRuck(CTorch:pointer); stdcall;
begin
  if not CanUseTorch(CTorch) then begin
    CTorch__Switch(CTorch, false);
  end;
end;

procedure OnOutfitOrHelmInRuck_Patch(); stdcall;
asm
  pushad
    push ecx
    call OnOutfitOrHelmInRuck
  popad
  push 1
  push 0
  push ecx
  call CTorch__SwitchNightVision
  ret 8
end;

procedure CTorch__Switch_Patch(); stdcall;
asm
  pushad
    push ecx
    call CanUseTorch
    cmp al, 1
  popad
  je @finish
  //нельзя пользоваться фонарем! выставляем аргумент статуса в 0
  xor ebx, ebx
  mov [esp+$14], 0

  @finish:
  lea edi, [esi+$e8]
end;

function IsItemActionAnimator(itm:pointer):boolean; stdcall;
begin
  result:=false;
  if itm = nil then exit;
  result:=game_ini_r_bool_def(GetSection(itm), 'action_animator', false)
end;

function OnActorSwithesSmth(restrictor_config_param:PChar; animator_item_section:PChar; anm_name:PChar; snd_label:PChar; key_repeat:cardinal; callback:TAnimationEffector; callback_param:integer):boolean; stdcall;
var
  buf:WpnBuf;
  wpn, act, det:pointer;
  res:boolean;
  curanm:PChar;
  slot:integer;
begin
  result:=false;
  act:=GetActor();
  if act=nil then exit;

  wpn:=GetActorActiveItem();
  det:=GetActiveDetector(act);
  if (det<>nil) and (GetCurrentState(det)<>EHudStates__eIdle) then begin
    exit;
  end;

  if (wpn=nil) or (restrictor_config_param=nil) or FindBoolValueInUpgradesDef(wpn, restrictor_config_param, game_ini_r_bool_def(GetSection(wpn), restrictor_config_param, false), true) then begin
    if not game_ini_r_bool_def(animator_item_section, 'action_animator', false) then begin
      log('Section ['+animator_item_section+'] defined as action animator in [gunslinger_base], but key action_animator is false or does not exist!', true);
      if IsDebug then Messenger.SendMessage('Action animator: invalid configuration, see log!');
    end;

//    log('spawn scheme');
    //если оружие есть и оно занято - уходим
    if (wpn<>nil) then begin
      buf:=GetBuffer(wpn);
      if (buf<>nil) and not Weapon_SetKeyRepeatFlagIfNeeded(wpn, key_repeat) then begin
        exit;
      end else if (GetCurrentState(wpn)<>EHudStates__eIdle) then begin
        exit;
      end;
    end;

//    log('Check');
    slot:=game_ini_r_int_def(animator_item_section, 'slot', 0)+1;
    if ItemInSlot(act, slot)<>nil then begin
      exit;
    end;

    wpn:= pointer(cardinal(act)-$e8); //псевдооружие :)
//    log('spawn');
    CALifeSimulator__spawn_item2(animator_item_section, GetPosition(wpn), GetLevelVertexID(wpn), GetGameVertexID(wpn), GetID(wpn));

    if GetActorActiveSlot()<>0 then begin
      //хак - так как первое не может активировать слот, в котором ничего нет, а второе косячно скрывает предмет с детектором
      //если же в руках ничего нет - активация слота идет автоматом
      ActivateActorSlot__CInventory(0, false);
      ActivateActorSlot(slot);
    end;

    _action_animator_callback:=callback;
    _action_animator_param:=callback_param;
    _action_animator_autoshow:=true;
    result:=true;

  end else begin
    buf:=GetBuffer(wpn);
    if (buf<>nil) then begin
      //просто запускаем аниму через буфер
      res:=Weapon_SetKeyRepeatFlagIfNeeded(wpn, key_repeat);
      if res and WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, anm_name, snd_label) then begin
        curanm:=GetActualCurrentAnim(wpn);
        StartCompanionAnimIfNeeded(rightstr(curanm, length(curanm)-4), wpn, false);
        MakeLockByConfigParam(wpn, GetHUDSection(wpn), PChar('lock_time_start_'+curanm), false, callback, callback_param);
        _action_animator_callback:=nil;
        _action_animator_param:=0;
        _action_animator_autoshow:=false;
        result:=true;
      end;
    end else begin
      //SetPending(true) и вызов анимации, затем в OnAnimationEnd SetPending(false)
      if not IsPending(wpn) and (GetCurrentState(wpn)=EHudStates__eIdle) then begin
        if GetActorActionState(act, actSprint, mstate_REAL) or GetActorActionState(act, actModDetectorSprintStarted, mstate_REAL) or GetActorActionState(act, actModSprintStarted, mstate_REAL) then begin
          SetActorActionState(act, actModSprintStarted, false);
          SetActorActionState(act, actModSprintStarted, false, mState_WISHFUL);
      //    result:=false;
      //    exit;
        end;
        StartPending(wpn);
        PlayHudAnim(wpn, anm_name, true);
        CHudItem_Play_Snd(wpn, snd_label);
        StartCompanionAnimIfNeeded(rightstr(anm_name, length(anm_name)-4), wpn, false);
        _action_animator_callback:=callback;
        _action_animator_param:=callback_param;
        _action_animator_autoshow:=false;
        result:=true;
      end;
    end;
  end;
end;

//Action-animator callbacks-----------------------------------------------------------------------------------------

procedure HeadlampCallback(wpn:pointer; param:integer); stdcall;
var
  CTorch:pointer;
  act:pointer;
  buf:WpnBuf;
begin
  act:=GetActor();
  if act=nil then exit;
  CTorch:=ItemInSlot(act, 10);
  if CTorch=nil then exit;
  CTorch__Switch(CTorch, param>0);

//  log ('headlamp: '+booltostr(param>0, true));
  if wpn=nil then exit;
  buf:=GetBuffer(wpn);
  if (buf<>nil) then MakeLockByConfigParam(wpn, GetHUDSection(wpn), PChar('lock_time_end_'+GetActualCurrentAnim(wpn)));
end;

procedure NVCallback(wpn:pointer; param:integer); stdcall;
var
  CTorch:pointer;
  act:pointer;
  buf:WpnBuf;
begin
  act:=GetActor();
  if act=nil then exit;
  CTorch:=ItemInSlot(act, 10);
  if CTorch=nil then exit;
  CTorch__SwitchNightVision(CTorch, param>0, true);

  if wpn=nil then exit;
  buf:=GetBuffer(wpn);
  if (buf<>nil) then MakeLockByConfigParam(wpn, GetHUDSection(wpn), PChar('lock_time_end_'+GetActualCurrentAnim(wpn)));
end;

procedure KickCallback(wpn:pointer; param:integer); stdcall;
var
  act:pointer;
  buf:WpnBuf;
begin
  act:=GetActor();
  if act=nil then exit;
  if wpn=nil then exit;

  buf:=GetBuffer(wpn);
  MakeWeaponKick(CRenderDevice__GetCamPos(), CRenderDevice__GetCamDir(), wpn);


  if (buf<>nil) then MakeLockByConfigParam(wpn, GetHUDSection(wpn), PChar('lock_time_end_'+GetActualCurrentAnim(wpn)));
end;

procedure FakeCallback(wpn:pointer; param:integer); stdcall;
begin
end;

//-----------------------------------------------------------------------------------------------------------
procedure OnActorSwithesNV(itm:pointer); stdcall;
var
  modifier:string;
  wpn:pointer;
begin
  if IsActorControlled() or not (CanUseNV(itm)) then exit;

  wpn:=GetActorActiveItem();

  if (wpn<>nil) and IsAimNow(wpn) then begin
    if not game_ini_r_bool_def(GetHUDSection(wpn), 'can_use_nv_when_aim', false) then exit;
    modifier:='_aim' ;
  end else begin
    modifier:='';
  end;

  if IsNVSwitchedOn(itm) then begin
    OnActorSwithesSmth('disable_nv_anim', GetNVDisableAnimator(), PChar('anm_nv_off'+modifier), 'sndNVOff', kfNIGHTVISION, NVCallback, 0);
  end else begin
    OnActorSwithesSmth('disable_nv_anim', GetNVEnableAnimator(), PChar('anm_nv_on'+modifier), 'sndNVOn', kfNIGHTVISION, NVCallback, 1);
  end;
end;

procedure OnActorSwithesTorch(itm:pointer); stdcall;
var
  modifier:string;
  wpn:pointer;
  snd:string;
begin
  if IsActorControlled() or not CanUseTorch(itm) then exit;

  wpn:=GetActorActiveItem();

  if (wpn<>nil) and IsAimNow(wpn) then begin
    if not game_ini_r_bool_def(GetHUDSection(wpn), 'can_use_torch_when_aim', false) then exit;
    modifier:='_aim' ;
  end else begin
    modifier:='';
  end;

  if IsTorchSwitchedOn(itm) then begin
    OnActorSwithesSmth('disable_headlamp_anim', GetHeadlampDisableAnimator(), PChar('anm_headlamp_off'+modifier), 'sndHeadlampOff', kfHEADLAMP, HeadlampCallback, 0);
  end else begin
    OnActorSwithesSmth('disable_headlamp_anim', GetHeadlampEnableAnimator(), PChar('anm_headlamp_on'+modifier), 'sndHeadlampOn', kfHEADLAMP, HeadlampCallback, 1);
  end;
end;

procedure OnActorKick(); stdcall;
var
  wpn, act:pointer;
begin
    act:=GetActor;
    if act=nil then exit;
    wpn:=GetActorActiveItem();

    if IsActorControlled() then begin
      //под контролем не работает
      exit;
    end else if (GetActorActiveSlot()=1) then begin
      //если в руках нож - делаем обычный удар
      virtual_Action(wpn, kWPN_FIRE, kActPress);
    end else begin
      //проверяем, можем ли вообще бить сейчас
      //if ((wpn=nil) and (ItemInSlot(act, 1)=nil)) or ((wpn<>nil) and not FindBoolValueInUpgradesDef(wpn, 'disable_kick_anim', game_ini_r_bool_def(GetSection(wpn), 'disable_kick_anim', false))) then exit;
      if ((wpn=nil) or FindBoolValueInUpgradesDef(wpn, 'disable_kick_anim', game_ini_r_bool_def(GetSection(wpn), 'disable_kick_anim', false), true)) and (ItemInSlot(act, 1)=nil) then exit;

      if (wpn<>nil) and (IsScopeAttached(wpn)) and FindBoolValueInUpgradesDef(wpn, 'disable_kick_anim_when_scope_attached', game_ini_r_bool_def(GetSection(wpn), 'disable_kick_anim_when_scope_attached', false), true) then begin
        OnActorSwithesSmth('disable_kick_anim_when_scope_attached', GetKickAnimator(), 'anm_kick', 'sndKick', kfQUICKKICK, KickCallback, 0);
        exit;      
      end;

      if (wpn<>nil) and (IsSilencerAttached(wpn)) and FindBoolValueInUpgradesDef(wpn, 'disable_kick_anim_when_sil_attached', game_ini_r_bool_def(GetSection(wpn), 'disable_kick_anim_when_sil_attached', false), true) then begin
        OnActorSwithesSmth('disable_kick_anim_when_sil_attached', GetKickAnimator(), 'anm_kick', 'sndKick', kfQUICKKICK, KickCallback, 0);
        exit;      
      end;

      if (wpn<>nil) and IsGrenadeMode(wpn) and FindBoolValueInUpgradesDef(wpn, 'disable_kick_anim_when_gl_enabled', game_ini_r_bool_def(GetSection(wpn), 'disable_kick_anim_when_gl_enabled', false), true) then begin
        OnActorSwithesSmth('disable_kick_anim_when_gl_enabled', GetKickAnimator(), 'anm_kick', 'sndKick', kfQUICKKICK, KickCallback, 0);
        exit;      
      end;

      if (wpn<>nil) and ((GetGLStatus(wpn)=1) or ((GetGLStatus(wpn)=2) and IsGLAttached(wpn)) ) and FindBoolValueInUpgradesDef(wpn, 'disable_kick_anim_when_gl_attached', game_ini_r_bool_def(GetSection(wpn), 'disable_kick_anim_when_gl_attached', false), true) then begin
        OnActorSwithesSmth('disable_kick_anim_when_gl_attached', GetKickAnimator(), 'anm_kick', 'sndKick', kfQUICKKICK, KickCallback, 0);
        exit;
      end;

      if (wpn<>nil) and (GetSection(wpn)=GetKickAnimator()) then begin
        //хотим повторный удар :) Запомним это
        SetActorKeyRepeatFlag(kfQUICKKICK, true);
      end else begin
        OnActorSwithesSmth('disable_kick_anim', GetKickAnimator(), 'anm_kick', 'sndKick', kfQUICKKICK, KickCallback, 0);
      end;
    end;
end;

procedure CActor__SwitchTorch_Patch;
asm
  pushad
    push ecx
    call OnActorSwithesTorch
  popad
end;

procedure CActor__SwitchNightVision_Patch;
asm
  pushad
    push ecx
    call OnActorSwithesNV
  popad
end;


//--------------------------------------------------------------------------------------------------------------------------


function CInventory__CalcTotalWeight(this:pointer):single; stdcall;
asm
  pushad
    mov ecx, this
    mov eax, xrgame_addr
    add eax, $2A7460
    call eax
  popad
  fstp @result
end;

function CInventoryOwner__GetInventory(this:pointer):pointer; stdcall;
asm
  mov eax, this
  mov eax, [eax+$1c]
  mov @result, eax
end;

procedure CActor__set_inventory_disabled(this:pointer; status:boolean); stdcall;
asm
  push eax
  push ebx
  mov eax, this
  movzx ebx, status

  mov byte ptr [eax+$9CB], bl

  pop ebx
  pop eax
end;  


function CActor__get_inventory_disabled(this:pointer):boolean; stdcall;
asm
  mov eax, this
  movzx eax, byte ptr [eax+$9CB]
  mov @result, al
end;

function GetActor():pointer; stdcall;
begin
asm
    mov eax, xrgame_addr
    add eax, $64e2c0;
    mov eax, [eax]
    mov @result, eax
end;
end;

function GetActorIfAlive():pointer; stdcall;
begin
  result:=GetActor();
  if GetActorHealth(result) <= 0 then begin
    result:=nil;
  end;
end;

function GetActorHealth(act:pointer):single; stdcall;
var
  c:pCActorCondition;
begin
  c:=GetActorConditions(act);
  result:=c.base_CEntityCondition.base_CEntityConditionSimple.m_fHealth;
end;

function GetActorStamina(act:pointer):single; stdcall;
var
  c:pCActorCondition;
begin
  c:=GetActorConditions(act);
  result:=c.base_CEntityCondition.m_fPower;
end;

procedure SetActorStamina(act:pointer; val:single); stdcall;
var
  c:pCActorCondition;
begin
  if val < 0 then val:=0;
  if val > 1 then val:=1;

  c:=GetActorConditions(act);
  c.base_CEntityCondition.m_fPower := val;
end;


function GetActorActionState(stalker:pointer; mask:cardinal; state:cardinal=$594):boolean; stdcall;
asm
  push ecx
  push edx
  mov edx, state

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

function GetActorActionStateInt(stalker:pointer; mask:cardinal; state:cardinal=$594):integer; stdcall;
asm
  push ecx
  push edx
  mov edx, state

  @body:
  mov ecx, mask
  mov @result, 0
  mov eax, stalker
  mov eax, [eax+edx]
  and eax, ecx
  mov @result, eax


  @finish:
  pop edx
  pop ecx
end;



procedure SetActorActionState(stalker:pointer; mask:cardinal; set_value:boolean; state:cardinal=$594); stdcall;
asm
  pushad
  mov edx, state

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

procedure CEntity__KillEntity(this:pointer; who:word); stdcall;
asm
  pushad
    movzx eax, who
    push eax
    mov eax, xrgame_addr
    add eax, $2796B0
    mov ecx, this
    call eax
  popad
end;


procedure CActor__Die(this:pointer; who:pointer); stdcall;
asm
  pushad
    mov eax, xrgame_addr
    add eax, $261700
    mov ecx, this
    push who
    call eax
  popad
end;

procedure KillActor(actor:pointer; who:pointer); stdcall;
const
  EPS = 0.001;
begin
  if actor = nil then exit;
  if GetActorHealth(actor) > 0 then begin
    CActor__Die(actor, who);
  end;
end;


function IsHolderInSprintState(wpn:pointer):boolean;stdcall;
var actor:pointer;
    holder:pointer;
begin
  holder:=GetOwner(wpn);
  actor:=GetActor();
  if (actor<>nil) and (actor=holder) and (GetActorActionState(holder, actSprint) or GetActorActionState(holder, actModSprintStarted)) then begin
    result:=true;
  end else
    result:=false;
end;

function IsHolderInAimState(wpn:pointer):boolean;stdcall;
var actor:pointer;
    holder:pointer;
begin
  holder:=GetOwner(wpn);
  actor:=GetActor();
  if (actor<>nil) and (actor=holder) and (GetActorActionState(holder, actAimStarted)) then begin
    result:=true;
  end else
    result:=false;
end;

function IsHolderHasActiveDetector(wpn:pointer):boolean; stdcall;
var
  holder:pointer;
begin
  holder:=GetOwner(wpn);
  if (holder<>nil) then begin
    result:=(DetectorUtils.GetActiveDetector(holder)<>nil);
  end else
    result:=false;
end;

function GetActorActiveItem():pointer; stdcall;
var
  act:pointer;
begin
  result:=nil;
  act:=GetActorIfAlive;
  if act=nil then exit;
  result:=ItemInSlot(act, GetActorActiveSlot());
end;

var
  _is_pickup_mode:boolean;
procedure CActor__UpdateCL_PickupMode_Patch();stdcall;
asm
  mov dl, byte ptr [esi+$57C] //CActor::m_bPickupMode
  mov _is_pickup_mode, dl
  mov edx,[esi+$2C8] //original
end;

function IsPickupMode():boolean; stdcall;
begin
  result:=false;
  if GetActor()<>nil then begin
    result:=_is_pickup_mode;
  end
end;


{asm
  pushfd

  mov eax, xrGame_addr
  add eax, $64F0E4
  mov eax, [eax]              //g_player_hud
  mov eax, [eax+$94]          //first attachable_item
  cmp eax, 0
  je @finish
  mov eax, [eax+4]
  sub eax, $2e0

  @finish:
  popfd
  mov @result, eax
end; }

function GetActorActiveSlot():integer; stdcall;
begin
asm
  mov @result, -1;
  pushad
  pushfd

  call GetActor        //получаем актора

  test eax, eax
  je @finish

  mov eax, [eax+$2e4]   //получаем его CInventory
  test eax, eax
  je @finish

  mov ax, [eax+$40]     //получаем текущий активный слот актора
  movzx eax, ax
  mov @result, eax

  @finish:
  popfd
  popad
end;
end;

function GetActorSlotBlockedCounter(slot:cardinal):cardinal; stdcall;
asm
  mov @result, 0;
  pushfd
  pushad
  sub slot, 1
  cmp slot, 12
  jge @finish

  call GetActor        //получаем актора

  test eax, eax
  je @finish

  mov eax, [eax+$2e4]   //получаем его CInventory
  test eax, eax
  je @finish

  lea eax, [eax+$135]
  add eax, slot
  movzx eax, byte ptr [eax]
  mov @result, eax

  @finish:
  popad
  popfd
end;

procedure SetActorSlotBlockedCounter(slot:cardinal; cnt:byte); stdcall;
asm
  pushad
  pushfd
  sub slot, 1
  cmp slot, 12
  jge @finish

  call GetActor        //получаем актора

  test eax, eax
  je @finish

  mov eax, [eax+$2e4]   //получаем его CInventory
  test eax, eax
  je @finish

  lea eax, [eax+$135]
  add eax, slot

  mov bl, cnt
  mov byte ptr [eax], bl

  @finish:
  popfd
  popad
end;

procedure ActivateActorSlot__CInventory(slot:word; forced:boolean); stdcall;
asm
  pushad

  call GetActor        //получаем актора

  test eax, eax
  je @finish

  mov eax, [eax+$2e4]   //получаем его CInventory
  test eax, eax
  je @finish

  movzx ebx, forced
  push ebx
  movzx ebx, slot
  push ebx
  mov ecx, eax
  mov eax, xrgame_addr
  add eax, $2a8070
  call eax

  @finish:
  popad
end;

procedure ChangeSlotsBlockStatus(block:boolean); stdcall;
var
  i:integer;
  cnt:cardinal;
begin
  for i:=1 to 12 do begin
    cnt:=GetActorSlotBlockedCounter(i);
    if block then begin
      if cnt<200 then begin
        SetActorSlotBlockedCounter(i, cnt+1)
      end else begin
        Log('ChangeSlotsBlockStatus - block count > 200!', true);
      end;
    end else begin
      if cnt>0 then begin
        SetActorSlotBlockedCounter(i, cnt-1);
      end else begin
        Log('ChangeSlotsBlockStatus - block count = 0!', true);
      end;
    end;
  end;
end;

function GetActorTargetSlot():integer; stdcall;
begin
asm
  mov @result, -1;
  pushad
  pushfd

  call GetActor        //получаем актора

  test eax, eax
  je @finish

  mov eax, [eax+$2e4]   //получаем его CInventory
  test eax, eax
  je @finish

  mov ax, [eax+$42]     //получаем целевой слот актора
  movzx eax, ax
  mov @result, eax

  @finish:
  popfd
  popad
end;
end;

procedure ResetActorFlags(act:pointer);
begin
  SetActorActionState(act, actAimStarted, false);
  SetActorActionState(act, actModSprintStarted, false);
  SetActorActionState(act, actModNeedMoveReassign, false);
  SetActorActionState(act, actModNeedBlowoutAnim, false);
end;

procedure ProcessKeys(act:pointer);
var
  wpn, det, torch:pointer;
  action:cardinal;
  last_pdahide_state:boolean;
begin

  if act = nil then exit;
  wpn:=GetActorActiveItem();
  det:=GetActiveDetector(act);

  
  if (wpn = nil) then begin
    last_pdahide_state:=GetActorKeyRepeatFlag(kfPDAHIDE);
    ClearActorKeyRepeatFlags();
    SetActorKeyRepeatFlag(kfPDAHIDE, last_pdahide_state);    
    ResetActorFlags(act);
  end else if (not WpnCanShoot(wpn)) then begin
    //Реактивация после блока у болта, грены, ножа, вызванного доставанием детектора.
    if (IsThrowable(wpn) or IsKnife(wpn)) then begin
      if ((_keyflags and kfFIRE)<>0) then
        action:=kWPN_FIRE
      else if ((_keyflags and kfZOOM)<>0) then
        action:=kWPN_ZOOM
      else
        action:=0;
        
      if action>0 then begin
        if cardinal(GetCurrentState(det))<>EHudStates__eShowing then begin
          virtual_Action(wpn, action, kActPress);
          if (action=kWPN_ZOOM) and not IsActionKeyPressedInGame(kWPN_ZOOM) then virtual_Action(wpn, action, kActRelease);
          SetActorKeyRepeatFlag(kfFIRE, false);
          SetActorKeyRepeatFlag(kfZOOM, false);
        end;
      end;

    end;

    wpn:=nil;
  end else begin
    if not IsActionProcessing(wpn) and ((_keyflags and kfFIRE)<>0) then begin
      virtual_Action(wpn, kWPN_FIRE, kActPress);
      if not IsActionKeyPressed(kWPN_FIRE) then begin
        virtual_Action(wpn, kWPN_FIRE, kActRelease);
      end;
      SetActorKeyRepeatFlag(kfFIRE, false);
    end;
  end;

  if IsSprintOnHoldEnabled() and (IsAimToggle() or (not IsActionKeyPressedInGame(kWPN_ZOOM)) and (not IsActionKeyPressedInGame(kWPN_ZOOM_ALTER))) and (_keyflags=0) and (CDialogHolder__TopInputReceiver()=nil) then begin
    if IsActionKeyPressedInGame(kSPRINT_TOGGLE) and ((wpn=nil) or CanSprintNow(wpn)) then begin
      SetActorActionState(act, actSprint, true, mState_WISHFUL);
    end else begin
      SetActorActionState(act, actSprint, false, mState_WISHFUL);
    end;
  end;

  if ((_keyflags and kfWPNHIDE)<>0) then begin
    if (wpn=nil) or CanStartAction(wpn) then begin
      SetActorKeyRepeatFlag(kfWPNHIDE, false);
    end;
  end;

  if ((_keyflags and kfDETECTOR)<>0) then begin
    if (wpn=nil) or (CanStartAction(wpn)) then begin
      SetActorKeyRepeatFlag(kfDETECTOR, false);
    end;
  end;

  if (wpn=nil) then exit;

  if (_keyflags and kfHEADLAMP)<>0 then begin
    if CanStartAction(wpn) then begin
      torch:=ItemInSlot(act, 10);
      if torch<>nil then OnActorSwithesTorch(torch);
      SetActorKeyRepeatFlag(kfHEADLAMP, false);
    end;
  end;

  if (_keyflags and kfNIGHTVISION)<>0 then begin
    if CanStartAction(wpn) then begin
      torch:=ItemInSlot(act, 10);
      if torch<>nil then OnActorSwithesNV(torch);
      SetActorKeyRepeatFlag(kfNIGHTVISION, false);
    end;
  end;

  if (_keyflags and kfQUICKKICK)<>0 then begin
    if CanStartAction(wpn) then begin
      OnActorKick();
      SetActorKeyRepeatFlag(kfQUICKKICK, false);
    end;
  end;


  if IsActionKeyPressedInGame(kWPN_ZOOM) then begin
    if not IsAimToggle() and CanAimNow(wpn) and not IsAimNow(wpn) then begin
      virtual_Action(wpn, kWPN_ZOOM, kActPress);
      SetActorKeyRepeatFlag(kfUNZOOM, false);
    end;
  end else if IsActionKeyPressedInGame(kWPN_ZOOM_ALTER) then begin
    if not IsAimToggle() and CanAimNow(wpn) and not IsAimNow(wpn) then begin
      virtual_Action(wpn, kWPN_ZOOM_ALTER, kActPress);
      SetActorKeyRepeatFlag(kfUNZOOM, false);
    end;
  end;

  if (_keyflags and kfUNZOOM)<>0 then begin
    if IsAimNow(wpn) then begin
      if CanLeaveAimNow(wpn) then begin
        if IsAimToggle() then begin
          virtual_Action(wpn, kWPN_ZOOM, kActPress);
        end else begin
          virtual_Action(wpn, kWPN_ZOOM, kActRelease);
        end;
      end;
    end else begin
      SetActorKeyRepeatFlag(kfUNZOOM, false);
    end;
  end;

  if (_keyflags and kfRELOAD)<>0 then begin
    if CanStartAction(wpn) then begin
      virtual_Action(wpn, kWPN_RELOAD, kActPress);
      SetActorKeyRepeatFlag(kfRELOAD, false);
    end;
  end;

  if (_keyflags and kfNEXTAMMO)<>0 then begin
    if CanStartAction(wpn) then begin
      virtual_Action(wpn, kWPN_NEXT, kActPress);
      SetActorKeyRepeatFlag(kfNEXTAMMO, false);
    end;
  end;

  if (_keyflags and kfGLAUNCHSWITCH)<>0 then begin
    if CanStartAction(wpn) then begin
      virtual_Action(wpn, kWPN_FUNC, kActPress);
      SetActorKeyRepeatFlag(kfGLAUNCHSWITCH, false);
    end;
  end;

  if (_keyflags and kfNEXTFIREMODE)<>0 then begin
    if CanStartAction(wpn) then begin
      virtual_Action(wpn, kWPN_FIREMODE_NEXT, kActPress);
      SetActorKeyRepeatFlag(kfNEXTFIREMODE, false);
    end;
  end;

  if (_keyflags and kfPREVFIREMODE)<>0 then begin
    if CanStartAction(wpn) then begin
      virtual_Action(wpn, kWPN_FIREMODE_PREV, kActPress);
      SetActorKeyRepeatFlag(kfPREVFIREMODE, false);
    end;
  end;

  if (_keyflags and kfLASER)<>0 then begin
    if CanStartAction(wpn) then begin
      virtual_Action(wpn, kLASER, kActPress);
      SetActorKeyRepeatFlag(kfLASER, false);
    end;
  end;

  if (_keyflags and kfTACTICALTORCH)<>0 then begin
    if CanStartAction(wpn) then begin
      virtual_Action(wpn, kTACTICALTORCH, kActPress);
      SetActorKeyRepeatFlag(kfTACTICALTORCH, false);
    end;
  end;

  if ((_keyflags and kfPDASHOW)<>0) then begin
    if (wpn=nil) or CanStartAction(wpn) then begin
      ShowPDAMenu();
      SetActorKeyRepeatFlag(kfPDASHOW, false);
    end;
  end;



{  //принудительный сброс бега во время действия
  if not (IsSprintOnHoldEnabled()) and GetActorActionState(act, actSprint, mstate_WISHFUL) and (not CanSprintNow(wpn)) then begin
    SetActorActionState(act, actSprint, false, mstate_WISHFUL);
  end; }

end;

procedure RestoreLastActorDetector(); stdcall;
var
  detector, act:pointer;
begin
  act:=GetActor();
  if not (WasLastDetectorHiddenManually()) then begin
    detector:=ItemInSlot(act, 9);
    if (detector<>nil) and (not GetDetectorActiveStatus(detector)) then begin
      SetDetectorForceUnhide(detector, true);
      SetActorActionState(act, actShowDetectorNow, true);
    end;
  end;
end;


procedure OnActorNewSlotActivated(act:pointer; slot:integer); stdcall;
var
  itm:pointer;
begin
  ResetWpnOffset();
  ResetActorFlags(act);
  ResetActivationHoldState();

  if (slot<=0) then ResetDof(1000);
  if slot<>4 then SetForcedQuickthrow(false);

  itm:=GetActorActiveItem();
  if (itm<>nil) then begin
    itm:=dynamic_cast(itm, 0, RTTI_CHudItemObject, RTTI_CWeapon, false);
    if itm<>nil then begin
      SetZoomStatus(itm, false);
      SetAimFactor(itm, 0);
    end;
  end;

  //TODO: перенести еду

{$ifdef USE_SCRIPT_USABLE_HUDITEMS}
  if _was_unprocessed_use_of_usable_huditem then begin
    //произошла смена итейбла, восстановим детектор
    //скриптово активировать детектор в юзабельных предметах нельзя - активируем движково
    RestoreLastActorDetector();
    _was_unprocessed_use_of_usable_huditem:=false;
  end;
{$endif}
end;

procedure UpdateSlots(act:pointer);
var
  sect:PChar;
  itm:pointer;
begin
  if _last_act_slot<>-1 then begin                      //проверка на инициализацию переменной на прошлых апдейтах
    if _last_act_slot<>GetActorActiveSlot() then begin
      _prev_act_slot:=_last_act_slot;
      OnActorNewSlotActivated(act, GetActorActiveSlot());
    end;
  end;

{$ifdef USE_SCRIPT_USABLE_HUDITEMS}
  //если в руках худовый юзабельный предмет, то выставим флаг для последующей обработки детектора

  itm:=GetActorActiveItem();
  if itm<>nil then begin
    sect:=GetSection(itm);
      if game_ini_line_exist(sect, 'gwr_changed_object') and game_ini_line_exist(sect, 'gwr_eatable_object') then begin
        _was_unprocessed_use_of_usable_huditem:=true;
      end;
  end;
{$endif}

  _last_act_slot:=GetActorActiveSlot();
end;


procedure DisableNVIfNeeded(act:pointer); stdcall;
var
  CTorch:pointer;
begin
  CTorch:=ItemInSlot(act, 10);
  if CTorch=nil then exit;
  if (IsNVSwitchedOn(CTorch) or IsNVPostprocessOn(CTorch)) and not CanUseNV(CTorch) then begin
    CTorch__SwitchNightVision(CTorch, false, true);
  end;
end;

procedure DisableTorchIfNeeded(act:pointer); stdcall;
var
  CTorch:pointer;
begin
  CTorch:=ItemInSlot(act, 10);
  if CTorch=nil then exit;
  if IsTorchSwitchedOn(CTorch) and not CanUseTorch(CTorch) then begin
    CTorch__Switch(CTorch, false);
  end;
end;

function IsPDAAnimatorInSlot():boolean; stdcall;
var
  slot:cardinal;
  itm:pointer;
begin
  result:=false;
  if GetActor()=nil then exit;
  slot:=game_ini_r_int_def(GetPDAShowAnimator(), 'slot', 0)+1;
  itm:=ItemInSlot(GetActor(), slot);
  if itm=nil then exit;
  result:=GetSection(itm)=GetPDAShowAnimator();
end;

function GetPDADirByAngle(angle:single):TCursorDirection;
begin
  if (angle>=0.393) and (angle<1.18) then begin
    result:=DownRight;
  end else if (angle>=1.18) and (angle<1.96) then begin
    result:=Down;
  end else if (angle>=1.96) and (angle<2.74) then begin
    result:=DownLeft;
  end else if (angle>=2.74) and (angle<3.53) then begin
    result:=Left;
  end else if (angle>=3.53) and (angle<4.32) then begin
    result:=UpLeft;
  end else if (angle>=4.32) and (angle<5.10) then begin
    result:=Up;
  end else if (angle>=5.10) and (angle<5.89) then begin
    result:=UpRight;
  end else begin
    result:=Right;  
  end;
end;

function GetPDAJoystickAnimationModifier():string;
begin
  case _pda_cursor_state.current_dir of
    Up:result:='_up';
    UpRight:result:='_up_right';
    Right:result:='_right';
    DownRight:result:='_down_right';
    Down:result:='_down';
    DownLeft:result:='_down_left';
    Left:result:='_left';
    UpLeft:result:='_up_left';
    Click:result:='_click';       
  else
    result:='';
  end;
end;


procedure virtual_CActor__IR_OnMouseMove(act:pointer; mouse_dx:integer; mouse_dy:integer); stdcall;
asm
  pushad
    mov ecx, act
    add ecx, $298 // cast CActor to input receiver
    mov edx, [ecx]
    mov eax, [edx+$18] // IR_OnMouseMove
    push mouse_dy
    push mouse_dx
    call eax
  popad
end;

function IsPDAShowToZoomNow():boolean;
begin
  result:=_need_pda_zoom;
end;

function NeedFastPdaZoom():boolean;
begin
  if IsSavePdaZoomState() then begin
    result:=_last_pda_zoom_state;
  end else begin
    result:=IsFastPdaZoom();
  end;
end;

function BlowoutAnimCondition(wpn:pointer):boolean; stdcall;
var
  blowout_level:single;
begin
  blowout_level:=ModifyFloatUpgradedValue(wpn, 'blowout_anim_level', game_ini_r_single_def(GetSection(wpn), 'blowout_anim_level', 1000));
  result:=(blowout_level<=CurrentElectronicsProblemsCnt());
end;

procedure PlanActorKickAnimator(kick_types_section:string);
var
  cnt, i:integer;
begin
  if length(_planned_kick_animator) > 0 then exit;

  cnt:=game_ini_r_int_def(PAnsiChar(kick_types_section), 'count', 0);
  if cnt<=0 then exit;

  i:= floor(random * cnt);

  _planned_kick_animator:=game_ini_read_string(PAnsiChar(kick_types_section), PAnsiChar('animator_'+inttostr(i)));
end;

function IsPlannedKickAnimator(itm:pointer; kick_types_section:string):boolean;
var
  sect:PAnsiChar;
  cnt, i:integer;
begin
  result:=false;

  cnt:=game_ini_r_int_def(PAnsiChar(kick_types_section), 'count', 0);
  if (itm=nil) or (cnt<=0) then exit;

  sect:=GetSection(itm);
  for i:=0 to cnt-1 do begin
    if game_ini_read_string(PAnsiChar(kick_types_section), PAnsiChar('animator_'+inttostr(i))) = sect then begin
      result:=true;
      break;
    end;
  end;
end;

var
  cached_blowout_disabling_level:cached_cfg_param_float;

procedure ActorUpdate(act:pointer); stdcall;
var
  itm, det, wpn:pointer;
  hud_sect:PChar;
  dt, ct:cardinal;
  anim_time:cardinal;
  treasure_time:cardinal;
  anm_name:PChar;

  ppe:PChar;
  ppe_start, ppe_end:cardinal;

  dir:TCursorDirection;
  angle:single;

  is_nv_enabled:boolean;
  contr_k:controller_mouse_control_params;

  ss:shared_str;
  canshoot:boolean;
  slot:cardinal;
  act_anm:boolean;
  tmpstr:string;

  act_conds:pCActorCondition;
  need_skip_cb_in_idle:boolean;

const
  PDA_CURSOR_MOVE_TREASURE:cardinal=2;
begin
  ct:=GetGameTickCount();
  dt:=GetTimeDeltaSafe(_last_update_time, ct);
  _last_update_time:=ct;

//  log(inttohex(cardinal(dynamic_cast(act, 0, RTTI_CActor, RTTI_CInventoryItemOwner, false)), 8));

  UpdateSlots(act);

  det:=ItemInSlot(act, 9);

  if det <> nil then begin
    if GetActorActionState(act, actShowDetectorNow) and (GetActiveDetector(act)=nil) then begin
      SetDetectorForceUnhide(det, true);
    end else if (GetCurrentState(det)=2) then begin //мы собрались убирать детектор. Назначим аниму рукам, если оружие не выполняет сейчас какое-то действие.
      itm:=GetActorActiveItem();
      if (itm<>nil) and WpnCanShoot(itm) then begin
        hud_sect:=GetHUDSection(itm);
        if (game_ini_line_exist(hud_sect, 'use_finish_detector_anim')) and (game_ini_r_bool(hud_sect, 'use_finish_detector_anim')) then begin
          if CanStartAction(itm) and (not IsHolderInSprintState(itm)) then
            PlayCustomAnimStatic(itm, 'anm_finish_detector', 'sndFinishDet');
        end;
      end;
    end;
  end else begin
    SetActorActionState(act, actShowDetectorNow, false);
  end;

//TODO: разобраться, что вынести в game для МП
  ProcessKeys(act);
  ProcessChangedGrenade(act);
  UpdateFOV(act);
  UpdateInertion(GetActorActiveItem());
  UpdateWeaponOffset(act, dt);
  ControllerMonster.Update(dt);
  UpdateElectronicsProblemsCnt(dt);

  if _jitter_time_remains>dt then _jitter_time_remains:=_jitter_time_remains-dt else _jitter_time_remains:=0;

  if (_lefthanded_torch.base.render<>nil) and ((GetActiveDetector(act) = nil) or not game_ini_r_bool_def(GetSection(GetActiveDetector(act)), 'torch_installed', false)) then begin
//    log('Destroy lefthand light');
    SwitchLefthandedTorch(false);
    DelTorchlight(@_lefthanded_torch.base);
    _torch_linked_detector:=nil;
  end;

  if (GetMaxJitterHealth()> GetActorHealth(act)) then begin
    SetHandsJitterTime(GetShockTime());
  end;

  itm:=GetActorActiveItem();

  if itm=nil then begin
    //[bug] баг - останавливаем эффектор анимации камеры оружия при его наличии, но остутствии оружия в руках
    if CCameraManager__GetCamEffector($12)<>nil then begin
      CCameraManager__RemoveCamEffector($12);
    end;
  end;

  if IsActorBurned() then begin
    tmpstr:=GetBurnAnimator();
    act_conds:=GetActorConditions(act);
    if (itm<>nil) and (GetSection(itm)=tmpstr) and (GetCurrentState(itm)<>EHudStates__eHidden) then begin
      CEntityCondition__ChangeBleeding_custom(@act_conds.base_CEntityCondition, game_ini_r_single_def(GetSection(itm), 'burn_restore', 0)*dt, (1 shl EHitType__eHitTypeBurn));
      if _need_fire_particle then begin
        CShootingObject__StartFlameParticles(itm);
        _need_fire_particle:=false;
      end;
    end else begin
      Messenger.SendMessage('gunsl_actor_burned', gd_stalker);
      CEntityCondition__ChangeBleeding_custom(@act_conds.base_CEntityCondition, GetActorBurnRestoreSpeed()*dt, (1 shl EHitType__eHitTypeBurn));
    end;
  end;

  if length(_planned_kick_animator) > 0 then begin
    //надо проиграть аниматор пинка с выбиванием оружия из рук
    if (itm<>nil) and (GetSection(itm)=_planned_kick_animator) and (length(GetActualCurrentAnim(itm)) > 0) then begin
      // уже играем
      _planned_kick_animator:='';
    end else if (itm<>nil) or (GetActiveDetector(act)<>nil) then begin
      //Если руки заняты - выбрасываем всё нафиг
      if ((itm<>nil) and (GetSection(itm)<>_planned_kick_animator)) or (GetActiveDetector(act)<>nil) then begin
        PerformDropFromActorHands();
        ActivateActorSlot__CInventory(0, true);
      end else begin
        if length(GetActualCurrentAnim(itm)) = 0 then begin
          //защита от потенциального "выбрасывания" предыдущего аниматора - в этом случае новый почему-то не запускается, всё просто "висит" в состоянии без оружия в руках до активации чего-нибудь
          ActivateActorSlot(1);
        end else begin
          _planned_kick_animator:='';
        end;
      end;
    end else begin
      OnActorSwithesSmth('disable_planned_kicks', PAnsiChar(_planned_kick_animator), nil, nil, 0, @FakeCallback, 0);
    end;
  end;

  //если в руках аниматор действия или премет без буфера с играющейся анимой действия - запускаем калбэк вручную
  if (@_action_animator_callback<>nil) then begin
    act_anm:=(itm<>nil) and IsItemActionAnimator(itm);
    if (itm<>nil) and (act_anm or ((GetBuffer(itm)=nil) and IsPending(itm) and (GetCurrentState(itm)=EHudStates__eIdle))) then begin
      anm_name:=GetActualCurrentAnim(itm);
      anim_time:=GetTimeDeltaSafe(GetAnimTimeState(itm, ANM_TIME_START), GetAnimTimeState(itm, ANM_TIME_CUR));
      treasure_time:=floor(game_ini_r_single_def(GetHUDSection(itm), PChar('mark_'+anm_name),100)*1000);

      need_skip_cb_in_idle:=act_anm and ((leftstr(anm_name, length('anm_nv')) = 'anm_nv') or (leftstr(anm_name, length('anm_headlamp')) = 'anm_headlamp'));

      if (treasure_time<anim_time) or (act_anm and (GetCurrentState(itm)=EHudStates__eIdle) and not need_skip_cb_in_idle) then begin
        _action_animator_callback(itm, _action_animator_param);
        _action_animator_callback:=nil;
        _action_animator_param:=0;
      end;
    end;
  end;

  //PPE
  if (itm<>nil) then begin
    anm_name:=GetActualCurrentAnim(itm);
    if game_ini_r_bool_def(GetHUDSection(itm), PChar('use_ppe_effector_'+anm_name), false) then begin
      anim_time:=GetTimeDeltaSafe(GetAnimTimeState(itm, ANM_TIME_START), GetAnimTimeState(itm, ANM_TIME_CUR));
      ppe:=game_ini_read_string(GetHUDSection(itm), PChar('ppe_effector_'+anm_name));
      ppe_start := floor(game_ini_r_single_def(GetHUDSection(itm), PChar('ppe_start_'+anm_name), 0)*1000);
      ppe_end := floor(game_ini_r_single_def(GetHUDSection(itm), PChar('ppe_end_'+anm_name), 100)*1000);

      if (anim_time>ppe_start) and (anim_time<ppe_end) then begin
        //включим рре, если он выключен
        if _action_ppe<0 then begin
          _action_ppe:=2014;
          add_pp_effector(ppe, _action_ppe, false);
          set_pp_effector_factor(_action_ppe, 1.0, 10000);
        end;
      end else begin
        //выключим рре, если он включен
        if _action_ppe>=0 then begin
          set_pp_effector_factor(_action_ppe, 0.001, 10000);
          remove_pp_effector(_action_ppe);
          _action_ppe:=-1;
        end;
      end;
    end else begin
      if (_action_ppe>=0) then begin
        set_pp_effector_factor(_action_ppe, 0.001, 10000);
        remove_pp_effector(_action_ppe);
        _action_ppe:=-1;
      end;
    end;
  end;

  //обработка анимированного ПДА
  //Общая идея - если у окна ПДА в статусе стоит "показывается" (в реале идет отрисовка в текстуру), то всучиваем предмет  ПДА актору
  //Если же пда "выключен - убираем этот предмет из рук.
  
  if IsPDAWindowVisible then begin
    //ПДА активирован.
    if not _was_pda_animator_spawned then begin
      //только что включился. Заспавним аниматор, если можно.
      if not OnActorSwithesSmth(nil, GetPDAShowAnimator(), nil, nil, kfPDASHOW, @FakeCallback, 0) then begin
        //почему-то не заспавнился... Вырубаем ПДА, пусть игрок подумает получше над тем, что ему надо :)
        HidePDAMenu();
      end else begin
        //все ок, заспавнилось, активация в обработчике аниматоров в апдейте
        _was_pda_animator_spawned:=true;
        _is_pda_lookout_mode:=true;
        _pda_cursor_state.last_moving_time:=GetGameTickCount();
        _pda_cursor_state.current_dir:=Idle;
        _pda_cursor_state.last_click_time:=GetPDA().base_CUIDialogWnd.base_CUIWindow.m_dwLastClickTime;
        _pda_cursor_state.dir_accumulator.x:=0;
        _pda_cursor_state.dir_accumulator.y:=0;
        _last_mouse_coord:=GetSysMousePoint();
        _need_pda_zoom:=NeedFastPdaZoom();
        _pda_blowout_anim_started:=false;
      end;
    end else begin
      //пда уже был включен и заспавнен. Убеждаемся, что до сих пор в слоте
      if not IsPDAAnimatorInSlot() then begin
        //почему-то не в слоте... Гасим ПДА, об остальном позаботится обработчик аниматоров в апдейте предмета
        HidePDAMenu();
        _was_pda_animator_spawned:=false;
      end else begin
        _last_pda_zoom_state:=_need_pda_zoom or ((GetActorActiveItem()<>nil) and IsAimNow(GetActorActiveItem()));
        if _need_pda_zoom and (GetActorActiveItem()<>nil) and (GetCurrentState(GetActorActiveItem()) = EHudStates__eIdle) then begin
          virtual_Action(GetActorActiveItem(), kWPN_ZOOM, kActPress);
          _need_pda_zoom:=false;
        end;
        if GetTimeDeltaSafe(_pda_cursor_state.last_moving_time)>GetPDAUpdatePeriod() then begin
          //Пришло время обновить аниму курсора
          if (_pda_cursor_state.last_click_time<>GetPDA().base_CUIDialogWnd.base_CUIWindow.m_dwLastClickTime) and (game_ini_r_bool_def(GetPDAShowAnimator(), 'use_clicks', true)) then begin
            dir:=Click;
            _pda_cursor_state.last_click_time:=GetPDA().base_CUIDialogWnd.base_CUIWindow.m_dwLastClickTime
          end else if (abs(_pda_cursor_state.dir_accumulator.x)<PDA_CURSOR_MOVE_TREASURE) and (abs(_pda_cursor_state.dir_accumulator.y)<PDA_CURSOR_MOVE_TREASURE) then begin
            //курсор неподвижен
            dir:=Idle;
          end else begin
            angle:=GetAngleByLegs(_pda_cursor_state.dir_accumulator.x, _pda_cursor_state.dir_accumulator.y);
            dir:=GetPDADirByAngle(angle);
          end;

          if (dir<>_pda_cursor_state.current_dir) and not (IsPending(GetActorActiveItem())) then begin
            //анима изменилась
            _pda_cursor_state.current_dir:=dir;
            SetActorActionState(act, actModNeedMoveReassign, true);
          end;

          //сбрасываем текущее состояние накопителя движения
          _pda_cursor_state.dir_accumulator.x:=0;
          _pda_cursor_state.dir_accumulator.y:=0;
          _pda_cursor_state.last_moving_time:=GetGameTickCount();
        end;
      end;
    end;
  end else begin
    //ПДА выключен
    if (GetActorActiveItem()<>nil) and (GetSection(GetActorActiveItem())=GetPDAShowAnimator()) then begin
      //если в рюкзаке завалялся его аниматор - восстанавливаем предыдущий слот
      if GetCurrentState(GetActorActiveItem()) = EHudStates__eBore then begin
        ActivateActorSlot__CInventory(GetActorPreviousSlot(), false); //ActivateActorSlot не сможет скрыть :(
      end else begin
        ActivateActorSlot(GetActorPreviousSlot());
      end;

      //Если ПДА играет аниму выхода из режима приближения - форсированно переходим в аниму убирание (полагаемся на миксовку, которая сгладит переход)
      //Само убирание будет отработано в OnAnimationEnd
      anm_name:=GetActualCurrentAnim(GetActorActiveItem());
      if (rightstr(anm_name, length('_aim_end')) = '_aim_end') and (GetCurrentState(GetActorActiveItem()) <> EHudStates__eHiding) then begin
        PlayHudAnim(GetActorActiveItem(), 'anm_hide_emerg', true)        
      end;      
    end;
    _was_pda_animator_spawned:=false;
  end;

  if (itm<>nil) and (WpnCanShoot(itm)) then begin
    CWeapon__ModUpdate(itm);
  end;

  if (itm<>nil) and game_ini_r_bool_def(GetHUDSection(itm), 'play_blowout_anim', false) then begin
    if (leftstr(GetActualCurrentAnim(itm), length('anm_blowout')) = 'anm_blowout') then begin
      if not BlowoutAnimCondition(itm) then begin
        virtual_CHudItem_SwitchState(itm, EHudStates__eIdle);
        CHudItem_StopAllSounds(itm);
      end;
    end else begin
      if BlowoutAnimCondition(itm) and not _pda_blowout_anim_started then begin
        SetActorActionState(act, actModNeedBlowoutAnim, true)
      end;
    end;
  end;

  if GetActorActionState(act, actModNeedBlowoutAnim) then begin
    if ((GetBuffer(itm)<>nil) and CanStartAction(itm)) or ((GetBuffer(itm)=nil) and (GetCurrentState(itm)=EHudStates__eIdle) ) then begin
      if not IsAimNow(itm) and (pos('_aim', GetActualCurrentAnim(itm))=0) then begin
        virtual_CHudItem_SwitchState(itm, EHudStates__eBore);
        _pda_blowout_anim_started:=true;
      end else begin
        if pos('_fastzoom', GetActualCurrentAnim(itm))=0 then begin
          if IsAimToggle() then virtual_Action(itm, kWPN_ZOOM, kActPress) else virtual_Action(itm, kWPN_ZOOM, kActRelease);
        end;
      end;
    end;
  end;

  itm:=ItemInSlot(act, 10);
  is_nv_enabled := false;
  if itm<>nil then begin
    is_nv_enabled:=IsNVSwitchedOn(itm);
    if GetCachedCfgParamFloatDef(cached_blowout_disabling_level, GetSection(itm), 'blowout_disabling_level', 10) <=CurrentElectronicsProblemsCnt() then begin
      if is_nv_enabled and (game_ini_r_single_def(GetSection(itm), 'blowout_disabling_probability', 1.0)>random) then begin
        if game_ini_r_bool_def(GetSection(itm), 'blowout_disable_only_nv_effector', true) then begin
          if IsNVPostprocessOn(itm) then begin
            CTorch__StopNvEffector(itm, game_ini_r_single_def(GetSection(itm), 'blowout_disabling_speed', 100000.0), game_ini_r_bool_def(GetSection(itm), 'blowout_disabling_sound', false));
          end;
        end else begin
          CTorch__SwitchNightVision(itm, false, true);
        end;
      end;
    end;
  end;
  if (is_nv_enabled) then begin
    script_call(GetNvMaskUpdateFunctorName(), 'true', dt);
  end else begin
    script_call(GetNvMaskUpdateFunctorName(), 'false', dt);
  end;

  //[bug] Баг оригинала с ПНВ - если надеть шлем/броню, включить ПНВ на ней и выбросить её из слота - эффект НВ останется
  DisableNVIfNeeded(act);
  DisableTorchIfNeeded(act);

  //Обработка смены худовой модели рук - если был запрос и оружия нет / оно скрыто, то меняем, иначе - ждем сокрытия
  if length(_hud_update_sect) > 0 then begin
    itm:=GetActorActiveItem();
    det:=GetActiveDetector(act);
    if (itm = nil) and (det = nil) then begin
      //Log('Changing hud');
      init_string(@ss);
      assign_string(@ss, PAnsiChar(_hud_update_sect));
      player_hud__load(@ss);
      _hud_update_sect:='';
      assign_string(@ss, nil);
    end else if (_slot_to_restore_after_outfit_change < 0) then begin
      canshoot:= (itm<>nil) and WpnCanShoot(itm);
      if (itm=nil) or (canshoot and CanStartAction(itm)) or (not canshoot and (GetCurrentState(itm) = EHudStates__eIdle)) then begin
        //Log('Hide slots for hud section change');
        ChangeSlotsBlockStatus(true);
        slot:=GetActorActiveSlot();
        if slot < 0 then slot:=0;
        _slot_to_restore_after_outfit_change:=slot;
        ActivateActorSlot(0);
        if (det <> nil) then begin
          ForceHideDetector(det);
        end;
      end;
    end;
  end else if (_slot_to_restore_after_outfit_change >= 0) then begin
    //Log('Restore slots after hud section change');
    itm:=GetActorActiveItem();    
    if itm = nil then begin
      RestoreLastActorDetector();
      if (_slot_to_restore_after_outfit_change > 0) and (ItemInSlot(act, _slot_to_restore_after_outfit_change)<>nil) then begin
        ActivateActorSlot(_slot_to_restore_after_outfit_change)
      end;
      ChangeSlotsBlockStatus(false);
    end;
    _slot_to_restore_after_outfit_change:=-1;    
  end;

  if GetCurrentControllerInputCorrectionParams().active then begin
    contr_k:=GetControllerMouseControlParams();
    if GetActorActionState(act, actMovingLeft, mState_REAL) then begin
      virtual_CActor__IR_OnMouseMove(act, floor(contr_k.keyboard_move_k*contr_k.min_offset), floor(contr_k.keyboard_move_k*contr_k.max_offset));
    end else if GetActorActionState(act, actMovingRight, mState_REAL) then begin
      virtual_CActor__IR_OnMouseMove(act, floor(contr_k.keyboard_move_k*contr_k.max_offset), floor(contr_k.keyboard_move_k*contr_k.max_offset));
    end else if GetActorActionState(act, actMovingForward, mState_REAL) then begin
      virtual_CActor__IR_OnMouseMove(act, floor(contr_k.keyboard_move_k*contr_k.min_offset), floor(contr_k.keyboard_move_k*contr_k.max_offset));
    end else if GetActorActionState(act, actMovingBack, mState_REAL) then begin
      virtual_CActor__IR_OnMouseMove(act, floor(contr_k.keyboard_move_k*contr_k.min_offset), floor(contr_k.keyboard_move_k*contr_k.min_offset));
    end;
  end;
end;

procedure ActorUpdate_Patch(); stdcall;
asm
  pushad
    push ecx
    call ActorUpdate
  popad
  mov eax, [esi+$200]
end;

function ItemInSlot(act:pointer; slot:integer):pointer; stdcall;
asm
  pushad
    mov @result, 0
    cmp act, 0
    je @finish

    push act
    call game_object_GetScriptGameObject
    cmp eax, 0
    je @finish

    mov ecx, eax
    push slot
    mov ebx, xrGame_addr
    add ebx, $1C87f0
    call ebx
    cmp eax, 0
    je @finish

    mov eax, [eax+4]
    cmp eax, 0
    je @finish
    
    sub eax, $e8
    mov @result, eax

    @finish:
  popad
end;


function CheckActorWeaponAvailabilityWithInform(wpn:pointer):boolean;
begin
  result:=false;
  if (GetActorActiveItem()<>wpn) then begin
    Messenger.SendMessage('gunsl_msg_take_wpn_into_hands');
    exit;
  end;

  if not (CanStartAction(wpn)) then begin
    Messenger.SendMessage('gunsl_msg_stop_actions');
    exit;
  end;
  result:=true;
end;

procedure SetActorKeyRepeatFlag(mask:cardinal; state:boolean; ignore_suicide:boolean=false);
begin
  if not ignore_suicide and IsActorSuicideNow() then exit;

  if state then begin
    _keyflags:=_keyflags or mask;
  end else begin
    _keyflags:=_keyflags and (not mask);
  end;
end;

function GetActorKeyRepeatFlag(mask:cardinal):boolean;
begin
  result:= (_keyflags and mask)>0;
end;


procedure ClearActorKeyRepeatFlags();
begin
  _keyflags:=0;
end;

procedure CActor__OnKeyboardPress_initiate(dik:cardinal); stdcall;
asm
  pushad
    call GetActor
    cmp eax, 0
    je @finish

    mov ecx, eax
    mov eax, xrgame_addr
    add eax, $2783C0

    push dik
    call eax

    @finish:
  popad
end;

function CActor__OnKeyboardPress(dik:cardinal):boolean; stdcall;
var
  act:pointer;
  wpn, det, itm:pointer;
  iswpnthrowable, canshoot, is_bino:boolean;
  state:cardinal;
  tmp_pchar:PChar;
begin

  //возвратить false, чтобы забыть про данное нажатие
  result:=true;

  act:=GetActor();
  if act = nil then exit;

  if (CDialogHolder__TopInputReceiver()<> nil) and not IsPDAWindowVisible() then begin
    result:=false;
    exit;
  end;

  det:=GetActiveDetector(act);
  wpn:=GetActorActiveItem();
  if (wpn<>nil) then begin
    iswpnthrowable:=IsThrowable(wpn);
    canshoot:=WpnCanShoot(wpn);
    is_bino:=IsBino(wpn);
    state:=GetCurrentState(wpn);
  end;

  if (dik=kJUMP) then begin
    result:=not (IsActorControlled() or IsActorSuicideNow() or IsActorPlanningSuicide() or IsControllerPreparing());
  end else if (dik >= kQUICK_USE_1) and (dik<=kQUICK_USE_4) then begin
    result:=not (IsActorControlled() or IsActorSuicideNow() or IsActorPlanningSuicide());
    if result then begin
      tmp_pchar:=GetQuickUseScriptFunctorName();
      if tmp_pchar<>nil then begin
        script_call(tmp_pchar, '', 1);
      end;
    end;
  end else if dik = kDETECTOR then begin
      if (wpn<>nil) then begin
        if
          (iswpnthrowable and ((state=EMissileStates__eReady) or (state=EMissileStates__eThrowStart) or (state=EMissileStates__eThrow) or (state=EMissileStates__eThrowEnd)))
          or
          (not iswpnthrowable and ((state=EWeaponStates__eReload) or (state=EWeaponStates__eSwitch) or (state=EWeaponStates__eFire) or (state=EWeaponStates__eFire2)))
          or
          (IsActionProcessing(wpn))
          or
          (canshoot or is_bino) and (IsAimNow(wpn) or IsHolderinAimState(wpn))
          or
          GetActorActionState(act, actModDetectorSprintStarted)
          or
          (GetCurrentState(wpn)<>EHudStates__eIdle)
          or
          ((GetBuffer(wpn)<>nil) and not CanStartAction(wpn))
        then begin
          result:=false;
        end;
      end;

      {if (GetActorActionState(act, actSprint) or GetActorActionState(act, actModSprintStarted)) then begin
        SetActorKeyRepeatFlag(kfDETECTOR, true);  //не сработает с детектором :(
        SetActorActionState(act, actSprint, false, mState_WISHFUL);
      end;}
  end else if ((dik=kWPN_FIRE) or (dik=kWPN_ZOOM)) then begin
    if (det<>nil) and (wpn<>nil) then begin
      if (IsKnife(wpn) or IsThrowable(wpn)) then begin
        if (GetCurrentState(det)=EHudStates__eShowing) then begin
          result:=false;
          if dik=kWPN_FIRE then SetActorKeyRepeatFlag(kfFIRE, true) else SetActorKeyRepeatFlag(kfZOOM, true);
        end else if GetActorActionState(act, actModDetectorSprintStarted) then begin
          SetActorActionState(act, actModDetectorSprintStarted, false);
        end;
      end;
    end;
  end else if ((dik=kWPN_1) or (dik=kWPN_2) or (dik=kWPN_3) or (dik=kWPN_4) or (dik=kWPN_5) or (dik=kWPN_6) or (dik=kARTEFACT)) then begin
    if (IsActorSuicideNow()) or IsActorPlanningSuicide() or ((wpn<>nil) and game_ini_line_exist(GetSection(wpn), 'gwr_changed_object') and game_ini_line_exist(GetSection(wpn), 'gwr_eatable_object')) or ((wpn<>nil) and IsItemActionAnimator(wpn)) then begin
      result:=false;
    end else if IsActorControlled() then begin
      result:=CanUseItemForSuicide(ItemInSlot(act, dik-kWPN_1+1));
    end else if (det<>nil) and (wpn<>nil) then begin
      if iswpnthrowable then begin
        if (state=EMissileStates__eReady) or (state=EMissileStates__eThrowStart) or (state=EMissileStates__eThrow) or (state=EMissileStates__eThrowEnd) then result:=false;
      end else if canshoot or is_bino then begin
        if IsAimNow(wpn) or IsHolderinAimState(wpn) then result:=false;
      end else begin
        if GetActorActionState(act, actModDetectorSprintStarted) then result:=false;
      end;
    end;
  end else if (dik=kQUICK_GRENADE) then begin
    if (GetActorActiveSlot()=4) or (GetActorSlotBlockedCounter(4)>0) or IsActorControlled() or (IsActorSuicideNow()) or (IsActorPlanningSuicide()) then exit;

    itm:=ItemInSlot(act, 4);
    if (itm<>nil) and game_ini_r_bool_def(GetSection(itm), 'supports_quick_throw', false) then begin
      SetForcedQuickthrow(true);
      ActivateActorSlot__CInventory(4, false);
    end;
  end else if (dik=kQUICK_KICK) then begin
    OnActorKick();
  end else if (dik=kUSE) then begin
    if IsActorBurned() and not IsActorControlled() and ((wpn=nil) or (GetSection(wpn)<>GetBurnAnimator())) then begin
      OnActorSwithesSmth('disable_burn_anim', GetBurnAnimator(), PChar('anm_burned'), 'sndBurned', 0, @FakeCallback, 0);
      _need_fire_particle:=true;
      result:=false;
    end;
  end;

end;

procedure CActor__IR_OnKeyboardPress_Patch();stdcall;
asm
  pushad
    push ebp
    call CActor__OnKeyboardPress
    cmp  al, 1
  popad
  jne @ignore

  mov ebx, 00000001
  test bl, cl
  @ignore:
end;

function CUIGameSP__IR_OnKeyboardPress_process_key(dik:cardinal):boolean; stdcall;
var
  itm, act:pointer;
begin
  if ((dik=get_action_dik(kWPN_ZOOM,0)) or (dik=get_action_dik(kWPN_ZOOM,1))) and IsPDAWindowVisible() then begin
    //если в руках аниматор и мы нажали клавишу зума - передаем команду аниматору
    itm:=GetActorActiveItem;
    if (itm<>nil) and not IsPending(itm) and (GetSection(itm)=GetPDAShowAnimator()) then begin
      // Манипуляции с координатой мыши нужны для того, чтобы курсор ПДА не скакал взад-вперед при переключениях в режим обзора и обратно (см. реализацию CUICursor::UpdateCursorPosition в движке)
      if IsAimNow(itm) then begin
        _last_mouse_coord:=GetSysMousePoint();
        if IsAimToggle() then virtual_Action(itm, kWPN_ZOOM, kActPress) else virtual_Action(itm, kWPN_ZOOM, kActRelease);
      end else begin
        SetSysMousePoint(_last_mouse_coord);
        virtual_Action(itm, kWPN_ZOOM, kActPress);
      end;
    end;
  end else if ((dik=get_action_dik(kWPN_ZOOM_ALTER,0)) or (dik=get_action_dik(kWPN_ZOOM_ALTER,1))) and IsPDAWindowVisible() then begin
    if not _is_pda_lookout_mode then begin
      _last_mouse_coord:=GetSysMousePoint();
    end else begin
      SetSysMousePoint(_last_mouse_coord);
    end;
    
    _is_pda_lookout_mode:=not _is_pda_lookout_mode;
//  end else if ((dik=get_action_dik(kCROUCH,0)) or (dik=get_action_dik(kCROUCH,1))) and IsPDAWindowVisible() then begin
//    CActor__OnKeyboardPress_initiate(kCROUCH);
//    act:=GetActor();
//    if act<>nil then SetActorActionState(act, actCrouch, GetActorActionState(act, actCrouch, mState_Real), mState_WISHFUL);
  end;
  result:=false;
end;

procedure CUIGameSP__IR_OnKeyboardPress_Patch(); stdcall;
asm
  mov eax, [esp+8]

  pushad
    push eax
    call CUIGameSP__IR_OnKeyboardPress_process_key
    cmp al, 0
  popad
  jne @finish_processing

  pop eax
  push ebx
  push edi
  mov edi, [esp+$0c]
  jmp eax

  @finish_processing:
  add esp, 4
  mov al, 1
  ret 4 //return from CUIGameSP::IR_OnKeyboardPress
end;


function GetActorPreviousSlot():integer; stdcall;
begin
  result:=_prev_act_slot;
end;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
procedure CActor__netSpawn(CActor:pointer); stdcall;
begin
  //TODO: Разобраться, что вынести в game для мп
  ResetCamHeight();
  ResetWpnOffset();
  ResetActorControl();
  ClearActorKeyRepeatFlags();
  ResetChangedGrenade();
  ResetActorFlags(CActor);
  ResetActivationHoldState();
  SetForcedQuickthrow(false);
  ResetBirdsAttackingState();
  ResetElectronicsProblems_Full();
  ElectronicsProblemsImmediateApply();
{$ifdef USE_SCRIPT_USABLE_HUDITEMS}
  _was_unprocessed_use_of_usable_huditem:=false;
{$endif}  
  _prev_act_slot:=-1;
  _last_act_slot:=-1;
  ResetDOF(1000);
  _thirst_value:=1;
  _jitter_time_remains:=0;

  _last_update_time:=GetGameTickCount();
  _action_animator_callback := nil;
  _action_animator_param := 0;
  _action_ppe:=-1;

  _sprint_tiredness:=0;
  _was_pda_animator_spawned:=false;

  _hud_update_sect:='';
  _slot_to_restore_after_outfit_change:=-1;

  ForgetDetectorAutoHide();

  _last_pda_zoom_state:=IsFastPdaZoom();
  _is_pda_lookout_mode:=false;
  _pda_blowout_anim_started:=false;
  _planned_kick_animator:='';

  _need_fire_particle:=false;
end;

procedure CActor__netSpawn_Patch(); stdcall;
asm
  pushad
    push esi
    call CActor__netSpawn
  popad

  pop edi //оригинальный код завершения метода
  pop esi
  pop ebp
  mov eax, 1
  pop ebx
  add esp, 8
  ret 4
end;


procedure CActor__net_Destroy(CActor:pointer); stdcall;
begin
  if _lefthanded_torch.base.render<>nil then begin
    SwitchLefthandedTorch(false);
    DelTorchlight(@_lefthanded_torch.base);
    _torch_linked_detector:=nil;
  end;

  if _action_ppe>=0 then begin
    //снимаем постэффект
    set_pp_effector_factor(_action_ppe, 0.001, 10000);
    remove_pp_effector(_action_ppe);
    _action_ppe:=-1;
  end;

  ForgetDetectorAutoHide();
end;

procedure CActor__net_Destroy_Patch(); stdcall;
asm
  pushad
    push esi
    call CActor__net_Destroy
  popad
  movzx eax, word ptr [esi+$9c8]
end;
//-----------------------------------------------------------------------------------
function GetSlotOfActorHUDItem(act:pointer; itm:pointer):integer; stdcall;
begin
  for result:=1 to 9 do begin
    if ItemInSlot(act, result)=itm then exit;
  end;
  result:=-1;
end;

procedure ActivateActorSlot(slot:cardinal); stdcall;
asm
  pushad
  pushfd

  call GetActor        //получаем актора

  test eax, eax
  je @finish

  mov eax, [eax+$2e4]   //получаем его CInventory
  test eax, eax
  je @finish

  mov ecx, slot
  mov [eax+$42], cx     //пишем желаемый слот актора

  @finish:
  popfd  
  popad
end;

function RecalcZoomFOV(scope_factor:single):single; stdcall;
var
  fov:single;
begin
  fov:=(GetBaseFOV()/2)*pi/180;
  result:=2*arctan(tan(fov)/scope_factor)*180/pi;
  //log(floattostr(fov));
  //log(floattostr(result));
end;

procedure ZoomFOV_Patch(); stdcall;
asm
  pushad
    push [esi+$498] //m_fCurrentZoomFactor
    call RecalcZoomFOV
  popad

  pop edi
  pop esi
  push edi
end;

procedure ResetZoomFov_Patch(); stdcall;
asm
  pushad
  push $3F800000
  push esi
  call SetZoomFactor
  popad
end;


var
  cached_fov_factor:cached_cfg_param_float;
  cached_hud_fov_factor_wpn:cached_cfg_param_float;
  cached_hud_fov_factor_scope:cached_cfg_param_float;
  cached_hud_fov_gl_zoom_factor:cached_cfg_param_float;
  cached_hud_fov_zoom_factor:cached_cfg_param_float;
  cached_hud_fov_alter_zoom_factor:cached_cfg_param_float;

procedure UpdateFOV(act:pointer);
var
    fov, zoom_fov, alter_zoom_fov, alter_zoom_factor, hud_fov, af:single;
    wpn, det, itm:pointer;
    buf:WpnBuf;
    zoom_fov_section:PAnsiChar;
const
  EPS=0.0001;
begin
  //Можно манипулировать FOV и HudFOV

  wpn:=GetActorActiveItem();
  det:=GetActiveDetector(act);

  if not game_ini_line_exist(GUNSL_BASE_SECTION, 'fov') then exit;
  fov:=GetBaseFOV();

  if (wpn<>nil) then begin
    fov := fov*GetCachedCfgParamFloatDef(cached_fov_factor, GetSection(wpn), 'fov_factor', 1.0);
  end else if (det<>nil) then begin
    fov := fov*GetCachedCfgParamFloatDef(cached_fov_factor, GetSection(det), 'fov_factor', 1.0);
  end;
  
  SetFOV(fov);
  alter_zoom_factor:=0;
  zoom_fov_section:=nil;

  fov:=GetBaseHudFOV();
  if (wpn<>nil) then begin
    hud_fov:=GetCachedCfgParamFloatDef(cached_hud_fov_factor_wpn, GetHUDSection(wpn), 'hud_fov_factor', 1.0);
    if (GetScopeStatus(wpn)=2) and IsScopeAttached(wpn) then begin
      hud_fov:=hud_fov*GetCachedCfgParamFloatDef(cached_hud_fov_factor_scope, GetCurrentScopeSection(wpn), 'hud_fov_factor', 1.0);
    end;
    
    if (IsAimNow(wpn) or (leftstr(GetActualCurrentAnim(wpn), length('anm_idle_aim'))='anm_idle_aim')) then begin
      buf:=GetBuffer(wpn);

      if buf<>nil then begin
        alter_zoom_factor:=buf.GetAlterZoomDirectSwitchMixupFactor();
        if CanUseAlterScope(wpn) and (buf.IsAlterZoomMode() or ((GetAimFactor(wpn)>0) and buf.IsLastZoomAlter())) then begin
          //Переходим в альтернативное прицеливание из обычного или уже полностью в альтернативном прицеливании
          alter_zoom_factor:=1-alter_zoom_factor;
        end;
      end;

      if ((GetGLStatus(wpn)=1) or ((GetGLStatus(wpn)=2) and IsGLAttached(wpn))) and IsGLEnabled(wpn) then begin
        zoom_fov:=GetCachedCfgParamFloatDef(cached_hud_fov_gl_zoom_factor, GetHUDSection(wpn), 'hud_fov_gl_zoom_factor', hud_fov);
        zoom_fov_section:=nil;
      end else if (GetScopeStatus(wpn)=2) and IsScopeAttached(wpn) then begin
        zoom_fov_section:=GetCurrentScopeSection(wpn);
      end else begin
        zoom_fov_section:=GetHUDSection(wpn);
      end;

      if zoom_fov_section<>nil then begin
        if alter_zoom_factor < EPS then begin
          zoom_fov:=GetCachedCfgParamFloatDef(cached_hud_fov_zoom_factor, zoom_fov_section, 'hud_fov_zoom_factor', hud_fov);
        end else if alter_zoom_factor > 1-EPS then begin
          zoom_fov:=GetCachedCfgParamFloatDef(cached_hud_fov_alter_zoom_factor, zoom_fov_section, 'hud_fov_alter_zoom_factor', zoom_fov);  
        end else begin
          zoom_fov:=GetCachedCfgParamFloatDef(cached_hud_fov_zoom_factor, zoom_fov_section, 'hud_fov_zoom_factor', hud_fov);
          alter_zoom_fov:=GetCachedCfgParamFloatDef(cached_hud_fov_alter_zoom_factor, zoom_fov_section, 'hud_fov_alter_zoom_factor', zoom_fov);
          zoom_fov:=zoom_fov+(alter_zoom_fov-zoom_fov)*alter_zoom_factor;
        end;
      end;

      af :=GetAimFactor(wpn);
      hud_fov:=hud_fov-(hud_fov-zoom_fov)*af;
    end;
    fov := fov*hud_fov;
  end else if (det<>nil) then begin
    hud_fov:=GetCachedCfgParamFloatDef(cached_hud_fov_factor_wpn, GetHUDSection(det), 'hud_fov_factor', 1.0);
    fov := fov*hud_fov;
  end;
  SetHudFOV(fov);
end;

procedure SetFOV(fov:single); stdcall;
asm
  push eax
  push ebx

  mov eax, fov
  mov ebx, xrgame_addr
  add ebx, $635C44
  mov [ebx], eax

  pop ebx
  pop eax
end;

function GetFOV():single; stdcall;
begin
asm
  mov eax, xrgame_addr
  add eax, $635C44
  mov eax, [eax]
  mov @result, eax
end;
end;

procedure SetHudFOV(fov:single); stdcall;
var
  koef:single;
begin
  koef:=fov/GetFOV;
  asm
    push eax
    push ebx

    mov eax, koef
    mov ebx, $490624
    mov [ebx], eax

    pop ebx
    pop eax
  end;
end;

procedure DropItem(act:pointer; item:pointer); stdcall;
asm
  pushad
  mov edx, act
  cmp edx, 0
  je @finish

  mov ebx, item
  cmp ebx, 0
  je @finish

  push edx
  call game_object_GetScriptGameObject
  mov edx, eax

  add ebx, $E8
  push ebx
  call game_object_GetScriptGameObject

  push eax
  mov ecx, edx  
  mov eax, xrgame_addr
  add eax, $1c7460
  call eax
  
  @finish:
  popad
end;

function CRenderDevice__GetCamPos():pointer; stdcall;
begin
asm
  mov eax, xrEngine_addr
  lea eax, [eax+$92ed8+$30]
  mov @result, eax
end;
end;

function CRenderDevice__GetCamDir():pointer; stdcall;
begin
asm
  mov eax, xrEngine_addr
  lea eax, [eax+$92ed8+$3C]
  mov @result, eax
end;
end;

function CRenderDevice__GetCamTop():pointer; stdcall;
begin
asm
  mov eax, xrEngine_addr
  lea eax, [eax+$92ed8+$48]
  mov @result, eax
end;
end;

function CRenderDevice__GetCamRight():pointer; stdcall;
begin
asm
  mov eax, xrEngine_addr
  lea eax, [eax+$92ed8+$54]
  mov @result, eax
end;
end;


{procedure CorrectPointFromWorldToHud(point:pFVector3); stdcall;
var
  cam_dir, cam_pos:FVector3;
  scale, p_len:single;
  v_to_p, project:FVector3;
begin
  cam_dir:=FVector3_copyfromengine(CRenderDevice__GetCamDir());
  cam_pos:=FVector3_copyfromengine(CRenderDevice__GetCamPos());

  v_to_p:=point^;
  v_sub(@v_to_p, @cam_pos);
  p_len:=v_projection_to_v(@v_to_p, @cam_dir);
  v_mul(@cam_dir, p_len);
  v_sub(@v_to_p, @cam_dir);
  v_mul(@v_to_p, cos(GetBaseFOV()*pi/180)/cos(GetBaseHudFOV()*pi/180));

  point^:=cam_pos;
  v_add(point, @cam_dir);
  v_add(point, @v_to_p);
end;

procedure CorrectDirFromWorldToHud(dir:pFVector3; pos:pFVector3); stdcall;
var
  point1, point2:FVEctor3;
begin
  point1:=pos^;
  point2:=point1;
  v_add(@point2, dir); 

  CorrectPointFromWorldToHud(@point1);
  CorrectPointFromWorldToHud(@point2);

  v_sub(@point2, @point1);
  v_normalize(@point2);
  dir^:=point2;
end;}


procedure CorrectDirFromWorldToHud(dir:pFVector3; pos:pFVector3; k:single); stdcall;
var
  tmp:FVector3;
  m:single;
begin
  tmp:=FVector3_copyfromengine(CRenderDevice__GetCamDir());
  m:=k*GetBaseFOV()/GetBaseHudFOV();
  v_sub(dir, @tmp);
  v_mul(dir, m);
  v_add(dir, @tmp);
  v_normalize(dir)
end;

function GetTargetDist():single; stdcall;
begin
asm
  pushad
  mov @result, 0
  call g_hud
  cmp eax, 0
  je @finish
  mov ecx, eax
  mov eax, xrgame_addr
  add eax, $4afe40
  call eax                 //CHudManager::GetCurrentRayQuery
  cmp eax, 0
  je @finish
  
  mov eax, [eax+4]
  mov @result, eax

  @finish:
  popad
end;
end;


function GetActorThirst():single; stdcall;
begin
  result:=_thirst_value;
end;


procedure RecreateLefthandedTorch(params_section:PChar; det:pointer); stdcall;
var
  defpos, defdir:FVector3;
begin
  if _lefthanded_torch.base.render<>nil then begin
    DelTorchlight(@_lefthanded_torch.base);
  end;
  NewTorchlight(@_lefthanded_torch.base, params_section);
  _lefthanded_torch.aim_offset.x:=game_ini_r_single_def(params_section, 'torch_aim_attach_offset_x', 0.0);
  _lefthanded_torch.aim_offset.y:=game_ini_r_single_def(params_section, 'torch_aim_attach_offset_y', 0.0);
  _lefthanded_torch.aim_offset.z:=game_ini_r_single_def(params_section, 'torch_aim_attach_offset_z', 0.0);

  v_zero(@defpos);
  v_zero(@defdir);

  // Уводим фонарь за пределы карты и направляем вверх - чтобы актор точно не увидел вспышку в момент спавна
  defpos.y:=1000;
  defdir.y:=1;
  SetTorchlightPosAndDir(@_lefthanded_torch.base, @defpos, @defdir);

  SwitchTorchlight(@_lefthanded_torch.base, false);
  SetWeaponMultipleBonesStatus(det, _lefthanded_torch.base.light_cone_bones, false);
  _torch_linked_detector:=det;
end;

function GetLefthandedTorchLinkedDetector():pointer; stdcall;
begin
  result:=_torch_linked_detector;
end;

procedure SwitchLefthandedTorch(status:boolean); stdcall;
var
  act, det:pointer;
begin
  if _lefthanded_torch.base.render=nil then exit;

  if _lefthanded_torch.base.enabled<>status then begin
    SwitchTorchlight(@_lefthanded_torch.base, status);
  end;

  act:=GetActor;
  if act=nil then exit;
  det:=GetActiveDetector(act);
  if det<>nil then begin
    SetWeaponMultipleBonesStatus(det, _lefthanded_torch.base.light_cone_bones, status);
  end;
end;

function GetLefthandedTorchParams():lefthanded_torchlight_params; stdcall;
begin
  result:=_lefthanded_torch;
end;

function HitMarkCondition():boolean;
begin
  //если false, то хитмарки отключаются
  result := GetCurrentDifficulty()<gd_master;
end;

procedure CActor__Hit_HitmarkCondition_Patch(); stdcall;
asm
  pushad
    call HitMarkCondition;
    cmp al, 1
  popad
  jne @finish
  cmp byte ptr[esi+$9ca], 0
  @finish:
end;

function IsTacticHudInstalled():boolean;
var
  act:pointer;
  helmet:pointer;
begin
  result:=false;
  act:=GetActor();
  if act<>nil then helmet:=ItemInSlot(act, 12) else helmet := nil;

  if helmet<>nil then begin
    helmet:=dynamic_cast(helmet, 0, RTTI_CInventoryItem, RTTI_CHelmet, false);
    if helmet<>nil then begin
      result:=FindIntValueInUpgradesDef(helmet, 'nearest_enemies_show_dist', -1) > 0;
    end;
  end;
end;


function ZoneMapCondition():boolean; stdcall;
begin
  result := GetCurrentDifficulty()<gd_veteran;

  if IsLensFrameNow() then begin
    result:=false;
  end else if not result and IsTacticHudInstalled() then begin
    result:=true;
  end;
end;

procedure CUIMainIngameWnd__Draw_zonemap_Patch(); stdcall;
asm
  pop eax
  pop edx
  push eax

  pushad
  push esi
  call ZoneMapCondition
  pop esi
  mov ecx, [esi+$60]
  mov [ecx+4], al //UIZoneMap->visible = al
  cmp al, 0
  popad

  je @finish

  push edx
  mov eax, xrgame_addr
  add eax, $45c300
  call eax   //UIMotionIcon->SetNoise

  mov ecx, [esi+$5c]
  mov edx, [ecx]
  mov eax, [edx+$60]
  call eax //UIMotionIcon->Draw();

  mov ecx, [esi+$60]

  mov eax, xrgame_addr
  add eax, $45ce90
  call eax //UIZoneMap->Render();

  @finish:
end;

function drawingame_conditions():boolean; stdcall;
begin
  if IsLensFrameNow() then begin
    result:=false;
  end else if IsInventoryShown() then begin
    result:=true;
  end else if ((GetHudFlags() and HUD_DRAW) <> 0) and ((GetHudFlags() and HUD_DRAW_RT) <> 0) then begin
    result := (GetCurrentDifficulty()<gd_master) or IsInventoryShown() or IsTacticHudInstalled();
  end else begin
    result:=false;
  end;
end;

procedure CUIGameCustom__Render_drawingame_Patch; stdcall;
asm
  pushad
    call drawingame_conditions
    cmp al, 0
  popad
  je @finish
  mov ecx, [ebp+$5c]
  mov eax, [ecx]
  mov edx, [eax+$60]
  call edx
  @finish:
end;

//Return pointer to CONSTANT char string!
function GetActorCameraMovingAnim(act:pointer; factor:psingle; anm_id:pcardinal):PChar; stdcall;
var
  wpn:pointer;
const
  HUD_PREFIX='cam_';
  eCEActorMoving:cardinal = 19;
  eCEActorMovingFwd:cardinal = 20;
  eCEActorMovingBack:cardinal = 21;
  eCEActorMovingLeft:cardinal = 22;
  eCEActorMovingRight:cardinal = 23;
  eCEActorMovingSprint:cardinal = 24;
  eCEActorMovingCrouchDown:cardinal = 25;
  eCEActorMovingCrouchUp:cardinal = 26;
  eCEActorMovingJump:cardinal = 27;
  eCEActorMovingFall:cardinal = 28;
  eCEActorMovingLanding:cardinal = 29;

  eCEActorRLookoutStart:cardinal = 30;
  eCEActorLLookoutStart:cardinal = 31;
  eCEActorRLookoutEnd:cardinal = 32;
  eCEActorLLookoutEnd:cardinal = 33;
begin
  result:=nil;
  anm_id^:=eCEActorMoving;
  factor^:=70;    //default value for 1
  wpn:=GetActorActiveItem();
  
  if not GetActorActionState(act, actRLookout, mState_REAL) and GetActorActionState(act, actRLookout, mState_WISHFUL) then begin
    result:='lookout_right_start';
    if (wpn<>nil) then begin
      if (IsAimNow(wpn)) then begin
        result:='lookout_right_start_aim';
      end;
      result:=game_ini_read_string_def(GetHudSection(wpn), PChar(HUD_PREFIX+result), result);
    end;
    anm_id^:=eCEActorRLookoutStart;

  end else if GetActorActionState(act, actRLookout, mState_REAL) and not GetActorActionState(act, actRLookout, mState_WISHFUL) then begin
    result:='lookout_right_end';
    if (wpn<>nil) then begin
      if (IsAimNow(wpn)) then begin
        result:='lookout_right_end_aim';
      end;
      result:=game_ini_read_string_def(GetHudSection(wpn), PChar(HUD_PREFIX+result), result);
    end;
    anm_id^:=eCEActorRLookoutEnd;

  end else if not GetActorActionState(act, actLLookout, mState_REAL) and GetActorActionState(act, actLLookout, mState_WISHFUL) then begin
    result:='lookout_left_start';
    if (wpn<>nil) then begin
      if (IsAimNow(wpn)) then begin
        result:='lookout_left_start_aim';
      end;
      result:=game_ini_read_string_def(GetHudSection(wpn), PChar(HUD_PREFIX+result), result);
    end;
    anm_id^:=eCEActorLLookoutStart;

  end else if GetActorActionState(act, actLLookout, mState_REAL) and not GetActorActionState(act, actLLookout, mState_WISHFUL) then begin
    result:='lookout_left_end';
    if (wpn<>nil) then begin
      if (IsAimNow(wpn)) then begin
        result:='lookout_left_end_aim';
      end;
      result:=game_ini_read_string_def(GetHudSection(wpn), PChar(HUD_PREFIX+result), result);
    end;
    anm_id^:=eCEActorLLookoutEnd;

  end else if GetActorActionState(act, actMovingLeft, mState_REAL) and not GetActorActionState(act, actMovingLeft, mState_OLD) then begin
    result:='strafe_left';
    if (wpn<>nil) then begin
      if (IsAimNow(wpn)) then begin
        result:='strafe_left_aim';
      end;
      result:=game_ini_read_string_def(GetHudSection(wpn), PChar(HUD_PREFIX+result), result);
    end;
    anm_id^:=eCEActorMovingLeft;
  end else if GetActorActionState(act, actMovingRight, mState_REAL) and not GetActorActionState(act, actMovingRight, mState_OLD) then begin
    result:='strafe_right';
    if (wpn<>nil) then begin
      if (IsAimNow(wpn)) then begin
        result:='strafe_right_aim';
      end;
      result:=game_ini_read_string_def(GetHudSection(wpn), PChar(HUD_PREFIX+result), result);
    end;
    anm_id^:=eCEActorMovingRight;
  end else if GetActorActionState(act, actMovingForward, mState_REAL) and not GetActorActionState(act, actMovingForward, mState_OLD) then begin
    result:='move_fwd';
    if (wpn<>nil) then begin
      if (IsAimNow(wpn)) then begin
        result:='move_fwd_aim';
      end;
      result:=game_ini_read_string_def(GetHudSection(wpn), PChar(HUD_PREFIX+result), result);
    end;
    anm_id^:=eCEActorMovingFwd;
  end else if GetActorActionState(act, actMovingBack, mState_REAL) and not GetActorActionState(act, actMovingBack, mState_OLD) then begin
    result:='move_back';
    if (wpn<>nil) then begin
      if (IsAimNow(wpn)) then begin
        result:='move_back_aim';
      end;
      result:=game_ini_read_string_def(GetHudSection(wpn), PChar(HUD_PREFIX+result), result);
    end;
    anm_id^:=eCEActorMovingBack;    
  end else if GetActorActionState(act, actCrouch, mState_REAL) and not GetActorActionState(act, actCrouch, mState_OLD) then begin
    result:='crouch_down';
    if (wpn<>nil) then begin
      if (IsAimNow(wpn)) then begin
        result:='crouch_down_aim';
      end;
      result:=game_ini_read_string_def(GetHudSection(wpn), PChar(HUD_PREFIX+result), result);
    end;
    anm_id^:=eCEActorMovingCrouchDown;
  end else if GetActorActionState(act, actCrouch, mState_REAL) and not GetActorActionState(act, actCrouch, mState_WISHFUL) then begin
    result:='crouch_up';
    if (wpn<>nil) then begin
      if (IsAimNow(wpn)) then begin
        result:='crouch_up_aim';
      end;
      result:=game_ini_read_string_def(GetHudSection(wpn), PChar(HUD_PREFIX+result), result);
    end;
    anm_id^:=eCEActorMovingCrouchUp;
  end else if GetActorActionState(act, actJump, mState_REAL) and not GetActorActionState(act, actJump, mState_OLD) then begin
    result:='jump';
    if (wpn<>nil) then begin
      if (IsAimNow(wpn)) then begin
        result:='jump_aim';
      end;
      result:=game_ini_read_string_def(GetHudSection(wpn), PChar(HUD_PREFIX+result), result);
    end;
    anm_id^:=eCEActorMovingJump;
  end else if GetActorActionState(act, actFall, mState_REAL) and not GetActorActionState(act, actFall, mState_OLD) then begin
    result:='fall';
    if (wpn<>nil) then begin
      if (IsAimNow(wpn)) then begin
        result:='fall_aim';
      end;
      result:=game_ini_read_string_def(GetHudSection(wpn), PChar(HUD_PREFIX+result), result);
    end;
    anm_id^:=eCEActorMovingFall;
  end else if GetActorActionState(act, actLanding2, mState_REAL) then begin
    result:='landing2';
    if (wpn<>nil) then begin
      if (IsAimNow(wpn)) then begin
        result:='landing2_aim';
      end;
      result:=game_ini_read_string_def(GetHudSection(wpn), PChar(HUD_PREFIX+result), result);
    end;
    anm_id^:=eCEActorMovingLanding;
  end else if GetActorActionState(act, actLanding, mState_REAL) then begin
    result:='landing';
    if (wpn<>nil) then begin
      if (IsAimNow(wpn)) then begin
        result:='landing_aim';
      end;
      result:=game_ini_read_string_def(GetHudSection(wpn), PChar(HUD_PREFIX+result), result);
    end;
    anm_id^:=eCEActorMovingLanding;
  end else if GetActorActionState(act, actSprint, mState_REAL) then begin
    result:='sprint';
    if (wpn<>nil) then begin
      result:=game_ini_read_string_def(GetHudSection(wpn), PChar(HUD_PREFIX+result), result);
    end;
    anm_id^:=eCEActorMovingSprint;        
  end;

//  if (result<>nil) then Log('CamAnim: '+result+', id='+inttostr(anm_id^));
end;

procedure CActor__g_cl_CheckControls_select_cam_anm_Patch; stdcall;
asm
  lea edi, [esp+4+$22c+$204] //последние байты eff_name все равно не будут использоваться в случае названия анимаци камеры, используем их для сохранения ИДшника 
  pushad
  lea eax, [esp+$34]
  push edi
  push eax
  push esi
  call GetActorCameraMovingAnim
  mov [esp+$1c], eax
  popad
  mov edi, eax
  test eax, eax
end;

procedure CActor__g_cl_CheckControls_change_anmid_for_checking_Patch(); stdcall;
asm
  mov ecx,[ebp+$544]
  pop eax
  push [esp+$22c+$204]
  jmp eax
end;

procedure CActor__g_cl_CheckControls_change_anmid_for_assigning_Patch(); stdcall;
asm
  mov edx, [esp+4+4+$22c+$204]
  mov [edi+$0c], edx
end;

procedure SelectBobbingParams(zoom_mode:boolean; is_limping:boolean; old_phase:psingle; old_freq:psingle; old_amp:psingle; mstate:cardinal; time:single; amp:psingle; st:psingle); stdcall;
var
  crouch_k, amp_tmp, freq_tmp, phase_tmp, dt:single;
  bep:bobbing_effector_params;
begin
  bep:=GetBobbingEffectorParams();

  if (mstate and actSprint) > 0 then begin
    amp_tmp:=bep.sprint.amplitude;
    freq_tmp:=bep.sprint.speed;
  end else if is_limping then begin
    if zoom_mode then begin
      amp_tmp:=bep.zoom_limp.amplitude;
      freq_tmp:=bep.zoom_limp.speed;
    end else begin
      amp_tmp:=bep.limp.amplitude;
      freq_tmp:=bep.limp.speed;
    end;
  end else if ((mstate and actCrouch)>0) and ((mstate and actSlow)>0) then begin
    if zoom_mode then begin
      amp_tmp:=bep.zoom_slow_crouch.amplitude;
      freq_tmp:=bep.zoom_slow_crouch.speed;
    end else begin
      amp_tmp:=bep.slow_crouch.amplitude;
      freq_tmp:=bep.slow_crouch.speed;
    end;
  end else if ((mstate and actCrouch)>0) then begin
    if zoom_mode then begin
      amp_tmp:=bep.zoom_crouch.amplitude;
      freq_tmp:=bep.zoom_crouch.speed;
    end else begin
      amp_tmp:=bep.crouch.amplitude;
      freq_tmp:=bep.crouch.speed;
    end;
  end else if ((mstate and actSlow)>0) then begin
    if zoom_mode then begin
      amp_tmp:=bep.zoom_walk.amplitude;
      freq_tmp:=bep.zoom_walk.speed;
    end else begin
      amp_tmp:=bep.walk.amplitude;
      freq_tmp:=bep.walk.speed;
    end;
  end else begin
    if zoom_mode then begin
      amp_tmp:=bep.zoom_run.amplitude;
      freq_tmp:=bep.zoom_run.speed;
    end else begin
      amp_tmp:=bep.run.amplitude;
      freq_tmp:=bep.run.speed;
    end;
  end;

  phase_tmp:=old_phase^;

  if (freq_tmp<>old_freq^) then begin
    //Подберем новую фазу так, чтобы при изменении частоты положение камеры осталось прежним
    phase_tmp:=(old_freq^-freq_tmp)*time+old_phase^;
    if phase_tmp > 2*pi then begin
      phase_tmp:=phase_tmp - floor(phase_tmp/(2*pi))*2*pi;
    end else if phase_tmp < 0 then begin
      phase_tmp:=phase_tmp+ ceil(abs(phase_tmp)/(2*pi))*2*pi;
    end;

    {Log('old_freq: '+floattostr(old_freq^)+
        ', need freq '+floattostr(freq_tmp)+
        ', time '+floattostr(time)+
        ', old phase '+floattostr(old_phase^)+
        ', need phase '+floattostr(phase_tmp));}
    old_freq^:=freq_tmp;
    old_phase^:=phase_tmp;
  end;

  if (amp_tmp<>old_amp^) then begin
    //Сделаем уменьшение амплитуды плавным
    //Log('old amp: '+floattostr(old_amp^)+', need amp '+floattostr(amp_tmp));
    dt:=bep.amplitude_delta*get_device_timedelta();
    if (amp_tmp>old_amp^) then begin
      if amp_tmp-old_amp^>dt then begin
        amp_tmp:=old_amp^+dt;
      end;
    end else begin
      if old_amp^-amp_tmp>dt then begin
        amp_tmp:=old_amp^-dt;
      end;
    end;
    old_amp^:=amp_tmp;
  end;

  amp^ := amp_tmp;
  st^ := time*freq_tmp+phase_tmp;
end;

procedure CEffectorBobbing__ProcessCam_Patch(); stdcall;
asm
  // original (not needed really)
  mulss xmm1,xmm0
  movss [esp+4+8],xmm1

  //ours
  lea edx, [esp+4+8] //float ST;
  lea ecx, [esp+4+$C] //float A;
  pushad
    push edx       //ST
    push ecx       //A
    push [edi+$18] //fTime
    push [edi+$30] // mstate;
    lea edx, [edi+$3c] //в реальности m_fAmplitudeRun, но мы там храним предыдущую амплитуду
    push edx
    lea edx, [edi+$48] //в реальности m_fSpeedRun, но мы там храним предыдущую частоту
    push edx
    lea edx, [edi+$4C] //там храним предыдущую фазу
    push edx
    movzx edx, byte ptr [edi+$38] //is_limping
    push edx
    movzx edx, byte ptr [edi+$39] //m_bZoomMode
    push edx
    call SelectBobbingParams
  popad
end;

procedure CActor__ActorUse_Patch_deadbodies(); stdcall;
//чтобы инвентарь не открывался при попытке тащить труп
asm
  mov edi, [esi+$54c]
  cmp byte ptr [edi+$71], 0
  jne @finish
  pushad
    push $2A //DIK_LSHIFT
    call IsKeyPressed
    cmp al, 00
  popad

  @finish:
end;

function CanMoveItem(CObject:pointer):boolean; stdcall;
begin
  result:=true;
  CObject:=dynamic_cast(CObject, 0, RTTI_CObject, RTTI_CInventoryItemOwner, false);
  if CObject=nil then exit;
  CObject:=CInventoryOwner__GetInventory(CObject);
  if CObject=nil then exit;
  result:=(CInventory__CalcTotalWeight(CObject)<GetMaxCorpseWeight);
  if not result then SendMessage('gunsl_corpse_overweighted', gd_stalker);
end;

procedure CActor__ActorUse_Patch_deadbodies_weight(); stdcall;
//чтобы нельзя было накидать кучу лута в труп, а потом тащить
asm
  mov eax, xrgame_addr
  add eax, $4fec00
  call eax
  test eax, eax
  jne @finish
  pushad
    push ebp
    call CanMoveItem
    cmp al, 01
  popad
  @finish:
end;

function IsHandJitter(itm:pointer):boolean; stdcall;
begin
 result := ((IsActorControlled() or IsSuicideAnimPlaying(itm) or IsControllerPreparing()) and not IsSuicideInreversible()) or (_jitter_time_remains>0);
end;

function GetHandJitterScale(itm:pointer):single; stdcall;
var
  restore_time:cardinal;
begin
  restore_time:=floor(game_ini_r_single_def(GetHUDSection(itm), 'jitter_stop_time', 3)*1000);
  if (IsActorControlled() or IsSuicideAnimPlaying(itm) or IsControllerPreparing()) or (_jitter_time_remains>restore_time) then begin
    result:=1;
  end else if _jitter_time_remains=0 then begin
    result:=0;
  end else begin
    result:= _jitter_time_remains/restore_time;
  end;
end;

procedure SetDisableInputStatus(status:boolean); stdcall;
asm
  push eax
  push ebx

  movzx eax, status
  mov ebx, xrgame_addr
  mov byte ptr [ebx+$64db8a], al 

  pop ebx
  pop eax
end;

procedure SetHandsJitterTime(time:cardinal); stdcall;
begin
  _jitter_time_remains:=time;
end;


procedure CorrectActorSpeed(); stdcall;
asm
  pushfd

  push eax
  movss [esp], xmm0

  pushad
  call GetCurrentSuicideWalkKoef
  popad

  movss xmm0, [esp]
  fstp [esp]
  mulss xmm0, [esp]

  add esp, 4
  mov eax, [esi+$594]

  popfd
end;

procedure add_pp_effector(fn:pchar; id:integer; cyclic:boolean); stdcall;
asm
  pushad

  movzx eax, cyclic
  push eax

  push id
  push fn
  mov eax, xrgame_addr
  add eax, $23ef00
  call eax

  add esp, $C

  popad
end;

procedure set_pp_effector_factor2(id:integer; f:single); stdcall;
asm
  pushad
    push f
    push id

    mov eax, xrgame_addr
    add eax, $242fd0
    call eax

    add esp, 8
  popad
end;

procedure set_pp_effector_factor(id:integer; f:single; f_sp:single); stdcall;
asm
  pushad
    push f_sp
    push f
    push id

    mov eax, xrgame_addr
    add eax, $243030
    call eax

    add esp, $C
  popad
end;

procedure remove_pp_effector(id:integer); stdcall;
asm
  pushad
    push id

    mov eax, xrgame_addr
    add eax, $242f80
    call eax

    add esp, 4
  popad
end;

procedure SetActorActionCallback(cb:TAnimationEffector);
begin
  _action_animator_callback:=cb;
end;

function GetActorActionCallback():TAnimationEffector;
begin
  result:=_action_animator_callback;
end;

function IsActorActionAnimatorAutoshow():boolean;
begin
  result:=_action_animator_autoshow;
end;

function CheckHeavyBreathAdditionalCondition(bs:single; health:single):single; stdcall;
begin
//  log('bs='+floattostr(bs^)+', hlth='+floattostr(health));
  if (health<GetActorMaxBreathHealth()) then begin
    result:=GetActorMaxBreathHealth()-health;
    if (result>GetActorBreathHealthSndDelta) or (bs>0.6) then
      result:=1.0
    else
      result:=0.6+0.4*result/GetActorBreathHealthSndDelta;
  end else begin
    result:=bs;
  end;
end;

procedure CheckHeavyBreathAdditionalCondition_Patch(); stdcall;
asm
  push ecx
  mov ebp, xrgame_addr
  add ebp, $27dd00
  call ebp //CEntityCondition::BleedingSpeed
  pop ecx

  pushad
    mov ecx, [ecx+4]
    push ecx
    push ecx
    fstp [esp]
    call CheckHeavyBreathAdditionalCondition
  popad
  lea ebp, [esi+$3a8]
end;


procedure CUIMotionIcon__Update_Patch(); stdcall;
asm
  pushad
    call IsActorPlanningSuicide
    test al, al
    jne @set_max
    call IsActorSuicideNow
    test al, al
    jne @set_max
    call IsActorAttackedByBirds
    test al, al
    jne @set_max
    call GetActorActiveItem
    cmp eax, 0
    je @finish
    push eax
    call IsSuicideAnimPlaying
    test al, al
    je @finish
    @set_max:
    mov [esi+$250], $42c80000  //m_luminosity = 100
    mov byte ptr [esi+$248], 1 //m_bchanged = true    
    @finish:
  popad
  movss xmm0, [esi+$250] //original;
end;

function NeedZoneBeep():boolean; stdcall;
var
  act, det:pointer;

begin
  result:=false;
  
  act:=GetActor();
  if act=nil then exit;

  det:=ItemInSlot(act, 9);
  if det=nil then exit;

  det:=dynamic_cast(det, 0, RTTI_CInventoryItem, RTTI_CCustomDetector, false);
  if det=nil then exit;

  result:=game_ini_r_bool_def(GetSection(det), 'detects_zones', true);

end;

procedure CUIHudStatesWnd__UpdateZones_Patch(); stdcall;
asm
  //original
  comiss xmm1, xmm0
  movss [esi+$1c], xmm0
  jna @finish //will not play sound already

  //check if actor has a detector
  pushad
    call NeedZoneBeep
    cmp al, 0
  popad

  xorps xmm5, xmm5 //для гарантии
  @finish:
end;

procedure CActor__IR_OnMouseMove_CorrectMouseSense(p_dx:pinteger; p_dy:pinteger; sense:pSingle); stdcall;
var
  wpn:pointer;
  sect:PChar;
  dx, dy:single;
  rot_ang, sense_scale_x, sense_scale_y:single;
  controller_correction:controller_input_correction_params;
  controller_offset:controller_input_random_offset;

const
  ROTATE_SCALER:single = 10;
  EPS:single=0.01;
begin
  wpn:=GetActorActiveItem();
  if (wpn<>nil) and (IsAimNow(wpn)) then begin
    if (IsScopeAttached(wpn)) and (GetScopeStatus(wpn)=2) and not IsAlterZoom(wpn) then begin
      sect:=game_ini_read_string(GetCurrentScopeSection(wpn), 'scope_name');
    end else begin
      sect:=GetSection(wpn);
    end;

    if not IsGrenadeMode(wpn) then
      sense^:=sense^*ModifyFloatUpgradedValue(wpn, 'zoom_mouse_sense_koef', game_ini_r_single_def(sect, 'zoom_mouse_sense_koef', 1.0))
    else
      sense^:=sense^*game_ini_r_single_def(sect, 'zoom_gl_mouse_sense_koef', 1.0);
  end;

  controller_correction:=GetCurrentControllerInputCorrectionParams();
  if controller_correction.reverse_axis_y then begin
    p_dy^:=(-1) * p_dy^;
  end;

  rot_ang:=controller_correction.rotate_angle;
  sense_scale_x:=controller_correction.sense_scaler_x;
  sense_scale_y:=controller_correction.sense_scaler_y;

  if (abs(rot_ang) > EPS) or (abs(sense_scale_x-1) > EPS) or (abs(sense_scale_y-1) > EPS) then begin
    //так как dx и dy интовые и маленькие - увеличим их за счет уменьшения сенсы
    sense^:=sense^ / ROTATE_SCALER;
    dx:=ROTATE_SCALER * p_dx^ * sense_scale_x;
    dy:=ROTATE_SCALER * p_dy^ * sense_scale_y;

    if (abs(rot_ang) > EPS) then begin
      //Довернем вектор (dx, dy) на угол rotate_angle
      p_dx^:=floor(dx*cos(rot_ang)+dy*sin(rot_ang));
      p_dy^:=floor(dy*cos(rot_ang)-dx*sin(rot_ang));
    end else begin
      p_dx^:=floor(dx);
      p_dy^:=floor(dy);
    end;

    // Тряску нужно применять после того, как применили sense_scale, чтобы она не масштабировалась, также учитываем наши манипуляции с ROTATE_SCALER
    controller_offset:=GetControllerInputRandomOffset();
    p_dx^:=p_dx^ + floor(controller_offset.offset_x * ROTATE_SCALER);
    p_dy^:=p_dy^ + floor(controller_offset.offset_y * ROTATE_SCALER);
  end else begin
    controller_offset:=GetControllerInputRandomOffset();
    p_dx^:=p_dx^ + controller_offset.offset_x;
    p_dy^:=p_dy^ + controller_offset.offset_y;
  end;
end;

procedure CActor__IR_OnMouseMove_CorrectMouseSense_Patch(); stdcall;
asm
  //original
  push ebp
  mov ebp, xrgame_addr
  add ebp, $521F20
  fmul [ebp]
  fstp [esp+$10]

  lea ebp, [esp+$10]
  pushad
  push ebp // sense
  add ebp, $18
  push ebp //ptr to dy
  sub ebp, 4
  push ebp //ptr to dx
  call CActor__IR_OnMouseMove_CorrectMouseSense
  popad
  pop ebp

  //original
  mov eax,[esp+$20] // dx --> eax
  test eax, eax
end;

procedure OnStep(id:cardinal); stdcall;
const
  f:PChar = 'gunsl_exo.on_step_sound';
begin
  script_call(f, nil, id);
end;

procedure CStepManager__material_sound__play_next_OnStepSnd(); stdcall;
asm
  sbb eax, eax
  and eax, 02

  pushad
    movzx eax, word ptr [ebp+$a4]
    push eax
    call OnStep
  popad
end;

function GetCameraManager():pointer; stdcall;
begin
asm
  pushad
    call GetLevel
    mov edi, [eax+$486BC]
    mov ecx, [edi+$544]
    mov @result, ecx
  popad
end;
end;

function CCameraManager__GetCamEffector(index:cardinal):pointer; stdcall;
asm
  pushad
    call GetCameraManager
    test eax, eax
    je @finish

    mov ecx, eax
    push index
    mov eax, xrengine_addr
    add eax, $2C200
    call eax

    @finish:
    mov @result, eax
  popad
end;

procedure CCameraManager__RemoveCamEffector(index:cardinal); stdcall;
asm
  pushad
    call GetCameraManager
    test eax, eax
    je @finish

    mov ecx, eax
    push index
    mov eax, xrengine_addr
    add eax, $2C390
    call eax

    @finish:
  popad
end;

function CDialogHolder__IR_UIOnMouseMove(dx, dy:integer):boolean; stdcall;
const
  ACCUMULATOR_RESET_PERIOD:cardinal=100;
begin

  if _is_pda_lookout_mode and IsPDAWindowVisible() and not IsMainMenuActive() then begin
    result:=false;
    exit;
  end else if not IsMainMenuActive() and IsPDAWindowVisible() then begin
    _pda_cursor_state.dir_accumulator.x:=_pda_cursor_state.dir_accumulator.x+dx;
    _pda_cursor_state.dir_accumulator.y:=_pda_cursor_state.dir_accumulator.y+dy;
  end;

  result:=true;
end;

procedure CDialogHolder__IR_UIOnMouseMove_Patch(); stdcall;
asm
  mov esi, esp
  pushad
    push [esi+$18]
    push [esi+$14]
    call CDialogHolder__IR_UIOnMouseMove
    cmp al, 0
  popad

  je @finish
  mov esi, [ecx-8]
  test esi, esi

  @finish:
end;

procedure MakeImpossibleRLLookout(act:pointer); stdcall;
begin
  if GetActorActionState(act, actRLookout, mState_WISHFUL) and GetActorActionState(act, actLLookout, mState_WISHFUL) then begin
    SetActorActionState(act, actRLookout, false, mState_WISHFUL);
    SetActorActionState(act, actLLookout, false, mState_WISHFUL);
  end;
end;

procedure CActor__IR_OnKeyboardHold_Patch(); stdcall;
asm
  pushad
  sub esi, $298
  push esi
  call MakeImpossibleRLLookout
  popad
  fstp st(0)
  pop edi
  pop ebx
  pop esi
  ret 4
end;

function GetEntityPosition(e:pointer):pFVector3; stdcall;
asm
  mov eax, e
  add eax, $80
  mov @result, eax
end;

function GetEntityDirection(e:pointer):pFVector3; stdcall;
asm
  mov eax, e
  add eax, $70
  mov @result, eax
end;


procedure OnActorHit(act:pointer; hit:pSHit); stdcall;
begin
  if IsActorControlled() and (hit.whoId = hit.DestID) and (hit.power>0.3) and ( (hit.hit_type = EHitType__eHitTypeFireWound) or (hit.hit_type = EHitType__eHitTypeExplosion)) then begin
    hit.power:=hit.power * 100000;
    KillActor(act, act);
  end;
end;

procedure OnActorHit_Patch; stdcall;
asm
  pushad
    push edi
    push ecx
    call OnActorHit
  popad
  //original
  mov eax,[edi+$34]
  test eax,eax
end;

function CanActorTakeItems(inventoryitem:pointer):boolean; stdcall;
var
  sect:PAnsiChar;
begin
  result:=true;
  if IsActorControlled() or IsActorSuicideNow() or IsActorPlanningSuicide() then begin
    result:=false;
    sect:=GetSection(inventoryitem);
    if (sect<>nil) and game_ini_r_bool_def(sect, 'can_take_when_controlled', false) then begin
      result:=true;
    end;
  end;
end;

procedure CInventory__CanTakeItem_Conditions(); stdcall;
asm
  pop edx     //ret addr
  add esp, 4  //orig code
  test eax, eax
  je @normal

  pushad
    push [esp+$2c]
    call CanActorTakeItems
    test al, al
  popad
  jne @normal
  //брать предмет нельзя, выходим
  pop edi
  xor eax, eax  
  pop esi
  ret 4

  @normal:
  test eax, eax
  jmp edx
end;

function GetActorTorchDist():single; stdcall;
//Возвратить дистанцию засвета или -1, если света нет
var
  act:pointer;
  CTorch:pointer;
  itm:pointer;
  buf:WpnBuf;
begin
  result:=-1;
  act:=GetActor();
  if act=nil then exit;

  //Включен ли налобный фонарь
  CTorch:=ItemInSlot(act, 10);
  if (CTorch<>nil) and IsTorchSwitchedOn(CTorch) then begin
    result:=GetHeadlampTreasureDist;
    exit;
  end;

  //Включен ли детектор-фонарь
  if (GetLefthandedTorchParams().base.render<>nil) and (GetLefthandedTorchParams().base.enabled) then begin
    result:=GetLefthandedTorchTreasureDist;
  end;
  if result > 0 then exit;

  //Включен ли тактический фонарь на оружии
  itm:=GetActorActiveItem();
  if itm<>nil then begin
    buf:=GetBuffer(itm);
    if buf<>nil then begin
      if buf.IsTorchInstalled() and buf.IsTorchEnabled() then begin
        result:=GetWeaponTorchTreasureDist;
      end;
    end;
  end;
end;

function GetObjectSeePointLevel(o:pointer; point:FVector3):cardinal; stdcall;
var
  vdiff, object_point, object_dir:FVector3;
  o_dist, o_cos:single;
  rq:rq_result;
const
  head_correction_value:single=2;
begin
  result:=0;

  object_point:=FVector3_copyfromengine(GetEntityPosition(o));
  object_dir:=FVector3_copyfromengine(GetEntityDirection(o));
  object_point.y:=object_point.y+head_correction_value; //Коррекция на высоту глаз

  vdiff:=point;
  v_sub(@vdiff, @object_point); //вектор от объекта к проверяемой точке

  o_dist:=v_length(@vdiff); //расстояние от объекта до  проверяемой точки

  v_normalize(@vdiff);

  o_cos:=GetAngleCos(@object_dir, @vdiff);
  if o_cos < 0 then exit;

  rq:=TraceAsView_RQ(@object_point, @vdiff, o);

  if rq.range*1.01 >= o_dist then begin
    if o_dist <= GetLightPalevoDist() then begin
      //log('palevo');
      result:=2;
      exit;
    end else if o_dist <= GetLightSeeDist() then begin
      //log('see');
      result:=1;
      exit;
    end;
  end;
end;

function IsObjectTorched(o:pointer):cardinal; stdcall;
//Вернуть 0 -если палева нет, 1 - если палево среднее, 2-если сильное(будет звук стрельбы)
var
  rq:rq_result;
  torch_dist:single;
  pcampos, pcamdir:pFVector3;
  light_point:FVector3;
  res1, res2:cardinal;
begin
  result:=0;
  torch_dist:=GetActorTorchDist();
  if torch_dist < 0 then exit;

  pcampos:=CRenderDevice__GetCamPos();
  pcamdir:=CRenderDevice__GetCamDir();

  rq:=TraceAsView_RQ(pcampos, pcamdir, GetActor());
  rq.range:=rq.range*0.99;
  if (rq.O = o) and (torch_dist >= rq.range) then begin
    //Светим прямо на объект
    result:=2;
    exit;
  end;

  //Если точка, в которую мы светим, или точка, из которой мы светим, видна объекту - палим это
  res1:=0;
  res2:=0;

  if rq.range <= torch_dist then begin
    light_point:=FVector3_copyfromengine(pcamdir);
    v_mul(@light_point, rq.range);
    v_add(@light_point, pcampos);
    res1:=GetObjectSeePointLevel(o, light_point);
  end;

  light_point:=FVector3_copyfromengine(pcampos);
  res2:=GetObjectSeePointLevel(o, light_point);
  result:=max(res1, res2);
end;

procedure CBaseMonster__shedule_Update_Patch(); stdcall;
const
  //SOUND_TYPE_WEAPON | SOUND_TYPE_AMBIENT
  GUNS_TORCH_LIGHT_SND:cardinal=$80000080;

  //SOUND_TYPE_WEAPON | SOUND_TYPE_SHOOTING | SOUND_TYPE_AMBIENT
  //GUNS_TORCH_LIGHT_PALEVO_SND:cardinal=$80200080;
  GUNS_TORCH_LIGHT_PALEVO_SND:cardinal=$80200000;
asm
  pushad
  push esi
  call IsObjectTorched
  
  cmp eax, 0
  je @no_torch
  cmp eax, 1
  jne @palevo
  mov edi, GUNS_TORCH_LIGHT_SND
  jmp @pushargs

  @palevo:
  mov edi, GUNS_TORCH_LIGHT_PALEVO_SND

  @pushargs:
  push $42c80000 //power
//  call CRenderDevice__GetCamPos
  push esi
  call GetEntityPosition

  push eax // position
  push 0 //user_data
  push edi //sound_type

  call GetActor
  push eax //who

  lea ecx, [esi+$34c]
  mov edx,[ecx]
  mov eax,[edx]
  call eax
  @no_torch:
  popad
end;

procedure CCustomMonster__shedule_Update_Patch(); stdcall;
asm
  push esi
  lea esi, [ebp-$44]
  call CBaseMonster__shedule_Update_Patch
  pop esi

  //original
  mov edx, [ebp+$3e8]
end;

procedure CAI_Stalker__shedule_Update_Patch(); stdcall;
asm
  push esi
  lea esi, [ebx-$44]
  call CBaseMonster__shedule_Update_Patch
  pop esi
  
  //original
  mov edx,[ebx+$254]
end;

procedure OnMonsterHit(h:pSHit); stdcall;
var
  source, dest:pointer;
  boar, act:pointer;
  stamina:single;
  itm:pointer;
  sect:PAnsiChar;
  slot:cardinal;
  dropped:boolean;
  cond_dec:single;
  hit_params:boar_hit_params;

  look_v:FVector3;
  is_actor_see_monster:boolean;
begin
  dest:=GetObjectById(h.DestID);
  act:=GetActor();
  if (dest<>nil) and (dest = act) then begin
    source:=GetObjectById(h.whoId);
    boar:=dynamic_cast(source, 0, RTTI_CObject, RTTI_CAI_Boar, false);
    if boar<>nil then begin
      itm:=GetActorActiveItem();
      stamina:=GetActorStamina(act);

      look_v:=FVector3_copyfromengine(CRenderDevice__GetCamdir());
      is_actor_see_monster:=GetAngleCos(@h.dir, @look_v) < 0;

      if stamina > h.power then begin
        SetActorStamina(act, stamina-h.power);
      end else if itm = nil then begin
        if is_actor_see_monster then begin
          PlanActorKickAnimator('boar_front_kicks');
        end else begin
          PlanActorKickAnimator('boar_back_kicks');
        end;
      end else begin
        sect:=GetSection(itm);
        slot:=game_ini_r_int_def(sect, 'slot', 2);
        dropped:=false;
        if (slot<>1) or (random < (h.power - stamina)) then begin
          PerformDropFromActorHands();
          if is_actor_see_monster then begin
            PlanActorKickAnimator('boar_front_kicks');
          end else begin
            PlanActorKickAnimator('boar_back_kicks');
          end;
          dropped:=true;
        end;

        if dropped and (dynamic_cast(itm, 0, RTTI_CHudItemObject, RTTI_CWeaponMagazined, false)<>nil) then begin
          hit_params:=GetBoarHitParams();
          cond_dec:=hit_params.min_condition_decrease + random * (hit_params.max_condition_decrease - hit_params.min_condition_decrease);
          cond_dec:=GetCurrentCondition(itm)-cond_dec;
          if cond_dec < 0 then cond_dec:=0;
          SetCondition(itm, cond_dec);
        end;

        SetActorStamina(act, 0);
      end;
    end;
  end;
end;

procedure CBaseMonster__HitEntity_WeaponDrop_Patch();stdcall;
asm
  //original
  movss [esp+$78+4], xmm0
  mov [esp+$7c+4], eax

  pushad
    push ecx //SHit*
    call OnMonsterHit
  popad

  ret
end;

procedure CorrectActorPhysicsHit(phit:pSHit); stdcall;
begin
  if GetActorActionState(GetActor(), actFall, mstate_REAL) then begin
    phit.power:=phit.power*GetActorFallHitKoef();
  end;
end;

procedure CActor__g_Physics_FallHit_Patch(); stdcall;
asm
  lea edx, [esp+$40] // HDS
  pushad
  push edx
  call CorrectActorPhysicsHit
  popad
  lea edx,[esp+$88] // original code
end;

function GetBoosterFromConditions(cond:pCEntityCondition; booster_type:cardinal):pSBooster; stdcall;
begin
  result:=pSBooster(FindItemInIntKeyMap(@cond.m_booster_influences.data, booster_type));
end;

function CanIgnoreLimping(conds:pCActorCondition):boolean; stdcall;
var
  energy_booster:pSBooster;
begin
  result:=false;
  energy_booster:=GetBoosterFromConditions(@conds.base_CEntityCondition, eBoostPowerRestore);
  if energy_booster<>nil then begin
    result:=true;
  end;
end;

procedure CActor__CanMove_Patch();stdcall;
asm
  pushad
  push ecx
  call CanIgnoreLimping
  test al, al
  popad

  je @enable_limping
  mov byte ptr [ecx+$1F1],00
  jmp @finish

  @enable_limping:
  mov byte ptr [ecx+$1F1],01

  @finish:
end;

function GetActorConditions(act:pointer):pCActorCondition; stdcall;
begin
  asm
    mov eax, act
    mov eax, [eax+$97c]
    mov @result, eax
  end;
end;

procedure ModifyObjectHitBeforeProcessing(h:pSHit); stdcall;
begin
  // Модифицируем поля в хите перед тем, как отдать его на обработку пораженному объекту
  if h.hit_type = EHitType__eHitTypeBurn then begin
    h.add_wound:=1;
  end;
end;

procedure CGameObject__OnEvent_addwoundonhit_Patch(); stdcall;
asm
  // original
  mov edx,[eax+$E8]
  lea ecx,[esp+$14]

  pushad
  push ecx
  call ModifyObjectHitBeforeProcessing
  popad

end;

procedure ScaleWoundByHitType(obj:pointer; hit_power:psingle; hit_type:cardinal); stdcall;
var
  factor1, factor2:single;
  sect:PAnsiChar;
begin
  sect:=get_string_value(GetCObjectSection(obj));
  sect:=game_ini_read_string_def(sect, 'condition_sect', sect);
  
  factor1:=game_ini_r_single_def('gunslinger_wound_factors', PAnsiChar('wound_factor_for_hit_type_'+inttostr(hit_type)), 1.0);
  factor2:=game_ini_r_single_def(sect, PAnsiChar('wound_factor_for_hit_type_'+inttostr(hit_type)), 1.0);

  // log('Section '+sect+', hit_type '+inttostr(hit_type)+', factor1 is '+floattostr(factor1)+', factor2 is '+floattostr(factor2));

  hit_power^:=hit_power^*factor1*factor2;
end;

procedure CEntityCondition__AddWound_scalewoundsize_Patch(); stdcall;
asm
  lea esi, [esp+$14] //hit_power
  mov eax, [esp+$18] //hit_type

  pushad
  push eax
  push esi
  push [ecx+$44] // this->m_object
  call ScaleWoundByHitType
  popad

  //original
  mov esi, ecx
  mov eax, [esi+$48]
end;

function GetMinFireParticleForDeadEntities():cardinal;
begin
  result:=game_ini_r_int_def('entity_fire_particles', 'min_burn_time_dead', 5000);
end;

procedure CEntityAlive__UpdateFireParticles_deadfire_Patch(); stdcall;
asm
  pushad
  mov ecx, edi
  mov eax, xrgame_addr
  add eax, $40aa0
  call eax // CEntity::g_Alive
  test eax, eax
  popad

  jne @alive
  
  lea eax, [esp+$8] // адрес аргумента с временем жизни
  pushad
  push eax
  call GetMinFireParticleForDeadEntities
  pop ecx
  mov [ecx], eax
  popad

  @alive:
  //original
  fldcw [esp+$1c]
  push [esp]
  mov [esp+4], esi
end;

procedure CEntityAlive__shedule_Update_updateparticles_Patch(); stdcall;
asm
  pushad
  lea ecx, [edi+$1b0] //cast to CParticlesPlayer
  mov eax, xrgame_addr
  add eax, $282b90
  call eax  //CParticlesPlayer::UpdateParticles
  popad

  //original
  mov eax,[edx+$254]
end;

function CorrectBleedingForHitType(obj:pointer; hit_type:cardinal; bleeding:single):single; stdcall;
var
  factor1, factor2:single;
  sect:PAnsiChar;
begin
  result:=bleeding;

  sect:=get_string_value(GetCObjectSection(obj));
  sect:=game_ini_read_string_def(sect, 'condition_sect', sect);

  factor1:=game_ini_r_single_def('gunslinger_wound_factors', PAnsiChar('bleeding_factor_for_hit_type_'+inttostr(hit_type)), 1.0);
  factor2:=game_ini_r_single_def(sect, PAnsiChar('bleeding_factor_for_hit_type_'+inttostr(hit_type)), 1.0);

  //log('Section '+sect+', hit_type '+inttostr(hit_type)+', val='+floattostr(bleeding)+', factor1 is '+floattostr(factor1)+', factor2 is '+floattostr(factor2));

  result:=result*factor1*factor2;
end;

function GetWoundComponentByHitType(wound:pointer; hit_type:cardinal):single; stdcall;
var
 a_m_Wounds:cardinal;
begin
  result:=0;
  if hit_type>=EHitType__eHitTypeMax then exit;

  a_m_Wounds:=cardinal(wound)+$10;
  result:=psingle(a_m_Wounds+hit_type*sizeof(single))^;
end;

procedure SetWoundComponentByHitType(wound:pointer; value:single; hit_type:cardinal); stdcall;
var
 a_m_Wounds:cardinal;
begin
  if hit_type>=EHitType__eHitTypeMax then exit;

  a_m_Wounds:=cardinal(wound)+$10;
  psingle(a_m_Wounds+hit_type*sizeof(single))^:=value;
end;

procedure CWound__SetDestroy(wound:pointer; status:byte); stdcall;
var
  m_bToBeDestroy:pByte;
begin
  m_bToBeDestroy:=@(PAnsiChar(wound)[$40]);
  m_bToBeDestroy^:=status;
end;


function CalcModifiedWoundTotalSize(obj:pointer; wound:pointer; hit_type_mask:integer = -1):single; stdcall;
var
  i:integer;
  bleeding:single;
begin
  result:=0;
  for i:=0 to EHitType__eHitTypeMax-1 do begin
    if (hit_type_mask > 0) and ( (1 shl i) and hit_type_mask = 0) then continue;
    bleeding:=GetWoundComponentByHitType(wound, i);
    if bleeding > 0 then begin
      result:=result+CorrectBleedingForHitType(obj, i, bleeding);
    end;
  end;
end;

function CEntityCondition__BleedingSpeed_reimpl(pcond:pCEntityCondition; hit_type_mask:integer = -1):single; stdcall;
var
  i:integer;
  pwound:pointer;
begin
  result:=0;

  for i:=0 to items_count_in_vector(@pcond.m_WoundVector, sizeof(pointer))-1 do begin
    pwound:=get_item_from_vector(@pcond.m_WoundVector, i, sizeof(pointer));
    result:=result+CalcModifiedWoundTotalSize(pcond.m_object, pointer(pcardinal(pwound)^), hit_type_mask);
  end;
end;

procedure CEntityCondition__BleedingSpeed_Patch(); stdcall;
asm
  pushad
  push $FFFFFFFF
  push ecx // this
  call CEntityCondition__BleedingSpeed_reimpl // returns value in fpu register - exactly what's we need
  popad

  ret
end;

function ChangeBleedingForWound(wound:pointer; percent:single; min_wound_size:single; hit_type_mask:integer = -1):boolean; stdcall;
var
  i:integer;
  wound_size:single;
const
  EPS:single=0.0000001;  
begin
  for i:=0 to EHitType__eHitTypeMax-1 do begin
    if (hit_type_mask > 0) and ( (1 shl i) and hit_type_mask = 0) then continue;
    wound_size:=GetWoundComponentByHitType(wound, i);
    wound_size:=wound_size - percent;
    if wound_size < min_wound_size then begin
      wound_size:=0;
    end;
    SetWoundComponentByHitType(wound, wound_size, i);
  end;

  result:=true;
  for i:=0 to EHitType__eHitTypeMax-1 do begin
    if GetWoundComponentByHitType(wound, i) > EPS then begin
     result:=false;
     break;
    end;
  end;

  if result then begin
    for i:=0 to EHitType__eHitTypeMax-1 do begin
      SetWoundComponentByHitType(wound, 0, i);
    end;  
  end;

end;

procedure CEntityCondition__ChangeBleeding_custom(cond:pCEntityCondition; percent:single; hit_type_mask:integer = -1); stdcall;
var
  i:integer;
  pwound:pointer;
begin
  for i:=0 to items_count_in_vector(@cond.m_WoundVector, sizeof(pointer))-1 do begin
    pwound:=get_item_from_vector(@cond.m_WoundVector, i, sizeof(pointer));
    if ChangeBleedingForWound(pointer(pcardinal(pwound)^), percent, cond.m_fMinWoundSize, hit_type_mask) then begin
      //bleeding stopped, need to remove wound
      CWound__SetDestroy(pointer(pcardinal(pwound)^), 1);
    end;
  end;
end;

procedure CEntityCondition__ChangeBleeding_reimpl(cond:pCEntityCondition; percent:single); stdcall;
var
  mask:word;
begin
  if cond.m_object = GetActor() then begin
    mask:=not (1 shl EHitType__eHitTypeBurn); // beware of negative value after passing to CEntityCondition__ChangeBleeding_custom!
    CEntityCondition__ChangeBleeding_custom(cond, percent, mask);
  end else begin
    CEntityCondition__ChangeBleeding_custom(cond, percent);
  end;
end;

procedure CEntityCondition__ChangeBleeding_reimpl_Patch(); stdcall;
asm
  mov eax, [esp+4] // percent
  pushad
  push eax
  push ecx
  call CEntityCondition__ChangeBleeding_reimpl
  popad
  ret 4
end;

function Init():boolean; stdcall;
var jmp_addr:cardinal;
begin
  ClearActorKeyRepeatFlags();
  ResetChangedGrenade();

  _prev_act_slot:=-1;
  _last_act_slot:=-1;

{$ifdef USE_SCRIPT_USABLE_HUDITEMS}
  _was_unprocessed_use_of_usable_huditem:=false;
{$endif}

  _lefthanded_torch.base.render:=nil;
  _lefthanded_torch.base.omni:=nil;
  _lefthanded_torch.base.glow:=nil;
  _lefthanded_torch.base.enabled:=false;
  v_zero(@_lefthanded_torch.aim_offset);

  _pda_cursor_state.last_moving_time:=0;
  _pda_cursor_state.current_dir:=Idle;
  _pda_cursor_state.last_click_time:=0;
  _is_pda_lookout_mode:=false;


  result:=false;
  jmp_addr:=xrGame_addr+$261DF6; //CActor::UpdateCL
  if not WriteJump(jmp_addr, cardinal(@ActorUpdate_Patch), 6, true) then exit;

  jmp_addr:= xrgame_addr+$2783F9;  //CActor::IR_OnKeyboardPress
  if not WriteJump(jmp_addr, cardinal(@CActor__IR_OnKeyboardPress_Patch), 7, true) then exit;

  jmp_addr:= xrgame_addr+$4B60E0;
  if not WriteJump(jmp_addr, cardinal(@CUIGameSP__IR_OnKeyboardPress_Patch), 6, true) then exit;

  jmp_addr:= xrgame_addr+$26D115;
  if not WriteJump(jmp_addr, cardinal(@CActor__netSpawn_Patch), 8) then exit;

  jmp_addr:= xrgame_addr+$26F04B;
  if not WriteJump(jmp_addr, cardinal(@CActor__net_Destroy_Patch), 7, true) then exit;

  jmp_addr:= xrgame_addr+$2637BE;
  if not WriteJump(jmp_addr, cardinal(@CActor__Hit_HitmarkCondition_Patch), 7, true) then exit;

  jmp_addr:= xrgame_addr+$45A0D7;
  if not WriteJump(jmp_addr, cardinal(@CUIMainIngameWnd__Draw_zonemap_Patch), 29, true) then exit;

  jmp_addr:= xrgame_addr+$4b1b46;
  if not WriteJump(jmp_addr, cardinal(@CUIGameCustom__Render_drawingame_Patch), 24, true) then exit;

  //фов в прицеливании (правим в CActor::currentFOV)
  jmp_addr:= xrgame_addr+$2605d0;
  if not WriteJump(jmp_addr, cardinal(@ZoomFOV_Patch), 13, true) then exit;

  //переделка анимаций (camera effectors) камеры в движении
  jmp_addr:= xrgame_addr+$269b97;
  if not WriteJump(jmp_addr, cardinal(@CActor__g_cl_CheckControls_select_cam_anm_Patch), 24, true) then exit;
  if not nop_code(xrgame_addr+$269bb1, 17) then exit;
  jmp_addr:= xrgame_addr+$269c5e;
  if not WriteJump(jmp_addr, cardinal(@CActor__g_cl_CheckControls_change_anmid_for_checking_Patch), 8, true) then exit;
  jmp_addr:= xrgame_addr+$269d0b;
  if not WriteJump(jmp_addr, cardinal(@CActor__g_cl_CheckControls_change_anmid_for_assigning_Patch), 7, true) then exit;

  //[bug] баг - чтобы при попытке тащить труп не открывался инвентарь
  //внимание - подозрение на то, что приводит к другому багу: в скрипты подается сигнал об открытии инвентаря трупа, когда сам инвентарь не открывался!
  jmp_addr:= xrgame_addr+$27820d;
  if not WriteJump(jmp_addr, cardinal(@CActor__ActorUse_Patch_deadbodies), 10, true) then exit;

  //баг - возможность таскать тяжелые трупы
  jmp_addr:= xrgame_addr+$27832e;
  if not WriteJump(jmp_addr, cardinal(@CActor__ActorUse_Patch_deadbodies_weight), 7, true) then exit;

  //включаем коллизию
  if IsCorpseCollisionEnabled() then begin
    nop_code(xrgame_addr+$4e2160, 2);
    nop_code(xrgame_addr+$4e20c0, 2);
  end;

  //теперь в обычном состоянии m_zoom_params.m_fCurrentZoomFactor должен инициализироваться не g_fov, а 1.0
  //в CWeapon::OnZoomOut
  jmp_addr:= xrgame_addr+$2BEE26;
  if not WriteJump(jmp_addr, cardinal(@ResetZoomFov_Patch), 16, true) then exit;
  //и в CWeapon::CWeapon
  jmp_addr:= xrgame_addr+$2BF6F7;
  if not WriteJump(jmp_addr, cardinal(@ResetZoomFov_Patch), 16, true) then exit;


  //возможность использовать налобный фонарь теперь зависит от костюма
  jmp_addr:= xrgame_addr+$2F13F9;
  if not WriteJump(jmp_addr, cardinal(@CTorch__Switch_Patch), 6, true) then exit;


  jmp_addr:= xrgame_addr+$2F6235;
  if not WriteJump(jmp_addr, cardinal(@OnOutfitOrHelmInRuck_Patch), 5, true) then exit;

  jmp_addr:= xrgame_addr+$2F6235;
  if not WriteJump(jmp_addr, cardinal(@OnOutfitOrHelmInRuck_Patch), 5, true) then exit;

  jmp_addr:= xrgame_addr+$2F8102;
  if not WriteJump(jmp_addr, cardinal(@OnOutfitOrHelmInRuck_Patch), 5, true) then exit;


  jmp_addr:= xrgame_addr+$269ab0;
  if not WriteJump(jmp_addr, cardinal(@CorrectActorSpeed), 6, true) then exit;


  jmp_addr:= xrgame_addr+$278031;
  if not WriteJump(jmp_addr, cardinal(@CActor__SwitchTorch_Patch), 5, false) then exit;

  jmp_addr:= xrgame_addr+$277FE5;
  if not WriteJump(jmp_addr, cardinal(@CActor__SwitchNightVision_Patch), 5, false) then exit;


  jmp_addr:= xrgame_addr+$2627D2;
  if not WriteJump(jmp_addr, cardinal(@CheckHeavyBreathAdditionalCondition_Patch), 5, true) then exit;

  jmp_addr:= xrgame_addr+$45CA70;
  if not WriteJump(jmp_addr, cardinal(@CUIMotionIcon__Update_Patch), 8, true) then exit;

  jmp_addr:= xrgame_addr+$277CC3;
  if not WriteJump(jmp_addr, cardinal(@CActor__IR_OnMouseMove_CorrectMouseSense_Patch), 16, true) then exit;

  //[bug] не совсем баг, но нелогично - что-то пищит при подходе к аномалиям, даже когда детектора нет ни в слоте, ни в инвентаре. Исправлено.
  jmp_addr:= xrgame_addr+$458393;
  if not WriteJump(jmp_addr, cardinal(@CUIHudStatesWnd__UpdateZones_Patch), 8, true) then exit;

  //звук шагов экзы
  jmp_addr:= xrgame_addr+$78F9C;
  if not WriteJump(jmp_addr, cardinal(@CStepManager__material_sound__play_next_OnStepSnd), 5, true) then exit;

  //обработка разных режимов мыши (обзор/курсор) в ПДА;
  jmp_addr:=xrGame_addr+$43e2b3;
  if not WriteJump(jmp_addr, cardinal(@CDialogHolder__IR_UIOnMouseMove_Patch), 5, true) then exit;

  //[bug] нажать наклон влево, затем наклон вправо, затем отпустить один из наклонов и наслаждаться залипшим mstate_real.
  // Причина - проблемы в битовой арифметике в CActor::g_cl_ValidateMState (mcLookout - составной, про это забыли)
  // Для исправления - сделаем невозможным наклон в обе стороны сразу в CActor__IR_OnKeyboardHold
  jmp_addr:=xrGame_addr+$277b2a;
  if not WriteJump(jmp_addr, cardinal(@CActor__IR_OnKeyboardHold_Patch), 8, false) then exit;

  jmp_addr:=xrGame_addr+$277b3c;
  if not WriteJump(jmp_addr, cardinal(@CActor__IR_OnKeyboardHold_Patch), 8, false) then exit;

  jmp_addr:=xrGame_addr+$2633d8;
  if not WriteJump(jmp_addr, cardinal(@OnActorHit_Patch), 5, true) then exit;

  //[bug] баг - отсутствует плавное изменение частоты и амплитуд эффектора раскачки камеры при ходьбе (bobbing) при
  // смене темпа ходьбы\приседании
  jmp_addr:=xrGame_addr+$22d8ac;
  if not WriteJump(jmp_addr, cardinal(@CEffectorBobbing__ProcessCam_Patch), 10, true) then exit;

  //Дополнительные условия, когда актор не может поднимать предметы с земли (например, под воздействием контролера)
  jmp_addr:=xrGame_addr+$2a9ce3;
  if not WriteJump(jmp_addr, cardinal(@CInventory__CanTakeItem_Conditions), 5, true) then exit;

  // Удлиненние рук актора - чтобы мог взять хабар из нычек в кабинах и т.п
  jmp_addr:=cardinal(@g_pickup_distance);
  if not WriteBufAtAdr(xrGame_addr+$2629a3, @jmp_addr, sizeof(jmp_addr)) then exit;

  //player_hud::load - заставляем функцию не делать ничего, кроме как выставлять в нашем коде флаг о необходимости смены модели худа
  //Реальная смена модели рук будет из апдейта
  jmp_addr:=xrGame_addr+$2fecf0;
  if not WriteJump(jmp_addr, cardinal(@player_hud__onloadrequest), 5, false) then exit;

  //При обнаружении засвета акторским фонариком вызовем из CCustomMonster::shedule_Update (xrgame+bf29c) функцию CBaseMonster::feel_sound_new (наподобие того, как это сделано в CBaseMonster::HitSignal(xrgame+ca440)); смещение this 0x308
  jmp_addr:=xrGame_addr+$bf29c;
  if not WriteJump(jmp_addr, cardinal(@CCustomMonster__shedule_Update_Patch), 6, true) then exit;
  //аналогично - из CAI_Stalker(xrgame+1616b0)
  jmp_addr:=xrGame_addr+$161963;
  if not WriteJump(jmp_addr, cardinal(@CAI_Stalker__shedule_Update_Patch), 6, true) then exit;

  //в CBaseMonster::HitEntity заставляем актора сбрасывать оружие при ударе монстра
  jmp_addr:=xrGame_addr+$c96e5;
  if not WriteJump(jmp_addr, cardinal(@CBaseMonster__HitEntity_WeaponDrop_Patch), 10, true) then exit;

  // в CActor::UpdateCL добавляем сохранение активного режима подъема предметов
  jmp_addr:=xrGame_addr+$261e8e;
  if not WriteJump(jmp_addr, cardinal(@CActor__UpdateCL_PickupMode_Patch), 6, true) then exit;

  // в CActor::g_Physics перед отправкой нетпакета корректируем данные в нём (увеличиваем урон от падений)
  jmp_addr:=xrGame_addr+$261db0;
  if not WriteJump(jmp_addr, cardinal(@CActor__g_Physics_FallHit_Patch), 7, true) then exit;

  // в CActor::CanMove даём возможность передвигаться независимо от наличия стамины под действием энергетика
  jmp_addr:=xrGame_addr+$2749d2;
  if not WriteJump(jmp_addr, cardinal(@CActor__CanMove_Patch), 7, true) then exit;

  // В CGameObject::OnEvent при получении сообщения о хите перед вызовом Hit ставим add_wound=true
  jmp_addr:=xrGame_addr+$280935;
  if not WriteJump(jmp_addr, cardinal(@CGameObject__OnEvent_addwoundonhit_Patch), 10, true) then exit;

  // в CEntityCondition::AddWound добавим возможность масштабировать размер раны в зависимости от типа урона
  jmp_addr:=xrGame_addr+$27e683;
  if not WriteJump(jmp_addr, cardinal(@CEntityCondition__AddWound_scalewoundsize_Patch), 5, true) then exit;

  // в CEntityAlive::UpdateFireParticles если существо умерло до остановки отыгрыша партиклов огня, то продляем отыгрыш партикла (пусть "догорает")
  jmp_addr:=xrGame_addr+$27b6dc;
  if not WriteJump(jmp_addr, cardinal(@CEntityAlive__UpdateFireParticles_deadfire_Patch), 5, true) then exit;

  //в CEntityAlive::UpdateFireParticles исправляем странное условие burn_size>0 на burn_size>=0, иначе "составная" рана (с несколькими типами хитов) при заживлении ожога не потухнет
  nop_code(xrgame_addr+$27b653, 1, chr($72));

  //Надо вызывать CParticlesPlayer::UpdateParticles из CEntityAlive::shedule_Update, чтобы партиклы корректно удалялись после смерти
  jmp_addr:=xrGame_addr+$27a768;
  if not WriteJump(jmp_addr, cardinal(@CEntityAlive__shedule_Update_updateparticles_Patch), 6, true) then exit;

  //В CEntityAlive::Hit можно отключить вопроизведение партикла горения для типа eHitTypeLightBurn
  nop_code(xrgame_addr+$27be23, 2); 

  // [bug] баг в CEntityCondition::BleedingSpeed - из-за того, что итоговое кровотечение берется как среднее от всех ран, то при заживании небольшой раны кровотечение усиливается
  // Для исправления заменяем функцию на нашу реализацию, заодно учитывающую и коэффициенты в завсимости от типа хита
  jmp_addr:=xrGame_addr+$27dd00;
  if not WriteJump(jmp_addr, cardinal(@CEntityCondition__BleedingSpeed_Patch), 6, false) then exit;

  // Переабатываем стандартный CEntityCondition::ChangeBleeding так, чтобы он не заживлял актору ожоги
  jmp_addr:=xrGame_addr+$27dc60;
  if not WriteJump(jmp_addr, cardinal(@CEntityCondition__ChangeBleeding_reimpl_Patch), 7, false) then exit;

  result:=true;
end;

// CEntityCondition::ChangeBleeding - xrGame.dll+27dc60
// CActor::UpdateArtefactsOnBeltAndOutfit - xrGame.dll+262cd0

end.
