unit CommonUpdate;

interface
function Init:boolean;

implementation
uses BaseGameData, WpnUtils, WeaponUpdate, sysutils;

function GetCObjectClassName(itm:pointer):string; stdcall;
var i:cardinal;
    c:char;
begin
  result:='';
  for i:=7 downto 0 do begin
    asm
      push eax
      mov eax, itm
      add eax, $8
      add eax, i
      mov al, [eax]
      mov c, al
      pop eax
    end;
    result:=result+c;
  end;
  result:=trim(result);
end;

procedure UpdateDispatcher(itm:pointer); stdcall;
var
  cls:string;
begin
  cls:=GetCObjectClassName(itm);

  if WpnCanShoot(PChar(cls)) then begin
    asm
      sub itm, $e8
    end;
    WeaponUpdate.WpnUpdate(itm)
  end;
end;

procedure spatial_update_patch;
asm
  mov eax, [esi+$f8];
  pushad
    push ecx
    call UpdateDispatcher
  popad
end;

function Init:boolean;
var
  patch_addr:cardinal;
begin
  result:=false;
  patch_addr:=$41a0ad;
  if not WriteJump(patch_addr, cardinal(@spatial_update_patch), 6, true) then exit;
  result:=true;
end;

end.
