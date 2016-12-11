unit collimator;


interface
function Init:boolean;

implementation
uses BaseGameData, GameWrappers;

var
  drawhud_patch:cardinal;


//Флаг коллиматора выставляется в WeaponVisualSelector.WeaponVisualChanger!
procedure CompareCollimator();
begin
  asm
    cmp byte ptr [esi+$6be], 0
    je @nocollim
    pop edi
    pop esi
    mov eax, 1
    ret
    @nocollim:
    pop edi
    pop esi
    xor eax, eax
    ret
  end;
end;

function Init:boolean;
begin
  result:=false;
  drawhud_patch:=xrGame_addr+$2BCB01;

  if not WriteJump(drawhud_patch, cardinal(@CompareCollimator), 0) then exit;

  result:=true;
end;

end.
