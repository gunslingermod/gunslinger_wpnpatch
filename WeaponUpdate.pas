unit WeaponUpdate;

interface
function Init:boolean;
function WpnUpdate(wpn:pointer):boolean; stdcall;

implementation
uses BaseGameData, GameWrappers, WpnUtils, LightUtils, sysutils, WeaponAdditionalBuffer, WeaponEvents, ActorUtils, strutils;

var patch_addr:cardinal;
  tst_light:pointer;

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
begin
  section:=GetSection(wpn);
  //Скроем все кости, которые надо скрыть, исходя из данных секции оружия
  if game_ini_line_exist(section, 'def_hide_bones') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'def_hide_bones'), false);
  if game_ini_line_exist(section, 'def_show_bones') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'def_show_bones'), true);  
  
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
    if game_ini_line_exist(section, 'show_bones') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'show_bones'), true);
    if game_ini_line_exist(section, 'hide_bones') then SetWeaponMultipleBonesStatus(wpn, game_ini_read_string(section, 'hide_bones'), false);
    if game_ini_line_exist(section, 'hud') then begin
      SetHUDSection(wpn, game_ini_read_string(section, 'hud'));
    end;
    if game_ini_line_exist(section, 'visual') then begin
      SetWpnVisual(wpn, game_ini_read_string(section, 'visual'));
    end;
  end;
end;

procedure ProcessScope(wpn:pointer); stdcall;
var section:PChar;
    curscope:string;
    scopes:string;
    tmp:string;
    status:boolean;
begin
  section:=GetSection(wpn);
  if not game_ini_line_exist(section, 'scopes_sect') then exit;
  scopes:=game_ini_read_string(section, 'scopes_sect');
  if IsScopeAttached(wpn) and (GetScopeStatus(wpn)=2) then curscope:=GetCurrentScopeSection(wpn) else curscope:='';
  while (GetNextSubStr(scopes, tmp, ',')) do begin
    if tmp=curscope then status:=true else status:=false;
    if game_ini_line_exist(PChar(tmp), 'bones') then begin;
      SetWeaponMultipleBonesStatus(wpn,game_ini_read_string(PChar(tmp), 'bones'), status);
    end;
    if game_ini_line_exist(PChar(tmp), 'hide_bones') then begin
      SetWeaponMultipleBonesStatus(wpn,game_ini_read_string(PChar(tmp), 'hide_bones'), not status);
    end;
  end;
end;

function WpnUpdate(wpn:pointer):boolean; stdcall; //возвращает, стоит ли продолжать апдейт для обновления состояние оружия, или погодеть пока
const a:single = 1.0;
var buf:WpnBuf;
begin
    result:=true;
    if get_server_object_by_id(GetID(wpn))=nil then exit;

    if ((GetActor=nil) or (GetOwner(wpn)<>GetActor)) then begin
      if IsExplosed(wpn) then OnWeaponExplode_AfterAnim(wpn, 0);
      if leftstr(GetCurAnim(wpn), length('anm_attach_scope_'))='anm_attach_scope_' then DetachAddon(wpn, 1);
      if leftstr(GetCurAnim(wpn), length('anm_attach_gl'))='anm_attach_gl' then DetachAddon(wpn, 2);
      if leftstr(GetCurAnim(wpn), length('anm_attach_sil'))='anm_attach_sil' then DetachAddon(wpn, 4);

      {if (leftstr(GetCurAnim(wpn), length('anm_reload'))='anm_reload') then begin
        if (leftstr(GetCurAnim(wpn), length('anm_reload_jammed'))<>'anm_reload_jammed') then begin
          unload_magazine(wpn);
          if GetBuffer(wpn).GetBeforeReloadAmmoCnt()>0 then
            SelectAmmoInMagCount(wpn, GetMagCapacityInCurrentWeaponMode(wpn), 1);
            ReloadMag(wpn);
          end;
        end else begin
          JamWeapon(wpn);
        end;
      end;  }
    end;

    //апдейт буфера
    buf:=WeaponAdditionalBuffer.GetBuffer(wpn);
    if buf<>nil then begin
      if not buf.Update then Log('Failed to update wpn: '+inttohex(cardinal(wpn), 8));
    end;

    if GetShootLockTime(wpn)<=0 then begin
      //Обработаем установленные апгрейды
      ProcessUpgrade(wpn);
      //Теперь отобразим установленный прицел
      ProcessScope(wpn);
    end;

  {if tst_light = nil then tst_light:=LightUtils.CreateLight;
  LightUtils.Enable(tst_light, true);
  asm
    pushad
    pushfd

    mov ebp, $492ed8

    mov ebx, tst_light
    push [ebp+$38]
    push [ebp+$34]
    push [ebp+$30]
    push ebx
    call LightUtils.SetPos

    push [ebp+$44]
    push [ebp+$40]
    push [ebp+$3C]
    push ebx
    call LightUtils.SetDir

    popfd
    popad
  end;     }
end;



procedure Patch();stdcall;
asm
    movss [esp+8], xmm0
    pushad
    push esi
    call WpnUpdate
    cmp al, 1
    popad
    jne @finish
    cmp [esi+$2e8], eax
    @finish:
    ret
end;

function Init:boolean;
begin
  result:=false;
  tst_light:=nil;

  patch_addr:=xrGame_addr+$2CD369;
  if not WriteJump(patch_addr, cardinal(@Patch), 12, true) then exit;
  result:=true;
end;
end.
