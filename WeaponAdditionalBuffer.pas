unit WeaponAdditionalBuffer;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface
uses MatVectors, LightUtils;

type dist_switch = record
  name:PChar;
  startdist:single;
end;

type dist_koefs = record
  startdist:single;
  multiplier:single;
end;

type conditional_breaking_params = packed record
  start_condition:single; //при каком состоянии начнутся проблемы
  end_condition:single;   //при каком состоянии отрубится вообще
  start_probability:single; //вероятность проблем в стартовом состоянии
end;

type laserdot_params = packed record
    particles_cur:PChar;
    bone_name:PChar;
    ray_bones:PChar;
    offset:FVector3;
    world_offset:FVector3;
    always_hud:boolean;
    always_world:boolean;
    hud_treshold:single;
    color:FVector3;
end;

type lens_offset_params = record
  dir:single;
  max_value:single;
  start_condition:single;
  end_condition:single;
end;
plens_offset_params = ^lens_offset_params;

type lens_zoom_params = record
  delta:single;
  target_position:single;
  speed:single;
  factor_min:single;
  factor_max:single;
  gyro_period:single;
  real_position:single;
  last_gyro_snd_time:cardinal;
end;

type stepped_params = record
  max_value:single;
  min_value:single;
  cur_value:single;
  cur_step:integer;
  steps:integer;
  jitter:single;
end;
pstepped_params = ^stepped_params;

type
  TAnimationEffector = procedure(wpn:pointer; param:integer);stdcall;

  { WpnBuf }

  WpnBuf = class
    private
    _is_weapon_explosed:boolean;

    _reloaded:boolean;
    _ammocnt_before_reload:integer;

    _needs_unzoom:boolean;

    _do_action_after_anim_played:TAnimationEffector;
    _action_param:integer;
    _my_wpn:pointer;

    _last_update_time:cardinal;
    _lock_remain_time:cardinal;
    _current_anim:string;
    _owner:pointer;

    _wanim_force_assign:boolean;

    _laser_enabled:boolean;
    _laser_installed:boolean;
    _laserdot:laserdot_params;
    _laserdot_particle_object:pointer;
    _laserdot_particles_distwitch:array of dist_switch;
    _laserdot_dist_multipliers_switch:array of dist_koefs;

    _torch_installed:boolean;
    _torch_params:torchlight_params;    

    _bullet_point_offset_hud:single;  //смещение от fire_point до точки вылета пули
    _bullet_point_offset_world:single;

    _is_ammo_in_chamber:boolean;
    _save_cartridge_in_chamber:boolean;
    _add_cartridge_in_open:boolean;

    _actor_camera_speed:single;

    _is_alter_zoom_now:boolean;
    _is_alter_zoom_last:boolean;
    _alter_zoom_direct_switch_mixup_factor:single;

    _collimator_breaking:conditional_breaking_params;
    _collimator_problems_level:single;

    _laser_breaking:conditional_breaking_params;
    _laser_problems_level:single;

    _misfire_problems_level:single;

    _torch_breaking:conditional_breaking_params;    

    _shells_needed:boolean;
    _shells_offset:FVector3;
    _preloaded:boolean;
    _is_preload_mode:boolean;

    _need_permanent_lensrender:boolean;

    _lens_zoom_params:lens_zoom_params;

    //параметры смещения при поломке оружия - полярная с.к!
    _lens_offset:lens_offset_params;
    _lens_night_brightness:stepped_params;
    _lens_night_brightness_saved_step:integer;

    //смещение сетки при выстреле
    _lens_shoot_recoil_current:FVector3; //x,y,speed
    _lens_shoot_recoil_max:FVector4;//x,y,speed,deviation
    _lens_misfire_recoil_max:FVector4;//x,y,speed,deviation

    //автоаим
    _autoaim_delay:integer;
    _autoaim_valid_time:cardinal;


    _last_recharge_time:single;
    _last_shot_time:cardinal;

    _is_shooting_without_parent:boolean;
    _shooting_without_parent_start_time:cardinal;
    _shooting_without_parent_period:cardinal;

    _last_scope_id:cardinal;

    class procedure _SetWpnBufPtr(wpn:pointer; what_write:pointer);


    public

    ammos:array of byte;
    is_firstlast_ammo_swapped:boolean;
    ammo_cnt_to_reload:integer;
    loaded_gl_state:boolean;
    last_frame_rocket_loaded:cardinal; //для РПГ
    rocket_launched:boolean;     //от утечек памяти при стрелбе из гранатометов НПСами

    last_bones_update_frame:cardinal;
    need_update_icon:boolean;

    constructor Create(wpn:pointer);
    destructor Destroy; override;
    function PlayCustomAnim(base_anm:PChar; snd_label:PChar=nil; effector:TAnimationEffector=nil; eff_param:integer=0; lock_shooting:boolean = false; ignore_aim_state:boolean=false):boolean; stdcall;

    function Update():boolean;
    procedure UpdateLensFactor(timedelta:cardinal);
    procedure UpdateTorch();

    procedure SetBeforeReloadAmmoCnt(cnt:integer);
    function GetBeforeReloadAmmoCnt():integer;

    function IsExplosed():boolean;stdcall;
    procedure SetExplosed(status:boolean);stdcall;

    function IsReloaded():boolean;stdcall;
    procedure SetReloaded(status:boolean);stdcall;

    procedure SetAnimForceReassignStatus(status:boolean);stdcall;
    function GetAnimForceReassignStatus():boolean;stdcall;

    function GetCurAnim():string;stdcall;

    procedure AddLockTime(time:cardinal);
    procedure SetLockTime(time:cardinal);
    procedure MakeLockByConfigParam(section:PChar; key:PChar; lock_shooting:boolean = false; fun:TAnimationEffector=nil; param:integer=0);

    function IsLaserEnabled():boolean;
    function IsLaserInstalled():boolean;
    function GetLaserDotData():laserdot_params;
    procedure InstallLaser(params_section:PChar);

    procedure SetLaserEnabledStatus(status:boolean);
    procedure PlayLaserdotParticle(pos:pFVector3; dist:single; is1stpersonview:boolean; hud_mode:boolean);
    procedure StopLaserdotParticle();
    procedure SetLaserDotParticleHudStatus(status:boolean);

    procedure InstallTorch(params_section:PChar);
    procedure SwitchTorch(status:boolean; forced:boolean=false);
    function IsTorchInstalled():boolean;
    function IsTorchEnabled():boolean;

    function IsAmmoInChamber():boolean;
    function SaveAmmoInChamber():boolean;
    function AddCartridgeAfterOpen():boolean;

    function GetHUDBulletOffset():single;
    function GetWorldBulletOffset: single;

    procedure SetCameraSpeed(s:single);
    function GetCameraSpeed():single;

    function IsAlterZoomMode():boolean;
    procedure SetAlterZoomMode(status:boolean);

    // Показывает, был ли последний вход в прицеливание "альтернативным" - надо для корректного выхода из альтернативного прицеливания
    function IsLastZoomAlter():boolean;
    procedure SetLastZoomAlter(status:boolean);

    //Управление плавным переходом из альтернативного прицеливания в обычное и наоборот
    procedure SetAlterZoomDirectSwitchMixupFactor(factor:single);
    function GetAlterZoomDirectSwitchMixupFactor():single;
    procedure StartAlterZoomDirectSwitchMixup();
    procedure UpdateAlterZoomDirectSwitchMixupFactor(dt:cardinal);

    function GetCollimatorBreakingParams():conditional_breaking_params;
    function GetLaserBreakingParams():conditional_breaking_params;

    function IsShellsNeeded():boolean;
    function GetShellsOffset:FVector3;

    function IsPreloadMode():boolean;
    function IsPreloaded():boolean;
    procedure SetPreloadedStatus(status:boolean);

    function NeedPermanentLensRendering():boolean;
    procedure SetPermanentLensRenderingStatus(status:boolean);
    function GetLensParams():lens_zoom_params;
    procedure SetLensParams(params:lens_zoom_params);
    procedure GetLensOffsetParams(p:plens_offset_params);
    procedure SetLensOffsetParams(p:plens_offset_params);
    function GetLensOffsetDir():single;
    procedure SetOffsetDir(val:single);

    procedure LoadNightBrightnessParamsFromSection(sect:PChar);
    procedure ReloadNightBrightnessParams();
    procedure ChangeNightBrightness(steps:integer);
    procedure SetNightBrightnessSavedStep(val:integer);
    procedure SetNightBrightness(steps:integer; use_sound:boolean);
    function GetNightPPEFactor():single;
    procedure UpdateZoomCrosshairUI();
    function GetCurBrightness():stepped_params;
    function GetCurLensRecoil():FVector3;
    procedure ApplyLensRecoil(recoil:FVector4);
    function GetShootRecoil:FVector4;
    function GetMisfireRecoil:FVector4;

    function GetAutoAimPeriod():integer;
    function GetAutoAimStartTime():cardinal;
    procedure SetAutoAimStartTime(cnt:cardinal);

    procedure SetLastRechargeTime(t:single);
    function GetLastRechargeTime():single;

    function GetCollimatorProblemsLevel():single;
    function GetLaserProblemsLevel():single;
    function GetMisfireProblemsLevel():single;

    procedure RegisterShot();
    function GetLastShotTimeDelta():cardinal;
    function GetTimeBeforeNextShot():single;

    function StartShootingWithoutParent(time:cardinal):boolean;
    function StopShootingWithoutParent():boolean;
    function IsShootingWithoutParent():boolean;

    function GetLastScopeId():cardinal;
    procedure SetLastScopeId(id:cardinal);
  end;

  function PlayCustomAnimStatic(wpn:pointer; base_anm:PChar; snd_label:PChar=nil; effector:TAnimationEffector=nil; eff_param:integer=0; lock_shooting:boolean = false; ignore_aim_state:boolean=false):boolean; stdcall;
  function GetBuffer(wpn:pointer):WpnBuf;stdcall;
  function IsExplosed(wpn:pointer):boolean;stdcall;
  procedure SetExplosed(wpn:pointer; status:boolean);stdcall;
  function IsActionProcessing(wpn:pointer):boolean;stdcall;
  function GetCurAnim(wpn:pointer):string;stdcall;
  function CanStartAction(wpn:pointer; allow_aim_state:boolean=false):boolean;stdcall;
  function CanAutoReload(wpn:pointer):boolean;stdcall;
  function CanSprintNow(wpn:pointer):boolean;stdcall;
  function CanHideWeaponNow(wpn:pointer):boolean;stdcall;
  function CanAimNow(wpn:pointer):boolean;stdcall;
  function CanBoreNow(wpn:pointer):boolean;stdcall;
  function OnActWhileReload_CanActNow(wpn:pointer):boolean;stdcall;
  function OnShoot_CanShootNow(wpn:pointer):boolean;stdcall;
  function CanLeaveAimNow(wpn:pointer):boolean;stdcall;
  procedure MakeLockByConfigParam(wpn:pointer; section:PChar; key:PChar; lock_shooting:boolean = false; fun:TAnimationEffector=nil; param:integer=0);

  function IsReloaded(wpn:pointer):boolean;stdcall;
  procedure SetReloaded(wpn:pointer; status:boolean);stdcall;
  procedure SetBeforeReloadAmmoCnt(wpn:pointer; cnt:integer);stdcall;
  function GetBeforeReloadAmmoCnt(wpn:pointer):integer;stdcall;
  procedure SetAnimForceReassignStatus(wpn:pointer; status:boolean);stdcall;
  function GetAnimForceReassignStatus(wpn:pointer):boolean;stdcall;

implementation
uses gunsl_config, windows, sysutils, BaseGameData, WeaponAnims, ActorUtils, HudItemUtils, math, strutils, DetectorUtils, ActorDOF, xr_BoneUtils, Messenger, ControllerMonster, ConsoleUtils, WeaponEvents, dynamic_caster, misc, UIUtils, xr_strings, KeyUtils;

{ WpnBuf }


procedure WpnBuf.AddLockTime(time: cardinal);
begin
  self._lock_remain_time:=self._lock_remain_time+time;
end;

constructor WpnBuf.Create(wpn: pointer);
var
  tmpvec:FVector3;
begin
  inherited Create;

  // ВНИМАНИЕ! Метод load выполняется раньше применения апгрейдов, а нас могут вызвать именно из него при загрузке игры!
  // Из-за этого все вносимые апгрейдами изменения (вроде допприцелов или типов патронов) будут еще невалидны!
  // Поэтому использовать что-то, что может поменяться при установке апгрейдов, в этом конструкторе НЕЛЬЗЯ!

  _my_wpn := wpn;
  _lock_remain_time:=0;
  self._current_anim:='';
  _is_weapon_explosed:=false;
  _owner:=GetOwner(wpn);

  _last_update_time:=GetGameTickCount;

  _SetWpnBufPtr(wpn, self);

  _reloaded:=false;
  _ammocnt_before_reload:=-1;
  _needs_unzoom:=false;
  _wanim_force_assign:=false;
  ammo_cnt_to_reload:=-1;     //только 2стволы, максимальное число заряжаемых патронов

  _laser_enabled:= (Random>0.5);
  _laser_installed:=false;
  _laserdot_particle_object:=nil;
  _laserdot.particles_cur:=nil;
  SetLength(self._laserdot_particles_distwitch, 0);
  setlength(self._laserdot_dist_multipliers_switch, 0);

  _bullet_point_offset_hud:=game_ini_r_single_def(GetSection(wpn), 'bullet_point_offset_hud', -1.0);
  _bullet_point_offset_world:=game_ini_r_single_def(GetSection(wpn), 'bullet_point_offset_world', -0.3);

  setlength(ammos, 0);
  is_firstlast_ammo_swapped:=false;

  _torch_installed:=false;
  _torch_params.enabled:=false;

  _is_ammo_in_chamber:=game_ini_r_bool_def(GetSection(wpn), 'ammo_in_chamber', false);
  _save_cartridge_in_chamber:=game_ini_r_bool_def(GetSection(wpn), 'save_cartridge_in_ammochange', true);

  _add_cartridge_in_open:=game_ini_r_bool_def(GetHUDSection(wpn), 'add_cartridge_in_open', true);
  self._preloaded:=false;
  self._is_preload_mode:=game_ini_r_bool_def(GetHUDSection(wpn), 'empty_preload_mode', true);

  _actor_camera_speed:=game_ini_r_single_def(GetSection(wpn), 'actor_camera_speed_factor', 1.0)*GetCamSpeedDef();
  _is_alter_zoom_now:=false;
  _is_alter_zoom_last:=false;
  _alter_zoom_direct_switch_mixup_factor:=0;
//  Log('creating buf for: '+inttohex(cardinal(wpn), 8));


  tmpvec.x := -1;
  tmpvec.y := -1;
  tmpvec.z := 0;
  tmpvec:=game_ini_read_vector3_def(GetSection(wpn), 'collimator_breaking_params', @tmpvec);
  _collimator_breaking.start_condition:=tmpvec.x;
  _collimator_breaking.end_condition:=tmpvec.y;
  _collimator_breaking.start_probability:=tmpvec.z;
  _collimator_problems_level := game_ini_r_single_def(GetSection(wpn), 'collimator_problems_level', 0);


  tmpvec.x := 0;
  tmpvec.y := 0;
  tmpvec.z := 0;
  _shells_needed:=game_ini_r_bool_def(GetSection(wpn), 'spawn_shells', false);
  _shells_offset:=game_ini_read_vector3_def(GetSection(wpn), 'spawn_shells_offset', @tmpvec);

  _need_permanent_lensrender:=game_ini_r_bool_def(GetHUDSection(wpn), 'permanent_lens_render', false);

  self._lens_zoom_params.factor_min:=game_ini_r_single_def(GetSection(wpn), 'min_lens_factor', 1);
  self._lens_zoom_params.factor_max:=game_ini_r_single_def(GetSection(wpn), 'max_lens_factor', 1);
  self._lens_zoom_params.speed := game_ini_r_single_def(GetSection(wpn), 'lens_speed', 0);
  self._lens_zoom_params.gyro_period:=game_ini_r_single_def(GetSection(wpn), 'lens_gyro_sound_period', 0);
  self._lens_zoom_params.delta:=1/game_ini_r_single_def(GetSection(wpn), 'lens_factor_levels_count', 5);
  self._lens_zoom_params.target_position:=1;
  
  self._lens_zoom_params.last_gyro_snd_time := GetGameTickCount();
  self._lens_zoom_params.real_position := 0;

  //параметры сбивающегося прицела
  _lens_offset.max_value:=game_ini_r_single_def(GetSection(wpn), 'lens_offset_max_val', 0.05);
  _lens_offset.start_condition:=game_ini_r_single_def(GetSection(wpn), 'lens_offset_start_condition', 0.5);
  _lens_offset.end_condition:=game_ini_r_single_def(GetSection(wpn), 'lens_offset_end_condition', 0.1);
  self.SetOffsetDir(random); //смещение линзы (перезапишется в load в случае загрузки сейва)

  _lens_night_brightness.max_value := 1.0;
  _lens_night_brightness.min_value := 0.0;
  _lens_night_brightness.cur_value := 0.5;
  _lens_night_brightness.steps:=2;
  _lens_night_brightness.cur_step:=1;
  _lens_night_brightness.jitter:=0.1;
  _lens_night_brightness_saved_step:=-1;

  _lens_shoot_recoil_max.x:=game_ini_r_single_def(GetSection(wpn), 'lens_shoot_recoil_x', 0.0);
  _lens_shoot_recoil_max.y:=game_ini_r_single_def(GetSection(wpn), 'lens_shoot_recoil_y', 0.0);
  _lens_shoot_recoil_max.z:=game_ini_r_single_def(GetSection(wpn), 'lens_shoot_recoil_speed', 0.0);
  _lens_shoot_recoil_max.w:=game_ini_r_single_def(GetSection(wpn), 'lens_shoot_recoil_deviation', 0.0);

  _lens_misfire_recoil_max.x:=game_ini_r_single_def(GetSection(wpn), 'lens_misfire_recoil_x', 0.0);
  _lens_misfire_recoil_max.y:=game_ini_r_single_def(GetSection(wpn), 'lens_misfire_recoil_y', 0.0);
  _lens_misfire_recoil_max.z:=game_ini_r_single_def(GetSection(wpn), 'lens_misfire_recoil_speed', 0.0);
  _lens_misfire_recoil_max.w:=game_ini_r_single_def(GetSection(wpn), 'lens_misfire_recoil_deviation', 0.0);

  _autoaim_delay:=floor(game_ini_r_single_def(GetSection(wpn), 'autoaim_time', 0.0)*1000);

  _misfire_problems_level := game_ini_r_single_def(GetSection(wpn), 'misfire_after_problems_level', 10);

  _lens_shoot_recoil_current.x:=0;
  _lens_shoot_recoil_current.y:=0;
  _lens_shoot_recoil_current.z:=-1;
  loaded_gl_state:=false;
  last_frame_rocket_loaded:=0;
  rocket_launched:=false;

  _autoaim_valid_time:=0;

  _last_shot_time:=0;

  _last_recharge_time:=0;

  _shooting_without_parent_start_time:=0;
  _shooting_without_parent_period:=0;
  _is_shooting_without_parent:=false;

  _last_scope_id := $FFFFFFFF;
  need_update_icon:=false;

end;

destructor WpnBuf.Destroy;
begin
  if _torch_installed then begin
    DelTorchlight(@_torch_params);
    _torch_installed:=false;
  end;

  StopLaserdotParticle();
  setlength(self._laserdot_particles_distwitch, 0);
  setlength(self._laserdot_dist_multipliers_switch, 0);
  setlength(ammos, 0);
  _SetWpnBufPtr(_my_wpn, nil);

  inherited;
end;

function GetBuffer(wpn: pointer): WpnBuf;
begin
  result:=nil;
  if not WpnCanShoot(wpn)  then exit;

  asm
    push eax
    push ebx


    mov ebx, wpn
    mov ax, [ebx+$6be]
    shl eax,16
    mov ax, [ebx+$6a2]
    mov @result, eax

    pop ebx
    pop eax
  end;
end;

function WpnBuf.GetBeforeReloadAmmoCnt(): integer;
begin
  if self._ammocnt_before_reload>=0 then begin
    result:=self._ammocnt_before_reload;
  end else begin
    result:=0;
    log('WpnBuf.GetBeforeReloadAmmoCnt: negative value found; uninitialized?');
  end;
end;

function WpnBuf.GetCurAnim(): string; stdcall;
begin
  if self._current_anim<>'' then begin
    result:=self._current_anim;
  end else begin
    result:=GetActualCurrentAnim(self._my_wpn);
  end;
end;

function IsActionProcessing(wpn: pointer): boolean;
var buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if buf<>nil then
    result:= ((GetOwner(wpn)<>nil) and (buf._lock_remain_time>0)) or ((GetOwner(wpn)<>nil) and (GetOwner(wpn)=GetActor()) and (IsActorSuicideNow() or IsActorPlanningSuicide()))
  else
    result:=false;
end;

function GetCurAnim(wpn:pointer):string;stdcall;
var buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if buf<>nil then
    result:=buf.GetCurAnim
  else
    result:='';
end;

function WpnBuf.IsExplosed(): boolean; stdcall;
begin
  result:=self._is_weapon_explosed;
end;

function WpnBuf.IsReloaded(): boolean; stdcall;
begin
  result:=self._reloaded;
end;

procedure WpnBuf.MakeLockByConfigParam(section: PChar; key: PChar; lock_shooting: boolean; fun: TAnimationEffector; param: integer);
var time:single;
begin
  if game_ini_line_exist(section, key) then begin
    time:=game_ini_r_single(section, key);
    self.SetLockTime(floor(time*1000));
    if lock_shooting then SetShootLockTime(self._my_wpn, time);
  end;

  if @fun<>nil then begin
    self._do_action_after_anim_played:=fun;
    self._action_param:=param;
  end;
end;

function WpnBuf.PlayCustomAnim(base_anm:PChar; snd_label:PChar=nil; effector:TAnimationEffector=nil; eff_param:integer=0; lock_shooting:boolean = false; ignore_aim_state:boolean=false):boolean; stdcall;
var
  actor:pointer;
  hud_sect:PChar;
  anm_name:string;
  v:FVector3;
begin
  result:=false;

  actor:=GetActor();
  if (actor=nil) or (actor<>GetOwner(_my_wpn)) then begin
    self._do_action_after_anim_played:=effector;
    self._action_param:=eff_param;
    result:=true;
    exit;
  end;
  if not CanStartAction(_my_wpn, ignore_aim_state) then exit;

  hud_sect:=GetHUDSection(_my_wpn);

  anm_name:=ModifierStd(_my_wpn, base_anm);

  PlayHudAnim(_my_wpn, PChar(anm_name), true);

  //если звук прописан в худовой секции по анимации - играем его, иначе - играем умолчательную метку
  if not PlaySoundByAnimName(_my_wpn, anm_name) then begin
    if (snd_label<>nil) then CHudItem_Play_Snd(_my_wpn, snd_label);
  end;

  self.MakeLockByConfigParam(hud_sect, PChar('lock_time_'+anm_name), lock_shooting, effector, eff_param);
  if self._lock_remain_time>0 then begin
    self._current_anim:=anm_name;
  end;

  if ReadActionDOFVector(_my_wpn, v, anm_name, false) then begin
    SetDOF(v, ReadActionDOFSpeed_In(_my_wpn, anm_name));
  end;
    
  result:=true;
end;

function PlayCustomAnimStatic(wpn:pointer; base_anm:PChar; snd_label:PChar=nil; effector:TAnimationEffector=nil; eff_param:integer=0; lock_shooting:boolean = false; ignore_aim_state:boolean=false):boolean; stdcall;
var buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if buf<> nil then
    result:=buf.PlayCustomAnim(base_anm, snd_label, effector, eff_param, lock_shooting, ignore_aim_state)
  else
    result:=true;
end;


procedure WpnBuf.SetBeforeReloadAmmoCnt(cnt: integer);
begin
  self._ammocnt_before_reload:=cnt;
end;

procedure WpnBuf.SetExplosed(status: boolean); stdcall;
begin
  self._is_weapon_explosed:=status;
end;

procedure WpnBuf.SetLockTime(time: cardinal);
begin
  self._lock_remain_time:=time;
end;

procedure WpnBuf.SetReloaded(status: boolean); stdcall;
begin
  self._reloaded:=status;
end;

procedure WpnBuf.SetAnimForceReassignStatus(status:boolean);stdcall;
begin
  self._wanim_force_assign:=status;
end;
function WpnBuf.GetAnimForceReassignStatus():boolean;stdcall;
begin
  result:=self._wanim_force_assign;
end;

procedure WpnBuf.UpdateLensFactor(timedelta:cardinal);
var
  lens_params_tmp, lens_params_final:lens_zoom_params;
  dt_needed, dt, zoom_remains, snd_remains:single;
  scope_sect:PChar;
const
  EPS:single = 0.00001;
begin
  lens_params_final:=GetLensParams();
  lens_params_tmp:=lens_params_final;

  if IsScopeAttached(_my_wpn) and (GetScopeStatus(_my_wpn)=2) then begin
    scope_sect:=game_ini_read_string(GetCurrentScopeSection(_my_wpn), 'scope_name');
    lens_params_tmp.factor_min:=game_ini_r_single_def(scope_sect, 'min_lens_factor', 1.0);
    lens_params_tmp.factor_max:=game_ini_r_single_def(scope_sect, 'max_lens_factor', 1.0);
    lens_params_tmp.speed:=game_ini_r_single_def(scope_sect, 'lens_speed', 0);
    lens_params_tmp.gyro_period := game_ini_r_single_def(scope_sect, 'lens_gyro_sound_period', 0);
  end;

  //Смотрим, сколько фова надо добрать еще
  dt_needed:= lens_params_tmp.target_position - lens_params_tmp.real_position;

  if (lens_params_tmp.speed < EPS) then begin
    //Зум меняется скачками
    lens_params_final.real_position:=lens_params_tmp.target_position;
    SetLensParams(lens_params_final);
  end else if (abs(dt_needed) > EPS) then begin
    //Сейчас требуется плавно менять зум. Оценим, с какой скоростью надо зумить, чтобы зум закончился ровно на звуке

    if (lens_params_tmp.gyro_period>EPS) then begin
      //посмотрим, сколько еще продлится зум при константной скорости
      zoom_remains:=abs(dt_needed)/lens_params_tmp.speed;
      //Посчитаем, сколько времени еще будет играться звук
      snd_remains:= lens_params_tmp.gyro_period - GetTimeDeltaSafe(lens_params_tmp.last_gyro_snd_time)/1000;
      //если звук играется дольше, чем длится зум - непорядок, замедлим зум
      if (snd_remains>zoom_remains) and (snd_remains>0) then begin
        lens_params_tmp.speed:= abs(dt_needed)/snd_remains;
      end;
    end;

    //плавное изменение увеличения
    dt := timedelta*lens_params_tmp.speed/1000; //насколько можем измениь

    if (dt < abs(dt_needed)) then begin
      if (lens_params_tmp.gyro_period>EPS) then begin
        if GetTimeDeltaSafe(lens_params_tmp.last_gyro_snd_time)/1000 > lens_params_tmp.gyro_period then begin
          //играем звук мотора
          CHudItem_Play_Snd(_my_wpn, 'sndScopeZoomGyro');
          lens_params_final.last_gyro_snd_time := GetGameTickCount();
        end;
      end;
      lens_params_final.real_position:=lens_params_final.real_position+sign(dt_needed)*dt;
    end else begin
      lens_params_final.real_position:=lens_params_tmp.target_position;
    end;
    SetLensParams(lens_params_final);
  end;
end;

function WpnBuf.Update():boolean;
var
  delta:cardinal;
  val,len,recharge_time, shot_time:single;
  queue_sz:integer;
  queue_fired:boolean;

const
  EPS:single = 0.00001;  
begin

  delta:=GetTimeDeltaSafe(_last_update_time);

  if _owner<>GetOwner(self._my_wpn) then begin
    _do_action_after_anim_played:=nil;
    self._lock_remain_time:=0;
    _owner:=GetOwner(_my_wpn);
  end;

  if self._lock_remain_time>delta then begin
    self._lock_remain_time:=self._lock_remain_time-delta;
  end else begin
    self._lock_remain_time:=0;
    _current_anim:='';
        
    if @_do_action_after_anim_played<>nil then begin
      _do_action_after_anim_played(self._my_wpn, self._action_param);
      _do_action_after_anim_played:=nil;
      _action_param:=0;
    end;
  end;

  if (_lens_shoot_recoil_current.z>0) then begin
    val:=_lens_shoot_recoil_current.z*delta/1000;
    len:=sqrt(_lens_shoot_recoil_current.x*_lens_shoot_recoil_current.x + _lens_shoot_recoil_current.y*_lens_shoot_recoil_current.y);
    if (len<=val) then begin
      _lens_shoot_recoil_current.x:=0;
      _lens_shoot_recoil_current.y:=0;
      _lens_shoot_recoil_current.z:=-1;
    end else begin
      _lens_shoot_recoil_current.x:=_lens_shoot_recoil_current.x*(1-val/len);
      _lens_shoot_recoil_current.y:=_lens_shoot_recoil_current.y*(1-val/len);
    end;
  end;

  if abs(1-GetCurrentCondition(self._my_wpn))<EPS then begin
    //при идеальном состоянии оружия - задаем новое направление поломки прицела
    self.SetOffsetDir(random);
  end;

  shot_time:=GetOneShotTime(_my_wpn);
  recharge_time:=(game_ini_r_single_def(GetSection(_my_wpn), 'recharge_time',0));
  recharge_time:=ModifyFloatUpgradedValue(_my_wpn, 'recharge_time',recharge_time);

  if recharge_time>shot_time then begin
    SetLastRechargeTime(recharge_time);
  end else begin
    SetLastRechargeTime(shot_time);
  end;

  UpdateLensFactor(delta);
  UpdateAlterZoomDirectSwitchMixupFactor(delta);


  queue_sz:=CurrentQueueSize(_my_wpn);
  queue_fired:=(queue_sz > 0) and (queue_sz<=QueueFiredCount(_my_wpn));

  if IsShootingWithoutParent() and ((GetOwner(_my_wpn) <> nil) or queue_fired or (GetCurrentAmmoCount(_my_wpn)<=0) or IsWeaponJammed(_my_wpn) or (GetTimeDeltaSafe(_shooting_without_parent_start_time)>_shooting_without_parent_period)) then begin
    StopShootingWithoutParent();
  end; 

  _last_update_time:=GetGameTickCount();
  result:=true;
end;

class procedure WpnBuf._SetWpnBufPtr(wpn: pointer; what_write: pointer);
asm
    push eax
    push ebx

    mov eax, what_write
    mov ebx, wpn
    mov [ebx+$6A2], ax
    shr eax,16
    mov [ebx+$6BE], ax

    pop ebx
    pop eax
end;

function CanHideWeaponNow(wpn:pointer):boolean;stdcall;
begin
  if (IsActionProcessing(wpn) and not OnActWhileReload_CanActNow(wpn)) or (leftstr(GetActualCurrentAnim(wpn), length('anm_switch'))= 'anm_switch') or IsHolderInSprintState(wpn) or IsHolderInAimState(wpn) or IsAimNow(wpn) then
    result:=false
  else
    result:=true;
end;

function CanSprintNow(wpn:pointer):boolean;stdcall;
begin
  if (wpn=nil) then
    result:=true
  else if IsActionProcessing(wpn) or IsControllerPreparing() or IsActorPlanningSuicide() or IsActorSuicideNow() or IsSuicideAnimPlaying(wpn) or (GetCurrentState(wpn)<>0) or (leftstr(GetActualCurrentAnim(wpn), length('anm_idle_sprint_end'))= 'anm_idle_sprint_end') or (leftstr(GetActualCurrentAnim(wpn), length('anm_shoot'))= 'anm_shoot') or (leftstr(GetActualCurrentAnim(wpn), length('anm_idle_aim'))= 'anm_idle_aim') then
    result:=false
  else if (leftstr(GetActualCurrentAnim(wpn), length('anm_idle'))<> 'anm_idle') then
    result:=false
  else
    result:=true;
end;

function CanAimNow(wpn:pointer):boolean;stdcall;
var
  tmp:pointer;
  sect:PAnsiChar;
  gl_status:integer;
begin
  result:=true;
  if IsActorSuicideNow() or IsActorPlanningSuicide() or IsControllerPreparing() then begin
    result:=false;
  end else if (leftstr(GetActualCurrentAnim(wpn), length('anm_idle_aim'))='anm_idle_aim') then begin
    //на случай, если мы недовышли из прицеливания
    result:=true
  end else if IsActionProcessing(wpn) or IsHolderInSprintState(wpn) or game_ini_r_bool_def(GetHUDSection(wpn), 'disable_aim_with_detector', false) {or IsHolderHasActiveDetector(wpn)} then begin
    result:=false
  end else begin
    if (GetActor()<>nil) and (GetActor()=GetOwner(wpn)) then begin
      tmp:=GetActiveDetector(GetActor());
      if (tmp<>nil) and (cardinal(GetCurrentState(tmp))<>EHudStates__eIdle) then
        result:=false
      else
        result:=true;
    end;

    if result then begin
      gl_status:=GetGLStatus(wpn);
      if ((gl_status=1) or ((gl_status=2) and (IsGLAttached(wpn)))) and IsGLEnabled(wpn) then begin
        if IsScopeAttached(wpn) then begin
          sect:=GetCurrentScopeSection(wpn);
        end else begin
          sect:=GetHUDSection(wpn);
        end;
        if game_ini_r_bool_def(sect, 'prohibit_aim_for_grenade_mode', false) then begin
          result:=false;
        end;
      end;
    end;
  end;
end;

function CanLeaveAimNow(wpn:pointer):boolean;stdcall;
var
  buf: WpnBuf;
  act:pointer;
  hud_sect, scope:PChar;
  leave_time:cardinal;
begin
  //Выходить из зума запрещено при действиях с оружием из-за опасности некорректной работы анимации выхода из прицеливания
  //Но если нам нужен эффект "выхода наполовину" - то разрешать его надо
  //Соответственно, разрешение на "полуприцеливание" надо прописывать в конфиге самого оружия

  //Если на оружии стоит прицел - то мы сначала смотрим, разрешает ли оружие состояние "полуприцела", а затем - разрешает ли установленный прицел.
  result:=true;

  buf := GetBuffer(wpn);
  act := GetActor();
  if (buf = nil) or (act=nil) or (act<>GetOwner(wpn))  then exit;

  if (leftstr(GetActualCurrentAnim(wpn), length('anm_shoot_lightmisfire'))='anm_shoot_lightmisfire') then begin
    result:=false;
    exit;
  end;

  if IsActorSuicideNow() or IsActorPlanningSuicide() or IsControllerPreparing() then begin
    result:=true;
    exit;
  end;

  if (IsActionProcessing(wpn) or (GetCurrentState(wpn)<>0)) and (leftstr(GetActualCurrentAnim(wpn), length('anm_idle_aim_start'))<>'anm_idle_aim_start') then begin
    hud_sect:=GetHUDSection(wpn);
    if game_ini_r_bool_def(hud_sect, 'allow_halfaimstate', false) then begin
      if IsScopeAttached(wpn) then begin
        scope:=GetCurrentScopeSection(wpn);
        if not game_ini_line_exist(scope, 'allow_halfaimstate') or not game_ini_r_bool(scope, 'allow_halfaimstate') then begin
          result:=false;
        end;
      end;
    end else begin
      result:=false;
    end; 
  end;


end;

function CanBoreNow(wpn:pointer):boolean;stdcall;
var hud_sect:string;
begin
  if IsActionProcessing(wpn) then
    result:=false
  else begin
    hud_sect:=GetHUDSection(wpn);
    if (GetActor<>nil) and (GetActor()=GetOwner(wpn)) and (GetActorActionState(GetActor(), actModNeedBlowoutAnim)) then begin
      result:=true;
    end else if game_ini_r_bool_def(PChar(hud_sect), 'disable_bore', true) then
      result:=false
    else
      result:=true;
  end;
end;

function OnActWhileReload_CanActNow(wpn:pointer):boolean;stdcall;
var
  delay:cardinal;
begin
  result:=false;
  //if (GetCurrentState(wpn)<>EWeaponStates__eReload) then exit;        //если делать так - не будет нормально работать досрочное убирание ствола

  if leftstr(GetActualCurrentAnim(wpn), length('anm_reload'))<>'anm_reload' then exit;
  delay:=floor(game_ini_r_single_def(GetHUDSection(wpn), PChar('early_reload_end_delta_'+GetActualCurrentAnim(wpn)),0)*1000);
  result:= GetTimeDeltaSafe(GetAnimTimeState(wpn, ANM_TIME_CUR), GetAnimTimeState(wpn, ANM_TIME_END))<delay;
end;

function OnShoot_CanShootNow(wpn:pointer):boolean;stdcall;
var
  anm_name:string;
  hud_sect:PChar;
  act:pointer;
  cur_param:string;
  buf:WpnBuf;
  recharge_time:single;
begin
  hud_sect:=GetHUDSection(wpn);
  act:=GetActor();

  if (act<>nil) and (act=GetOwner(wpn)) and (IsActorPlanningSuicide() or IsActorSuicideNow()) then begin
    result:=IsSuicideInreversible();
    exit;
  end;

  if IsActionProcessing(wpn) then begin
    if OnActWhileReload_CanActNow(wpn) then begin
      result:=true;
      exit;
    end;

    cur_param:='autoshoot_'+GetActualCurrentAnim(wpn);
    buf:=GetBuffer(wpn);
    if (buf<>nil) and (buf._lock_remain_time>0) and game_ini_line_exist(hud_sect, PChar(cur_param)) and game_ini_r_bool(hud_sect, PChar(cur_param)) then begin
//      SetShootLockTime(wpn, buf._lock_remain_time/1000);
//      result:=true;
        SetActorKeyRepeatFlag(kfFIRE, true);
        result:=false;
    end else begin
      result:=false;
    end;
  end else begin
    result:=true;
    //если у нас оружие "заряжается", то ждем
    buf:=GetBuffer(wpn);
    if (buf<>nil) then begin
      recharge_time:=(game_ini_r_single_def(GetSection(wpn), 'recharge_time',0));
      recharge_time:=ModifyFloatUpgradedValue(wpn, 'recharge_time',recharge_time);
      if (recharge_time>0) and (buf.GetLastShotTimeDelta()<floor(recharge_time*1000)) then begin
        result:=false;
        exit;
      end;
    end;

    //Если мы в спринте сейчас - то предварительно надо проиграть аниму выхода из него
    if (act<>nil) and (act = GetOwner(wpn)) and IsHolderInSprintState(wpn) then begin
      anm_name:='anm_idle_sprint';
      anm_name:=ModifierAlterSprint(wpn, anm_name);
      anm_name:=anm_name+'_end';
      anm_name:=ModifierStd(wpn, anm_name);
      MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_'+anm_name), true);
      PlayHudAnim(wpn, PChar(anm_name), true);
      if not PlaySoundByAnimName(wpn, anm_name) then begin
        CHudItem_Play_Snd(wpn, 'sndSprintEnd');
      end;
      SetActorActionState(act, actModSprintStarted, false);
      SetActorActionState(act, actSprint, false, mState_WISHFUL);

      SetActorKeyRepeatFlag(kfFIRE, true);
      result:=false;
    end;
  end;


end;

function CanStartAction(wpn:pointer; allow_aim_state:boolean=false):boolean;stdcall;
var
act, det:pointer;
begin
  if (wpn=nil) or ((GetOwner(wpn)<>GetActor()) and (GetActor()<>nil)) then begin
    result:=true;
    exit;
  end;
  if (GetBuffer(wpn)=nil) or IsActionProcessing(wpn) or (GetCurrentState(wpn)<>0) or ( (not allow_aim_state) and (IsHolderInAimState(wpn) or IsAimNow(wpn)) ) or IsHolderInSprintState(wpn) then
    result:=false
  else begin
    result:=true;
    if wpn <> GetActorActiveItem() then exit;

    act:=GetActor;
    det := GetActiveDetector(act);
    if (det<>nil) and (cardinal(GetCurrentState(det))=EHudStates__eShowing) then result:=false;
  end;
end;

procedure MakeLockByConfigParam(wpn:pointer; section:PChar; key:PChar; lock_shooting:boolean = false; fun:TAnimationEffector=nil; param:integer=0);
var buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if buf<>nil then begin
    buf.MakeLockByConfigParam(section, key, lock_shooting, fun, param);
  end;
end;

function IsExplosed(wpn:pointer):boolean;stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if buf<>nil then
    result:=buf.IsExplosed()
  else
    result:=false;
end;

procedure SetExplosed(wpn:pointer; status:boolean);stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if buf<>nil then buf.SetExplosed(status);
end;

function CanAutoReload(wpn:pointer):boolean;stdcall;
begin
  result:=false;
{  if not CanStartAction(wpn) then exit;
  buf:=GetBuffer(wpn);
  if not IsWeaponJammed(wpn) then result:=true;}
end;


function IsReloaded(wpn:pointer):boolean;stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if buf<>nil then
    result:=buf.IsReloaded()
  else
    result:=false;
end;

procedure SetReloaded(wpn:pointer; status:boolean);stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if buf<>nil then buf.SetReloaded(status);
end;

procedure SetBeforeReloadAmmoCnt(wpn:pointer; cnt:integer);stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if buf<>nil then buf.SetBeforeReloadAmmoCnt(cnt);
end;

function GetBeforeReloadAmmoCnt(wpn:pointer):integer;stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if buf<>nil then
    result:=buf.GetBeforeReloadAmmoCnt()
  else
    result:=-1;
end;

procedure SetAnimForceReassignStatus(wpn:pointer; status:boolean);stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if buf<>nil then buf.SetAnimForceReassignStatus(status);
end;

function GetAnimForceReassignStatus(wpn:pointer):boolean;stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if buf<>nil then
    result:=buf.GetAnimForceReassignStatus()
  else
    result:=false;
end;


function WpnBuf.IsLaserEnabled(): boolean;
begin
  result:=_laser_enabled;
end;

function WpnBuf.IsLaserInstalled(): boolean;
begin
  result:=self._laser_installed
end;

procedure WpnBuf.SetLaserEnabledStatus(status: boolean);
begin
  self._laser_enabled:=status;
end;


function WpnBuf.IsAmmoInChamber(): boolean;
begin
  result:=self._is_ammo_in_chamber;
end;

function WpnBuf.SaveAmmoInChamber(): boolean;
begin
  result:=self._save_cartridge_in_chamber;
end;

function WpnBuf.AddCartridgeAfterOpen(): boolean;
begin
  result:=self._add_cartridge_in_open;
end;

procedure WpnBuf.InstallLaser(params_section: PChar);
var
  i:integer;
  len:integer;
  tmpvec:FVector3;
begin
  if IsLaserInstalled() then exit;
  _laserdot_particle_object:=nil;
  _laserdot.particles_cur:=nil;

  //Читаем все варианты партиклов точки
  len:=game_ini_r_int_def(params_section, 'particles_count', 1);
  if len<1 then len:=1;

  setlength(self._laserdot_particles_distwitch, len);
  for i:=0 to len-1 do begin
    _laserdot_particles_distwitch[i].name:=game_ini_read_string(params_section, PChar('laserdot_particle_'+inttostr(i)));
    if i=0 then begin
      _laserdot_particles_distwitch[i].startdist:=0;
    end else begin
      _laserdot_particles_distwitch[i].startdist:=game_ini_r_single_def(params_section, PChar('laserdot_dist_'+inttostr(i)), -1);
      if _laserdot_particles_distwitch[i].startdist<_laserdot_particles_distwitch[i-1].startdist then _laserdot_particles_distwitch[i].startdist:=_laserdot_particles_distwitch[i-1].startdist;
    end;
  end;

  //читаем все переключатели дистанции
  len:=game_ini_r_int_def(params_section, 'laserdot_dists_count', 0);
  if len<0 then len:=0;
  setlength(self._laserdot_dist_multipliers_switch, len+1);
  self._laserdot_dist_multipliers_switch[0].startdist:=0;
  self._laserdot_dist_multipliers_switch[0].multiplier:=1;  

  for i:=1 to len do begin
    self._laserdot_dist_multipliers_switch[i].multiplier:=game_ini_r_single(params_section, pchar('laserdot_dist_scale_'+inttostr(i)));
    self._laserdot_dist_multipliers_switch[i].startdist:=game_ini_r_single(params_section, pchar('laserdot_dist_treshold_'+inttostr(i)));
    if self._laserdot_dist_multipliers_switch[i].startdist<self._laserdot_dist_multipliers_switch[i-1].startdist then self._laserdot_dist_multipliers_switch[i].startdist:=self._laserdot_dist_multipliers_switch[i-1].startdist;
  end;

  _laserdot.ray_bones:=game_ini_read_string(params_section, 'laser_ray_bones');
  _laserdot.bone_name:=game_ini_read_string(params_section, 'laserdot_attach_bone');
  _laserdot.offset.x:=game_ini_r_single_def(params_section, 'laserdot_attach_offset_x', 0.0);
  _laserdot.offset.y:=game_ini_r_single_def(params_section, 'laserdot_attach_offset_y', 0.0);
  _laserdot.offset.z:=game_ini_r_single_def(params_section, 'laserdot_attach_offset_z', 0.0);

  _laserdot.world_offset.x:=game_ini_r_single_def(params_section, 'laserdot_world_attach_offset_x', 0.0);
  _laserdot.world_offset.y:=game_ini_r_single_def(params_section, 'laserdot_world_attach_offset_y', 0.0);
  _laserdot.world_offset.z:=game_ini_r_single_def(params_section, 'laserdot_world_attach_offset_z', 0.0);

  _laserdot.always_hud:=game_ini_r_bool_def(GetHUDSection(_my_wpn), 'laserdot_always_hud', false);
  _laserdot.always_world:=game_ini_r_bool_def(GetHUDSection(_my_wpn), 'laserdot_always_world', false);
  _laserdot.hud_treshold:=cos(game_ini_r_single_def(GetHUDSection(_my_wpn), 'laserdot_hud_treshold', 10)*pi/180);


  tmpvec.x := -1;
  tmpvec.y := -1;
  tmpvec.z := 0;
  tmpvec:=game_ini_read_vector3_def(params_section, 'laser_breaking_params', @tmpvec);
  _laser_breaking.start_condition:=tmpvec.x;
  _laser_breaking.end_condition:=tmpvec.y;
  _laser_breaking.start_probability:=tmpvec.z;
  _laser_problems_level := game_ini_r_single_def(params_section, 'laser_problems_level', 0);

  self._laser_installed:=true;
end;

function WpnBuf.GetLaserDotData(): laserdot_params;
begin
  result:=self._laserdot;
end;

procedure WpnBuf.PlayLaserdotParticle(pos:pFVector3; dist:single; is1stpersonview:boolean; hud_mode:boolean);
var
  zero_vel, viewpos:FVector3;
  index, i, l:integer;
  newdist, tmpdist, dist_to_cam:single;

  m:FMatrix4x4;
begin
  if (not self.IsLaserInstalled) or (not self.IsLaserEnabled) then exit;

  if is1stpersonview then begin
    if hud_mode then begin
      StopLaserdotParticle();
      exit;
    end;
    if not IsLaserdotCorrection() then begin
      if length(self._laserdot_particles_distwitch)>1 then begin
        index:=-1;
        for i:=0 to length(self._laserdot_particles_distwitch)-2 do begin
          if (dist>=_laserdot_particles_distwitch[i].startdist) and (dist<=_laserdot_particles_distwitch[i+1].startdist) then begin
            index:=i;
            break;
          end;
        end;
        if index=-1 then index := length(self._laserdot_particles_distwitch)-1;
      end else index:=0;

      if _laserdot.particles_cur<>self._laserdot_particles_distwitch[index].name then begin
        StopLaserdotParticle();
      end;

      _laserdot.particles_cur:=_laserdot_particles_distwitch[index].name;
    end else begin
      if _laserdot.particles_cur<>self._laserdot_particles_distwitch[0].name then begin
        StopLaserdotParticle();
      end;
      _laserdot.particles_cur:=_laserdot_particles_distwitch[0].name;
      //посмотрим, на какой дистанции от камеры точка
      viewpos:=FVector3_copyfromengine(CRenderDevice__GetCamPos());
      v_sub(@viewpos, pos);
      dist_to_cam:=v_length(@viewpos);
      tmpdist:=dist_to_cam;
      //messenger.SendMessage(PChar(floattostr(tmpdist)));

      //модифицируем дистанцию, на которой будем отображать точку.

      newdist:=0;
      l:=length(self._laserdot_dist_multipliers_switch)-1;
      for i:=1 to l do begin
        if tmpdist>_laserdot_dist_multipliers_switch[i].startdist-_laserdot_dist_multipliers_switch[i-1].startdist then begin
          tmpdist:=tmpdist-(_laserdot_dist_multipliers_switch[i].startdist-_laserdot_dist_multipliers_switch[i-1].startdist);
          newdist:=newdist+(_laserdot_dist_multipliers_switch[i].startdist-_laserdot_dist_multipliers_switch[i-1].startdist)*_laserdot_dist_multipliers_switch[i-1].multiplier;
        end else begin
          newdist:=newdist+tmpdist*_laserdot_dist_multipliers_switch[i-1].multiplier;
          tmpdist:=0;
          break;
        end;
      end;
      newdist:=newdist+tmpdist*self._laserdot_dist_multipliers_switch[l].multiplier;

      tmpdist:=dist_to_cam-newdist;
      v_normalize(@viewpos);
      v_mul(@viewpos, tmpdist);
      v_add(pos, @viewpos);
    end;
  end else begin
    if (length(_laserdot_particles_distwitch)>0) then begin
      if _laserdot.particles_cur<>self._laserdot_particles_distwitch[1].name then begin
        StopLaserdotParticle();
      end;
      _laserdot.particles_cur:=_laserdot_particles_distwitch[1].name;
    end else begin
      _laserdot.particles_cur:=_laserdot_particles_distwitch[0].name;
    end;
  end;

  zero_vel.x:=0;
  zero_vel.y:=0;
  zero_vel.z:=0;
  CShootingObject__StartParticles(self._my_wpn, @self._laserdot_particle_object, _laserdot.particles_cur, pos, @zero_vel, false);
end;

procedure WpnBuf.StopLaserdotParticle();
begin
  CShootingObject__StopParticles(self._my_wpn, @self._laserdot_particle_object);
  _laserdot.particles_cur := nil;
end;

procedure WpnBuf.SetLaserDotParticleHudStatus(status: boolean);
begin
  if self._laserdot_particle_object<>nil then begin
    SetParticlesHudStatus(self._laserdot_particle_object, status);
  end;
end;

function WpnBuf.GetHUDBulletOffset(): single;
begin
  result:=self._bullet_point_offset_hud;
end;

function WpnBuf.GetWorldBulletOffset: single;
begin
  result:=self._bullet_point_offset_world;
end;

procedure WpnBuf.InstallTorch(params_section: PChar);
var
  tmpvec:FVector3;
begin
  if self._torch_installed then exit;

  tmpvec.x := -1;
  tmpvec.y := -1;
  tmpvec.z := 0;
  tmpvec:=game_ini_read_vector3_def(params_section, 'torch_breaking_params', @tmpvec);
  _torch_breaking.start_condition:=tmpvec.x;
  _torch_breaking.end_condition:=tmpvec.y;
  _torch_breaking.start_probability:=tmpvec.z;

  self._torch_installed:=true;
  NewTorchlight(@_torch_params, params_section);
end;

procedure WpnBuf.SwitchTorch(status: boolean; forced:boolean=false);
begin
  if (not forced) and (status =_torch_params.enabled) then exit;
  _torch_params.enabled:=status;
  if not self._torch_installed then exit;
  SwitchTorchlight(@_torch_params, status);
end;

procedure WpnBuf.UpdateTorch();
var
  HID:pointer;
  pos, dir, tmp, zerovec, omnipos, omnidir:FVector3;
  hudmode, is_broken:boolean;
begin

  if not self._torch_installed then exit;
  
  if (GetOwner(_my_wpn)<>nil) and (GetOwner(_my_wpn)<>GetActor()) then begin
    //НПСам нельзя!
    SwitchTorch(false);
  end;

  if (IsTorchEnabled()) then begin
    SetWeaponMultipleBonesStatus(_my_wpn, _torch_params.light_cone_bones, true);
    SwitchTorch(true, true);
  end else begin
    SetWeaponMultipleBonesStatus(_my_wpn, _torch_params.light_cone_bones, false);
    SwitchTorch(false);
    exit; 
  end;

  if GetCurrentCondition(_my_wpn)<_torch_breaking.end_condition then begin
    is_broken:=true;
  end else if GetCurrentCondition(_my_wpn)<_torch_breaking.start_condition then begin
    is_broken:= random<_torch_breaking.start_probability+(_torch_breaking.start_condition-GetCurrentCondition(_my_wpn))* (1-_torch_breaking.start_probability)/(_torch_breaking.start_condition-_torch_breaking.end_condition)
  end else begin
    is_broken:=false;
  end;  

  if is_broken then begin
    SwitchTorch(false);
    SetWeaponMultipleBonesStatus(_my_wpn, _torch_params.light_cone_bones, false);
    _torch_params.enabled:=true;
  end;

  zerovec.x:=0;
  zerovec.y:=0;
  zerovec.z:=0;

  HID:=CHudItem__HudItemData(_my_wpn);
  if (GetOwner(_my_wpn)<>nil) and (GetOwner(_my_wpn)=GetActor()) and (GetActorActiveItem()<>_my_wpn) then begin 
    SwitchTorch(false);
    _torch_params.enabled:=true;
    exit;
  end else if (HID<>nil) and (GetActorActiveItem()=_my_wpn)then begin
    //1st person view
    hudmode:=true;
    attachable_hud_item__GetBoneOffsetPosDir(HID, _torch_params.light_bone, @pos, @dir, @_torch_params.offset);
    if _torch_params.is_lightdir_by_bone then begin
      //направление света задается через разность позиций 2х костей оружия
      attachable_hud_item__GetBoneOffsetPosDir(HID, _torch_params.lightdir_bone_name, @dir, @tmp, @zerovec);
      v_sub(@dir, @pos);
      v_normalize(@dir);
    end else if not IsDemoRecord() then begin
      CorrectDirFromWorldToHud(@dir, @pos, game_ini_r_single_def(GetHUDSection(_my_wpn), 'hud_recalc_koef', 1.0));      
    end;
    attachable_hud_item__GetBoneOffsetPosDir(HID, _torch_params.light_bone, @omnipos, @omnidir, @_torch_params.omni_offset);
  end else begin
    //world view
    hudmode:=false;
    dir:=_torch_params.world_offset;
    transform_tiny(GetXFORM(_my_wpn), @pos, @dir);

    dir:=_torch_params.omni_world_offset;
    transform_tiny(GetXFORM(_my_wpn), @omnipos, @dir);

    dir:=GetLastFD(_my_wpn);
  end;
  SetTorchlightPosAndDir(@_torch_params, @pos, @dir, hudmode, @omnipos, @dir);
end;

function WpnBuf.IsTorchEnabled(): boolean;
begin
  result:=_torch_params.enabled;
end;

function WpnBuf.IsTorchInstalled(): boolean;
begin
  result:=self._torch_installed;
end;

function WpnBuf.GetCameraSpeed(): single;
begin
  result:=self._actor_camera_speed;
end;

procedure WpnBuf.SetCameraSpeed(s: single);
begin
  self._actor_camera_speed:=s;
end;

function WpnBuf.IsAlterZoomMode(): boolean;
begin
  result:=self._is_alter_zoom_now;
end;

procedure WpnBuf.SetAlterZoomMode(status: boolean);
begin
  _is_alter_zoom_now:=status;
end;

function WpnBuf.IsLastZoomAlter(): boolean;
begin
  result:=_is_alter_zoom_last;
end;

procedure WpnBuf.SetLastZoomAlter(status: boolean);
begin
  _is_alter_zoom_last:=status;
end;

function WpnBuf.GetCollimatorBreakingParams(): conditional_breaking_params;
begin
  result:=self._collimator_breaking;
end;

function WpnBuf.GetLaserBreakingParams(): conditional_breaking_params;
begin
  result:=self._laser_breaking;
end;

function WpnBuf.GetShellsOffset: FVector3;
begin
  result:=self._shells_offset;
end;

function WpnBuf.IsShellsNeeded(): boolean;
begin
  result:=self._shells_needed;
end;

function WpnBuf.IsPreloaded(): boolean;
begin
  result:=self._preloaded;
end;

function WpnBuf.IsPreloadMode(): boolean;
begin
  result:=self._is_preload_mode;
end;

procedure WpnBuf.SetPreloadedStatus(status: boolean);
begin
  _preloaded:=status;
end;

function WpnBuf.NeedPermanentLensRendering(): boolean;
begin
  result:=_need_permanent_lensrender;
end;

procedure WpnBuf.SetPermanentLensRenderingStatus(status: boolean);
begin
  _need_permanent_lensrender:=status;
end;

function WpnBuf.GetLensParams():lens_zoom_params;
begin
  result:=_lens_zoom_params;
end;

procedure WpnBuf.SetLensParams(params:lens_zoom_params);
var
  t:single;
begin
  if params.factor_max < params.factor_min then begin
    t:=params.factor_min;
    params.factor_min:=params.factor_max;
    params.factor_max:=t;
  end;

  if params.target_position<0 then begin
    params.target_position:=0;
  end else if params.target_position>1 then begin
    params.target_position:=1;
  end;

  if params.real_position<0 then begin
    params.real_position:=0;
  end else if params.real_position>1 then begin
    params.real_position:=1;
  end;

  _lens_zoom_params:=params;
end;

procedure WpnBuf.GetLensOffsetParams(p: plens_offset_params);
begin
  if p<>nil then begin
  
    p^:=_lens_offset;
    if _lens_offset.dir<0 then
      _lens_offset.dir:=0
    else if _lens_offset.dir>1 then
      _lens_offset.dir:=1;

  end;
end;

procedure WpnBuf.SetLensOffsetParams(p: plens_offset_params);
begin
  if p<>nil then begin
    _lens_offset:=p^;
  end;
end;

function WpnBuf.GetLensOffsetDir(): single;
begin
  result:=_lens_offset.dir;
end;

procedure WpnBuf.SetOffsetDir(val: single);
begin
  _lens_offset.dir:=val;
end;

procedure WpnBuf.ReloadNightBrightnessParams();
var
  scope_sect:PChar;
begin
  scope_sect:=GetSection(self._my_wpn);
  if IsScopeAttached(self._my_wpn) and (GetScopeStatus(self._my_wpn)=2) then begin
    scope_sect:=game_ini_read_string(GetCurrentScopeSection(self._my_wpn), 'scope_name');
  end;
  self.LoadNightBrightnessParamsFromSection(scope_sect);
end;

procedure WpnBuf.LoadNightBrightnessParamsFromSection(sect: PChar);
var
  last:stepped_params;
const
  EPS:single = 0.00001;
begin
  last:=_lens_night_brightness;

  if 0 = strcomp(sect, GetSection(_my_wpn)) then begin
    _lens_night_brightness.max_value:=ModifyFloatUpgradedValue(_my_wpn, 'max_night_brightness', game_ini_r_single_def(sect, 'max_night_brightness', 1)/3);
    _lens_night_brightness.min_value:=ModifyFloatUpgradedValue(_my_wpn, 'min_night_brightness', game_ini_r_single_def(sect, 'min_night_brightness', 1)/3);
    _lens_night_brightness.steps:=FindIntValueInUpgradesDef(_my_wpn, 'steps_brightness', game_ini_r_int_def(sect, 'steps_brightness', 0));
    _lens_night_brightness.jitter:=ModifyFloatUpgradedValue(_my_wpn, 'jitter_brightness', game_ini_r_single_def(sect, 'jitter_brightness', 1));
  end else begin
    _lens_night_brightness.max_value:=game_ini_r_single_def(sect, 'max_night_brightness', 1)/3;
    _lens_night_brightness.min_value:=game_ini_r_single_def(sect, 'min_night_brightness', 1)/3;
    _lens_night_brightness.steps:=game_ini_r_int_def(sect, 'steps_brightness', 0);
    _lens_night_brightness.jitter:=game_ini_r_single_def(sect, 'jitter_brightness', 1);
  end;

  if (xrRender_R1_addr<>0) and (_lens_night_brightness.max_value>1) then begin
    _lens_night_brightness.max_value:=1;
  end;

  if (abs(_lens_night_brightness.max_value-last.max_value)>EPS) or (abs(_lens_night_brightness.min_value-last.min_value)>EPS) or (_lens_night_brightness.steps<>last.steps) then begin
    if _lens_night_brightness_saved_step >= 0 then begin
      //судя по всему, игра была только загружена, надо восстановить сохраненное значение
      _lens_night_brightness.cur_step:=_lens_night_brightness_saved_step;
      _lens_night_brightness_saved_step:=-1;
    end else begin
      _lens_night_brightness.cur_step:=game_ini_r_int_def(sect, 'default_brightness_step', _lens_night_brightness.steps);
    end;
    SetNightBrightness(_lens_night_brightness.cur_step, false);
  end;

end;

procedure WpnBuf.ChangeNightBrightness(steps: integer);
begin
  if _lens_night_brightness.steps=0 then begin
    _lens_night_brightness.cur_value:=_lens_night_brightness.min_value;
    exit;
  end;

  SetNightBrightness(_lens_night_brightness.cur_step+steps, true);
end;


// try to use ChangeNightBrightness instead of SetNightBrightness!
procedure WpnBuf.SetNightBrightness(steps: integer; use_sound:boolean);
var
  delta:single;
  last_steps:integer;
begin
  last_steps:=_lens_night_brightness.cur_step;
  
  _lens_night_brightness.cur_step:=steps;
  if (_lens_night_brightness.cur_step<=0) then begin
    _lens_night_brightness.cur_step:=0;
    _lens_night_brightness.cur_value:=_lens_night_brightness.min_value;
  end else if (_lens_night_brightness.cur_step>=_lens_night_brightness.steps) then begin
    _lens_night_brightness.cur_step:=_lens_night_brightness.steps;
    _lens_night_brightness.cur_value:=_lens_night_brightness.max_value;
  end else begin
    delta:= (_lens_night_brightness.max_value-_lens_night_brightness.min_value)/(_lens_night_brightness.steps);
    _lens_night_brightness.cur_value:=_lens_night_brightness.min_value+delta*(_lens_night_brightness.cur_step);
  end;

  if (use_sound) then begin
    if last_steps>_lens_night_brightness.cur_step then begin
      CHudItem_Play_Snd(_my_wpn, 'sndScopeBrightnessMinus');
    end else if last_steps<_lens_night_brightness.cur_step then begin
      CHudItem_Play_Snd(_my_wpn, 'sndScopeBrightnessPlus');
    end;
  end;

  if last_steps <> _lens_night_brightness.cur_step then begin
    UpdateZoomCrosshairUI();
  end;
end;

procedure WpnBuf.UpdateZoomCrosshairUI();
var
  m_UIScope, child:pCUIWindow;
  i:integer;
  wndname:string;
begin
  m_UIScope:=GetWeaponZoomUI(_my_wpn);
  if (m_UIScope<>nil) then begin
    wndname:=get_string_value(@m_UIScope.m_windowName);
    if wndname = 'switchable_zoom_wnd' then begin
      for i:=0 to _lens_night_brightness.steps do begin
        child := CUIWindow__FindChild(m_UIScope, PAnsiChar('auto_static_'+inttostr(i)));
        if child<>nil then begin
          if i = _lens_night_brightness.cur_step then begin
            virtual_CUIWindow__Show(child, 1);
          end else begin
            virtual_CUIWindow__Show(child, 0);
          end;
        end;
      end;
    end;
  end else if ((GetScopeStatus(_my_wpn)=1) or (GetScopeStatus(_my_wpn)=2) and IsScopeAttached(_my_wpn)) then begin
    Log('WpnBuf.UpdateZoomCrosshairUI - scope zoom texture doesn''t exist');
  end;
end;

function WpnBuf.GetNightPPEFactor(): single;
const
  PP_MIN_FACTOR:PAnsiChar='scope_nightvision_min_factor';
var
  val, min_factor:single;
  scope_sect:PAnsiChar;
begin
  result:=-1;
  scope_sect:=nil;
  min_factor:=0;
  
  if IsScopeAttached(_my_wpn) and (GetScopeStatus(_my_wpn)=2) then begin
    scope_sect:=game_ini_read_string(GetCurrentScopeSection(_my_wpn), 'scope_name');
    min_factor:= game_ini_r_single_def(scope_sect, PP_MIN_FACTOR, 0);
  end else if (GetScopeStatus(_my_wpn)=1) then begin
    scope_sect:=GetSection(_my_wpn);
    min_factor:= ModifyFloatUpgradedValue(_my_wpn, PP_MIN_FACTOR, game_ini_r_int_def(scope_sect, PP_MIN_FACTOR, 0));
  end;

  if scope_sect<>nil then begin
    if min_factor < 0 then min_factor:=0;
    if min_factor > 1 then min_factor:=1;

    //Смотрим на уровень текущей яркости (0-1)
    if _lens_night_brightness.steps > 0 then begin
      val:=_lens_night_brightness.cur_step / _lens_night_brightness.steps;
    end else begin
      val:=1.0;
    end;

    // Нормируем яркость с учетом минимума
    val:= min_factor + (1.0-min_factor) * val;

    result:=val;
  end;
end;

function WpnBuf.GetCurBrightness(): stepped_params;
begin
  result:=_lens_night_brightness;
end;


procedure WpnBuf.ApplyLensRecoil(recoil: FVector4);
begin
  _lens_shoot_recoil_current.x:=recoil.x + recoil.w*(Random-0.5)*recoil.x;
  _lens_shoot_recoil_current.y:=recoil.y + recoil.w*(Random-0.5)*recoil.x;
  _lens_shoot_recoil_current.z:=recoil.z;
end;

function WpnBuf.GetShootRecoil: FVector4;
begin
  result:=_lens_shoot_recoil_max;
end;

function WpnBuf.GetCurLensRecoil(): FVector3;
begin
  result:=_lens_shoot_recoil_current;
end;

function WpnBuf.GetMisfireRecoil:FVector4;
begin
  result:=_lens_misfire_recoil_max;
end;

function WpnBuf.GetAutoAimPeriod():integer;
var
  modes:string;
  mode:string;
begin
  modes:=FindStrValueInUpgradesDef(self._my_wpn, 'autoaim_modes', '');
  if CurrentQueueSize(self._my_wpn)>=0 then begin
      mode:=inttostr(CurrentQueueSize(self._my_wpn));
  end else begin
    mode:='a';
  end;

  if Pos(mode, modes)<>0 then begin
    result:=FindIntValueInUpgradesDef(self._my_wpn, 'autoaim_time', self._autoaim_delay);
  end else begin
    result:=0;
  end;
end;

function WpnBuf.GetCollimatorProblemsLevel():single;
begin
  result:=ModifyFloatUpgradedValue(self._my_wpn, 'collimator_problems_level', self._collimator_problems_level);
end;

function WpnBuf.GetLaserProblemsLevel():single;
begin
  result:=self._laser_problems_level;
end;

function WpnBuf.GetMisfireProblemsLevel(): single;
begin
  result:= ModifyFloatUpgradedValue(self._my_wpn, 'misfire_after_problems_level', self._misfire_problems_level);
end;


function WpnBuf.GetAutoAimStartTime():cardinal;
begin
  result:=self._autoaim_valid_time;
end;

procedure WpnBuf.SetAutoAimStartTime(cnt:cardinal);
begin
  self._autoaim_valid_time:=cnt;
end;

procedure WpnBuf.SetLastRechargeTime(t: single);
begin
  _last_recharge_time:=t;
end;

function WpnBuf.GetLastRechargeTime(): single;
begin
  result:=_last_recharge_time;
end;

procedure WpnBuf.SetNightBrightnessSavedStep(val: integer);
begin
  _lens_night_brightness_saved_step:=val;
end;

function WpnBuf.GetAlterZoomDirectSwitchMixupFactor(): single;
begin
  result:=_alter_zoom_direct_switch_mixup_factor;
end;

procedure WpnBuf.SetAlterZoomDirectSwitchMixupFactor(factor: single);
begin
  if factor > 1.0 then begin
    factor:=1.0
  end else if factor < 0.0 then begin
    factor:=0.0;
  end;

  _alter_zoom_direct_switch_mixup_factor:=factor;
end;

procedure WpnBuf.StartAlterZoomDirectSwitchMixup();
begin
  SetAlterZoomDirectSwitchMixupFactor(1.0 - GetAlterZoomDirectSwitchMixupFactor());
end;

procedure WpnBuf.UpdateAlterZoomDirectSwitchMixupFactor(dt:cardinal);
var
  sect:PAnsiChar;
  speed:single;
  change:single;
const
  EPS:single = 0.0001;
begin
  if (GetAlterZoomDirectSwitchMixupFactor() > 0) and (GetActorActiveItem() = _my_wpn) then begin
    sect:=GetHUDSection(_my_wpn);
    speed:=ModifyFloatUpgradedValue(_my_wpn, 'alter_zoom_direct_switch_speed', game_ini_r_single_def(sect, 'alter_zoom_direct_switch_speed', 0.0));

    if IsScopeAttached(_my_wpn) then begin
      speed:=game_ini_r_single_def(GetCurrentScopeSection(_my_wpn), 'alter_zoom_direct_switch_speed', speed);
    end;

    if speed < EPS then begin
      //Моментальная смена
      SetAlterZoomDirectSwitchMixupFactor(0);
    end else begin
      speed:=speed * dt / 1000;
      if speed > GetAlterZoomDirectSwitchMixupFactor() then begin
        SetAlterZoomDirectSwitchMixupFactor(0);
      end else begin
        SetAlterZoomDirectSwitchMixupFactor(GetAlterZoomDirectSwitchMixupFactor() - speed);
      end;
    end;
  end else begin
    SetAlterZoomDirectSwitchMixupFactor(0);
  end;
end;

procedure WpnBuf.RegisterShot();
begin
  _last_shot_time:=GetGameTickCount();
end;

function WpnBuf.GetLastShotTimeDelta(): cardinal;
begin
  result:=GetTimeDeltaSafe(_last_shot_time);
end;

function WpnBuf.GetTimeBeforeNextShot(): single;
var
  delta, total:single;
begin
  total:=GetLastRechargeTime();
  delta:=GetLastShotTimeDelta()/1000;
  if delta > total then begin
    result:=0;
  end else begin
    result:=total - delta;
  end;
end;

function WpnBuf.IsShootingWithoutParent(): boolean;
begin
  result:=_is_shooting_without_parent;
end;

function WpnBuf.StartShootingWithoutParent(time: cardinal): boolean;
begin
  result:=false;
  if IsShootingWithoutParent() then exit;
  if GetOwner(_my_wpn) <> nil then exit;
  if GetCurrentAmmoCount(_my_wpn) <= 0 then exit;

  //"зажимаем" клавишу стрельбы
  CObject__processing_activate(CastHudItemToCObject(_my_wpn));
  virtual_Action(_my_wpn, kWPN_FIRE, kActPress);

  _shooting_without_parent_start_time:=GetGameTickCount();
  _shooting_without_parent_period:=time;
  _is_shooting_without_parent:=true;
  result:=true;
end;

function WpnBuf.StopShootingWithoutParent(): boolean;
begin
  result:=false;
  if not IsShootingWithoutParent() then exit;

  // "отжимаем" клавишу стрельбы
  virtual_Action(_my_wpn, kWPN_FIRE, kActRelease);

  CObject__processing_deactivate(CastHudItemToCObject(_my_wpn));
  _is_shooting_without_parent:=false;
  result:=true;
end;

function WpnBuf.GetLastScopeId: cardinal;
begin
  result:=_last_scope_id
end;

procedure WpnBuf.SetLastScopeId(id: cardinal);
begin
  _last_scope_id:=id;
end;


end.
