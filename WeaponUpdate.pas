unit WeaponUpdate;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface
function Init:boolean;
procedure ReassignWorldAnims(wpn:pointer); stdcall;
procedure CWeapon__ModUpdate(wpn:pointer); stdcall;
procedure ProcessAmmo(wpn: pointer; forced:boolean=false);

implementation
uses Messenger, BaseGameData, MatVectors, Misc, HudItemUtils, LightUtils, sysutils, WeaponAdditionalBuffer, WeaponEvents, ActorUtils, strutils, math, gunsl_config, ConsoleUtils, xr_BoneUtils, ActorDOF, dynamic_caster, RayPick, xr_ScriptParticles, xr_Cartridge, ControllerMonster, UIUtils, xr_RocketLauncher, KeyUtils;

function NeedUpdateBonesCheck(wpn:pointer):boolean;
var
  buf:WpnBuf;
  new_conds:upgrades_process_condition;
begin
  result:=true;

  buf:=GetBuffer(wpn);
  if buf = nil then exit;

  new_conds.force:=false;
  new_conds.upgrades_count:=GetInstalledUpgradesCount(wpn);
  new_conds.gl_attached:=IsGLAttached(wpn);
  new_conds.gl_enabled:=IsGrenadeMode(wpn);
  new_conds.silencer_attached:=IsSilencerAttached(wpn);
  new_conds.scope_sect:=nil;
  if IsScopeAttached(wpn) then begin
    new_conds.scope_sect:=GetCurrentScopeSection(wpn);
  end;
  new_conds.ammo_type:=GetAmmoTypeIndex(wpn, false);
  new_conds.ammo_count:=GetCurrentAmmoCount(wpn);
  new_conds.firemode:=CurrentQueueSize(wpn);
  new_conds.state:=GetCurrentState(wpn);


  if buf.upgrades_procesing_conditions.force then begin
    result:=true;
  end else begin
    result:= (new_conds.upgrades_count <> buf.upgrades_procesing_conditions.upgrades_count) or
             (new_conds.gl_attached <> buf.upgrades_procesing_conditions.gl_attached) or
             (new_conds.gl_enabled <> buf.upgrades_procesing_conditions.gl_enabled) or
             (new_conds.silencer_attached <> buf.upgrades_procesing_conditions.silencer_attached) or
             (new_conds.scope_sect <> buf.upgrades_procesing_conditions.scope_sect) or
             (new_conds.ammo_type <> buf.upgrades_procesing_conditions.ammo_type) or
             (new_conds.ammo_count <> buf.upgrades_procesing_conditions.ammo_count) or
             (new_conds.firemode <> buf.upgrades_procesing_conditions.firemode) or
             (new_conds.state <> buf.upgrades_procesing_conditions.state);
  end;

  if result then begin
    buf.upgrades_procesing_conditions:=new_conds;
  end;
end;

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
  probability, probability2:single;
  max_problems_cnt:single;

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
        end else begin
          SetWeaponMultipleBonesStatus(wpn, laserdot_data.ray_bones, true);
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
  max_problems_cnt := buf.GetLaserProblemsLevel();  //уровень помех, выше которого отрубится лазер

  if GetCurrentCondition(wpn)<lb.end_condition then begin
    SetWeaponMultipleBonesStatus(wpn, laserdot_data.ray_bones, false);
    buf.StopLaserdotParticle();
    exit;
  end else if (GetCurrentCondition(wpn)<lb.start_condition) or ( (max_problems_cnt>0) and ( CurrentElectronicsProblemsCnt() >= max_problems_cnt) ) then begin
    if ( TargetElectronicsProblemsCnt() >= max_problems_cnt ) then begin
      probability:=1;
    end else if (lb.start_condition = lb.end_condition) then begin
      probability := lb.start_condition;
    end else begin
      probability := lb.start_probability+(lb.start_condition-GetCurrentCondition(wpn))* (1-lb.start_probability)/(lb.start_condition-lb.end_condition);
    end;

    if random<probability then begin
      SetWeaponMultipleBonesStatus(wpn, laserdot_data.ray_bones, false);
      buf.StopLaserdotParticle();
      exit;
    end;
  end;


  HID :=CHudItem__HudItemData(wpn);
  if (HID<>nil) and (GetActorActiveItem()=wpn)then begin // and (not IsDemoRecord()) then begin
    //1st person view
    if (IsAimNow(wpn) or IsHolderInAimState(wpn)) and (not IsGrenadeMode(wpn)) then begin
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

function GetOrdinalAmmoType(wpn:pointer):byte; stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if (buf <> nil) and game_ini_r_bool_def(GetHUDSection(wpn), 'ammo_params_use_previous_shot_type', false) then begin
    //за тип секции отвечает тип последнего патрона, которым был произведен выстрел
    result:=buf.GetLastShotAmmoType();
  end else if game_ini_r_bool_def(GetHUDSection(wpn), 'ammo_params_use_last_cartridge_type', false) and (GetAmmoInMagCount(wpn)>0) then begin
    //если указан этот параметр, то в остальных режимах за тип секции отвечает тип последнего патрона в магазине
    result:=GetCartridgeType(GetCartridgeFromMagVector(wpn, GetAmmoInMagCount(wpn)-1));
  end else begin
    result:=GetAmmoTypeIndex(wpn, IsGrenadeMode(wpn));
  end;
end;

function GetGlAmmotype(wpn:pointer):byte; stdcall;
begin
  result:=GetAmmoTypeIndex(wpn, not IsGrenadeMode(wpn));
end;

procedure ProcessAmmoAdv(wpn: pointer; forced:boolean=false);
var
  hud_sect:PChar;
  bones_sect:PChar;
  bones:PChar;
  cnt, ammotype:integer;
  sect_w_ammotype:string;
  g_b:boolean;
  ejection_delay:cardinal;
  param:string;
begin
  hud_sect:=GetHUDSection(wpn);
  g_b:=IsGrenadeMode(wpn);

  if (not g_b) and (GetCurrentState(wpn)=cardinal(EWeaponStates__eFire)) and not forced and game_ini_r_bool_def(hud_sect, 'ammo_params_toggle_shooting', false) then begin
    //во время стрельбы не производить обновление костей - нужно для корректных гильз у дробовиков
    exit;
  end;

  cnt:=GetAmmoInMagCount(wpn);

  if g_b then begin
    //Оружие в режиме стрельбы подстволом
    ammotype:=GetOrdinalAmmoType(wpn);

  end else if (GetCurrentState(wpn)=cardinal(EWeaponStates__eReload)) then begin
    if IsWeaponJammed(wpn) then begin
      //идет расклин
      ammotype:=GetOrdinalAmmoType(wpn);
    end else if IsTriStateReload(wpn)  then begin
      //идет перезарядка по типу дробовика
      if (leftstr(GetActualCurrentAnim(wpn), length('anm_open'))='anm_open') then begin
        // если в anm_open есть извлечение предыдущей гильзы - остановим обновление костей на это время
        param:='ejection_delay_'+GetActualCurrentAnim(wpn);
        ejection_delay:=game_ini_r_int_def(GetHUDSection(wpn), PAnsiChar(param), 0);
        if (ejection_delay > 0) and (GetTimeDeltaSafe(GetAnimTimeState(wpn, ANM_TIME_START), GetAnimTimeState(wpn, ANM_TIME_CUR)) < ejection_delay) then begin
          exit;
        end;
      end;

      ammotype:=GetAmmoTypeToReload(wpn);
    end else begin
      //идет обычная перезарядка
      //патрон в патроннике может быть старого типа! учитываем это
      //обновление синхронно со счетчиком
      ammotype:=GetAmmoTypeIndex(wpn, g_b);

      //Хак для неправильно заанимированных моделей вроде сайги - при обычных релоадах нам может потребоваться отображать в магазине на один патрон МЕНЬШЕ
      //чем в реальности - они не учитывают патрон в патроннике! Поэтому если на счетчике 1, и мы жмем релоад, в магазине будет "лишний" патрон! Хотя магазин как раз должен быть пуст
      if game_ini_r_bool_def(hud_sect, 'minus_ammo_in_usual_reloads', false) and (cnt >= 1) and (Pos('_empty', GetActualCurrentAnim(wpn))=0) then begin
        cnt:=cnt-1;
      end;
    end
  end else begin
    //не в состоянии перезарядки, подствол выключен
    ammotype:=GetOrdinalAmmotype(wpn);

    //Хак для неправильно заанимированных моделей, не учитывающих патрон в патроннике - нам может потребоваться отображать в магазине на один патрон МЕНЬШЕ
    if game_ini_r_bool_def(hud_sect, 'minus_ammo_in_bore', false) and (cnt >= 1) and (leftstr(GetActualCurrentAnim(wpn), length('anm_bore'))='anm_bore') then begin
      cnt:=cnt-1;
    end;
  end;

  bones_sect:=nil;
  sect_w_ammotype:='ammo_params_section_'+inttostr(ammotype);
  if game_ini_line_exist(hud_sect, PChar(sect_w_ammotype)) then begin
    bones_sect:= game_ini_read_string(hud_sect, PChar(sect_w_ammotype));
  end else if game_ini_line_exist(hud_sect, 'ammo_params_section') then begin
    bones_sect:= game_ini_read_string(hud_sect, 'ammo_params_section');
  end;

  if bones_sect<>nil then begin
    if (IsWeaponJammed(wpn) and game_ini_line_exist(bones_sect, 'additional_ammo_bone_when_jammed') and game_ini_r_bool(bones_sect, 'additional_ammo_bone_when_jammed')) then
      cnt:=cnt+1;

    //скрываем все
    bones:= game_ini_read_string(bones_sect, 'all_bones');
    SetWeaponMultipleBonesStatus(wpn, bones, false);

    //отображаем нужные
    if game_ini_line_exist(bones_sect, PChar('configuration_'+inttostr(cnt))) then begin
      bones:= game_ini_read_string(bones_sect, PChar('configuration_'+inttostr(cnt)));
      SetWeaponMultipleBonesStatus(wpn, bones, true);
    end;
  end;
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
    if cnt = 0 then begin
      //Тут нужно использовать именно GetAmmoTypeToReload, а не GetGlAmmoType, иначе при смене типа гранаты после выстрела схема не просечет, что нужно изменить скин, и отрисует грену другого типа
      ammotype:=GetAmmoTypeToReload(wpn);
       cnt:=1;
    end else begin
      //Очевидно, смена типа - а в случае, когда граната вытаскивается визуально, в начале смены типа необходимо показывать старый тип
      ammotype:=GetGlAmmoType(wpn);
    end;
  end else begin
    ammotype:=GetGlAmmoType(wpn);
  end;

  bones_sect:=nil;
  sect_w_ammotype:='gl_ammo_params_section_'+inttostr(ammotype);
  if game_ini_line_exist(hud_sect, PChar(sect_w_ammotype)) then begin
    bones_sect:= game_ini_read_string(hud_sect, PChar(sect_w_ammotype));
  end else if game_ini_line_exist(hud_sect, 'gl_ammo_params_section') then begin
    bones_sect:= game_ini_read_string(hud_sect, 'gl_ammo_params_section');
  end;

  if bones_sect<>nil then begin
    //скрываем все
    bones:= game_ini_read_string(bones_sect, 'all_bones');
    SetWeaponMultipleBonesStatus(wpn, bones, false);

    //отображаем нужные
    if game_ini_line_exist(bones_sect, PChar('configuration_'+inttostr(cnt))) then begin
      bones:= game_ini_read_string(bones_sect, PChar('configuration_'+inttostr(cnt)));
      SetWeaponMultipleBonesStatus(wpn, bones, true);
    end;
  end;
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

  prefix_hide:=game_ini_read_string_def(hud_sect, 'ammo_hide_bones_prefix', '');
  prefix_var:=game_ini_read_string_def(hud_sect, 'ammo_var_bones_prefix', '');
  start_index:=game_ini_r_int_def(hud_sect, 'start_ammo_bone_index', 0);
  limitator:=game_ini_r_int_def(hud_sect, 'end_ammo_bone_index', 0);

  finish_index:=start_index+GetAmmoInMagCount(wpn)-1;

  if IsWeaponJammed(wpn) and game_ini_line_exist(hud_sect, 'additional_ammo_bone_when_jammed') and game_ini_r_bool(hud_sect, 'additional_ammo_bone_when_jammed') then
    finish_index:=finish_index+1;

  if game_ini_line_exist(hud_sect, 'ammo_divisor_up') then
    finish_index:=ceil(finish_index/game_ini_r_int_def(hud_sect, 'ammo_divisor_up', 1))
  else if game_ini_line_exist(hud_sect, 'ammo_divisor_down') then
    finish_index:=floor(finish_index/game_ini_r_int_def(hud_sect, 'ammo_divisor_down', 1));

  if finish_index>limitator then finish_index:=limitator;

//  if wpn=GetActorActiveItem() then SendMessage(PChar(inttostr(start_index)+' '+PChar(inttostr(finish_index))+' '+PChar(inttostr(limitator))));

  for i:=start_index to finish_index do begin
    SetWeaponModelBoneStatus(wpn, PChar(prefix+inttostr(i)), true);
    if length(prefix_hide) > 0 then begin
      SetWeaponModelBoneStatus(wpn, PChar(prefix_hide+inttostr(i)), false);
    end;
  end;
  for i:= finish_index+1 to limitator do begin
    SetWeaponModelBoneStatus(wpn, PChar(prefix+inttostr(i)), false);
    if length(prefix_hide) > 0 then begin
      SetWeaponModelBoneStatus(wpn, PChar(prefix_hide+inttostr(i)), true);
    end;
  end;

  if (length(prefix_var) > 0) then begin
    for i:= start_index-1 to limitator do begin
      SetWeaponModelBoneStatus(wpn, PChar(prefix_var+inttostr(i)), i=finish_index);
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

function GetFiremodeSuffix(wpn:pointer):string; stdcall;
var
  firemode:integer;
begin
  firemode:=CurrentQueueSize(wpn);
  if firemode<0 then begin
    result:='_a';
  end else begin
    result:='_'+inttostr(firemode);
  end;
end;

procedure ProcessFiremode(wpn:pointer); stdcall;
var
  hud_sect:PAnsiChar;
  firemode_mark:string;
begin
  hud_sect:=GetHUDSection(wpn);
  if game_ini_line_exist(hud_sect, 'firemode_bones_total') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(hud_sect, 'firemode_bones_total'), false);
  firemode_mark:='firemode_bones'+GetFiremodeSuffix(wpn);
  if game_ini_line_exist(hud_sect, PAnsiChar(firemode_mark)) then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(hud_sect, PAnsiChar(firemode_mark)), true);
end;

type
UpgradeProcessResults = packed record
  hud_overriden:boolean;
  visual_overriden:boolean;
end;

function ProcessUpgrade(wpn:pointer):UpgradeProcessResults; stdcall;
var all_upgrades:string;
    section:PChar;
    new_hud_sect, old_hud_sect:PAnsiChar;
    up_gr_sect:string;
    i:integer;
    buf:WpnBuf;
    lens_params:lens_zoom_params;
    t_dt:single;
    gl_status:cardinal;
    gl_enabled:boolean;
begin
  result.hud_overriden:=false;
  result.visual_overriden:=false;

  section:=GetSection(wpn);
  buf:=GetBuffer(wpn);

  gl_status:=GetGLStatus(wpn);
  gl_enabled:=(gl_status>0) and IsGrenadeMode(wpn);

  //Скроем все кости, которые надо скрыть, исходя из данных секции оружия
  if game_ini_line_exist(section, 'def_hide_bones') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'def_hide_bones'), false);
  if game_ini_line_exist(section, 'def_show_bones') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'def_show_bones'), true);
  if gl_enabled and game_ini_line_exist(section, 'def_hide_bones_grenade') and not (leftstr(GetActualCurrentAnim(wpn), length('anm_switch'))='anm_switch') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'def_hide_bones_grenade'), false);

  //Прочитаем секции всех доступных апов из конфига
  if game_ini_line_exist(section, 'upgrades') then begin
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
        old_hud_sect:=GetHUDSection(wpn);
        new_hud_sect:=old_hud_sect;

        if IsSilencerAttached(wpn) and game_ini_r_bool_def(section, 'hud_when_silencer_is_attached', false) then begin
          new_hud_sect:=game_ini_read_string(section, 'hud_silencer');
          result.hud_overriden:=true;
        end else if (GetGLStatus(wpn) = 2) and IsGLAttached(wpn) and game_ini_r_bool_def(section, 'hud_when_gl_is_attached', false) then begin
          new_hud_sect:= game_ini_read_string(section, 'hud_gl');
          result.hud_overriden:=true;
        end else if IsScopeAttached(wpn) and game_ini_r_bool_def(section, 'hud_when_scope_is_attached', false) then begin
          new_hud_sect:=game_ini_read_string(section, 'hud_scope');
          result.hud_overriden:=true;
        end else begin
          new_hud_sect:=game_ini_read_string(section, 'hud');
          if new_hud_sect = 'skip_reassign' then begin
            new_hud_sect:=old_hud_sect;
          end else begin
            result.hud_overriden:=true;
          end;
        end;

        if new_hud_sect<>old_hud_sect then begin
          SetHUDSection(wpn, new_hud_sect);
        end;
      end;
      if game_ini_line_exist(section, 'visual') then begin
        result.visual_overriden:=true;
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
        lens_params:=buf.GetLensParams();
        t_dt:=game_ini_r_single_def(section, 'lens_factor_levels_count', 0);

        if t_dt <> 0 then begin
          lens_params.delta:=1.0/t_dt;
        end;
        lens_params.factor_min:=game_ini_r_single_def(section, 'min_lens_factor', lens_params.factor_min);
        lens_params.factor_max:=game_ini_r_single_def(section, 'max_lens_factor', lens_params.factor_max);
        lens_params.speed:=game_ini_r_single_def(section, 'lens_speed', lens_params.speed);
        lens_params.gyro_period:=game_ini_r_single_def(section, 'lens_gyro_sound_period', lens_params.gyro_period);
        buf.SetLensParams(lens_params);
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


      if (IsSilencerAttached(wpn)) then begin
        if game_ini_line_exist(section, 'hide_bones_override_when_silencer_attached') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'hide_bones_override_when_silencer_attached'), false);
      end;

      if (IsScopeAttached(wpn)) then begin
        if game_ini_line_exist(section, 'hide_bones_override_when_scope_attached') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'hide_bones_override_when_scope_attached'), false);
      end;

      if ((gl_status=1) or ((gl_status=2) and IsGLAttached(wpn)) ) then begin
        if game_ini_line_exist(section, 'hide_bones_override_when_gl_attached') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'hide_bones_override_when_gl_attached'), false);
      end;

      if gl_enabled and not (leftstr(GetActualCurrentAnim(wpn), length('anm_switch'))='anm_switch') then begin
        if game_ini_line_exist(section, 'hide_bones_override_grenade') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'hide_bones_override_grenade'), false);
      end;
    end;
  end;

  section:=GetSection(wpn);
  if ((gl_status=1) or ((gl_status=2) and IsGLAttached(wpn)) ) then begin
    if game_ini_line_exist(section, 'def_hide_bones_override_when_gl_attached') then begin
      SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'def_hide_bones_override_when_gl_attached'), false);
    end;
  end;

end;

procedure ProcessScope(wpn:pointer); stdcall;
var
    tmp:string;
    status:boolean;
    cur_index, i:integer;
    total_scope_cnt:cardinal;
begin
  if IsScopeAttached(wpn) and (GetScopeStatus(wpn)=2) then cur_index:=GetCurrentScopeIndex(wpn) else cur_index:=-1;
  total_scope_cnt:=GetScopesCount(wpn);

  for i:=0 to total_scope_cnt-1 do begin
    tmp:=GetScopeSection(wpn, i);
    if i=cur_index then status:=true else status:=false;

    if game_ini_line_exist(PChar(tmp), 'bones') then begin;
      SetWeaponMultipleBonesStatus(wpn,game_ini_read_string(PChar(tmp), 'bones'), status);
    end;
    if game_ini_line_exist(PChar(tmp), 'hide_bones') then begin
      SetWeaponMultipleBonesStatus(wpn,game_ini_read_string(PChar(tmp), 'hide_bones'), not status);
    end;
  end;

  if (cur_index>=0) then begin
    tmp:=GetScopeSection(wpn, cur_index);
    if game_ini_line_exist(PChar(tmp), 'overriding_hide_bones') then begin
      SetWeaponMultipleBonesStatus(wpn,game_ini_read_string(PChar(tmp), 'overriding_hide_bones'), false);
    end;
    if game_ini_line_exist(PChar(tmp), 'overriding_show_bones') then begin
      SetWeaponMultipleBonesStatus(wpn,game_ini_read_string(PChar(tmp), 'overriding_show_bones'), true);
    end;
  end else begin
    tmp:=GetSection(wpn);
    if game_ini_line_exist(PChar(tmp), 'no_scope_overriding_hide_bones') then begin
      SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(PChar(tmp), 'no_scope_overriding_hide_bones'), false);
    end;
    if game_ini_line_exist(PChar(tmp), 'no_scope_overriding_show_bones') then begin
      SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(PChar(tmp), 'no_scope_overriding_show_bones'), true);
    end;
  end;
end;

procedure AddSuffixIfStringExist(sect:PChar; suffix:PChar; var anm:string);
var
  newanm:string;
begin
  newanm := anm + suffix;
  if (length(game_ini_read_string_def(sect, PChar(newanm), '')) > 0) then begin
    anm := newanm;
  end;
end;

procedure ReassignWorldAnims(wpn:pointer); stdcall;
var
  sect:PChar;
  anm:string;
  state:cardinal;
  bmixin:boolean;
begin

  state:=cardinal(GetNextState(wpn));
  if (not GetAnimForceReassignStatus(wpn)) then exit;
  sect:=GetSection(wpn);
  if not game_ini_r_bool_def(sect, 'use_world_anims', false) then exit;

  bmixin:=true;
  if state=EHudStates__eIdle then begin
    anm:='wanm_idle';
  end else if state=EHudStates__eShowing then begin
    anm:='wanm_draw'
  end else if state=EHudStates__eHiding then begin
    anm:='wanm_holster';
  end else if state=EWeaponStates__eFire then begin
    anm:='wanm_shoot';
    if GetAmmoInMagCount(wpn)<=0 then begin
	  AddSuffixIfStringExist(sect, '_last', anm);
    end;
  end else if state=EWeaponStates__eReload then begin
    anm:='wanm_reload';
  end else begin
    anm:='wanm_idle';
  end;

  if (length(game_ini_read_string_def(sect, PChar(anm), '')) = 0) then begin
    anm:='wanm_idle';
  end;

  if IsWeaponJammed(wpn) then begin
	AddSuffixIfStringExist(sect, '_jammed', anm);
  end else if (GetAmmoInMagCount(wpn)<=0) and (state<>EWeaponStates__eFire) then begin
    AddSuffixIfStringExist(sect, '_empty', anm);
  end else if (IsFirstShotAnimationNeeded(wpn)) and IsJustAfterReload(wpn) and (state<>EWeaponStates__eFire) then begin
    AddSuffixIfStringExist(sect, '_first', anm);
  end;

  AddSuffixIfStringExist(sect,PChar(GetFiremodeSuffix(wpn)), anm);

  if IsGrenadeMode(wpn) then begin
	AddSuffixIfStringExist(sect, '_g', anm);
  end else if (GetGLStatus(wpn)=1) or ((GetGLStatus(wpn)=2) and IsGLAttached(wpn)) then begin
	AddSuffixIfStringExist(sect, '_w_gl', anm);
  end;

if GetSection(wpn)='wpn_protecta' then begin
  log('play '+ anm);
end;

  PlayCycle(wpn, game_ini_read_string(sect,PChar(anm)), bmixin);

  SetAnimForceReassignStatus(wpn, false);
end;

function CastToCWeapon(CObject:pointer):pointer; stdcall;
begin
  result:=dynamic_cast(CObject, 0, RTTI_CObject, RTTI_CWeapon, false);
end;

procedure CheckRLHasActiveRocket(wpn:pointer; rl:pointer); stdcall;
var
  n, p:FVector3;
  sect:PChar;
  cond, start_tr, end_tr,start_prob, end_prob:single;
  is_expl:boolean;
  r:pCCustomRocket;
  act:pointer;
  is_act_own:boolean;
begin
  act:=GetActor();
  is_act_own:=(act<>nil) and (act=GetOwner(wpn));

  if GetRocketsCount(rl)>0 then begin
    if (not IsActionProcessing(wpn) or (is_act_own and IsActorControlled())) and (GetAmmoInMagCount(wpn)>0)  then begin
      sect:=GetSection(wpn);

      start_tr:=game_ini_r_single_def(sect, 'rocket_misfunc_start_condition', 0);
      end_tr:=game_ini_r_single_def(sect, 'rocket_misfunc_end_condition', 0);
      start_prob:=game_ini_r_single_def(sect, 'rocket_misfunc_start_probability', 0);
      end_prob:=game_ini_r_single_def(sect, 'rocket_misfunc_end_probability', 0);
      cond:=GetCurrentCondition(wpn);

      if (GetOwner(wpn)<>GetActor()) or (cond>start_tr) or (start_tr=end_tr) then begin
        is_expl:=false;
      end else if cond<end_tr then begin
        is_expl:= random < end_prob;
      end else begin
        is_expl:= random < start_prob+(end_prob-start_prob)*(start_tr-cond)/(start_tr-end_tr);
      end;

      if (IsActorControlled() and is_act_own) or is_expl then begin
        p:=FVector3_copyfromengine(GetPosition(wpn));
        n.x:=0;
        n.y:=1;
        n.z:=0;
        r:=GetRocket(rl, 0);
        DetachRocket(rl, GetCObjectID(r), true);
        virtual_CCustomRocket__Contact(r, @p, @n);

        UnloadRockets(rl);
        virtual_CWeaponMagazined__UnloadMagazine(wpn, false);
      end else begin
        virtual_Action(wpn, kWPN_FIRE, kActPress);
      end;
    end else begin
      UnloadRockets(rl);
    end;
  end;
end;

procedure CWeapon__ModUpdate(wpn:pointer); stdcall;
var
  buf:WpnBuf;
  sect:PChar;

  offset:integer;
  slot, prevslot:integer;

  probability, probability2:single;
  collim_problems_cnt:single;

  bp:conditional_breaking_params;
  last_rec_time:cardinal;
  lens_recoil:FVector3;
  val, len:single;
  rl:pCRocketLauncher;

  gl_ammocnt, gl_ammotype:byte;
  so:pointer;
  need_bones_recheck:boolean;
  k:single;

  upgrade_results:UpgradeProcessResults;
  cur_hud_sect, new_hud_sect:PAnsiChar;

  cb:TAnimationEffector;
const
  EPS:single = 0.0001;
begin
    so:=get_server_object_by_id(GetID(wpn));
    if so=nil then exit;
    sect:=GetSection(wpn);

    rl:=dynamic_cast(wpn, 0, RTTI_CWeapon, RTTI_CWeaponMagazinedWGrenade, false);
    if (rl<>nil) then begin
      rl:=dynamic_cast(wpn, 0, RTTI_CWeapon, RTTI_CRocketLauncher, false);
      if GetRocketsCount(rl)>0 then begin
        CWeaponMagazinedWGrenade__LaunchGrenade(wpn); // не rl - функция ждет CWeaponMagazinedWGrenade!
      end;

      //[bug] баг - отсутствует выставление a_elapsed_grenades в апдейт-пакете, из-за чего грены прогружаются некорректно. По-хорошему, надо править не так топорно, а модифицированием методов экспорта и импорта нетпакетов
      gl_ammocnt:=GetAmmoInGLCount(wpn);
      if gl_ammocnt>0 then begin
        gl_ammotype:=GetCartridgeType(GetGrenadeCartridgeFromGLVector(wpn, gl_ammocnt-1));
      end else begin
        gl_ammotype:=GetAmmoTypeIndex(wpn, not IsGrenadeMode(wpn))
      end;
      pbyte(cardinal(so)+$1A8)^:=(gl_ammotype shl 6) + (gl_ammocnt and $3F);
    end else begin
      rl:=dynamic_cast(wpn, 0, RTTI_CWeapon, RTTI_CRocketLauncher, false);
      if (rl<>nil) then begin
        CheckRLHasActiveRocket(wpn, rl);
      end;
    end;

    if IsItemActionAnimator(wpn) then begin
        if (wpn=GetActorActiveItem()) then begin
          if (GetCurrentState(wpn)=EHudStates__eShowing) then begin
            if (GetActorTargetSlot()=GetActorActiveSlot()) and not game_ini_r_bool_def(sect, 'disable_autochange_slot', false) then begin
              prevslot:=GetActorPreviousSlot();
//              log ('activating '+inttostr(prevslot)+', state='+inttostr(GetCurrentState(wpn)));
              if (prevslot>=0) and (prevslot<>GetActorActiveSlot()) and (ItemInSlot(GetActor, prevslot)<>nil) then
                ActivateActorSlot(prevslot)
              else
                ActivateActorSlot(0);
            end;
          end else begin
//            log(inttostr(GetCurrentState(wpn)));
            cb:=GetActorActionCallback();
            if (GetActorTargetSlot()=GetActorActiveSlot()) and ((GetCurrentState(wpn)<>EHudStates__eIdle)) and IsActorActionAnimatorAutoshow() and ((@cb<>nil) or not game_ini_r_bool_def(sect, 'disable_autochange_slot', false)) then begin
              virtual_CHudItem_SwitchState(wpn, EHudStates__eShowing);
            end;
          end;
        end else begin
          if (GetActor=nil) or (GetOwner(wpn)<>GetActor()) then begin
            alife_release(get_server_object_by_id(GetID(wpn)));
          end else begin
            slot:=game_ini_r_int_def(sect, 'slot', 0)+1;
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

      if (game_ini_line_exist(sect, 'collimator_sights_bones')) then begin
        bp:=buf.GetCollimatorBreakingParams();
        if ((GetAimFactor(wpn)>0) and (buf.IsLastZoomAlter() or (buf.GetAlterZoomDirectSwitchMixupFactor() > EPS)) and game_ini_r_bool_def(sect,'hide_collimator_sights_in_alter_zoom', true)) or (GetCurrentCondition(wpn)<bp.end_condition) then begin
          SetWeaponMultipleBonesStatus(wpn,game_ini_read_string(sect, 'collimator_sights_bones'), false);
        end else if (GetCurrentCondition(wpn)<bp.start_condition) or ( CurrentElectronicsProblemsCnt() > 0 ) then begin
          if (bp.start_condition=bp.end_condition) then begin
            probability := bp.end_condition;
          end else begin
            probability := bp.start_probability+(bp.start_condition-GetCurrentCondition(wpn))* (1-bp.start_probability)/(bp.start_condition-bp.end_condition);
          end;

          collim_problems_cnt := buf.GetCollimatorProblemsLevel();
          if ( CurrentElectronicsProblemsCnt() > 0 ) and ( collim_problems_cnt > 0) then begin
            if CurrentElectronicsProblemsCnt() >= collim_problems_cnt then begin
              probability := 1;
            end else begin
              probability2 := CurrentElectronicsProblemsCnt() / collim_problems_cnt;
              if probability2 > probability then begin
                probability:= probability2;
              end;
            end;
          end;

          SetWeaponMultipleBonesStatus(
                                        wpn,
                                        game_ini_read_string(sect, 'collimator_sights_bones'),
                                        not (random<probability)
                                      );

        end else begin
          SetWeaponMultipleBonesStatus(wpn,game_ini_read_string(sect, 'collimator_sights_bones'), true);
        end;
      end;
    end;

    if ((GetActor()=nil) or (GetOwner(wpn)<>GetActor())) or (GetActorActiveItem()<>wpn) then begin
      if IsExplosed(wpn) then OnWeaponExplode_AfterAnim(wpn, 0);
      if leftstr(GetCurAnim(wpn), length('anm_attach_scope_'))='anm_attach_scope_' then DetachAddon(wpn, 1);
      if leftstr(GetCurAnim(wpn), length('anm_attach_gl'))='anm_attach_gl' then DetachAddon(wpn, 2);
      if leftstr(GetCurAnim(wpn), length('anm_attach_sil'))='anm_attach_sil' then DetachAddon(wpn, 4);
    end;


    if (GetOwner(wpn)=nil) or (dynamic_cast(GetOwner(wpn), 0, RTTI_CObject, RTTI_CEntityAlive, false) <> nil) then begin
      // Оптимизация - выполняем или не выполняем все действия пачкой, чтобы не получилось рассинхрона.
      if IsHardUpdates() then begin
        k:=2;
      end else begin
        k:=1;
      end;

      need_bones_recheck:=NeedUpdateBonesCheck(wpn);

      if need_bones_recheck or ((GetOwner(wpn)=GetActor()) and (GetActor()<>nil) and (GetCurrentFrame() mod 10 = 0) ) then begin
        //Обработаем установленные апгрейды
        upgrade_results:=ProcessUpgrade(wpn);
        if (GetInstalledUpgradesCount(wpn)>0) and (not upgrade_results.hud_overriden) then begin
          cur_hud_sect:=GetHUDSection(wpn);
          new_hud_sect:=cur_hud_sect;

          if IsSilencerAttached(wpn) and game_ini_r_bool_def(sect, 'hud_when_silencer_is_attached', false) then begin
            if buf<>nil then begin
              new_hud_sect:=buf.GetDefaultHudSectionSil();
            end else begin
              new_hud_sect:=game_ini_read_string(sect, 'hud_silencer');
            end;
          end else if (GetGLStatus(wpn) = 2) and IsGLAttached(wpn) and game_ini_r_bool_def(sect, 'hud_when_gl_is_attached', false) then begin
            if buf<>nil then begin
              new_hud_sect:=buf.GetDefaultHudSectionGL();
            end else begin
              new_hud_sect:=game_ini_read_string(sect, 'hud_gl');
            end;
          end else if IsScopeAttached(wpn) and game_ini_r_bool_def(sect, 'hud_when_scope_is_attached', false) then begin
            if buf<>nil then begin
              new_hud_sect:=buf.GetDefaultHudSectionScope();
            end else begin
              new_hud_sect:=game_ini_read_string(sect, 'hud_scope');
            end;
          end else begin
            if buf<>nil then begin
              new_hud_sect:=buf.GetDefaultHudSection();
            end else begin
              new_hud_sect:=game_ini_read_string(sect, 'hud');
            end;
          end;

          if cur_hud_sect <> new_hud_sect then begin
            SetHUDSection(wpn, new_hud_sect);
          end;
        end;

        //Теперь отобразим установленный прицел
        ProcessScope(wpn);
        //Разберемся с визуализацией патронов
        ProcessAmmo(wpn);
        ProcessAmmoGL(wpn);
        //Визуализация режима огня
        ProcessFiremode(wpn);
      end;
      //анимы от 3-го лица
      ReassignWorldAnims(wpn);
    end;

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

  // [bug] [thx to SkyLoader] баг оригинала - при доставании оружия на секунду мерцает перекркстие. Лечится путём добавления проверки на IsHidden
  if GetCurrentState(wpn) = EHudStates__eHidden then begin
    result:=false;
    exit;
  end;

  buf:=GetBuffer(wpn);
  if (buf<>nil) and ((buf.IsLaserInstalled() and buf.IsLaserEnabled()) or ((GetAimFactor(wpn)>0.001) and IsZoomHideCrosshair(wpn))) then begin
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
var
  patch_addr:cardinal;
begin
  result:=false;

//может прилететь что-то невалидное - отрубим
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

  //CActor::PickupModeUpdate - xrgame+268b10
  //CActor::PickupModeUpdate_COD - xrgame+267de0

  //[bug] Баг - в CActor::PickupModeUpdate кто-то поставил условие !m_pUsableObject->nonscript_usable() на поднятие с земли
  //Из-за этого при отключенном COD-режиме с земли вообще ничего не поднимается, а при включенном - не поднимается то, центр чего игра видимым не считает
  //Правим путем патчинга глупого отрицания (je -> jne)
  nop_code(xrGame_addr+$268b8d, 1, chr($74));


  result:=true;
end;
end.

