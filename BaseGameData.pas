unit BaseGameData;

interface
  function Init:boolean;
  function WriteJump(var write_addr:cardinal; dest_addr:cardinal; addbytescount:cardinal=0; writecall:boolean=false):boolean;
  function nop_code(addr:cardinal; count:cardinal):boolean;

var
  xrGame_addr:cardinal;
  xrCore_addr:cardinal;
  hndl:cardinal;

const
  //Младшие слова адресов vftable различных классов объектов, надо для "самопальной" RTTI
  W_BM16:word=$4744;
  W_RPG7:word=$F56C;

{  //новые анимации
  anm_reload:PChar='anm_reload';
  anm_reload_w_gl:PChar='anm_reload_w_gl';
  anm_reload_empty:PChar='anm_reload_empty';
  anm_reload_empty_w_gl:PChar='anm_reload_empty_w_gl';
  anm_changecartridgetype:PChar='anm_changecartridgetype';
  anm_changecartridgetype_w_gl:PChar='anm_changecartridgetype_w_gl';
  anm_jamned:PChar = 'anm_jamned';
  anm_jamned_last:PChar = 'anm_jamned_last';
  anm_jamned_w_gl:PChar = 'anm_jamned_w_gl';
  anm_jamned_last_w_gl:PChar = 'anm_jamned_last_w_gl';}

  //Новые звуки
  sndReload:PChar='sndReload';
  sndReloadEmpty:PChar='sndReloadEmpty';
  snd_reload_empty:PChar='snd_reload_empty';
  snd_changecartridgetype:PChar = 'snd_changecartridgetype';
  sndChangeCartridgeType:PChar = 'sndChangeCartridgeType';

  snd_jamned:PChar = 'snd_jamned';
  sndJamned:PChar = 'sndJamned';
  snd_jamned_last:PChar = 'snd_jamned_last';
  sndJamnedLast:PChar = 'sndJamnedLast';

  //Остальное
  scope_name:PChar = 'scope_name';
  body:PChar = 'body';
  wpn_silencer:PChar = 'wpn_silencer';
  magazin:PChar = 'magazin';

implementation
uses windows;

const
  xrGame:PChar='xrGame';
  xrCore:PChar='xrCore';

function Init:boolean;
begin
  result:=false;
  hndl:=GetCurrentProcess;
  xrGame_addr := GetModuleHandle(xrGame);
  xrCore_addr := GetModuleHandle(xrCore);
  if (xrGame_addr = 0) or (xrCore_addr = 0) then exit;
  xrGame_addr := (xrGame_addr shr 16) shl 16;
  xrCore_addr := (xrCore_addr shr 16) shl 16;
  result:=true;
end;

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

end.
