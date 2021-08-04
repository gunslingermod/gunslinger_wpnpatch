unit savedgames;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface
function Init():boolean; stdcall;

implementation
uses BaseGameData, gunsl_config, misc, sysutils;

const
  GUNS_SAVE_VER:cardinal = 1;
  GUNS_MASK:cardinal = $20200101;

  GUNS_KEY_ID_MOD_NAME:word = $0001;
  GUNS_KEY_ID_MOD_VER:word = $0002;
  GUNS_KEY_ID_AUTH_LOW:word = $0003;
  GUNS_KEY_ID_AUTH_HIGH:word = $0004;
  GUNS_KEY_ID_SAVE_VER:word = $0005;

  GUNS_UNCOMPATIBLE_SAVE:cardinal=0;
  GUNS_FULLY_COMPATIBLE_SAVE:cardinal=1;
  GUNS_ORIGINAL_GAME_SAVE:cardinal=2;
  GUNS_ANOTHER_MOD_SAVE:cardinal=3;

type
  GUNS_KEY_TYPE = (
    GUNS_KEY_TYPE_U32 = $00010000,
    GUNS_KEY_TYPE_STRINGZ = $00020000,
    GUNS_KEY_TYPE_TERMINATOR = $00030000
  );

function GetTransformedGunsSaveVer():cardinal;
begin
  result:=($FFFFFFFF-GUNS_SAVE_VER) xor GUNS_MASK;
end;

//-------------------------
procedure GetAuthVal(phigh:pcardinal; plow:pcardinal); stdcall;
var
  h, l:cardinal;
begin
  asm
    pushad
    mov ecx, xrgame_addr
    add ecx, $512834
    mov ecx, [ecx]  //xr_FS
    mov ecx, [ecx]

    mov eax, xrgame_addr
    add eax, $512600
    call [eax]
    mov l, eax
    mov h, edx
    popad
  end;

  phigh^:=h;
  plow^:=l;
end;

//-------------------------
procedure WriteGunsStringZData(packet:pointer; key_id:word; data:string);
begin
  IWriter__w_u32(packet, cardinal(GUNS_KEY_TYPE_STRINGZ) xor key_id);
  IWriter__w_stringZ(packet, PAnsiChar(data));
end;

procedure WriteGunsU32Data(packet:pointer; key_id:word; data:cardinal);
begin
  IWriter__w_u32(packet, cardinal(GUNS_KEY_TYPE_U32) xor key_id);
  IWriter__w_u32(packet, data);
end;

procedure WriteGunsDataTerminator(packet:pointer);
begin
  IWriter__w_u32(packet, cardinal(GUNS_KEY_TYPE_TERMINATOR));
end;


function ReadNextGunsU32Data(reader:pIReader; var id:word; var value:cardinal):boolean;
var
  tmp:cardinal;
begin
  result:=false;
  if ReaderElapsed(reader)<8 then exit;

  ReadFromReader(reader, @tmp, sizeof(tmp));
  if tmp and $FFFF0000 <> cardinal(GUNS_KEY_TYPE_U32) then exit;
  id:=tmp and $FFFF;

  ReadFromReader(reader, @value, sizeof(value));
  result:=true;
end;

function ReadNextGunsStringZData(reader:pIReader; var id:word; var value:string):boolean;
var
  tmp:cardinal;
  str:string;
  c:char;
begin
  result:=false;
  if ReaderElapsed(reader)<5 then exit;

  ReadFromReader(reader, @tmp, sizeof(tmp));
  if tmp and $FFFF0000 <> cardinal(GUNS_KEY_TYPE_STRINGZ) then exit;
  id:=tmp and $FFFF;

  str:='';
  c:=chr(0);
  repeat
    if c<>chr(0) then str:=str+c;
    ReadFromReader(reader, @c, sizeof(c));
  until (c = chr(0)) or (ReaderElapsed(reader)<1);

  if c = chr(0) then begin
    value:=str;
    result:=true;
  end;
end;

function ReadGunsTerminatorData(reader:pointer):boolean;
var
  tmp:cardinal;
begin
  result:=false;
  if ReaderElapsed(reader)<8 then exit;

  ReadFromReader(reader, @tmp, sizeof(tmp));
  if tmp and $FFFF0000 <> cardinal(GUNS_KEY_TYPE_TERMINATOR) then exit;

  result:=true;
end;
//-------------------------
function CSavedGameWrapper__valid_saved_game_override_internal(reader:pIReader; var version:string; var addon_name:string; var save_ver:string; var d1:cardinal; var d2:cardinal):cardinal; stdcall;
var
  ver_hdr:cardinal;
  alife_ver:cardinal;
  data_id:word;
const
  CURRENT_ALIFE_VERSION:cardinal=6;
begin
  ver_hdr:=0;
  alife_ver:=0;
  data_id:=0;
  
  version:='';
  save_ver:='';
  addon_name:='';
  d1:=0;
  d2:=0;
  
  result:=GUNS_UNCOMPATIBLE_SAVE;

  if ReaderLength(reader) < 8 then exit;

  ReadFromReader(reader, @ver_hdr, sizeof(ver_hdr));
  if ver_hdr=$FFFFFFFF then begin
    ReadFromReader(reader, @alife_ver, sizeof(alife_ver));
    if alife_ver >= CURRENT_ALIFE_VERSION then begin
      result:=GUNS_ORIGINAL_GAME_SAVE;
    end;
  end else if ver_hdr=GetTransformedGunsSaveVer() then begin
    if not ReadNextGunsU32Data(reader, data_id, d1) then exit;
    if not ReadNextGunsU32Data(reader, data_id, d2) then exit;

    if not ReadNextGunsStringZData(reader, data_id, addon_name) or (data_id<>GUNS_KEY_ID_MOD_NAME) then exit;
    if not ReadNextGunsStringZData(reader, data_id, save_ver) or (data_id<>GUNS_KEY_ID_SAVE_VER) then exit;
    if not ReadNextGunsStringZData(reader, data_id, version) or (data_id<>GUNS_KEY_ID_MOD_VER) then exit;
    if not ReadGunsTerminatorData(reader) then exit;

    if (addon_name=GetAddonName()) and (save_ver=GetSaveVer()) then begin
      result:=GUNS_FULLY_COMPATIBLE_SAVE;
    end else begin
      result:=GUNS_ANOTHER_MOD_SAVE;
    end;

    //parse original ALIFE_VERSION
    if (ReaderElapsed(reader)<4) then begin
      result:=GUNS_UNCOMPATIBLE_SAVE;
      exit;
    end;
    ReadFromReader(reader, @alife_ver, sizeof(alife_ver));
    if alife_ver < CURRENT_ALIFE_VERSION then begin
      result:=GUNS_UNCOMPATIBLE_SAVE;
    end;
  end;
end;

function CSavedGameWrapper__valid_saved_game_override(reader:pIReader):cardinal; stdcall;
var
  version, addon_name, save_ver:string;
  d1, d2:cardinal;
begin
  result:=CSavedGameWrapper__valid_saved_game_override_internal(reader, version, addon_name, save_ver, d1, d2);

  Log('Saved game status: '+inttostr(result));
  if (result = GUNS_FULLY_COMPATIBLE_SAVE) or (result = GUNS_ANOTHER_MOD_SAVE) then begin
    Log('Info: '+addon_name+'('+GetAddonName()+')'+', '+
        version+'('+GetModVer()+')'+', '+
        save_ver+'('+GetSaveVer()+')'+', '+
        inttohex(d2, 8)+inttohex(d1, 8));
  end;
end;

procedure CSavedGameWrapper__valid_saved_game_override_patch(); stdcall;
asm
  mov eax, [esp+4]

  push ebx
  push 0 //temp buf
  mov ebx, esp

  pushad
  push eax
  call CSavedGameWrapper__valid_saved_game_override
  mov [ebx], eax
  popad

  pop eax
  pop ebx
  ret
end;

procedure ConstructGunsHeader(packet:pointer); stdcall;
var
  h, l:cardinal;
begin
  GetAuthVal(@h, @l);

  //Сначала - наш хидер вместо вырезанного (-1)
  IWriter__w_u32(packet, GetTransformedGunsSaveVer());

  //Теперь - данные мода
  WriteGunsU32Data(packet, GUNS_KEY_ID_AUTH_LOW, l);
  WriteGunsU32Data(packet, GUNS_KEY_ID_AUTH_HIGH, h);
  WriteGunsStringZData(packet, GUNS_KEY_ID_MOD_NAME, GetAddonName());
  WriteGunsStringZData(packet, GUNS_KEY_ID_SAVE_VER, GetSaveVer());
  WriteGunsStringZData(packet, GUNS_KEY_ID_MOD_VER, GetModVer());

  //Завершение данных ганса
  WriteGunsDataTerminator(packet);
end;

procedure ConstructGunsHeader_Patch(); stdcall;
asm
  mov ecx, eax //оригинальный код
  mov [esp+$14], ecx

  pushad
  push ecx
  call ConstructGunsHeader
  popad
end;

function Init():boolean; stdcall;
var
  jmp_addr:cardinal;
begin
  result:=false;


  //Вырезаем в CALifeStorageManager::save запись стандартного -1 в хидере, и вместо него вызываем нашу процедуру, которая что-то запишет
  jmp_addr:=xrgame_addr+$acb2a;
  if not WriteJump(jmp_addr, cardinal(@ConstructGunsHeader_patch), 14, true) then exit;

  // В CLevel::Connect2Server заставляем auth считаться в сингле
  nop_code(xrgame_addr+$239cf3, 6);

  //Переопределяем CSavedGameWrapper::valid_saved_game
  jmp_addr:=xrgame_addr+$adae0;
  if not WriteJump(jmp_addr, cardinal(@CSavedGameWrapper__valid_saved_game_override_patch), 6, false) then exit;

  result:=true;
end;

end.
