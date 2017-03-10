unit WeaponSoundSelector;

interface
function Init:boolean;

implementation
uses ActorUtils, BaseGameData, HudItemUtils, gunsl_config, xr_Cartridge;

function MagazinedWeaponReloadSoundSelector(wpn:pointer):PChar; stdcall;
var
  detector_now: boolean;
begin
  detector_now:=(GetActor<>nil) and (GetOwner(wpn)=GetActor()) and IsHolderHasActiveDetector(wpn);


  //default
  if detector_now and game_ini_r_bool_def(GetHUDSection(wpn), 'use_reload_detector_snd', false) then
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


    if detector_now and game_ini_line_exist(GetHUDSection(wpn), 'use_empty_detector_snd') and game_ini_r_bool(GetHUDSection(wpn), 'use_empty_detector_snd') then begin
      if (GetClassName(wpn)='WP_BM16') and (CWeapon__GetAmmoCount(wpn, GetAmmoTypeToReload(wpn))<2) then begin
        if (GetAmmoTypeChangingStatus(wpn)=$FF) then
          result:='sndReloadOnlyDetector'
        else
          result:='sndReloadOnlyAmmochangeDetector';
      end else begin
        result:='sndReloadEmptyDetector'
      end;
    end else begin
      if (GetClassName(wpn)='WP_BM16') and (CWeapon__GetAmmoCount(wpn, GetAmmoTypeToReload(wpn))<2) then begin
        if (GetAmmoTypeChangingStatus(wpn)=$FF) then
          result:='sndReloadOnly'
        else
          result:='sndReloadOnlyAmmochange';
      end else begin
        result:='sndReloadEmpty';
      end
    end;


  end else if GetAmmoTypeChangingStatus(wpn)<>$FF then begin

    if detector_now and game_ini_line_exist(GetHUDSection(wpn), 'use_changeammo_detector_snd') and game_ini_r_bool(GetHUDSection(wpn), 'use_changeammo_detector_snd') then begin
      if (GetClassName(wpn)='WP_BM16') and (CWeapon__GetAmmoCount(wpn, GetAmmoTypeToReload(wpn))<2) then begin
        if GetCurrentAmmoCount(wpn)=1 then begin
          result:='sndChangeCartridgeTypeDetectorOneOnly'
        end else begin
          result:='sndChangeCartridgeTypeDetectorOnly'
        end;
      end else begin
        if GetCurrentAmmoCount(wpn)=1 then begin
          result:='sndChangeCartridgeTypeOneDetector';
        end else begin
          result:='sndChangeCartridgeTypeDetector';
        end;
      end;
    end else begin
      if (GetClassName(wpn)='WP_BM16') and (CWeapon__GetAmmoCount(wpn, GetAmmoTypeToReload(wpn))<2) then begin
        if GetCurrentAmmoCount(wpn)=1 then begin
          result:='sndChangeCartridgeTypeOneOnly'
        end else begin
          result:='sndChangeCartridgeTypeOnly'
        end;
      end else begin
        if GetCurrentAmmoCount(wpn)=1 then begin
          result:='sndChangeCartridgeTypeOne';
        end else begin
          result:='sndChangeCartridgeType';
        end;
      end;
    end;
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

procedure CWeaponBM16__PlayReloadSound(wpn:pointer); stdcall;
//переопределяем функцию
begin
  CHudItem_Play_Snd(wpn, MagazinedWeaponReloadSoundSelector(wpn));
end;

procedure CWeaponBM16__PlayReloadSound_Patch(); stdcall;
asm
  pushad
    push ecx
    call CWeaponBM16__PlayReloadSound
  popad
end;

function Init:boolean;
var jmp_addr:cardinal;
begin
  result:=false;
  jmp_addr:=xrGame_addr+$2CCE6F;
  if not WriteJump(jmp_addr, cardinal(@MagazinedWeaponReloadSoundPatch), 5, true) then exit;

  jmp_addr:=xrGame_addr+$2E0060;
  if not WriteJump(jmp_addr, cardinal(@CWeaponBM16__PlayReloadSound_Patch), 9, false) then exit;
  result:=true;
end;

end.
