unit UIUtils;

interface

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

function CurrentGameUI(): {CUIGameCustom*} pointer; stdcall;
function AddCustomStatic(cuigamecustom_this: pointer; id:PChar; bSingleInstance: boolean): {SDrawStaticStruct*} pointer; stdcall;

function g_hud():{CCustomHUD*}pointer; stdcall;

procedure CUILines__SetText(cuilines: pointer; msg:PChar); stdcall;
procedure virtual_CUIWindow__Show (cuiwindow: pointer; status:cardinal); stdcall;
procedure CustomStaticSetText(sdrawstaticstruct:pointer; text:pchar); stdcall;
function CDialogHolder__TopInputReceiver(): {CUIDialogWnd} pointer; stdcall;
procedure HideShownDialogs(); stdcall;

procedure ShowPDAMenu(); stdcall;
procedure HidePDAMenu(); stdcall;
function IsPDAShown():boolean; stdcall;


implementation
uses BaseGameData;

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

function IsPDAShown():boolean; stdcall;
asm
  mov @result, 0
  pushad
    call CurrentGameUI
    cmp eax, 0
    je @finish
    mov ecx, [eax+$54]
    mov bl, [ecx+4]
    mov @result, bl
    @finish:
  popad
end;



end.
