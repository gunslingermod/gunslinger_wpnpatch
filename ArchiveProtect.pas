unit ArchiveProtect;

interface
function Init():boolean; stdcall;

implementation
uses BaseGameData, GameWrappers, windows, sysutils;

const
  ARCHIVE_VER:word =$29A;

procedure ParseArchive(mapping_id:cardinal; size:cardinal); stdcall;
var
  map_ptr:pointer;
  res:pointer;
  tst:cardinal;
begin
  if size <> 2508 then exit;
  log('id = '+inttostr(mapping_id)+', size = '+inttostr(size));

  map_ptr := MapViewOfFile(mapping_id, FILE_MAP_ALL_ACCESS,0,0,10);
  log ('mapped: '+inttohex(cardinal(map_ptr), 8));
  asm
    push eax
    mov eax, map_ptr
    mov eax, [eax]
    mov tst, eax
    pop eax
  end;
  log('val = '+ inttostr(tst));

{  asm
    push eax
    mov eax, map_ptr
    mov [eax], 1234
    pop eax
  end;   }

  UnmapViewOfFile(map_ptr);
end;

procedure CLocatorAPI__archive__open_Patch(); stdcall;
asm
  pushad
    push [esi+$0C]
    push [esi+$08]
    call ParseArchive
  popad
end;

function Init():boolean; stdcall;
var
  jmp_addr:cardinal;
  buf:cardinal;
  rb:cardinal;
begin
  result:=false;

  //в вызове CreateFileA в CLocatorAPI::LoadArchive меняем dwDesiredAccess с GENERIC_READ на GENERIC_WRITE
  buf:=GENERIC_READ+GENERIC_WRITE;
  writeprocessmemory(hndl, pointer(xrCore_addr+$E0EE), @buf, 4, rb);
  if rb<>4 then exit;

  //в вызове CreateFileMappingA в CLocatorAPI::LoadArchive меняем flProtect с PAGE_READONLY на PAGE_READWRITE
  buf:=PAGE_READWRITE;
  writeprocessmemory(hndl, pointer(xrCore_addr+$E140), @buf, 1, rb);
  if rb<>1 then exit;

  jmp_addr:=xrCore_addr+$E1D2;
  if not WriteJump(jmp_addr, cardinal(@CLocatorAPI__archive__open_Patch), 5, false) then exit;
  result:=true;
end;
end.
