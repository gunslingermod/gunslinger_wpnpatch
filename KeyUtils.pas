unit KeyUtils;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

const

  kActPress:cardinal = 1;
  kActRelease:cardinal = 2;

	kLEFT:cardinal=$0;
	kRIGHT:cardinal=$1;
	kUP:cardinal=$2;
	kDOWN:cardinal=$3;
	kJUMP:cardinal=$4;
	kCROUCH:cardinal=$5;
	kACCEL:cardinal=$6;
	kSPRINT_TOGGLE:cardinal=$7;
	kFWD:cardinal=$8;
	kBACK:cardinal=$9;
	kL_STRAFE:cardinal=$A;
	kR_STRAFE:cardinal=$B;
	kL_LOOKOUT:cardinal=$C;
	kR_LOOKOUT:cardinal=$D;
	kCAM_1:cardinal=$E;
	kCAM_2:cardinal=$F;
	kCAM_3:cardinal=$10;
	kCAM_ZOOM_IN:cardinal=$11;
	kCAM_ZOOM_OUT:cardinal=$12;
	kTORCH:cardinal=$13;
	kNIGHT_VISION:cardinal=$14;
	kDETECTOR:cardinal=$15;
	kWPN_1:cardinal=$16;
	kWPN_2:cardinal=$17;
	kWPN_3:cardinal=$18;
	kWPN_4:cardinal=$19;
	kWPN_5:cardinal=$1A;
	kWPN_6:cardinal=$1B;
	kARTEFACT:cardinal=$1C;
	kWPN_NEXT:cardinal=$1D;
	kWPN_FIRE:cardinal=$1E;
	kWPN_ZOOM:cardinal=$1F;
	kWPN_ZOOM_INC:cardinal=$20;
	kWPN_ZOOM_DEC:cardinal=$21;
	kWPN_RELOAD:cardinal=$22;
	kWPN_FUNC:cardinal=$23;    //переключение на подствол
	kWPN_FIREMODE_PREV:cardinal=$24;
	kWPN_FIREMODE_NEXT:cardinal=$25;
	kPAUSE:cardinal=$26;
	kDROP:cardinal=$27;
	kUSE:cardinal=$28;
	kSCORES:cardinal=$29;
	kCHAT:cardinal=$2A;
	kCHAT_TEAM:cardinal=$2B;
	kSCREENSHOT:cardinal=$2C;
	kQUIT:cardinal=$2D;
	kCONSOLE:cardinal=$2E;
	kINVENTORY:cardinal=$2F;
	kBUY:cardinal=$30;
	kSKIN:cardinal=$31;
	kTEAM:cardinal=$32;
	kACTIVE_JOBS:cardinal=$33;
	kVOTE_BEGIN:cardinal=$34;
  kADMIN:cardinal=$35;
	kVOTE:cardinal=$36;
	kVOTEYES:cardinal=$37;
	kVOTENO:cardinal=$38;
	kNEXT_SLOT:cardinal=$39;
	kPREV_SLOT:cardinal=$3A;
	kSPEECH_MENU_0:cardinal=$3B;
	kSPEECH_MENU_1:cardinal=$3C;
	kQUICK_USE_1:cardinal=$3D;
	kQUICK_USE_2:cardinal=$3E;
	kQUICK_USE_3:cardinal=$3F;
	kQUICK_USE_4:cardinal=$40;
	kQUICK_SAVE:cardinal=$41;
	kQUICK_LOAD:cardinal=$42;
	kALIFE_CMD:cardinal=$43;
	kLASTACTION:cardinal=$44;
	kNOTBINDED:cardinal=$45;
	kFORCEDWORD:cardinal=$FF;

  //действия мода
  kLASER:cardinal = $46;
  kTACTICALTORCH:cardinal = $47;
  kQUICK_GRENADE:cardinal = $48;
  kWPN_ZOOM_ALTER:cardinal = $49;
  kQUICK_KICK:cardinal = $4A;
  kBRIGHTNESS_PLUS:cardinal = $4B;
  kBRIGHTNESS_MINUS:cardinal = $4C;

function IsActionKeyPressed(EGameAction:cardinal):boolean; stdcall;
function get_action_dik(EGameAction:cardinal; idx:integer):cardinal; stdcall; //idx принимает значения: 0 - основная клавиша, 1 - вспомогательная, -1 - дефаултовая назначенная
function IsKeyPressed(dik:cardinal):boolean; stdcall;
function IsActionKeyPressedInGame(EGameAction:cardinal):boolean; stdcall;

implementation
uses BaseGameData, UIUtils, ConsoleUtils;

function IsActionKeyPressed(EGameAction:cardinal):boolean; stdcall;
var
  key1, key2:cardinal;
begin
  key1:=get_action_dik(EGameAction, 0);
  key2:=get_action_dik(EGameAction, 1);

  result:= ((key1<>0) and IsKeyPressed(key1)) or ((key2<>0) and IsKeyPressed(key2)); 
end;

function IsKeyPressed(dik:cardinal):boolean; stdcall;
asm
  pushad
    xor eax, eax
    
    mov ebx, xrGame_addr;
    mov ebx, [ebx+$512e80] //получаем pInput
    mov ebx, [ebx]  //получаем CInput

    mov esi, dik
    cmp esi, $100
    jnl @mouse_suspected

    cmp [ebx+esi*4+$5c], 0
    je @finish
    mov eax, 1
    jmp @finish

    @mouse_suspected:
    lea edx, [esi-$151]
    cmp edx, 7
    ja @finish
    cmp [ebx+esi*4-$508], 0
    je @finish
    mov eax, 1
    jmp @finish    


    @finish:
    mov @result, al
  popad
end;


function get_action_dik(EGameAction:cardinal; idx:integer):cardinal; stdcall;
asm
  pushad
    mov eax, xrgame_addr
    add eax, $25bbd0      //получаем адрес get_action_dik

    push idx
    push EGameAction
    call eax
    add esp, 8

    mov @result, eax

  popad
end;

function IsActionKeyPressedInGame(EGameAction:cardinal):boolean; stdcall;
begin
  if IsActionKeyPressed(EGameAction) and (not IsConsoleShown()) and (not IsDemoRecord()) and (CDialogHolder__TopInputReceiver()=nil) then
    result:=true
  else
    result:=false;
end;


end.
