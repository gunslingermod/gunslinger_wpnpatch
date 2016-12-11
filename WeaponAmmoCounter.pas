unit WeaponAmmoCounter;

interface
function Init:boolean;

implementation
uses BaseGameData, GameWrappers, windows;

var
  reload_process_selectcount_addr:cardinal;
  reload_process_reportcartridgescnt_addr:cardinal;

procedure SelectAmmoInMagCount;
//¬ конфиге указывать емкость на 1 большую, чем в магазине!
begin
  asm
    lea ecx, [esi-$2E0]
    pushad
    pushfd
    mov ebx, [ecx+$694]
    //ѕолучим в ebx число патронов, которое будем зар€жать
    //если у нас двустволка или –ѕ√ - то берем стандартное значение
    mov word ptr [ecx], ax
    cmp ax, W_BM16
    je @finish
    cmp ax, W_RPG7
    je @finish
    //≈сли непустое оружие заклинило - то надо сбросить флаг смены типа патронов, запомнить уменьшенное на 1 текущее число патронов и разр€дить его!
    cmp byte ptr [ecx+$45A], 1
    je @gun_jamned
    //≈сли мы мен€ем тип боеприпасов
    cmp byte ptr [ecx+$6C7], $FF
    jne @changingammotype
    //смотрим, есть ли в магазине патроны
    cmp [ecx+$690], 0
    jle @empty
    jmp @finish

    @gun_jamned:
    // лин оружи€
    //ќтмен€ем смену типа патронов в любом случае
    mov byte ptr [ecx+$6C7], $FF
    //≈сли оружие пустое - то действуем как при перезар€дке
    mov eax, [ecx+$690]
    cmp eax, 0
    jle @empty
    mov ebx, eax
    sub ebx, 1
    push ecx
    call unload_magazine

    jmp @finish

    @empty:
    @changingammotype:
    //ћен€ем тип патронов - никогда нет патрона в патроннике
    //TODO:запомнить факт смены при необходимости
    sub ebx, 1
    jmp @finish

    @finish:
    //сохраним число патронов в магазине перед релоадом
    //разбиваем на 2 слова, чтобы 4 байта влезли в 2 трехбайтовые дыры
    mov [ecx+$6A2], bx
    shr ebx,16
    mov [ecx+$6BE], bx

    popfd
    popad

    jmp reload_process_selectcount_addr
  end;
end;

procedure DoCompareMagCapacity(count:cardinal);stdcall;
//Ќичего не возвращает, но выставл€ет флаги!
//в esi ожидает адрес ствола
begin
  asm
    push ecx

    //читаем число патронов в оружии, которое (максимально) надо установить
    mov cx, [esi+$6BE]
    shl ecx, 16
    add cx, word ptr [esi+$6A2]
    cmp count, ecx

    pop ecx
  end;
end;

procedure OnCartridgeAdded;
begin
  asm
    //TODO:ѕри смене типа патронов помен€ть местами новый патрон и патрон в патроннике
    
    //выполним вырезанную проверку
    push eax //[esi+$690]
    call DoCompareMagCapacity
    jmp reload_process_reportcartridgescnt_addr
  end;
end;

function Init:boolean;
var rb:cardinal;
    debug_bytes:array of byte;
    debug_addr:cardinal;
begin
  result:=false;
  setlength(debug_bytes, 8);
  ////////////////////////////////////////////////////
  //отключаем моментальную смену типа патронов при перезар€дке, когда у нас не хватает патронов текущего типа до полного магазина
  //TODO: может, сделать это же дл€ остальных видов оружи€?
  debug_bytes[0]:=$C7;
  debug_addr:=xrGame_addr+$2D0185;
  writeprocessmemory(hndl, PChar(debug_addr), @debug_bytes, 1, rb);
  if rb<>1 then exit;
  ////////////////////////////////////////////////////
  //«апишем вызовы функции сравнени€, заменив соответствующие mov'ы на push'ы
  debug_bytes[0]:=$FF; debug_bytes[1]:=$B6; debug_bytes[2]:=$90; debug_bytes[3]:=$06; debug_bytes[4]:=$00; debug_bytes[5]:=$00;
  debug_bytes[6]:=$90; debug_bytes[7]:=$7D;
  //----------------------------------------------------
  reload_process_reportcartridgescnt_addr:=xrGame_addr+$2D1150;
  writeprocessmemory(hndl, PChar(reload_process_reportcartridgescnt_addr), debug_bytes, 6, rb);
  if rb<>6 then exit;
  reload_process_reportcartridgescnt_addr:=reload_process_reportcartridgescnt_addr+6;
  if not WriteJump(reload_process_reportcartridgescnt_addr, cardinal(@DoCompareMagCapacity), 5, true) then exit;
  writeprocessmemory(hndl, PChar(reload_process_reportcartridgescnt_addr), @debug_bytes[6], 1, rb);
  if rb<>1 then exit;
  //----------------------------------------------------
  reload_process_reportcartridgescnt_addr:=xrGame_addr+$2D1214;
  writeprocessmemory(hndl, PChar(reload_process_reportcartridgescnt_addr), debug_bytes, 6, rb);
  if rb<>6 then exit;
  reload_process_reportcartridgescnt_addr:=reload_process_reportcartridgescnt_addr+6;
  if not WriteJump(reload_process_reportcartridgescnt_addr, cardinal(@DoCompareMagCapacity), 5, true) then exit;
  writeprocessmemory(hndl, PChar(reload_process_reportcartridgescnt_addr), @debug_bytes[6], 2, rb);
  if rb<>2 then exit;
  //----------------------------------------------------


  reload_process_selectcount_addr:=xrGame_addr+$2CCDA0;
  reload_process_reportcartridgescnt_addr:=xrGame_addr+$2D11DA;
  if not WriteJump(reload_process_selectcount_addr, cardinal(@SelectAmmoInMagCount), 6) then exit;
  if not WriteJump(reload_process_reportcartridgescnt_addr, cardinal(@OnCartridgeAdded), 6) then exit;
  result:=true;
end;


end.
