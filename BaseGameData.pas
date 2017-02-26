unit BaseGameData;

interface

type TKeyHoldState = record
  IsActive: boolean;
  IsHoldContinued:boolean;
  ActivationStart: cardinal;
  HoldDeltaTimePeriod: cardinal; //время, после истечения которого мы засчитываем удержание клавиши
end;

function Init:boolean;
function WriteJump(var write_addr:cardinal; dest_addr:cardinal; addbytescount:cardinal=0; writecall:boolean=false):boolean;
function nop_code(addr:cardinal; count:cardinal):boolean;
function GetGameTickCount:cardinal;
function GetTimeDeltaSafe(starttime:cardinal):cardinal;
function WriteBufAtAdr(addr:cardinal; buf:pointer; count:cardinal):boolean;

function GetNextSubStr(var data:string; var buf:string; separator:char=char($00)):boolean;
procedure Log(text:string; IsError:boolean = false);stdcall;
function Is16x9():boolean;stdcall;
function str_container_dock(str:PChar):pointer; stdcall;


var
  xrGame_addr:cardinal;
  xrCore_addr:cardinal;
  xrEngine_addr:cardinal;
  xrRender_R1_addr:cardinal;
  xrRender_R2_addr:cardinal;
  xrRender_R3_addr:cardinal;
  xrRender_R4_addr:cardinal;      
  hndl:cardinal;

const
  //Младшие слова адресов vftable различных классов объектов, надо для "самопальной" RTTI
  W_BM16:word=$4744;
  W_RPG7:word=$F56C;

implementation
uses windows, strutils, sysutils;

const
  xrGame:PChar='xrGame';
  xrCore:PChar='xrCore';
  xrEngine:PChar='xrEngine.exe';
  xrRender_R1:PChar='xrRender_R1';  
  xrRender_R2:PChar='xrRender_R2';
  xrRender_R3:PChar='xrRender_R3';
  xrRender_R4:PChar='xrRender_R4';    

function nop_code(addr:cardinal; count:cardinal):boolean;
const opcode:char=CHR($90);
var rb:cardinal;
    i:cardinal;
begin
  result:=true;
  for i:=addr to addr+count-1 do begin
    writeprocessmemory(hndl, PChar(i), @opcode, 1, rb);
    if rb<>1 then result:=false;
  end;
end;

function WriteBufAtAdr(addr:cardinal; buf:pointer; count:cardinal):boolean;
var rb:cardinal;
begin
  result:=true;
  writeprocessmemory(hndl, PChar(addr), buf, count, rb);
  if rb<>count then result:=false;
end;

function WriteJump(var write_addr:cardinal; dest_addr:cardinal; addbytescount:cardinal=0; writecall:boolean=false):boolean;
var offsettowrite:cardinal;
    rb:cardinal;
    opcode:char;
begin
  result:=true;
  if writecall then opcode:=CHR($E8) else opcode:=CHR($E9);
  offsettowrite:=dest_addr-write_addr-5;
  writeprocessmemory(hndl, PChar(write_addr), @opcode, 1, rb);
  if rb<>1 then result:=false;
  writeprocessmemory(hndl, PChar(write_addr+1), @offsettowrite, 4, rb);
  if rb<>4 then result:=false;
  if addbytescount>5 then nop_code(write_addr+5, addbytescount-5);
  write_addr:=write_addr+addbytescount;
end;

function GetGameTickCount:cardinal;
asm
  mov eax, $492ed8 //xrEngine.Device
  mov eax, [eax+$28];
  mov @result, eax
end;


function GetTimeDeltaSafe(starttime:cardinal):cardinal;
var
  curtime:cardinal;
begin
  curtime:=GetGameTickCount;
  result:=curtime-starttime;
  //обработаем переполнение
  if result>curtime then result:=$FFFFFFFF-starttime+curtime;
end;

function GetNextSubStr(var data:string; var buf:string; separator:char=char($00)):boolean;
var p, i:integer;
begin
  p:=0;
  for i:=1 to length(data) do begin
    if data[i]=separator then begin
      p:=i;
      break;
    end;
  end;

  if p>0 then begin
    buf:=leftstr(data, p-1);
    buf:=trim(buf);
    data:=rightstr(data, length(data)-p);
    data:=trim(data);
    result:=true;
  end else begin
    if trim(data)<>'' then begin
      buf:=trim(data);
      data:='';
      result:=true;
    end else result:=false;
  end;
end;

procedure Log(text:string; IsError:boolean = false);stdcall;
var
  paramText:PChar;
begin
  try
    text:='GNSLWP: '+text;
    if IsError then
      text:= '! ' + text
    else
      text:= '~ ' + text;

    paramText:=PChar(text);
    asm
      pushad
      pushf

      push text

      mov eax, xrCore_addr
      add eax, $158B0
      call eax
      add esp, 4

      popf
      popad
    end;
  except
  end;
end;

function Is16x9():boolean;stdcall;
asm
    pushad
    pushfd

    mov eax, xrgame_addr
    add eax, $43c830
    call eax
    
    mov @result, al

    popfd
    popad
end;


function GetStrContainer():pointer;stdcall;
asm
  mov eax, xrgame_addr
  mov eax, [eax+$512814]
  mov eax, [eax]
  mov @result, eax
end;

function str_container_dock(str:PChar):pointer; stdcall
asm
    pushad
    pushfd

    push str

    call GetStrContainer
    mov eax, ecx

    mov eax, xrcore_addr
    add eax, $20690
    call eax
    mov @Result, eax

    popfd
    popad
end;



function Init:boolean;
begin
  result:=false;
  hndl:=GetCurrentProcess;
  xrGame_addr := GetModuleHandle(xrGame);
  xrCore_addr := GetModuleHandle(xrCore);
  xrEngine_addr:=GetModuleHandle(xrEngine);
  xrRender_R1_addr:=GetModuleHandle(xrRender_R1);  
  xrRender_R2_addr:=GetModuleHandle(xrRender_R2);
  xrRender_R3_addr:=GetModuleHandle(xrRender_R3);
  xrRender_R4_addr:=GetModuleHandle(xrRender_R4);      
  
  if xrEngine_addr=0 then xrEngine_addr:=$400000;

  if (xrGame_addr = 0) or (xrCore_addr = 0) then exit;

  //в младших 16 битах GetModuleHandle может возвращать флаги - поэтому обнуляем их для получения адреса загрузки модуля 
  xrGame_addr := (xrGame_addr shr 16) shl 16;
  xrCore_addr := (xrCore_addr shr 16) shl 16;
  xrRender_R1_addr := (xrRender_R1_addr shr 16) shl 16;  
  xrRender_R2_addr := (xrRender_R2_addr shr 16) shl 16;
  xrRender_R3_addr := (xrRender_R3_addr shr 16) shl 16;
  xrRender_R4_addr := (xrRender_R4_addr shr 16) shl 16;
  result:=true;
end;


end.
