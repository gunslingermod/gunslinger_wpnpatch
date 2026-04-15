library initialpatch;
uses
  windows, sysutils;

{$R *.res}

function nop_code(addr:cardinal; count:cardinal; opcode:char = CHR($90)):boolean;
var rb:cardinal;
    i:cardinal;
    old:cardinal;
begin
  result:=true;
  virtualprotect(PChar(addr), count, PAGE_EXECUTE_READWRITE, @old);

  for i:=addr to addr+count-1 do begin
    writeprocessmemory(GetCurrentProcess(), PChar(i), @opcode, 1, rb);
    if rb<>1 then result:=false;
  end;

  virtualprotect(PChar(addr), count, old, @rb);
end;

function WriteJump(var write_addr:cardinal; dest_addr:cardinal; addbytescount:cardinal=0; writecall:boolean=false):boolean;
var offsettowrite:cardinal;
    rb:cardinal;
    opcode:char;
    old:cardinal;
    vprotcnt:cardinal;
begin
  result:=true;

  if writecall then opcode:=CHR($E8) else opcode:=CHR($E9);
  offsettowrite:=dest_addr-write_addr-5;

  if addbytescount>5 then begin
    vprotcnt:=addbytescount;
  end else begin
    vprotcnt:=5
  end;
  virtualprotect(PChar(write_addr), vprotcnt, PAGE_EXECUTE_READWRITE, @old);

  writeprocessmemory(GetCurrentProcess(), PChar(write_addr), @opcode, 1, rb);
  if rb<>1 then result:=false;
  writeprocessmemory(GetCurrentProcess(), PChar(write_addr+1), @offsettowrite, 4, rb);
  if rb<>4 then result:=false;
  if addbytescount>5 then nop_code(write_addr+5, addbytescount-5);
  write_addr:=write_addr+addbytescount;

  virtualprotect(PChar(write_addr), vprotcnt, old, rb);
end;

type xr_token = packed record
  name:PAnsiChar;
  id:integer;
end;
pxr_token = ^xr_token;
ppxr_token = ^pxr_token;

var
  xrEngine_addr:cardinal;
  xrCore_addr:cardinal;
  pSettings:pCardinal;

procedure Log(text:string; IsError:boolean = false);stdcall;
var
  paramText:PChar;
begin
  try
    text:='GNSLIN: '+text;
    if IsError then
      text:= '! ' + text
    else
      text:= '~ ' + text;

    paramText:=PChar(text);
    asm
      pushad
      pushf

      push paramText

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

function GetSystemIni():pointer;stdcall;
begin
  result:= pointer(pSettings^);
end;

function game_ini_line_exist(section:PChar; key:PChar):boolean;stdcall;
asm
    pushad
    pushfd

    push key
    push section

    call GetSystemIni
    mov ecx, eax

    mov eax, xrCore_addr
    add eax, $182D0
    call eax
    mov @result, al

    popfd
    popad
end;

function game_ini_r_bool(section:PChar; key:PChar):boolean;stdcall;
asm
    pushad
    pushfd

    push key
    push section
    call GetSystemIni
    mov ecx, eax

    mov eax, xrCore_addr
    add eax, $18970
    call eax

    mov @result, al

    popfd
    popad
end;

function game_ini_r_bool_def(section:PChar; key:PChar; def:boolean; is_default:pboolean=nil):boolean;stdcall;
begin
  if game_ini_line_exist(section, key) then begin
    result:=game_ini_r_bool(section, key);
    if is_default<>nil then is_default^:=false;
  end else begin
    result:=def;
    if is_default<>nil then is_default^:=true;
  end;
end;


function game_ini_read_string(section:PChar; key:PChar):PChar;stdcall;
asm
    pushad
    pushfd

    push key
    push section

    call GetSystemIni
    mov ecx, eax

    mov eax, xrCore_addr
    add eax, $18530
    call eax
    
    mov @result, eax

    popfd
    popad
end;


function GetConsole():pointer; stdcall;
begin
asm
  mov eax, xrengine_addr
  cmp eax, 0
  je @finish

  add eax, $92d5c
  mov eax, [eax] //получаем консоль
  mov @result, eax

  @finish:
end;
end;


procedure Console__Execute(cmd:PChar); stdcall;
asm
  pushad
    call GetConsole
    test eax, eax
    je @finish
    push cmd

    mov ecx, eax
    mov ebx, xrengine_addr
    add ebx, $48560
    call ebx

    @finish:
  popad
end;

procedure CorrectAllowedGameRenderers(); stdcall;
var
  p_vid_quality_token:ppxr_token;
  vid_quality_token:pxr_token;
  t:xr_token;
  new_allowed_renderers:array of xr_token;
  i,j:integer;
  flag:boolean;
  cmd:string;
begin
  p_vid_quality_token:=ppxr_token(xrengine_addr+$92d60);
  vid_quality_token:=p_vid_quality_token^;
  setlength(new_allowed_renderers, 0);
  
  i:=0;
  while(true) do begin
    t:=pxr_token(@((PAnsiChar(vid_quality_token))[sizeof(xr_token)*i]))^;
    if t.id = -1 then break;


    flag:=game_ini_r_bool_def('gunslinger_allowed_renderers', t.name, true);
    if flag then begin
      Log(string(t.name)+' is enabled');
      j:=length(new_allowed_renderers);
      setlength(new_allowed_renderers, j+1);
      new_allowed_renderers[j]:=t;
    end else begin
      Log(string(t.name)+' is disabled');
    end;
    i:=i+1;
  end;

  for i:=0 to length(new_allowed_renderers)-1 do begin
    vid_quality_token^:=new_allowed_renderers[i];
    vid_quality_token:= @(PAnsiChar(vid_quality_token)[sizeof(xr_token)]);
  end;
  vid_quality_token.name:=nil;
  vid_quality_token.id:=-1;

  setlength(new_allowed_renderers, 0);

  if game_ini_line_exist('gunslinger_allowed_renderers', 'preferred') then begin
    cmd:='renderer ' + game_ini_read_string('gunslinger_allowed_renderers', 'preferred');
    Console__Execute(PAnsiChar(cmd));
  end;

end;

procedure CEngineAPI__CreateRendererList_correction_Patch(); stdcall;
asm
  pushad
  call CorrectAllowedGameRenderers
  popad

  //original
  pop edi
  pop esi
  pop ebp
  pop ebx
  add esp,$14
  ret
end;

const
  xrCore:PChar='xrCore';
  xrEngine:PChar='xrEngine.exe';
var
  addr:cardinal;
begin
  xrEngine_addr:=GetModuleHandle(xrEngine);
  xrCore_addr := GetModuleHandle(xrCore);
  pSettings:=GetProcAddress(xrCore_addr, '?pSettings@@3PBVCInifile@@B');
  Log('pSettings='+inttohex(cardinal(pSettings), 8));

  // В CEngineAPI::CreateRendererList корректируем список доступных рендеров
  addr:=xrEngine_addr+$4e72f;
  if not WriteJump(addr, cardinal(@CEngineAPI__CreateRendererList_correction_Patch), 5, false) then exit;
end.
