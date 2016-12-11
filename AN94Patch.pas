unit AN94Patch;
//Реализация увеличенного темпа стрельбы для первых выстрелов

interface
function Init:boolean;

implementation
uses BaseGameData, GameWrappers, WpnUtils;
var rpm_loading_patch_addr:cardinal;

const
  base_dispersioned_bullets_time_delta:PChar='base_dispersioned_bullets_time_delta';

procedure AN94_RPM_Patch; stdcall;
begin
  asm
    movss xmm0, [esi+$35c]
    pushad
    pushf
    mov eax, [esi+$774] //сколько уже выстрелили в очереди
    mov ebx, [esi+$778] //сколько пуль с базовыми параметрами выпускаем
    cmp ebx, 0
    je @finish
    sub ebx, 1
    cmp eax, ebx
    jae @finish
    //Прочитаем текущую секцию оружия
    push esi
    call GetSection
    mov ebx, eax
    //Посмотрим, есть ли в ней параметр base_dispersioned_bullets_rpm
    push base_dispersioned_bullets_time_delta
    push ebx
    call game_ini_line_exist
    cmp al, 0
    je @finish
    //Прочитаем его и подменим скорострельность
    push base_dispersioned_bullets_time_delta
    push ebx
    call game_ini_r_single
    sub esp, 4
    fstp dword ptr [esp]
    movss xmm0, [esp]
    add esp, 4
    @finish:
    popf
    popad
    jmp rpm_loading_patch_addr
  end;
end;

function Init:boolean;
begin
  result:=false;
  rpm_loading_patch_addr:=xrGame_addr+$2D062F;
  if not WriteJump(rpm_loading_patch_addr, cardinal(@AN94_RPM_Patch), 8) then exit;
  result:=true;
end;

end.
