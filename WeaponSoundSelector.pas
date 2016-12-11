unit WeaponSoundSelector;

interface
function Init:boolean;

implementation
uses BaseGameData, WpnUtils;

function MagazinedWeaponReloadSoundSelector(wpn:pointer):PChar; stdcall;
begin
  result:='sndReload';
  if IsWeaponJammed(wpn) then begin
    if GetAmmoInMagCount(wpn)<=0 then
      result:='sndReloadJammedLast'
    else
      result:='sndReloadJammed';
    SetAmmoTypeChangingStatus(wpn, $FF);
  end else if GetAmmoInMagCount(wpn)<=0 then begin
    result:='sndReloadEmpty';
  end else if GetAmmoTypeChangingStatus(wpn)<>$FF then begin
    result:='sndChangeCartridgeType';
  end;
end;

procedure MagazinedWeaponReloadSoundPatch; stdcall;
asm
  push eax
  pushad
  pushfd
    mov eax,[esp+$28]
    mov [esp+$24], eax

    sub esi, $5B1
    push esi
    call MagazinedWeaponReloadSoundSelector
    mov [esp+$28], eax
  popfd
  popad
  ret
end;

function Init:boolean;
var jmp_addr:cardinal;
begin
  result:=false;
  jmp_addr:=xrGame_addr+$2CCE6F;
  if not WriteJump(jmp_addr, cardinal(@MagazinedWeaponReloadSoundPatch), 5, true) then exit;
  result:=true;
end;

end.
