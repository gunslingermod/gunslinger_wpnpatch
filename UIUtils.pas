unit UIUtils;

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
pCMapLocation=pointer;


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
  m_alignment:cardinal;
  _unused1:byte;
  _unused2:word;
end;
pCUISimpleWindow=^CUISimpleWindow;

WINDOW_LIST = packed record
  vec_start:pointer;
  vec_end:pointer;
  vec_memend:pointer;    
end;

CUIWindow = packed record
  base_CUISimpleWindow:CUISimpleWindow;
  _unknown:cardinal;
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
  m_bCustomDraw:byte;
  _unused1:byte;
  _unused2:word;
end;
pCUIWindow=^CUIWindow;

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
  base_ITextureOwner:ITextureOwner;
  base_CUILightAnimColorConrollerImpl:CUILightAnimColorConrollerImpl;
  m_lanim_xform:lanim_cont_xf;
  m_pTextControl:pCUILines;
  m_bStretchTexture:byte;
  m_bTextureEnable:byte;
  m_bHeading:byte;
  m_bConstHeading:byte;  
  m_UIStaticItem:CUIStaticItem;
  m_fHeading:single;
  m_TextureOffset:FVector2;
  TextItemControl:pCUILines;
  m_stat_hint_text:shared_str;
end;
pCUIStatic=^CUIStatic;

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

function IsInventoryShown():boolean; stdcall;

function Init():boolean;stdcall;



var
  bShowPauseString:pBoolean;

implementation
uses BaseGameData, collimator, ActorUtils, HudItemUtils, gunsl_config, sysutils, dynamic_caster, misc, math;

var
  register_level_isuishown_ret:cardinal;
  IsUIShown_ptr, IndicatorsShown_adapter_ptr, IsInventoryShown_adapter_ptr:pointer;
  ElectronicProblemsBegin_ptr, ElectronicProblemsEnd_ptr, ElectronicProblemsReset_ptr, ElectronicProblemsApply_ptr:pointer;

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
asm
  pushad
    mov eax, xrgame_addr
    add eax, $4afd90
    call eax
    mov @result, eax
  popad
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

function g_hud():{CCustomHUD*}pointer; stdcall;
asm
  mov eax, xrengine_addr
  mov eax, [eax+$92d3c]
  mov @result, eax
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
  pda:=GetPDA();
  if pda<>nil then begin
    result:=pda.base_CUIDialogWnd.base_CUIWindow.base_CUISimpleWindow.m_bShowMe<>0;
  end else begin
    result:=false;
  end;
end;

function GetPDA():pCUIPDAWnd; stdcall;
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

function IsInventoryShown():boolean; stdcall;
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

function IsInventoryShown_adapter():boolean; stdcall;
asm
  pushad
    call IsInventoryShown
    mov @result, al
  popad
end;

function IsUIShown():boolean; stdcall;
asm
  pushad
    call CurrentGameUI
    movzx eax, byte ptr [eax+$58]
    mov @result, al
  popad
end;

function IndicatorsShown():boolean; stdcall;
var
  wpn:pointer;
begin
  result:=IsUIShown();
  if result then begin
    wpn:=GetActorActiveItem();
    result:= (wpn=nil) or not ( (IsAimNow(wpn) and not IsGrenadeMode(wpn)) and (IsScopeAttached(wpn) or (GetScopeStatus(wpn)=1)) and not IsUINotNeededToBeHidden(wpn));
    if result and (wpn<>nil) and IsBino(wpn) and IsAimNow(wpn) and game_ini_r_bool_def(GetSection(wpn), 'zoom_hide_ui', false) then begin
      result:=false;
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

function GetUICursor():pCUICursor; stdcall;
asm
  pushad
    mov eax, xrgame_addr
    add eax, $43C8B0
    call eax
    mov @result, eax
  popad
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
asm
  pushad
    call IndicatorsShown
    mov @result, al
  popad
end;

function ElectronicProblemsBegin():boolean; stdcall;
asm
  pushad
    call ElectronicsProblemsInc
    mov @result, al
  popad
end;

function ElectronicProblemsReset():boolean; stdcall;
asm
  pushad
    call ResetElectronicsProblems
    mov @result, 1
  popad
end;

function ElectronicProblemsApply():boolean; stdcall;
asm
  pushad
    call ElectronicsProblemsImmediateApply
    mov @result, 1
  popad
end;

function ElectronicProblemsEnd():boolean; stdcall;
asm
  pushad
    call ElectronicsProblemsDec
    mov @result, al
  popad
end;

procedure register_level_isuishown(); stdcall;
const
  name:PChar='is_ui_shown';
  name2:PChar='indicators_shown';
  name3:PChar='inventory_shown';

  name_electroproblem_begin:PChar='electronics_break';
  name_electroproblem_end:PChar='electronics_restore';
  name_electroproblem_reset:PChar='electronics_reset';
  name_electroproblem_apply:PChar='electronics_apply';
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
  spot:pCMapSpot;
  scale:single;
begin
  if cardinal(map.m_ChildWndList.vec_start)=0 then exit;
  vec_element:=map.m_ChildWndList.vec_start;
  while vec_element<>map.m_ChildWndList.vec_end do begin
    spot:=pCMapSpot(pcardinal(vec_element)^);
    if dynamic_cast(spot, 0, RTTI_CUIWindow, RTTI_CMapSpot, false)=nil then continue;
    scale:=spot.base_CUIStatic.base_CUIWindow.base_CUISimpleWindow.m_wndSize.y/spot.m_originSize.y;
    spot.base_CUIStatic.base_CUIWindow.base_CUISimpleWindow.m_wndSize.x:=spot.m_originSize.x*scale*k;
    if (spot.m_border_static<>nil) then begin
      //only square borders suported now! If you need not square - use unused bytes to store origin sizes
      spot.m_border_static.base_CUIWindow.base_CUISimpleWindow.m_wndSize.x:=spot.m_border_static.base_CUIWindow.base_CUISimpleWindow.m_wndSize.y*k;
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
    call GetPDAScreen_kx
  popad
end;

procedure CUICursor__UpdateCursorPosition_Patch();
asm
  mov esi, ecx
  cmp byte ptr [esi+$19], 0
  je @finish  //уже не используем виндовый курсор

  pushad
    call IsInputExclusive
    cmp al, 1
  popad


  @finish:
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

function Init():boolean;stdcall;
var
  jmp_addr:cardinal;
begin
  bShowPauseString:=pointer(xrengine_addr+$9032c);

  jmp_addr:=xrGame_addr+$24A762;
  register_level_isuishown_ret:=xrgame_addr+$24a768;
  IsUIShown_ptr:=@IsUIShown;
  IndicatorsShown_adapter_ptr:=@IndicatorsShown_adapter;
  IsInventoryShown_adapter_ptr:=@IsInventoryShown_adapter;
  ElectronicProblemsBegin_ptr:=@ElectronicProblemsBegin;
  ElectronicProblemsEnd_ptr:=@ElectronicProblemsEnd;
  ElectronicProblemsReset_ptr:=@ElectronicProblemsReset;
  ElectronicProblemsApply_ptr:=@ElectronicProblemsApply;

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
  //По аналогичным причинам имеются проблемы с оваласи на ПДА
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
  if not WriteJump(jmp_addr, cardinal(@GetPDAScreen_kx_patcher), 5, true) then exit;
  jmp_addr:=xrGame_addr+$446DE3;
  if not WriteJump(jmp_addr, cardinal(@GetPDAScreen_kx_patcher), 5, true) then exit;
  jmp_addr:=xrGame_addr+$446E4F;
  if not WriteJump(jmp_addr, cardinal(@GetPDAScreen_kx_patcher), 5, true) then exit;

  //CUIRankingWnd::get_favorite_weapon - избавиться от вызова get_current_kx в отрисовке иконки оружия
  jmp_addr:=xrGame_addr+$44C254;
  if not WriteJump(jmp_addr, cardinal(@GetPDAScreen_kx_patcher), 5, true) then exit;   

  //правим CUIPdaWnd::Show, чтобы всегда при доставании пда отрисовывалась карта
  if not nop_code(xrgame_addr+$442b23, 2) then exit;

  //фикс позиции курсора - чтобы не скакал при переключениях режима мыши в ПДА
  jmp_addr:=xrGame_addr+$4D9834;
  if not WriteJump(jmp_addr, cardinal(@CUICursor__UpdateCursorPosition_Patch), 6, true) then exit;

  //Фикс позиции заглушек слотов для артефактов (CUIActorMenu::Construct)
  //Отключено в связи с невозможностью выстроить сами слоты не то, что в сложной конфигурации, а даже просто вертикально
  //jmp_addr:=xrGame_addr+$46AB17;
  //if not WriteJump(jmp_addr, cardinal(@CorrectBeltListOver), 6, true) then exit;

  result:=true;
end;



end.
