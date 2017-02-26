unit WeaponAmmoCounter;

interface
function Init:boolean;
procedure SelectAmmoInMagCount(wpn:pointer; default_value:integer); stdcall;

implementation
uses BaseGameData, GameWrappers, windows, WeaponAdditionalBuffer, WpnUtils;

var
  addr:cardinal;

procedure SelectAmmoInMagCount(wpn:pointer; default_value:integer); stdcall;
var curammocnt:integer;
begin
  if default_value < 0 then begin
    WeaponAdditionalBuffer.GetBuffer(wpn).SetReloadAmmoCnt(0);
    exit;
  end;
  WeaponAdditionalBuffer.GetBuffer(wpn).SetReloadAmmoCnt(default_value);
  WeaponAdditionalBuffer.GetBuffer(wpn).SetBeforeReloadAmmoCnt(GetAmmoInMagCount(wpn));

  if ((WpnUtils.GetGLStatus(wpn)=1) or (WpnUtils.IsGLAttached(wpn))) and WpnUtils.IsGLEnabled(wpn) then exit;

  curammocnt:=WpnUtils.GetAmmoInMagCount(wpn);

  if WpnUtils.IsWeaponJammed(wpn) then begin
    WpnUtils.SetAmmoTypeChangingStatus(wpn, $FF);
    WeaponAdditionalBuffer.GetBuffer(wpn).SetReloadAmmoCnt(curammocnt);
    exit;
  end;

  if  (not game_ini_line_exist(GetSection(wpn), 'ammo_in_chamber')) or (game_ini_r_bool(GetSection(wpn), 'ammo_in_chamber')=false) then exit;

  if (curammocnt=0) or (WpnUtils.GetAmmoTypeChangingStatus(wpn)<>$FF) then begin
    WeaponAdditionalBuffer.GetBuffer(wpn).SetReloadAmmoCnt(default_value-1);
    exit;
  end;
end;


procedure SelectAmmoInMagCount_Patch; stdcall;
//¬ конфиге указывать емкость на 1 большую, чем в магазине!
begin
  asm
    lea ecx, [esi-$2E0]

    pushad
    pushfd

    push ecx

    push ecx
    call WeaponAdditionalBuffer.IsReloaded
    pop ecx

    cmp al, 1
    je @noreload

    push [ecx+$694]
    jmp @doselect

    @noreload:
    push -1

    @doselect:
    push ecx
    call SelectAmmoInMagCount

    popfd
    popad
    ret

  end;
end;

//--------------------------------ѕроверка сохраненного значени€----------------

function GetSavedValue(wpn:pointer):cardinal;stdcall;
begin
  result:=WeaponAdditionalBuffer.GetBuffer(wpn).GetReloadAmmoCnt;
end;

procedure DoCompareMagCapacity(count:cardinal);stdcall;
//Ќичего не возвращает, но выставл€ет флаги!
//в esi ожидает адрес ствола
begin
  asm
    pushad

    push esi
    call GetSavedValue
    cmp count, eax

    popad
  end;
end;

procedure OnCartridgeAdded; stdcall;
begin
  asm
    //TODO:ѕри смене типа патронов помен€ть местами новый патрон и патрон в патроннике
    
    //выполним вырезанную проверку
    push eax //[esi+$690]
    call DoCompareMagCapacity
    ret
  end;
end;
//------------------------------------------------------------------------------

function Init:boolean;
var rb:cardinal;
    debug_bytes:array of byte;
    debug_addr:cardinal;
begin
  result:=false;
  setlength(debug_bytes, 8);
  ////////////////////////////////////////////////////
  //отключаем баг с моментальной сменой типа патронов при перезар€дке, когда у нас не хватает патронов текущего типа до полного магазина
  //ќно же про€вл€етс€, если у оружи€, у которого неполный магазин одного типа патронов, и такого типа в инвентаре больше нет, попробовать сменить тип и, не дожида€сь окончани€ анимы,  выбросить
  //после подъема оружие не будет реагировать на клавишу смены типа
  // причина в том, что в CWeaponMagazined::TryReload мы присваиваем значение члену m_ammoType вместо m_set_next_ammoType_on_reload
  debug_bytes[0]:=$C7;
  debug_addr:=xrGame_addr+$2D0185;
  writeprocessmemory(hndl, PChar(debug_addr), @debug_bytes[0], 1, rb);
  if rb<>1 then exit;
  ////////////////////////////////////////////////////
  //¬ырубаем смену патронов при клине
  debug_bytes[0]:=$EB;
  debug_addr:=xrGame_addr+$2D0FF8;
  writeprocessmemory(hndl, PChar(debug_addr), @debug_bytes[0], 1, rb);
  if rb<>1 then exit;
  ////////////////////////////////////////////////////
  //«апишем вызовы функции сравнени€, заменив соответствующие mov'ы на push'ы
  debug_bytes[0]:=$FF; debug_bytes[1]:=$B6; debug_bytes[2]:=$90; debug_bytes[3]:=$06; debug_bytes[4]:=$00; debug_bytes[5]:=$00;
  debug_bytes[6]:=$90; debug_bytes[7]:=$7D;
  //----------------------------------------------------
  addr:=xrGame_addr+$2D1150;
  writeprocessmemory(hndl, PChar(addr), debug_bytes, 6, rb);
  if rb<>6 then exit;
  addr:=addr+6;
  if not WriteJump(addr, cardinal(@DoCompareMagCapacity), 5, true) then exit;
  writeprocessmemory(hndl, PChar(addr), @debug_bytes[6], 1, rb);
  if rb<>1 then exit;
  //----------------------------------------------------
  addr:=xrGame_addr+$2D1214;
  writeprocessmemory(hndl, PChar(addr), debug_bytes, 6, rb);
  if rb<>6 then exit;
  addr:=addr+6;
  if not WriteJump(addr, cardinal(@DoCompareMagCapacity), 5, true) then exit;
  writeprocessmemory(hndl, PChar(addr), @debug_bytes[6], 2, rb);
  if rb<>2 then exit;
  //----------------------------------------------------


  addr:=xrGame_addr+$2CCDA0;
  if not WriteJump(addr, cardinal(@SelectAmmoInMagCount_Patch), 6, true) then exit;

  addr:=xrGame_addr+$2D11DA;
  if not WriteJump(addr, cardinal(@OnCartridgeAdded), 6, true) then exit;
  result:=true;
end;


end.
