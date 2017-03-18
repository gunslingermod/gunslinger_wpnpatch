unit xr_keybinding;

{//$define DISABLE_UNUSED_COMMANDS}

interface

function Init():boolean; stdcall;

//новые действия добавлять в procedure fill_actions_list(), остальное автоматом

type _action = packed record
  action_name:PChar;
  id:cardinal;
  key_group:cardinal;
end;
type paction = ^_action;

type _binding = packed record
  action:paction;
  key1:cardinal;
  key2:cardinal;
end;

const
  _keygroup_both:cardinal=1;
  _keygroup_sp:cardinal=3;
  _keygroup_mp:cardinal=5;

implementation
uses BaseGameData, KeyUtils, sysutils, windows, gunsl_config;
const
  _max_actions_size:cardinal=100;
  _max_keybinding_size:cardinal=100;
var
  _arr:array [0..99] of _action;
  _keybindings:array[0..99] of _binding;
  _actions_count:integer;
  _max_id:integer;

function _add_action(name:PChar; id:cardinal; key_group:cardinal):boolean; stdcall;
begin
  result:=false;
  if _actions_count>=_max_actions_size then begin
    log ('keybinding._add_action: Cannot add action - overflow; increase bind_size value and size of _arr!', true);
    exit;
  end else if id>=_max_keybinding_size then begin
    log ('keybinding._add_action: Cannot add action with id='+inttostr(id)+', increase _max_keybinding_size value and size of _keybindings!', true);
    exit;
  end;
  if id>_max_id then _max_id:=id;

  _arr[_actions_count].action_name:=name;
  _arr[_actions_count].id:=id;
  _arr[_actions_count].key_group:=key_group;

  _actions_count:=_actions_count+1;
  result:=true;
end;

procedure _finalize_keybindings();
begin
//  log ('finalizing... (max id='+inttostr(_max_id)+')');
  _add_action(nil, _max_id+1, _keygroup_both);
end;

procedure fill_actions_list();
begin
  _add_action('left', kLEFT, _keygroup_both);
  _add_action('right', kRIGHT, _keygroup_both);
  _add_action('up', kUP, _keygroup_both);
  _add_action('down', kDOWN, _keygroup_both);
  _add_action('jump', kJUMP, _keygroup_both);
  _add_action('crouch', kCROUCH, _keygroup_both);
  _add_action('accel', kACCEL, _keygroup_both);
  _add_action('sprint_toggle', kSPRINT_TOGGLE, _keygroup_both);

  _add_action('forward', kFWD, _keygroup_both);
  _add_action('back', kBACK, _keygroup_both);
  _add_action('lstrafe', kL_STRAFE, _keygroup_both);
  _add_action('rstrafe', kR_STRAFE, _keygroup_both);

  _add_action('llookout', kL_LOOKOUT, _keygroup_both);
  _add_action('rlookout', kR_LOOKOUT, _keygroup_both);

{$ifndef DISABLE_UNUSED_COMMANDS}
  _add_action('cam_1', kCAM_1, _keygroup_both);
  _add_action('cam_2', kCAM_2, _keygroup_both);
  _add_action('cam_3', kCAM_3, _keygroup_both);
{$endif}

  _add_action('cam_zoom_in', kCAM_ZOOM_IN, _keygroup_both);
  _add_action('cam_zoom_out', kCAM_ZOOM_OUT, _keygroup_both);

  _add_action('torch', kTORCH, _keygroup_both);
  _add_action('night_vision', kNIGHT_VISION, _keygroup_both);
  _add_action('show_detector', kDETECTOR, _keygroup_sp);

  _add_action('wpn_1', kWPN_1, _keygroup_both);
  _add_action('wpn_2', kWPN_2, _keygroup_both);
  _add_action('wpn_3', kWPN_3, _keygroup_both);
  _add_action('wpn_4', kWPN_4, _keygroup_both);
  _add_action('wpn_5', kWPN_5, _keygroup_both);
  _add_action('wpn_6', kWPN_6, _keygroup_both);
{$ifndef DISABLE_UNUSED_COMMANDS}
  _add_action('artefact', kARTEFACT, _keygroup_both);
{$endif}
  _add_action('wpn_next', kWPN_NEXT, _keygroup_both);
  _add_action('wpn_fire', kWPN_FIRE, _keygroup_both);
  _add_action('wpn_zoom', kWPN_ZOOM, _keygroup_both);

  _add_action('wpn_zoom_inc', kWPN_ZOOM_INC, _keygroup_both);
  _add_action('wpn_zoom_dec', kWPN_ZOOM_DEC, _keygroup_both);
  _add_action('wpn_reload', kWPN_RELOAD, _keygroup_both);
  _add_action('wpn_func', kWPN_FUNC, _keygroup_both);
  _add_action('wpn_firemode_prev', kWPN_FIREMODE_PREV, _keygroup_both);
  _add_action('wpn_firemode_next', kWPN_FIREMODE_NEXT, _keygroup_both);


  _add_action('pause', kPAUSE, _keygroup_both);
  _add_action('drop', kDROP, _keygroup_both);
  _add_action('use', kUSE, _keygroup_both);
  _add_action('scores', kSCORES, _keygroup_both);
{$ifndef DISABLE_UNUSED_COMMANDS}  
  _add_action('chat', kCHAT, _keygroup_mp);
  _add_action('chat_team', kCHAT_TEAM, _keygroup_mp);
{$endif}
  _add_action('screenshot', kSCREENSHOT, _keygroup_both);
  _add_action('quit', kQUIT, _keygroup_both);
  _add_action('console', kCONSOLE, _keygroup_both);
  _add_action('inventory', kINVENTORY, _keygroup_both);
{$ifndef DISABLE_UNUSED_COMMANDS}
  _add_action('buy_menu', kBUY, _keygroup_mp);
  _add_action('skin_menu', kSKIN, _keygroup_mp);
  _add_action('team_menu', kTEAM, _keygroup_mp);
{$endif}  
  _add_action('active_jobs', kACTIVE_JOBS, _keygroup_sp); //PDA


{$ifndef DISABLE_UNUSED_COMMANDS}
  _add_action('vote_begin', kVOTE_BEGIN, _keygroup_mp);
  _add_action('show_admin_menu', kADMIN, _keygroup_mp);
  _add_action('vote', kVOTE, _keygroup_mp);
  _add_action('vote_yes', kVOTEYES, _keygroup_mp);
  _add_action('vote_no', kVOTENO, _keygroup_mp);
{$endif}  

  _add_action('next_slot', kNEXT_SLOT, _keygroup_both);
  _add_action('prev_slot', kPREV_SLOT, _keygroup_both);

{$ifndef DISABLE_UNUSED_COMMANDS}
  _add_action('speech_menu_0', kSPEECH_MENU_0, _keygroup_mp);
  _add_action('speech_menu_1', kSPEECH_MENU_1, _keygroup_mp);
{$endif}

  _add_action('quick_use_1', kQUICK_USE_1, _keygroup_both);
  _add_action('quick_use_2', kQUICK_USE_2, _keygroup_both);
  _add_action('quick_use_3', kQUICK_USE_3, _keygroup_both);
  _add_action('quick_use_4', kQUICK_USE_4, _keygroup_both);

  _add_action('quick_save', kQUICK_SAVE, _keygroup_sp);
  _add_action('quick_load', kQUICK_LOAD, _keygroup_sp);

  _add_action('wpn_laser', kLASER, _keygroup_both);
  _add_action('wpn_torch', kTACTICALTORCH, _keygroup_both);
  _add_action('quick_grenade', kQUICK_GRENADE, _keygroup_both);

  _add_action('wpn_zoom_alter', kWPN_ZOOM_ALTER, _keygroup_both);
  _add_action('quick_kick', kQUICK_KICK, _keygroup_both);
  _add_action('scope_brightness_plus', kBRIGHTNESS_PLUS, _keygroup_both);
  _add_action('scope_brightness_minus', kBRIGHTNESS_MINUS, _keygroup_both);

//  _add_action('alife_command', kALIFE_CMD, _keygroup_sp); //восстанавливаем ЧНовское

//  _add_action('not_binded', $45, _keygroup_sp);

end;

function find_action_by_id(id:cardinal):paction; stdcall;
var
  i:integer;
begin
  for i:=0 to _actions_count-1 do begin
    if _arr[i].id=id then begin
      result:=@_arr[i];
      exit;
    end;
  end;
  result:=@_arr[_max_id-1];
end;

procedure initialize_bindings_fixed(); stdcall;
var
  i:integer;
  res:paction;
begin
  for i:=0 to _max_id-1 do begin
    res:=find_action_by_id(i);
//    log ('for id='+inttostr(i)+' found index '+inttohex(cardinal(res),8));
    _keybindings[i].action:=res;
  end;
end;

procedure initialize_bindings_bugfix_Patch(); stdcall;
asm
  pushad
  call initialize_bindings_fixed
  popad
  ret
end;


function Init():boolean; stdcall;
var
  c_addr, rb:cardinal;
  a_addr:pointer;
  tmp:cardinal;
begin
  result:=false;
  _actions_count:=0;
  _max_id:=-1;

  //для гарантии
  for tmp:=0 to _max_keybinding_size-1 do begin
    _keybindings[tmp].action:=nil;
    _keybindings[tmp].key1:=0;
    _keybindings[tmp].key2:=0;
  end;

  fill_actions_list();
  _finalize_keybindings();
//  _add_action('test1', $43, _keygroup_sp);  
//  _add_action(nil, kLASTACTION, _keygroup_both);


//  log(inttohex(cardinal(@_arr[0]),8));

  // xrgame.dll+6345f8 - здесь начинается оригинальный массив действий
  //меняем его во всем коде на наш


  a_addr:=@_arr[0];
//  log(inttohex(cardinal(a_addr),8));
  c_addr:=xrgame_addr+$25ba3a;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

  c_addr:=xrgame_addr+$25ba48;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

  c_addr:=xrgame_addr+$25ba66;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

  c_addr:=xrgame_addr+$25ba6E;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

  c_addr:=xrgame_addr+$25ba91;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

// тут (initialize_bindings) баг в оригинале - правим ниже
//  c_addr:=xrgame_addr+$25bdc2;
//  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
//  if rb<>4 then exit;
  
  //перенаправим бинды

  //патчим bool is_binded(EGameActions _action_id, int _dik);
  a_addr:=@_keybindings[0];
  c_addr:=xrgame_addr+$25bba7;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

  a_addr:=@_keybindings[0];
  a_addr:=PChar(a_addr)+4;
  c_addr:=xrgame_addr+$25bb9e;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

  //патчим int get_action_dik(EGameActions _action_id, int idx)
  a_addr:=@_keybindings[0];
  c_addr:=xrgame_addr+$25bbe1;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

  //патчим CCC_Bind::Save
  a_addr:=@_keybindings[0];
  c_addr:=xrgame_addr+$25bc92;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

  a_addr:=@_keybindings[0];
  a_addr:=PChar(a_addr)+(_max_id)*12;
  c_addr:=xrgame_addr+$25bccc;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

  //патчим CCC_ListActions::Execute
  a_addr:=@_keybindings[0];
  c_addr:=xrgame_addr+$25bcfa;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

  a_addr:=@_keybindings[0];
  a_addr:=PChar(a_addr)+(_max_id)*12;
  c_addr:=xrgame_addr+$25bd14;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

  //патчим (inline) initialize_bindings в void CCC_RegisterInput
  //строка g_key_bindings[idx].m_action = &actions[idx] багоопасна - если id action'a не совпадает с его индексом в actions (а так оно в оригинале и есть - там "окно" из-за вырезанной команды kALIFE_CMD)  - будет плохо.
  //перепишем всю функцию.
  c_addr:=xrgame_addr+$25bdc0;
  if not WriteJump(c_addr, cardinal(@initialize_bindings_bugfix_Patch), 22, true) then exit;

//  a_addr:=@_keybindings[0];
//  c_addr:=xrgame_addr+$25bdc8;
//  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
//  if rb<>4 then exit;

//  tmp:=(_max_id)*12;
//  c_addr:=xrgame_addr+$25bdd0;
//  writeprocessmemory(hndl, PChar(c_addr), @tmp, 4, rb);
//  if rb<>4 then exit;

  //патчим GetActionAllBinding
  a_addr:=@_keybindings[0];
  c_addr:=xrgame_addr+$25c141;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

  a_addr:=@_keybindings[0];
  a_addr:=PChar(a_addr)+4;
  c_addr:=xrgame_addr+$25c138;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

  //патчим CCC_Bind::Execute
  a_addr:=@_keybindings[0];
  c_addr:=xrgame_addr+$25c957;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

  a_addr:=@_keybindings[0];
  a_addr:=PChar(a_addr)+8;
  c_addr:=xrgame_addr+$25c960;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;  

  a_addr:=@_keybindings[0];
  a_addr:=PChar(a_addr)+(_max_id)*12+8;
  c_addr:=xrgame_addr+$25c9a0;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

  //патчим EGameActions get_binded_action (int _dik);
  a_addr:=@_keybindings[0];
  a_addr:=PChar(a_addr)+8;
  c_addr:=xrgame_addr+$25bc1c;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

  a_addr:=@_keybindings[0];
  a_addr:=PChar(a_addr)+(_max_id)*12+8;
  c_addr:=xrgame_addr+$25bc4f;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;


  //патчим CCC_BindList::Execute
  a_addr:=@_keybindings[0];
  a_addr:=PChar(a_addr)+4;
  c_addr:=xrgame_addr+$25c2c9;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

  a_addr:=@_keybindings[0];
  a_addr:=PChar(a_addr)+(_max_id)*12+4;
  c_addr:=xrgame_addr+$25c32f;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;


  //патчим ???
  a_addr:=@_keybindings[0];
  a_addr:=PChar(a_addr)+8;
  c_addr:=xrgame_addr+$25ca82;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

  a_addr:=@_keybindings[0];
  a_addr:=PChar(a_addr)+(_max_id)*12+8;
  c_addr:=xrgame_addr+$25ca91;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

  //патчим CCC_Unbind::Execute
  a_addr:=@_keybindings[0];
  a_addr:=PChar(a_addr)+4;
  c_addr:=xrgame_addr+$25bd97;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

  //патчим ???
  a_addr:=@_keybindings[0];
  a_addr:=PChar(a_addr)+4;
  c_addr:=xrgame_addr+$463cf0;
  writeprocessmemory(hndl, PChar(c_addr), @a_addr, 4, rb);
  if rb<>4 then exit;

  result:=true;
end;



end.
