unit AutoUpdater;

interface

function Init:boolean;

implementation
uses BaseGameData,windows, gunsl_config, classes, sysutils, IdHashMessageDigest, strutils, ConsoleUtils;


var
  _dllhash:string;
  _modver:string;

  _dll_path:string;

  _update_str:string;

  _newpatch_src:string;
  _newpatch_dst:array [0..1024] of char;

  _patch_app:string;
  _patch_app_wrk_dir:string;


const
  _mod_name:PChar = 'gunslinger-cop';
//  _path:PChar='http://stalker.gamepolis.ru/stalkerupdate.php';
  _path:PChar='http://127.0.0.1/stalkerupdate.php';




procedure OnRunDownloadedPatch(filename:PChar; run_app:PChar{512};run_params:PChar{512}; wrk_folder:PChar{520}); stdcall;
var
  z:byte;
  rb:cardinal;
  fname:string;

  tmp:array[0..520] of char;
begin
  //смотрим на расширение патча
  //если db - закидываем его в patches, с перезаписью, если надо
  //если ехе - создаем рядом файлик с путями и запускаем на выполнение
  z:=0;
  writeprocessmemory(hndl, run_params, @z, 1, rb);
  writeprocessmemory(hndl, run_app, @z, 1, rb);
  writeprocessmemory(hndl, wrk_folder, @z, 1, rb);

  if rightstr(filename,4)='.gmf' then begin
    log('Game Archive Loaded! Preparing to install...');
    //TODO:проверка на коректность загруженных данных

    _patch_app:=GetCommandLine();
    _patch_app_wrk_dir:='';

    _newpatch_src:=filename;
    rb:=length(_newpatch_src)-4;
    fname:='';
    while (rb>0) and (_newpatch_src[rb]<>'/') and (_newpatch_src[rb]<>'\') do begin
      fname:=_newpatch_src[rb]+fname;
      rb:=rb-1;
    end;
    fname:=fname+'.db';

    fs_update_path(_newpatch_dst, '$arch_dir_patches$', PChar(fname));

  end else if rightstr(filename,4)='.exe' then begin
    fs_update_path(tmp, '$arch_dir_patches$','');

    _patch_app:='"' + filename + '" -b "' + _dll_path + '" -p "' + tmp + '"';
    _patch_app_wrk_dir:='';
  end;

  Console__Execute('quit');
end;


procedure OnRunDownloadedPatch_Patch(this:pointer; CUIWindow:pointer; void:pointer); stdcall;
asm
  pushad

  mov ebx, xrgame_addr
  mov ebx, [ebx+$512AA4]
  push ebx              //working folder

  mov ebx, xrgame_addr
  mov ebx, [ebx+$512AA0]
  push ebx              //app params

  mov ebx, xrgame_addr
  mov ebx, [ebx+$512A9C]
  push ebx              //app path

  mov eax, this
  mov eax, [eax+$2a4]
  test eax, eax
  je @p
  add eax, $10
  @p:
  push eax              //patch file

  call OnRunDownloadedPatch

  popad
end;


procedure ModifyDownloadUrl_Patch(); stdcall;
asm
  //после копирования url выходим, не добавляя суффикса... Хотя можно потом и добавить что-то
  mov eax, edi
  pop ebp
  add esp, $100
  ret
end;

procedure PatchGameSpyPatching(); stdcall;
var
  addr:cardinal;
  str:PChar;
  rb:cardinal;
const
  GS:PChar='xrGameSpy';
begin
  addr:=GetModuleHandle(GS);
  if addr=0 then exit;
  addr:=addr and $FFFF0000;

  str:=PChar(_update_str);
  writeprocessmemory(hndl, PChar(addr+$25A87), @str, 4, rb);
end;


procedure CCC_GSCheckForUpdates__Execute_Patch(); stdcall;
asm
  pushad
    call PatchGameSpyPatching
  popad
  mov edx, [eax+$26C]
end;


procedure ProcessPatching(); stdcall
var
  si:STARTUPINFO;
  pi:PROCESS_INFORMATION;
  temp_wf:PChar;
begin
  //если патч является db-архивом - копируем его и удаляем
  if (length(_newpatch_src)>0) and (_newpatch_dst[0]<>char(0)) then begin
    CopyFile(PChar(_newpatch_src), _newpatch_dst, false);
    DeleteFile(PChar(_newpatch_src));
  end;

  //теперь запустим приложение, если надо
  if _patch_app<>'' then begin
    ZeroMemory(@si, sizeof(si));
    si.cb:=sizeof(si);
    ZeroMemory(@pi, sizeof(pi));
    temp_wf:=nil;
    if length(_patch_app_wrk_dir)>0 then temp_wf:=PChar(_patch_app_wrk_dir);
    CreateProcess(nil, PChar(_patch_app), nil, nil, false, 0, nil, temp_wf, si, pi);
  end;
end;

procedure WinMain_impl_Patch(); stdcall;
asm
  mov eax, xrengine_addr
  call [eax+$6f58c] //Core._destroy

  pushad
    //убиваем мьютекс ДО того, как запускать приложение
    mov eax, [esp+$14]
    push eax
    call CloseHandle

    //скопируем архив с патчем при необходимости
    call ProcessPatching
  popad
end;


function md5(s: TStream): string;
begin
  Result := '';
  with TIdHashMessageDigest5.Create do
  try
    Result := AnsiLowerCase(AsHex(HashValue(s)));
  finally
    Free;
  end;
end; 

function Init:boolean;
var
  jmp_addr:cardinal;
  mod_name:array [0..1024] of char;

  f:TFileStream;
begin
  result:=true;

  jmp_addr:= xrgame_addr+$3b2bff;
  if not WriteJump(jmp_addr, cardinal(@ModifyDownloadUrl_Patch), 5, false) then exit;

  jmp_addr:= xrgame_addr+$334141;
  if not WriteJump(jmp_addr, cardinal(@CCC_GSCheckForUpdates__Execute_Patch), 6, true) then exit;

  jmp_addr:= xrengine_addr+$948D;
  if not WriteJump(jmp_addr, cardinal(@WinMain_impl_Patch), 6, true) then exit;

  jmp_addr:= xrgame_addr+$460480;
  if not WriteJump(jmp_addr, cardinal(@OnRunDownloadedPatch_Patch), 10, false) then exit;

  _newpatch_src:='';
  _newpatch_dst[0]:=char(0);

  _patch_app:='';
  _patch_app_wrk_dir:='';

  nop_code(xrengine_addr+$951C, 11);

  mod_name[1024]:=char(0);
  GetModuleFileNameA(mydll_handle, @mod_name, 1024);
  _dll_path:=mod_name;

{  f:=TFileStream.Create(PChar(@mod_name[0]), fmOpenRead);
  _dllhash:=md5(f);
  f.Free();}

  _dllhash:='12345';
  log('Mod DLL digest:');
  log(_dllhash);
  _modver:=GetModVer();
  log('Mod version: '+_modver);

  _update_str:=_path+'?name='+_mod_name+'&ver='+_modver+'&dllhash='+_dllhash;

  log(GetCommandLine());
end;

end.
