unit WeaponSoundLoader;

interface
function Init:boolean;

implementation
uses BaseGameData;

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
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_jamned', 'sndJamned', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_jamned_last', 'sndJamnedLast', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_changefiremode', 'sndChangeFireMode', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_attach_sil', 'sndSilAtt', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(HUD_SOUND_COLLECTION, section, 'snd_fakeshoot_first', 'sndFakeFirst', 1, $80040000);  
end;

procedure SoundLoaderPatch; stdcall;
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
