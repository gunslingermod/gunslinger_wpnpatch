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
uses windows;

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
