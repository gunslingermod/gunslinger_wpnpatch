unit WeaponUpdate;

interface
function Init:boolean;

implementation
uses BaseGameData, GameWrappers, WpnUtils;

var patch_addr:cardinal;

procedure ProcessUpgrade(wpn:pointer); stdcall;
var all_upgrades:string;
    all_subelements:string;
    bones:string;
    tmp:string;
    element:string;
    up_sect:string;
    section:PChar;
    up_gr_sect:string;
    i:integer;
begin
  section:=GetSection(wpn);
  //Прочитаем секции всех доступных апов из конфига
  if not game_ini_line_exist(section, 'upgrades') then exit;
  all_upgrades:=game_ini_read_string(section, 'upgrades');
  //Переберем их все
  while (GetNextSubStr(all_upgrades, up_gr_sect, ',')) do begin
    all_subelements:=game_ini_read_string(PChar(up_gr_sect), 'elements');
    while (GetNextSubStr(all_subelements, element, ',')) do begin
      up_sect:=game_ini_read_string(PChar(element), 'section');
      //Теперь посмотрим, какие кости надо отображать, когда данный апгрейд установлен
      if not game_ini_line_exist(PChar(up_sect), 'show_bones') then continue;
      bones:=game_ini_read_string(PChar(up_sect), 'show_bones');
      //И скроем их
      while (GetNextSubStr(bones, tmp, ',')) do begin
        SetWeaponModelBoneStatus(wpn, PChar(tmp), false);
      end;
    end;
  end;

  //Посмотрим, какие апгрейды уже установлены, и отобразим их
  for i:=0 to GetInstalledUpgradesCount(wpn)-1 do begin
    section:=GetInstalledUpgradeSection(wpn, i);
    section:=game_ini_read_string(section, 'section');
    if game_ini_line_exist(section, 'show_bones') then begin
      bones:=game_ini_read_string(section, 'show_bones');
      while (GetNextSubStr(bones, tmp, ',')) do begin
        SetWeaponModelBoneStatus(wpn, PChar(tmp), true);
      end;
    end;

    if game_ini_line_exist(section, 'hide_bones') then begin
      bones:=game_ini_read_string(section, 'hide_bones');
      while (GetNextSubStr(bones, tmp, ',')) do begin
        SetWeaponModelBoneStatus(wpn, PChar(tmp), false);
      end;
    end;

    if game_ini_line_exist(section, 'hud') then begin
      SetHUDSection(wpn, game_ini_read_string(section, 'hud'));
    end;

    if game_ini_line_exist(section, 'visual') then begin
      SetVisual(wpn, game_ini_read_string(section, 'visual'));
    end;
  end;
end;

procedure ProcessScope(wpn:pointer); stdcall;
var section:PChar;
    curscope:string;
    scopes:string;
    tmp:string;
    bones, bone:string;
    status:boolean;
begin
  section:=GetSection(wpn);
  if not game_ini_line_exist(section, 'scopes_sect') then exit;
  scopes:=game_ini_read_string(section, 'scopes_sect');
  if IsScopeAttached(wpn) and (GetScopeStatus(wpn)=2) then curscope:=GetCurrentScopeSection(wpn) else curscope:='';
  while (GetNextSubStr(scopes, tmp, ',')) do begin
    if not game_ini_line_exist(PChar(tmp), 'bones') then continue;
    if tmp=curscope then status:=true else status:=false;
    bones:=game_ini_read_string(PChar(tmp), 'bones');
    while (GetNextSubStr(bones, bone, ',')) do begin
      SetWeaponModelBoneStatus(wpn, PChar(bone), status);
    end;
  end;
end;

procedure WpnUpdate(wpn:pointer); stdcall;
begin
  //Обработаем установленные апгрейды
  ProcessUpgrade(wpn);
  //Теперь отобразим установленный прицел
  ProcessScope(wpn);

end;

procedure Patch();stdcall;
begin
  asm
    pushad
    pushfd
    push esi
    call WpnUpdate
    popfd
    popad
    lea edi, [esi+$2e0]
    jmp patch_addr
  end;
end;

function Init:boolean;
begin
  result:=false;
  patch_addr:=xrGame_addr+$2BC204;
  if not WriteJump(patch_addr, cardinal(@Patch), 6) then exit;
  result:=true;
end;

end.
