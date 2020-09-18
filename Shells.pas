unit Shells;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface
uses MatVectors;

type TShell = record
  id:cardinal;
  wpn_id:cardinal;
  need_impulse:boolean;
  impulse_dir:FVector3;
  spawn_time:cardinal;
end;

type TShellMgr = class
  private
  _shells:array of TShell;
  _shells_max_cnt:cardinal;
  constructor _Create;
  destructor _Destroy;
  public
  class procedure New;
  class function Get():TShellMgr;
  procedure AddShell(id:cardinal; wpn_id:cardinal; imp_dir:FVector3);
  procedure Update;
end;

function Init():boolean;

implementation
uses BaseGameData;
var
  _instance:TShellMgr;



{ TShellMgr }

constructor TShellMgr._Create;
begin
  SetLength(_shells, 0);
  _shells_max_cnt:=100;
end;

destructor TShellMgr._Destroy;
begin
  SetLength(_shells, 0);
  _instance:=nil;
end;

procedure TShellMgr.AddShell(id, wpn_id: cardinal; imp_dir: FVector3);
begin

end;

class function TShellMgr.Get: TShellMgr;
begin
  result:=_instance;
end;

class procedure TShellMgr.New;
begin
  if _instance=nil then _instance:=TShellMgr.Create;
end;

procedure TShellMgr.Update;
begin

end;

function Init():boolean;
begin
  _instance:=nil;
end;

end.
