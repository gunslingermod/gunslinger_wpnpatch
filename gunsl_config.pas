unit gunsl_config;

interface
uses MatVectors;

type weapon_inertion_params = record
  pitch_offset_r:single;
  pitch_offset_n:single;
  pitch_offset_d:single;
  origin_offset:single;
  speed:single;
end;

function Init:boolean;
function GetStdInertion(aim:boolean):weapon_inertion_params;

const
  gd_novice:cardinal=0;
  gd_stalker:cardinal=1;
  gd_veteran:cardinal=2;
  gd_master:cardinal=3;


//------------------------------Общие функции работы с игровыми конфигами---------------------------------
  function game_ini_read_string_by_object_string(section:pointer; key:PChar):PChar;stdcall;
  function game_ini_read_string(section:PChar; key:PChar):PChar;stdcall;
  function game_ini_read_vector3_def(section:PChar; key:PChar; def:pfvector3):FVector3;stdcall;
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

function IsMoveCamAnmsEnabled():boolean; stdcall;

implementation
uses BaseGameData, sysutils, ConsoleUtils;

var
  std_inertion:weapon_inertion_params;
  aim_inertion:weapon_inertion_params;
  fov:single;
  hud_fov:single;

  hud_move_cam_anms_enabled:boolean;

  def_zoom_dof:FVector3;
  def_act_dof:FVector3;
  dof_def_speed:single;
  dof_def_speed_in:single;
  dof_def_speed_out:single;
  dof_def_timeoffset:single;

//данные консольных команд
//булевские флаги
  _console_bool_flags:cardinal;



//Сами консольные команды
  CCC_dyndof:CCC_Mask;
  CCC_constzoomdof:CCC_Mask;
  CCC_laserdotdistcorrection:CCC_Mask;
  CCC_npclasers:CCC_Mask;
  CCC_realballistics:CCC_Mask;

//маски для флагов
const
  _mask_dyndof:cardinal=$1;
  _mask_constzoomdof:cardinal=$2;
  _mask_laserdotcorrection:cardinal=$4;
  _mask_npclasers:cardinal=$8;
  _mask_realballistics:cardinal=$10;

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


function game_ini_read_vector3_def(section:PChar; key:PChar; def:pfvector3):FVector3;stdcall;
var
  tmp, coord:string;
  i:integer;
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


function GetCurrentDifficulty():cardinal; stdcall;
asm
  mov eax, xrgame_addr
  mov eax, [eax+$63bc54]
  mov @result, eax
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

function IsMoveCamAnmsEnabled():boolean; stdcall;
begin
  result:=hud_move_cam_anms_enabled;
end;


function Init:boolean;
const
  GUNSL_BASE_SECTION:PChar='gunslinger_base';
begin
  result:=false;
  _console_bool_flags:=0;
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

//-----------------------------------------------------------------------------------------------------------------
  fov:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'fov', 65);
  hud_fov:=game_ini_r_single_def(GUNSL_BASE_SECTION, 'hud_fov', 30);

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


  hud_move_cam_anms_enabled:=game_ini_r_bool_def(GUNSL_BASE_SECTION, 'enable_move_cam_anms', false);
  result:=true;
end;

function GetStdInertion(aim:boolean):weapon_inertion_params;
begin
  if aim then result:=aim_inertion else result:=std_inertion;
end;

end.
