unit WeaponAdditionalBuffer;

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

type laserdot_params = packed record
    particles_cur:PChar;
    bone_name:PChar;
    ray_bones:PChar;
    offset:FVector3;
    world_offset:FVector3;
    always_hud:boolean;
    always_world:boolean;
    hud_treshold:single;
end;

type
  TAnimationEffector = procedure(wpn:pointer; param:integer);stdcall;
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

    _bullet_point_offset_hud:single;  //�������� �� fire_point �� ����� ������ ����
    _bullet_point_offset_world:single;

    _is_ammo_in_chamber:boolean;
    _save_cartridge_in_chamber:boolean;
    _add_cartridge_in_open:boolean;

    class procedure _SetWpnBufPtr(wpn:pointer; what_write:pointer);



    public

    ammos:array of byte;
    is_firstlast_ammo_swapped:boolean;


    constructor Create(wpn:pointer);
    destructor Destroy; override;
    function PlayCustomAnim(base_anm:PChar; snd_label:PChar=nil; effector:TAnimationEffector=nil; eff_param:integer=0; lock_shooting:boolean = false; ignore_aim_state:boolean=false):boolean; stdcall;

    function Update():boolean;
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
uses gunsl_config, windows, sysutils, BaseGameData, WeaponAnims, ActorUtils, HudItemUtils, math, strutils, DetectorUtils, ActorDOF, xr_BoneUtils, Messenger;

{ WpnBuf }

procedure WpnBuf.AddLockTime(time: cardinal);
begin
  self._lock_remain_time:=self._lock_remain_time+time;
end;

constructor WpnBuf.Create(wpn: pointer);
begin
  inherited Create;

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

  _laser_enabled:= (Random>0.5);
  _laser_installed:=false;
  _laserdot_particle_object:=nil;
  _laserdot.particles_cur:=nil;
  SetLength(self._laserdot_particles_distwitch, 0);
  setlength(self._laserdot_dist_multipliers_switch, 0);

  _bullet_point_offset_hud:=game_ini_r_single_def(GetSection(wpn), 'bullet_point_offset_hud', -1.3);
  _bullet_point_offset_world:=game_ini_r_single_def(GetSection(wpn), 'bullet_point_offset_world', -0.3);

  setlength(ammos, 0);
  is_firstlast_ammo_swapped:=false;

  _torch_installed:=false;
  _torch_params.enabled:=false;

  _is_ammo_in_chamber:=game_ini_r_bool_def(GetSection(wpn), 'ammo_in_chamber', false);
  _save_cartridge_in_chamber:=game_ini_r_bool_def(GetSection(wpn), 'save_cartridge_in_ammochange', true);

  _add_cartridge_in_open:=game_ini_r_bool_def(GetHUDSection(wpn), 'add_cartridge_in_open', true);
//  Log('creating buf for: '+inttohex(cardinal(wpn), 8));
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
var cls:string;
begin
  result:=nil;
  cls:=GetClassName(wpn);
  if not WpnCanShoot(PChar(cls))  then exit;

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

function WpnBuf.GetBeforeReloadAmmoCnt: integer;
begin
  if self._ammocnt_before_reload>=0 then begin
    result:=self._ammocnt_before_reload;
  end else begin
    result:=0;
    log('WpnBuf.GetBeforeReloadAmmoCnt: negative value found; uninitialized?');
  end;
end;

function WpnBuf.GetCurAnim: string;
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
    result:=(buf._lock_remain_time>0)
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

function WpnBuf.IsExplosed: boolean;
begin
  result:=self._is_weapon_explosed;
end;

function WpnBuf.IsReloaded: boolean;
begin
  result:=self._reloaded;
end;

procedure WpnBuf.MakeLockByConfigParam(section, key: PChar; lock_shooting:boolean = false; fun:TAnimationEffector=nil; param:integer=0);
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
  if (snd_label<>nil) then CHudItem_Play_Snd(_my_wpn, snd_label);
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

procedure WpnBuf.SetExplosed(status: boolean);
begin
  self._is_weapon_explosed:=status;
end;

procedure WpnBuf.SetLockTime(time: cardinal);
begin
  self._lock_remain_time:=time;
end;

procedure WpnBuf.SetReloaded(status: boolean);
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

function WpnBuf.Update():boolean;
var delta:cardinal;
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

  _last_update_time:=GetGameTickCount();
  result:=true;

end;

class procedure WpnBuf._SetWpnBufPtr(wpn: pointer; what_write: pointer);
begin
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
end;

function CanHideWeaponNow(wpn:pointer):boolean;stdcall;
begin
  if IsActionProcessing(wpn) or IsHolderInSprintState(wpn) or IsHolderInAimState(wpn) or IsAimNow(wpn) then
    result:=false
  else
    result:=true;
end;

function CanSprintNow(wpn:pointer):boolean;stdcall;
begin
  if IsActionProcessing(wpn) or (GetCurrentState(wpn)<>0) or (leftstr(GetActualCurrentAnim(wpn), length('anm_idle_sprint_end'))= 'anm_idle_sprint_end') or (leftstr(GetActualCurrentAnim(wpn), length('anm_shoot'))= 'anm_shoot') or (leftstr(GetActualCurrentAnim(wpn), length('anm_idle_aim'))= 'anm_idle_aim') then
    result:=false
  else
    result:=true;
end;

function CanAimNow(wpn:pointer):boolean;stdcall;
var
  tmp:pointer;
begin
  result:=true;
  if leftstr(GetActualCurrentAnim(wpn), length('anm_idle_aim'))='anm_idle_aim' then
    //�� ������, ���� �� ��������� �� ������������
    result:=true
  else if IsActionProcessing(wpn) or IsHolderInSprintState(wpn) or game_ini_r_bool_def(GetHUDSection(wpn), 'disable_aim_with_detector', false) {or IsHolderHasActiveDetector(wpn)} then
    result:=false
  else begin
    if (GetActor()<>nil) and (GetActor()=GetOwner(wpn)) then begin
      tmp:=GetActiveDetector(GetActor());
      if (tmp<>nil) and (cardinal(GetCurrentState(tmp))<>EHudStates__eIdle) then
        result:=false
      else
        result:=true;
    end;
  end;
end;

function CanLeaveAimNow(wpn:pointer):boolean;stdcall;
var
  buf: WpnBuf;
  act:pointer;
  hud_sect, scope:PChar;
begin
  //�������� �� ���� ��������� ��� ��������� � ������� ��-�� ��������� ������������ ������ �������� ������ �� ������������
  //�� ���� ��� ����� ������ "������ ����������" - �� ��������� ��� ����
  //��������������, ���������� �� "����������������" ���� ����������� � ������� ������ ������

  //���� �� ������ ����� ������ - �� �� ������� �������, ��������� �� ������ ��������� "�����������", � ����� - ��������� �� ������������� ������.
  result:=true;

  buf := GetBuffer(wpn);
  act := GetActor();
  if (buf = nil) or (act=nil) or (act<>GetOwner(wpn))  then exit;

  if (leftstr(GetActualCurrentAnim(wpn), length('anm_shoot_lightmisfire'))='anm_shoot_lightmisfire') then begin
    result:=false;
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
    if game_ini_r_bool_def(PChar(hud_sect), 'disable_bore', true) then
      result:=false
    else
      result:=true;
  end;
end;

function OnShoot_CanShootNow(wpn:pointer):boolean;stdcall;
var
  anm_name:string;
  hud_sect:PChar;
  act:pointer;
  cur_param:string;
  buf:WpnBuf;
begin
  hud_sect:=GetHUDSection(wpn);

  if IsActionProcessing(wpn) then begin
    cur_param:='autoshoot_'+GetActualCurrentAnim(wpn);
    buf:=GetBuffer(wpn);
    if (buf<>nil) and (buf._lock_remain_time>0) and game_ini_line_exist(hud_sect, PChar(cur_param)) and game_ini_r_bool(hud_sect, PChar(cur_param)) then begin
      SetShootLockTime(wpn, buf._lock_remain_time/1000);
      result:=true;
    end else begin
      result:=false;
    end;
  end else begin
    result:=true;
    //���� �� � ������� ������ - �� �������������� ���� ��������� ����� ������ �� ����
    act:=GetActor();
    if (act<>nil) and (act = GetOwner(wpn)) and IsHolderInSprintState(wpn) then begin
      anm_name:=ModifierStd(wpn, 'anm_idle_sprint_end');
      MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_'+anm_name), true);
      PlayHudAnim(wpn, PChar(anm_name), true);
      CHudItem_Play_Snd(wpn, 'sndSprintEnd');
      SetActorActionState(act, actModSprintStarted, false);
      SetActorActionState(act, actSprint, false, mState_WISHFUL);
    end;
  end;
end;

function CanStartAction(wpn:pointer; allow_aim_state:boolean=false):boolean;stdcall;
var
act, det:pointer;
begin
  if (GetBuffer(wpn)=nil) or IsActionProcessing(wpn) or (GetCurrentState(wpn)<>0) or ( (not allow_aim_state) and (IsHolderInAimState(wpn) or IsAimNow(wpn)) ) or IsHolderInSprintState(wpn) then
    result:=false
  else begin
    result:=true;
    if wpn <> GetActorActiveItem() then exit;

    act:=GetActor;
    det := GetActiveDetector(act);
    if (det<>nil) and (cardinal(GetCurrentState(det))=CHUDState__eShowing) then result:=false;
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


function WpnBuf.IsLaserEnabled: boolean;
begin
  result:=_laser_enabled;
end;

function WpnBuf.IsLaserInstalled: boolean;
begin
  result:=self._laser_installed
end;

procedure WpnBuf.SetLaserEnabledStatus(status: boolean);
begin
  self._laser_enabled:=status;
end;


function WpnBuf.IsAmmoInChamber: boolean;
begin
  result:=self._is_ammo_in_chamber;
end;

function WpnBuf.SaveAmmoInChamber: boolean;
begin
  result:=self._save_cartridge_in_chamber;
end;

function WpnBuf.AddCartridgeAfterOpen: boolean;
begin
  result:=self._add_cartridge_in_open;
end;

procedure WpnBuf.InstallLaser(params_section: PChar);
var
  i:integer;
  len:integer;
begin
  if IsLaserInstalled() then exit;
  _laserdot_particle_object:=nil;
  _laserdot.particles_cur:=nil;

  //������ ��� �������� ��������� �����
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

  //������ ��� ������������� ���������
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
  self._laser_installed:=true;
end;

function WpnBuf.GetLaserDotData: laserdot_params;
begin
  result:=self._laserdot;
end;

procedure WpnBuf.PlayLaserdotParticle(pos:pFVector3; dist:single; is1stpersonview:boolean; hud_mode:boolean);
var
  zero_vel, viewpos:FVector3;
  index, i, l:integer;
  newdist, tmpdist, dist_to_cam:single;
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
      //���������, �� ����� ��������� �� ������ �����
      viewpos:=FVector3_copyfromengine(CRenderDevice__GetCamPos());
      v_sub(@viewpos, pos);
      dist_to_cam:=v_length(@viewpos);
      tmpdist:=dist_to_cam;
      //messenger.SendMessage(PChar(floattostr(tmpdist)));

      //������������ ���������, �� ������� ����� ���������� �����.

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

procedure WpnBuf.StopLaserdotParticle;
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

function WpnBuf.GetHUDBulletOffset: single;
begin
  result:=self._bullet_point_offset_hud;
end;

function WpnBuf.GetWorldBulletOffset: single;
begin
  result:=self._bullet_point_offset_world;
end;

procedure WpnBuf.InstallTorch(params_section: PChar);
begin
  if self._torch_installed then exit;

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

procedure WpnBuf.UpdateTorch;
var
  HID:pointer;
  pos, dir, tmp, zerovec:FVector3;
begin

  if not self._torch_installed then exit;
  
  if (GetOwner(_my_wpn)<>nil) and (GetOwner(_my_wpn)<>GetActor()) then begin
    //����� ������!
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

  zerovec.x:=0;
  zerovec.y:=0;
  zerovec.z:=0;

  HID:=CHudItem__HudItemData(_my_wpn);
  if (GetOwner(_my_wpn)<>nil) and ((cardinal(GetCurrentState(_my_wpn))=EHudStates__eHidden) or (cardinal(GetNextState(_my_wpn))=EHudStates__eHidden)) then begin
    SwitchTorch(false);
    _torch_params.enabled:=true;
    exit;
  end else if (HID<>nil) and (GetActorActiveItem()=_my_wpn)then begin
    //1st person view
    attachable_hud_item__GetBoneOffsetPosDir(HID, _torch_params.light_bone, @pos, @dir, @_torch_params.offset);
    if _torch_params.is_lightdir_by_bone then begin
      //����������� ����� �������� ����� �������� ������� 2� ������ ������
      attachable_hud_item__GetBoneOffsetPosDir(HID, _torch_params.lightdir_bone_name, @dir, @tmp, @zerovec);
      v_sub(@dir, @pos);
      v_normalize(@dir);
    end;
  end else begin
    //world view
    dir:=_torch_params.world_offset;
    transform_tiny(GetXFORM(_my_wpn), @pos, @dir);
    dir:=GetLastFD(_my_wpn);
  end;
  SetTorchlightPosAndDir(@_torch_params, @pos, @dir);
end;

function WpnBuf.IsTorchEnabled: boolean;
begin
  result:=_torch_params.enabled;
end;

function WpnBuf.IsTorchInstalled: boolean;
begin
  result:=self._torch_installed;
end;

end.
