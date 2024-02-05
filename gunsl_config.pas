unit gunsl_config;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface
uses MatVectors;

type weapon_inertion_params = record
  pitch_offset_r:single;
  pitch_offset_n:single;
  pitch_offset_d:single;
  origin_offset:single;
  speed:single;
end;

type landing_params = record
  offset_landing:single;
  offset_landing2:single;
  time_landing:cardinal;
  time_landing2:cardinal;
  cam_speed_factor:single;
  cam_speed_factor2:single;
  pow_factor:single;
  pow_factor2:single;

  time_finish_landing:cardinal;
  pow_finish_landing_factor:single;
  cam_speed_finish_landing_factor:single;
end;

type jitter_params = record
  pos_amplitude:single;
  rot_amplitude:single;
end;

type lookout_params = record
  speed:single;
  ampl_k:single;
  dx_pow:single;
end;

type phantoms_params = record
  min_cnt:cardinal;
  max_cnt:cardinal;
  min_radius:single;
  max_radius:single;  
end;

type actor_tiredness_params = record
  min_tiredness:single;
  base_speed_idle:single;
  base_speed_idle_aim:single;
  base_speed_idle_moving:single;
  base_speed_idle_slow:single;
  base_speed_idle_crouch:single;
  base_speed_idle_crouch_slow:single;
  base_speed_idle_aim_moving:single;
  base_speed_idle_slow_moving:single;
  base_speed_idle_crouch_moving:single;
  base_speed_idle_crouch_slow_moving:single;

  max_speed_idle:single;
  max_speed_idle_aim:single;
  max_speed_idle_moving:single;
  max_speed_idle_slow:single;
  max_speed_idle_crouch:single;
  max_speed_idle_crouch_slow:single;
  max_speed_idle_aim_moving:single;
  max_speed_idle_slow_moving:single;
  max_speed_idle_crouch_moving:single;
  max_speed_idle_crouch_slow_moving:single;

  increment_per_second:single;
  decrement_per_second:single;
end;

type controller_feel_params = record
  min_dist:single;
  max_dist:single;
end;

type controller_psiunblock_params = record
  min_dist:single;
  min_dist_prob:single;
  max_dist:single;
  max_dist_prob:single;
end;

type controller_mouse_control_params = record
  min_sense_scale:single;
  max_sense_scale:single;
  min_offset:integer;
  max_offset:integer;
  keyboard_move_k:single;
end;

type burer_superstamina_hit_params = record
  distance:single;
  stamina_decrease:single;
  minimal_stamina:single;
  minimal_stamina_health:single;
  power:single;
  impulse:single;
  hit_type:cardinal;
  force_hide_items_prob:single;
  condition_dec_min:single;
  condition_dec_max:single;
end;

type burer_fly_params = record
  enabled:boolean;
  max_dist:single;
  critical_dist:single;
  preferred_dist:single;
  preferred_height:single;
  impulse:single;
  cooldown_period:cardinal;
  visibility_period:cardinal;
  max_time:cardinal;
  vertical_accel:single;
end;

type burer_teleweapon_params = record
  impulse:single;
  allowed_angle:single;
  min_shoot_time:integer;
  max_shoot_time:integer;
  shot_probability:single;
end;

type weapon_physics_damage_params = packed record
  treshold:single;
  speed:single;
end;

type boar_hit_params = packed record
  min_condition_decrease:single;
  max_condition_decrease:single;
end;

type bobbing_effector_param = packed record
  amplitude:single;
  speed:single;
end;

type bobbing_effector_params = packed record
  sprint:bobbing_effector_param;
  zoom_limp:bobbing_effector_param;
  limp:bobbing_effector_param;
  zoom_slow_crouch:bobbing_effector_param;
  slow_crouch:bobbing_effector_param;
  zoom_crouch:bobbing_effector_param;
  crouch:bobbing_effector_param;
  zoom_walk:bobbing_effector_param;
  walk:bobbing_effector_param;
  zoom_run:bobbing_effector_param;
  run:bobbing_effector_param;

  amplitude_delta:single;
end;

function Init:boolean;

const
  gd_novice:cardinal=0;
  gd_stalker:cardinal=1;
  gd_veteran:cardinal=2;
  gd_master:cardinal=3;
  GUNSL_BASE_SECTION:PChar='gunslinger_base';
  GUNSL_BONE_OVERRIDES_SECTION='gunslinger_visual_bone_mass_overrides';


//------------------------------Общие функции работы с игровыми конфигами---------------------------------
  function game_ini_read_string_by_object_string(section:pointer; key:PChar):PChar;stdcall;
  function game_ini_read_string(section:PChar; key:PChar):PChar;stdcall;
  function game_ini_read_string_def(section:PChar; key:PChar; def:PChar):PChar;stdcall;  
  function game_ini_read_vector3_def(section:PChar; key:PChar; def:pfvector3):FVector3;stdcall;
  function game_ini_line_exist(section:PChar; key:PChar):boolean;stdcall;
  function game_ini_r_single_def(section:PChar; key:PChar; def:single; is_default:pboolean=nil):single;stdcall;
  function game_ini_r_single(section:PChar; key:PChar):single;stdcall;
  function game_ini_r_bool(section:PChar; key:PChar):boolean;stdcall;
  function game_ini_r_bool_def(section:PChar; key:PChar; def:boolean; is_default:pboolean=nil):boolean;stdcall;
  function game_ini_r_int_def(section:PChar; key:PChar; def:integer; is_default:pboolean=nil):integer; stdcall;
  function game_ini_r_line(section:PChar; idx:integer; n:PPAnsiChar; v:PPAnsiChar):boolean;stdcall;
  function translate(text:PChar):PChar;stdcall;

  type cached_cfg_param_float = packed record
    last_section:string;
    value:single;
    is_default:boolean;
  end;
  function GetCachedCfgParamFloatDef(var cached:cached_cfg_param_float; section:string; key:string; def:single):single;

  type cached_cfg_param_bool = packed record
    last_section:string;
    value:boolean;
    is_default:boolean;
  end;
  function GetCachedCfgParamBoolDef(var cached:cached_cfg_param_bool; section:string; key:string; def:boolean):boolean;

  //---------------------------специфические функции конфигурации ганса--------------------------------------
function IsSprintOnHoldEnabled():boolean; stdcall;
function IsDebug():boolean; stdcall;
function GetBaseFOV():single; stdcall;
function GetBaseHudFOV():single; stdcall;
function GetCurrentDifficulty():cardinal; stdcall;
function GetDefaultActionDOF():FVector3; stdcall;
function GetDefaultZoomDOF():FVector3; stdcall;
function IsDynamicDOF():boolean; stdcall;
function GetDefaultDOFSpeed():single; stdcall;
function GetDefaultDOFSpeed_In():single; stdcall;
function GetDefaultDOFSpeed_Out():single; stdcall;
function GetDefaultDOFTimeOffset():single;
function IsConstZoomDOF():boolean; stdcall;
function IsDofEnabled():boolean; stdcall;
function IsLaserdotCorrection():boolean; stdcall;
function IsNPCLasers():boolean; stdcall;
function IsRealBallistics():boolean; stdcall;
function IsWeaponmoveEnabled():boolean; stdcall;

function IsCollimAimEnabled():boolean; stdcall;

function GetStdInertion(aim:boolean):weapon_inertion_params;
function GetCamSpeedDef():single;
function GetCamSpeedPow():single;
function GetCamLandingParams():landing_params;

function GetControllerTime():cardinal; stdcall;
function GetControllerPrepareTime():cardinal; stdcall;
function GetControllerBlockedTime():cardinal; stdcall;
function GetShockTime():cardinal; stdcall;
function GetMaxJitterHealth():single; stdcall;
function GetControllerFeelParams():controller_feel_params; stdcall;
function GetControllerQueueStopProb():single; stdcall;
function GetControllerPsiUnblockProb():controller_psiunblock_params; stdcall;
function GetControllerMouseControlParams():controller_mouse_control_params; stdcall;

function GetControlledActorSpeedKoef():single; stdcall;

function GetBaseJitterParams():jitter_params; stdcall;
function GetCurJitterParams(hud_sect:PChar):jitter_params; stdcall;
function GetControllerPhantomsParams():phantoms_params; stdcall;

function GetMaxCorpseWeight():single; stdcall;
function IsCorpseCollisionEnabled():boolean; stdcall;
function GetActorMaxBreathHealth():single; stdcall;
function GetActorBreathHealthSndDelta():single; stdcall;

function GetHeadlampEnableAnimator():PChar;
function GetHeadlampDisableAnimator():PChar;
function GetNVEnableAnimator():PChar;
function GetNVDisableAnimator():PChar;
function GetBurnAnimator():PChar;
function GetKickAnimator():PChar;
function GetPDAShowAnimator():PChar;
function GetPDAScreen_kx():single; stdcall;
function GetPDAUpdatePeriod():cardinal; stdcall;
function IsFastPdaZoom():boolean; stdcall;
function IsSavePdaZoomState():boolean; stdcall;
function IsAlterZoomClickSwitchScheme():boolean; stdcall;

function GetInventoryShowAnimator():PChar;

function GetLensRenderFactor():cardinal;  stdcall;
function IsLensEnabled():boolean;
function IsForcedLens:boolean;  stdcall;
function IsSndUnlock:boolean; stdcall;
function IsDynamicUpdrate():boolean; stdcall;

function GetModVer():PChar; stdcall;
function GetSaveVer():PChar; stdcall;
function GetAddonName():PChar; stdcall;
function GetQuickUseScriptFunctorName():PChar; stdcall;
function GetNvMaskUpdateFunctorName():PChar; stdcall;

function IsAnimatedAddons():boolean; stdcall;
function IsMandatoryAnimatedUnloadMag():boolean; stdcall;

function IsVSyncEnabled():boolean; stdcall;

function IsSoundPatchNeeded():boolean; stdcall;

function GetBaseLookoutParams():lookout_params; stdcall;

function GetWeaponTorchTreasureDist():single; stdcall;
function GetHeadlampTreasureDist():single; stdcall;
function GetLefthandedTorchTreasureDist():single; stdcall;
function GetLightPalevoDist():single; stdcall;
function GetLightSeeDist():single; stdcall;

function GetBurerSuperstaminaHitParams():burer_superstamina_hit_params;
function GetBurerForceantiaimDist():single; stdcall;
function GetBurerForceshieldDist():single; stdcall;
function GetBurerShieldedRiskyFactor():single; stdcall;
function GetBurerMinGrenTimer():cardinal; stdcall;
function GetBurerCriticalGrenTimer():cardinal; stdcall;
function GetBurerTeleweaponShotParams():burer_teleweapon_params; stdcall;
function GetBurerForceTeleFireMinDelta():cardinal; stdcall;
function GetWeaponPhysicsDamageParams():weapon_physics_damage_params;
function GetBoneNameForBurerTeleFire():PAnsiChar; stdcall;
function GetBurerGraviImpulseForActor():single; stdcall;
function GetBurerFlyParams():burer_fly_params;
function GetSkipFireAllProbability():single; stdcall;
function GetBurerAimShieldDelay():cardinal; stdcall;
function GetBurerSelfKickWindowTime():integer; stdcall;
function IsBurerKnifeSelfKick():boolean; stdcall;

function GetOverriddenBoneMassForVisual(visual:PAnsiChar; def:single):single; stdcall;

function GetHudSoundVolume():single;

function GetUpgradeMenuPointOffsetX(need_16x9:boolean):integer;

function GetBoarHitParams():boar_hit_params;

function GetActorFallHitKoef():single;
function GetActorBurnRestoreSpeed():single;

function GetBobbingEffectorParams():bobbing_effector_params;

function IsShadersCacheNeeded():boolean;

var
  g_pickup_distance:single;

implementation
uses BaseGameData, sysutils, ConsoleUtils, ActorUtils, DetectorUtils, math, uiutils, xr_strings, fs;

var
  std_inertion:weapon_inertion_params;
  aim_inertion:weapon_inertion_params;
  fov:single;
  hud_fov:single;

  def_zoom_dof:FVector3;
  def_act_dof:FVector3;
  dof_def_speed:single;
  dof_def_speed_in:single;
  dof_def_speed_out:single;
  dof_def_timeoffset:single;

  _weaponmove_enabled:boolean;
  _collimaim_enabled:boolean;
  _controller_time:cardinal;
  _controller_prepare_time:cardinal;
  _controller_blocked_time:cardinal;
  _controller_queue_stop_prob:single;
  _controller_psiunblock_params:controller_psiunblock_params;
  _controller_phantoms:phantoms_params;
  _controller_feel:controller_feel_params;
  _controller_mouse_control_params:controller_mouse_control_params;

  _actor_shocked_time:cardinal;

  _max_corpse_weight:single;
  _enable_corpse_collision:boolean;
  _controlled_actor_speed_koef:single;

  _max_jitter_health:single;
  _actor_max_breath_health:single;
  _actor_breath_health_snddelta:single;

  _headlamp_enable_animator_section:PChar;
  _nv_enable_animator_section:PChar;
  _headlamp_disable_animator_section:PChar;
  _nv_disable_animator_section:PChar;
  _burn_animator_section:PChar;
  _kick_animator:PChar;
  _pda_show_animator:PChar;
  _inventory_show_animator:PChar;

  _quickuse_functor:PChar;
  _nv_mask_update_functor:PChar;
  _is_animated_addons:boolean;
  _is_mandatory_animated_unload_mag:boolean;

  _std_tiredness_params:actor_tiredness_params;

  _mod_ver:PChar;
  _save_ver:PChar;
  _addon_name:PChar;

  psDeviceFlags:pointer;
  g_upgrades_log:pointer;

  _pda_screen_kx:single;
  _pda_update_period:cardinal;

  _lookout_params:lookout_params;

  _weapon_torch_treasure_dist:single;
  _headlamp_treasure_dist:single;
  _lefthanded_torch_treasure_dist:single;
  _light_palevo_dist:single;
  _light_see_dist:single;

  _burer_forceantiaim_dist:single;
  _burer_forceshield_dist:single;
  _burer_shielded_risky_factor:single;
  _burer_min_gren_timer:cardinal;
  _burer_critical_gren_timer:cardinal;
  _burer_forcetelefire_min_delta:cardinal;
  _burer_gravi_impulse_for_actor:single;
  _burer_fly_params:burer_fly_params;
  _burer_skipfireall_prob:single;
  _burer_aim_shield_delay_const:cardinal;
  _burer_aim_shield_delay_random:cardinal;
  _burer_selfkick_window_time:integer;

  _burer_superstaminahit_params:burer_superstamina_hit_params;
  _burer_teleweapon_params:burer_teleweapon_params;
  _weapon_physics_damage_params:weapon_physics_damage_params;

  _upgrade_menu_points_offset_x:integer;
  _upgrade_menu_points_offset_x_16x9:integer;

  _boar_hit_params:boar_hit_params;

  _actor_fall_hit_koef:single;

  _actor_burn_restore_speed:single;

  _bobbing_effector_params:bobbing_effector_params;

//данные консольных команд
//булевские флаги
  _console_bool_flags:cardinal;

  _max_actor_cam_speed:single;
  _actor_cam_pow:single;
  _cam_landing:landing_params;
  _jitter:jitter_params;
  _lens_render_factor:cardinal;
  _lens_enabled:boolean;
  _hud_sound_volume:single;

//Сами консольные команды
  CCC_dyndof:CCC_Mask;
  CCC_constzoomdof:CCC_Mask;
  CCC_laserdotdistcorrection:CCC_Mask;
  CCC_npclasers:CCC_Mask;
  CCC_realballistics:CCC_Mask;

  CCC_lens_render_factor:CCC_Integer;
  CCC_lens_enabled:CCC_Mask;
  CCC_force_lense:CCC_Mask;
  CCC_unlock_snd:CCC_Mask;
  CCC_dynamic_updrate:CCC_Mask;

//вырезанные движковые консольные команды
  CCC_mt_sound:CCC_Mask;
  CCC_mt_physics:CCC_Mask;
  CCC_mt_network:CCC_Mask;

  CCC_rs_wireframe:CCC_Mask;
  CCC_rs_clear_bb:CCC_Mask;
  CCC_rs_occlusion:CCC_Mask;

  CCC_rs_detail:CCC_Mask;

  CCC_rs_render_statics:CCC_Mask;
  CCC_rs_render_dynamics:CCC_Mask;

  CCC_rs_occ_draw:CCC_Mask;
  CCC_rs_occ_stats:CCC_Mask;

  CCC_rs_disable_objects_as_crows:CCC_Mask;
  CCC_fov:CCC_Float;
  CCC_snd_hud_volume:CCC_Float;

  CCC_upgrades_log:CCC_Integer;

  CCC_pdaautozoom:CCC_Mask;
  CCC_savezoomstate:CCC_Mask;

  CCC_alterzoomclickswitch:CCC_Mask;

  _shader_cache_needed:boolean;

//маски для флагов
const
  _mask_dyndof:cardinal=$1;
  _mask_constzoomdof:cardinal=$2;
  _mask_laserdotcorrection:cardinal=$4;
  _mask_npclasers:cardinal=$8;
  _mask_realballistics:cardinal=$10;
  _mask_forcelense:cardinal=$20;
  _mask_unlocksnd:cardinal=$40;
  _mask_lens_enabled:cardinal=$80;
  _mask_dynupdrate:cardinal=$100;
  _mask_pdaautozoom:cardinal=$200;
  _mask_pdasavezoomstate:cardinal=$400;
  _mask_alterzoomclickswitch:cardinal=$800;

//--------------------------------------------------Общие вещи---------------------------------------------------
function GetGameIni():pointer;stdcall;
begin
asm
  mov eax, xrgame_addr
  mov eax, [eax+$5127E8]
  mov eax, [eax]
  mov @result, eax
end;
end;

function game_ini_line_exist(section:PChar; key:PChar):boolean;stdcall;
asm
    pushad
    pushfd

    push key
    push section

    call GetGameIni
    mov ecx, eax

    mov eax, xrCore_addr
    add eax, $182D0
    call eax
    mov @result, al

    popfd
    popad
end;

function game_ini_r_bool_int(section:PChar; key:PChar):boolean;stdcall;
asm
    pushad
    pushfd

    push key
    push section
    call GetGameIni
    mov ecx, eax

    mov eax, xrCore_addr
    add eax, $18970
    call eax

    mov @result, al

    popfd
    popad
end;

function game_ini_r_bool(section:PChar; key:PChar):boolean;stdcall;
begin
{$ifdef LOG_RAW_CONFIG_ACCESS}
  Log('game_ini_r_bool: ' + key + ', ' + section);
{$endif}

  result:=game_ini_r_bool_int(section, key);
end;

function game_ini_read_string_int(section:PChar; key:PChar):PChar;stdcall;
asm
    pushad
    pushfd

    push key
    push section

    call GetGameIni
    mov ecx, eax

    mov eax, xrCore_addr
    add eax, $18530
    call eax
    
    mov @result, eax

    popfd
    popad
end;

function game_ini_read_string(section:PChar; key:PChar):PChar;stdcall;
begin
{$ifdef LOG_RAW_CONFIG_ACCESS}
  Log('game_ini_read_string: ' + key + ', ' + section);
{$endif}

  result:=game_ini_read_string_int(section, key);
end;

function game_ini_read_string_def(section:PChar; key:PChar; def:PChar):PChar;stdcall;
begin
  result:=def;
  if game_ini_line_exist(section, key) then begin
    result:=game_ini_read_string(section, key);
  end;
end;

function game_ini_read_string_by_object_string(section:pointer; key:PChar):PChar;stdcall;
asm
    pushad
    pushfd

    push key
    push section
    call GetGameIni
    mov ecx, eax

    mov eax, xrCore_addr
    add eax, $2BE0
    call eax
    mov @result, eax

    popfd
    popad
end;

function game_ini_r_bool_def(section:PChar; key:PChar; def:boolean; is_default:pboolean):boolean;stdcall;
begin
  if game_ini_line_exist(section, key) then begin
    result:=game_ini_r_bool(section, key);
    if is_default<>nil then is_default^:=false;
  end else begin
    result:=def;
    if is_default<>nil then is_default^:=true;
  end;
end;

function game_ini_r_int_def(section:PChar; key:PChar; def:integer; is_default:pboolean):integer; stdcall;
begin
  if game_ini_line_exist(section, key) then begin
    result:=strtointdef(game_ini_read_string(section, key), def);
    if is_default<>nil then is_default^:=false;
  end else begin
    result:=def;
    if is_default<>nil then is_default^:=true;
  end;
end;

function game_ini_r_single(section:PChar; key:PChar):single;stdcall;
begin
  result:= strtofloatdef(game_ini_read_string(section, key),0);
end;

function game_ini_r_single_def(section:PChar; key:PChar; def:single; is_default:pboolean):single; stdcall;
begin
  if game_ini_line_exist(section, key) then begin
    result:=game_ini_r_single(section, key);
    if is_default<>nil then is_default^:=false;
  end else begin
    result:=def;
    if is_default<>nil then is_default^:=true;
  end;
end;


function game_ini_read_vector3_def(section:PChar; key:PChar; def:pfvector3):FVector3;stdcall;
var
  tmp, coord:string;
begin
  if game_ini_line_exist(section, key) then begin
    tmp:=game_ini_read_string(section, key);

    GetNextSubStr(tmp, coord, ',');
    result.x:=strtofloatdef(coord, 0);

    GetNextSubStr(tmp, coord, ',');
    result.y:=strtofloatdef(coord, 0);

    GetNextSubStr(tmp, coord, ',');
    result.z:=strtofloatdef(coord, 0);

  end else
    result:=def^;
end;

function game_ini_r_line(section:PChar; idx:integer; n:PPAnsiChar; v:PPAnsiChar):boolean;stdcall;
asm
    pushad
    pushfd

    push v
    push n
    push idx
    push section

    call GetGameIni
    mov ecx, eax

    mov eax, xrCore_addr
    add eax, $18A40
    call eax
    mov @result, al

    popfd
    popad
end;

function translate(text:PChar):PChar;stdcall;
asm
  pushad
    mov eax, xrgame_addr
    add eax, $23d4f0
    push text
    call eax
    mov @result, eax
    add esp, 4
  popad
end;


function GetCachedCfgParamFloatDef(var cached:cached_cfg_param_float; section:string; key:string; def:single):single;
begin
  if (length(cached.last_section)=length(section)) and (cached.last_section = section) then begin
    if cached.is_default then begin
      result:=def;
    end else begin
      result:=cached.value;
    end;
  end else begin
    result:=game_ini_r_single_def(PAnsiChar(section), PAnsiChar(key), def, @cached.is_default);
    cached.last_section:=section;
    cached.value:=result;
  end;
end;

function GetCachedCfgParamBoolDef(var cached:cached_cfg_param_bool; section:string; key:string; def:boolean):boolean;
begin
  if (length(cached.last_section)=length(section)) and (cached.last_section = section) then begin
    if cached.is_default then begin
      result:=def;
    end else begin
      result:=cached.value;
    end;
  end else begin
    result:=game_ini_r_bool_def(PAnsiChar(section), PAnsiChar(key), def, @cached.is_default);
    cached.last_section:=section;
    cached.value:=result;
  end;
end;

//--------------------------------------------------Ганс---------------------------------------------------------
function IsSprintOnHoldEnabled():boolean; stdcall;
begin
  result:=true;
end;

function IsDebug():boolean; stdcall;
begin
  result:=true;
end;


function GetBaseFOV():single; stdcall;
begin
  result:=fov;
end;

function GetBaseHudFOV():single; stdcall;
begin
  result:=hud_fov;
end;


function GetCurrentDifficulty():cardinal; stdcall;
begin
asm
  mov eax, xrgame_addr
  mov eax, [eax+$63bc54]
  mov @result, eax
end;
end;

function IsDynamicDOF():boolean; stdcall;
begin
  result:=IsDofEnabled() and ((_console_bool_flags and _mask_dyndof)>0);
end;

function IsConstZoomDOF():boolean; stdcall;
begin
  result:=((_console_bool_flags and _mask_constzoomdof)>0);
end;

function IsLaserdotCorrection():boolean; stdcall;
begin
  result:=((_console_bool_flags and _mask_laserdotcorrection)>0);
end;


function IsSoundPatchNeeded():boolean; stdcall;
begin
  result:=game_ini_r_bool_def(GUNSL_BASE_SECTION, 'patch_weapon_sounds', true);
end;

function IsNPCLasers():boolean; stdcall;
begin
  result:=((_console_bool_flags and _mask_npclasers)>0);
end;

function IsRealBallistics():boolean; stdcall;
begin
  result:=((_console_bool_flags and _mask_realballistics)>0);
end;

function GetDefaultActionDOF():FVector3; stdcall;
begin
  result:=def_act_dof;
end;

function GetDefaultZoomDOF():FVector3; stdcall;
begin
  result:=def_zoom_dof;
end;

function GetDefaultDOFSpeed():single; stdcall;
begin
  result:=dof_def_speed;
end;

function GetDefaultDOFSpeed_In():single; stdcall;
begin
  result:=dof_def_speed_in;
end;

function GetDefaultDOFSpeed_Out():single; stdcall;
begin
  result:=dof_def_speed_out;
end;

function GetDefaultDOFTimeOffset():single;
begin
  result:=dof_def_timeoffset;
end;

function IsDofEnabled():boolean; stdcall;
var
  addr:cardinal;
  val:cardinal;
const
  r2_dof_enable:cardinal = $800000;
begin
  if xrRender_R1_addr>0 then
    addr:=xrRender_R1_addr+$A4728
  else if xrRender_R2_addr>0 then
    addr:=xrRender_R2_addr+$CB9C8
  else if xrRender_R3_addr>0 then
    addr:=xrRender_R3_addr+$E7C4C
  else if xrRender_R4_addr>0 then
    addr:=xrRender_R4_addr+$F4C54;

  asm
    mov eax, addr
    mov eax, [eax]
    mov val, eax
  end;

  result:=((val and r2_dof_enable)>0);
end;


procedure InjectReaderToSystemIni(r:pIReader; path:PAnsiChar);stdcall;
asm
  pushad
  mov eax, xrcore_addr
  mov ecx, [eax+$be91c] // xrCore.pSettings
  lea ebx, [eax+$171f0]

  push 0
  push 0
  push path
  push r
  call ebx

  popad
end;

function IterateInjectionsFiles():boolean;
var
  path:string_path;
  fname:string;
  flist:FileList;
  i, cnt:cardinal;

  r:pIReader;
begin
  result:=false; 

  fs_update_path(path, '$game_config$', 'injections\system\');
  fs_file_list_open(@flist, path, FS_ListFiles+FS_RootOnly);

  cnt:=fs_file_list_count(@flist);

  log('Config injections count = '+inttostr(cnt));

  if cnt > 0 then begin
    for i:=0 to cnt-1 do begin
      fname:=fs_file_list_get_item(@flist, i);
      log('Injecting config file '+fname);
      fname:=path+fname;

      fs_r_open(@r, PAnsiChar(fname));
      if r <> nil then begin
        InjectReaderToSystemIni(r, path);
        fs_r_close(@r);
      end;
    end;
  end;

  fs_file_list_close(@flist);

  result:=true;
end;

function EnableConfigsInjections():boolean;
begin
  result:=false;

  //1. Let's disable 'Duplicate section' asserts in CInifile::Load
  if not nop_code(xrCore_addr+$175c2, 1, chr($eb)) then exit;
  if not nop_code(xrCore_addr+$17e5f, 1, chr($eb)) then exit;

  //2. Iterate all injections configs
  if not IterateInjectionsFiles() then exit;

  //3. Enable disabled asserts
  if not nop_code(xrCore_addr+$175c2, 1, chr($74)) then exit;
  if not nop_code(xrCore_addr+$17e5f, 1, chr($74)) then exit;

  result:=true;
end;

function FixConsoleCommandsValues():boolean;
var
  i, cnt:integer;
  param, val:PAnsiChar;
  fix_result:ConsoleCommandFixResult;
const
  FIX_SECTION:PAnsiChar = 'gunslinger_fixed_commands';
begin
  result:=false;

  i:=0;
  cnt:=0;
  while game_ini_r_line(FIX_SECTION, i, @param, @val) do begin
    fix_result:=FixConsoleCommandValue(param, val);
    if fix_result<>CONSOLE_FIX_RESULT_SUCCESS then begin
      Log('Can''t fix "'+param+'" to "'+val+'" - '+ConsoleCommandFixResultToString(fix_result), true);
    end else begin
      cnt:=cnt+1;
    end;
    i:=i+1;
  end;

  Log('Fixed commands count: '+inttostr(cnt));

  result:=true;
end;

function ReadBobbingEffectorParams():boolean;
const
  SECT:PChar='bobbing_effector';
begin
  result:=false;

  _bobbing_effector_params.sprint.amplitude:=game_ini_r_single_def(SECT, 'sprint_amplitude', 0);
  _bobbing_effector_params.sprint.speed:=game_ini_r_single_def(SECT, 'sprint_speed', 0);

  _bobbing_effector_params.zoom_limp.amplitude:=game_ini_r_single_def(SECT, 'zoom_limp_amplitude', 0);
  _bobbing_effector_params.zoom_limp.speed:=game_ini_r_single_def(SECT, 'zoom_limp_speed', 0);

  _bobbing_effector_params.limp.amplitude:=game_ini_r_single_def(SECT, 'limp_amplitude', 0);
  _bobbing_effector_params.limp.speed:=game_ini_r_single_def(SECT, 'limp_speed', 0);

  _bobbing_effector_params.zoom_slow_crouch.amplitude:=game_ini_r_single_def(SECT, 'zoom_slow_crouch_amplitude', 0);
  _bobbing_effector_params.zoom_slow_crouch.speed:=game_ini_r_single_def(SECT, 'zoom_slow_crouch_speed', 0);

  _bobbing_effector_params.slow_crouch.amplitude:=game_ini_r_single_def(SECT, 'slow_crouch_amplitude', 0);
  _bobbing_effector_params.slow_crouch.speed:=game_ini_r_single_def(SECT, 'slow_crouch_speed', 0);

  _bobbing_effector_params.zoom_crouch.amplitude:=game_ini_r_single_def(SECT, 'zoom_crouch_amplitude', 0);
  _bobbing_effector_params.zoom_crouch.speed:=game_ini_r_single_def(SECT, 'zoom_crouch_speed', 0);

  _bobbing_effector_params.crouch.amplitude:=game_ini_r_single_def(SECT, 'crouch_amplitude', 0);
  _bobbing_effector_params.crouch.speed:=game_ini_r_single_def(SECT, 'crouch_speed', 0);

  _bobbing_effector_params.zoom_walk.amplitude:=game_ini_r_single_def(SECT, 'zoom_walk_amplitude', 0);
  _bobbing_effector_params.zoom_walk.speed:=game_ini_r_single_def(SECT, 'zoom_walk_speed', 0);

  _bobbing_effector_params.walk.amplitude:=game_ini_r_single_def(SECT, 'walk_amplitude', 0);
  _bobbing_effector_params.walk.speed:=game_ini_r_single_def(SECT, 'walk_speed', 0);

  _bobbing_effector_params.zoom_run.amplitude:=game_ini_r_single_def(SECT, 'zoom_run_amplitude', 0);
  _bobbing_effector_params.zoom_run.speed:=game_ini_r_single_def(SECT, 'zoom_run_speed', 0);

  _bobbing_effector_params.run.amplitude:=game_ini_r_single_def(SECT, 'run_amplitude', 0);
  _bobbing_effector_params.run.speed:=game_ini_r_single_def(SECT, 'run_speed', 0);

  _bobbing_effector_params.amplitude_delta:=game_ini_r_single_def(SECT, 'amplitude_delta', 1);

  result:=true;
end;

function Init:boolean;
begin
  result:=false;
  
  if not EnableConfigsInjections() then exit;

  _console_bool_flags:=0;
  _console_bool_flags:=_console_bool_flags or _mask_alterzoomclickswitch;

  _lens_render_factor:=1;
  _lens_enabled:=true;
//--------------------------------Uncut console commands-----------------------------------------------------------
  if IsDebug() then begin
    psDeviceFlags:=pointer(xrEngine_addr+$91304);
    g_upgrades_log:=pointer(xrGame_addr+$64bd94);

    CCC_Mask__CCC_Mask(@CCC_mt_sound, 'mt_sound', psDeviceFlags, 1 shl 14);
    CConsole__AddCommand(@(CCC_mt_sound.base));

    CCC_Mask__CCC_Mask(@CCC_mt_physics, 'mt_physics', psDeviceFlags, 1 shl 15);
    CConsole__AddCommand(@(CCC_mt_physics.base));

    CCC_Mask__CCC_Mask(@CCC_mt_network, 'mt_network', psDeviceFlags, 1 shl 16);
    CConsole__AddCommand(@(CCC_mt_network.base));

    CCC_Mask__CCC_Mask(@CCC_rs_wireframe, 'rs_wireframe', psDeviceFlags, 1 shl 3);
    CConsole__AddCommand(@(CCC_rs_wireframe.base));

    CCC_Mask__CCC_Mask(@CCC_rs_clear_bb, 'rs_clear_bb', psDeviceFlags, 1 shl 1);
    CConsole__AddCommand(@(CCC_rs_clear_bb.base));

    CCC_Mask__CCC_Mask(@CCC_rs_occlusion, 'rs_occlusion', psDeviceFlags, 1 shl 4);
    CConsole__AddCommand(@(CCC_rs_occlusion.base));

    CCC_Mask__CCC_Mask(@CCC_rs_detail, 'rs_detail', psDeviceFlags, 1 shl 6);
    CConsole__AddCommand(@(CCC_rs_detail.base));

    CCC_Mask__CCC_Mask(@CCC_rs_render_statics, 'rs_render_statics', psDeviceFlags, 1 shl 9);
    CConsole__AddCommand(@(CCC_rs_render_statics.base));

    CCC_Mask__CCC_Mask(@CCC_rs_render_dynamics, 'rs_render_dynamics', psDeviceFlags, 1 shl 10);
    CConsole__AddCommand(@(CCC_rs_render_dynamics.base));

    CCC_Mask__CCC_Mask(@CCC_rs_occ_draw, 'rs_occ_draw', psDeviceFlags, 1 shl 12);
    CConsole__AddCommand(@(CCC_rs_occ_draw.base));

    CCC_Mask__CCC_Mask(@CCC_rs_occ_stats, 'rs_occ_stats', psDeviceFlags, 1 shl 13);
    CConsole__AddCommand(@(CCC_rs_occ_stats.base));

    CCC_Mask__CCC_Mask(@CCC_rs_disable_objects_as_crows, 'rs_disable_objects_as_crows', psDeviceFlags, 1 shl 11);
    CConsole__AddCommand(@(CCC_rs_disable_objects_as_crows.base));


    CCC_Integer__CCC_Integer(@CCC_upgrades_log, 'g_upgrades_log', g_upgrades_log, 0, 1);
    CConsole__AddCommand(@(CCC_upgrades_log.base));
  end;
//-----------------------------------------------------------------------------------------------------------------
  CCC_Mask__CCC_Mask(@CCC_dyndof, 'r2_dynamic_dof', @_console_bool_flags, _mask_dyndof);
  CConsole__AddCommand(@(CCC_dyndof.base));
  CCC_Mask__CCC_Mask(@CCC_constzoomdof, 'r2_const_zoomdof', @_console_bool_flags, _mask_constzoomdof);
  CConsole__AddCommand(@(CCC_constzoomdof.base));
  CCC_Mask__CCC_Mask(@CCC_laserdotdistcorrection, 'laserdot_correction', @_console_bool_flags, _mask_laserdotcorrection);
  CConsole__AddCommand(@(CCC_laserdotdistcorrection.base));
  CCC_Mask__CCC_Mask(@CCC_npclasers, 'npc_lasers', @_console_bool_flags, _mask_npclasers);
  CConsole__AddCommand(@(CCC_npclasers.base));
  CCC_Mask__CCC_Mask(@CCC_realballistics, 'g_real_shooting', @_console_bool_flags, _mask_realballistics);
  CConsole__AddCommand(@(CCC_realballistics.base));
  CCC_Integer__CCC_Integer(@CCC_lens_render_factor, 'lens_render_factor', pinteger(@_lens_render_factor), 1, 4);
  CConsole__AddCommand(@(CCC_lens_render_factor.base));
  CCC_Mask__CCC_Mask(@CCC_force_lense, 'lens_render_forced', @_console_bool_flags, _mask_forcelense);
  CConsole__AddCommand(@(CCC_force_lense.base));
  CCC_Mask__CCC_Mask(@CCC_unlock_snd, 'snd_unlock', @_console_bool_flags, _mask_unlocksnd);
  CConsole__AddCommand(@(CCC_unlock_snd.base));
  CCC_Mask__CCC_Mask(@CCC_lens_enabled, 'lens_enabled', @_console_bool_flags, _mask_lens_enabled);
  CConsole__AddCommand(@(CCC_lens_enabled.base));
  CCC_Mask__CCC_Mask(@CCC_dynamic_updrate, 'dynamic_updrate', @_console_bool_flags, _mask_dynupdrate);
  CConsole__AddCommand(@(CCC_dynamic_updrate.base));
  CCC_Mask__CCC_Mask(@CCC_pdaautozoom, 'pda_autozoom', @_console_bool_flags, _mask_pdaautozoom);
  CConsole__AddCommand(@(CCC_pdaautozoom.base));
  CCC_Mask__CCC_Mask(@CCC_savezoomstate, 'pda_savezoomstate', @_console_bool_flags, _mask_pdasavezoomstate);
  CConsole__AddCommand(@(CCC_savezoomstate.base));
  CCC_Mask__CCC_Mask(@CCC_alterzoomclickswitch, 'alter_zoom_switch_on_click', @_console_bool_flags, _mask_alterzoomclickswitch);
  CConsole__AddCommand(@(CCC_alterzoomclickswitch.base));

  CCC_Float__CCC_Float(@CCC_fov, 'g_fov', @fov, 60, 100);
  CConsole__AddCommand(@(CCC_fov.base));

  CCC_Float__CCC_Float(@CCC_snd_hud_volume, 'snd_volume_hudweapon', @_hud_sound_volume, 0.1, 1.0);
  CConsole__AddCommand(@(CCC_snd_hud_volume.base));
//-----------------------------------------------------------------------------------------------------------------
  fov:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'fov', 65);
  hud_fov:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'hud_fov', 30);
  _hud_sound_volume:=1.0;

  if not FixConsoleCommandsValues() then exit;

  def_zoom_dof.x:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'default_zoom_dof_near', 0.5);
  def_zoom_dof.y:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'default_zoom_dof_focus', 0.8);
  def_zoom_dof.z:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'default_zoom_dof_far', 10000);

  def_act_dof.x:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'default_action_dof_near', 0);
  def_act_dof.y:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'default_action_dof_focus', 0.5);
  def_act_dof.z:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'default_action_dof_far', 5);
  dof_def_speed:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'default_dof_speed', 5); //для оригинального зума (pick mode)
  dof_def_speed_in:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'default_dof_speed_in', 3); //для входа в аниму
  dof_def_speed_out:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'default_dof_speed_out', 1); //для выхода из анимы

  dof_def_timeoffset:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'default_dof_time_offset', -0.4); //время выключения дофа

//----------------------------------------------------------------------------------------------------------------------------

  std_inertion.pitch_offset_r:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'inertion_default_pitch_offset_r', -0.017);
  std_inertion.pitch_offset_n:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'inertion_default_pitch_offset_n', -0.012);
  std_inertion.pitch_offset_d:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'inertion_default_pitch_offset_d', -0.02);
  std_inertion.origin_offset:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'inertion_default_origin_offset', 0.05);
  std_inertion.speed:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'inertion_default_speed', 5);

  aim_inertion.pitch_offset_r:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'inertion_aim_default_pitch_offset_r', std_inertion.pitch_offset_r);
  aim_inertion.pitch_offset_n:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'inertion_aim_default_pitch_offset_n', std_inertion.pitch_offset_n);
  aim_inertion.pitch_offset_d:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'inertion_aim_default_pitch_offset_d', std_inertion.pitch_offset_d);
  aim_inertion.origin_offset:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'inertion_aim_default_origin_offset', std_inertion.origin_offset);
  aim_inertion.speed:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'inertion_aim_default_speed', std_inertion.speed);


  _weaponmove_enabled:=game_ini_r_bool_def(GUNSL_BASE_SECTION, 'enable_hud_moving', true);
  _collimaim_enabled:=game_ini_r_bool_def(GUNSL_BASE_SECTION, 'enable_collimaim', true);  

  _max_actor_cam_speed:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'default_actor_camera_speed', 10);
  _actor_cam_pow:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'actor_camera_speed_pow', 1.0);

  _cam_landing.offset_landing:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'actor_camera_landing_offset', 0);
  _cam_landing.offset_landing2:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'actor_camera_landing2_offset', 0);
  _cam_landing.cam_speed_factor:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'actor_camera_landing_speed_factor', 1.0);
  _cam_landing.cam_speed_factor2:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'actor_camera_landing2_speed_factor', 1.0);
  _cam_landing.time_landing:=floor(game_ini_r_single_def(GUNSL_BASE_SECTION, 'actor_camera_landing_time', 0.5)*1000);
  _cam_landing.time_landing2:=floor(game_ini_r_single_def(GUNSL_BASE_SECTION, 'actor_camera_landing2_time', 0.5)*1000);
  
  _cam_landing.pow_factor:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'actor_camera_landing_speed_pow_factor', 1.0);
  _cam_landing.pow_factor2:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'actor_camera_landing2_speed_pow_factor', 1.0);

  _cam_landing.time_finish_landing:=floor(game_ini_r_single_def(GUNSL_BASE_SECTION, 'actor_camera_finish_landing_time', 0.5)*1000);
  _cam_landing.pow_finish_landing_factor:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'actor_camera_finish_landing_speed_pow_factor', 1.0);
  _cam_landing.cam_speed_finish_landing_factor:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'actor_camera_finish_landing_speed_factor', 1.0);


  _controller_time:=floor(game_ini_r_single_def(GUNSL_BASE_SECTION, 'controller_time', 3)*1000);
  _controller_prepare_time:=floor(game_ini_r_single_def(GUNSL_BASE_SECTION, 'controller_prepare_time', 3)*1000);
  _controller_blocked_time :=floor(game_ini_r_single_def(GUNSL_BASE_SECTION, 'controller_psyblocked_time ', 5)*1000);
  _actor_shocked_time:=floor(game_ini_r_single_def(GUNSL_BASE_SECTION, 'actor_shock_time', 10)*1000);

  _jitter.pos_amplitude:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'base_jitter_pos_amplitude', 0.001);
  _jitter.rot_amplitude:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'base_jitter_rot_amplitude', 0.1);

  _controlled_actor_speed_koef:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'controlled_actor_speed_koef', 1.0);

  _max_corpse_weight:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'max_corpse_weight', 100.0);
  _enable_corpse_collision:=game_ini_r_bool_def(GUNSL_BASE_SECTION, 'enable_corpse_collision', true);

  _controller_phantoms.min_cnt:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'controller_phantoms_min', 0);
  _controller_phantoms.max_cnt:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'controller_phantoms_max', 0);
  _controller_phantoms.max_radius:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'controller_phantoms_max_radius', 10);
  _controller_phantoms.min_radius:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'controller_phantoms_min_radius', 0);

  _controller_feel.min_dist:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'controller_min_feel_dist', 10.0);
  _controller_feel.max_dist:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'controller_max_feel_dist', 30.0);
  _controller_queue_stop_prob:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'controller_queue_stop_prob', 0.95);

  _controller_psiunblock_params.min_dist:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'controller_psi_unblock_mindist', 7.0);
  _controller_psiunblock_params.max_dist:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'controller_psi_unblock_maxdist', 60.0);
  _controller_psiunblock_params.min_dist_prob:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'controller_psi_unblock_mindist_prob', 0.95);
  _controller_psiunblock_params.max_dist_prob:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'controller_psi_unblock_maxdist_prob', 0.1);

  _controller_mouse_control_params.min_sense_scale:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'controller_mouse_sense_min', 0.1);
  _controller_mouse_control_params.max_sense_scale:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'controller_mouse_sense_max', 0.5);
  _controller_mouse_control_params.min_offset:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'controller_mouse_offset_min', -5);
  _controller_mouse_control_params.max_offset:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'controller_mouse_offset_max', 5);
  _controller_mouse_control_params.keyboard_move_k:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'controller_mouse_keyboard_move_k', 3.0);

  _max_jitter_health:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'max_jitter_health', 0.3);
  _actor_max_breath_health:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'max_breath_health', 0.15);
  _actor_breath_health_snddelta:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'max_breath_health_snddelta', 0.05);

  _headlamp_enable_animator_section:=game_ini_read_string(GUNSL_BASE_SECTION, 'headlamp_enable_animator');
  _headlamp_disable_animator_section:=game_ini_read_string(GUNSL_BASE_SECTION, 'headlamp_disable_animator');

  _nv_enable_animator_section:=game_ini_read_string(GUNSL_BASE_SECTION, 'nv_enable_animator');
  _nv_disable_animator_section:=game_ini_read_string(GUNSL_BASE_SECTION, 'nv_disable_animator');
  _burn_animator_section:=game_ini_read_string(GUNSL_BASE_SECTION, 'burn_animator');
  _kick_animator:=game_ini_read_string(GUNSL_BASE_SECTION, 'kick_animator');
  _pda_show_animator:=game_ini_read_string(GUNSL_BASE_SECTION, 'pda_show_animator');

  if game_ini_line_exist(GUNSL_BASE_SECTION, 'inventory_show_animator') then begin
    _inventory_show_animator:=game_ini_read_string(GUNSL_BASE_SECTION, 'inventory_show_animator');
  end else begin
    _inventory_show_animator:=nil;  
  end;

  _is_animated_addons:=game_ini_r_bool_def(GUNSL_BASE_SECTION, 'animated_addons', false);
  _is_mandatory_animated_unload_mag:=game_ini_r_bool_def(GUNSL_BASE_SECTION, 'mandatory_animated_unload_mag', false);

  _std_tiredness_params.min_tiredness:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_min_condition', 0.0);
  _std_tiredness_params.base_speed_idle:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_idle_base_speed', 1.0);
  _std_tiredness_params.base_speed_idle_aim:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_idle_aim_base_speed', 1.0);
  _std_tiredness_params.base_speed_idle_moving:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_idle_moving_base_speed', 1.0);
  _std_tiredness_params.base_speed_idle_slow:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_idle_slow_base_speed', 1.0);
  _std_tiredness_params.base_speed_idle_crouch:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_idle_crouch_base_speed', 1.0);
  _std_tiredness_params.base_speed_idle_crouch_slow:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_idle_crouch_slow_base_speed', 1.0);
  _std_tiredness_params.base_speed_idle_aim_moving:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_idle_aim_moving_base_speed', 1.0);
  _std_tiredness_params.base_speed_idle_slow_moving:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_idle_slow_moving_base_speed', 1.0);
  _std_tiredness_params.base_speed_idle_crouch_moving:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_idle_crouch_moving_base_speed', 1.0);
  _std_tiredness_params.base_speed_idle_crouch_slow_moving:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_idle_crouch_slow_moving_base_speed', 1.0);

  _std_tiredness_params.max_speed_idle:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_idle_max_speed', 1.0);
  _std_tiredness_params.max_speed_idle_aim:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_idle_aim_max_speed', 1.0);
  _std_tiredness_params.max_speed_idle_moving:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_idle_moving_max_speed', 1.0);
  _std_tiredness_params.max_speed_idle_slow:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_idle_slow_max_speed', 1.0);
  _std_tiredness_params.max_speed_idle_crouch:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_idle_crouch_max_speed', 1.0);
  _std_tiredness_params.max_speed_idle_crouch_slow:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_idle_crouch_slow_max_speed', 1.0);
  _std_tiredness_params.max_speed_idle_aim_moving:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_idle_aim_moving_max_speed', 1.0);
  _std_tiredness_params.max_speed_idle_slow_moving:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_idle_slow_moving_max_speed', 1.0);
  _std_tiredness_params.max_speed_idle_crouch_moving:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_idle_crouch_moving_max_speed', 1.0);
  _std_tiredness_params.max_speed_idle_crouch_slow_moving:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_idle_crouch_slow_moving_max_speed', 1.0);


  _std_tiredness_params.increment_per_second:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_increment_per_second', 0.1);
  _std_tiredness_params.decrement_per_second:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'tiredness_decrement_per_second', 0.1);  

  _mod_ver:=game_ini_read_string(GUNSL_BASE_SECTION, 'version');
  _save_ver:=game_ini_read_string(GUNSL_BASE_SECTION, 'save_version');
  _addon_name:=game_ini_read_string(GUNSL_BASE_SECTION, 'addon_name');

  if game_ini_line_exist(GUNSL_BASE_SECTION, 'quickuse_functor') then begin
    _quickuse_functor:=game_ini_read_string(GUNSL_BASE_SECTION, 'quickuse_functor');
  end else begin
    _quickuse_functor:=nil;
  end;
  if game_ini_line_exist(GUNSL_BASE_SECTION, 'nv_mask_update_functor') then begin
    _nv_mask_update_functor:=game_ini_read_string(GUNSL_BASE_SECTION, 'nv_mask_update_functor');
  end else begin
    _nv_mask_update_functor:=nil;
  end;

  _pda_screen_kx:=game_ini_r_single_def(GetPDAShowAnimator, 'screen_kx', 1.0);
  _pda_update_period:=game_ini_r_int_def(GetPDAShowAnimator, 'animation_update_period', 100);

  _lookout_params.speed:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'lookout_speed', 1.0);
  _lookout_params.ampl_k:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'lookout_ampl_k', 1.0);

  _lookout_params.dx_pow:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'lookout_ampl_dx_pow', 1.0);

  g_pickup_distance:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'actor_pickup_distance', 2.0);

  _weapon_torch_treasure_dist:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'weapon_torch_treasure_dist', 45);
  _headlamp_treasure_dist:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'headlamp_treasure_dist', 45);
  _lefthanded_torch_treasure_dist:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'lefthanded_torch_treasure_dist', 20);
  _light_palevo_dist:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'light_palevo_dist', 20);
  _light_see_dist:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'light_see_dist', 60);

  _burer_superstaminahit_params.distance:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_superstaminahit_dist', 15);
  _burer_superstaminahit_params.stamina_decrease:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_superstaminahit_value', 1000);
  _burer_superstaminahit_params.minimal_stamina:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_superstaminahit_minimal_stamina', 0.05);
  _burer_superstaminahit_params.minimal_stamina_health:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_superstaminahit_minimal_stamina_health', 0.5);
  _burer_superstaminahit_params.power:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_superhealthhit_power', -1);
  _burer_superstaminahit_params.impulse:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_superhealthhit_impulse', 10);
  _burer_superstaminahit_params.hit_type:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'burer_superhealthhit_type', 5);
  _burer_superstaminahit_params.force_hide_items_prob:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_superstaminahit_forceitemshideprob', 1.0);
  _burer_superstaminahit_params.condition_dec_min:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_superstaminahit_conditiondecmin', 0.05);
  _burer_superstaminahit_params.condition_dec_max:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_superstaminahit_conditiondecmax', 0.1);

  _burer_forceantiaim_dist:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_forceantiaim_dist', 7);
  _burer_forceshield_dist:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_forceshield_dist', 3);
  _burer_shielded_risky_factor:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_shielded_risky_factor', 0.02);
  _burer_min_gren_timer:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'burer_min_gren_timer', 1000);
  _burer_critical_gren_timer:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'burer_critical_gren_timer', 1000);
  _burer_forcetelefire_min_delta:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'burer_forcetelefire_min_delta', 1000);
  _burer_gravi_impulse_for_actor:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_gravi_impulse_for_actor', 1000);
  _burer_aim_shield_delay_const:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'burer_aim_shield_delay_const', 500);
  _burer_aim_shield_delay_random:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'burer_aim_shield_delay_random', 1000);  

  _burer_teleweapon_params.impulse:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_teleweapon_impulse', 0.1);
  _burer_teleweapon_params.allowed_angle:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_teleweapon_angle', 0.26);
  _burer_teleweapon_params.min_shoot_time:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'burer_teleweapon_min_shot_time', 20);
  _burer_teleweapon_params.max_shoot_time:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'burer_teleweapon_max_shot_time', 400);
  _burer_teleweapon_params.shot_probability:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_teleweapon_shot_probability', 0.4);

  _burer_skipfireall_prob:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_skip_fireall_probability', 0.8);

  _burer_selfkick_window_time:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'burer_knife_selfkick_window_time', 500);

  _burer_fly_params.enabled:=game_ini_r_bool_def(GUNSL_BASE_SECTION, 'burer_fly_params_enabled', false);
  _burer_fly_params.max_dist:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_fly_params_max_dist', 50);
  _burer_fly_params.critical_dist:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_fly_params_critical_dist', 5);
  _burer_fly_params.preferred_dist:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_fly_params_preferred_dist', 20);
  _burer_fly_params.preferred_height:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_fly_params_preferred_height', 10);
  _burer_fly_params.impulse:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'burer_fly_params_impulse', 10000);
  _burer_fly_params.cooldown_period:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'burer_fly_params_cooldown_period', 2000);
  _burer_fly_params.visibility_period:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'burer_fly_params_visibility_period', 1000);
  _burer_fly_params.max_time:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'burer_fly_params_max_time', 5000);
  _burer_fly_params.vertical_accel:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'burer_fly_params_vertical_accel', 1);

  _weapon_physics_damage_params.treshold:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'weapon_physics_damage_treshold', 15);
  _weapon_physics_damage_params.speed:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'weapon_physics_damage_speed', 0.03);

  _upgrade_menu_points_offset_x:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'upgrade_menu_points_offset_x', 0);
  _upgrade_menu_points_offset_x_16x9:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'upgrade_menu_points_offset_x_16x9', 0);

  _boar_hit_params.min_condition_decrease:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'boar_hit_conditiondecmin', 0.15);
  _boar_hit_params.max_condition_decrease:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'boar_hit_conditiondecmax', 0.3);

  _actor_fall_hit_koef:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'actor_fall_hit_koef', 1.0);
  _actor_burn_restore_speed:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'actor_burn_restore_speed', 0.000001);

  if not ReadBobbingEffectorParams() then exit;

  _shader_cache_needed:=game_ini_r_bool_def(GUNSL_BASE_SECTION, 'enable_shaders_cache', true);

  result:=true;
end;

function GetControllerTime():cardinal; stdcall;
begin
  result:=_controller_time;
end;

function IsWeaponmoveEnabled():boolean; stdcall;
begin
  result:=_weaponmove_enabled;
end;

function IsCollimAimEnabled():boolean; stdcall;
begin
  result:=_collimaim_enabled;
end;

function GetStdInertion(aim:boolean):weapon_inertion_params;
begin
  if aim then result:=aim_inertion else result:=std_inertion;
end;

function GetCamSpeedDef():single;
begin
  result:=_max_actor_cam_speed;
end;

function GetCamSpeedPow():single;
begin
  result:=_actor_cam_pow;
end;


function GetCamLandingParams():landing_params;
begin
  result:=_cam_landing;
end;

function GetBaseJitterParams():jitter_params; stdcall;
begin
  result:=_jitter;
end;

function GetCurJitterParams(hud_sect:PChar):jitter_params; stdcall;
begin
  result.pos_amplitude:=game_ini_r_single_def(hud_sect, 'jitter_pos_amplitude', _jitter.pos_amplitude);
  result.rot_amplitude:=game_ini_r_single_def(hud_sect, 'jitter_rot_amplitude', _jitter.rot_amplitude);
end;

function GetMaxCorpseWeight():single;
begin
  result:=_max_corpse_weight;
end;

function IsCorpseCollisionEnabled():boolean; stdcall;
begin
  result:=_enable_corpse_collision;
end;

function GetControllerPhantomsParams():phantoms_params; stdcall;
begin
  result:=_controller_phantoms;
end;

function GetShockTime():cardinal; stdcall;
begin
  result:=_actor_shocked_time;
end;

function GetControllerBlockedTime():cardinal; stdcall;
begin
  result:=_controller_blocked_time;
end;

function GetControllerPrepareTime():cardinal; stdcall;
begin
   result:=_controller_prepare_time;
end;

function GetControlledActorSpeedKoef():single; stdcall;
begin
  result:=_controlled_actor_speed_koef;
end;

function GetMaxJitterHealth():single; stdcall;
begin
  result:=_max_jitter_health;
end;

function GetControllerFeelParams():controller_feel_params; stdcall;
begin
  result:=_controller_feel;
end;

function GetControllerQueueStopProb():single; stdcall;
begin
  result:=_controller_queue_stop_prob;
end;

function GetControllerPsiUnblockProb():controller_psiunblock_params; stdcall;
begin
  result:=_controller_psiunblock_params;
end;

function GetControllerMouseControlParams():controller_mouse_control_params; stdcall;
begin
  result:=_controller_mouse_control_params;
end;

function GetHeadlampEnableAnimator():PChar;
begin
  result:=_headlamp_enable_animator_section;
end;

function GetHeadlampDisableAnimator():PChar;
begin
  result:=_headlamp_disable_animator_section;
end;

function GetNVEnableAnimator():PChar;
begin
  result:=_nv_enable_animator_section;
end;

function GetNVDisableAnimator():PChar;
begin
  result:=_nv_disable_animator_section;
end;

function GetBurnAnimator():PChar;
begin
  result:=_burn_animator_section;
end;

function GetKickAnimator():PChar;
begin
  result:=_kick_animator;
end;

function GetPDAShowAnimator():PChar;
begin
  result:=_pda_show_animator;
end;

function GetInventoryShowAnimator():PChar;
begin
  result:=_inventory_show_animator;
end;

function GetLensRenderFactor():cardinal; stdcall;
begin
  result:=_lens_render_factor;
end;

function IsLensEnabled():boolean;
begin
  result:=(_mask_lens_enabled and _console_bool_flags) <> 0;
end;

function GetModVer():PChar; stdcall;
begin
  result:=_mod_ver;
end;

function GetSaveVer():PChar; stdcall;
begin
  result:=_save_ver;
end;

function GetAddonName():PChar; stdcall;
begin
  result:=_addon_name;
end;

function GetActorMaxBreathHealth():single; stdcall;
begin
  result:=_actor_max_breath_health;
end;

function GetActorBreathHealthSndDelta():single; stdcall;
begin
  result:=_actor_breath_health_snddelta;
end;

function IsForcedLens:boolean; stdcall;
begin
  result:=((_console_bool_flags and _mask_forcelense)>0);
end;

function IsSndUnlock:boolean; stdcall;
begin
  result:=((_console_bool_flags and _mask_unlocksnd)>0);
end;

function IsDynamicUpdrate():boolean; stdcall;
begin
  result:=((_console_bool_flags and _mask_dynupdrate)>0);
end;

function GetQuickUseScriptFunctorName():PChar; stdcall;
begin
  result:=_quickuse_functor;
end;

function GetNvMaskUpdateFunctorName():PChar; stdcall;
begin
  result:=_nv_mask_update_functor;
end;


function IsAnimatedAddons():boolean; stdcall;
begin
  result:=_is_animated_addons;
end;

function IsMandatoryAnimatedUnloadMag():boolean; stdcall;
begin
  result:=_is_mandatory_animated_unload_mag;
end;

function IsVSyncEnabled():boolean; stdcall;
begin
  result:= (pCardinal(psDeviceFlags)^ and (1 shl 2))>0;
end;

function GetPDAScreen_kx():single; stdcall;
begin
  result:=_pda_screen_kx;
end;

function GetPDAUpdatePeriod():cardinal; stdcall;
begin
  result:=_pda_update_period;
end;

function IsFastPdaZoom():boolean; stdcall;
begin
  result:=_console_bool_flags and _mask_pdaautozoom <> 0
end;

function IsSavePdaZoomState():boolean; stdcall;
begin
  result:=_console_bool_flags and _mask_pdasavezoomstate <> 0
end;

function IsAlterZoomClickSwitchScheme():boolean; stdcall;
begin
  result:= (_console_bool_flags and _mask_alterzoomclickswitch)<>0;
end;

function GetBaseLookoutParams():lookout_params; stdcall;
begin
  result:=_lookout_params;
end;

function GetWeaponTorchTreasureDist():single; stdcall;
begin
  result:=_weapon_torch_treasure_dist;
end;

function GetHeadlampTreasureDist():single; stdcall;
begin
  result:=_headlamp_treasure_dist;
end;

function GetLefthandedTorchTreasureDist():single; stdcall;
begin
  result:=_lefthanded_torch_treasure_dist;
end;

function GetLightPalevoDist():single; stdcall;
begin
  result:=_light_palevo_dist;
end;

function GetLightSeeDist():single; stdcall;
begin
  result:=_light_see_dist
end;

function GetBurerSuperstaminaHitParams():burer_superstamina_hit_params;
begin
  result:=_burer_superstaminahit_params;
end;

function GetBurerForceantiaimDist():single; stdcall;
begin
  result:=_burer_forceantiaim_dist;
end;

function GetBurerForceshieldDist():single; stdcall;
begin
  result:=_burer_forceshield_dist;
end;

function GetBurerShieldedRiskyFactor():single; stdcall;
begin
  result:=_burer_shielded_risky_factor;
end;

function GetBurerMinGrenTimer():cardinal; stdcall;
begin
  result:=_burer_min_gren_timer;
end;

function GetBurerCriticalGrenTimer():cardinal; stdcall;
begin
  result:=_burer_critical_gren_timer;
end;


function GetOverriddenBoneMassForVisual(visual:PAnsiChar; def:single):single; stdcall;
begin
  result:=game_ini_r_single_def(GUNSL_BONE_OVERRIDES_SECTION, visual, -1);
end;

function GetBurerTeleweaponShotParams():burer_teleweapon_params; stdcall;
begin
  result:=_burer_teleweapon_params;
end;

function GetBurerForceTeleFireMinDelta():cardinal; stdcall;
begin
  result:=_burer_forcetelefire_min_delta;
end;

function GetWeaponPhysicsDamageParams():weapon_physics_damage_params;
begin
  result:=_weapon_physics_damage_params;
end;

function GetBoneNameForBurerTeleFire():PAnsiChar; stdcall;
var
  cnt, i:cardinal;
  param:string;
begin
  result:='';
  cnt:=game_ini_r_int_def(GUNSL_BASE_SECTION, 'burer_teleweapon_bones_count', 0);
  if cnt > 0 then begin
    i:=floor(random * cnt);
    param:='burer_teleweapon_bone_'+inttostr(i);
    result:=game_ini_read_string_def(GUNSL_BASE_SECTION, PAnsiChar(param), '');
  end;
end;

function GetBurerGraviImpulseForActor():single; stdcall;
begin
  result:=_burer_gravi_impulse_for_actor;
end;

function GetBurerFlyParams():burer_fly_params;
begin
  result:=_burer_fly_params;
end;

function GetSkipFireAllProbability():single; stdcall;
begin
  result:=_burer_skipfireall_prob;
end;

function GetBurerAimShieldDelay():cardinal; stdcall;
begin
  result:=_burer_aim_shield_delay_const + (random(_burer_aim_shield_delay_random));
end;

function GetBurerSelfKickWindowTime():integer; stdcall;
begin
  result:=_burer_selfkick_window_time;
end;

function IsBurerKnifeSelfKick():boolean; stdcall;
begin
  result:=GetBurerSelfKickWindowTime()>0;
end;

function GetHudSoundVolume():single;
begin
  result:=_hud_sound_volume;
end;

function GetUpgradeMenuPointOffsetX(need_16x9:boolean):integer;
begin
  if need_16x9 then begin
    result:=_upgrade_menu_points_offset_x_16x9;
  end else begin
    result:=_upgrade_menu_points_offset_x;
  end;
end;

function GetBoarHitParams(): boar_hit_params;
begin
  result:=_boar_hit_params;
end;

function GetActorFallHitKoef():single;
begin
  result:=_actor_fall_hit_koef;
end;

function GetActorBurnRestoreSpeed():single;
begin
  result:=_actor_burn_restore_speed;
end;

function GetBobbingEffectorParams():bobbing_effector_params;
begin
  result:=_bobbing_effector_params;
end;

function IsShadersCacheNeeded():boolean;
begin
  result:=_shader_cache_needed;
end;

end.
