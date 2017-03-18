unit UIUtils;

interface
uses MatVectors;

{type CUIWindow = packed record
  _unknown:array [0..54] of byte;
end;

type CUIStatic = packed record
end;
type pCUIStatic = ^CUIStatic;

type CUITextWnd = packed record
end;
type pCUITextWnd = ^CUITextWnd;

type CUIMotionIcon = packed record
end;
type pCUIMotionIcon = ^CUIMotionIcon;

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
function CDialogHolder__TopInputReceiver(): {CUIDialogWnd} pointer; stdcall;
procedure HideShownDialogs(); stdcall;
function IsUIShown():boolean; stdcall;

procedure ShowPDAMenu(); stdcall;
procedure HidePDAMenu(); stdcall;
function IsPDAWindowEnabled():boolean; stdcall;
procedure SetPDAWindowVisible(status:boolean); stdcall;
procedure SetPDAWindowEnabled(status:boolean); stdcall;
function IsPDAWindowVisible():boolean; stdcall;
function GetPDACursorCoords():PFVector2;

function IsInventoryShown():boolean; stdcall;

function Init():boolean;stdcall;

implementation
uses BaseGameData, collimator, ActorUtils, HudItemUtils, gunsl_config;

var
  register_level_isuishown_ret:cardinal;
  IsUIShown_ptr, IndicatorsShown_adapter_ptr, IsInventoryShown_adapter_ptr:pointer;

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

function CDialogHolder__TopInputReceiver(): {CUIDialogWnd} pointer; stdcall;
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

procedure HidePDAMenu_Internal(); stdcall;
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

procedure HidePDAMenu(); stdcall;
begin
  if not IsPDAWindowVisible() and IsPDAWindowEnabled() then begin
    SetPDAWindowVisible(true);
  end;
  HidePDAMenu_Internal
end;

function IsPDAWindowEnabled():boolean; stdcall;
asm
  pushad
    mov @result, 0
    call CurrentGameUI
    cmp eax, 0
    je @finish
    
    mov ecx, [eax+$54]
    cmp ecx, 0
    je @finish

//    mov bl, [ecx+4] //CUISimpleWindow.m_bShowMe
//    mov bl, [ecx+$4E] //CUIWindow.m_bIsEnabled
//    mov @result, bl

    mov ebx, [ecx+$54]//CUIDialogWnd.m_pParentHolder
    cmp ebx, 0
    je @finish
    mov @result, 1

    @finish:
  popad
end;

function IsPDAWindowVisible():boolean; stdcall;
asm
  pushad
    mov @result, 0
    call CurrentGameUI
    cmp eax, 0
    je @finish
    
    mov ecx, [eax+$54]
    cmp ecx, 0
    je @finish

    mov bl, [ecx+4] //CUISimpleWindow.m_bShowMe
    mov @result, bl
    @finish:
  popad
end;

procedure SetPDAWindowVisible(status:boolean); stdcall;
asm
  pushad
    call CurrentGameUI
    cmp eax, 0
    je @finish
    mov ecx, [eax+$54]

    mov bl, status
    mov [ecx+4], bl //CUISimpleWindow.m_bShowMe
    @finish:
  popad
end;

procedure SetPDAWindowEnabled(status:boolean); stdcall;
asm
  pushad
    call CurrentGameUI
    cmp eax, 0
    je @finish
    mov ecx, [eax+$54]

    mov bl, status
    mov [ecx+$4E], bl //CUIWindow.m_bIsEnabled
    @finish:
  popad
end;

function GetPDACursorCoords():PFVector2;
asm
  mov @result, 0
  pushad
    call CurrentGameUI
    cmp eax, 0
    je @finish
    mov ecx, [eax+$54]
    cmp ecx, 0
    je @finish

    add ecx, $3C //CUIWindow.cursor_pos
    mov @result, ecx

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
  end;
end;

function IndicatorsShown_adapter():boolean; stdcall;
asm
  pushad
    call IndicatorsShown
    mov @result, al
  popad
end;

procedure register_level_isuishown(); stdcall;
const
  name:PChar='is_ui_shown';
  name2:PChar='indicators_shown';
  name3:PChar='inventory_shown';
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

function GetUICursor():pCUICursor; stdcall;
asm
  pushad
    mov eax, xrgame_addr
    add eax, $43C8B0
    call eax
    mov @result, eax
  popad
end;


function Init():boolean;stdcall;
var
  jmp_addr:cardinal;
begin
  jmp_addr:=xrGame_addr+$24A762;
  register_level_isuishown_ret:=xrgame_addr+$24a768;
  IsUIShown_ptr:=@IsUIShown;
  IndicatorsShown_adapter_ptr:=@IndicatorsShown_adapter;
  IsInventoryShown_adapter_ptr:=@IsInventoryShown_adapter;

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

  result:=true;
end;



end.
