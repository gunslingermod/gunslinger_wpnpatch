unit strings;

interface

function Init():boolean; stdcall;

type str_value = packed record
  dwReference:cardinal;
  length:cardinal;
  dwCRC:cardinal;
  next:pointer;
  value:char; //really array here
end;

type pstr_value = ^str_value;

type shared_str = packed record
  p_:pstr_value;
end;

type pshared_str = ^shared_str;

implementation

function Init():boolean; stdcall;
begin
  result:=true;
end;

end.

