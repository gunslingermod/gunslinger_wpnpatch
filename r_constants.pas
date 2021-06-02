unit r_constants;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

//добавляет экспорт новых параметров в шейдеры
//смотреть CBlender_Compile__SetMapping, остальное не трогать

interface
function Init():boolean;

implementation
uses BaseGameData, sysutils, ActorUtils, HudItemUtils, dynamic_caster, WeaponAdditionalBuffer, gunsl_config, MatVectors, math, Misc, LensDoubleRender, collimator;
//////////////////////////////////////////////////////////////////
type R_constant = record
//todo:дописать
end;
type pR_constant = ^R_constant;
/////////////////// R_constant_setup//////////////////////////////
type R_constant_setup_vftable  = record
  setup_proc:pointer;
  virtual_destructor:pointer;
end;
type pR_constant_setup_vftable = ^R_constant_setup_vftable;

type R_constant_setup  = record
  vftable:pR_constant_setup_vftable;
  setup_proc_addr:procedure(C:pR_constant); stdcall; //для адреса процедуры setup, в оригинале нет! Нужно для удобства работы
end;
type pR_constant_setup = ^R_constant_setup;

//////////////////////////////////////////////////////////////////////////

const
  eye_direction:PChar = 'eye_direction';

var
  CBlender_Compile__r_Constant_proc_addr:cardinal;
  RCache__set: procedure(C:pR_constant; x,y,z,w:single); stdcall;
  r_constant_vftable:R_constant_setup_vftable;
  binder_cur_zoom_factor:R_constant_setup;
  binder_actor_states:R_constant_setup;
  binder_zoom_deviation:R_constant_setup;
  binder_affects:R_constant_setup;
  binder_timearrow:R_constant_setup;
  binder_timearrow2:R_constant_setup;
  binder_digiclock:R_constant_setup;



//Вызов движком блендера////////////////////////////////////////
// "прокладка" для удобства работы с членом-указателем
procedure R_constant_setup__setup_internal_caller(this:pR_constant_setup; C:pR_constant); stdcall;
begin
  this.setup_proc_addr(C);
end;

//эта процедура вызывается движком
procedure R_constant_setup__setup(); stdcall;
asm
  push ebp
  mov ebp, esp
  pushad
    push [ebp+$8]
    push ecx
    call R_constant_setup__setup_internal_caller
  popad
  pop ebp
  ret 4
end;

////////////////////////////////////////////////////////////////
//процедура регистрации новой константы
procedure CBlender_Compile__r_Constant(this:pointer; name:PChar; addr:pR_constant_setup); stdcall;
asm
    pushad
      push name
      push this
      mov esi, addr
      call  CBlender_Compile__r_Constant_proc_addr
    popad
end;


////////////////////////////////////////////////////////////////////////
//собственно функции заполнения данными наших констант
procedure binder_cur_zoom_factor_setup(C:pR_constant); stdcall;
var
  wpn:pointer;
  val:single;
  abberation:single;
  x,y:cardinal;
  sect:PChar;

  lens_factor:single;
begin
  val:=0;
  wpn:=GetActorActiveItem();
  abberation:=0;
  lens_factor:=0;
  if (wpn<>nil) and (dynamic_cast(wpn, 0, RTTI_CHudItemObject, RTTI_CWeapon, false)<>nil) then begin
    val:=GetAimFactor(wpn);
    abberation:=ModifyFloatUpgradedValue(wpn, 'scope_abberation', game_ini_r_single_def(GetSection(wpn), 'scope_abberation', 0));
    if IsScopeAttached(wpn) then begin
     sect:=game_ini_read_string(GetCurrentScopeSection(wpn), 'scope_name');
      abberation:=game_ini_r_single_def(sect, 'scope_abberation', abberation);
    end;

    lens_factor:=GetZoomLensVisibilityFactor(wpn);
  end;
  GetScreenParams(@x, @y);
  RCache__set(C, y/x,val,abberation,lens_factor);

end;

procedure binder_affects_setup(C:pR_constant); stdcall;
var
  decr:single;
begin
  if IsElectronicsProblemsDecreasing() then decr:=1 else decr := 0;
  RCache__set(C, CurrentElectronicsProblemsCnt()/10, random, TargetElectronicsProblemsCnt()/10, decr);
end;

procedure binder_actor_states_setup(C:pR_constant); stdcall;
var
  act, outfit, wpn:pointer;
  actor_health, actor_weapon_cond, actor_outfit_cond, actor_wpn_loading:single;
  buf:WpnBuf;
  reload_time, now_time:cardinal;
begin
  act:=GetActor();
  if act=nil then begin
    RCache__set(C, -1,-1,-1,-1);
  end;
  outfit:=ItemInSlot(act, 7);
  if (outfit<>nil) then outfit:=dynamic_cast(outfit, 0, RTTI_CInventoryItem, RTTI_CCustomOutfit, false);
  if (outfit<>nil) then begin
    actor_outfit_cond:=GetCurrentCondition(outfit);
  end else begin
    actor_outfit_cond:=-1;
  end;

  wpn:=GetActorActiveItem();
  if wpn<>nil then begin
    actor_weapon_cond:=GetCurrentCondition(wpn);

    buf:=GetBuffer(wpn);
    if buf<>nil then begin
      reload_time:=floor(buf.GetLastRechargeTime() * 1000);
      now_time:= buf.GetLastShotTimeDelta();
      actor_wpn_loading := now_time / reload_time;
      if actor_wpn_loading>1 then actor_wpn_loading:=1;
    end else begin
      actor_wpn_loading :=1;
    end;
  end else begin
    actor_weapon_cond:=-1;
    actor_wpn_loading:=1;
  end;

  actor_health:=GetActorHealth(act);
  RCache__set(C, actor_health, actor_outfit_cond, actor_weapon_cond, actor_wpn_loading);
end;

procedure binder_zoom_deviation_setup(C:pR_constant); stdcall;
var
  wpn:pointer;
  buf:WpnBuf;
  offset_params:lens_offset_params;
  ang, len, x,y, cond:single;
  scope_sect:PChar;
begin
  wpn:=GetActorActiveItem();
  if (wpn<>nil) and WpnCanShoot(wpn) then buf:=GetBuffer(wpn) else buf:=nil;

  if buf<>nil then begin
    buf.GetLensOffsetParams(@offset_params);
    ang:=offset_params.dir*2*pi;
    cond:=GetCurrentCondition(wpn);
    if cond>offset_params.start_condition then
      len:=0
    else if cond<offset_params.end_condition then
      len:=offset_params.max_value
    else
      len:=offset_params.max_value*(offset_params.start_condition-cond)/(offset_params.start_condition-offset_params.end_condition);

    if IsScopeAttached(wpn) and (GetScopeStatus(wpn)=2) then begin
      scope_sect:=game_ini_read_string(GetCurrentScopeSection(wpn), 'scope_name');
      len:=len*game_ini_r_single_def(scope_sect, 'lens_offset_factor', 1.0);
    end;
    
    x:=len*cos(ang);
    y:=len*sin(ang);


    x:=x+buf.GetCurLensRecoil.x;
    y:=y+buf.GetCurLensRecoil.y;

//    log('deviation len='+floattostr(len)+', x='+floattostr(x)+', y='+floattostr(y));
    RCache__set(C, x,y,buf.GetCurBrightness.cur_value,buf.GetCurBrightness.jitter);
  end;
end;


procedure binder_timearrow_setup(C:pR_constant); stdcall;
var
  y, mo, d, h, m, s, ms:integer;
  h_f, m_f, s_f:single;
  h_angle, m_angle, s_angle:single;
begin
  y:=0;
  mo:=0;
  d:=0;
  h:=0;
  m:=0;
  s:=0;
  ms:=0;

  get_split_time(@y, @mo, @d, @h, @m, @s, @ms);

  R_ASSERT((h>=0) and (h<24), 'Invalid hours value', 'binder_timearrow_setup');
  R_ASSERT((m>=0) and (m<60), 'Invalid minutes value', 'binder_timearrow_setup');
  R_ASSERT((s>=0) and (s<60), 'Invalid seconds value', 'binder_timearrow_setup');

  s_f := s/60;
  s_angle := 2*pi*s_f;

  m_f:= (s_f+m) / 60;
  m_angle := 2*pi*m_f;

  h_f:= (m_f+h) / 12;
  h_angle:=2*pi*h_f;

  RCache__set(C, sin(h_angle), cos(h_angle), sin(m_angle), cos(m_angle));
end;

procedure binder_timearrow2_setup(C:pR_constant); stdcall;
var
  y, mo, d, h, m, s, ms:integer;
  camdir:FVector3;
  sec_f, temp:single;
  sec_angle, compass_angle:single;
begin
  y:=0;
  mo:=0;
  d:=0;
  h:=0;
  m:=0;
  s:=0;
  ms:=0;

  get_split_time(@y, @mo, @d, @h, @m, @s, @ms);
  R_ASSERT((s>=0) and (s<60), 'Invalid seconds value', 'binder_timearrow2_setup');

  sec_f:= s / 60;
  sec_angle := 2*pi*sec_f;

  camdir:=FVector3_copyfromengine(CRenderDevice__GetCamDir());
  getHP(@camdir, compass_angle, temp);

  RCache__set(C, sin(sec_angle), cos(sec_angle), sin(compass_angle), cos(compass_angle));
end;

procedure binder_digiclock_setup(C:pR_constant); stdcall;
var
  y, mo, d, h, m, s, ms:integer;
  hh, hl, mh, ml:single;
begin
  y:=0;
  mo:=0;
  d:=0;
  h:=0;
  m:=0;
  s:=0;
  ms:=0;

  get_split_time(@y, @mo, @d, @h, @m, @s, @ms);
  hh:= (h div 10) / 10; //старший разряд часов
  hl:= (h mod 10) / 10; //младший разряд часов
  mh:= (m div 10) / 10; //старший разряд минут
  ml:= (m mod 10) / 10; //младший разряд минут  

  RCache__set(C, hh, hl, mh, ml);
end;

////////////////////////////////////////////////////////////////////////
procedure CBlender_Compile__SetMapping(this:pointer); stdcall;
begin
  //Новые константы дописывать ЗДЕСЬ!
  //log(inttohex(cardinal(@binder_cur_zoom_factor), 8));

  binder_cur_zoom_factor.vftable:=@r_constant_vftable;
  binder_cur_zoom_factor.setup_proc_addr:=@binder_cur_zoom_factor_setup;
  CBlender_Compile__r_Constant(this, 'm_hud_params', @binder_cur_zoom_factor);

  binder_actor_states.vftable:=@r_constant_vftable;
  binder_actor_states.setup_proc_addr:=@binder_actor_states_setup;
  CBlender_Compile__r_Constant(this, 'm_actor_params', @binder_actor_states);

  binder_zoom_deviation.vftable:=@r_constant_vftable;
  binder_zoom_deviation.setup_proc_addr:=@binder_zoom_deviation_setup;
  CBlender_Compile__r_Constant(this, 'm_zoom_deviation', @binder_zoom_deviation);

  binder_affects.vftable:=@r_constant_vftable;
  binder_affects.setup_proc_addr:=@binder_affects_setup;
  CBlender_Compile__r_Constant(this, 'm_affects', @binder_affects);

  binder_timearrow.vftable:=@r_constant_vftable;
  binder_timearrow.setup_proc_addr:=@binder_timearrow_setup;
  CBlender_Compile__r_Constant(this, 'm_timearrow', @binder_timearrow);

  binder_timearrow2.vftable:=@r_constant_vftable;
  binder_timearrow2.setup_proc_addr:=@binder_timearrow2_setup;
  CBlender_Compile__r_Constant(this, 'm_timearrow2', @binder_timearrow2);

  binder_digiclock.vftable:=@r_constant_vftable;
  binder_digiclock.setup_proc_addr:=@binder_digiclock_setup;
  CBlender_Compile__r_Constant(this, 'm_digiclock', @binder_digiclock);
end;

//Патч для добавления констант
procedure CBlender_Compile__SetMapping_Patch(); stdcall;
asm
  pushad
    push edi
    call CBlender_Compile__SetMapping
  popad
  push [esp]
  push eax
  mov eax, eye_direction
  mov [esp+8], eax
  pop eax
end;



//////////////Семейство RCache::Set для каждого из рендеров/////////////
procedure RCache__Set_R1 (C:pR_constant; x,y,z,w:single); stdcall;
asm
  pushad

  mov ecx, C
  test ecx, ecx
  je @finish
  test byte ptr [ecx+$0C],01

  movss xmm0, x
  movss xmm1, y
  movss xmm2, z
  movss xmm3, w

  je @vertex

  //if pixel
  movzx eax,word ptr [ecx+$10]
  shl eax,04
  add eax, xrRender_R1_addr
  add eax, $B5B60
  movss [eax],xmm0
  movss [eax+$04],xmm1
  movss [eax+$08],xmm2
  movss [eax+$0C],xmm3
  movzx eax,word ptr [ecx+$10]
  mov ebx, xrRender_R1_addr
  add ebx, $B6B64
  cmp eax, [ebx]
  lea edx,[eax+$01]
  jae @p1
  mov [ebx], eax
  @p1:
  add ebx, $4
  cmp edx, [ebx]
  jna @p2
  mov [ebx], edx
  @p2:
  mov [ebx+$8], 1

  @vertex:
  test byte ptr [ecx+$0C],02
  je @finish
  movzx eax,word ptr [ecx+$14]
  shl eax,04
  add eax, xrRender_R1_addr
  add eax, $B6B80
  movss [eax],xmm0
  movss [eax+$04],xmm1
  movss [eax+$08],xmm2
  movss [eax+$0C],xmm3
  movzx eax,word ptr [ecx+$14]
  mov ebx, xrRender_R1_addr
  add ebx, $B7B84
  cmp eax, [ebx]
  lea ecx,[eax+$01]
  jae @v1
  mov [ebx], eax
  @v1:
  add ebx, $4
  cmp ecx, [ebx]
  jna @v2
  mov [ebx], ecx
  @v2:
  mov [ebx+$8], 1
  @finish:
  popad
end;


procedure RCache__Set_R2 (C:pR_constant; x,y,z,w:single); stdcall;
asm
  pushad

  mov ecx, C
  test ecx, ecx
  je @finish
  test byte ptr [ecx+$0C],01

  movss xmm0, x
  movss xmm1, y
  movss xmm2, z
  movss xmm3, w

  je @vertex

  //if pixel
  movzx eax,word ptr [ecx+$10]
  shl eax,04
  add eax, xrRender_R2_addr
  add eax, $DD090
  movss [eax],xmm0
  movss [eax+$04],xmm1
  movss [eax+$08],xmm2
  movss [eax+$0C],xmm3
  movzx eax,word ptr [ecx+$10]
  mov ebx, xrRender_R2_addr
  add ebx, $DE094
  cmp eax, [ebx]
  lea edx,[eax+$01]
  jae @p1
  mov [ebx], eax
  @p1:
  add ebx, $4
  cmp edx, [ebx]
  jna @p2
  mov [ebx], edx
  @p2:
  mov [ebx+$8], 1

  @vertex:
  test byte ptr [ecx+$0C],02
  je @finish
  movzx eax,word ptr [ecx+$14]
  shl eax,04
  add eax, xrRender_R2_addr
  add eax, $DE0B0
  movss [eax],xmm0
  movss [eax+$04],xmm1
  movss [eax+$08],xmm2
  movss [eax+$0C],xmm3
  movzx eax,word ptr [ecx+$14]
  mov ebx, xrRender_R2_addr
  add ebx, $DF0B4
  cmp eax, [ebx] 
  lea ecx,[eax+$01]
  jae @v1
  mov [ebx], eax
  @v1:
  add ebx, $4
  cmp ecx, [ebx]
  jna @v2
  mov [ebx], ecx
  @v2:
  mov [ebx+$8], 1
  @finish:
  popad
end;

procedure RCache__Set_R3_internal(); stdcall;
//fake arguments present!!!
//наш девиз: что работает - то не безобразно!!!
asm
  mov ecx, esp
  sub esp, $10
  push esi

  mov esi, [ecx+$04]

  mov eax, [ecx+$08]
  mov [esp+$04], eax

  mov eax, [ecx+$0C]
  mov [esp+$08], eax

  mov eax, [ecx+$10]
  mov [esp+$0C], eax

  mov eax, [ecx+$14]
  mov [esp+$10], eax


  mov ecx, xrrender_r3_addr
  add ecx, $96F64
  mov eax, [esi+$0C]  
  test al, 01
  jmp ecx          //[hack] используем кусок движковой функции
end;

procedure RCache__Set_R3 (C:pR_constant; x,y,z,w:single); stdcall;
asm
  pushad

  cmp C, 0
  je @finish

  push w
  push z
  push y
  push x
  push c
  call RCache__Set_R3_internal
  add esp, $10

  @finish:
  popad
end;

procedure RCache__Set_R4_internal(); stdcall;
//fake arguments present!!!
//наш девиз: что работает - то не безобразно!!!
asm
  mov ecx, esp
  sub esp, $10
  push esi

  mov esi, [ecx+$04]

  mov eax, [ecx+$08]
  mov [esp+$04], eax

  mov eax, [ecx+$0C]
  mov [esp+$08], eax

  mov eax, [ecx+$10]
  mov [esp+$0C], eax

  mov eax, [ecx+$14]
  mov [esp+$10], eax


  mov ecx, xrrender_r4_addr
  add ecx, $9F15A
  mov eax, [esi+$0C]
  push ebx
  mov ebx, 1
  test bl, al
  jmp ecx          //[hack] используем кусок движковой функции
end;

procedure RCache__Set_R4 (C:pR_constant; x,y,z,w:single); stdcall;
asm
  pushad

  cmp C, 0
  je @finish

  push w
  push z
  push y
  push x
  push c
  call RCache__Set_R4_internal
  add esp, $10

  @finish:
  popad
end;

////////////////////////////////////////////////////////////////////////

function Init():boolean;
var
  jmp_addr:cardinal;
begin
  result:=false;
  if xrRender_R1_addr<>0 then begin
    CBlender_Compile__r_Constant_proc_addr:=xrRender_R1_addr+$610A0;
    RCache__set:=RCache__Set_R1;
    jmp_addr:=xrRender_R1_addr+$6304B;
    r_constant_vftable.virtual_destructor:= pointer(xrRender_R1_addr+$616C0);
    
  end else if xrRender_R2_addr<>0 then begin
    CBlender_Compile__r_Constant_proc_addr:=xrRender_R2_addr+$89600;
    RCache__set:=RCache__Set_R2;
    jmp_addr:=xrRender_R2_addr+$8B5EB;
    r_constant_vftable.virtual_destructor:=pointer(xrRender_R2_addr+$89c60);

  end else if xrRender_R3_addr<>0 then begin
    CBlender_Compile__r_Constant_proc_addr:=xrRender_R3_addr+$95490;
    RCache__set:=RCache__Set_R3;
    jmp_addr:=xrRender_R3_addr+$9762B;
    r_constant_vftable.virtual_destructor:=pointer(xrRender_R3_addr+$15950);

  end else if xrRender_R4_addr<>0 then begin
    CBlender_Compile__r_Constant_proc_addr:=xrRender_R4_addr+$9D160;
    RCache__set:=RCache__Set_R4;
    jmp_addr:=xrRender_R4_addr+$9FF3B;
    r_constant_vftable.virtual_destructor:=pointer(xrRender_R4_addr+$9E1C0);

  end else begin
    CBlender_Compile__r_Constant_proc_addr :=0;
    RCache__set:=nil;
    r_constant_vftable.virtual_destructor:=nil;
    jmp_addr:=0;
  end;
  if jmp_addr>0 then
    if not WriteJump(jmp_addr, cardinal(@CBlender_Compile__SetMapping_Patch), 5, true) then exit;
  r_constant_vftable.setup_proc:=@R_constant_setup__setup;
  result:=true;
end;

end.
