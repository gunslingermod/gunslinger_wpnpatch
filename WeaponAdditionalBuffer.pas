unit WeaponAdditionalBuffer;

interface
uses ScriptParticles;

type
  TAnimationEffector = procedure(wpn:pointer; param:integer);stdcall;
  WpnBuf = class
    private
    _is_weapon_explosed:boolean;

    _reloaded:boolean;
    _ammocnt_before_reload:integer;

    _needs_unzoom:boolean;

    _light:pointer;
    _do_action_after_anim_played:TAnimationEffector;
    _action_param:integer;
    _my_wpn:pointer;

    _last_update_time:cardinal;
    _lock_remain_time:cardinal;
    _current_anim:string;
    _owner:pointer;

    _wanim_force_assign:boolean;

    _laserdot:CScriptParticles;
    _laser_enabled:boolean;
    _laser_installed:boolean;

    _is_ammo_in_chamber:boolean;
    _save_cartridge_in_chamber:boolean;
    _add_cartridge_in_open:boolean;



    class procedure _SetWpnBufPtr(wpn:pointer; what_write:pointer);
    procedure _DestructLaserDot();

    public

    ammos:array of byte;
    is_firstlast_ammo_swapped:boolean;

    constructor Create(wpn:pointer);
    destructor Destroy; override;
    function PlayCustomAnim(base_anm:PChar; snd_label:PChar=nil; effector:TAnimationEffector=nil; eff_param:integer=0; lock_shooting:boolean = false; ignore_aim_state:boolean=false):boolean; stdcall;

    function Update():boolean;


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

    procedure SetLaserDotParticle(particlename: PChar);
    procedure PlayLaserDotParticleAt(vector:pointer);
    procedure StopLaserParticle();
    function IsLaserEnabled():boolean;
    function IsLaserInstalled():boolean;
    procedure SetLaserInstalledStatus(status:boolean);
    procedure SetLaserEnabledStatus(status:boolean);    
    function IsLaserDotInited():boolean;
    function IsAmmoInChamber():boolean;
    function SaveAmmoInChamber():boolean;
    function AddCartridgeAfterOpen():boolean;
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
uses GameWrappers, windows, sysutils, BaseGameData, WeaponAnims, ActorUtils, wpnutils, math, strutils, DetectorUtils;

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

  InitCScriptParticles(_laserdot);
  _laser_enabled:= (Random>0.5);
  _laser_installed:=false;

  setlength(ammos, 0);
  is_firstlast_ammo_swapped:=false;

  _is_ammo_in_chamber:=game_ini_r_bool_def(GetSection(wpn), 'ammo_in_chamber', false);
  _save_cartridge_in_chamber:=game_ini_r_bool_def(GetSection(wpn), 'save_cartridge_in_ammochange', true);

  _add_cartridge_in_open:=game_ini_r_bool_def(GetHUDSection(wpn), 'add_cartridge_in_open', true);

//  Log('creating buf for: '+inttohex(cardinal(wpn), 8));
end;

destructor WpnBuf.Destroy;
begin
  setlength(ammos, 0);
  _SetWpnBufPtr(_my_wpn, nil);
  _DestructLaserDot();
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
  if IsActionProcessing(wpn) or (GetCurrentState(wpn)<>0) or (leftstr(GetActualCurrentAnim(wpn), length('anm_shoot'))= 'anm_shoot') or (leftstr(GetActualCurrentAnim(wpn), length('anm_idle_aim'))= 'anm_idle_aim') then
    result:=false
  else
    result:=true;
end;

function CanAimNow(wpn:pointer):boolean;stdcall;
var
  tmp:pointer;
begin
  if leftstr(GetActualCurrentAnim(wpn), length('anm_idle_aim'))='anm_idle_aim' then
    //на случай, если мы недовышли из прицеливания
    result:=true
  else if IsActionProcessing(wpn) or IsHolderInSprintState(wpn) or game_ini_r_bool_def(GetHUDSection(wpn), 'disable_aim_with_detector', false) {or IsHolderHasActiveDetector(wpn)} then
    result:=false
  else begin
    if (GetActor()<>nil) and (GetActor()=GetOwner(wpn)) then begin
      tmp:=GetActiveDetector(GetActor());
      if (tmp<>nil) and (GetCurrentState(tmp)<>EHudStates__eIdle) then
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
  //Выходить из зума запрещено при действиях с оружием из-за опасности некорректной работы анимации выхода из прицеливания
  //Но если нам нужен эффект "выхода наполовину" - то разрешать его надо
  //Соответственно, разрешение на "полуприцеливание" надо прописывать в конфиге самого оружия

  //Если на оружии стоит прицел - то мы сначала смотрим, разрешает ли оружие состояние "полуприцела", а затем - разрешает ли установленный прицел.
  result:=true;

  buf := GetBuffer(wpn);
  act := GetActor();
  if (buf = nil) or (act=nil) or (act<>GetOwner(wpn))  then exit;

  if (IsActionProcessing(wpn) or (GetCurrentState(wpn)<>0)) and (leftstr(GetActualCurrentAnim(wpn), length('anm_idle_aim_start'))<>'anm_idle_aim_start') then begin
    hud_sect:=GetHUDSection(wpn);
    if game_ini_line_exist(hud_sect, 'allow_halfaimstate') and game_ini_r_bool(hud_sect, 'allow_halfaimstate') then begin
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
    //Если мы в спринте сейчас - то предварительно надо проиграть аниму выхода из него
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
    if (det<>nil) and (GetCurrentState(det)=CHUDState__eShowing) then result:=false;
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

procedure WpnBuf._DestructLaserDot;
begin
//  log('Destruct laserdot');
  if IsLaserDotInited then begin
//    log ('vftable == '+inttohex(cardinal(_laserdot.vftable),8));
    CScriptParticles__destructor(@_laserdot);
  end;
  InitCScriptParticles(_laserdot);
end;

procedure WpnBuf.SetLaserDotParticle(particlename: PChar);
begin
//  log('SetLaserDotParticle');
  if IsLaserDotInited then _DestructLaserDot;
  if particlename<>nil then CScriptParticles__constructor(@_laserdot, particlename);
end;

function WpnBuf.IsLaserEnabled: boolean;
begin
  result:=_laser_enabled;
end;

function WpnBuf.IsLaserDotInited: boolean;
begin
  result:=_laserdot.vftable<>nil;
end;

procedure WpnBuf.PlayLaserDotParticleAt(vector: pointer);
var
  zerovec:FVector3;
begin
  if not IsLaserDotInited() then exit;
  CScriptParticles__Stop(@_laserdot);
  CScriptParticles__PlayAtPos(@_laserdot, vector);
{  if not CScriptParticles__IsPlaying(@_laserdot) then begin
    CScriptParticles__PlayAtPos(@_laserdot, vector);
  end else begin
    zerovec.x:=0;
    zerovec.y:=0;
    zerovec.z:=0;
    CScriptParticles__MoveTo(@_laserdot, vector, @zerovec);
  end;}
end;

function WpnBuf.IsLaserInstalled: boolean;
begin
  result:=self._laser_installed
end;

procedure WpnBuf.SetLaserEnabledStatus(status: boolean);
begin
  self._laser_enabled:=status;
end;

procedure WpnBuf.SetLaserInstalledStatus(status: boolean);
begin
  self._laser_installed:=status;
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

procedure WpnBuf.StopLaserParticle;
begin
  if IsLaserDotInited and CScriptParticles__IsPlaying(@_laserdot) then begin
    CScriptParticles__Stop(@_laserdot);
  end;
end;

end.
