unit WeaponEvents;

interface
function Init:boolean;

implementation
uses BaseGameData, GameWrappers, WpnUtils, WeaponAnims, LightUtils;

var
  jmp_addr:cardinal;

  cweaponmagazined_netspawn_patch_addr:cardinal;
  scope_attach_callback_addr:cardinal;
  upgrade_weapon_addr:cardinal;
  scope_detach_callback_addr:cardinal;


//---------------------------Присоединение глушителя------------------------------
function OnSilencerAttach(wpn:pointer):boolean;stdcall;
var
  silattach_anm:string;
  hud_sect:PChar;
begin
  hud_sect:=GetHUDSection(wpn);
  if (not game_ini_line_exist(hud_sect, 'use_silattach_anim')) or (not game_ini_r_bool(hud_sect, 'use_silattach_anim')) then begin
    result:=true;
    exit;
  end;
  silattach_anm:=ModifierStd(wpn, 'anm_attach_sil');
  result:=CustomAnmPlayer(wpn, PChar(silattach_anm), 'sndSilAtt');
end;

procedure AttachSilencer_Patch();stdcall;
begin
  asm
    pushad
    push ebp
    call OnSilencerAttach
    cmp al, 0
    popad
    
    jne @all_ok
    //Анимацию аттача начать играть не смогли. Валим из двух процедур сразу.
    pop edi //наш адрес возврата
    //восстанавливаем регистры для вызвавшей нас процедуры
    pop edi
    pop esi
    pop ebp
    xor al, al
    pop ebx
    pop ecx
    ret 8

    @all_ok:
    or byte ptr [ebp+$460],04
  end;
end;
//------------------------------------------------------------------------------

procedure CWeaponMagazined_NetSpawn_Patch();
begin
  asm
    pushad
    pushfd

    popfd
    popad

    test edi, edi
    mov [esp+$10], eax

    jmp cweaponmagazined_netspawn_patch_addr
  end;
end;

procedure AttachScope_Callback_Patch();
begin
  asm
    or byte ptr [ebp+$460],01

    pushad
    pushfd

{    call CreateLight
    mov ebx, eax

    push [ebp+$170]
    push [ebp+$16C]
    push [ebp+$168]
    push ebx
    call LightUtils.SetPos

    push 01
    push ebx
    call LightUtils.Enable  }


    popfd
    popad
    jmp scope_attach_callback_addr
  end;
end;

procedure DetachScope_Callback_Patch();
begin
  asm
    mov [esi+$460], al
    pushad
    pushfd

    //push esi
    //call WeaponVisualChanger

    popfd
    popad
    jmp scope_detach_callback_addr
  end;
end;

procedure Upgrade_Weapon_Patch();
begin
  asm
    pushad
    pushfd
    //push ebx
    //call WeaponVisualChanger
    popfd
    popad

    push ecx
    lea edx, [esp+$1c]
    jmp upgrade_weapon_addr
  end;
end;

//-----------------------------------------Переключение режимов огня------------------------
function OnChangeFireMode(wpn:pointer):boolean; stdcall;
var
  hud_sect:PChar;
begin
  result:=true;
  hud_sect:=GetHUDSection(wpn);
  if (not game_ini_line_exist(hud_sect, 'use_firemode_change_anim')) or (not game_ini_r_bool(hud_sect, 'use_firemode_change_anim')) then exit;
  result:=CustomAnmPlayer(wpn, 'anm_changefiremode', 'sndChangeFireMode');
end;

procedure ChangeFireMode_Patch(); stdcall;
begin
  asm
    pushad
    push esi
    call OnChangeFireMode
    cmp al, 0
    popad
    je @finish
    cmp byte ptr [esi+$79E],00
    @finish:
    ret
  end;
end;

//------------------------------------Событие клина(переход в состояние jammed)-------------
function OnWeaponJammed(wpn:pointer):boolean; stdcall;
var anm:string;
begin
  anm:=ModifierStd(wpn, 'anm_fakeshoot_first');
  PlayHudAnim(wpn, PChar(anm), true);
  MagazinedWpnPlaySnd(wpn, 'sndFakeFirst');
end;

procedure WeaponJammed_Patch(); stdcall;
begin
  asm
    mov byte ptr [esi+$45A],01
    xor eax, eax


{    pushad
    pushfd

    push esi
    call OnWeaponJammed

    //mov edx, [esi]
    //mov eax, [edx+$18c]
    //call eax

    popfd
    popad}


  end;
end;
//------------------------------------------------------------------------------------------
function Init:boolean;
begin
  result:=false;

  jmp_addr:= xrGame_addr+$2BD0AF;
  if not WriteJump(jmp_addr, cardinal(@WeaponJammed_Patch),16, true) then exit;

  jmp_addr:= xrGame_addr+$2CEE5A;
  if not WriteJump(jmp_addr, cardinal(@AttachSilencer_Patch),7, true) then exit;

  cweaponmagazined_netspawn_patch_addr:=xrGame_addr+$2C120B;
  if not WriteJump(cweaponmagazined_netspawn_patch_addr, cardinal(@CWeaponMagazined_NetSpawn_Patch),6) then exit;

  scope_attach_callback_addr:=xrGame_addr+$2CEE33;
  if not WriteJump(scope_attach_callback_addr, cardinal(@AttachScope_Callback_Patch), 7) then exit;

  scope_detach_callback_addr:=xrGame_addr+$2CDA8D;
  if not WriteJump(scope_detach_callback_addr, cardinal(@DetachScope_Callback_Patch), 6) then exit;

  upgrade_weapon_addr:=xrGame_addr+$2D09D6;
  if not WriteJump(upgrade_weapon_addr, cardinal(@Upgrade_Weapon_Patch), 5) then exit;

  //добавим аниму смены режима стрельбы
  jmp_addr:=xrGame_addr+$2CE2A3;
  if not WriteJump(jmp_addr, cardinal(@ChangeFireMode_Patch), 7, true) then exit;
  jmp_addr:=xrGame_addr+$2CE303;
  if not WriteJump(jmp_addr, cardinal(@ChangeFireMode_Patch), 7, true) then exit;

  result:=true;
end;

end.

