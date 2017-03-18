unit WeaponUpdate;

interface
function Init:boolean;
procedure ReassignWorldAnims(wpn:pointer); stdcall;
procedure CWeapon__ModUpdate(wpn:pointer); stdcall;
procedure ProcessAmmo(wpn: pointer; forced:boolean=false);

implementation
uses Messenger, BaseGameData, MatVectors, Misc, HudItemUtils, LightUtils, sysutils, WeaponAdditionalBuffer, WeaponEvents, ActorUtils, strutils, math, gunsl_config, ConsoleUtils, xr_BoneUtils, ActorDOF, dynamic_caster, RayPick, xr_ScriptParticles, xr_Cartridge, ControllerMonster, UIUtils, xr_RocketLauncher, KeyUtils;



var patch_addr:cardinal;
  tst_light:pointer;



procedure ProcessLaserdot(wpn:pointer);
var
  buf:WpnBuf;
  laserdot_data:laserdot_params;
  dotpos, dotdir, zerovec, viewdir, viewpos, tmp, bonedir:FVector3;
  dist:single;
  HID:pointer;
  b:boolean;
  time:cardinal;

  lb:conditional_breaking_params;
begin
  buf:=GetBuffer(wpn);
  if not buf.IsLaserInstalled() then exit;

  zerovec.x:=0;
  zerovec.y:=0;
  zerovec.z:=0;
  laserdot_data:=buf.GetLaserDotData();

  //если в собственности НПСа и в консоли выставлено не использовать лазер - отключим
  if (GetOwner(wpn)<>nil) and (GetOwner(wpn)<>GetActor()) and not IsNPCLasers()then begin
    buf.SetLaserEnabledStatus(false);
  end;

  if buf.IsLaserEnabled() then begin
     if not game_ini_r_bool_def(GetHUDSection(wpn), 'disable_laserdot_when_gl_enabled', false) then begin
       SetWeaponMultipleBonesStatus(wpn, laserdot_data.ray_bones, true);
     end else begin
      //подствол при прицеливании может перекрывать ЛЦУ - тогда выключаем последний
      if leftstr(GetActualCurrentAnim(wpn), length('anm_switch'))='anm_switch' then begin
        if rightstr(GetActualCurrentAnim(wpn), 2)='_g' then
          time:=GetTimeDeltaSafe(GetAnimTimeState(wpn, ANM_TIME_START), GetAnimTimeState(wpn, ANM_TIME_CUR))
        else
          time:=GetTimeDeltaSafe(GetAnimTimeState(wpn, ANM_TIME_CUR), GetAnimTimeState(wpn, ANM_TIME_END));

        if time>game_ini_r_int_def(GetHUDSection(wpn), PChar('laser_switch_time_'+GetActualCurrentAnim(wpn)), 0) then begin
          if game_ini_r_bool_def(GetHUDSection(wpn), 'disable_laserray_when_gl_enabled', false) then begin
            SetWeaponMultipleBonesStatus(wpn, laserdot_data.ray_bones, false);
          end;
          buf.StopLaserdotParticle();
          exit;
        end else begin
          SetWeaponMultipleBonesStatus(wpn, laserdot_data.ray_bones, true);
        end;

      end else if IsGrenadeMode(wpn) then begin
        if game_ini_r_bool_def(GetHUDSection(wpn), 'disable_laserray_when_gl_enabled', false) then begin
          SetWeaponMultipleBonesStatus(wpn, laserdot_data.ray_bones, false);
        end;
        buf.StopLaserdotParticle();
        exit;
      end else begin
        SetWeaponMultipleBonesStatus(wpn, laserdot_data.ray_bones, true);
      end;
     end;
  end else begin
    SetWeaponMultipleBonesStatus(wpn, laserdot_data.ray_bones, false);
    buf.StopLaserdotParticle();
    exit;
  end;

  lb:=buf.GetLaserBreakingParams();

  if GetCurrentCondition(wpn)<lb.end_condition then begin
    SetWeaponMultipleBonesStatus(wpn, laserdot_data.ray_bones, false);
    buf.StopLaserdotParticle();
    exit;
  end else if GetCurrentCondition(wpn)<lb.start_condition then begin
    if random<lb.start_probability+(lb.start_condition-GetCurrentCondition(wpn))* (1-lb.start_probability)/(lb.start_condition-lb.end_condition) then begin
      SetWeaponMultipleBonesStatus(wpn, laserdot_data.ray_bones, false);
      buf.StopLaserdotParticle();
      exit;
    end;
  end;


  HID :=CHudItem__HudItemData(wpn);
  if (HID<>nil) and (GetActorActiveItem()=wpn)then begin // and (not IsDemoRecord()) then begin
    //1st person view
    if IsAimNow(wpn) or IsHolderInAimState(wpn) then begin
      //в режиме прицеливания привязываемся к камере - иначе при настройке прицеливания у оружия будем проводить прямую через 3 точки :(
      viewdir:=FVector3_copyfromengine(CRenderDevice__GetCamDir());
      viewpos:=FVector3_copyfromengine(CRenderDevice__GetCamPos());
      attachable_hud_item__GetBoneOffsetPosDir(HID, laserdot_data.bone_name, @dotpos, @dotdir, @laserdot_data.offset);

      v_sub(@viewdir, @dotdir); //считаем разностный вектор направления
      v_mul(@viewdir, GetAimFactor(wpn)-1.0); //величина добавки зависит от того, насколько сильно мы вошли в режим прицела
      dotdir:=FVector3_copyfromengine(CRenderDevice__GetCamDir());
      v_add(@dotdir, @viewdir);
      v_normalize(@dotdir);

      v_sub(@viewpos, @dotpos);
      v_mul(@viewpos, GetAimFactor(wpn)-1.0);
      dotpos:=FVector3_copyfromengine(CRenderDevice__GetCamPos());
      v_add(@dotpos, @viewpos);

    end else begin
      attachable_hud_item__GetBoneOffsetPosDir(HID, laserdot_data.bone_name, @dotpos, @dotdir, @laserdot_data.offset);
      bonedir:=dotdir;

      //пытаемся скорректировать разность ФОВ худа и мира
      tmp:=FVector3_copyfromengine(CRenderDevice__GetCamDir());
      CorrectDirFromWorldToHud(@dotdir, @dotpos, game_ini_r_single_def(GetHUDSection(wpn), 'hud_recalc_koef', 1.0));
    end;

    dist:=TraceAsView(@dotpos, @dotdir, dynamic_cast(GetActor(), 0, RTTI_CActor, RTTI_CObject, false))*0.99;


    if laserdot_data.always_world then begin
      b:=false;
    end else if laserdot_data.always_hud then begin
      b:=true;
    end else begin
      viewdir:=FVector3_copyfromengine(CRenderDevice__GetCamDir());
      b:=(GetAngleCos(@viewdir, @dotdir)<laserdot_data.hud_treshold);
    end;

    if (not IsLaserdotCorrection()) then dist:=dist*0.85;

    dotpos.x:=dotpos.x+dotdir.x*dist;
    dotpos.y:=dotpos.y+dotdir.y*dist;
    dotpos.z:=dotpos.z+dotdir.z*dist;

    buf.PlayLaserdotParticle(@dotpos, dist, true, b);
    buf.SetLaserDotParticleHudStatus(b);
  end else if (GetOwner(wpn)=GetActor()) and (GetActorActiveItem()=wpn) then begin
    viewpos:=laserdot_data.world_offset;
    transform_tiny(GetXFORM(wpn), @dotpos, @viewpos);
    dotdir:=GetLastFD(wpn);
    dist:=TraceAsView(@dotpos, @dotdir, dynamic_cast(wpn, 0, RTTI_CWeapon, RTTI_CObject, false))*0.99;
    dotpos.x:=dotpos.x+dotdir.x*dist;
    dotpos.y:=dotpos.y+dotdir.y*dist;
    dotpos.z:=dotpos.z+dotdir.z*dist;
    buf.PlayLaserdotParticle(@dotpos, dist, false, false);
    buf.SetLaserDotParticleHudStatus(false);

    //messenger.SendMessage(PChar(inttohex(cardinal(wpn),8)));
  end else begin
    buf.StopLaserdotParticle();
  end;
end;

function GetOrdinalAmmotype(wpn:pointer):byte; stdcall;
begin
  if game_ini_r_bool_def(GetHUDSection(wpn), 'ammo_params_use_last_cartridge_type', false) and (GetAmmoInMagCount(wpn)>0) then begin
    //если указан этот параметр, то в остальных режимах за тип секции отвечает тип последнего патрона
    result:=GetCartridgeFromMagVector(wpn, GetAmmoInMagCount(wpn)-1).m_local_ammotype;
  end else begin
    result:=GetAmmoTypeIndex(wpn, IsGrenadeMode(wpn));
  end;
end;

procedure ProcessAmmoAdv(wpn: pointer; forced:boolean=false);
var
  hud_sect:PChar;
  bones_sect:PChar;
  bones:PChar;
  cnt, ammotype:integer;
  sect_w_ammotype:string;
  g_b:boolean;
begin
  hud_sect:=GetHUDSection(wpn);
  g_b:=IsGrenadeMode(wpn);

  if (not g_b) and (GetCurrentState(wpn)=cardinal(EWeaponStates__eFire)) and not forced and game_ini_r_bool_def(hud_sect, 'ammo_params_toggle_shooting', false) then begin
    //во время стрельбы не производить обновление костей - нужно для корректных гильз у дробовиков
    exit;
  end;

  cnt:=GetAmmoInMagCount(wpn);
  if
    (IsWeaponJammed(wpn) and game_ini_line_exist(bones_sect, 'additional_ammo_bone_when_jammed') and game_ini_r_bool(bones_sect, 'additional_ammo_bone_when_jammed'))
  then
    cnt:=cnt+1;

  if g_b then begin
    //Оружие в режиме стрельбы подстволом
    ammotype:=GetOrdinalAmmoType(wpn);

  end else if (GetCurrentState(wpn)=cardinal(EWeaponStates__eReload)) then begin
    if IsWeaponJammed(wpn) then begin
      //идет расклин
      ammotype:=GetOrdinalAmmoType(wpn);
    end else if IsTriStateReload(wpn)  then begin
      //идет перезарядка по типу дробовика
      ammotype:=GetAmmoTypeToReload(wpn);
      cnt:=cnt+1;
    end else begin
      //идет обычная перезарядка
      //патрон в патроннике может быть старого типа! учитываем это
      //обновление синхронно со счетчиком
      ammotype:=GetAmmoTypeIndex(wpn, g_b);
    end

  end else begin
    //не в состоянии перезарядки, подствол выключен
    ammotype:=GetOrdinalAmmotype(wpn);
  end;

  {  if (not g_b) and (GetCurrentState(wpn)=cardinal(EWeaponStates__eReload)) and game_ini_r_bool_def(hud_sect, 'ammo_params_changing_when_reload_starts', false) then begin
    //обновление нужно производить в начале перезарядки - для дробашей
    ammotype:=GetAmmoTypeToReload(wpn);
    if IsTriStateReload(wpn) and not IsWeaponJammed(wpn) then cnt:=cnt+1;
  end else if (not g_b) and (GetCurrentState(wpn)=cardinal(EWeaponStates__eReload)) and not IsWeaponJammed(wpn) then begin
    //обновление в перезарядке синхронно со счетчиком
    ammotype:=GetAmmoTypeIndex(wpn, g_b);
  end else if game_ini_r_bool_def(hud_sect, 'ammo_params_use_last_cartridge_type', false) and (GetAmmoInMagCount(wpn)>0) then begin
    //если указан этот параметр, то в остальных режимах за тип секции отвечает тип последнего патрона
    ammotype:=GetCartridgeFromMagVector(wpn, GetAmmoInMagCount(wpn)-1).m_local_ammotype;
  end else begin
    //за тип секции отвечает общий тип оружия
    ammotype:=GetAmmoTypeIndex(wpn, g_b);
  end; }

  sect_w_ammotype:='ammo_params_section_'+inttostr(ammotype);
  if game_ini_line_exist(hud_sect, PChar(sect_w_ammotype)) then begin
    bones_sect:= game_ini_read_string(hud_sect, PChar(sect_w_ammotype));
  end else if game_ini_line_exist(hud_sect, 'ammo_params_section') then begin
    bones_sect:= game_ini_read_string(hud_sect, 'ammo_params_section');
  end else begin
    exit;
  end;

  //скрываем все
  bones:= game_ini_read_string(bones_sect, 'all_bones');
  SetWeaponMultipleBonesStatus(wpn, bones, false);

  //отображаем нужные
  bones:= game_ini_read_string(bones_sect, PChar('configuration_'+inttostr(cnt)));
  SetWeaponMultipleBonesStatus(wpn, bones, true);
end;

procedure ProcessAmmoGL(wpn: pointer; forced:boolean=false);
var
  hud_sect, bones_sect, bones:PChar;
  ammotype, cnt:integer;
  sect_w_ammotype:string;
  g_m:boolean;
begin

  if (GetGLStatus(wpn)=0) then exit; 

  g_m:=IsGrenadeMode(wpn);
  hud_sect:=GetHUDSection(wpn);

  cnt:=GetAmmoInGLCount(wpn);
  if g_m and (GetCurrentState(wpn)=cardinal(EWeaponStates__eReload)) then begin
    ammotype:=GetAmmoTypeToReload(wpn);
    if cnt=0 then cnt:=1;
  end else begin
    ammotype:=GetAmmoTypeIndex(wpn, not g_m);
  end;

  sect_w_ammotype:='gl_ammo_params_section_'+inttostr(ammotype);
  if game_ini_line_exist(hud_sect, PChar(sect_w_ammotype)) then begin
    bones_sect:= game_ini_read_string(hud_sect, PChar(sect_w_ammotype));
  end else if game_ini_line_exist(hud_sect, 'ammo_params_section') then begin
    bones_sect:= game_ini_read_string(hud_sect, 'ammo_params_section');
  end else begin
    exit;
  end;
  
  //скрываем все
  bones:= game_ini_read_string(bones_sect, 'all_bones');
  SetWeaponMultipleBonesStatus(wpn, bones, false);

  //отображаем нужные
  bones:= game_ini_read_string(bones_sect, PChar('configuration_'+inttostr(cnt)));
  SetWeaponMultipleBonesStatus(wpn, bones, true);
end;


procedure ProcessAmmo(wpn: pointer; forced:boolean=false);
var hud_sect:PChar;
    prefix, prefix_hide, prefix_var:string;
    i:integer;
    start_index, finish_index, limitator:integer;
begin
  hud_sect:=GetHUDSection(wpn);
  if game_ini_r_bool_def(hud_sect, 'use_advanced_ammo_bones', false) then begin
    ProcessAmmoAdv(wpn, forced);
    exit;
  end;

  if not game_ini_r_bool_def(hud_sect, 'use_ammo_bones', false) then exit;
  prefix:= game_ini_read_string(hud_sect, 'ammo_bones_prefix');

  if game_ini_line_exist(hud_sect, 'ammo_hide_bones_prefix') then
    prefix_hide:= game_ini_read_string(hud_sect, 'ammo_hide_bones_prefix')
  else
    prefix_hide:='';

  if game_ini_line_exist(hud_sect, 'ammo_var_bones_prefix') then
    prefix_var:= game_ini_read_string(hud_sect, 'ammo_var_bones_prefix')
  else
    prefix_var:='';


  if game_ini_line_exist(hud_sect, 'start_ammo_bone_index') then
    start_index:= strtoint(game_ini_read_string(hud_sect, 'start_ammo_bone_index'))
  else
    start_index:=0;

  if game_ini_line_exist(hud_sect, 'end_ammo_bone_index') then
    limitator:= strtoint(game_ini_read_string(hud_sect, 'end_ammo_bone_index'))
  else
    limitator:=0;

  finish_index:=start_index+GetAmmoInMagCount(wpn)-1;

  if IsWeaponJammed(wpn) and game_ini_line_exist(hud_sect, 'additional_ammo_bone_when_jammed') and game_ini_r_bool(hud_sect, 'additional_ammo_bone_when_jammed') then
    finish_index:=finish_index+1;

  if game_ini_line_exist(hud_sect, 'ammo_divisor_up') then
    finish_index:=ceil(finish_index/strtoint(game_ini_read_string(hud_sect, 'ammo_divisor_up')))
  else if game_ini_line_exist(hud_sect, 'ammo_divisor_down') then
    finish_index:=floor(finish_index/strtoint(game_ini_read_string(hud_sect, 'ammo_divisor_down')));

  if finish_index>limitator then finish_index:=limitator;

//  if wpn=GetActorActiveItem() then SendMessage(PChar(inttostr(start_index)+' '+PChar(inttostr(finish_index))+' '+PChar(inttostr(limitator))));

  for i:=start_index to finish_index do begin
    SetWeaponMultipleBonesStatus(wpn, PChar(prefix+inttostr(i)), true);
    if prefix_hide<>'' then begin
      SetWeaponMultipleBonesStatus(wpn, PChar(prefix_hide+inttostr(i)), false);
    end;
  end;
  for i:= finish_index+1 to limitator do begin
    SetWeaponMultipleBonesStatus(wpn, PChar(prefix+inttostr(i)), false);
    if prefix_hide<>'' then begin
      SetWeaponMultipleBonesStatus(wpn, PChar(prefix_hide+inttostr(i)), true);
    end;
  end;

  if prefix_var<>'' then begin
    for i:= start_index-1 to limitator do begin
      SetWeaponMultipleBonesStatus(wpn, PChar(prefix_var+inttostr(i)), i=finish_index);
    end;
  end;
end;

procedure HideOneUpgradeLevel(wpn:pointer; up_gr_section:pchar); stdcall;
var
  up_sect:PChar;
  up_group:string;
  tmp:string;
  all_subelements, element:string;
begin
  all_subelements:=game_ini_read_string(up_gr_section, 'elements');
  
  while (GetNextSubStr(all_subelements, element, ',')) do begin
    //Обработаем ветки, которые открывает данный апгрейд
    if game_ini_line_exist(PChar(element), 'effects') then begin
      up_group:=game_ini_read_string(PChar(element), 'effects');
      while (GetNextSubStr(up_group, tmp, ',')) do begin
        HideOneUpgradeLevel(wpn, PChar(tmp));
      end;
    end;

    //Теперь посмотрим, какие кости надо отображать, когда данный апгрейд установлен
    up_sect:=game_ini_read_string(PChar(element), 'section');
    if game_ini_line_exist(up_sect, 'show_bones') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(up_sect, 'show_bones'), false);
  end;
end;

procedure ProcessUpgrade(wpn:pointer); stdcall;
var all_upgrades:string;
    section:PChar;
    up_gr_sect:string;
    i:integer;
    buf:WpnBuf;
    min, max, pos, delta, t_dt:single;
begin
  section:=GetSection(wpn);
  buf:=GetBuffer(wpn);
  //Скроем все кости, которые надо скрыть, исходя из данных секции оружия
  if game_ini_line_exist(section, 'def_hide_bones') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'def_hide_bones'), false);
  if game_ini_line_exist(section, 'def_show_bones') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'def_show_bones'), true);
  if IsGrenadeMode(wpn) and game_ini_line_exist(section, 'def_hide_bones_grenade') and not (leftstr(GetActualCurrentAnim(wpn), length('anm_switch'))='anm_switch') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'def_hide_bones_grenade'), false);
  
  //Прочитаем секции всех доступных апов из конфига
  if not game_ini_line_exist(section, 'upgrades') then exit;
  all_upgrades:=game_ini_read_string(section, 'upgrades');
  //Переберем их все
  while (GetNextSubStr(all_upgrades, up_gr_sect, ',')) do begin
      HideOneUpgradeLevel(wpn, PChar(up_gr_sect));
  end;

  //Посмотрим, какие апгрейды уже установлены, и отобразим их
  for i:=0 to GetInstalledUpgradesCount(wpn)-1 do begin
    section:=GetInstalledUpgradeSection(wpn, i);
    section:=game_ini_read_string(section, 'section');
    if game_ini_line_exist(section, 'hide_bones') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'hide_bones'), false);
    if game_ini_line_exist(section, 'hud') then begin
      SetHUDSection(wpn, game_ini_read_string(section, 'hud'));
    end;
    if game_ini_line_exist(section, 'visual') then begin
      SetWpnVisual(wpn, game_ini_read_string(section, 'visual'));
    end;

    if (buf<>nil) and not buf.IsLaserInstalled() and game_ini_r_bool_def(section, 'laser_installed', false) then begin
      buf.InstallLaser(section);
    end;
    if (buf<>nil) and not buf.IsTorchInstalled() and game_ini_r_bool_def(section, 'torch_installed', false) then begin
      buf.InstallTorch(section);
    end;
    if (buf<>nil) and not buf.NeedPermanentLensRendering() and game_ini_r_bool_def(section, 'permanent_lens_render', false) then begin
      buf.SetPermanentLensRenderingStatus(true);
    end;


    if (buf<>nil) then begin
      buf.GetLensParams(min, max, pos, delta);
      t_dt:=game_ini_r_single_def(section, 'lens_factor_levels_count', 0);

      if t_dt <> 0 then begin
        delta:=1/t_dt;
      end;

      buf.SetLensParams(
        game_ini_r_single_def(section, 'min_lens_factor', min),
        game_ini_r_single_def(section, 'max_lens_factor', max),
        t_dt
      );
    end;



    if game_ini_line_exist(section, 'flame_particles') then begin
      ChangeParticles(wpn, game_ini_read_string(section, 'flame_particles'), CWEAPON_FLAME_PARTICLES);
      if not IsSilencerAttached(wpn) then ChangeParticles(wpn, game_ini_read_string(section, 'flame_particles'), CWEAPON_FLAME_PARTICLES_CURRENT);
    end;
    if game_ini_line_exist(section, 'smoke_particles') then begin
      ChangeParticles(wpn, game_ini_read_string(section, 'smoke_particles'), CWEAPON_SMOKE_PARTICLES);
      if not IsSilencerAttached(wpn) then ChangeParticles(wpn, game_ini_read_string(section, 'smoke_particles'), CWEAPON_SMOKE_PARTICLES_CURRENT);
    end;
    if game_ini_line_exist(section, 'shell_particles') then ChangeParticles(wpn, game_ini_read_string(section, 'shell_particles'), CWEAPON_SHELL_PARTICLES);

    if game_ini_line_exist(section, 'actor_camera_speed_factor') then begin
      buf.SetCameraSpeed(GetCamSpeedDef()*game_ini_r_single(section, 'actor_camera_speed_factor'));
    end;            
  end;

 for i:=0 to GetInstalledUpgradesCount(wpn)-1 do begin
    section:=GetInstalledUpgradeSection(wpn, i);
    section:=game_ini_read_string(section, 'section');
    if game_ini_line_exist(section, 'show_bones') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'show_bones'), true);

    //для сокрытия костей, отвечающих за предыдущие апы ветки
    if game_ini_line_exist(section, 'hide_bones_override') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'hide_bones_override'), false);

    if IsGrenadeMode(wpn) and not (leftstr(GetActualCurrentAnim(wpn), length('anm_switch'))='anm_switch') then begin
      if game_ini_line_exist(section, 'hide_bones_override_grenade') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'hide_bones_override_grenade'), false);    
    end;
  end;
end;

procedure ProcessScope(wpn:pointer); stdcall;
var //section:PChar;

    tmp:string;
    status:boolean;
    cur_index, i:integer;
    total_scope_cnt:cardinal;
begin

  if IsScopeAttached(wpn) and (GetScopeStatus(wpn)=2) then cur_index:=GetCurrentScopeIndex(wpn) else cur_index:=-1;
  total_scope_cnt:=GetScopesCount(wpn);

  for i:=0 to total_scope_cnt-1 do begin
    tmp:=GetScopeSection(wpn, i);
//    if wpn=GetActorActiveItem() then log('scp: '+tmp);
    if i=cur_index then status:=true else status:=false;

    if game_ini_line_exist(PChar(tmp), 'bones') then begin;
      SetWeaponMultipleBonesStatus(wpn,game_ini_read_string(PChar(tmp), 'bones'), status);
    end;
    if game_ini_line_exist(PChar(tmp), 'hide_bones') then begin
      SetWeaponMultipleBonesStatus(wpn,game_ini_read_string(PChar(tmp), 'hide_bones'), not status);
    end;
    if status and game_ini_line_exist(PChar(tmp), 'overriding_hide_bones') then begin
      SetWeaponMultipleBonesStatus(wpn,game_ini_read_string(PChar(tmp), 'overriding_hide_bones'), false);
    end;
  end;
end;

procedure ReassignWorldAnims(wpn:pointer); stdcall;
var
  sect:PChar;
  anm:string;
  rest_anm:string;
  state:cardinal;
  firemode:integer;
  bmixin:boolean;
begin

  state:=cardinal(GetNextState(wpn));
  if (not GetAnimForceReassignStatus(wpn)) then exit;
  sect:=GetSection(wpn);
  if not game_ini_line_exist(sect, 'use_world_anims') or not game_ini_r_bool(sect, 'use_world_anims') then exit;

  bmixin:=true;
  if state=EHudStates__eIdle then begin
    anm:='wanm_idle';
  end else if state=EHudStates__eShowing then begin
    anm:='wanm_draw'
  end else if state=EHudStates__eHiding then begin
    anm:='wanm_holster';
  end else if state=EWeaponStates__eFire then begin
    anm:='wanm_shoot';
    if ((GetGLStatus(wpn)=1) or (IsGLAttached(wpn))) and IsGLEnabled(wpn) then begin
      anm:=anm+'_gl';
    end else if GetAmmoInMagCount(wpn)<=0 then begin
      rest_anm:=anm;
      anm:=anm+'_last';
      if not(game_ini_line_exist(sect, PChar(anm))) or (trim(game_ini_read_string(sect,PChar(anm)))='') then begin
        anm:=rest_anm;
      end;
    end;
  end else if state=EWeaponStates__eReload then begin
    anm:='wanm_reload';
  end else begin
    anm:='wanm_idle';
  end;

  if not game_ini_line_exist(sect, PChar(anm)) or (trim(game_ini_read_string(sect,PChar(anm)))='') then begin
    anm:='wanm_idle';
  end;

  rest_anm:=anm;
  if IsWeaponJammed(wpn) then begin
    anm:=anm+'_jammed';
  end else if (GetAmmoInMagCount(wpn)<=0) and (state<>EWeaponStates__eFire) then begin
    anm:=anm+'_empty';
  end;
  if not(game_ini_line_exist(sect, PChar(anm))) or (trim(game_ini_read_string(sect,PChar(anm)))='') then begin
    anm:=rest_anm;
  end;

  rest_anm:=anm;
  firemode:=CurrentQueueSize(wpn);
  if firemode<0 then begin
    anm:=anm+'_a';
  end else begin
    anm:=anm+'_'+inttostr(firemode);
  end;

  if not(game_ini_line_exist(sect, PChar(anm))) or (trim(game_ini_read_string(sect,PChar(anm)))='') then begin
    anm:=rest_anm;
  end;  

  PlayCycle(wpn, game_ini_read_string(sect,PChar(anm)), bmixin);

  SetAnimForceReassignStatus(wpn, false);
end;

function CastToCWeapon(CObject:pointer):pointer; stdcall;
begin
  result:=dynamic_cast(CObject, 0, RTTI_CObject, RTTI_CWeapon, false);
end;

procedure CWeapon__ModUpdate(wpn:pointer); stdcall;
var
  buf:WpnBuf;
  sect:PChar;

  offset:integer;
  slot, prevslot:integer;
  
  bp:conditional_breaking_params;
  last_rec_time:cardinal;
  lens_recoil:FVector3;
  val, len:single;
  rl:pCRocketLauncher;

  gl_ammocnt, gl_ammotype:byte;
  so:pointer;
begin
    so:=get_server_object_by_id(GetID(wpn));
    if so=nil then exit;
    sect:=GetSection(wpn);


    rl:=dynamic_cast(wpn, 0, RTTI_CWeapon, RTTI_CWeaponMagazinedWGrenade, false);
    if (rl<>nil) then begin
      rl:=dynamic_cast(wpn, 0, RTTI_CWeapon, RTTI_CRocketLauncher, false);
      if GetRocketsCount(rl)>0 then begin
        CWeaponMagazinedWGrenade__LaunchGrenade(wpn);
      end;

      //[bug] баг - отсутствует выставление a_elapsed_grenades в апдейт-пакете, из-за чего грены прогружаются некорректно. По-хорошему, надо править не так топорно, а модифицированием методов экспорта и импорта нетпакетов
      gl_ammocnt:=GetAmmoInGLCount(wpn);
      if gl_ammocnt>0 then begin
        gl_ammotype:=GetGrenadeCartridgeFromGLVector(wpn, gl_ammocnt-1).m_local_ammotype;
      end else begin
        gl_ammotype:=GetAmmoTypeIndex(wpn, not IsGrenadeMode(wpn))
      end;
      pbyte(cardinal(so)+$1A8)^:=(gl_ammotype shl 6) + (gl_ammocnt and $3F);
    end else begin
      rl:=dynamic_cast(wpn, 0, RTTI_CWeapon, RTTI_CRocketLauncher, false);
      if (rl<>nil) then begin
        if GetRocketsCount(rl)>0 then begin
          virtual_Action(wpn, kWPN_FIRE, kActPress);
        end;
      end;
    end;

    if game_ini_r_bool_def(GetSection(wpn), 'action_animator', false) then begin
        if (wpn=GetActorActiveItem()) then begin
          if (GetCurrentState(wpn)=EHudStates__eShowing) then begin
            if GetActorTargetSlot()=GetActorActiveSlot() then begin
              prevslot:=GetActorPreviousSlot();
//              log ('activating '+inttostr(prevslot)+', state='+inttostr(GetCurrentState(wpn)));
              if (prevslot>=0) and (prevslot<>GetActorActiveSlot()) and (ItemInSlot(GetActor, prevslot)<>nil) then
                ActivateActorSlot(prevslot)
              else
                ActivateActorSlot(0);
            end;
          end else begin
            if GetActorTargetSlot()=GetActorActiveSlot() then begin
              virtual_CHudItem_SwitchState(wpn, EHudStates__eShowing);
            end;
          end;
        end else begin
          if (GetActor=nil) or (GetOwner(wpn)<>GetActor()) then begin
            alife_release(get_server_object_by_id(GetID(wpn)));
          end else begin
            slot:=game_ini_r_int_def(GetSection(wpn), 'slot', 0)+1;
//            log('release candidate');
            if (GetActorTargetSlot() <> slot) then begin
//              log('released');
              alife_release(get_server_object_by_id(GetID(wpn)));
              RestoreLastActorDetector();
            end;
          end;
        end;
    end;

    if (GetActorActiveItem=wpn) and DOFChanged() and (not IsAimNow(wpn)) and (not IsHolderInAimState(wpn)) and (GetAnimTimeState(wpn, ANM_TIME_CUR)>0) then begin
      offset:=ReadActionDOFTimeOffset(wpn, GetActualCurrentAnim(wpn));
      if (offset>0) then begin
        if GetTimeDeltaSafe(GetAnimTimeState(wpn, ANM_TIME_START), GetAnimTimeState(wpn, ANM_TIME_CUR))>cardinal(offset) then begin
          ResetDOF(ReadActionDOFSpeed_Out(wpn, GetActualCurrentAnim(wpn)));
        end;
      end else if (offset<0) then begin
        if GetTimeDeltaSafe(GetAnimTimeState(wpn, ANM_TIME_CUR), GetAnimTimeState(wpn, ANM_TIME_END))<cardinal(-1*offset) then begin
          ResetDOF(ReadActionDOFSpeed_Out(wpn, GetActualCurrentAnim(wpn)));
        end;
      end;
    end;

    //апдейт буфера
    buf:=WeaponAdditionalBuffer.GetBuffer(wpn);
    if buf<>nil then begin
      if not buf.Update then Log('Failed to update wpn: '+inttohex(cardinal(wpn), 8));
      if not buf.IsLaserInstalled() and game_ini_r_bool_def(sect, 'laser_installed', false) then begin
        buf.InstallLaser(sect)
      end;
      if not buf.IsTorchInstalled() and game_ini_r_bool_def(sect, 'torch_installed', false) then begin
        buf.InstallTorch(sect)
      end;

      if (game_ini_line_exist(GetSection(wpn), 'collimator_sights_bones')) then begin
        bp:=buf.GetCollimatorBreakingParams();
        if ((GetAimFactor(wpn)>0) and buf.IsLastZoomAlter() and game_ini_r_bool_def(GetSection(wpn),'hide_collimator_sights_in_alter_zoom', true)) or (GetCurrentCondition(wpn)<bp.end_condition) then begin
          SetWeaponMultipleBonesStatus(wpn,game_ini_read_string(GetSection(wpn), 'collimator_sights_bones'), false);
        end else if GetCurrentCondition(wpn)<bp.start_condition then begin
          SetWeaponMultipleBonesStatus(
                                        wpn,
                                        game_ini_read_string(GetSection(wpn), 'collimator_sights_bones'),
                                        not (random<bp.start_probability+(bp.start_condition-GetCurrentCondition(wpn))* (1-bp.start_probability)/(bp.start_condition-bp.end_condition))
                                      );

        end else begin
          SetWeaponMultipleBonesStatus(wpn,game_ini_read_string(GetSection(wpn), 'collimator_sights_bones'), true);
        end;
      end;
    end;

    if ((GetActor()=nil) or (GetOwner(wpn)<>GetActor())) or (GetActorActiveItem()<>wpn) then begin
      if IsExplosed(wpn) then OnWeaponExplode_AfterAnim(wpn, 0);
      if leftstr(GetCurAnim(wpn), length('anm_attach_scope_'))='anm_attach_scope_' then DetachAddon(wpn, 1);
      if leftstr(GetCurAnim(wpn), length('anm_attach_gl'))='anm_attach_gl' then DetachAddon(wpn, 2);
      if leftstr(GetCurAnim(wpn), length('anm_attach_sil'))='anm_attach_sil' then DetachAddon(wpn, 4);
    end;

    //Обработаем установленные апгрейды
    ProcessUpgrade(wpn);
    //Теперь отобразим установленный прицел
    ProcessScope(wpn);
    //Разберемся с визуализацией патронов
    ProcessAmmo(wpn);
    ProcessAmmoGL(wpn);
    //анимы от 3-го лица
    ReassignWorldAnims(wpn);

    if (buf<>nil) then begin
      ProcessLaserDot(wpn);
    end;

    if (buf<>nil) then begin
      buf.UpdateTorch();
    end;
end;

{procedure CWeapon__UpdateCL_Patch();stdcall;
asm
    pushad
      push esi
      call CWeapon__ModUpdate
    popad
    mov eax, [esi+$338]
end;}

procedure CObjectList__SingleUpdate_Patch();stdcall;
asm
    pushad
      push esi
      call CastToCWeapon
      cmp eax, 0
      je @not_cweapon
      push eax
      call CWeapon__ModUpdate
      @not_cweapon:
    popad

    cmp byte ptr[esi+$a6], 00
end;

procedure CObject__shedule_Update_Patch();stdcall;
asm
  //принудительно отправим в очередь апдейтов объект, который является оружием, там уже разберутся.
  cmp byte ptr[esi+$a6], 00
  jne @all_ok
  pushad
    push esi
    call CastToCWeapon
    test eax, eax
  popad
  @all_ok:
end;

function WeaponAdditionalCrosshairHideConditions(wpn:pointer):boolean; stdcall;
var
  buf:WpnBuf;
begin
  //вернуть true, если прицел все же показывать
  if (CDialogHolder__TopInputReceiver()<>nil) then begin
    result:=false;
    exit;
  end;

  buf:=GetBuffer(wpn);
  if (buf<>nil) and ((buf.IsLaserInstalled() and buf.IsLaserEnabled()) or (GetAimFactor(wpn)>0.001)) then begin
    result:=false;
    exit;
  end;
  result:=true;
end;

procedure CWeapon__show_crosshair_Patch(); stdcall;
asm
  pushad
    push esi
    call WeaponAdditionalCrosshairHideConditions
    cmp al, 1
  popad
  je @show
  xor eax, eax
  ret
  @show:
  mov eax, 1
  ret
end;

function CanDrawCrosshairNow():boolean; stdcall;
begin
  result:=true;
  if (gunsl_config.GetCurrentDifficulty()>=gunsl_config.gd_veteran) or IsActorControlled() or IsActorSuicideNow() then begin
    result:=false;
  end;
end;


procedure CHudTarget__Render_Patch(); stdcall;
asm
  pushad
    call CanDrawCrosshairNow
    cmp al, 1
  popad
  jne @finish
  cmp ecx, $221
  @finish:
end;

function Init:boolean;
begin
  result:=false;
  tst_light:=nil;

//  patch_addr:=xrGame_addr+$2C04A0;
//  if not WriteJump(patch_addr, cardinal(@CWeapon__UpdateCL_Patch), 6, true) then exit;
  patch_addr:=xrEngine_addr+$1B226;
  if not WriteJump(patch_addr, cardinal(@CObjectList__SingleUpdate_Patch), 7, true) then exit;
  patch_addr:=xrEngine_addr+$1A487;
  if not WriteJump(patch_addr, cardinal(@CObject__shedule_Update_Patch), 7, true) then exit;

  //патч CWeapon::show_crosshair, чтобы при установленном ЛЦУ перекрестие скрывалось
  patch_addr:=xrGame_addr+$2bd1e5;
  if not WriteJump(patch_addr, cardinal(@CWeapon__show_crosshair_Patch), 5, true) then exit;

  //общий патч сокрытия прицела от уровня сложности
  patch_addr:=xrGame_addr+$4d8c43;
  if not WriteJump(patch_addr, cardinal(@CHudTarget__Render_Patch), 6, true) then exit; 

  result:=true;
end;
end.

