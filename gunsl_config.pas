unit gunsl_config;

interface
function Init:boolean;

const
  gd_novice:cardinal=0;
  gd_stalker:cardinal=1;
  gd_veteran:cardinal=2;
  gd_master:cardinal=3;


//------------------------------Общие функции работы с игровыми конфигами---------------------------------
  function game_ini_read_string_by_object_string(section:pointer; key:PChar):PChar;stdcall;
  function game_ini_read_string(section:PChar; key:PChar):PChar;stdcall;
  function game_ini_line_exist(section:PChar; key:PChar):boolean;stdcall;
  function game_ini_r_single_def(section:PChar; key:PChar; def:single):single;stdcall;
  function game_ini_r_single(section:PChar; key:PChar):single;stdcall;
  function game_ini_r_bool(section:PChar; key:PChar):boolean;stdcall;
  function game_ini_r_bool_def(section:PChar; key:PChar; def:boolean):boolean;stdcall;
  function game_ini_r_int_def(section:PChar; key:PChar; def:integer):integer; stdcall;
  function translate(text:PChar):PChar;stdcall;    


//---------------------------специфические функции конфигурации ганса--------------------------------------
function IsSprintOnHoldEnabled():boolean; stdcall;
function IsDebug():boolean; stdcall;
function GetBaseFOV():single; stdcall;
function GetBaseHudFOV():single; stdcall;
function GetLaserPointDrawingDistance(viewdistance:single):single; stdcall;
function GetCurrentDifficulty():cardinal; stdcall;


implementation
uses BaseGameData, sysutils;

var
  fov:single;
  hud_fov:single;

  laser_hide_dist:single; //дальше этой дистанции луч лазера будет скрываться
  laser_max_dist:single;  //максимальное расстояние, на котором рисуется точка
  laser_min_dist:single; //ближе этого значения луч будет выставлен на laser_min_override
  laser_min_dist_override:single; //если точка получается дальше, чем laser_max_dist, то рисоваться будет на этой
  laser_max_dist_override:single;

//--------------------------------------------------Общие вещи---------------------------------------------------
function GetGameIni():pointer;stdcall;
asm
  mov eax, xrgame_addr
  mov eax, [eax+$5127E8]
  mov eax, [eax]
  mov @result, eax
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

function game_ini_r_bool(section:PChar; key:PChar):boolean;stdcall;
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

function game_ini_read_string(section:PChar; key:PChar):PChar;stdcall;
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

function game_ini_r_bool_def(section:PChar; key:PChar; def:boolean):boolean;stdcall;
begin
  if game_ini_line_exist(section, key) then
    result:=game_ini_r_bool(section, key)
  else
    result:=def;
end;

function game_ini_r_int_def(section:PChar; key:PChar; def:integer):integer; stdcall;
begin
  if game_ini_line_exist(section, key) then
    result:=strtointdef(game_ini_read_string(section, key), def)
  else
    result:=def;
end;

function game_ini_r_single(section:PChar; key:PChar):single;stdcall;
begin
  result:= strtofloatdef(game_ini_read_string(section, key),0);
end;


function game_ini_r_single_def(section:PChar; key:PChar; def:single):single;stdcall;
begin
  if game_ini_line_exist(section, key) then
    result:=game_ini_r_single(section, key)
  else
    result:=def;
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

function GetCurrentDifficulty():cardinal; stdcall;
asm
  mov eax, xrgame_addr
  mov eax, [eax+$63bc54]
  mov @result, eax
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
end.
