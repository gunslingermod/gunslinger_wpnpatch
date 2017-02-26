unit LightUtils;

interface

uses MatVectors;

type torchlight_params = packed record
  render:pointer;
  omni:pointer;
  glow:pointer;
  enabled:boolean;
  light_bone:PChar;
  light_cone_bones:PChar;
  lightdir_bone_name:PChar;   //для реализации вычисления направления работы фонарика через разность векторов позиций данной и кости и light_bone
  is_lightdir_by_bone:boolean;
  offset:FVector3;
  world_offset:FVector3;
  color:Fvector4;
  omni_color:FVector4;
end;
type ptorchlight_params = ^torchlight_params;

function Init():boolean;
function light__create():pointer;stdcall;
function glow__create():pointer;stdcall;
procedure light__destroy(light:pointer);stdcall;
procedure glow__destroy(glow:pointer);stdcall;
procedure light__set_type(light:pointer; ltype:cardinal);stdcall;
procedure light__set_shadow(light:pointer; status:boolean);stdcall;
procedure light__set_enabled(light:pointer; state:boolean); stdcall;
procedure glow__set_enabled(glow:pointer; state:boolean); stdcall;
procedure light__set_direction(light:pointer; dir,right:pFVector3); stdcall;
procedure light__set_position(light:pointer; pos:pFVector3); stdcall;
procedure light__set_color(light:pointer; color:pFVector4); stdcall;
procedure glow__set_position(glow:pointer; pos:pFVector3); stdcall;
procedure glow__set_direction(glow:pointer; pos:pFVector3); stdcall;

procedure glow__set_color(glow:pointer; color:pFVector4); stdcall;
procedure glow__set_texture(glow:pointer; t:pChar); stdcall;
procedure glow__set_radius(glow:pointer; radius:single); stdcall;
procedure light__set_range(light:pointer; range:single); stdcall;
procedure light__set_cone(light:pointer; angle:single); stdcall;
procedure light__set_texture(light:pointer; t:pChar); stdcall;

procedure NewTorchlight(_torch_params:ptorchlight_params; params_section:PChar);
procedure DelTorchlight(_torch_params:ptorchlight_params);
procedure SwitchTorchlight(_torch_params:ptorchlight_params; status:boolean);
procedure SetTorchlightPosAndDir(_torch_params:ptorchlight_params; pos:pFVector3; dir:pFVector3);

const
  IRender_Light__DIRECT:cardinal = 0;
  IRender_Light__POINT:cardinal = 1;
  IRender_Light__SPOT:cardinal = 2;
  IRender_Light__OMNIPART:cardinal = 3;
  IRender_Light__REFLECTED:cardinal = 4;  


implementation
uses BaseGameData, gunsl_config;

var
  xrAPI_Render_ptr:cardinal;


function light__create():pointer;stdcall;
asm
  pushad
  mov eax, xrgame_addr
  add eax, $5124a8
  mov eax, [eax]
  mov ecx, [eax]
  mov edx, [ecx]
  mov eax, [edx+$7c]
  call eax
  mov @result, eax
  cmp eax, 0
  je @finish
  add dword ptr[eax+4], 02
  @finish:
  mov ebx, xrengine_addr
  add ebx, $14060
  lea ecx, @result
  call ebx
  popad
end;

function glow__create():pointer;stdcall;
asm
  pushad
  mov eax, xrgame_addr
  add eax, $5124a8
  mov eax, [eax]
  mov ecx, [eax]
  mov edx, [ecx]
  mov eax, [edx+$84]
  call eax
  mov @result, eax
  cmp eax, 0
  je @finish
  add dword ptr[eax+4], 02
  @finish:
  mov ebx, xrengine_addr
  add ebx, $14060
  lea ecx, @result
  call ebx
  popad
end;

procedure light__destroy(light:pointer);stdcall;
asm
  pushad
  lea ecx, light
  mov eax, xrengine_addr
  add eax, $13150
  call eax
  popad
end;

procedure glow__destroy(glow:pointer);stdcall;
asm
  pushad
  lea ecx, glow
  mov eax, xrengine_addr
  add eax, $132B0
  call eax
  popad
end;

procedure light__set_type(light:pointer; ltype:cardinal);stdcall;
asm
  pushad
  mov ecx, light
  mov edx, [ecx]
  mov eax, [edx]
  push ltype
  call eax
  popad
end;

procedure light__set_shadow(light:pointer; status:boolean);stdcall;
asm
  pushad
  mov ecx, light
  mov edx, [ecx]
  mov eax, [edx+$0C]
  movzx ebx, status
  push ebx
  call eax
  popad
end;

procedure light__set_enabled(light:pointer; state:boolean); stdcall;
asm
    pushad

    movzx eax, state
    push eax

    mov ecx, light
    mov edx, [ecx]
    mov eax, [edx+4]
    call eax

    popad
end;

procedure glow__set_enabled(glow:pointer; state:boolean); stdcall;
asm
    pushad

    movzx eax, state
    push eax

    mov ecx, glow
    mov edx, [ecx]
    mov eax, [edx]
    call eax

    popad
end;



procedure light__set_position(light:pointer; pos:pFVector3); stdcall;
asm
    pushad

    push pos
    mov ecx, light
    mov eax, [ecx]
    mov eax, [eax+$24]
    call eax

    popad
end;

procedure light__set_direction(light:pointer; dir,right:pFVector3); stdcall;
asm
    pushad

    push right
    push dir
    mov ecx, light
    mov eax, [ecx]
    mov eax, [eax+$28]
    call eax

    popad
end;


procedure glow__set_position(glow:pointer; pos:pFVector3); stdcall;
asm
    pushad

    push pos
    mov ecx, glow
    mov eax, [ecx]
    mov eax, [eax+$8]
    call eax

    popad
end;

procedure glow__set_direction(glow:pointer; pos:pFVector3); stdcall;
asm
    pushad

    push pos
    mov ecx, glow
    mov eax, [ecx]
    mov eax, [eax+$C]
    call eax

    popad
end;




procedure light__set_color(light:pointer; color:pFVector4); stdcall;
asm
  pushad
  mov ecx, light
  mov edx, [ecx]
  mov edx, [edx+$40]
  push color
  call edx
  popad
end;

procedure glow__set_color(glow:pointer; color:pFVector4); stdcall;
asm
  pushad
  mov ecx, glow
  mov edx, [ecx]
  mov edx, [edx+$1C]
  push color
  call edx
  popad
end;

procedure glow__set_texture(glow:pointer; t:pChar); stdcall;
asm
  pushad
  mov ecx, glow
  mov edx, [ecx]
  mov edx, [edx+$14]
  push t
  call edx
  popad
end;


procedure glow__set_radius(glow:pointer; radius:single); stdcall;
asm
  pushad
  mov ecx, glow
  mov edx, [ecx]
  mov edx, [edx+$10]
  push radius
  call edx
  popad
end;

procedure light__set_range(light:pointer; range:single); stdcall;
asm
  pushad
  mov ecx, light
  mov edx, [ecx]
  mov edx, [edx+$30]
  push range
  call edx
  popad
end;


procedure light__set_cone(light:pointer; angle:single); stdcall;
asm
  pushad
  mov ecx, light
  mov edx, [ecx]
  mov edx, [edx+$2C]
  push angle
  call edx
  popad
end;

procedure light__set_texture(light:pointer; t:pChar); stdcall;
asm
  pushad
  mov ecx, light
  mov edx, [ecx]
  mov edx, [edx+$38]
  push t
  call edx
  popad
end;

procedure NewTorchlight(_torch_params:ptorchlight_params; params_section:PChar);
begin
  _torch_params.render:=light__create();
  _torch_params.omni:=light__create();
  _torch_params.glow:=glow__create();
  light__set_type(_torch_params.render, IRender_Light__SPOT);
  light__set_type(_torch_params.omni, IRender_Light__POINT);
  light__set_shadow(_torch_params.render, true);
  light__set_shadow(_torch_params.omni, false);

  _torch_params.light_bone:=game_ini_read_string(params_section, 'torch_light_bone');
  _torch_params.light_cone_bones:=game_ini_read_string(params_section, 'torch_cone_bones');

  _torch_params.offset.x:=game_ini_r_single_def(params_section, 'torch_attach_offset_x', 0.0);
  _torch_params.offset.y:=game_ini_r_single_def(params_section, 'torch_attach_offset_y', 0.0);
  _torch_params.offset.z:=game_ini_r_single_def(params_section, 'torch_attach_offset_z', 0.0);

  _torch_params.world_offset.x:=game_ini_r_single_def(params_section, 'torch_world_attach_offset_x', 0.0);
  _torch_params.world_offset.y:=game_ini_r_single_def(params_section, 'torch_world_attach_offset_y', 0.0);
  _torch_params.world_offset.z:=game_ini_r_single_def(params_section, 'torch_world_attach_offset_z', 0.0);

  if (xrRender_R1_addr>0) then begin
    _torch_params.color.x:=game_ini_r_single_def(params_section, 'torch_color_r', 1.0);
    _torch_params.color.y:=game_ini_r_single_def(params_section, 'torch_color_g', 1.0);
    _torch_params.color.z:=game_ini_r_single_def(params_section, 'torch_color_b', 1.0);
    _torch_params.color.w:=game_ini_r_single_def(params_section, 'torch_color_a', 0.2);

    _torch_params.omni_color.x:=game_ini_r_single_def(params_section, 'torch_omni_color_r', 1.0);
    _torch_params.omni_color.y:=game_ini_r_single_def(params_section, 'torch_omni_color_g', 1.0);
    _torch_params.omni_color.z:=game_ini_r_single_def(params_section, 'torch_omni_color_b', 1.0);
    _torch_params.omni_color.w:=game_ini_r_single_def(params_section, 'torch_omni_color_a', 0.1);

    light__set_range(_torch_params.render, game_ini_r_single_def(params_section, 'torch_range', 15));
    light__set_range(_torch_params.omni, game_ini_r_single_def(params_section, 'torch_omni_range', 1.5));
  end else begin
    _torch_params.color.x:=game_ini_r_single_def(params_section, 'torch_r2_color_r', 0.6);
    _torch_params.color.y:=game_ini_r_single_def(params_section, 'torch_r2_color_g', 0.55);
    _torch_params.color.z:=game_ini_r_single_def(params_section, 'torch_r2_color_b', 0.55);
    _torch_params.color.w:=game_ini_r_single_def(params_section, 'torch_r2_color_a', 0.8);

    _torch_params.omni_color.x:=game_ini_r_single_def(params_section, 'torch_r2_omni_color_r', 1.0);
    _torch_params.omni_color.y:=game_ini_r_single_def(params_section, 'torch_r2_omni_color_g', 1.0);
    _torch_params.omni_color.z:=game_ini_r_single_def(params_section, 'torch_r2_omni_color_b', 1.0);
    _torch_params.omni_color.w:=game_ini_r_single_def(params_section, 'torch_r2_omni_color_a', 0.1);

    light__set_range(_torch_params.render, game_ini_r_single_def(params_section, 'torch_r2_range', 15));
    light__set_range(_torch_params.omni, game_ini_r_single_def(params_section, 'torch_r2_omni_range', 0.75));
  end;
  glow__set_color(_torch_params.glow, @_torch_params.color);
  light__set_color (_torch_params.render, @_torch_params.color);
  light__set_color (_torch_params.omni, @_torch_params.omni_color);

  glow__set_texture(_torch_params.glow, game_ini_read_string(params_section, 'torch_glow_texture'));
  glow__set_radius(_torch_params.glow, game_ini_r_single_def(params_section, 'torch_glow_radius', 0.3));
  light__set_cone(_torch_params.render, game_ini_r_single_def(params_section, 'torch_spot_angle', 75)*PI/180);
  light__set_texture(_torch_params.render, game_ini_read_string(params_section, 'torch_spot_texture'));

  _torch_params.is_lightdir_by_bone := game_ini_r_bool_def(params_section, 'light_directions_by_bones', false);
  if _torch_params.is_lightdir_by_bone then begin
    _torch_params.lightdir_bone_name:=game_ini_read_string(params_section, 'light_dir_bone');
  end;
end;

procedure DelTorchlight(_torch_params:ptorchlight_params);
begin
    light__destroy(_torch_params.render);
    light__destroy(_torch_params.omni);
    glow__destroy(_torch_params.glow);

    _torch_params.render:=nil;
    _torch_params.omni:=nil;
    _torch_params.glow:=nil;
end;
procedure SwitchTorchlight(_torch_params:ptorchlight_params; status:boolean);
begin
  light__set_enabled(_torch_params.render, status);
  light__set_enabled(_torch_params.omni, status);
  glow__set_enabled(_torch_params.glow, status);
  _torch_params.enabled:=status;
end;

procedure SetTorchlightPosAndDir(_torch_params:ptorchlight_params; pos:pFVector3; dir:pFVector3);
var
  up, right:FVector3;
begin
  generate_orthonormal_basis_normalized(dir, @up, @right);
  light__set_position(_torch_params.render, pos);
  light__set_direction(_torch_params.render, dir, @right);
  light__set_position(_torch_params.omni, pos);
  light__set_direction(_torch_params.omni, dir, @right);
  glow__set_position(_torch_params.glow, pos);
  glow__set_direction(_torch_params.glow, dir);
end;


function Init():boolean;
begin
  xrAPI_Render_ptr:=xrGame_addr+$5124A8;
  result:=true;
end;

end.
