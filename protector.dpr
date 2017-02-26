library protector;

uses
  BaseGameData, GameWrappers, windows, sysutils;
  
{$R *.res}
const
  ARCHIVE_VER:word =$29A;

procedure ParseArchive(mapping_id:cardinal; size:cardinal); stdcall;
begin
  log(inttostr(mapping_id)+', '+inttostr(size));
end;

procedure CLocatorAPI__archive__open_Patch(); stdcall;
asm
  pushad
    push [esi+$0C]
    push [esi+$08]
    call ParseArchive
  popad
end;


var
  jmp_addr:cardinal;
begin
  jmp_addr:=xrCore_addr+$E1D2;
  if not WriteJump(jmp_addr, cardinal(@CLocatorAPI__archive__open_Patch), 5, false) then exit;
end.
