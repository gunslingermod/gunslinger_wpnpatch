unit fs;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface
uses Vector, BaseGameData;

type
FileList=pxr_vector;
pFileList=^FileList;

const
	FS_ListFiles:cardinal	= 1;
	FS_ListFolders:cardinal	= 2;
	FS_ClampExt:cardinal	= 4;
	FS_RootOnly:cardinal	= 8;

procedure fs_update_path(buf:PAnsiChar{512}; root:PChar; append:PChar); stdcall;
procedure fs_file_list_open(flist:pFileList; path:PAnsiChar; flags:cardinal); stdcall;
procedure fs_file_list_close(flist:pFileList); stdcall;
function fs_file_list_count(flist:pFileList):cardinal; stdcall;
function fs_file_list_get_item(flist:pFileList; idx:cardinal):PAnsiChar; stdcall;

procedure fs_r_open(r:ppIReader; path:PAnsiChar); stdcall;
procedure fs_r_close(r:ppIReader); stdcall;

implementation

procedure fs_update_path(buf:PAnsiChar{512}; root:PChar; append:PChar); stdcall;
asm
  pushad
    mov eax, xrcore_addr
    mov ecx, [eax+$BE910]
    lea ebx, [eax+$11a00]

    push append
    push root
    push buf
    call ebx

  popad
end;

procedure fs_file_list_open(flist:pFileList; path:PAnsiChar; flags:cardinal); stdcall;
asm
  pushad
    mov eax, xrcore_addr
    mov ecx, [eax+$BE910]
    lea ebx, [eax+$ffc0]

    push flags
    push path
    call ebx  //CLocatorAPI::file_list_open

    mov ecx, flist
    mov [ecx], eax
  popad
end;

procedure fs_file_list_close(flist:pFileList); stdcall;
asm
  pushad
    mov eax, xrcore_addr
    mov ecx, [eax+$BE910]
    lea ebx, [eax+$102c0]

    push flist
    call ebx  //CLocatorAPI::file_list_open
  popad
end;

function fs_file_list_count(flist:pFileList):cardinal; stdcall;
begin
  R_ASSERT(flist <> nil, 'flist is nil', 'fs_file_list_count');

  result:=0;
  if flist^ = nil then exit;

  result:=items_count_in_vector(flist^, sizeof(PAnsiChar));
end;

function fs_file_list_get_item(flist:pFileList; idx:cardinal):PAnsiChar; stdcall;
begin
  R_ASSERT(flist <> nil, 'flist is nil', 'fs_file_list_get_item');
  result:=PAnsiChar(pcardinal(get_item_from_vector(flist^, idx, sizeof(PAnsiChar)))^);
end;

procedure fs_r_open(r:ppIReader; path:PAnsiChar); stdcall;
asm
  pushad
    mov eax, xrcore_addr
    mov ecx, [eax+$BE910]
    lea ebx, [eax+$3420]

    push path
    call ebx  //CLocatorAPI::r_open

    mov ecx, r
    mov [ecx], eax
  popad
end;

procedure fs_r_close(r:ppIReader); stdcall;
asm
  pushad
    mov eax, xrcore_addr
    mov ecx, [eax+$BE910]
    lea ebx, [eax+$10f00]

    push r
    call ebx  //CLocatorAPI::r_close
  popad
end;

end.
