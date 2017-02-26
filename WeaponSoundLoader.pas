unit WeaponSoundLoader;

interface
function Init:boolean;

implementation
uses BaseGameData, GameWrappers;

var
  sound_load_addr:cardinal;
  HUD_SOUND_COLLECTION__LoadSound_addr:cardinal;


procedure HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION:pointer; section:PChar; config_name:PChar; internal_name:PChar; param1:integer; snd_type:cardinal);stdcall;
begin
  asm
    pushad
    pushfd
    push snd_type
    push param1
    push internal_name
    push config_name
    push section
    mov ecx, HUD_SOUND_COLLECTION
    call HUD_SOUND_COLLECTION__LoadSound_addr
    popfd
    popad
  end;
end;

procedure LoadSounds(HUD_SOUND_COLLECTION:pointer; section:PChar); stdcall;
begin
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_changecartridgetype', 'sndChangeCartridgeType', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_reload_empty', 'sndReloadEmpty', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_reload_jammed', 'sndReloadJammed', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_reload_jammed_last', 'sndReloadJammedLast', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_jammed_click', 'sndJammedClick', 1, $80100000);

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
end;

procedure SoundLoaderPatch; stdcall;
const
  sndReload:PChar='sndReload';
begin
  asm
    pushad
    pushfd

    push ebx
    push edi
    call LoadSounds

    popfd
    popad

    push sndReload
    jmp sound_load_addr
  end;
end;

function Init:boolean;
begin
  result:=false;
  HUD_SOUND_COLLECTION__LoadSound_addr:=xrGame_addr+$2FB430;
  sound_load_addr:=xrGame_addr+$2CFADE;
  if not WriteJump(sound_load_addr, cardinal(@SoundLoaderPatch), 5) then exit;
  result:=true;
end;

end.
