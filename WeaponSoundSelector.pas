unit WeaponSoundSelector;

interface
function Init:boolean;

implementation
uses ActorUtils, BaseGameData, WpnUtils, GameWrappers;

function MagazinedWeaponReloadSoundSelector(wpn:pointer):PChar; stdcall;
var
  detector_now: boolean;
begin
  detector_now:=(GetActor<>nil) and (GetOwner(wpn)=GetActor()) and IsHolderHasActiveDetector(wpn);


  //default
  if detector_now and game_ini_line_exist(GetHUDSection(wpn), 'use_reload_detector_snd') and game_ini_r_bool(GetHUDSection(wpn), 'use_reload_detector_snd') then
    result:='sndReloadDetector'
  else
    result:='sndReload';

  //special cases after selecting default
  if IsWeaponJammed(wpn) then begin

  
    if GetAmmoInMagCount(wpn)<=0 then begin
      if detector_now and game_ini_line_exist(GetHUDSection(wpn), 'use_jammed_last_detector_snd') and game_ini_r_bool(GetHUDSection(wpn), 'use_jammed_last_detector_snd') then
        result:='sndReloadJammedLastDetector'
      else
        result:='sndReloadJammedLast';
    end else begin
      if detector_now and game_ini_line_exist(GetHUDSection(wpn), 'use_jammed_detector_snd') and game_ini_r_bool(GetHUDSection(wpn), 'use_jammed_detector_snd') then
        result:='sndReloadJammedDetector'
      else
        result:='sndReloadJammed';
    end;
    SetAmmoTypeChangingStatus(wpn, $FF);


  end else if GetAmmoInMagCount(wpn)<=0 then begin


    if detector_now and game_ini_line_exist(GetHUDSection(wpn), 'use_empty_detector_snd') and game_ini_r_bool(GetHUDSection(wpn), 'use_empty_detector_snd') then
      result:='sndReloadEmptyDetector'
    else
      result:='sndReloadEmpty';


  end else if GetAmmoTypeChangingStatus(wpn)<>$FF then begin

    if detector_now and game_ini_line_exist(GetHUDSection(wpn), 'use_changeammo_detector_snd') and game_ini_r_bool(GetHUDSection(wpn), 'use_changeammo_detector_snd') then
      result:='sndChangeCartridgeTypeDetector'
    else
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
