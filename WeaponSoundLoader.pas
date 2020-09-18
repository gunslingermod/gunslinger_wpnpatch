unit WeaponSoundLoader;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface
uses xr_strings, MatVectors;

type ref_sound = packed record
  _p:{ref_sound_data_ptr}pointer;
end;
type pref_sound = ^ref_sound;


type HUD_SOUND_ITEM_SSnd = packed record
  snd:ref_sound;
  delay:single;
  volume:single; // из-за бага в HUD_SOUND_ITEM::PlaySound толком не работает; вырезаем использование там и используем в своих целях
                 // отрицательное число значит, что звук "разблокирован". Модуль определяет вариацию частоты
end;
type pHUD_SOUND_ITEM_SSnd = ^HUD_SOUND_ITEM_SSnd;

type HUD_SOUND_ITEM = packed record
  m_alias:shared_str;
  m_activeSnd:pHUD_SOUND_ITEM_SSnd;
  m_b_exclusive:byte{bool};
  _unused1:byte;
  _unused2:word;
  sounds_start:pHUD_SOUND_ITEM_SSnd;
  sounds_end:pHUD_SOUND_ITEM_SSnd;
  sounds_mem:pHUD_SOUND_ITEM_SSnd;
end;
type pHUD_SOUND_ITEM = ^HUD_SOUND_ITEM;

type HUD_SOUND_COLLECTION = packed record
  first:pHUD_SOUND_ITEM;
  last:pHUD_SOUND_ITEM;
  mem:pHUD_SOUND_ITEM;
end;
type pHUD_SOUND_COLLECTION = ^HUD_SOUND_COLLECTION;

type CSound_params = packed record
	position:Fvector3;
	base_volume:single;
	volume:single;
	freq:single;
	min_distance:single;
	max_distance:single;
	max_ai_distance:single;
end;
type pCSound_params = ^CSound_params;

function Init:boolean;
procedure HUD_SOUND_COLLECTION__LoadSound(hcs:pHUD_SOUND_COLLECTION; section:PChar; config_name:PChar; internal_name:PChar; exclusive:cardinal; snd_type:cardinal);stdcall;


implementation
uses BaseGameData, gunsl_config, HudItemUtils, sysutils;

var
  sound_load_magazined_addr:cardinal;
  sound_load_knife_addr:cardinal;

procedure HUD_SOUND_COLLECTION__LoadSound(hcs:pHUD_SOUND_COLLECTION; section:PChar; config_name:PChar; internal_name:PChar; exclusive:cardinal; snd_type:cardinal);stdcall;
asm
    pushad
    pushfd
    push snd_type
    push exclusive
    push internal_name
    push config_name
    push section
    mov ecx, hcs

    mov eax, xrgame_addr
    add eax, $2FB430
    call eax // HUD_SOUND_COLLECTION::LoadSound
    popfd
    popad
end;

procedure LoadSounds_WeaponMagazined(hsc:pHUD_SOUND_COLLECTION; section:PChar); stdcall;
begin
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_changecartridgetype', 'sndChangeCartridgeType', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_reload_empty', 'sndReloadEmpty', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_reload_jammed', 'sndReloadJammed', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_reload_jammed_last', 'sndReloadJammedLast', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_jammed_click', 'sndJammedClick', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_change_grenade', 'sndChangeGrenade', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_load_grenade', 'sndLoadGrenade', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_change_grenade_detector', 'sndChangeGrenadeDetector', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_load_grenade_detector', 'sndLoadGrenadeDetector', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_changecartridgetype_detector', 'sndChangeCartridgeTypeDetector', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_reload_empty_detector', 'sndReloadEmptyDetector', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_reload_jammed_detector', 'sndReloadJammedDetector', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_reload_jammed_last_detector', 'sndReloadJammedLastDetector', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_jammed_click_detector', 'sndJammedClickDetector', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_changefiremode', 'sndChangeFireMode', 1, $80040000);
  if game_ini_line_exist(section, 'snd_changefiremode_empty') then
    HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_changefiremode_empty', 'sndChangeFireModeEmpty', 1, $FFFFFFFF)
  else
    HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_changefiremode', 'sndChangeFireModeEmpty', 1, $FFFFFFFF);

  if game_ini_line_exist(section, 'snd_changefiremode_jammed') then
    HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_changefiremode_jammed', 'sndChangeFireModeJammed', 1, $FFFFFFFF)
  else
    HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_changefiremode', 'sndChangeFireModeJammed', 1, $FFFFFFFF);


  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_sprint_start', 'sndSprintStart', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_sprint_end', 'sndSprintEnd', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_attach_sil', 'sndSilAtt', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_detach_sil', 'sndSilDet', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_attach_scope', 'sndScopeAtt', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_detach_scope', 'sndScopeDet', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_attach_gl', 'sndGLAtt', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_detach_gl', 'sndGLDet', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_unload_mag', 'sndUnload', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_jam', 'sndJam', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_breechblock', 'sndBreechblock', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_explose', 'sndExplose', 0, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_prepare_detector', 'sndPrepareDet', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_finish_detector', 'sndFinishDet', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_aim_start', 'sndAimStart', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_aim_end', 'sndAimEnd', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_laser_on', 'sndLaserOn', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_laser_off', 'sndLaserOff', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_torch_on', 'sndTorchOn', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_torch_off', 'sndTorchOff', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_open_weapon_empty', 'sndOpenEmpty', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_reload_only', 'sndReloadOnly', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_reload_only_detector', 'sndReloadOnlyDetector', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_reload_only_ammochange', 'sndReloadOnlyAmmochange', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_reload_only_ammochange_detector', 'sndReloadOnlyAmmochangeDetector', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_changecartridgetype_one', 'sndChangeCartridgeTypeOne', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_changecartridgetype_one_detector', 'sndChangeCartridgeTypeOneDetector', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_changecartridgetype_only', 'sndChangeCartridgeTypeOnly', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_changecartridgetype_one_only_detector', 'sndChangeCartridgeTypeDetectorOneOnly', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_changecartridgetype_one_only', 'sndChangeCartridgeTypeOneOnly', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_changecartridgetype_only_detector', 'sndChangeCartridgeTypeDetectorOnly', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_light_misfire', 'sndLightMisfire', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_suicide', 'sndSuicide', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_stop_suicide', 'sndStopSuicide', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_scream_1', 'sndScream1', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_scream_2', 'sndScream2', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_scream_3', 'sndScream3', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_scream_4', 'sndScream4', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_headlamp_on', 'sndHeadlampOn', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_headlamp_off', 'sndHeadlampOff', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_nv_on', 'sndNVOn', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_nv_off', 'sndNVOff', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_kick', 'sndKick', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_add_cartridge_preloaded', 'sndAddCartridgePreloaded', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_close_weapon_preloaded', 'sndClosePreloaded', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_add_cartridge_empty', 'sndAddCartridgeEmpty', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_close_weapon_empty', 'sndCloseEmpty', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_scope_brightness_plus', 'sndScopeBrightnessPlus', 0, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_scope_brightness_minus', 'sndScopeBrightnessMinus', 0, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_scope_zoom_plus', 'sndScopeZoomPlus', 0, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_scope_zoom_minus', 'sndScopeZoomMinus', 0, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_scope_zoom_gyro', 'sndScopeZoomGyro', 0, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_blowout', 'sndBlowout', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_addon_attach', 'sndAddonAttach', 0, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_addon_attach_fail', 'sndAddonAttachFail', 0, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_addon_detach', 'sndAddonDetach', 0, $FFFFFFFF);  
end;

procedure LoadSounds_Knife(hsc:pHUD_SOUND_COLLECTION; section:PChar); stdcall;
begin
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_draw', 'sndShow', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_holster', 'sndHide', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_kick_1', 'sndKick1', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_kick_2', 'sndKick2', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_sprint_start', 'sndSprintStart', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_sprint_end', 'sndSprintEnd', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_start_suicide', 'sndPrepareSuicide', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_selfkill', 'sndSelfKill', 1, $80040000);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_stop_suicide', 'sndStopSuicide', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_scream_1', 'sndScream1', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_scream_2', 'sndScream2', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_scream_3', 'sndScream3', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_scream_4', 'sndScream4', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_headlamp_on', 'sndHeadlampOn', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_headlamp_off', 'sndHeadlampOff', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_nv_on', 'sndNVOn', 1, $FFFFFFFF);
  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_nv_off', 'sndNVOff', 1, $FFFFFFFF);

  HUD_SOUND_COLLECTION__LoadSound(hsc, section, 'snd_kick', 'sndKick', 1, $FFFFFFFF);

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


procedure HUD_SOUND_ITEM__StopSound(hud_snd:pHUD_SOUND_ITEM); stdcall;
asm
  pushad
    mov eax, xrGame_addr
    add eax, $2FA380
    push hud_snd
    call eax
    add esp, 4
  popad
end;

procedure HUD_SOUND_ITEM__DestroySound(hud_snd:pHUD_SOUND_ITEM); stdcall;
asm
  pushad
    mov eax, xrGame_addr
    add eax, $2FB140
    push hud_snd
    call eax
    add esp, 4
  popad
end;

procedure HUD_SOUND_COLLECTION__SetPosition(collection:pHUD_SOUND_COLLECTION; alias:PChar; pos:pFVector3); stdcall;
asm
  pushad
    mov eax, xrGame_addr
    add eax, $2FA440
    mov ecx, collection
    push pos
    push alias
    call eax
  popad
end;

procedure HUD_SOUND_COLLECTION_UnLoadSound(collection:pHUD_SOUND_COLLECTION; snd:pHUD_SOUND_ITEM); stdcall;
begin
  HUD_SOUND_ITEM__StopSound(snd);
  HUD_SOUND_ITEM__DestroySound(snd);
  collection.last:=(pHUD_SOUND_ITEM(cardinal(collection.last)-sizeof(HUD_SOUND_ITEM)));
  if snd<>collection.last then snd^:=collection.last^;
end;

procedure HUD_SOUND_COLLECTION__LoadSound_Patch; stdcall;
asm
  pushad
    push eax
    push esi
    call HUD_SOUND_COLLECTION_UnLoadSound
  popad
end;


procedure UpdateSoundsPos(collection:pHUD_SOUND_COLLECTION; pos:pFVector3);stdcall;
var
  snd:pHUD_SOUND_ITEM;
  alias:PAnsiChar;
begin
  snd:=collection.first;
  while(snd<>collection.last) do begin
    if snd.m_activeSnd<>nil then begin
      alias:=get_string_value(@snd.m_alias);
      if length(alias) > 0 then begin
        HUD_SOUND_COLLECTION__SetPosition(collection, alias, pos);
      end;
    end;
    snd:=pHUD_SOUND_ITEM(cardinal(snd)+sizeof(HUD_SOUND_ITEM))
  end;
end;

procedure CWeaponMagazined__UpdateSounds_Patch(); stdcall;
asm
  pushad
  push edx
  push esi
  call UpdateSoundsPos
  popad
end;

function ref_sound__get_params(this:pref_sound):pCSound_params; stdcall;
asm
  // Скопировано из движка
  mov result, 0
  pushad
  mov eax, this
  mov eax, [eax]
  mov ecx, eax
  neg ecx
  sbb ecx, ecx
  test ecx, $6D09720
  je @finish
  mov ecx,[eax+$C]
  test ecx, ecx
  je @finish
  mov edx,[ecx]
  mov eax,[edx+$24]
  call eax
  mov result, eax
  @finish:
  popad
end;

procedure ref_sound__play_at_pos(this:pref_sound; O:pointer; pos:pFVector3; flags:cardinal; d:single); stdcall;
asm
  pushad
    push d
    push flags
    push pos
    push o
    push this

    mov ecx, xrgame_addr;
    mov ecx, [ecx+$5132a4]
    mov ecx, [ecx]
    mov edi, [ecx]
    mov eax, [edi+$38]
    call eax
  popad
end;

procedure ref_sound__play_no_feedback(this:pref_sound; O:pointer; flags:cardinal; d:single; pos:pFVector3; vol:psingle; freq:psingle; range:pFVector2); stdcall;
asm
  pushad
    push range
    push freq
    push vol
    push pos
    push d
    push flags
    push O
    push this

    mov ecx, xrgame_addr;
    mov ecx, [ecx+$5132a4]
    mov ecx, [ecx]
    mov edi, [ecx]
    mov eax, [edi+$3C]
    call eax
  popad
end;

//Правка на отключение прерывания звука при его рестарте (для стрельбы главным образом)
//также тут выполняем коррекцию частоты для стрельбы
procedure DecideHowToPlaySnd(snd:pHUD_SOUND_ITEM; O:pointer; pos:pFVector3; flags:cardinal); stdcall;
const
  sm_Looped:cardinal = $1;
  sm_2D:cardinal = $2;
  EPS:single=0.001;
var
  params:pCSound_params;
  freq, volume:single;
  need_freq_variation, sound_unlocked:boolean;
  freq_deviation, new_freq, delta:single;
  hud_mode:boolean;
begin
  freq_deviation:=abs(snd.m_activeSnd.volume);
  need_freq_variation := (freq_deviation - 1.0 > EPS);
  sound_unlocked:=(snd.m_activeSnd.volume < 0) or IsSndUnlock(); // теперь вместо громкости минус в знаке означает анлок звука, а модуль - изменение частоты

  if need_freq_variation then begin
    if freq_deviation > 1.0 then begin
      delta:=freq_deviation - 1.0;
      if delta > 0.9 then delta:=0.9;
      freq:=1.0 + (random * 2*delta) - delta;
    end else begin
      delta:=1.0 - freq_deviation;
      if delta > 0.9 then delta:=0.9;
      freq:=1.0 - random * delta;
    end;
    // Log('Freq = '+floattostr(freq)+', unlock = '+booltostr(sound_unlocked, true));
  end;

  volume:=1;
  hud_mode:=((flags and sm_2D)<>0);
  if hud_mode then begin
    volume:=GetHudSoundVolume();
  end;

  if (not sound_unlocked) or ((snd.m_b_exclusive<>0) or ((flags and sm_Looped)<>0))  then begin
    ref_sound__play_at_pos(@snd.m_activeSnd.snd, O, pos, flags, snd.m_activeSnd.delay);
    params:=ref_sound__get_params(@snd.m_activeSnd.snd);
    params.volume:=volume;
    if need_freq_variation then begin
      params.freq:=freq;
    end;
  end else begin
    if need_freq_variation then begin
      ref_sound__play_no_feedback(@snd.m_activeSnd.snd, O, flags, snd.m_activeSnd.delay, pos, @volume, @freq, nil);
    end else begin
      ref_sound__play_no_feedback(@snd.m_activeSnd.snd, O, flags, snd.m_activeSnd.delay, pos, @volume, nil, nil);
    end;
  end;
end;

procedure HUD_SOUND_ITEM__PlaySound_Patch();
asm
  push ebp
  mov ebp, esp
  
  pushad
  push [ebp+$14]
  push [ebp+$10]
  push [ebp+$c]
  push esi
  call DecideHowToPlaySnd
  popad

  pop ebp
  ret $14
end;

function Init:boolean;
var
  addr, tmp:cardinal;
begin
  result:=false;
  sound_load_magazined_addr:=xrGame_addr+$2CFADE;
  if not WriteJump(sound_load_magazined_addr, cardinal(@SoundLoader_Magazined_Patch), 5) then exit;
  sound_load_knife_addr:=xrGame_addr+$2D4DC2;
  if not WriteJump(sound_load_knife_addr, cardinal(@SoundLoader_Knife_Patch), 5) then exit;

  if IsSoundPatchNeeded() then begin
    //перезагрузка звука в HUD_SOUND_COLLECTION вместо вылета.
    addr:=xrGame_addr+$2FB46C;
    nop_code(addr, 37);
    if not WriteJump(addr, cardinal(@HUD_SOUND_COLLECTION__LoadSound_Patch), 5, true) then exit;

    //обновляем позиции всех звуков
    addr:=xrGame_addr+$2CCBD3;
    if not WriteJump(addr, cardinal(@CWeaponMagazined__UpdateSounds_Patch), 13, true) then exit;

    //фикс обрыва звука
    addr:=xrGame_addr+$2FA652;
    if not WriteJump(addr, cardinal(@HUD_SOUND_ITEM__PlaySound_Patch), 5, true) then exit;

    //в HUD_SOUND_ITEM::PlaySound  в вызове snd.set_volume отказываемся от использования hud_snd.m_activeSnd->volume в качестве множителя - все равно не работает
    nop_code(xrGame_addr+$2fa663, 5);

    //в HUD_SOUND_ITEM::PlaySound отключаем вызов snd.set_volume - более не нужен, так как все настройки выполняются нами в DecideHowToPlaySnd
    nop_code(xrGame_addr+$2fa69d, 1, chr($eb));

    //переводим в эксклюзивный режим все звуки типа доставания, убирания и т.д.
    nop_code(xrGame_addr+$2CFA6B, 1, chr(1));
    nop_code(xrGame_addr+$2CFA8C, 1, chr(1));
    nop_code(xrGame_addr+$2CFAC2, 1, chr(1));
    nop_code(xrGame_addr+$2DE2C6, 1, chr(1));
    nop_code(xrGame_addr+$2DE2E7, 1, chr(1));
    nop_code(xrGame_addr+$2DE302, 1, chr(1));
    nop_code(xrGame_addr+$2C5146, 1, chr(1));

    //увеличиваем максимальное число snd_targets
    tmp:=20000;
    addr:=xrEngine_addr+$939a0;
    WriteBufAtAdr(addr, @tmp, 4);
    tmp:=32;
    WriteBufAtAdr(addr-4, @tmp, 4);
  end;

  result:=true;
end;

end.
