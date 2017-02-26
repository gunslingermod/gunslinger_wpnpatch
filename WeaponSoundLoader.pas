unit WeaponSoundLoader;

interface
function Init:boolean;
procedure HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION:pointer; section:PChar; config_name:PChar; internal_name:PChar; exclusive:cardinal; snd_type:cardinal);stdcall;


implementation
uses BaseGameData, GameWrappers, wpnutils;

var
  sound_load_magazined_addr:cardinal;
  sound_load_knife_addr:cardinal;

procedure HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION:pointer; section:PChar; config_name:PChar; internal_name:PChar; exclusive:cardinal; snd_type:cardinal);stdcall;
begin
  asm
    pushad
    pushfd
    push snd_type
    push exclusive
    push internal_name
    push config_name
    push section
    mov ecx, HUD_SOUND_COLLECTION

    mov eax, xrgame_addr
    add eax, $2FB430
    call eax // HUD_SOUND_COLLECTION::LoadSound
    popfd
    popad
  end;
end;

procedure LoadSounds_WeaponMagazined(HUD_SOUND_COLLECTION:pointer; section:PChar); stdcall;
begin
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_changecartridgetype', 'sndChangeCartridgeType', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_reload_empty', 'sndReloadEmpty', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_reload_jammed', 'sndReloadJammed', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_reload_jammed_last', 'sndReloadJammedLast', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_jammed_click', 'sndJammedClick', 1, $80100000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_change_grenade', 'sndChangeGrenade', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_load_grenade', 'sndLoadGrenade', 1, $80040000);  

  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_change_grenade_detector', 'sndChangeGrenadeDetector', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_load_grenade_detector', 'sndLoadGrenadeDetector', 1, $80040000);

  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_changecartridgetype_detector', 'sndChangeCartridgeTypeDetector', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_reload_empty_detector', 'sndReloadEmptyDetector', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_reload_jammed_detector', 'sndReloadJammedDetector', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_reload_jammed_last_detector', 'sndReloadJammedLastDetector', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_jammed_click_detector', 'sndJammedClickDetector', 1, $80100000);

  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_changefiremode', 'sndChangeFireMode', 1, $80040000);
  if game_ini_line_exist(section, 'snd_changefiremode_empty') then
    HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_changefiremode_empty', 'sndChangeFireModeEmpty', 1, $80040000)
  else
    HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_changefiremode', 'sndChangeFireModeEmpty', 1, $80040000);

  if game_ini_line_exist(section, 'snd_changefiremode_jammed') then
    HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_changefiremode_jammed', 'sndChangeFireModeJammed', 1, $80040000)
  else
    HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_changefiremode', 'sndChangeFireModeJammed', 1, $80040000);


  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_sprint_start', 'sndSprintStart', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_sprint_end', 'sndSprintEnd', 1, $80040000);

  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_attach_sil', 'sndSilAtt', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_detach_sil', 'sndSilDet', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_attach_scope', 'sndScopeAtt', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_detach_scope', 'sndScopeDet', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_attach_gl', 'sndGLAtt', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_detach_gl', 'sndGLDet', 1, $80040000);

  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_unload_mag', 'sndUnload', 1, $80040000);

  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_jam', 'sndJam', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_breechblock', 'sndBreechblock', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_explose', 'sndExplose', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_prepare_detector', 'sndPrepareDet', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_finish_detector', 'sndFinishDet', 1, $80040000);

  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_aim_start', 'sndAimStart', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_aim_end', 'sndAimEnd', 1, $80040000);

  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_laser_on', 'sndLaserOn', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_laser_off', 'sndLaserOff', 1, $80040000);

  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_open_weapon_empty', 'sndOpenEmpty', 1, $80040000);
end;

procedure LoadSounds_Knife(HUD_SOUND_COLLECTION:pointer; section:PChar); stdcall;
begin
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_draw', 'sndShow', 1, $80200000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_holster', 'sndHide', 1, $80200000);  
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_kick_1', 'sndKick1', 1, $80200000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_kick_2', 'sndKick2', 1, $80200000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_sprint_start', 'sndSprintStart', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_sprint_end', 'sndSprintEnd', 1, $80040000);  
end;

procedure SoundLoader_Knife_Patch; stdcall;
const
  sndShot:PChar='sndShot';
asm
    pushad
    pushfd

    push edi //section
    lea ecx, [esi+$324]
    push ecx //snd_collection
    call LoadSounds_Knife

    popfd
    popad

    push sndShot
    jmp sound_load_knife_addr
end;


procedure SoundLoader_Magazined_Patch; stdcall;
const
  sndReload:PChar='sndReload';
asm
    pushad
    pushfd

    push ebx
    push edi
    call LoadSounds_WeaponMagazined

    popfd
    popad

    push sndReload
    jmp sound_load_magazined_addr
end;

function Init:boolean;
begin
  result:=false;
  sound_load_magazined_addr:=xrGame_addr+$2CFADE;
  if not WriteJump(sound_load_magazined_addr, cardinal(@SoundLoader_Magazined_Patch), 5) then exit;
  sound_load_knife_addr:=xrGame_addr+$2D4DC2;
  if not WriteJump(sound_load_knife_addr, cardinal(@SoundLoader_Knife_Patch), 5) then exit;
  result:=true;
end;

end.
