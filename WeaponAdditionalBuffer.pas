unit WeaponAdditionalBuffer;

interface
type
  TAnimationEffector = procedure(wpn:pointer; param:integer);stdcall;
  WpnBuf = class
    private
    _is_weapon_explosed:boolean;

    _light:pointer;
    _do_action_after_anim_played:TAnimationEffector;
    _action_param:integer;
    _my_wpn:pointer;
    _ammo_count_for_reload:integer;

    _last_update_time:cardinal;
    _lock_remain_time:cardinal;
    _current_anim:string;
    _owner:pointer;

    class procedure _SetWpnBufPtr(wpn:pointer; what_write:pointer);

    public
    constructor Create(wpn:pointer);
    destructor Destroy; override;
    function PlayCustomAnim(base_anm:PChar; snd_label:PChar=nil; effector:TAnimationEffector=nil; eff_param:integer=0; lock_shooting:boolean = false; ignore_aim_state:boolean=false):boolean; stdcall;

    function Update():boolean;

    procedure SetReloadAmmoCnt(cnt:integer);
    function GetReloadAmmoCnt():integer;

    function IsExplosed():boolean;stdcall;
    procedure SetExplosed(status:boolean);stdcall;

    function GetCurAnim():string;stdcall;

    procedure AddLockTime(time:cardinal);
    procedure SetLockTime(time:cardinal);
    procedure MakeLockByConfigParam(section:PChar; key:PChar; lock_shooting:boolean = false; fun:TAnimationEffector=nil; param:integer=0);
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
  function OnShoot_CanShootNow(wpn:pointer):boolean;stdcall;
  procedure MakeLockByConfigParam(wpn:pointer; section:PChar; key:PChar; lock_shooting:boolean = false; fun:TAnimationEffector=nil; param:integer=0);
implementation
uses GameWrappers, windows, sysutils, BaseGameData, WeaponAnims, ActorUtils, wpnutils, math;

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
  _ammo_count_for_reload:=-1;
  _is_weapon_explosed:=false;
  _owner:=GetOwner(wpn);

  _last_update_time:=GetGameTickCount;

  _SetWpnBufPtr(wpn, self);

//  Log('creating buf for: '+inttohex(cardinal(wpn), 8));
end;

destructor WpnBuf.Destroy;
begin
  _SetWpnBufPtr(_my_wpn, nil);
  inherited;
end;

function GetBuffer(wpn: pointer): WpnBuf;
var cls:string;
begin
  result:=nil;
  cls:=GetClassName(wpn);
  if not WpnCanShoot(PChar(cls)) then exit;

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

function WpnBuf.GetCurAnim: string;
begin
  if self._current_anim<>'' then begin
    result:=self._current_anim;
  end else begin
    result:=GetActualCurrentAnim(self._my_wpn);
  end;
end;

function WpnBuf.GetReloadAmmoCnt: integer;
begin
  if self._ammo_count_for_reload>=0 then begin
    result:=self._ammo_count_for_reload;
  end else begin
    result:=0;
    log('WpnBuf.GetReloadAmmoCnt: negative value found; uninitialized?');
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
  if (snd_label<>nil) then MagazinedWpnPlaySnd(_my_wpn, snd_label);
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


procedure WpnBuf.SetExplosed(status: boolean);
begin
  self._is_weapon_explosed:=status;
end;

procedure WpnBuf.SetLockTime(time: cardinal);
begin
  self._lock_remain_time:=time;
end;

procedure WpnBuf.SetReloadAmmoCnt(cnt: integer);
begin
  self._ammo_count_for_reload:=cnt;
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
  if IsActionProcessing(wpn) or (GetCurrentState(wpn)<>0) then
    result:=false
  else
    result:=true;
end;

function CanAimNow(wpn:pointer):boolean;stdcall;
begin
  if IsActionProcessing(wpn) or IsHolderInSprintState(wpn) or IsHolderHasActiveDetector(wpn) then
    result:=false
  else
    result:=true;
end;

function OnShoot_CanShootNow(wpn:pointer):boolean;stdcall;
var anm_name:string;
  hud_sect:PChar;
  act:pointer;
begin
  if IsActionProcessing(wpn) then
    result:=false
  else begin
    result:=true;
    if IsHolderInSprintState(wpn) then begin
      hud_sect:=GetHUDSection(wpn);
      act:=GetActor();
      anm_name:=ModifierStd(wpn, 'anm_idle_sprint_end');
      MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_'+anm_name), true);
            
      if (act<>nil) and (act = GetOwner(wpn)) then begin
        PlayHudAnim(wpn, PChar(anm_name), true);
        MagazinedWpnPlaySnd(wpn, 'sndSprintEnd');
        SetActorActionState(act, actModSprintStarted, false);
      end;
    end;
  end;
end;

function CanStartAction(wpn:pointer; allow_aim_state:boolean=false):boolean;stdcall;
begin
  if (GetBuffer(wpn)=nil) or IsActionProcessing(wpn) or (GetCurrentState(wpn)<>0) or ( (not allow_aim_state) and (IsHolderInAimState(wpn) or IsAimNow(wpn)) ) or IsHolderInSprintState(wpn) then
    result:=false
  else
    result:=true;
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
var
  buf:WpnBuf;
begin
  result:=false;
{  if not CanStartAction(wpn) then exit;
  buf:=GetBuffer(wpn);
  if not IsWeaponJammed(wpn) then result:=true;}
end;



end.
