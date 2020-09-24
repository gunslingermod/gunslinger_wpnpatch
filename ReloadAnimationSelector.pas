unit ReloadAnimationSelector;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface
function Init:boolean;

implementation
uses BaseGameData;

var
  reload_pistols_patch_addr:cardinal;
  reload_nogl_patch_addr:cardinal;
  reload_withgl_patch_addr:cardinal;

function PistolAssaultAnimationSelector(weapon_addr:cardinal):PChar; stdcall;
asm
    pushad
    pushf

    mov ecx, weapon_addr
    //Если у нас РПГ - обрабатываем индивидуально
    mov ax, word ptr [eax]
    cmp ax, W_RPG7
    je @rpg7
    //Если в магазине нет патронов - то вариант действий один
    cmp [ecx+$690], 0
    jle @empty
    //Смотрим, не заклинило ли оружие
    cmp byte ptr [ecx+$45A], 0
    jne @jamned
    //Проверяем, не идет ли смена типа патронов
    cmp byte ptr [ecx+$6C7], $FF
    jne @changeammotype
    //Проверяем, стоит ли подствол
    test byte ptr [ecx+$460], 2
    jz @reload_nogl
    mov ebx, anm_reload_w_gl
    jmp @finish
    @reload_nogl:
    mov ebx, anm_reload
    jmp @finish

    @jamned:
    //Отменим смену типа патронов
    mov byte ptr [ecx+$6C7], $FF
    //Проверим, не последний ли патрон остался в магазине
    cmp [ecx+$690], 1
    jle @last_jamned
    //Смотрим, активен ли подствол
    test byte ptr [ecx+$460], 2
    jz @jamned_nogl
    mov ebx, anm_jamned_w_gl
    jmp @finish
    @jamned_nogl:
    mov ebx, anm_jamned
    jmp @finish

    @last_jamned:
    test byte ptr [ecx+$460], 2
    jz @jamned_nogl_last
    mov ebx, anm_jamned_last_w_gl
    jmp @finish
    @jamned_nogl_last:
    mov ebx, anm_jamned_last
    jmp @finish

    @changeammotype:
    test byte ptr [ecx+$460], 2
    jz @changingammo_nogl
    mov ebx, anm_changecartridgetype_w_gl
    jmp @finish
    @changingammo_nogl:
    mov ebx, anm_changecartridgetype
    jmp @finish

    @empty:
    //Проверяем подствол
    test byte ptr [ecx+$460], 2
    jz @empty_nogl
    mov ebx, anm_reload_empty_w_gl
    jmp @finish
    @empty_nogl:
    mov ebx, anm_reload_empty
    jmp @finish

    @rpg7:
    //проверим на клин
    cmp byte ptr [ecx+$45A], 1
    je @rpg7_jamned
    mov ebx, anm_reload
    jmp @finish
    @rpg7_jamned:
    mov ebx, anm_jamned
    jmp @finish

    @finish:
    mov @result, ebx
//-------------------------------------------------------------

    popf
    popad
end;

procedure AK74ReloadNoGLAnimationSelector;
asm
    push ecx
    push esi
    call PistolAssaultAnimationSelector
    pop ecx
    push eax

    jmp reload_nogl_patch_addr
end;

procedure AK74ReloadWithGLAnimationSelector;
asm
    push ecx
    push esi
    call PistolAssaultAnimationSelector
    pop ecx
    push eax

    jmp reload_withgl_patch_addr
end;

procedure PistolReloadAnimationSelector;
asm
    push ecx
    push esi
    call PistolAssaultAnimationSelector
    pop ecx
    push eax
    
    jmp reload_pistols_patch_addr
end;

function Init:boolean;
begin
  result:=false;
  reload_nogl_patch_addr:=xrGame_addr+$2CCFB2;
  reload_withgl_patch_addr:=xrGame_addr+$2D18AB;
  reload_pistols_patch_addr:=xrGame_addr+$2C5451;
  if not WriteJump(reload_nogl_patch_addr, cardinal(@AK74ReloadNoGLAnimationSelector), 5) then exit;
  if not WriteJump(reload_withgl_patch_addr, cardinal(@AK74ReloadWithGLAnimationSelector), 5) then exit;
  if not WriteJump(reload_pistols_patch_addr, cardinal(@PistolReloadAnimationSelector), 14) then exit;
  result:=true;
end;

end.
