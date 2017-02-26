unit gunsl_config;

interface
function Init:boolean;

const
  gd_novice:cardinal=0;
  gd_stalker:cardinal=1;
  gd_veteran:cardinal=2;
  gd_master:cardinal=3;

function IsSprintOnHoldEnabled():boolean; stdcall;
function IsDebug():boolean; stdcall;
function GetBaseFOV():single; stdcall;
function GetBaseHudFOV():single; stdcall;
function GetLaserPointDrawingDistance(viewdistance:single):single; stdcall;
function GetCurrentDifficulty():cardinal; stdcall;


implementation
uses GameWrappers, BaseGameData;

var
  fov:single;
  hud_fov:single;

  laser_hide_dist:single; //дальше этой дистанции луч лазера будет скрываться
  laser_max_dist:single;  //максимальное расстояние, на котором рисуется точка
  laser_min_dist:single; //ближе этого значения луч будет выставлен на laser_min_override
  laser_min_dist_override:single; //если точка получается дальше, чем laser_max_dist, то рисоваться будет на этой
  laser_max_dist_override:single;

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


function GetLaserPointDrawingDistance(viewdistance:single):single; stdcall;
begin
  if viewdistance<laser_min_dist then begin
    result:=laser_min_dist_override;
  end else if viewdistance>laser_hide_dist then begin
    result:=-10;
    exit;
  end else if viewdistance>laser_max_dist then begin
    result:=laser_max_dist_override;
  end else begin
    result:=laser_min_dist_override+((laser_max_dist_override-laser_min_dist_override)/(laser_max_dist-laser_min_dist))*(viewdistance-laser_min_dist);
  end;

end;

function Init:boolean;
begin
  result:=false;
  if game_ini_line_exist('gunslinger_base', 'fov') then begin
    fov:=game_ini_r_single('gunslinger_base', 'fov');
  end else begin
    fov:=65;
  end;

  if game_ini_line_exist('gunslinger_base', 'hud_fov') then begin;
    hud_fov:=game_ini_r_single('gunslinger_base', 'hud_fov');
  end else begin
    hud_fov:=30;
  end;


  if game_ini_line_exist('gunslinger_base', 'laser_min_dist') then begin;
    laser_min_dist:=game_ini_r_single('gunslinger_base', 'laser_min_dist');
  end else begin
    laser_min_dist:=0.7;
  end;

  if game_ini_line_exist('gunslinger_base', 'laser_min_dist_override') then begin;
    laser_min_dist_override:=game_ini_r_single('gunslinger_base', 'laser_min_dist_override');
  end else begin
    laser_min_dist_override:=laser_min_dist;
  end;

  if game_ini_line_exist('gunslinger_base', 'laser_max_dist_override') then begin;
    laser_max_dist_override:=game_ini_r_single('gunslinger_base', 'laser_max_dist_override');
  end else begin
    laser_max_dist_override:=laser_min_dist;
  end;


  if game_ini_line_exist('gunslinger_base', 'laser_max_dist') then begin;
    laser_max_dist:=game_ini_r_single('gunslinger_base', 'laser_max_dist');
  end else begin
    laser_max_dist:=15;
  end;

  if game_ini_line_exist('gunslinger_base', 'laser_max_dist_override') then begin;
    laser_max_dist_override:=game_ini_r_single('gunslinger_base', 'laser_max_dist_override');
  end else begin
    laser_max_dist_override:=laser_max_dist;
  end;


  if game_ini_line_exist('gunslinger_base', 'laser_hide_dist') then begin;
    laser_hide_dist:=game_ini_r_single('gunslinger_base', 'laser_hide_dist');
  end else begin
    laser_hide_dist:=25;
  end;

  result:=true;
end;


function GetCurrentDifficulty():cardinal; stdcall;
asm
  mov eax, xrgame_addr
  mov eax, [eax+$63bc54]
  mov @result, eax
end;
end.
