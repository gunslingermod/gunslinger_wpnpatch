unit xr_strings;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface



type
str_value = packed record
  dwReference:cardinal;
  length:cardinal;
  dwCRC:cardinal;
  next:pointer;
  value:char; //really array here
end;

pstr_value = ^str_value;

shared_str = packed record
  p_:pstr_value;
end;

pshared_str = ^shared_str;

str_container=packed record
  //TODO:Fill
end;
pstr_container=^str_container;
ppstr_container=^pstr_container;

string_path=array [0..519] of Char;

procedure init_string(str:pshared_str); stdcall;
procedure assign_string(str:pshared_str; text:PChar); stdcall;
procedure assign_string_noaddref(str:pshared_str; text:PChar); stdcall; //'Hacky' version, try don't use
function get_string_value(str:pshared_str):PAnsiChar; stdcall;
function Init():boolean; stdcall;
function str_container_dock(str:PChar):pstr_value; stdcall;

implementation
uses basegamedata;
var
  g_pStringContainer:ppstr_container;

procedure assign_string_noaddref(str:pshared_str; text:PChar); stdcall;
begin
  assign_string(str, text);
  if (str^.p_<>nil) then begin
    str^.p_.dwReference:=str^.p_.dwReference-1;  
  end;
end;

procedure assign_string(str:pshared_str; text:PChar); stdcall;
var
  docked:pstr_value;
begin
  docked:= str_container_dock(text);
  if docked<>nil then begin
    docked.dwReference:=docked.dwReference+1;
  end;

  if (str^.p_<>nil) then begin
    str^.p_.dwReference:=str^.p_.dwReference-1;
    if str^.p_.dwReference=0 then str.p_:=nil
  end;

  str^.p_:=docked;
end;

procedure init_string(str:pshared_str); stdcall;
begin
  str.p_:=nil;
end;  

function get_string_value(str:pshared_str):PAnsiChar; stdcall;
begin
  result:='';
  if str=nil then exit;
  if str.p_=nil then exit;
  result:=PAnsiChar(@str.p_.value);
end;   

function GetStrContainer():pointer;stdcall;
asm
  mov eax, xrgame_addr
  mov eax, [eax+$512814]
  mov eax, [eax]
  mov @result, eax
end;

function str_container_dock(str:PChar):pstr_value; stdcall;
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

function Init():boolean; stdcall;
begin
  result:=true;
end;

end.

