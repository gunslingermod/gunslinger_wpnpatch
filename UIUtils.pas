unit UIUtils;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface
uses MatVectors, xr_strings;

type

pCDialogHolder = pointer;
pCUITabControl=pointer;
pCUI3tButton=pointer;
pCUILines=pointer;
pCUITextWnd=pointer;
pUIHint=pointer;
pCUITaskWnd=pointer;
pCUIRankingWnd=pointer;
pCLAItem=pointer;
ui_shader = pointer;


ITextureOwner = packed record
  vftable:pointer;
end;
pITextureOwner=^ITextureOwner;

CUILightAnimColorConroller = packed record
  vftable:pointer;
end;
pCUILightAnimColorConroller=^CUILightAnimColorConroller;

color_animation = packed record
  m_lanim:pCLAItem;
  m_lanim_start_time:single;
  m_lanim_delay_time:single;
  m_lanimFlags:byte;
  _unused1:byte;
  _unused2:word;  
end;
pcolor_animation=^color_animation;

CUILightAnimColorConrollerImpl = packed record
  base_CUILightAnimColorConroller:CUILightAnimColorConroller;
  m_lanim_clr:color_animation;
end;
pCUILightAnimColorConrollerImpl=^CUILightAnimColorConrollerImpl;

CUISimpleWindow = packed record
  vftable:pointer;
  m_bShowMe:byte;
  m_wndPos:FVector2;
  m_wndSize:FVector2;
  _unused1:byte;
  _unused2:word;
  m_alignment:cardinal;
end;
pCUISimpleWindow=^CUISimpleWindow;

WINDOW_LIST = packed record
  vec_start:pointer;
  vec_end:pointer;
  vec_memend:pointer;    
end;

CUIWindow = packed record //sizeof = 0x54
  base_CUISimpleWindow:CUISimpleWindow;
  m_windowName:shared_str;
  m_ChildWndList:WINDOW_LIST;
  m_pParentWnd:pointer; {CUIWindow}
  m_pMouseCapturer:pointer; {CUIWindow}
  m_pKeyboardCapturer:pointer; {CUIWindow}
  m_pMessageTarget:pointer; {CUIWindow}
  cursor_pos:FVector2;
  m_dwLastClickTime:cardinal;
  m_dwFocusReceiveTime:cardinal;
  m_bAutoDelete:byte;
  m_bPP:byte;
  m_bIsEnabled:byte;
  m_bCursorOverWindow:byte;

  //offset = 0x50
  m_bCustomDraw:byte;
  _unused1:byte;
  _unused2:word;
end;
pCUIWindow=^CUIWindow;
ppCUIWindow=^pCUIWindow;

lanim_cont = packed record
  m_lanim:pCLAItem;
  m_lanim_start_time:single;
  m_lanim_delay_time:single;
  m_lanimFlags:byte;
  _unused1:byte;
  _unused2:word;
end;
planim_cont=^lanim_cont;

lanim_cont_xf = packed record
  base_lanim_cont:lanim_cont;
  m_origSize:FVector2;
end;

CUIStaticItem = packed record
  TextureRect:FRect;
  vHeadingPivot:FVector2;
  vHeadingOffset:FVector2;
  uFlags:byte;
  _unused1:byte;
  _unused2:word;
  hShader:ui_shader;
  vPos:FVector2;
  vSize:FVector2;
  color:cardinal
end;
pCUIStaticItem=^CUIStaticItem;

CUIStatic = packed record
  base_CUIWindow:CUIWindow;
  //offset = 0x54
  base_ITextureOwner:ITextureOwner;
  //offset = 0x58
  base_CUILightAnimColorConrollerImpl:CUILightAnimColorConrollerImpl;
  // offset = 0x6c
  m_lanim_xform:lanim_cont_xf;
  //0x84
  m_pTextControl:pCUILines;
  m_bStretchTexture:byte;
  m_bTextureEnable:byte;
  unused1:word;
  m_UIStaticItem:CUIStaticItem;

  //offset:0xc8
  m_bHeading:byte;
  m_bConstHeading:byte;
  unused2:word;  
  //offset:0xcc
  m_fHeading:single;
  m_TextureOffset:FVector2;
  //offset:0xd8
  m_stat_hint_text:shared_str;
end;
pCUIStatic=^CUIStatic;
ppCUIStatic=^pCUIStatic;

SCachedValues = packed record
  m_updatedFrame:cardinal;
  m_graphID:word;
  m_Position:FVector2;
  m_Direction:FVector2;
  unused1:word;
  m_LevelName:shared_str;
  m_Actuality:byte; {boolean}
end;

CMapLocation = packed record
  vftable:pointer;
  m_flags:cardinal;
  m_hint:shared_str;

  m_level_spot:pointer;
  m_level_spot_pointer:pointer;
  m_minimap_spot:pointer;
  m_minimap_spot_pointer:pointer;
  m_complex_spot:pointer;
  m_complex_spot_pointer:pointer;

  m_spot_border_names:array[0..5] of shared_str;
  m_level_map_spot_border:pointer;
  m_mini_map_spot_border:pointer;
  m_complex_spot_border:pointer;

  m_level_map_spot_border_na:pointer;
  m_mini_map_spot_border_na:pointer;
  m_complex_spot_border_na:pointer;

  //offset: 0x54
  m_objectID:word;
  unused1:word;
  m_owner_se_object:pointer;
  m_ttl:integer;
  m_actual_time:cardinal;
  m_position_global:FVector3;
  m_position_on_map:FVector2;

  //offset:0x78
  m_cached:SCachedValues;
end;
pCMapLocation = ^CMapLocation;

CMapSpot = packed record
  base_CUIStatic:CUIStatic;
  m_map_location:pCMapLocation;
  m_location_level:integer;
  m_border_static:pCUIStatic;
  m_mark_focused:byte;
  m_bScale:byte;
//  _unused1:word;
  m_scale_bounds:FVector2;
  m_originSize:FVector2;
end;
pCMapSpot=^CMapSpot;
ppCMapSpot=^pCMapSpot;

CUIDialogWnd = packed record
  base_CUIWindow:CUIWindow;
  m_pParentHolder:pCDialogHolder;
  m_bWorkInPause:byte;
  _unused1:byte;
  _unused2:word;
end;
pCUIDialogWnd=^CUIDialogWnd;

CUIPdaWnd = packed record
  base_CUIDialogWnd:CUIDialogWnd;
  UITabControl:pCUITabControl;
  m_btn_close:pCUI3tButton;
  UIMainPdaFrame:pCUIStatic;
  UINoice:pCUIStatic;
  m_caption:pCUITextWnd;
  m_caption_const:shared_str;
  m_clock:pCUITextWnd;
  m_pActiveDialog:pCUIWindow;
  m_sActiveSection:shared_str;
  m_hint_wnd:pUIHint;
  pUITaskWnd:pCUITaskWnd;
  pUIRankingWnd:pCUIRankingWnd;
end;
pCUIPDAWnd = ^CUIPDAWnd;

{
type CUIMainIngameWnd = packed record
  base:CUIWindow;
  UIStaticDiskIO:pCUIStatic;
  UIStaticQuickHelp:pCUITextWnd;
  UIMotionIcon:pCUIMotionIcon;
end;        }

type CUICursor = packed record
  vftable_pureRender:pointer;
  vftable_pureScreenResolutionChanged:pointer;
  bVisible:byte;
  vPos:FVector2;
  vPrevPos:FVector2;
  m_b_use_win_cursor:byte;
  m_static:pointer; {CUIStatic*}
end;
pCUICursor=^CUICursor;


function GetUICursor():pCUICursor; stdcall;

function CurrentGameUI(): {CUIGameCustom*} pointer; stdcall;
function AddCustomStatic(cuigamecustom_this: pointer; id:PChar; bSingleInstance: boolean): {SDrawStaticStruct*} pointer; stdcall;

function g_hud():{CCustomHUD*}pointer; stdcall;

procedure CUILines__SetText(cuilines: pointer; msg:PChar); stdcall;
procedure virtual_CUIWindow__Show (cuiwindow: pointer; status:cardinal); stdcall;
procedure CustomStaticSetText(sdrawstaticstruct:pointer; text:pchar); stdcall;
function CDialogHolder__TopInputReceiver(): pCUIDialogWnd; stdcall;
procedure HideShownDialogs(); stdcall;
function IsUIShown():boolean; stdcall;

procedure ShowPDAMenu(); stdcall;
procedure HidePDAMenu(); stdcall;
function GetPDA():pCUIPDAWnd; stdcall;
//function IsPDAWindowEnabled():boolean; stdcall;
function IsPDAWindowVisible():boolean; stdcall;

procedure virtual_CUIWindow__Draw(window:pCUIWindow); stdcall;
procedure virtual_CUICursor__OnRender(cursor:pCUICursor); stdcall;
procedure virtual_CUIDialogWnd__Show(dlg:pCUIDialogWnd; status:boolean); stdcall;
function CUIWindow__FindChild(parent:pCUIWindow; name:PAnsiChar):pCUIWindow; stdcall;
procedure virtual_ITextureOwner__SetTextureRect(ito:pITextureOwner; rect:pFRect); stdcall;
procedure virtual_CUISimpleWindow__SetWndSize(wnd:pCUISimpleWindow; sz:pFVector2); stdcall;
procedure virtual_CUISimpleWindow__SetWndPos(wnd:pCUISimpleWindow; pos:pFVector2); stdcall;
procedure virtual_CUILightAnimColorConroller__SetColorAnimation(this:pCUILightAnimColorConroller; name:pansichar; flags:pbyte; delay:single); stdcall;

function IsInventoryShown():boolean; stdcall;
procedure ShowInventory(); stdcall;
procedure HideInventory(); stdcall;

function IsActorBurned():boolean; stdcall;

function Init():boolean;stdcall;

type
upgrade_icon_data = packed record
  offset:FVector2;
  icon_section:PAnsiChar;
  icon:pCUIStatic;
  enabled:boolean;  
end;

CellItemBuffer = class
protected
  _my_item:pointer;
  _my_cell:pointer;
  _up_icons:array of upgrade_icon_data;
  procedure _ProcessUpgrade(section:PAnsiChar);
public
  constructor Create(itm:pointer; cell:pointer);
  destructor Destroy(); override;
  procedure Update();
  procedure SetItem(new_item:pointer);
end;
pCellItemBuffer = ^CellItemBuffer;

const
  LA_CYCLIC:byte = 1;
  LA_ONLYALPHA:byte = 2;
  LA_TEXTCOLOR:byte = 4;
  LA_TEXTURECOLOR:byte = 8;

var
  bShowPauseString:pBoolean;

implementation
uses BaseGameData, collimator, ActorUtils, HudItemUtils, gunsl_config, sysutils, dynamic_caster, misc, math, Level, ControllerMonster, ScriptFunctors, xr_Cartridge, HitUtils, WeaponAdditionalBuffer;

var
  register_level_isuishown_ret:cardinal;
  IsUIShown_ptr, IndicatorsShown_adapter_ptr, IsInventoryShown_adapter_ptr, IsActorControlled_adapter_ptr, IsActorBurned_adapter_ptr, IsPickupMode_adapter_ptr, IsTacticHudInstalled_adapter_ptr:pointer;
  ElectronicProblemsBegin_ptr, ElectronicProblemsEnd_ptr, ElectronicProblemsReset_ptr, ElectronicProblemsApply_ptr, GetParameterUpgraded_int_ptr, valid_saved_game_int_ptr:pointer;
  CUIInventoryUpgradeWnd__m_btn_disassemble:pCUI3tButton;

procedure HideShownDialogs(); stdcall;
asm
  pushad
    call CurrentGameUI
    test eax, eax
    je @finish
    mov edx, [eax]
    mov ecx, eax
    mov eax, [edx+$18]
    call eax
    @finish:
  popad
end;

function CurrentGameUI(): {CUIGameCustom*} pointer; stdcall;
begin
asm
  pushad
    mov eax, xrgame_addr
    add eax, $4afd90
    call eax
    mov @result, eax
  popad
end;
end;

function AddCustomStatic(cuigamecustom_this: pointer; id:PChar; bSingleInstance: boolean): {SDrawStaticStruct*} pointer; stdcall;
asm
  pushad
    movzx eax, bSingleInstance
    push eax
    push id
    mov ecx, cuigamecustom_this
    mov eax, xrgame_addr
    add eax, $4b1760
    call eax
    mov @result, eax
  popad
end;

procedure CustomStaticSetText(sdrawstaticstruct:pointer; text:pchar); stdcall;
asm
  pushad
    mov eax, sdrawstaticstruct
    mov ecx, [eax+4]
    push text
    push [ecx+$84]
    call CUILines__SetText
  popad
end;

procedure CUILines__SetText(cuilines: pointer; msg:PChar); stdcall;
asm
  pushad
    push msg
    mov ecx, cuilines
    mov eax, xrgame_addr
    add eax, $49cc60
    call eax
  popad
end;

procedure virtual_CUIWindow__Show (cuiwindow: pointer; status:cardinal); stdcall;
//TODO: 2nd argument is boolean
asm
  pushad
    cmp cuiwindow, 0
    je @finish

    mov ecx, cuiwindow
    mov eax, [ecx]
    mov eax, [eax+$58]

    push status
    call eax

    @finish:
  popad
end;

function CDialogHolder__TopInputReceiver(): pCUIDialogWnd; stdcall;
begin
asm
  pushad
    call CurrentGameUI
    lea ecx, [eax+$10]

    mov eax, xrGame_addr
    add eax, $43df30
    call eax
    mov @result, eax 
  popad
end;
end;

function g_hud():{CCustomHUD*}pointer; stdcall;
begin
asm
  mov eax, xrengine_addr
  mov eax, [eax+$92d3c]
  mov @result, eax
end;
end;

procedure ShowPDAMenu(); stdcall;
asm
  pushad
    call CurrentGameUI
    cmp eax, 0
    je @finish

    mov ecx, eax
    mov ebx, xrgame_addr
    add ebx, $4b0bb0
    call ebx

    @finish:
  popad
end;

procedure HidePDAMenu(); stdcall;
asm
  pushad
    call CurrentGameUI
    cmp eax, 0
    je @finish

    mov ecx, eax
    mov ebx, xrgame_addr
    add ebx, $4b0bd0
    call ebx

    @finish:
  popad
end;

procedure ToggleActorMenu(); stdcall;
asm
  pushad
    call CurrentGameUI
    cmp eax, 0
    je @finish

    mov ecx, eax
    mov ebx, xrgame_addr
    add ebx, $4b1b80 // CUIGameCustom::ShowActorMenu
    call ebx

    @finish:
  popad
end;

procedure ShowInventory(); stdcall;
begin
  if not IsInventoryShown() then ToggleActorMenu();
end;

procedure HideInventory(); stdcall;
begin
  if IsInventoryShown() then ToggleActorMenu();
end;

function IsPDAWindowEnabled():boolean; stdcall;
var
  pda:pCUIPdaWnd;
begin
  pda:=GetPDA();
  if pda<>nil then begin
    result:=pda.base_CUIDialogWnd.m_pParentHolder<>nil;
  end else begin
    result:=false;
  end;
end;

function IsPDAWindowVisible():boolean; stdcall;
var
  pda:pCUIPdaWnd;
begin
  if GetLevel() = nil then begin
    result:=false;
    exit;
  end;

  pda:=GetPDA();
  if pda<>nil then begin
    result:=pda.base_CUIDialogWnd.base_CUIWindow.base_CUISimpleWindow.m_bShowMe<>0;
  end else begin
    result:=false;
  end;
end;

function GetPDA():pCUIPDAWnd; stdcall;
begin
asm
  mov @result, 0
  pushad
    call CurrentGameUI
    cmp eax, 0
    je @finish
    mov eax, [eax+$54]
    mov @result, eax

    @finish:
  popad
end;
end;

function IsInventoryShown():boolean; stdcall;
begin
asm
  mov @result, 0
  pushad
    call CurrentGameUI
    cmp eax, 0
    je @finish
    mov ecx, [eax+$50]
    mov bl, [ecx+4]
    mov @result, bl
    @finish:
  popad
end;
end;

function IsInventoryShown_adapter():boolean; stdcall;
begin
asm
  pushad
    call IsInventoryShown
    mov @result, al
  popad
end;
end;


function IsTacticHudInstalled_adapter():boolean; stdcall;
begin
asm
  pushad
    call IsTacticHudInstalled
    mov @result, al
  popad
end;
end;

function IsPickupMode_adapter():boolean; stdcall;
begin
asm
  pushad
    call IsPickupMode
    mov @result, al
  popad
end;
end;

function IsUIShown():boolean; stdcall;
begin
asm
  pushad
    call CurrentGameUI
    movzx eax, byte ptr [eax+$58]
    mov @result, al
  popad
end;
end;

function IndicatorsShown():boolean; stdcall;
var
  wpn:pointer;
begin
  result:=IsUIShown();
  if result then begin
    wpn:=GetActorActiveItem();
    if wpn = nil then begin
      result:=true;
    end else if dynamic_cast(wpn, 0, RTTI_CHudItemObject, RTTI_CWeapon, false) = nil then begin
      result:=true;
    end else if IsUIForceHiding(wpn) then begin
      result:=false;
    end else if IsUIForceUnhiding(wpn) then begin
      result:=true;
    end else if IsGrenadeMode(wpn) then begin
      result:=true;      
    end else if IsAimNow(wpn) and ((GetScopeStatus(wpn)=1) or (GetScopeStatus(wpn)=2) and IsScopeAttached(wpn)) then begin
      result:=false;
    end else begin
      result:=true;
    end;
  end;
end;

procedure virtual_CUIWindow__Draw(window:pCUIWindow); stdcall;
asm
  pushad
    mov ecx, window
    cmp ecx, 0
    je @finish

    mov eax, [ecx]
    mov eax, [eax+$60]
    call eax

    @finish:
  popad
end;

procedure virtual_CUIWindow__Enable(window:pCUIWindow; status:boolean); stdcall;
asm
  pushad
    mov ecx, window
    cmp ecx, 0
    je @finish

    mov eax, [ecx]
    mov eax, [eax+$54]

    xor edx, edx
    mov dl, status
    push edx
    call eax

    @finish:
  popad
end;

function CUIWindow__FindChild(parent:pCUIWindow; name:PAnsiChar):pCUIWindow; stdcall;
var
  ss_name:shared_str;
begin
  init_string(@ss_name);
  assign_string(@ss_name, name);

  asm
    pushad
    mov ecx, parent
    push ss_name.p_
    mov eax, xrgame_addr
    add eax, $485510
    call eax
    mov result, eax
    popad
  end;

  assign_string(@ss_name, nil);
end;

procedure virtual_CUIDialogWnd__Show(dlg:pCUIDialogWnd; status:boolean); stdcall;
asm
  pushad
    mov ecx, dlg
    cmp ecx, 0
    je @finish

    movzx ebx, status
    push ebx

    mov eax, [ecx]
    mov eax, [eax+$54]
    call eax

    @finish:
  popad
end;

procedure virtual_ITextureOwner__SetTextureRect(ito:pITextureOwner; rect:pFRect); stdcall;
asm
  pushad
  mov eax, rect
  push eax
  mov ecx, ito
  mov edi, [ecx] // vtable
  mov edi, [edi+$0c]
  call edi
  popad
end;

procedure virtual_CUISimpleWindow__SetWndSize(wnd:pCUISimpleWindow; sz:pFVector2); stdcall;
asm
  pushad
  mov eax, sz
  push eax
  mov ecx, wnd
  mov edi, [ecx] // vtable
  mov edi, [edi+$04]
  call edi
  popad
end;

procedure virtual_CUISimpleWindow__SetWndPos(wnd:pCUISimpleWindow; pos:pFVector2); stdcall;
asm
  pushad
  mov eax, pos
  push eax
  mov ecx, wnd
  mov edi, [ecx] // vtable
  mov edi, [edi+$04]
  call edi
  popad
end;

procedure virtual_CUILightAnimColorConroller__SetColorAnimation(this:pCUILightAnimColorConroller; name:pansichar; flags:pbyte; delay:single); stdcall;
asm
  pushad
  mov eax, delay
  push eax

  mov eax, flags
  push eax

  mov eax, name
  push eax


  mov ecx, this
  mov edi, [ecx] // vtable
  mov edi, [edi+$08]
  call edi
  popad
end;

function GetUICursor():pCUICursor; stdcall;
begin
asm
  pushad
    mov eax, xrgame_addr
    add eax, $43C8B0
    call eax
    mov @result, eax
  popad
end;
end;

procedure virtual_CUICursor__OnRender(cursor:pCUICursor); stdcall;
asm
  pushad
    mov ecx, cursor
    cmp ecx, 0
    je @finish

    mov eax, [ecx]
    mov eax, [eax]
    call eax

    @finish:
  popad
end;

function IndicatorsShown_adapter():boolean; stdcall;
begin
asm
  pushad
    call IndicatorsShown
    mov @result, al
  popad
end;
end;

function ElectronicProblemsBegin():boolean; stdcall;
begin
asm
  pushad
    call ElectronicsProblemsInc
    mov @result, al
  popad
end;
end;

function ElectronicProblemsReset():boolean; stdcall;
begin
asm
  pushad
    call ResetElectronicsProblems
    mov @result, 1
  popad
end;
end;

function ElectronicProblemsApply():boolean; stdcall;
begin
asm
  pushad
    call ElectronicsProblemsImmediateApply
    mov @result, 1
  popad
end;
end;

function ElectronicProblemsEnd():boolean; stdcall;
begin
asm
  pushad
    call ElectronicsProblemsDec
    mov @result, al
  popad
end;
end;

function GetParameterUpgraded_int(objid:word; param_name:PAnsiChar):word; cdecl;
var
  obj, ii:pointer;
begin
  result:=255;
  obj:=GetObjectById(objid);
  ii:=dynamic_cast(obj, 0, RTTI_CGameObject, RTTI_CInventoryItem, false);

  if ii=nil then exit;
  result:=FindIntValueInUpgradesDef(ii, param_name, result);
end;

function valid_saved_game_int(unused:word; save_name:PAnsiChar):word; cdecl;
asm
  pushad
  mov eax, xrgame_addr
  add eax, $adb30
  push save_name
  call eax
  add esp, 4
  movzx ax, al
  mov @result, ax
  popad
end;

function IsActorControlled_adapter():boolean;
begin
asm
  pushad
    call IsActorSuicideNow
    mov @result, al
    cmp al, 0
  popad
  jne @finish

  pushad
    call IsActorControlled
    mov @result, al
    cmp al, 0
  popad
  jne @finish

  pushad
    call GetActorActiveItem
    test eax, eax
    je @nowpn
    push eax
    call IsSuicideAnimPlaying
    mov @result, al
    @nowpn:
  popad

  @finish:
end;
end;

function IsActorBurned_adapter():boolean;
begin
asm
  pushad
    call IsActorBurned
    mov @result, al
  popad

end;
end;

procedure register_level_isuishown(); stdcall;
const
  name:PChar='is_ui_shown';
  name2:PChar='indicators_shown';
  name3:PChar='inventory_shown';
  name4:PChar='pickup_mode';
  name5:PChar='is_tactical_hud';

  name_electroproblem_begin:PChar='electronics_break';
  name_electroproblem_end:PChar='electronics_restore';
  name_electroproblem_reset:PChar='electronics_reset';
  name_electroproblem_apply:PChar='electronics_apply';

  name_get_parameter_upgraded:PChar='get_parameter_upgraded_int';
  name_is_actor_suicide:PChar='is_actor_controlled';
  name_is_actor_burned:PChar='is_actor_burned';
  name_valid_saved_game_int:PChar='valid_saved_game_int';
asm
  push eax

  mov ecx, IsUIShown_ptr
  push ecx
  mov ecx, esp
  push name
  push ecx
  mov ecx, xrgame_addr
  add ecx, $1FF277;
  call ecx

  pop ecx
  pop ecx
  pop ecx

  pop eax


  push ecx
  mov ecx, eax
  call esi

  ////////////////////////////
  push eax

  mov ecx, IndicatorsShown_adapter_ptr
  push ecx
  mov ecx, esp
  push name2
  push ecx
  mov ecx, xrgame_addr
  add ecx, $1FF277;
  call ecx

  pop ecx
  pop ecx
  pop ecx

  pop eax


  push ecx
  mov ecx, eax
  call esi

 ////////////////////////////
  push eax

  mov ecx, ElectronicProblemsReset_ptr
  push ecx
  mov ecx, esp
  push name_electroproblem_reset
  push ecx
  mov ecx, xrgame_addr
  add ecx, $1FF277;
  call ecx

  pop ecx
  pop ecx
  pop ecx

  pop eax


  push ecx
  mov ecx, eax
  call esi

 ////////////////////////////
  push eax

  mov ecx, ElectronicProblemsApply_ptr
  push ecx
  mov ecx, esp
  push name_electroproblem_apply
  push ecx
  mov ecx, xrgame_addr
  add ecx, $1FF277;
  call ecx

  pop ecx
  pop ecx
  pop ecx

  pop eax


  push ecx
  mov ecx, eax
  call esi

  ////////////////////////////
  push eax

  mov ecx, IsActorControlled_adapter_ptr
  push ecx
  mov ecx, esp
  push name_is_actor_suicide
  push ecx
  mov ecx, xrgame_addr
  add ecx, $1FF277;
  call ecx

  pop ecx
  pop ecx
  pop ecx

  pop eax


  push ecx
  mov ecx, eax
  call esi

  ////////////////////////////
  push eax

  mov ecx, IsActorBurned_adapter_ptr
  push ecx
  mov ecx, esp
  push name_is_actor_burned
  push ecx
  mov ecx, xrgame_addr
  add ecx, $1FF277;
  call ecx

  pop ecx
  pop ecx
  pop ecx

  pop eax


  push ecx
  mov ecx, eax
  call esi

  ////////////////////////////
  push eax

  mov ecx, ElectronicProblemsEnd_ptr
  push ecx
  mov ecx, esp
  push name_electroproblem_end
  push ecx
  mov ecx, xrgame_addr
  add ecx, $1FF277;
  call ecx

  pop ecx
  pop ecx
  pop ecx

  pop eax


  push ecx
  mov ecx, eax
  call esi

  ////////////////////////////
  push eax

  mov ecx, ElectronicProblemsBegin_ptr
  push ecx
  mov ecx, esp
  push name_electroproblem_begin
  push ecx
  mov ecx, xrgame_addr
  add ecx, $1FF277;
  call ecx

  pop ecx
  pop ecx
  pop ecx

  pop eax


  push ecx
  mov ecx, eax
  call esi

  ////////////////////////////

  push eax

  mov ecx, IsInventoryShown_adapter_ptr
  push ecx
  mov ecx, esp
  push name3
  push ecx
  mov ecx, xrgame_addr
  add ecx, $1FF277;
  call ecx

  pop ecx
  pop ecx
  pop ecx

  pop eax


  push ecx
  mov ecx, eax
  call esi

  ////////////////////////////

  push eax

  mov ecx, IsPickupMode_adapter_ptr
  push ecx
  mov ecx, esp
  push name4
  push ecx
  mov ecx, xrgame_addr
  add ecx, $1FF277;
  call ecx

  pop ecx
  pop ecx
  pop ecx

  pop eax


  push ecx
  mov ecx, eax
  call esi

  ////////////////////////////

  push eax

  mov ecx, IsTacticHudInstalled_adapter_ptr
  push ecx
  mov ecx, esp
  push name5
  push ecx
  mov ecx, xrgame_addr
  add ecx, $1FF277;
  call ecx

  pop ecx
  pop ecx
  pop ecx

  pop eax


  push ecx
  mov ecx, eax
  call esi

  ///////////////////////////////
  push eax

  mov ecx, GetParameterUpgraded_int_ptr
  push ecx
  mov ecx, esp
  push name_get_parameter_upgraded
  push ecx
  mov ecx, xrgame_addr
  add ecx, $241cd2;
  call ecx

  pop ecx
  pop ecx
  pop ecx

  pop eax


  push ecx
  mov ecx, eax
  call esi

  ///////////////////////////////
  push eax

  mov ecx, valid_saved_game_int_ptr
  push ecx
  mov ecx, esp
  push name_valid_saved_game_int
  push ecx
  mov ecx, xrgame_addr
  add ecx, $241cd2;
  call ecx

  pop ecx
  pop ecx
  pop ecx

  pop eax


  push ecx
  mov ecx, eax
  call esi

  ///////////////////////////////
  //original
  mov ecx, eax
  call esi
  mov ecx, eax

  jmp register_level_isuishown_ret
end;


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Подмена заполнения шкалы состояния
procedure OverrideItemCondition(itm:pointer; condition:psingle); stdcall;
var
  sect:PChar;
begin
  sect:=GetSection(itm);
  condition^:=game_ini_r_single_def(sect, 'visual_condition', condition^);
end;

procedure CUICellItem__UpdateConditionProgressBar_condition_Patch(); stdcall;
asm
  pushad
    push [edi+$AC]
    push esp
    push edi
    call OverrideItemCondition
    movss xmm0, [esp]
    add esp, 4
  popad
end;

//нужно ли показывать шкалу
function NeedShowCondition(itm:pointer):boolean; stdcall;
begin
  result:=game_ini_line_exist(GetSection(itm), 'visual_condition');
end;

procedure CUICellItem__UpdateConditionProgressBar_needshow_Patch(); stdcall;
asm
  //ZF=0 для того, чтобы не рисовать
  test ebx, ebx
  jne @need_draw
  test ebp, ebp
  jne @need_draw
  test eax, eax
  jne @need_draw

  pushad
    push edi
    call NeedShowCondition
    cmp al, 0
  popad
  jne @need_draw

  test eax, eax //гарантированно верно - уже проверяли
  ret

  @need_draw:
  cmp esi, 0 //гарантированно неверно -> не уходим в Show(false)
  ret
end;

procedure ResizeMapSpots(map:pCUIWindow; k:single); stdcall;
var
  vec_element:pointer;
  spot_wnd:pCUIWindow;
  spot:pCMapSpot;
  scale:single;
begin
  if cardinal(map.m_ChildWndList.vec_start)=0 then exit;
  vec_element:=map.m_ChildWndList.vec_start;
  while vec_element<>map.m_ChildWndList.vec_end do begin
    spot_wnd:=(ppCUIWindow(vec_element))^;
    spot:=dynamic_cast(spot_wnd, 0, RTTI_CUIWindow, RTTI_CMapSpot, false);
    if (spot<>nil) then begin;
      if spot.base_CUIStatic.m_bHeading = 0 then begin
        scale:=spot.base_CUIStatic.base_CUIWindow.base_CUISimpleWindow.m_wndSize.y/spot.m_originSize.y;
        spot.base_CUIStatic.base_CUIWindow.base_CUISimpleWindow.m_wndSize.x:=spot.m_originSize.x*scale*k;
        if (spot.m_border_static<>nil) then begin
          //only square borders suported now! If you need not square - use unused bytes to store origin sizes
          spot.m_border_static.base_CUIWindow.base_CUISimpleWindow.m_wndSize.x:=spot.m_border_static.base_CUIWindow.base_CUISimpleWindow.m_wndSize.y*k;
        end;
      end;
    end;

    vec_element:=pointer(cardinal(vec_element)+sizeof(pointer));
  end;
end;

procedure CUILevelMap__Draw_Patch(); stdcall;
asm
  pushad
    push edi
    push edi
    call GetPDAScreen_kx
    fstp [esp+4]
    call ResizeMapSpots
  popad
  lea eax, [edi+$108]
end;

procedure CUIMiniMap__Draw_Patch(); stdcall;
asm
  pushad
    push ecx
    push ecx
    call get_current_kx
    fstp [esp+4]
    call ResizeMapSpots
  popad
  pop eax
  add esp, $320
  jmp eax
end;

procedure GetPDAScreen_kx_patcher(); stdcall;
asm
  pushad
    // Возвращаемое значение - в стеке FPU
    call GetPDAScreen_kx
  popad
end;

procedure GetPDAScreen_kx_patcher_checkforminimap_esi(); stdcall;
asm
  pushad
  push 0
  push RTTI_CUIMiniMap
  push RTTI_CUICustomMap
  push 0
  push esi
  call dynamic_cast
  test eax, eax
  je @not_minimap
  
  call get_current_kx
  jmp @finish

  @not_minimap:
  call GetPDAScreen_kx

  @finish:
  popad
end;

function ReadFloatUiParameter(uiXml:pointer; path:PAnsiChar; attrib_name:PAnsiChar; def_val:single):single; stdcall;
asm
  pushad
    lea eax, [def_val]
    push [eax]
    push [attrib_name]
    push 0
    push [path]
    
    mov ecx, [uiXml]
    mov eax, [xrGame_addr]
    call [eax+$5132CC] //CXml::ReadAttribFlt
  popad
end;

procedure UpdateStaticPosition(uiXml:pointer; path:PAnsiChar; index:integer; pos:pFVector2); stdcall;
var
  cols_num:integer;
  dx:integer;
  dy:integer;
  x_start:single;
  y_start:single;

  item_col:integer;
  item_row:integer;
begin
  x_start:=floor(ReadFloatUiParameter(uiXml, path, 'x', 0));
  y_start:=floor(ReadFloatUiParameter(uiXml, path, 'y', 0));
  dx:=floor(ReadFloatUiParameter(uiXml, path, 'dx', 0));
  dy:=floor(ReadFloatUiParameter(uiXml, path, 'dy', 0));
  cols_num:=floor(ReadFloatUiParameter(uiXml, path, 'cols_num', 1));

  item_col:= index mod cols_num;
  item_row:= index div cols_num;

  pos.x:=x_start+dx*item_col;
  pos.y:=y_start+dy*item_row;
  Log('Slot '+inttostr(index)+' : ('+inttostr(floor(pos.x))+', '+inttostr(floor(pos.y))+')');
end;

procedure CorrectBeltListOver(); stdcall;
const
  path:PAnsiChar = 'belt_list_over';
asm
  mov edx,[edx]
  lea ecx, [esp+$28]
  pushad
    push ecx

    mov edx, 5
    sub edx, ebx
    push edx

    push path
    add ecx, $C
    push ecx
    call UpdateStaticPosition
  popad
end;

var
  temp_eatable_sect:shared_str;
function OverrideEatableSection(old_sect:pshared_str):pshared_str; stdcall;
var
  base_sect, hud_sect, eat_sect:PAnsiChar;
  ignore_eatable_boost:boolean;
begin
  result:=old_sect;

  base_sect:=get_string_value(old_sect);
  hud_sect:=game_ini_read_string_def(base_sect, 'hud', '');
  ignore_eatable_boost:=game_ini_r_bool_def(base_sect, 'ignore_eatable_boost', false);
  if not ignore_eatable_boost and (length(hud_sect) > 0) then begin
    eat_sect:=game_ini_read_string_def(hud_sect, 'gwr_eatable_object', '');
    if length(eat_sect) > 0 then begin
      //Об увеличении счетчика ссылок не заботимся - все равно строка не протухнет никуда до завершения игры, зато у нас об уменьшении потом голова не будет болеть
      init_string(@temp_eatable_sect);
      assign_string_noaddref(@temp_eatable_sect, eat_sect);
      result:=@temp_eatable_sect;
    end;
  end;
end;

procedure CUIBoosterInfo__SetInfo_Patch(); stdcall;
asm
  //Save pointer to the argument
  lea edx, [esp+8]

  //Execute original code
  sub esp, $24 //28 in original, but we have a return address
  push ebx
  mov ebx, ecx

  //copy return addr to the top of the stack
  push [esp+$28]

  //Change the section
  pushad
  push edx
  push [edx]
  call OverrideEatableSection
  pop edx
  mov [edx],eax
  popad

end;

procedure CUITalkWnd__SwitchToUpgrade_Patch(); stdcall;
asm
  // m_pOurInvOwner->IsTradeEnabled()
  mov eax,[esi+$6C]
  cmp byte ptr [eax+$35],0
  je @finish

  // m_pOthersInvOwner->IsTradeEnabled()
  mov ecx,[esi+$70]
  cmp byte ptr [ecx+$35],0 
  je @finish

  // Original call
  mov eax, xrgame_addr
  add eax, $4afd90
  call eax

  @finish:
end;


procedure CUIInventoryUpgradeWnd__Init_Patch(); stdcall;
const
  disassemble_str:PChar='disassemble_button';
asm
  mov [esi+$54], eax   //original - store created repair button

  mov edx, [esp+4] // get uiXml from arguments of previous call

  pushad
  push esi
  push disassemble_str;
  push edx
  mov eax, xrgame_addr
  add eax, $464a00
  call eax // UIHelper::Create3tButton

  mov CUIInventoryUpgradeWnd__m_btn_disassemble, eax
  add esp, $c
  popad

  pop edx //ret addr
  add esp, $1c  //original
  jmp edx
end;


function TryDisassembleItem(str_buffer:pshared_str; piitem:pointer):boolean; stdcall;
var
  question, section:pchar;
  mechanic_str:string;
  condition:single;
  can_disassemble:boolean;
begin
  //извлекаем имя техника из буферного аргумента
  mechanic_str:=get_string_value(str_buffer);

  condition:=GetCurrentCondition(piitem);
  section:=GetSection(piitem);
  can_disassemble:=script_bool_call('inventory_upgrades.gunsl_can_disassemble_item', section, condition, PChar(mechanic_str));
  question:=script_pchar_call('inventory_upgrades.gunsl_question_disassemble_item', section, condition, can_disassemble, PChar(mechanic_str));

  //Буферный аргумент работает и на выход - забиваем туда строку с сообщением
  assign_string(str_buffer, question);

  //false в результате означает, что вывести messagebox с ошибкой из str_buffer, true - вывести messagebox с подтверждением
  result:=can_disassemble;
end;

procedure ButtonDisassembleCb(CUIActorMenu:pointer; w:pointer; d:pointer); stdcall;
asm
  pushad
  xor eax, eax
  push eax //buffer for shared_str

  mov ecx, CUIActorMenu
  mov eax, xrgame_addr
  add eax, $46f6f0
  call eax // CUIActorMenu::get_upgrade_item
  test eax, eax
  je @finish

  push eax

  mov esi, CUIActorMenu
  mov eax, [esi+$15c] // CUIActorMenu::m_pPartnerInvOwner
  mov ecx, [eax+$40]  // inlined CharacterInfo()
  lea eax, [esp+4]
  push eax //ptr to buffer
  mov eax, xrgame_addr
  add eax, $2b3510
  call eax // Profile()
  push eax
  call TryDisassembleItem
  test al, al
  je @errorbox

  mov ecx, CUIActorMenu
  mov [ecx+$1d8], 2 // CUIActorMenu::m_repair_mode
  push esp
  call get_string_value
  push eax
  mov ecx, CUIActorMenu
  mov eax, xrgame_addr
  add eax, $467080
  call eax // CUIActorMenu::CallMessageBoxYesNo
  jmp @finish

  @errorbox:
  push esp
  call get_string_value
  push eax
  mov ecx, CUIActorMenu
  mov eax, xrgame_addr
  add eax, $466b80
  call eax // CUIActorMenu::CallMessageBoxOK

  @finish:
  //reset shared_str
  push 0
  lea eax, [esp+4]
  push eax
  call assign_string
  
  add esp, 4 //clear place of shared_str
  popad
end;

var
  ButtonDisassembleCb_ptr:pointer;

procedure CUIActorMenu__InitCallbacks_Patch(); stdcall;
asm
  pushad
  lea ecx, [esi+$5c]
  mov eax, CUIInventoryUpgradeWnd__m_btn_disassemble
  push eax
  mov eax, xrgame_addr
  add eax, $4709e0
  call eax //Register
  popad

  pushad
  sub esp, 8
  
  lea edx, [esp]
  push edx
  mov edx, ButtonDisassembleCb_ptr
  mov [esp+8], edx
  mov [esp+4], esi
  mov ecx, CUIInventoryUpgradeWnd__m_btn_disassemble
  push $11
  push ecx
  mov ecx, edi
  mov eax, xrgame_addr
  add eax, $470ad0
  call eax //AddCallback

  add esp, 8
  popad

  pop eax //ret addr

  pop edi //original
  pop esi //original
  add esp, $08 //original

  jmp eax
end;

procedure PerformDisassemble(mechanic:pshared_str; PIItem:pointer); stdcall;
var
  mech_str:string;
  o:pointer;
begin
  o:=dynamic_cast(PIItem, 0, RTTI_CInventoryItem, RTTI_CObject, false);
  if (o<>nil) then begin
    mech_str:=get_string_value(mechanic);
    script_bool_call('inventory_upgrades.gunsl_effect_disassemble', GetSection(PIItem), GetCurrentCondition(PIItem), PChar(mech_str));
    alife_release(get_server_object_by_id(GetCObjectID(o)));
  end;
end;

procedure CUIActorMenu__OnMesBoxYes_Patch(); stdcall;
asm
  cmp byte ptr [esi+$1D8],02
  jne @orig

  pushad
  xor eax, eax
  push eax // buffer for shared_str

  mov ecx, esi
  mov eax, xrgame_addr
  add eax, $46f6f0
  call eax // CUIActorMenu::get_upgrade_item
  push eax

  mov eax, [esi+$15c] // CUIActorMenu::m_pPartnerInvOwner
  mov ecx, [eax+$40]  // inlined CharacterInfo()
  lea eax, [esp+4]
  push eax //ptr to buffer
  mov eax, xrgame_addr
  add eax, $2b3510
  call eax // Profile()
  push eax

  call PerformDisassemble

  //reset buffer for shared_str
  push 0
  lea eax, [esp+4]
  push eax
  call assign_string
  add esp, 4 // delete buffer for shared str

  popad
  mov byte ptr [esi+$1D8],00  // m_repair_mode = 0

  pushad
  //сбросим выбранный предмет апгрейда
  mov ecx, esi
  push 0
  mov eax, xrgame_addr
  add eax, $467ea0
  call eax // CUIActorMenu::SetCurrentItem
  popad


  pop esi //ret addr
  pop esi
  ret $c

  @orig:
  //original
  cmp byte ptr [esi+$1D8],00
end;

procedure CUIInventoryUpgradeWnd__InitInventory_Patch(); stdcall;
asm
  pushad
  push 0
  push CUIInventoryUpgradeWnd__m_btn_disassemble
  call virtual_CUIWindow__Enable
  popad

  //original
  mov eax, [ecx]
  mov edx, [eax+$54]
end;

procedure CUIActorMenu__DeInitUpgradeMode_Patch(); stdcall;
asm
  pushad
  push 0
  push CUIInventoryUpgradeWnd__m_btn_disassemble
  call virtual_CUIWindow__Enable
  popad

  //original
  mov ecx, [eax+$54]
  mov edx, [ecx]
end;

function CheckEnableDisassembleButton(piitem:pointer):boolean; stdcall;
var
  condition:single;
  section:PChar;
begin
  condition:=GetCurrentCondition(piitem);
  section:=GetSection(piitem);
  result:=script_bool_call('inventory_upgrades.gunsl_need_disassemble_button', section, condition, '');
end;

procedure CUIInventoryUpgradeWnd__install_item_Patch(); stdcall;
asm
  mov eax, [esp+$20]
  pushad
  push eax
  call CheckEnableDisassembleButton
  test al, al
  je @finish
  push 1
  push CUIInventoryUpgradeWnd__m_btn_disassemble
  call virtual_CUIWindow__Enable
  @finish:
  popad
  //original
  mov eax, [ecx]
  mov edx, [eax+$24]
end;


function Upgrade_type__GetGroup(upgrade:pointer):pshared_str;
asm
  mov @result, 0
  pushad
  mov ebx, upgrade
  test ebx, ebx
  je @finish
  mov ebx, [ebx+$18] // Group* m_parent_group
  lea ebx, [ebx+$4] // shared_str* Group::m_id
  mov @result, ebx

  @finish:
  popad
end;

function OverrideFreeButtonState(my_upgrade:pointer; active_upgrade:pointer; new_state:pcardinal):boolean; stdcall;
var
  active_group, my_group:pshared_str;
const
  STATE_DISABLED_GROUP:cardinal = 6;
begin
  // Вызывается для апов, на которые сейчас не наведен курсор
  // Для переопределения записать новый стейт в new_state и вернуть true

  result:=false;

  active_group:=Upgrade_type__GetGroup(active_upgrade);
  my_group:=Upgrade_type__GetGroup(my_upgrade);
  if (active_group<>nil) and (my_group<>nil) and (my_upgrade<>active_upgrade) and (get_string_value(active_group) = get_string_value(my_group)) then begin
    result:=true;
    new_state^:=STATE_DISABLED_GROUP;
  end;
end;

procedure UIUpgrade__update_upgrade_state_Patch(); stdcall;
asm
  push 0 //out_buffer
  mov eax, esp

  // Получим текущий активный апгрейд
  pushad
  mov edx, [esi+$5c] // CUIInventoryUpgradeWnd* UIUpgrade::m_parent_wnd
  mov ecx, [edx+$2c] // CUIWindow* CUIInventoryUpgradeWnd::m_pParentWnd
  push eax // save ptr to out_buffer

  push 0
  push RTTI_CUIActorMenu
  push RTTI_CUIWindow
  push 0
  push ecx
  call dynamic_cast
  pop ebx // restore ptr to out_buffer
  test eax, eax
  je @end

  mov ecx, [eax+$14c] // UIInvUpgradeInfo* CUIActorMenu::m_upgrade_info
  cmp ecx, 0
  je @end
  mov ecx, [ecx+$54] // Upgrade_type* UIInvUpgradeInfo::m_upgrade
  mov [ebx], ecx // save Upgrade_type* to buffer

  @end:
  popad


  // Вызовем функцию, которая и решит, отрисовывать нам наш ап как активный, или нет
  pushad
  push eax // arg 3 - ptr to out_buffer
  push [eax] // arg2 - UIUpgrade::Upgrade_type* active_upgrade
  mov ecx, esi
  mov ebx, xrgame_addr
  add ebx, $440600
  call ebx // UIUpgrade::get_upgrade
  push eax // arg1 - UIUpgrade::Upgrade_type* my own upgrade

  call OverrideFreeButtonState
  test al, al
  popad
  pop eax
  je @orig
  mov [esi+$78], eax // m_state = out_buffer

  pop esi //ret addr

  pop esi //orig
  ret

  @orig:
  // original
  mov eax, [esi+$78]
  test eax, eax
end;

procedure UIUpgrade__update_upgrade_state_change_unavailable_focused(); stdcall;
asm
  cmp eax, 01 // original - compare with STATE_FOCUSED
  je @finish
  mov [esi+$78], 6 // m_state := STATE_DISABLED_GROUP

  pop esi //ret addr
  pop esi //original
  ret // from caller

  @finish:
end;

procedure CUIZoneMap__Update_Counter_Patch(); stdcall;
asm
push eax
call GetCurrentDifficulty
cmp eax, gd_stalker
pop eax
jb @original

xor ecx, ecx
ret

@original:
mov ecx,[eax+$310]
sub ecx,[eax+$30C]
sar ecx,02
ret

end;

procedure correct_upgrade_point(x:psingle); stdcall;
begin
  x^:=x^+GetUpgradeMenuPointOffsetX(Is16x9());
end;

procedure CUIUpgradePoint__load_from_xml_Patch(); stdcall;
asm
  // original
  lea eax, [esp+$10]
  movss [eax],xmm0

  pushad
  push eax
  call correct_upgrade_point
  popad
end;


function IsTaskStaticDisabled():boolean; stdcall;
var
  itm:pointer;
begin
  result:=false;
  itm:=GetActorActiveItem();
  if (itm<>nil) and (IsAimNow(itm) or IsHolderInAimState(itm)) then begin
    result:=true;
  end;
end;

procedure CUIGameSP__IR_UIOnKeyboardPress_disabletask_Patch(); stdcall;
asm
  jne @finish //orig
  pushad
  call IsTaskStaticDisabled
  test al, al
  popad
  @finish:
end;

function OnInventoryKeyPress():boolean; stdcall;
var
  inventory_animator:PAnsiChar;
begin
  // вернуть false если отображать инвентарь сейчас не требуется, иначе true
  inventory_animator:=GetInventoryShowAnimator();

  result:=true;
  if inventory_animator<>nil then begin
    result:=false;
    OnInventoryShowAttempt();
  end;
end;

procedure CUIGameSP__IR_UIOnKeyboardPress_oninventoryopen_Patch(); stdcall;
asm
  pushad
  call OnInventoryKeyPress
  test al, al
  popad

  je @skip_inventory_show

  // original
  lea ecx, [ebx-$10]
  mov eax, xrgame_addr
  add eax, $4b1b80
  call eax // ShowActorMenu();

  @skip_inventory_show:
end;

function NeedHideMoveToBugItem(slot:cardinal):boolean; stdcall;
begin
  result:=(slot = 4);
end;

procedure CUIActorMenu__PropertiesBoxForSlots_Patch(); stdcall;
asm
  cmp byte ptr [eax+edx*4+08],00 //original
  jne @finish
  pushad
  movzx eax, bp
  push eax
  call NeedHideMoveToBugItem
  cmp al, 0
  popad
  @finish:
end;

procedure CUIGameSP__OnFrame_disabletask_Patch(); stdcall;
asm
  pop ecx //ret addr
  add esp, 8  //orig
  pushad
  call IsTaskStaticDisabled
  test al, al
  popad
  je @finish
  mov bl, 1  //b_remove = true
  @finish:
  test bl, bl //orig
  jmp ecx
end;

procedure OnWeaponInfoAmmoTypeIconSet(ammo1:pCUIStatic; ammo2:pCUIStatic; wpn:pointer); stdcall;
var
  flags:byte;
  idx:cardinal;
  lanim1, lanim2:PAnsiChar;
begin
  flags:=LA_CYCLIC + LA_ONLYALPHA + LA_TEXTURECOLOR;
  idx:=GetAmmoTypeIndex(wpn, false);
  lanim1:='ui_ammo_hint_passive';
  lanim2:='ui_ammo_hint_passive';
  if idx = 0 then begin
    lanim1:='ui_ammo_hint_active';
  end else if idx = 1 then begin
    lanim2:='ui_ammo_hint_active';  
  end;
  virtual_CUILightAnimColorConroller__SetColorAnimation(@(ammo1^.base_CUILightAnimColorConrollerImpl.base_CUILightAnimColorConroller), lanim1, @flags, 0);
  virtual_CUILightAnimColorConroller__SetColorAnimation(@(ammo2^.base_CUILightAnimColorConrollerImpl.base_CUILightAnimColorConroller), lanim2, @flags, 0);
end;

procedure CUIWpnParams__SetInfo_SecondAmmoType_Patch(); stdcall;
asm
  movss [esp+$24],xmm0 //original

  mov ecx, [esp+$8F8+4] //cur_wpn
  pushad
  push ecx
  lea edi, [ebp+$1f8c] // ptr to CUIWpnParams::m_stAmmoType2
  push edi
  lea edi, [ebp+$1eb0] // ptr to CUIWpnParams::m_stAmmoType1
  push edi
  call OnWeaponInfoAmmoTypeIconSet
  popad

  mov ecx, edi //original
end;

function GetOverriddenAmmoString(wpn:pointer):PAnsiChar; stdcall;
var
  idx:byte;
begin
  idx:=GetAmmoTypeIndex(wpn);
  result:=GetCurrentCartridgeSectionByType(wpn, idx);
  if result = nil then begin
    result:=GetCurrentCartridgeSectionByType(wpn, 0);
  end;
end;

procedure CUIWpnParams__SetInfo_OverrideAmmoString_Patch(); stdcall;
asm
  mov eax, [esp+$14] // selected weapon
  push eax //temp buf
  lea ecx, [esp]

  pushad
  push ecx

  push eax
  call GetOverriddenAmmoString

  pop ecx
  mov [ecx], eax
  popad

  pop eax
end;

function IsActorBurned():boolean; stdcall;
var
  act:pointer;
  cond:pCActorCondition;
  burn_amount:single;
begin
  result:=false;
  act:=GetActor();
  if act = nil then exit;

  cond:=GetActorConditions(act);
  if cond = nil then exit;

  burn_amount:=CEntityCondition__BleedingSpeed_reimpl(@cond.base_CEntityCondition, (1 shl EHitType__eHitTypeBurn));

  result:=burn_amount > 0;
end;

procedure CUIMainIngameWnd__UpdateMainIndicators_Patch(); stdcall;
const
  burn_icon:string = 'ui_gunsl_inGame2_circle_fire';
asm
  //original instruction
  fst dword ptr [esp+$14]
  mov ecx, [esi+$68]

  //check if bleeding
  pushad
  call IsActorBurned
  test al, al
  popad

  je @original_icon
  mov [esp+$14], 0 // bleeding = 0

  mov eax,[ecx]
  mov edx,[eax+$58]
  push 01
  call edx   // m_ind_bleeding->Show(true);

  mov eax,[esi+$68]
  lea ecx,[eax+$54]
  mov eax,[ecx]
  mov edx,[eax+04]
  push burn_icon
  call edx // m_ind_bleeding->InitTexture

  pop eax // ret addr
  mov eax, xrgame_addr
  add eax, $45a26b
  jmp eax // to m_ind_bleeding->SetColorAnimation("ui_fast_blinking_alpha", flags)

  @original_icon:
  ret
end;

procedure CheckForForceUpdateAddonsIcons(wpn:pointer; needforceupdate:pbyte); stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if (buf <> nil) and (buf.need_update_icon) then begin
    needforceupdate^:=1;
  end;
end;

procedure CUIWeaponCellItem__Update_forceaddonupdate_Patch(); stdcall;
asm
  setne [esp+$0B+4] //original

  lea edx, [esp+$0B+4]
  pushad
  push edx
  mov ecx,[esi+$110]
  push ecx
  call CheckForForceUpdateAddonsIcons
  popad

  mov edx,[eax+$150] // original
end;

procedure UpdateWeaponIcon(wpn:pointer; UIWeaponCellItem:pCUIStatic); stdcall;
var
  x, y, dx, dy, w, h:single;
const
  CELL_SIZE:single=50;
begin
  // обновляем иконку оружия в зависимости от установленных аддонов

  if GetInstalledUpgradesCount(wpn) > 0 then begin
    dx:=ModifyFloatUpgradedValue(wpn, 'inv_grid_x', 0);
    dy:=ModifyFloatUpgradedValue(wpn, 'inv_grid_y', 0);
    if (abs(dx)>0.5) or (abs(dy)>0.5) then begin
      x:=game_ini_r_single(GetSection(wpn), 'inv_grid_x');
      y:=game_ini_r_single(GetSection(wpn), 'inv_grid_y');
      w:=game_ini_r_single(GetSection(wpn), 'inv_grid_width');
      h:=game_ini_r_single(GetSection(wpn), 'inv_grid_height');
      UIWeaponCellItem.m_UIStaticItem.TextureRect.lt.x:=floor((x+dx)*CELL_SIZE);
      UIWeaponCellItem.m_UIStaticItem.TextureRect.lt.y:=floor((y+dy)*CELL_SIZE);
      UIWeaponCellItem.m_UIStaticItem.TextureRect.rb.x:=floor((x+w+dx)*CELL_SIZE);
      UIWeaponCellItem.m_UIStaticItem.TextureRect.rb.y:=floor((y+h+dy)*CELL_SIZE);     

    end;
  end;
end;

procedure CUIWeaponCellItem__Update_Patch(); stdcall;
asm
  pushad
  mov ecx,[esi+$110] // weapon object from m_pData
  push esi //this
  push ecx
  call UpdateWeaponIcon
  popad

  //original
  mov bl,[esi+$C8]
end;

procedure ui_actor_state_wnd__UpdateActorInfo_burnicon_Patch(); stdcall;
asm
  // так как код оригинала подразумевает только 3 варианта иконок состояния (и в кровотечении они все использованы) - добавляем иконку в здоровье (там по умолчанию только прогрессбар)

  // m_state[stt_health]->show_static(false, 1);
  mov ecx,[esi+$54]
  push 01
  push 00
  mov eax, xrgame_addr
  add eax, $46f9e0
  call eax

  pushad
  call IsActorBurned
  test al, al
  popad

  je @original
  // m_state[stt_health]->show_static(true, 1);
  mov ecx,[esi+$54]
  push 01
  push 01
  mov eax, xrgame_addr
  add eax, $46f9e0
  call eax

  // value = 0
  mov [esp+$58], 0

  @original:
  fld [esp+$58]
  fabs
end;

procedure CreateAddonIcon(ppicon:ppCUIStatic; cell:pointer); stdcall;
asm
  // Нужно выполнить все те действия, что и в CUIWeaponCellItem::CreateIcon, создав иконку и сохранив указатель на нее в буфере, на который указывает ppicon
  pushad
  mov esi, xrgame_addr
  mov ecx, [esi+$5127b4]        // xrMemory instance
  push $DC                      // sizeof(CUIStatic)
  call [esi+$5127b0]            //xrMemory::mem_alloc
  mov ebx, [ppicon]
  mov [ebx], eax

  push eax                      //save for further use in this proc

  mov ecx, eax
  mov edx, xrgame_addr
  add edx, $47b250
  call edx                      //CUIStatic constructor

  mov eax, [esp]                //allocated CUIStatic ptr
  mov byte ptr [eax+$4c], 01    //SetAutoDelete	(true)

  mov ecx, [cell]
  mov eax, [ecx]                //vtable
  mov edx,[eax+$18]             //virtual AttachChild ptr
  push [esp]                    //pass allocated CUIStatic ptr
  call edx                      //CUIWeaponCellItem::AttachChild

  mov edx, xrgame_addr
  add edx, $465600
  call edx                      //InventoryUtilities::GetEquipmentIconsShader

  mov ecx, [esp]                //allocated CUIStatic ptr  
  push eax
  mov edx, xrgame_addr
  add edx, $47ace0
  call edx                      //SetShader

  mov ecx, [cell]
  lea ecx, [ecx+$54]            //cast cell to ITextureOwner
  mov eax,[ecx]                 //vtable
  mov edx,[eax+$18]             //virtual GetTextureColor ptr
  call edx

  mov ecx, [esp]                //allocated CUIStatic ptr
  push eax  
  lea ecx, [ecx+$54]            //cast it to ITextureOwner
  mov eax,[ecx]                 //vtable
  mov edx,[eax+$14]             //virtual SetTextureColor ptr
  call edx

  pop eax                       //restore saved ptr to CUIStatic
  popad
end;

procedure CUIWeaponCellItem__InitAddon(cell:pointer; picon:pCUIStatic; section:PAnsiChar; offset_x:single; offset_y:single); stdcall;
asm
  pushad
  mov ecx, [cell]
  movzx eax, byte ptr [ecx+$C8] // m_bHeading
  push eax
  mov eax, [offset_y]
  push eax
  mov eax, [offset_x]
  push eax
  mov eax, [section]
  push eax
  mov eax, [picon]
  push eax

  mov eax, xrgame_addr
  add eax, $49d7c0
  call eax
  popad
end;


{ CellItemBuffer }

constructor CellItemBuffer.Create(itm:pointer; cell:pointer);
begin
  _my_item:=itm;
  _my_cell:=cell;
  setlength(_up_icons, 0);
end;

destructor CellItemBuffer.Destroy;
begin
  setlength(_up_icons, 0);
  inherited;
end;

procedure CellItemBuffer._ProcessUpgrade(section:PAnsiChar);
var
  i:integer;
  icon_section:PAnsiChar;
const
  UPGRADE_ICON_PARAM_NAME:PAnsiChar='upgrade_addon_icon';
  UPGRADE_ICON_OFFSET_X_PARAM_NAME:PAnsiChar='upgrade_addon_icon_offset_x';
  UPGRADE_ICON_OFFSET_Y_PARAM_NAME:PAnsiChar='upgrade_addon_icon_offset_y';
begin
  i:=length(_up_icons);
  setlength(_up_icons, i+1);
  section:=game_ini_read_string(section, 'section');
  if game_ini_line_exist(section, UPGRADE_ICON_PARAM_NAME) then begin
    _up_icons[i].enabled:=true;
    _up_icons[i].icon_section:=game_ini_read_string(section, UPGRADE_ICON_PARAM_NAME);
    _up_icons[i].offset.x:=game_ini_r_single_def(section, UPGRADE_ICON_OFFSET_X_PARAM_NAME, 0);
    _up_icons[i].offset.y:=game_ini_r_single_def(section, UPGRADE_ICON_OFFSET_Y_PARAM_NAME, 0);

    CreateAddonIcon(@_up_icons[i].icon, _my_cell);
    CUIWeaponCellItem__InitAddon(_my_cell, _up_icons[i].icon, _up_icons[i].icon_section, _up_icons[i].offset.x, _up_icons[i].offset.y);
    log('Created icon '+inttohex(cardinal(_up_icons[i].icon),8) +' for upgrade '+ _up_icons[i].icon_section+', offset '+floattostr(_up_icons[i].offset.x)+' '+floattostr(_up_icons[i].offset.y));
  end else begin
    _up_icons[i].enabled:=false;
  end;
end;

procedure CellItemBuffer.Update();
var
  ups_count, i, old_cnt:integer;
begin
//  Log('Update for wpn '+ inttohex(cardinal(_my_item), 8));
  ups_count:=GetInstalledUpgradesCount(_my_item);
  if ups_count > length(_up_icons) then begin
    old_cnt:=length(_up_icons);
    for i:=old_cnt to ups_count - 1 do begin
      _ProcessUpgrade(GetInstalledUpgradeSection(_my_item, i));
    end;
  end;
end;

procedure CellItemBuffer.SetItem(new_item:pointer);
begin
  _my_item:=new_item;
end;

procedure CreateCellItemBuffer(p:pCellItemBuffer; data:pointer; cell:pointer); stdcall;
begin
  Log('Create buffer for CellItem '+inttohex(cardinal(p), 8)+', weapon '+inttohex(cardinal(data), 8));
  p^:=CellItemBuffer.Create(data, cell);
end;

procedure FreeCellItemBuffer(p:pCellItemBuffer); stdcall;
begin
  if p^<>nil then begin
    Log('Destroy buffer for CellItem '+inttohex(cardinal(p), 8));
    FreeAndNil(p^);
  end;
end;

procedure CUICellItem__init_zeroupgradepos_Patch();stdcall;
asm
  mov [esi+$108], 0 // m_upgrade_pos.x
  mov [esi+$10c], 0 // m_upgrade_pos.y  
end;

procedure CUIWeaponCellItem__constructor_CreateBuffer_Patch(); stdcall
asm
  pushad
  push esi            //this
  mov eax, [esi+$110] // m_pData
  push eax
  lea edi, [esi+$108] // m_upgrade_pos.x
  push edi
  call CreateCellItemBuffer
  popad

  mov [esi+$124],eax // original
end;

procedure CUICellItem__destructor_FreeBuffer_Patch(); stdcall;
asm
  pushad
  lea esi, [esi+$108] // m_upgrade_pos.x
  push esi
  call FreeCellItemBuffer
  mov [esi], 0  
  popad

  cmp byte ptr [esi+$11C],00 //original
end;

procedure UpdateCellItemBuffer(p:pCellItemBuffer); stdcall;
begin
  if p^<>nil then begin
    p^.Update();
  end;
end;

procedure SetCellItemBufferItem(p:pCellItemBuffer; itm:pointer); stdcall;
begin
  if p^<>nil then begin
    p^.SetItem(itm);
  end;
end;

procedure CUICellItem__Update_Patch();stdcall;
asm
  mov ecx,[esi+$104] // CUICellItem::m_upgrade
  mov edx,[ecx+$5]   // m_upgrade.m_wndPos.x
  mov [esp+$18],edx
  mov edx,[ecx+$9]  // m_upgrade.m_wndPos.y
  mov [esp+$1c], edx

  pushad
  lea esi, [esi+$108] // m_upgrade_pos.x
  push esi
  call UpdateCellItemBuffer
  popad
  test eax, $FFFFFFFC // restore flags register value
end;

procedure CUICellItem__PopChild_Patch(); stdcall;
asm
  push ecx //save this

  // original
  mov edx, [eax+$7c]
  call edx // UpdateItemText

  pop ecx // restore this

  pushad
  mov eax, [ecx+$110] // this.m_pData
  lea esi, [ecx+$108] // this.m_upgrade_pos.x
  push eax
  push esi
  call SetCellItemBufferItem
  popad

  pushad
  mov eax, [esi+$110] // itm.m_pData
  lea esi, [esi+$108] // itm.m_upgrade_pos.x
  push eax
  push esi
  call SetCellItemBufferItem
  popad
end;

function Init():boolean;stdcall;
var
  jmp_addr:cardinal;
begin
  result:=false;
  bShowPauseString:=pointer(xrengine_addr+$9032c);

  jmp_addr:=xrGame_addr+$24A762;
  register_level_isuishown_ret:=xrgame_addr+$24a768;
  IsUIShown_ptr:=@IsUIShown;
  IndicatorsShown_adapter_ptr:=@IndicatorsShown_adapter;
  IsInventoryShown_adapter_ptr:=@IsInventoryShown_adapter;
  IsPickupMode_adapter_ptr:=@IsPickupMode_adapter;
  IsTacticHudInstalled_adapter_ptr:=@IsTacticHudInstalled_adapter;
  ElectronicProblemsBegin_ptr:=@ElectronicProblemsBegin;
  ElectronicProblemsEnd_ptr:=@ElectronicProblemsEnd;
  ElectronicProblemsReset_ptr:=@ElectronicProblemsReset;
  ElectronicProblemsApply_ptr:=@ElectronicProblemsApply;
  GetParameterUpgraded_int_ptr:=@GetParameterUpgraded_int;
  valid_saved_game_int_ptr:=@valid_saved_game_int;
  IsActorControlled_adapter_ptr:=@IsActorControlled_adapter;
  IsActorBurned_adapter_ptr:=@IsActorBurned_adapter;

  ButtonDisassembleCb_ptr:=@ButtonDisassembleCb;

  //экспорт в скрипты
  if not WriteJump(jmp_addr, cardinal(@register_level_isuishown), 6, false) then exit;

  jmp_addr:=xrGame_addr+$49f10f;
  if not WriteJump(jmp_addr, cardinal(@CUICellItem__UpdateConditionProgressBar_condition_Patch), 8, true) then exit;

  jmp_addr:=xrGame_addr+$49f074;
  if not WriteJump(jmp_addr, cardinal(@CUICellItem__UpdateConditionProgressBar_needshow_Patch), 10, true) then exit;

  //запрет на сокрытие индикаторов худа при включении окна пда/инвентаря
  nop_code(xrgame_addr+$4b0bc5, 1, char(00)); //pda
  nop_code(xrgame_addr+$4b1be5, 1, char(00)); //inventory
  nop_code(xrgame_addr+$466778, 5);           //отключение повторной отрисовки квикслотов и бустеров, когда активен инвентарь
  nop_code(xrgame_addr+$46676B, 5);           //отключение повторной отрисовки миникарты, когда активен инвентарь

  //[bug] баг в CUICheckButton::OnMouseDown - при нажатии правой/средней клавиши мыши состояние кнопки не поменяется, а сигнал о клике отправится. Критично для ПДА.
  nop_code(xrgame_addr+$495EFC, 1, char($24));

  //[bug] баг - при смене соотношения сторон экрана метки на карте (CMapSpot) не изменяют пропорции
  //По аналогичным причинам имеются проблемы с овалами на ПДА
  //отключаем движковое применение коэффициента сжатия в CMapSpot::Load (вызовы SetWidth)
  nop_code(xrgame_addr+$443EF0, 34);
  nop_code(xrgame_addr+$44404E, 44);
  //переносим учет этих факторов в CUILevelMap::Draw и CUIMiniMap::Draw (vftable:0x60), домножая перед отображением на свои коэффициенты
  jmp_addr:=xrGame_addr+$44711B;
  if not WriteJump(jmp_addr, cardinal(@CUILevelMap__Draw_Patch), 6, true) then exit;
  jmp_addr:=xrGame_addr+$446C25;
  if not WriteJump(jmp_addr, cardinal(@CUIMiniMap__Draw_Patch), 6, true) then exit;

  //фиксим коэффициенты самой глобальной карты для пда
  //1.CUICustomMap::Init_internal
  jmp_addr:=xrGame_addr+$445A4F;
  if not WriteJump(jmp_addr, cardinal(@GetPDAScreen_kx_patcher), 5, true) then exit;
  jmp_addr:=xrGame_addr+$445A61;
  if not WriteJump(jmp_addr, cardinal(@GetPDAScreen_kx_patcher), 5, true) then exit;
  //2.CUILevelMap::Init_internal
  jmp_addr:=xrGame_addr+$4466A4;
  if not WriteJump(jmp_addr, cardinal(@GetPDAScreen_kx_patcher), 5, true) then exit;
  jmp_addr:=xrGame_addr+$4466B6;
  if not WriteJump(jmp_addr, cardinal(@GetPDAScreen_kx_patcher), 5, true) then exit;
  //3.CUICustomMap::ConvertRealToLocal
  jmp_addr:=xrGame_addr+$446DD1;
  if not WriteJump(jmp_addr, cardinal(@GetPDAScreen_kx_patcher_checkforminimap_esi), 5, true) then exit;
  jmp_addr:=xrGame_addr+$446DE3;
  if not WriteJump(jmp_addr, cardinal(@GetPDAScreen_kx_patcher_checkforminimap_esi), 5, true) then exit;
  jmp_addr:=xrGame_addr+$446E4F;
  if not WriteJump(jmp_addr, cardinal(@GetPDAScreen_kx_patcher_checkforminimap_esi), 5, true) then exit;
  jmp_addr:=xrGame_addr+$446F0E;
  if not WriteJump(jmp_addr, cardinal(@GetPDAScreen_kx_patcher_checkforminimap_esi), 5, true) then exit;

  //В конце CUICustomMap::ConvertRealToLocal меняем указатель выходного буфера с ESI на EDX, чтобы не перезаписывался this (нам он енужен для патча xrGame_addr+$446E4F)
  nop_code(xrGame_addr+$446e24, 1, CHR($54));
  nop_code(xrGame_addr+$446e46, 1, CHR($02));
  nop_code(xrGame_addr+$446e48, 1, CHR($4a));
  nop_code(xrGame_addr+$446e55, 1, CHR($0a));
  nop_code(xrGame_addr+$446e58, 1, CHR($c2));
  nop_code(xrGame_addr+$446e5a, 1, CHR($1a));

  //CUIRankingWnd::get_favorite_weapon - избавиться от вызова get_current_kx в отрисовке иконки оружия
  jmp_addr:=xrGame_addr+$44C254;
  if not WriteJump(jmp_addr, cardinal(@GetPDAScreen_kx_patcher), 5, true) then exit;   

  //правим CUIPdaWnd::Show, чтобы всегда при доставании пда отрисовывалась карта
  if not nop_code(xrgame_addr+$442b23, 2) then exit;

  //Фикс позиции заглушек слотов для артефактов (CUIActorMenu::Construct)
  //Отключено в связи с невозможностью выстроить сами слоты не то, что в сложной конфигурации, а даже просто вертикально
  //jmp_addr:=xrGame_addr+$46AB17;
  //if not WriteJump(jmp_addr, cardinal(@CorrectBeltListOver), 6, true) then exit;

  // В CUIBoosterInfo::SetInfo в самом начале проверяем, не относится ли текущая секция к предметам с худом, и если так - заменяем ее на секцию итейбла
  jmp_addr:=xrGame_addr+$450e90;
  if not WriteJump(jmp_addr, cardinal(@CUIBoosterInfo__SetInfo_Patch), 6, true) then exit;
  
  //в CUITalkWnd::SwitchToUpgrade нет проверки на то, что у нас разрешено грейдиться (как в CUITalkWnd::SwitchToTrade) - из-за этого возможен грейд у Дядьки Яра при нажатии спринта. Точнее, есть закомменченная и с вызовом метода IsInvUpgradeEnabled, который... не очень актуален. Скопируем проверку.
  jmp_addr:=xrGame_addr+$456a13;
  if not WriteJump(jmp_addr, cardinal(@CUITalkWnd__SwitchToUpgrade_Patch), 5, true) then exit;


  //в CUIInventoryUpgradeWnd::Init добавляем создание кнопки разборки
  jmp_addr:=xrGame_addr+$43f088;
  if not WriteJump(jmp_addr, cardinal(@CUIInventoryUpgradeWnd__Init_Patch), 6, true) then exit;

  //в CUIActorMenu::InitCallbacks (xrgame.dll+46a140) добавляем колбэк на кнопку разбора
  jmp_addr:=xrGame_addr+$46a26a;
  if not WriteJump(jmp_addr, cardinal(@CUIActorMenu__InitCallbacks_Patch), 5, true) then exit;

  // в CUIActorMenu::OnMesBoxYes(xrgame.dll+468500) добавляем разборку предмета (когда m_repair_mode = 2)
  jmp_addr:=xrGame_addr+$468514;
  if not WriteJump(jmp_addr, cardinal(@CUIActorMenu__OnMesBoxYes_Patch), 7, true) then exit;

  //в CUIInventoryUpgradeWnd::InitInventory(xrgame.dll+43f6b0) по умолчанию отключаем кнопку разбора
  jmp_addr:=xrGame_addr+$43f8ba;
  if not WriteJump(jmp_addr, cardinal(@CUIInventoryUpgradeWnd__InitInventory_Patch), 5, true) then exit;

  //в CUIInventoryUpgradeWnd::install_item(xrgame.dll+43f210) включаем кнопку разбора при необходимости
  jmp_addr:=xrGame_addr+$43f227;
  if not WriteJump(jmp_addr, cardinal(@CUIInventoryUpgradeWnd__install_item_Patch), 5, true) then exit;

  //в CUIActorMenu::DeInitUpgradeMode (xrgame.dll+46f8d0) отключаем кнопку разбора
  jmp_addr:=xrGame_addr+$46f904;
  if not WriteJump(jmp_addr, cardinal(@CUIActorMenu__DeInitUpgradeMode_Patch), 5, true) then exit;

  // в UIUpgrade::update_upgrade_state (xrgame.dll+440cd0) делаем подсветку группы, когда на один из ее элементов наведен курсор:
  // в блоке "case BUTTON_FREE:" добавляем: если есть выбранный апгрейд (CUIActorMenu::m_upgrade_info::m_upgrade!=nullptr) и его группа совпадает с группой нашего (получаем наш вызовом UIUpgrade::get_upgrade) - ставим STATE_DISABLED_GROUP
  jmp_addr:=xrGame_addr+$440d21;
  if not WriteJump(jmp_addr, cardinal(@UIUpgrade__update_upgrade_state_Patch), 5, true) then exit;

  // В UIUpgrade::update_upgrade_state (xrgame.dll+440cd0) заставляем подсвечиваться недоступный для уствновки ап, на который навели курсор(где m_button_state == BUTTON_FOCUSED возвращаем не STATE_DISABLED_FOCUSED)
  jmp_addr:=xrGame_addr+$440d46;
  if not WriteJump(jmp_addr, cardinal(@UIUpgrade__update_upgrade_state_change_unavailable_focused), 5, true) then exit;

  // В CUIZoneMap::Update отключаем отображение числа контактов на сложности выше новичка
  jmp_addr:=xrGame_addr+$45d65f;
  if not WriteJump(jmp_addr, cardinal(@CUIZoneMap__Update_Counter_Patch), 15, true) then exit;

  // в CUIUpgradePoint::load_from_xml добавляем смещение точки по оси x при режиме 16x9
  jmp_addr:=xrGame_addr+$4409f2;
  if not WriteJump(jmp_addr, cardinal(@CUIUpgradePoint__load_from_xml_Patch), 6, true) then exit;

  // [bug] в CUIGameSP::IR_UIOnKeyboardPress отключаем отображение активного задания в режиме прицеливания, чтобы избежать рисования на сетке 2го рендера (актуально для гаусса с его рамками)
  jmp_addr:=xrGame_addr+$4b620f;
  if not WriteJump(jmp_addr, cardinal(@CUIGameSP__IR_UIOnKeyboardPress_disabletask_Patch), 7, true) then exit;

  // в CUIGameSP::IR_UIOnKeyboardPress добавляем обработку вызова окна инвентаря
  jmp_addr:=xrGame_addr+$4b61ff;
  if not WriteJump(jmp_addr, cardinal(@CUIGameSP__IR_UIOnKeyboardPress_oninventoryopen_Patch), 8, true) then exit;

  // [bug] в CUIGameSP::OnFrame удаляем отображение активного задания, если мы вошли в прицеливание
  jmp_addr:=xrGame_addr+$4b5983;
  if not WriteJump(jmp_addr, cardinal(@CUIGameSP__OnFrame_disabletask_Patch), 5, true) then exit;

  // [bug] так как у нас в слоте гранат slot_persistent_4 = false, то появляется пункт "убрать в рюскзак" для всех застекованных гранат, одна из которых в слоте
  // Выбор ведет к вылету. Для недопущения - в CUIActorMenu::PropertiesBoxForSlots не даем добавить пункт для слота гранат
  jmp_addr:=xrGame_addr+$46d563;
  if not WriteJump(jmp_addr, cardinal(@CUIActorMenu__PropertiesBoxForSlots_Patch), 5, true) then exit;

  // В CUIWpnParams::SetInfo назначаем "анимацию" иконки активного и неактивного типа патронов
  jmp_addr:=xrGame_addr+$454134;
  if not WriteJump(jmp_addr, cardinal(@CUIWpnParams__SetInfo_SecondAmmoType_Patch), 8, true) then exit;

  // В CUIWpnParams::SetInfo делаем отображение строки не нулевого типа патронов, а заряженного сейчас
  jmp_addr:=xrGame_addr+$453dee;
  if not WriteJump(jmp_addr, cardinal(@CUIWpnParams__SetInfo_OverrideAmmoString_Patch), 9, true) then exit;


  //Иконка горения вместо кровотечения
  jmp_addr:=xrGame_addr+$45a1b5;
  if not WriteJump(jmp_addr, cardinal(@CUIMainIngameWnd__UpdateMainIndicators_Patch), 7, true) then exit;
  jmp_addr:=xrGame_addr+$46ffe7;
  if not WriteJump(jmp_addr, cardinal(@ui_actor_state_wnd__UpdateActorInfo_burnicon_Patch), 6, true) then exit;

  //в CUIWeaponCellItem::Update выставляем bForceReInitAddons, когда в буфере установлено требование обновить иконки аддонов
  jmp_addr:=xrGame_addr+$49df80;
  if not WriteJump(jmp_addr, cardinal(@CUIWeaponCellItem__Update_forceaddonupdate_Patch), 11, true) then exit;

  //в CUIWeaponCellItem::Update производим дополнительные действия
  jmp_addr:=xrGame_addr+$49df67;
  if not WriteJump(jmp_addr, cardinal(@CUIWeaponCellItem__Update_Patch), 6, true) then exit;

  //В CUICellItem::Update меняем pos.set(m_upgrade_pos) на pos.set(m_upgrade->GetWndPos()) чтобы сделать m_upgrade_pos неиспользуемым + вызываем апдейт буфера
  jmp_addr:=xrGame_addr+$49efc0;
  if not WriteJump(jmp_addr, cardinal(@CUICellItem__Update_Patch), 6, true) then exit;

  // В CUICellItem::init вырезаем присваивание m_upgrade_pos и вставляем вместо него обнуление
  jmp_addr:=xrGame_addr+$49ea56;
  if not WriteJump(jmp_addr, cardinal(@CUICellItem__init_zeroupgradepos_Patch), 18, true) then exit;

  //В CUICellItem::~CUICellItem добавляем уничтожение буфера
  jmp_addr:=xrGame_addr+$49f6a4;
  if not WriteJump(jmp_addr, cardinal(@CUICellItem__destructor_FreeBuffer_Patch), 7, true) then exit;

  //В CUIWeaponCellItem::CUIWeaponCellItem добавляем конструирование буфера
  jmp_addr:=xrGame_addr+$49dd54;
  if not WriteJump(jmp_addr, cardinal(@CUIWeaponCellItem__constructor_CreateBuffer_Patch), 6, true) then exit;

  // В CUICellItem::PopChild заставляем вызвать апдейты иконок
  jmp_addr:=xrGame_addr+$49f2d3;
  if not WriteJump(jmp_addr, cardinal(@CUICellItem__PopChild_Patch), 5, true) then exit;

  // CUIWpnParams::SetInfo - xrgame.dll+4535b0
  // UIUpgrade::set_texture - xrgame.dll+440470
  // UIUpgrade::OnMouseAction - xrgame.dll+440f40
  // CUIInventoryUpgradeWnd::HighlightHierarchy - xrgame.dll+af830
  /// Root::highlight_hierarchy - xrgame.dll+b1800
  // Upgrade::highlight_down - xrgame.dll+b07a0
  // Group::highlight_down - xrgame.dll+b0260
  // UIUpgrade::update_upgrade_state - xrgame.dll+440cd0
  // CUIInventoryUpgradeWnd::set_info_cur_upgrade - xrgame.dll+43fa60
  // CUIActorMenu::SetInfoCurUpgrade - xrgame.dll+46f7f0
  // UIInvUpgradeInfo::init_upgrade - xrgame.dll+441470
  // UIUpgrade::Update - xrgame.dll+440f00

  //CUIActorMenu::InitPartnerInventoryContents - xrgame.dll+46ebe0
  //CAI_Stalker::can_sell - xrgame.dll+18e4f0
  //CAI_Stalker::update_sell_info - xrgame.dll+18e3b0
  //CAI_Stalker::tradable_item - xrgame.dll+18e240
  //CUIWeaponCellItem::Update - xrgame.dll+49df60
  //CUIWeaponCellItem::InitAddon - xrgame.dll+49d7c0
  //ui_actor_state_wnd::UpdateActorInfo - xrgame.dll+46ff40
  //CUICellItem::Update - xrgame.dll+49ee80
  //CUICellItem::~CUICellItem - xrgame.dll+49f6a0
  //CUIWeaponCellItem::CUIWeaponCellItem - xrgame.dll+49dd30
  //CUIWeaponCellItem::CreateIcon - xrgame.dll+49d730
  //CUIWeaponCellItem::InitAddon - xrgame.dll+49d7c0

  result:=true;
end;

end.
