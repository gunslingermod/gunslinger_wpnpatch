unit HudTransparencyFix;

interface
function Init:boolean;

implementation
uses BaseGameData, windows;


function Init:boolean;
var drawhud_patch, r:cardinal;
buf:single;
begin
  result:=false;
  buf:=1;
  drawhud_patch:=$490624;
  WriteProcessMemory(hndl, PChar(drawhud_patch), @buf, 4, r);
  

  result:=true;
end;

end.
