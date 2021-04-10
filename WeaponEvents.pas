unit WeaponEvents;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface
function Init:boolean;

procedure OnWeaponExplode_AfterAnim(wpn:pointer; param:integer);stdcall;
function OnWeaponHide(wpn:pointer):boolean;stdcall;
procedure OnWeaponHideAnmStart(wpn:pointer);stdcall;
procedure OnWeaponShow(wpn:pointer);stdcall;
function OnWeaponAimIn(wpn:pointer):boolean;stdcall;
function OnWeaponAimOut(wpn:pointer):boolean;stdcall;
function Weapon_SetKeyRepeatFlagIfNeeded(wpn:pointer; kfACTTYPE:cardinal):boolean;stdcall;
function CHudItem__OnMotionMark(wpn:pointer):boolean; stdcall;

procedure TryShootGLFix(wpn:pointer); stdcall;

implementation
uses Messenger, BaseGameData, Misc, HudItemUtils, WeaponAnims, LightUtils, WeaponAdditionalBuffer, sysutils, ActorUtils, DetectorUtils, strutils, dynamic_caster, weaponupdate, KeyUtils, gunsl_config, xr_Cartridge, ActorDOF, MatVectors, ControllerMonster, collimator, level, WeaponAmmoCounter, xr_RocketLauncher, xr_strings, Throwable, UIUtils, BallisticsCorrection, RayPick, burer, HitUtils, Vector;

var
  upgrade_weapon_addr:cardinal;

//-------------------------------���������� ��������-----------------------------
procedure OnUnloadInEndOfAnim(wpn:pointer; param:integer);stdcall;
begin
  virtual_CWeaponMagazined__UnloadMagazine(wpn, true);
  ForceWpnHudBriefUpdate(wpn);
  SetAnimForceReassignStatus(wpn, true);
end;

procedure OnUnloadInMiddleAnim(wpn:pointer; param:integer);stdcall;
begin
  virtual_CWeaponMagazined__UnloadMagazine(wpn, true);
  ForceWpnHudBriefUpdate(wpn);
  MakeLockByConfigParam(wpn, GetHUDSection(wpn), PChar('lock_time_end_'+GetActualCurrentAnim(wpn)));
  SetAnimForceReassignStatus(wpn, true);
end;


function OnUnloadMag(wpn:pointer):boolean; stdcall;
var
  hud_sect: PChar;
  act:pointer;
  curanm:PChar;
const
  param_name:PChar = 'use_unloadmag_anim';
begin
  //���������� false, ���� ��������� ������ ������ ������
  result := false;

  hud_sect:=GetHUDSection(wpn);
  act:=GetActor();
  if ((act=nil) or (GetOwner(wpn)<>act)) then begin
    result:=true;
    exit;
  end;

  if IsMandatoryAnimatedUnloadMag() and (not CheckActorWeaponAvailabilityWithInform(wpn)) then exit;

  if (not game_ini_line_exist(hud_sect, param_name)) or (not game_ini_r_bool(hud_sect, param_name)) then begin
    result:=true;
    exit;
  end;

  if WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_unload_mag', 'sndUnload') then begin
    curanm:=GetActualCurrentAnim(wpn);
    StartCompanionAnimIfNeeded(rightstr(curanm, length(curanm)-4), wpn, false);
    //����� ������ ��������. ���������, ����� ���� �����������
    if game_ini_line_exist(hud_sect, PChar('lock_time_start_'+GetActualCurrentAnim(wpn))) then begin
      //���������� ���� �� ����� ����������� ����������� �������� (� �������� ��������)
      MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_start_'+curanm), false, OnUnloadInMiddleAnim);
    end else if game_ini_line_exist(hud_sect, PChar('lock_time_end_'+curanm)) then begin
      //���������� ����������� ����� ��������
      MakeLockByConfigParam(wpn, hud_sect, PChar('lock_time_end_'+curanm), false, OnUnloadInEndOfAnim);
    end else begin
      //������� �������� ���, ������� ����������� �����
      result := true;
      SetAnimForceReassignStatus(wpn, true);
    end;
  end else begin
    //����� �� ���������� - ������ ������
    result := true;
  end;
end;

procedure UnloadMag_Patch(); stdcall;
asm
  //������ ����������: add esp, 4/test eax, eax
  push eax
  mov eax, [esp+4]
  mov [esp+8], eax
  pop eax
  add esp, 4
  test eax, eax
  je @finish
  pushad
    push ecx
    call OnUnloadMag
    cmp al, 0
  popad

  @finish:
end;  

//-----------------����� ���������� ������� ������������ �������----------------
procedure OnAddonDetach(wpn:pointer; addontype:integer);stdcall;
var
  param_name:PChar;
  anim_name:string;
  addon_name:PChar;
  snd_name:PChar;
  hud_sect:PChar;
  act:pointer;
  key:cardinal;

begin
  act:=GetActor();
  if ((act=nil) or (GetOwner(wpn)<>act)) or (IsAnimatedAddons() and not CheckActorWeaponAvailabilityWithInform(wpn)) then exit;

  param_name:=nil;
  snd_name:=nil;
  case addontype of
    1:begin
        addon_name:=GetCurrentScopeSection(wpn);
        if addon_name<>nil then begin
          param_name:='use_scopedetach_anim';
          anim_name:='anm_detach_scope_'+addon_name;
          snd_name:='sndScopeDet';
        end;

        if IsAimNow(wpn) then begin
          if IsAlterZoom(wpn) then begin
            key:=kWPN_ZOOM_ALTER;
          end else begin
            key:=kWPN_ZOOM;
          end;

          if IsAimToggle() then
            virtual_Action(wpn, key, kActPress)
          else
            virtual_Action(wpn, key, kActRelease);
        end;
      end;
    4:begin
        param_name:='use_sildetach_anim';
        anim_name:='anm_detach_sil';
        snd_name:='sndSilDet';
      end;
    2:begin
        param_name:='use_gldetach_anim';
        anim_name:='anm_detach_gl';
        snd_name:='sndGLDet';

        if IsAimNow(wpn) then begin
          if IsAimToggle() then
            virtual_Action(wpn, kWPN_ZOOM, kActPress)
          else
            virtual_Action(wpn, kWPN_ZOOM, kActRelease);
        end;
      end;
    else begin
      log('WeaponEvents.OnAddonDetach: Invalid addontype!', true);
      exit;
    end;
  end;
  hud_sect:=GetHUDSection(wpn);

  CHudItem_Play_Snd(wpn, 'sndAddonDetach');  
  if (not IsAnimatedAddons()) or (param_name=nil) or (not game_ini_line_exist(hud_sect, param_name)) or (not game_ini_r_bool(hud_sect, param_name)) then begin
    DetachAddon(wpn, addontype);
    exit;
  end;
  WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, PChar(anim_name), snd_name, DetachAddon, addontype);
end;


procedure DetachAddon_Patch(addontype:integer);stdcall;
asm
  pushad
    push addontype
    push esi //CWeapon
    call OnAddonDetach
  popad
end;

function InitDetachAddon(address:cardinal; addontype:byte; nopcount:integer; writejustpush:boolean = false):boolean;
var buf:string;
begin
  result:=false;
  buf:=chr($6A)+chr(addontype);//��������� � ���������� �������� ��� �����
  if not WriteBufAtAdr(address, PChar(buf), 2) then exit;
  if not writejustpush then begin
    address:=address+2;//������ ���������� ����� ����� � ����� ������, ���� ����� �� �����
    if not WriteJump(address, cardinal(@DetachAddon_Patch), nopcount, true) then exit;
  end;
  result:=true;
end;

//-----------------����� ���������� ������� ������������� �������----------------

function OnAddonAttach(wpn:pointer; addontype:integer):boolean;stdcall;
var addonname:PChar;
    actor:pointer;
    snd_name:PChar;
    param_name:PChar;
    anim_name:string;
    hud_sect, sect:PChar;
    err_msg:PChar;
    key:cardinal;
begin
  param_name:=nil;
  snd_name:=nil;
  sect:=GetSection(wpn);
  err_msg:=nil;
  case addontype of
    1:begin
        //log ('scope_att');
        addonname:=GetCurrentScopeSection(wpn);
        if addonname=nil then log('WpnEvents.OnAddonAttach: Scope has no section?!');
        addonname:=game_ini_read_string(addonname, 'scope_name');
        param_name:='use_scopeattach_anim';
        anim_name:='anm_attach_scope_'+addonname;
        snd_name:='sndScopeAtt';

        if IsSilencerAttached(wpn) and game_ini_line_exist(sect, 'restricted_scope_and_sil') and game_ini_r_bool(sect, 'restricted_scope_and_sil')  then begin
          err_msg:='gunsl_msg_sil_restricts_scope';
        end else if IsGLAttached(wpn) and game_ini_line_exist(sect, 'restricted_scope_and_gl') and game_ini_r_bool(sect, 'restricted_scope_and_gl') then begin
          err_msg:='gunsl_msg_gl_restricts_scope';
        end else if IsAimNow(wpn) then begin
          if IsAlterZoom(wpn) then begin
            key:=kWPN_ZOOM_ALTER;          
          end else begin
            key:=kWPN_ZOOM;
          end;

          if IsAimToggle() then
            virtual_Action(wpn, key, kActPress)
          else
            virtual_Action(wpn, key, kActRelease);
        end;
      end;
    4:begin
        //log ('sil_att');
        param_name:='use_silattach_anim';
        anim_name:='anm_attach_sil';
        snd_name:='sndSilAtt';
        addonname:=GetSilencerSection(wpn);
        if IsScopeAttached(wpn) and game_ini_line_exist(sect, 'restricted_scope_and_sil') and game_ini_r_bool(sect, 'restricted_scope_and_sil')  then begin
          err_msg:='gunsl_msg_scope_restricts_sil';
        end else if IsGLAttached(wpn) and game_ini_line_exist(sect, 'restricted_gl_and_sil') and game_ini_r_bool(sect, 'restricted_gl_and_sil') then begin
          err_msg:='gunsl_msg_gl_restricts_sil';
        end;
      end;
    2:begin
        //log('gl_att');
        param_name:='use_glattach_anim';
        anim_name:='anm_attach_gl';
        snd_name:='sndGLAtt';
        addonname:=GetGLSection(wpn);
        if IsScopeAttached(wpn) and game_ini_line_exist(sect, 'restricted_scope_and_gl') and game_ini_r_bool(sect, 'restricted_scope_and_gl')  then begin
          err_msg:='gunsl_msg_scope_restricts_gl';
        end else if IsSilencerAttached(wpn) and game_ini_line_exist(sect, 'restricted_gl_and_sil') and game_ini_r_bool(sect, 'restricted_gl_and_sil') then begin
          err_msg:='gunsl_msg_sil_restricts_gl';
        end;
      end;
    else begin
      log('WeaponEvents.OnAddonAttach: Invalid addontype!', true);
      result:=true;
      exit;
    end;
  end;

  hud_sect:=GetHUDSection(wpn);
  actor:=GetActor();
  if not IsAnimatedAddons() then begin
    if err_msg<>nil then begin
      if (actor<>nil) and (actor=GetOwner(wpn)) then begin
        Messenger.SendMessage(err_msg);
      end;
      result:=false
    end else begin
      result:=true;
    end;
  end else if (actor<>nil) and (actor=GetOwner(wpn)) and (not CheckActorWeaponAvailabilityWithInform(wpn)) then begin
    //log('not_available');
    result:=false;
  end else if err_msg<>nil then begin
    //log('att_err');
    if (actor<>nil) and (actor=GetOwner(wpn)) then begin
      Messenger.SendMessage(err_msg);
    end;
    result:=false
  end else if (actor=nil) or (actor<>GetOwner(wpn)) then begin
    //log('actor_not_owner');
    result:=true;
  end else if (param_name=nil) or (not game_ini_line_exist(hud_sect, param_name)) or (not game_ini_r_bool(hud_sect, param_name)) then begin
    //log('no_param');
    result:=true;
  end else begin
    //log (anim_name);
    //log('playing...');
    result:= WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, PChar(anim_name), snd_name);
  end;

  if (not result) then begin
    //������ ������������ ����� ������. ��������� ��� ����� � ���������.
    if addontype = 1 then SetCurrentScopeType(wpn, 0);
    if (actor<>nil) and (actor=GetOwner(wpn)) then CreateObjectToActor(addonname);
  end;

  if result then begin
    CHudItem_Play_Snd(wpn, 'sndAddonAttach');
  end else begin
    CHudItem_Play_Snd(wpn, 'sndAddonAttachFail');
  end;
end;

procedure AttachAddon_Patch{(addontype:integer)}();stdcall;
asm
  push ecx
  mov ecx, [esp+8]


  push esi
  push ebx

  mov ebx, ecx

  //� ������� ������ �������� ����� addontype - ��� ������, � ������� ������ - ������ �������� � ������� ������
  //1 - ebp, 0 - esi

  and ecx, $0000000F
  and ebx, $000000F0
  shr ebx, 4

  //��������������� �� ����� ��������� �� ������

  cmp bx, 0
  je @wpnfound
  
  mov esi, ebp
  cmp bx, 1
  je @wpnfound

  @wpnfound:
  pushad
    push ecx
    push esi //CWeapon
    call OnAddonAttach
    test al, al
  popad

  je @finish
  or byte ptr [esi+$460], cl

  @finish:

  pop ebx
  pop esi
  pop ecx
  ret 4
end;

function InitAttachAddon(address:cardinal; addontype:byte):boolean;
var buf:string;
begin
  result:=false;
  buf:=chr($6A)+chr(addontype);//��������� � ���������� �������� ��� �����
  if not WriteBufAtAdr(address, PChar(buf), 2) then exit;
  address:=address+2;//������ ���������� ����� �����
  if not WriteJump(address, cardinal(@AttachAddon_Patch), 0, true) then exit;
  result:=true;
end;
//------------------------------------------------------------------------------
procedure OnCWeaponNetSpawn_middle(wpn:pointer; swpn:pointer);stdcall;
var
  scope_id, wpnstate:byte;
begin
  if WpnCanShoot(wpn) then begin
    //����� ����� ��� ���� ������ � load'e - �������� ���
    if (GetBuffer(wpn)=nil) then begin
      WpnBuf.Create(wpn);
    end;
  end;

  //� 5 ������� ����� �� ������� ���������� ������� �� ��������� ������ �������
  wpnstate:=CSE_GetAddonsFlags(swpn);
  scope_id:=wpnstate shr 3;
  if scope_id<>0 then begin
    SetCurrentScopeType(wpn, scope_id);
    wpnstate := wpnstate and $7;
  end;
  CSE_SetAddonsFlags(swpn, wpnstate);

  //��������� � ������� ���������� ���� ����� ������� m_flagsAddOnState
  if IsScopeAttached(wpn) and (GetCurrentScopeIndex(wpn) >= GetScopesCount(wpn)) then begin
    //�������� - ������ �� ����������! ���������� ����
    Log('Invalid scope ID '+inttostr(GetCurrentScopeIndex(wpn))+' for '+GetSection(wpn)+', reset ID', true);
    SetCurrentScopeType(wpn, 0);
  end;
end;

procedure OnCWeaponNetSpawn_end(wpn:pointer);stdcall;
var
  buf:WpnBuf;
  i:word;
  c:pointer;
  sect, scope_sect:PChar;
  slot:integer;

  visual:pchar;
  banned_visuals, banned_item:string;
begin

  banned_visuals:=game_ini_read_string_def(GetSection(wpn), 'banned_visuals', '');
  visual:=GetWeaponVisualName(wpn);
  if (visual<>nil) and (length(banned_visuals) > 0) then begin
    banned_visuals:=banned_visuals;
    while (GetNextSubStr(banned_visuals, banned_item, ',')) do begin
      if visual = banned_item then begin
        log('Found banned visual "'+visual+' for '+GetSection(wpn)+', reset it');
        visual:=game_ini_read_string_def(GetSection(wpn), 'visual', '');
        if length(visual) > 0 then begin
          SetWpnVisual(wpn, visual);
        end;
        break;
      end;
    end;
  end;

  //�������� ����������� ���� ��������
  if WpnCanShoot(wpn) then begin
    buf:=GetBuffer(wpn);
    if (buf<>nil) then begin
//      if (IsGLAttached(wpn))  then log(booltostr(ISGLEnabled(wpn), true));

      if (length(buf.ammos)>0) and (length(buf.ammos)=integer(GetAmmoInMagCount(wpn))) then begin
        for i:=0 to length(buf.ammos)-1 do begin
          sect:=GetMainCartridgeSectionByType(wpn, buf.ammos[i]);
          if sect<>nil then begin
            c:=GetCartridgeFromMagVector(wpn, i);
            CCartridge__Load(c, sect, buf.ammos[i]);
          end;
        end;
      end else begin
       if (GetAmmoInMagCount(wpn)>0) and (length(buf.ammos)>0) then begin
        log(PChar('There is NO ammotype data in the save??? Weapon '+GetSection(wpn)+':'+inttostr(GetID(wpn))), true)
       end else if (length(buf.ammos)<>0) and (length(buf.ammos)=integer(GetAmmoInMagCount(wpn))) then begin
        log(PChar('Count of ammotypes in the save is not equal to count of ammo in weapon '+GetSection(wpn)+':'+inttostr(GetID(wpn))), true);
       end;
      end;
      setlength(buf.ammos, 0);

      //�.�. load ����������� ������ ���������� ���������, �� ��� �������� ��� ��������� ����� ��� ���������!
      //��-�� ����� �� ��������� �������� ��������� �� ��� ������ ���� - ��� �������� ��� ����.
      scope_sect:=GetSection(wpn);
      if IsScopeAttached(wpn) and (GetScopeStatus(wpn)=2) then begin
        scope_sect:=game_ini_read_string(GetCurrentScopeSection(wpn), 'scope_name');
      end;
      buf.LoadNightBrightnessParamsFromSection(scope_sect);
    end;
  end;
  SetAnimForceReassignStatus(wpn, true);

end;

procedure CWeapon_NetSpawn_Patch_middle();
asm

    pushad
    pushfd

    push edi
    push esi
    call OnCWeaponNetSpawn_middle

    popfd
    popad

    test edi, edi
    mov [esp+$14], eax

    ret
end;


procedure CWeapon_NetSpawn_Patch_end();
asm
    mov byte ptr [esi+$6a0], al
    pushad
    pushfd

    push esi
    call OnCWeaponNetSpawn_end

    popfd
    popad
    ret
end;
//------------------------------------------------------------------------------
procedure OnCWeaponNetDestroy(wpn:pointer);stdcall;
var
  buf:WpnBuf;
begin
  buf:=WeaponAdditionalBuffer.GetBuffer(wpn);
  if buf<>nil then buf.Free;
end;

procedure CWeapon_NetDestroy_Patch();
asm

    pushad
    pushfd

    push esi
    call OnCWeaponNetDestroy

    popfd
    popad

    lea edi, [esi+$338];

    ret
end;



//---------------�������� ��� ������� ������-�� �������� � ��������-------------
procedure Upgrade_Weapon_Patch(); stdcall;
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

//-----------------------------------------������������ ������� ����------------------------

function OnChangeFireMode(wpn:pointer; new_mode:integer; isPrev:boolean):boolean; stdcall;
var
  hud_sect:PChar;
  firemode:integer;
  anm_name:string;
  det_anim:PChar;
  res:boolean;
begin
  //���������� false, ���� ������ ������ ������ ����� ����
  if isPrev then
    result:=Weapon_SetKeyRepeatFlagIfNeeded(wpn, kfPREVFIREMODE)
  else
    result:=Weapon_SetKeyRepeatFlagIfNeeded(wpn, kfNEXTFIREMODE);

  if not result then exit;


  hud_sect:=GetHUDSection(wpn);
  firemode:=CurrentQueueSize(wpn);
  if firemode=new_mode then exit; //������������ ������������ � ������ ������������� ���������� ������ ��������

  if (hud_sect=nil) or (not game_ini_line_exist(hud_sect, 'use_firemode_change_anim')) or (not game_ini_r_bool(hud_sect, 'use_firemode_change_anim')) then exit;


  anm_name:='anm_changefiremode_from_';
  if firemode<0 then anm_name:=anm_name+'a' else anm_name:=anm_name+inttostr(firemode);
  anm_name:=anm_name+'_to_';
  if new_mode<0 then anm_name:=anm_name+'a' else anm_name:=anm_name+inttostr(new_mode);

  if IsWeaponJammed(wpn) then begin
    res:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, PChar(anm_name), 'sndChangeFireModeJammed');
  end else if GetAmmoInMagCount(wpn)<=0 then begin
    res:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, PChar(anm_name), 'sndChangeFireModeEmpty');
  end else begin
    res:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, PChar(anm_name), 'sndChangeFireMode');
  end;

  if res then begin
    SetAnimForceReassignStatus(wpn, true);     //for world model
    det_anim:=GetActualCurrentAnim(wpn);
    StartCompanionAnimIfNeeded(rightstr(det_anim, length(det_anim)-4), wpn, false);
  end;
end;

procedure OnChangeFireMode_Patch(); stdcall;
asm
  push [esi+$7ac]       //�������� ������� ������ ������ ��������

  mov [esi+$7ac], edx   //������� ����� ������ (��������������) ������ ��������
  mov edx, [edi+$1a8]
  call edx              //��������� ������ ������� ��� ������ ������ ��������
  push eax              //�������� ����� ������ ������� ��� ������ ������, ��� ���������������� (������� �����)


  mov ecx, [esp+$C]     //��������������� ��� ������������ (������/�����, ������� ��������)
  pushad
    push ecx
    push eax
    push esi
    call OnChangeFireMode
    cmp al, 1
  popad
  
  jne @nochange
    mov ecx, esi    //��� ���������, ��������� ������������
    mov eax, [edi+$218]
    call eax        //������������� ����� ������ �������
    add esp, 4      //������� �� ����� �� �������������� ��� ������ ����� ��������
    jmp @finish

  @nochange:
                          //��� �����, ������ ������������� �� �����
      add esp, 4          //��������, ����� ������� ���������� ����������
      pop [esi+$7ac]      //��������������� ������ ������

  @finish:
  ret 4
end;


function InitChangeFireMode(address:cardinal; changetype:byte):boolean;
var buf:string;
begin
  result:=false;
  buf:=chr($6A)+chr(changetype);//��������� � ���������� �������� ��� �����
  if not WriteBufAtAdr(address, PChar(buf), 2) then exit;
  address:=address+2;//������ ���������� ����� �����
  if not WriteJump(address, cardinal(@OnChangeFireMode_Patch), 23, true) then exit;
  result:=true;
end;


//-------------------------������� ���������� �����-----------------------------
procedure OnWeaponExplode_AfterAnim(wpn:pointer; param:integer);stdcall;
var
  hud_sect:PChar;
  trash, element:string;
  sitm:pCSE_Abstract;
begin
  hud_sect:=GetHUDSection(wpn);
  if game_ini_line_exist(hud_sect, 'explosion_trash') then begin
    trash:= game_ini_read_string(hud_sect, 'explosion_trash');
    while (GetNextSubStr(trash, element, ',')) do begin
      sitm:=alife_create(PChar(element), GetPosition(wpn), GetLevelVertexID(wpn), GetGameVertexID(wpn));
      if sitm<>nil then CSE_SetAngle(sitm, GetOrientation(wpn));
      if sitm<>nil then CSE_SetPosition(sitm, GetPosition(wpn));
    end;
  end;
  if IsScopeAttached(wpn) and (GetScopeStatus(wpn)=2) then alife_create(game_ini_read_string(GetCurrentScopeSection(wpn), 'scope_name'), GetPosition(wpn), GetLevelVertexID(wpn), GetGameVertexID(wpn));
  if IsSilencerAttached(wpn) and (GetSilencerStatus(wpn)=2) then alife_create(GetSilencerSection(wpn), GetPosition(wpn), GetLevelVertexID(wpn), GetGameVertexID(wpn));
  if IsGLAttached(wpn) and (GetGLStatus(wpn)=2) then alife_create(GetGLSection(wpn), GetPosition(wpn), GetLevelVertexID(wpn), GetGameVertexID(wpn));

  alife_release(get_server_object_by_id(GetID(wpn)));
end;

function IsJamProhibited(wpn:pointer):boolean; stdcall;
var
  c_cur, c_next:pCCartridge;
  ammoc:cardinal;
begin
  // ���� �������� ��� ������� � ������ � ���������� ������� (����, ������� ����� ������� ����� ��������) ���������� ����� ����� - ������� ������!
  // ����� �� ���������� ������ �������� ���� ����� ��������� �������� �������
  result:=false;

  if IsGrenadeMode(wpn) then exit;

  ammoc:=GetAmmoInMagCount(wpn);
  if ammoc <= 0 then exit;
  c_cur:=GetCartridgeFromMagVector(wpn, ammoc-1);

  if ammoc=1 then begin
    result:=GetAmmoTypeIndex(wpn, false) <> GetCartridgeType(c_cur);
  end else begin
    c_next:=GetCartridgeFromMagVector(wpn, ammoc-2);
    result:=GetCartridgeType(c_cur)<>GetCartridgeType(c_next);
  end;
end;

function OnWeaponJam(wpn:pointer):boolean;stdcall;
//������ � ������� ���������� ���-�� ���������...
//������� false, ���� �� �������� ����� ������, true - ���� ��������
var sect:PChar;
    owner:pointer;
    startcond, endcond, curcond, startprob, endprob, curprob:single;
    anm:string;
    buf:WpnBuf;
begin
  result:=true;
  SetWeaponMisfireStatus(wpn, true);
  SetAnimForceReassignStatus(wpn, true);
  owner := GetOwner(wpn);
  if (owner=nil) or (owner<>GetActor()) then exit;
  sect:=GetSection(wpn);
  curcond:=GetCurrentCondition(wpn);

  if IsActorSuicideNow() then begin
    SetWeaponMisfireStatus(wpn, false);
    result:=true;
  end;

  if FindBoolValueInUpgradesDef(wpn, 'can_explose', game_ini_r_bool_def(sect, 'can_explose', false), true) then begin
    if curcond<game_ini_r_single_def(sect, 'explode_start_condition', 1) then begin
      if random < game_ini_r_single_def(sect, 'explode_probability', 1) then begin
        //������ ������ ��������� � ����� :)
        result:=true;
        SetExplosed(wpn, true);
        if game_ini_line_exist(sect, 'explode_flame_particles') then SetCurrentParticles(wpn, game_ini_read_string(sect, 'explode_flame_particles'), OFFSET_PARTICLE_WEAPON_CURFLAME);
        if game_ini_line_exist(sect, 'explode_shell_particles') then SetCurrentParticles(wpn, game_ini_read_string(sect, 'explode_shell_particles'), OFFSET_PARTICLE_WEAPON_CURSHELLS);
        if game_ini_line_exist(sect, 'explode_smoke_particles') then SetCurrentParticles(wpn, game_ini_read_string(sect, 'explode_smoke_particles'), OFFSET_PARTICLE_WEAPON_CURSMOKE);
        exit;
      end;
    end;
  end;

  if game_ini_r_bool_def(sect, 'use_light_misfire', false) and not (IsHolderHasActiveDetector(wpn) and game_ini_r_bool_def(GetHUDSection(wpn), 'disable_light_misfires_with_detector', false)) then begin
    startcond:=game_ini_r_single_def(sect, 'light_misfire_start_condition', 1);   //��� ����� ��������� �������� ������
    endcond:=game_ini_r_single_def(sect, 'light_misfire_end_condition', 0);       //��� ����� ����������
    startprob:=game_ini_r_single_def(sect, 'light_misfire_start_probability', 1); //����� ���� �� ������ ��� ��������� ��������� ����� ���������� ������
    endprob:=game_ini_r_single_def(sect, 'light_misfire_end_probability', 0);     //����� ���� �� ���� ������ ������ ����� ���������� � �����

    if (curcond<endcond) then
      curprob:=endprob
    else if (curcond>startcond) then
      curprob:=0
    else
      curprob:=endprob+curcond*(startprob-endprob)/(startcond-endcond);

    if (random<curprob) then begin
      //������! ���������� ���� �����, � �������� �� ����
      SetWeaponMisfireStatus(wpn, false);
      result:=false;

      //������ �������� ����� - ����������� anm_shoot, ����� ����� ���������� �� ������� �������� - �� ��������� �������
      anm:='anm_shoot_lightmisfire';
      if IsAimNow(wpn) or IsHolderInAimState(wpn) then begin
        anm:=anm+'_aim';
        if (GetScopeStatus(wpn)=2) and IsScopeAttached(wpn) and game_ini_r_bool_def(GetHUDSection(wpn), 'aim_scope_anims', true) then anm:=anm+'_scope';
        buf:=GetBuffer(wpn);
        if buf<>nil then begin
          if GetActorActiveItem()=wpn then begin
            buf.ApplyLensRecoil(buf.GetMisfireRecoil);
          end;
        end;        
      end;
      anm:= ModifierStd(wpn, anm);
      PlayHUDAnim(wpn, PChar(anm), true);
      StartCompanionAnimIfNeeded(rightstr(anm, length(anm)-4), wpn, false);
      anm:='lock_time_'+anm;
      MakeLockByConfigParam(wpn, GetHUDSection(wpn), PChar(anm), true);
      CHudItem_Play_Snd(wpn, 'sndLightMisfire');
      SendMessage('gunsl_light_misfire', gd_novice);
      exit;
    end;
  end;

  //���� ������. ���������, �� �������� �� ��� �����
  result:= not game_ini_r_bool_def(GetHUDSection(wpn), 'no_jam_fire', false);
  //���� �� �������� - ������ ����� �������� � ���� �������
  if not result then PlayHUDAnim(wpn, anm_shots_selector(wpn, true), true);
end;

procedure WeaponJammed_Patch(); stdcall;
//� ��� ������ ������ ���� ��������� ��� ������ ��������
//�� ������� ������ - ���� �����������, �� �������� ���� �����, �� ���� �������, ��� ��� ���������, � ������� ��� ���� ����������
//����� �������� � ����������� ��������� ���������� �������� �� �������� �������� � WeaponAnims.pas
asm
  mov eax, 1
  pushad
    push esi
    call IsJamProhibited
    cmp al, 0
  popad
  je @jam_allowed
  mov byte ptr [esi+$45A], 0 //���������� ��������� ������
  xor eax, eax               //�������, ��� ������ ���
  jmp @finish

  @jam_allowed:
  pushad
    push esi
    call OnWeaponJam
    cmp al, 0
  popad

  je @finish    //���� OnWeaponJam ������� false (�� �������� ������) - ���������
  xor eax, eax  //�������, ��� ������ ���
  
  @finish:
end;

//--------------����������� ��������� � �����----------------------------------

procedure OnJammedHintShow(); stdcall;
//var
//  wpn:pointer;
begin
//  wpn:=GetActorActiveItem();
//  if (wpn=nil) or not WpnCanShoot(PChar(GetClassName(wpn))) then exit;
//  if not (IsExplosed(wpn) or (IsActionProcessing(wpn) and (leftstr(GetCurAnim(wpn), length('anm_fakeshoot'))<>'anm_fakeshoot'))) then begin
//    Messenger.SendMessage('gun_jammed', gd_novice);
//  end;
end;

procedure OnJammedHintShow_Patch(); stdcall;
asm
  pushad
    call OnJammedHintShow
  popad
end;

//---------------------������ ��� �������/������ ��������-----------------------
procedure OnEmptyClick(wpn:pointer);stdcall;
var
  anm_started:boolean;
  txt:PChar;
  act:pointer;
  det_anm:PChar;
  buf:WpnBuf;
begin
  anm_started:=false;

  //��� �������� �� �������� ��������������� �����. �������� ��� ������������� ������������ � ������������� �����.
  if not (((GetGLStatus(wpn)=1) or IsGLAttached(wpn)) and IsGLEnabled(wpn)) and IsWeaponJammed(wpn) then begin
    txt := 'gunsl_msg_weapon_jammed';
    if IsAimNow(wpn) or IsHolderInAimState(wpn) then begin
      anm_started:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_fakeshoot_aim', 'sndJammedClick', nil, 0, false, true)
    end else begin
      anm_started:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_fakeshoot', 'sndJammedClick', nil, 0, false, true);
    end;
  end else begin
    txt := 'gunsl_msg_weapon_empty';
    if IsAimNow(wpn) or IsHolderInAimState(wpn) then begin
      anm_started:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_fakeshoot_aim', 'sndEmptyClick', nil, 0, false, true);
    end else begin
      anm_started:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_fakeshoot', 'sndEmptyClick', nil, 0, false, true);
    end;
  end;

  act:=GetActor();
  if (act<>nil) and (act=GetOwner(wpn)) and anm_started then begin
    det_anm:=GetActualCurrentAnim(wpn);
    StartCompanionAnimIfNeeded(rightstr(det_anm, length(det_anm)-4), wpn, true);
    Messenger.SendMessage(txt, gd_novice);

    buf:=GetBuffer(wpn);
    if buf<>nil then begin
      buf.ApplyLensRecoil(buf.GetMisfireRecoil);
    end;
  end;
end;

procedure EmptyClick_Patch; stdcall;
asm
    pushad
    sub ecx, $2e0
    push ecx
    call OnEmptyClick
    popad
    ret
end;
//------------------------------------------------------------------------------

function OnWeaponHide(wpn:pointer):boolean;stdcall;
var
  act, owner, itm:pointer;
  state:cardinal;
begin

  //�������, ����� �������� ��� ���
  //�������� ��� ���� CHudItem! ����� ���������� (?)
  act:=GetActor();
  owner:=GetOwner(wpn);

  if (owner<>act) and (act<>nil) then begin
    result:=true;
    exit;
  end;


  if not (WpnCanShoot(wpn)) then begin
    result:=true;
    state:=GetCurrentState(wpn);

    if (IsActorSuicideNow() or IsSuicideAnimPlaying(wpn)) then begin
      result:=false;
      exit;
    end;

    if (act<>nil) and (owner=act) and IsThrowable(wpn) and ((state=EMissileStates__eReady) or (state=EMissileStates__eThrowStart) or (state=EMissileStates__eThrow) or (state=EMissileStates__eThrowEnd)) then begin
      result:=false;
    end;

    if IsBino(wpn) and (IsAimNow(wpn) or (leftstr(GetActualCurrentAnim(wpn), length('anm_idle_aim'))='anm_idle_aim')) then begin
      if IsAimNow(wpn) then begin
        if IsAimToggle() then virtual_Action(wpn, kWPN_ZOOM, kActPress) else virtual_Action(wpn, kWPN_ZOOM, kActRelease);
        SetActorActionState(act, actModNeedMoveReassign, true);
      end;
      result:=false
    end;
    exit;
  end;

  result:=CanHideWeaponNow(wpn);

  if (act<>nil) and (owner=act) then begin
    if result then begin
      if (GetBuffer(wpn)<>nil) and (not IsReloaded(wpn)) and OnActWhileReload_CanActNow(wpn) then begin
        CWeaponMagazined__OnAnimationEnd_DoReload(wpn);
        SetReloaded(wpn, false); //����� ����� �� ��������, ���� ��� :(
        SetReloaded(wpn, true);
      end;
      ResetActorFlags(act);
    end else begin
      if ActorUtils.IsHolderInSprintState(wpn) then begin
        SetActorKeyRepeatFlag(kfWPNHIDE, true);
        SetActorActionState(act, actSprint, false, mState_WISHFUL);
      end;
    end;
  end;
end;

procedure OnWeaponHideAnmStart(wpn:pointer);stdcall;
var
  act, owner:pointer;
begin
  //� ���� ��� ����� ��������. �������������.
  if IsKnife(wpn) then begin
    CHudItem_Play_Snd(wpn, 'sndHide');
  end;

  act:=GetActor();
  owner:=GetOwner(wpn);
  if (act<>nil) and (owner=act) then begin
    ResetActorFlags(act);
    SetActorActionState(act, actSprint, false, mState_WISHFUL);
    SetActorActionState(act, actSprint, false, mState_REAL);

    StartCompanionAnimIfNeeded('hide', wpn, false);
  end;
end;


procedure OnWeaponShow(wpn:pointer);stdcall;
var
  act, owner, det:pointer;
  last_pdahide_state:boolean;
begin
  //� ���� ��� ����� ����������. �������������.
  if IsKnife(wpn) then begin
    CHudItem_Play_Snd(wpn, 'sndShow');
  end;

  act:=GetActor();
  owner:=GetOwner(wpn);

  if (owner<>nil) and (owner=act) then begin
    //���� ���� � ����������� �������� ��� ����� ������� ������, ����� ����� ���������� �� ��������

    player_hud__attach_item(wpn);


    last_pdahide_state:=GetActorKeyRepeatFlag(kfPDAHIDE);
    ClearActorKeyRepeatFlags();
    ResetChangedGrenade();
    SetActorKeyRepeatFlag(kfPDAHIDE, last_pdahide_state);
    
    SetActorActionState(act, actSprint, false, mState_WISHFUL);
    ResetActorFlags(act);
    det:=ItemInSlot(act, 9);
    if (det<>nil) and not CanUseDetectorWithItem(wpn) then begin
      ForceHideDetector(det);
      SetDetectorForceUnhide(det, false);
      SetActorActionState(act, actShowDetectorNow, false);
    end;

    //���� �������� �� ������ � �����, �� � �������
    StartCompanionAnimIfNeeded('draw', wpn, false);
  end;
end;


function OnWeaponAimIn(wpn:pointer):boolean;stdcall;
var
  act:pointer;
begin
  result:=CanAimNow(wpn);
  act:=GetActor();
  if not result and (act<>nil) and not IsAimToggle() and (act = GetOwner(wpn)) and IsHolderInSprintState(wpn) then begin
    SetActorActionState(act, actSprint, false, mState_WISHFUL);
  end;

  if result and (GetAimFactor(wpn)< 0.002) then begin
    SetAimFactor(wpn, 0.002); //������ �� �������� ������ �����, ����� �� ���������� �������������� �����
  end;
end;


function OnWeaponAimOut(wpn:pointer):boolean;stdcall;
begin
  //��� �������� false ����� �� ���� ���������� �� �����
  //���� � ��� ����������� �����-�� �������� � ������������ (��������, ��������)
  //� � �������� ��������� ���������� ������ �� ����/�� ������ ����� ������
  //�� ����������, ��� �� ������ ��������� ������������
  //����� � ������� ������ ���� ��������� �������� � ������� �������� ��������� ������� ����� �� ����
  result:=CanLeaveAimNow(wpn);
//  log(booltostr(result, true));
  if not result then SetActorKeyRepeatFlag(kfUNZOOM, true);

  if result and (GetAimFactor(wpn)> 0.998) then begin
    SetAimFactor(wpn, 0.998); //������ �� �������� ������ ������, ����� �� ���������� �������������� �����
  end;  
end;


function Weapon_SetKeyRepeatFlagIfNeeded(wpn:pointer; kfACTTYPE:cardinal):boolean;stdcall;
var
  act:pointer;
begin
  result:=CanStartAction(wpn);
  if (not result) then begin
    act:=GetActor();
    if (act<>nil) and (act=GetOwner(wpn)) then begin

      if IsHolderInSprintState(wpn) then begin
        SetActorActionState(act, actSprint, false, mState_WISHFUL);
        SetActorKeyRepeatFlag(kfACTTYPE, true);
      end else if (IsWeaponJammed(wpn) and ( (kfACTTYPE = kfRELOAD) or (kfACTTYPE = kfNEXTAMMO)  )) then begin
        SetActorKeyRepeatFlag(kfACTTYPE, true);
      end;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------

procedure CHudItem__OnStateSwitch(chuditem:pointer); stdcall;
var
  wpn:pointer;
begin
  wpn:=dynamic_cast(chuditem, 0, RTTI_CHudItem, RTTI_CWeapon, false);
  if wpn<>nil then begin
    //��� �������� ������
    case GetNextState(wpn) of
      1,2,3,7,8,10: begin
        SetAnimForceReassignStatus(wpn, true);
        WeaponUpdate.ReassignWorldAnims(wpn);
      end;
    end;
  end;
end;

procedure CHudItem__SwitchState_Patch(); stdcall;
asm
  pushad
    push esi
    call CHudItem__OnStateSwitch
  popad
  pop esi
  add esp, $4014
  ret 4
end;
//----------------------------------------------------------------------------------------------------------
function anm_attack_selector(knife:pointer; kick_type:cardinal):PChar; stdcall;
var
  act:pointer;
  v:FVector3;
begin

  act:=GetActor();
  if (act<>nil) and (act=GetOwner(knife)) then begin
    SetActorActionState(act, actModSprintStarted, false);
    SetActorActionState(act, actModSprintStarted, false, mState_WISHFUL);

    if IsActorPlanningSuicide() and CheckActorVisibilityForController() then begin
      if not IsActorSuicideNow() then begin
        CHudItem_Play_Snd(knife, 'sndPrepareSuicide');
        result:='anm_prepare_suicide';
      end else begin
        SetDisableInputStatus(true);
        result:='anm_selfkill';
        CHudItem_Play_Snd(knife, 'sndSelfKill');
        NotifySuicideShotCallbackIfNeeded();
      end;
      exit;
    end else if IsSuicideAnimPlaying(knife) then begin
      SetExitKnifeSuicide(false);
      SetHandsJitterTime(GetShockTime());
      CHudItem_Play_Snd(knife, 'sndStopSuicide');
      result:='anm_stop_suicide';
      NotifySuicideStopCallbackIfNeeded();
      ResetActorControl();
      exit;
    end;
  end;

  case kick_type of
    1:begin
        result:='anm_attack';
        StartCompanionAnimIfNeeded('knife_attack', knife, true);
        CHudItem_Play_Snd(knife, 'sndKick1');
        if ReadActionDOFVector(knife, v, 'anm_attack', false) then begin
          SetDOF(v, ReadActionDOFSpeed_In(knife,'anm_attack'));
        end;
      end;
    2:begin
        result:='anm_attack2';
        StartCompanionAnimIfNeeded('knife_attack2', knife, true);
        CHudItem_Play_Snd(knife, 'sndKick2');
        if ReadActionDOFVector(knife, v, 'anm_attack2', false) then begin
          SetDOF(v, ReadActionDOFSpeed_In(knife, 'anm_attack2'));
        end;
      end;
  end;
end;

procedure OnKnifeKick_Patch(); stdcall;
asm
    push 0                  //�������� ����� ��� �������� �����
    pushad
    pushfd
    jne @second_type
      push 1
      jmp @call_proc
    @second_type:
      push 2
    @call_proc:
    push esi
    call anm_attack_selector  //�������� ������ � ������ �����
    mov ecx, [esp+$28]      //���������� ����� ��������
    mov [esp+$28], eax      //������ �� ��� ����� �������������� ������
    mov [esp+$24], ecx      //���������� ����� �������� �� 4 ����� ���� � �����
    popfd
    popad
    ret
end;

{procedure OnKnifeKick_Patch(); stdcall;
asm
  //original
  mov ebp, [esp+$10]
  cmp ebp, 5


  pushad
  pushfd
  //select type
  jne @second_type
    push 1
    jmp @call_proc
  @second_type:
    push 2
  @call_proc:
  push esi
  call OnKnifeKick

  popfd
  popad
  ret
end; }
//---------------------------------------------------------------------------------------------------------
procedure LaserSwitch(wpn:pointer; param:integer); stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  buf.SetLaserEnabledStatus(not buf.IsLaserEnabled());
  MakeLockByConfigParam(wpn, GetHUDSection(wpn), PChar('lock_time_end_'+GetActualCurrentAnim(wpn)));
end;

procedure OnLaserButton(wpn:pointer);
var
  buf:WpnBuf;
  res:boolean;
  curanm:PChar;
begin
  buf:=GetBuffer(wpn);
  if (buf<>nil) and buf.IsLaserInstalled() then begin
    res:=Weapon_SetKeyRepeatFlagIfNeeded(wpn, kfLASER);
    if res then begin
      if buf.IsLaserEnabled() then begin
        res:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_laser_on', 'sndLaserOn');
      end else begin
        res:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_laser_off', 'sndLaserOff');
      end;
    end;

    curanm:=GetActualCurrentAnim(wpn);
    if res then  begin
      StartCompanionAnimIfNeeded(rightstr(curanm, length(curanm)-4), wpn, false);
      MakeLockByConfigParam(wpn, GetHUDSection(wpn), PChar('lock_time_start_'+curanm), false, LaserSwitch);
    end;
  end;
end;


//---------------------------------------------------------------------------------------------------------
procedure TacticalTorchSwitch(wpn:pointer; param:integer); stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  buf.SwitchTorch(not buf.IsTorchEnabled());
  MakeLockByConfigParam(wpn, GetHUDSection(wpn), PChar('lock_time_end_'+GetActualCurrentAnim(wpn)));
end;

procedure OnTorchButton(wpn:pointer);
var
  buf:WpnBuf;
  res:boolean;
  curanm:PChar;
begin
  buf:=GetBuffer(wpn);
  if (buf<>nil) and buf.IsTorchInstalled() then begin
    res:=Weapon_SetKeyRepeatFlagIfNeeded(wpn, kfTACTICALTORCH);
    if res then begin
      if buf.IsTorchEnabled() then begin
        res:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_torch_on', 'sndTorchOn');
      end else begin
        res:=WeaponAdditionalBuffer.PlayCustomAnimStatic(wpn, 'anm_torch_off', 'sndTorchOff');
      end;
    end;

    //�������� ����� ���������� ���� ����� ��-�� ����, ��� ����� ����� ������������ ������ ���������� ��������
    curanm:=GetActualCurrentAnim(wpn);
    if res then  begin
      StartCompanionAnimIfNeeded(rightstr(curanm, length(curanm)-4), wpn, false);
      MakeLockByConfigParam(wpn, GetHUDSection(wpn), PChar('lock_time_start_'+curanm), false, TacticalTorchSwitch);
    end;
  end;
end;

//---------------------------------------------------------------------------------------------------------
procedure OnZoomAlterButton(wpn:pointer; flags:cardinal);
var
  buf:WpnBuf;
  act:pointer;
  aim_now, alter_aim_now:boolean;
begin

    buf:=GetBuffer(wpn);
    if (buf=nil) or not CanUseAlterScope(wpn) then exit;

    act:=GetActor();
    if (act=nil) or (act<>GetOwner(wpn)) then exit;

    if not CanAimNow(wpn) then begin
     if IsHolderInSprintState(wpn) and not IsAimToggle() then begin
      SetActorActionState(act, actSprint, false, mState_WISHFUL);
     end;
     exit;
    end;

    aim_now:=IsAimNow(wpn);
    alter_aim_now:=IsAlterZoom(wpn);

    if IsAimToggle() then begin
      if flags=kActPress then begin
        if not aim_now then begin
          //������� ������������ ���������, �������� ��������������
          buf.SetAlterZoomMode(true);
          virtual_Action(wpn, kWPN_ZOOM, kActPress);
        end else if alter_aim_now then begin
          //������� �������������� ������������, ������ ��� ������ ����� - ���� �������� �� ����
          buf.SetAlterZoomMode(false);
          virtual_Action(wpn, kWPN_ZOOM, kActPress);
        end else begin
          //������� ������� ������������, ������ ������ ��������������� - ���� ������� � ��������������
          buf.SetLastZoomAlter(true);
          buf.SetAlterZoomMode(true);
          buf.StartAlterZoomDirectSwitchMixup();
          RefreshZoomDOF(wpn);
        end;
      end;

    end else begin

      if flags=kActPress then begin
        if not aim_now then begin
          // ������� ������������ ��������� - �������� ��������������
          buf.SetAlterZoomMode(true);
          virtual_Action(wpn, kWPN_ZOOM, kActPress);
        end else if alter_aim_now then begin
          // ��� ������� �������������� ������������ - ������ �� ������
        end else begin
          // ������� ������� ������������ - ��������� � ��������������
          buf.SetLastZoomAlter(true);
          buf.SetAlterZoomMode(true);
          buf.StartAlterZoomDirectSwitchMixup();
          RefreshZoomDOF(wpn);
        end;
      end else begin
        if not aim_now then begin
          // ������� ������������ ��������� - �������, �� ������ �� ������
        end else if alter_aim_now then begin
          // ������� �������������� ������������ - ���� ������ ������ ��������, ��������� � ����, ����� - ������� �� ������������
          if IsActionKeyPressedInGame(kWPN_ZOOM) then begin
            buf.SetLastZoomAlter(false);
            buf.SetAlterZoomMode(false);
            buf.StartAlterZoomDirectSwitchMixup();
            RefreshZoomDOF(wpn);
          end else begin
            buf.SetAlterZoomMode(false);
            virtual_Action(wpn, kWPN_ZOOM, kActRelease);
          end;
        end else begin
          // ������� ������� ������������ - ������ �� ������
        end;
      end;
    end;
end;

function OnZoomButton(wpn:pointer; flags:cardinal):boolean;
var
  buf:WpnBuf;
  aim_now, alter_aim_now:boolean;  
begin
  //���� ������ true - ������� ����� ��������� ������������ � ������ �� ������
  result:=false;
  buf:=GetBuffer(wpn);
  if buf = nil then exit;

  aim_now:=IsAimNow(wpn);
  alter_aim_now:=IsAlterZoom(wpn);
  if IsAimToggle() then begin
    if flags=kActPress then begin
      if not aim_now then begin
        // �� ������ ������� ������� �� ���� ������� �������� ������������, ������ (��������) ���������� ����� � �����-�� (���� alter_aim_now = true - ������, � ��������������)
        // ��� ������� ������� ���
        result:=false;        
      end else if alter_aim_now then begin
        // ����� �������� ������� ��� ���� ������� �������������� ������������. ��������� � �������
        buf.SetLastZoomAlter(false);
        buf.SetAlterZoomMode(false);
        buf.StartAlterZoomDirectSwitchMixup();
        RefreshZoomDOF(wpn);
        result:=true;
      end else begin
        // ����� �������� ������� ��� ���� ������� ������� ������������. ������� �� ������������
        // ��� ������� ������� ���
        result:=false;
      end;
    end;

  end else begin
  
    if flags=kActPress then begin
      if not aim_now then begin
        // �� ������ ������� ������� �� ���� ������� �������� ������������, ������ (��������) ���������� ����� � �����-�� (���� alter_aim_now = true - ������, � ��������������)
        // ��� ������� ������� ���
        result:=false;
      end else if alter_aim_now then begin
        // ����� �������� ������� ��� ���� ������� �������������� ������������. ��������� � �������
        buf.SetLastZoomAlter(false);
        buf.SetAlterZoomMode(false);
        buf.StartAlterZoomDirectSwitchMixup();
        RefreshZoomDOF(wpn);
        result:=true;
      end else begin
        // ����� �������� ������� ��� ������-�� ���� ������� ������� ������������. ������ �� ������.
        result:=true;
      end;
    end else begin
      if not aim_now then begin
        // � ������ ���������� ������� ������������ �� ����. �������, �� ������ �� ������.
        result:=true;
      end else if alter_aim_now then begin
        // � ������ ���������� ������� ���� ������� �������������� ������������. ��������� ���.
        result:=true;
      end else begin
        // � ������ ���������� ������� ���� ������� ������� ������������. ���� ������ ������ ���������������, � �������������� �������������� �������, �� ��������� � ����, ����� -  ������� �� ������������
        if IsActionKeyPressedInGame(kWPN_ZOOM_ALTER) and CanUseAlterScope(wpn) then begin
          buf.SetLastZoomAlter(true);
          buf.SetAlterZoomMode(true);
          buf.StartAlterZoomDirectSwitchMixup();
          RefreshZoomDOF(wpn);
          result:=true;
        end else begin
          result:=false;
        end;
      end;
    end;
  end;
end;

//---------------------------------------------------------------------------------------------------------
function CWeapon__Action(wpn:pointer; id:cardinal; flags:cardinal):boolean; stdcall;
//������� true, ���� ������ ������������ ������� �� ����
var
  buf:WpnBuf;
  scope_sect:PChar;

  lens_params:lens_zoom_params;
  dt, oldpos:single;
  force_zoom_sound:boolean;
begin
  result:=false;
  buf:=GetBuffer(wpn);
  if (buf<>nil) and ((id=kWPN_ZOOM_ALTER) or (id= kWPN_ZOOM)) and (GetAimFactor(wpn)>0) and not IsAimNow(wpn) and (buf.IsAlterZoomMode()<>buf.IsLastZoomAlter())  then begin
    result:=true;
    exit;
  end;

  if (id=kWPN_NEXT) then begin
    if not CanReloadNow(wpn) then begin
      result:=true;
      exit;
    end;
  end;

  if (id=kWPN_FIRE) and IsActorControlled() then begin
      result:=true;
      exit;  
  end;

  if (id=kLASER) and (flags=kActPress) then begin
    OnLaserButton(wpn);
  end else if (id=kTACTICALTORCH) and (flags=kActPress) then begin
    OnTorchButton(wpn);
  end else if (id=kWPN_ZOOM_ALTER) then begin
    OnZoomAlterButton(wpn, flags);
  end else if (id=kWPN_ZOOM) then begin
    result:=OnZoomButton(wpn, flags);
  end else if ((id=kWPN_ZOOM_INC) or (id=kWPN_ZOOM_DEC) or (id=kBRIGHTNESS_PLUS) or (id=kBRIGHTNESS_MINUS)) and (flags=kActPress) then begin
    if (buf<>nil) and IsAimNow(wpn) and buf.IsAlterZoomMode() then begin
      result:=true;
    end else if (buf<>nil) and IsAimNow(wpn) then begin
      if (id=kWPN_ZOOM_INC) or (id=kWPN_ZOOM_DEC) then begin
        lens_params:=buf.GetLensParams();
        dt:=lens_params.delta;
        oldpos := lens_params.target_position;
        force_zoom_sound:=false;
        
        if IsScopeAttached(wpn) and (GetScopeStatus(wpn)=2) then begin
          scope_sect:=game_ini_read_string(GetCurrentScopeSection(wpn), 'scope_name');
          dt:=1/game_ini_r_int_def(scope_sect, 'lens_factor_levels_count', 5);
          force_zoom_sound:=game_ini_r_bool_def(scope_sect, 'force_zoom_sound', false);
        end;

        if id=kWPN_ZOOM_INC then begin
          lens_params.target_position:=lens_params.target_position+dt;
        end else begin
          lens_params.target_position:=lens_params.target_position-dt;
        end;
        buf.SetLensParams(lens_params);

        lens_params:=buf.GetLensParams();
        if (lens_params.target_position<>oldpos) and (force_zoom_sound or (lens_params.factor_min<>lens_params.factor_max)) and ( abs(oldpos-lens_params.target_position)>0.0001 ) then begin
          if id=kWPN_ZOOM_INC then begin
            CHudItem_Play_Snd(wpn, 'sndScopeZoomPlus');
          end else begin
            CHudItem_Play_Snd(wpn, 'sndScopeZoomMinus');
          end;
        end;

      end else begin
        buf.ReloadNightBrightnessParams();
        if id=kBRIGHTNESS_MINUS then begin
          buf.ChangeNightBrightness(-1);
        end else begin
          buf.ChangeNightBrightness(1);
        end;
      end;
    end;
  end;
end;

procedure CWeapon__Action_Patch(); stdcall;
asm
  mov esi, ecx
  pushad
    push ebx
    push edi
    push ecx
    call CWeapon__Action
    test al, al
  popad
end;

//---------------------------------------------------------------------------------------------------------------------

procedure CWeapon__OnAnimationEnd(wpn:pointer); stdcall;
var
  act:pointer;
  anm:PChar;
begin
  act:=GetActor();
  //�������� ���������� ���� ������ � ��������� � ����
  //������ ��� �������������� ��������������� ���� ����
  if (act<>nil) and (act=GetOwner(wpn)) and (leftstr(GetActualCurrentAnim(wpn), length('anm_idle'))='anm_idle')
    //���� ��� ��� �������� - �� ��������
    and GetActorActionState(act, actModSprintStarted, mstate_REAL) and GetActorActionState(act, actSprint, mstate_REAL)
  then begin
    SetActorActionState(act, actModNeedMoveReassign, true);
  end;

  anm:=GetActualCurrentAnim(wpn);
  if (GetActorActiveItem()=wpn) and (not IsAimNow(wpn)) and (leftstr(anm, length('anm_idle'))<>'anm_idle') then ResetDOF(ReadActionDOFSpeed_Out(wpn, anm));

  //���� � ��� �������� ����� � �� ���������� ���� ������ �����, �� ������������ ������� � ��������� ���������� :)
  if (GetActorActiveItem()=wpn) and (GetActorKeyRepeatFlag(kfQUICKKICK) {or IsActionKeyPressed(kQUICK_KICK)}) and (GetSection(wpn)=GetKickAnimator()) and not IsActorControlled() then begin
    SetActorKeyRepeatFlag(kfQUICKKICK, false);
    virtual_CHudItem_SwitchState(wpn, EHudStates__eShowing);
    SetActorActionCallback(@KickCallback);
  end;
end;

procedure CWeapon__OnAnimationEnd_Patch(); stdcall;
asm
  pushad
    sub ecx, $2e0
    push ecx
    call CWeapon__OnAnimationEnd
  popad

  mov eax, xrgame_addr //������� �� ������ - ��������.
  add eax, $2F9640
  jmp eax
end;

//---------------------------------------------------------------------------------------------------------------------
procedure CWeaponKnife__OnAnimationEnd(wpn:pointer); stdcall;
var
  act:pointer;
begin
  act:=GetActor;
  if (wpn=GetActorActiveItem) and (GetActualCurrentAnim(wpn)='anm_selfkill') then begin
    KillActor(act, act);
  end;
  
  //��������! �������� CWeapon__OnAnimationEnd � ��� ��������� ��-�� �������� ���������� ������ ��������, ��. ��� ����
  CWeapon__OnAnimationEnd(wpn);
end;

procedure CWeaponKnife__OnAnimationEnd_Patch(); stdcall;
asm
  pushad
    sub ecx, $2e0
    push ecx
    call CWeaponKnife__OnAnimationEnd
  popad
  mov eax, [esp+8]
  cmp eax, 6
  ret
end;


//---------------------------------------------------------------------------------------------------------------------


procedure CHudItem__SendHiddenItem_Patch(); stdcall;
asm
  pushad
    sub ecx, $2e0
    push ecx
    call WeaponEvents.OnWeaponHide
    cmp al, 1
  popad
  je @finish
    //������� �� ������� � ���������� �����
    pop eax
    ret
  @finish:
  mov eax, $4014
  ret
end;

//----------------------------------------------------------------------------------------------------------
procedure CWeaponMagazined__OnAnimationEnd(wpn:pointer; state:cardinal); stdcall;
begin
  //���� ����������� �������� ��������, �������� �������� �������� ����
  if state = EWeaponStates__eFire then begin
    PlayAnimIdle(wpn);
  end;

  //��� ���-�� ����... � ����� ���� �����
  if (GetSection(wpn)=GetPDAShowAnimator()) and not IsPDAWindowVisible() then begin
     if (leftstr(GetActualCurrentAnim(wpn), length('anm_idle_aim_end'))='anm_idle_aim_end') then begin
       virtual_CHudItem_SwitchState(wpn, EHudStates__eHiding);
     end else if (leftstr(GetActualCurrentAnim(wpn), length('anm_hide_emerg'))='anm_hide_emerg') then begin
       virtual_CHudItem_SwitchState(wpn, EHudStates__eHidden);
     end;
  end;
end;

procedure CWeaponMagazined__OnAnimationEnd_Patch(); stdcall;
asm
  pushad
    sub ecx, $2e0
    push edi
    push ecx
    call CWeaponMagazined__OnAnimationEnd
  popad
  cmp edi, $07
  mov esi, ecx
end;


procedure CWeaponShotgun__OnAnimationEnd_OnClose(wpn:pointer); stdcall;
var
  anm:PChar;
begin
  anm:=GetActualCurrentAnim(wpn);
  ResetDOF(ReadActionDOFSpeed_Out(wpn, anm));
end;

procedure CWeaponShotgun__OnAnimationEnd_OnClose_Patch(); stdcall;
asm
  pushad
    sub esi, $2e0
    push esi
    call CWeaponShotgun__OnAnimationEnd_OnClose
  popad
  mov [esi+$179], al
end;

procedure CEatableItemObject__OnH_A_Independent_Patch(); stdcall;
asm
  pushad
    lea ecx, [esi+$F0]
    mov eax, xrgame_addr
    call [eax+$512c88] //���������� - CPhysicItem::OnH_A_Independent
  popad
  pushad
    //�������� ����������� �������
    mov ecx, esi
    mov eax, [esi]
    mov edx, [eax+$3c]
    call edx   //this->Useful()
    test al, al
    jne @finish
      mov ecx, [esi+$d4]
      push 00
      mov eax, xrEngine_addr
      add eax, $196b0
      call eax //SetVisible(false)

      mov ecx, [esi+$d4]
      push 00
      mov eax, xrEngine_addr
      add eax, $19670
      call eax //SetEnabled(false)
    @finish:
  popad

  pop esi //����������
end;

procedure CWeaponMagazined__InitAddons_Patch; stdcall;
asm
  fstp dword ptr [esi+$4a4]
  mov eax, [esi+$4a4]
  mov [esi+$4C0], eax // m_fRTZoomFactor = m_zoom_params.m_fScopeZoomFactor
end;

//----------------------------------------------------------------------------------------------------------
procedure CWeapon__OnZoomOut(wpn:pointer); stdcall;
begin
  if IsDynamicDOF() then begin
    ResetDOF(game_ini_r_single_def(GetHUDSection(wpn),'zoom_out_dof_speed', GetDefaultDOFSpeed_Out()));
  end;

  if IsPDAWindowVisible() then begin
    ActorUtils._is_pda_lookout_mode:=true;
  end;
end;

procedure CWeapon__OnZoomOut_Patch(); stdcall;
asm
  pushad
    push esi
    call CWeapon__OnZoomOut
  popad
  fld [esi+$498]
end;



procedure CWeapon__OnZoomIn(wpn:pointer); stdcall;
var
  buf:WpnBuf;
  scope_sect:PChar;
begin
  if IsGLAttached(wpn) and IsGLEnabled(wpn) then begin
    scope_sect:=GetSection(wpn);
    if game_ini_line_exist(scope_sect, 'gl_zoom_factor') then begin
      SetZoomFactor(wpn, game_ini_r_single(scope_sect, 'gl_zoom_factor'));
    end;

    if IsScopeAttached(wpn) then begin
      scope_sect:=GetCurrentScopeSection(wpn);
      if game_ini_line_exist(scope_sect, 'gl_zoom_factor') then begin
        SetZoomFactor(wpn, game_ini_r_single(scope_sect, 'gl_zoom_factor'));
      end;
    end;
  end else if not IsScopeAttached(wpn) then begin
    if game_ini_line_exist(GetSection(wpn), 'nonscoped_zoom_factor') then begin
      SetZoomFactor(wpn, game_ini_r_single(GetSection(wpn), 'nonscoped_zoom_factor'));
    end;
  end;

  buf:=GetBuffer(wpn);
  if (buf<>nil) then begin
    buf.SetLastZoomAlter(buf.IsAlterZoomMode());

    if buf.IsAlterZoomMode() then begin
      SetZoomFactor(wpn, GetAlterScopeZoomFactor(wpn));
    end;

    buf.ReloadNightBrightnessParams();
    buf.UpdateZoomCrosshairUI();
  end;

  if IsPDAWindowVisible() then begin
    ActorUtils._is_pda_lookout_mode:=false;
  end;
end;

procedure CWeapon__OnZoomIn_Patch(); stdcall;
asm
  pushad
    push esi
    call CWeapon__OnZoomIn
  popad
  lea ecx, [esi+$2e0]
end;

//----------------------------------------------------------------------------------------------------------
procedure CHudItem__OnAnimationEnd(wpn:pointer); stdcall;
begin
  if (GetCurrentState(wpn) = EHudStates__eIdle) and IsPending(wpn) then begin
    EndPending(wpn);
  end;
end;

procedure CHudItem__OnAnimationEnd_Patch(); stdcall;
asm
  pushad
    sub ecx, $2e0
    push ecx
    call CHudItem__OnAnimationEnd
  popad
  cmp [esp+8], 4
end;

function CHudItem__OnMotionMark(wpn:pointer):boolean; stdcall;
var
  anm:pchar;
begin
  //�������� ��� ���� � ������������
  result:=false;
  if dynamic_cast(wpn, 0, RTTI_CWeapon, RTTI_CWeaponKnife, false)<>nil then begin
    if (GetOwner(wpn)=GetActor()) and (GetActorActiveItem()<>wpn)  then begin
      // ��� ��� ����� �� ��� ��� ������-�� ��� �� � �����. �������, �� ������ �����
      result:=true;      
    end else if GetCurrentState(wpn)=EWeaponStates__eFire then begin
      MakeWeaponKick(CRenderDevice__GetCamPos(), CRenderDevice__GetCamDir(), wpn);
      result:=true;
    end;
  end;
{  if IsPending(wpn) and (GetCurrentState(wpn)=EHudStates__eIdle) then begin
    anm:=GetActualCurrentAnim(wpn);
    if anm='anm_headlamp_on' then begin
    end else if anm='anm_headlamp_off' then begin
    end else if anm='anm_nv_on' then begin
    end else if anm='anm_nv_off' then begin
    end;
  end;  }
end;

procedure CWeaponKnife__OnMotionMark_Patch(); stdcall;
asm
  pushad
    sub ecx, $2e0
    push ecx
    call CHudItem__OnMotionMark
    cmp al, 00
  popad
  je @std
  //���� ��� ������ ����; ������ �� ���������� ���������
  add esp, $1c
  ret 8

  @std:
  push eax
  push eax


  //was original: cmp eax, 05 || push esi ||mov esi, ecx
  mov eax, [esp+8]
  mov [esp+4], eax
  mov [esp+8], esi

  pop eax
  cmp eax, 05
  mov esi, ecx
end;

//----------------------------------------------------------------------------------------------------------
procedure CWeaponKnife__OnStateSwitch_SetPending_Patch(); stdcall;
asm
  mov eax, [esi-$2e0]
  or word ptr [esi-$2e0+$2f4], 01 //SetPending(true)
end;
//----------------------------------------------------------------------------------------------------------

procedure CWeapon__Action_zoomincdec_Patch(); stdcall;
asm
  test bl, 1 // if !flags&&CMD_START then return;
  je @finish

  cmp byte ptr [esi+$494], 00
  je @finish

  @finish:
end;

////////////////////////////////���� ���� ������ ����� � ������ ������������//////////////////////////////////////

procedure LaunchGrenade_Correct(v:pFVector3); stdcall;
var
  camdir:FVector3;
begin
  //���� ������� ������... �������� ����� ��� ����� 45 �������� �� ����������� �������
  camdir:=FVector3_copyfromengine(CRenderDevice__GetCamDir());
  camdir.y:=0;
  v_normalize(@camdir);

  camdir.y:=1;
  v_normalize(@camdir);

  v^:=camdir;
end;

procedure CWeaponMagazinedWGrenade__LaunchGrenade_dir_Patch(); stdcall;
asm
  pop ecx // ret addr
  add esp, $10 //original
  push ecx //ret addr

  test al, al
  jne @finish //all OK

  lea ecx, [esp+$14]
  pushad
    push ecx
    call LaunchGrenade_Correct
  popad

  @finish:
  test al, al //original  
end;

////////////////////////////////���� ���� ������ ����� ��� ������������//////////////////////////////////////

procedure LaunchGrenade_controller_Correct(wpn:pointer; v:pFVector3); stdcall;
var
  act:pointer;
begin
  act:=GetActor();
  if (act<>nil) and (act = GetOwner(wpn)) and (IsActorSuicideNow() or IsSuicideInreversible()) then begin
    v.x := 0;
    v.y := -2;
    v.z :=0;
  end;
end;

procedure CWeaponMagazinedWGrenade__LaunchGrenade_controller_Patch(); stdcall;
asm
  //original
  movss [esp+4+$24], xmm2

  pushad
    mov eax, [esp + 32 + 8]    //2nd arg
    push eax
    push esi
    call LaunchGrenade_controller_Correct
  popad
end;

////////////////////////////////��������� ���� � CWeaponMagazinedWGrenade__Action//////////////////////////////////////

procedure TryShootGLFix(wpn:pointer); stdcall;
var
  rl:pCRocketLauncher;
  g_name:PChar;
  buf:WpnBuf;
begin
  rl:=dynamic_cast(wpn,0, RTTI_CWeaponMagazinedWGrenade, RTTI_CRocketLauncher, false);
  buf:=GetBuffer(wpn);
  if buf = nil then exit;
  if not (OnShoot_CanShootNow(wpn)) or (rl=nil) or (GetRocketsCount(rl)>0)  then begin
    //�������� ������, ������ ������
    exit;
  end else if GetCurrentAmmoCount(wpn)<=0 then begin
    //�������� ������, ��� �����������
    virtual_CWeaponMagazined__OnEmptyClick(wpn);
  end else begin
    if buf.last_frame_rocket_loaded<>GetCurrentFrame() then begin
      //�������� �����, ������� �������� �����
      g_name:=game_ini_read_string(GetGLCartridgeSectionByType(wpn, GetGrenadeCartridgeFromGLVector(wpn, GetAmmoInGLCount(wpn)-1).m_local_ammotype),'fake_grenade_name');
      CRocketLauncher__SpawnRocket(rl, g_name);
      //��������� ������� �������� � ��������
      SetAmmoInGLCount(wpn, GetCurrentAmmoCount(wpn)-1);
      SetCurrentAmmoCount(wpn, GetCurrentAmmoCount(wpn)-1);

      buf.last_frame_rocket_loaded:=GetCurrentFrame();
    end;
  end;
end;

procedure TryShootGLFix_Patch(); stdcall;
asm
  pushad
    push esi
    call TryShootGLFix
  popad
end;
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

procedure CWeaponRG6__AddCartridge_Replace_Patch(); stdcall;
asm
  mov eax, xrgame_addr
  add eax, $2DEA80
  jmp eax
end;


function RL_SpawnRocket(rl:pCRocketLauncher):boolean; stdcall;
var
  wpn:pointer;
  g_name:PChar;
  buf:WpnBuf;
begin
  result:=true;
  if GetRocketsCount(rl)=0 then begin
    wpn:=dynamic_cast(rl, 0, RTTI_CRocketLauncher, RTTI_CWeaponMagazined, false);
    if wpn=nil then exit;
    buf:=GetBuffer(wpn);
    if (GetAmmoInMagCount(wpn)>0) and (buf<>nil) and (buf.last_frame_rocket_loaded<>GetCurrentFrame()) then begin
      g_name:=game_ini_read_string(GetMainCartridgeSectionByType(wpn, GetCartridgeFromMagVector(wpn, GetAmmoInMagCount(wpn)-1).m_local_ammotype),'fake_grenade_name');
      CRocketLauncher__SpawnRocket(rl, g_name);
      buf.last_frame_rocket_loaded:=GetCurrentFrame();
      buf.rocket_launched:=false;
      result:=false;
    end;
  end else begin
    result:=not buf.rocket_launched;
    if result then buf.rocket_launched:=true;
  end;
end;

procedure CWeaponRG6__FireStart_SpawnRocket_Patch(); stdcall;
asm
  pushad
  push ecx
  call RL_SpawnRocket
  cmp al, 0
  popad
  jne @continue
  //������ �� ��������� ���! ������� �� ��������� ������� ����
  add esp, 4    //ret addr
  pop ebp
  add esp, $40a0
  ret

  @continue:
  //original
  mov eax, xrgame_addr
  add eax, $2CC650   //CRocketLauncher::getRocketCount
  call eax
end;


procedure CWeaponRPG7__FireStart_SpawnRocket_Replace_Patch(); stdcall;
asm
  pushad
  lea ecx, [ecx+$480]
  push ecx
  call RL_SpawnRocket
  cmp al, 0
  popad

  je @ret_noact

  //original
  mov eax, xrgame_addr
  add eax, $2CFE50  //CWeaponMagazined::FireStart
  jmp eax

  @ret_noact:
  ret
end;

procedure CWeaponRPG7__ReloadMagazine_Replace_Patch(); stdcall;
asm
  mov eax, xrgame_addr
  add eax, $2D0F10
  jmp eax
end;

procedure GetNewMotionSpeed(name:pshared_str; value:psingle); stdcall;
var
  act:pointer;
  wpn:pointer;
  str:string;
  anm_name:string;
const
  ANIMATOR_SLOT:cardinal =11;
  SUPERSTAMINA_HIT_PERIOD:cardinal=1000;
begin
  //TODO:���� ��, ��� � ���������?
  value^:=1;
  act:=GetActor();
  if act=nil then exit;
  wpn:=GetActorActiveItem();
  if wpn=nil then exit;

  anm_name:=get_string_value(name);
  if (leftstr(anm_name, length('anm_hide'))='anm_hide') then begin
    if GetForcedQuickthrow() or (GetActorTargetSlot()=ANIMATOR_SLOT) then begin
      value^:=game_ini_r_single_def(GetHUDSection(wpn), 'hide_factor_common', 1.8);
      value^:=game_ini_r_single_def(GetHUDSection(wpn), PChar('hide_factor_'+anm_name), value^);
    end else if (GetTimeDeltaSafe(GetLastSuperStaminaHitTime()) < SUPERSTAMINA_HIT_PERIOD ) then begin
      value^:=100;
    end;
  end;
end;

procedure CalcMotionSpeed_QuickItems_Patch(); stdcall;
asm
  push ecx
  lea ecx, [esp]
  pushad
    push ecx    //buffer
    mov ecx, [esp+4]
    push ecx    //anim
    call GetNewMotionSpeed
  popad
  fld [esp]
  add esp, 4
  
  //original
  pop ecx
  ret
end;

procedure attachable_hud_item__anim_play_cameff_patch; stdcall;
asm
  //���� �������� �������� ������ ��� �������� - ������������� ���������
  test eax, eax
  je @finish
    push $12
    call CCameraManager__RemoveCamEffector
  @finish:
end;

function IsShotNeededNow(wpn:pointer):boolean; stdcall;
var
  buf:WpnBuf;
  pos, dir:FVector3;
  owner:pointer;
  rqr:rq_result;
  aimperiod:integer;
  is_aim_exist:boolean;
  is_shot_after_key_released:boolean;
  entity:pointer;
  act:pointer;
begin
  result:=true;
  buf:=GetBuffer(wpn);
  if (buf=nil) or (GetShootLockTime(wpn)>0) then exit;
  aimperiod:=(buf.GetAutoAimPeriod());
  if aimperiod=0 then exit;

  pos:=GetLastFP(wpn);
  dir:=GetLastFD(wpn);
  owner:=GetOwner(wpn);
  if owner<>nil then begin
    CorrectShooting(wpn, owner, @pos, @dir);
  end;

  is_aim_exist:=Level_RayPick(@pos, @dir, 1000, rq_target__rqtObject, @rqr, owner);

  if not is_visible_by_thermovisor(rqr.O) and FindBoolValueInUpgradesDef(wpn, 'autoaim_only_alive', game_ini_r_bool_def(GetSection(wpn), 'autoaim_only_alive', false), true) then begin
    is_aim_exist:=false;
  end;

  entity:=dynamic_cast(rqr.O, 0, RTTI_CObject, RTTI_CEntity, false);
  if is_aim_exist and FindBoolValueInUpgradesDef(wpn, 'autoaim_ignore_dead', game_ini_r_bool_def(GetSection(wpn), 'autoaim_ignore_dead', false), true) and not is_object_has_health(entity) then begin
    is_aim_exist:=false;  
  end;

  is_shot_after_key_released := FindBoolValueInUpgradesDef(wpn, 'autoaim_shot_after_key_released', game_ini_r_bool_def(GetSection(wpn), 'autoaim_shot_after_key_released', false), true);

  if aimperiod>0 then begin
    if (is_shot_after_key_released) then begin
      // ����� � ��������� ����� ���������� ������ - � ������ ������� ���������� ������ ������
      if IsActionKeyPressedInGame(kWPN_FIRE) then begin
        buf.SetAutoAimStartTime(GetGameTickCount());
      end;
    end else if buf.GetAutoAimStartTime=0 then begin
      //����� � ���������� ��������� - ��� �� ����������.
      buf.SetAutoAimStartTime(GetGameTickCount());
    end;
    result:= is_aim_exist or (GetTimeDeltaSafe(buf.GetAutoAimStartTime())>=buf.GetAutoAimPeriod());

    if result then begin
      buf.SetAutoAimStartTime(0);
    end else begin
      //�� ���� ����� �� ��������� shoot
      if GetShootLockTime(wpn)<=0 then SetShootLockTime(wpn, 0);
    end;
  end else begin
    //����� � ������� ��������
    result:=is_aim_exist;
    if (not result) then begin
     if FindBoolValueInUpgradesDef(wpn, 'autoaim_shot_cancellation', game_ini_r_bool_def(GetSection(wpn), 'autoaim_shot_cancellation', false), true) then begin
      //� ��� �������������� ��������������, ���������� ��������
      SetShootLockTime(wpn, -1);
     end else if IsActionKeyPressedInGame(kWPN_FIRE) then begin
      //� ��� ������� ������������ ����������, �� ���� ����� �� ��������� shoot
      if GetShootLockTime(wpn)<=0 then SetShootLockTime(wpn, 0);
     end else begin
      //�������� ��� �� ����
      SetShootLockTime(wpn, -1);
     end;
    end;
  end;


  act:=GetActor();
  if not result and (act<>nil) and (act=GetOwner(wpn)) then begin
    if GetActorActionStateInt(act, actTotalActions)<>GetActorActionStateInt(act, actTotalActions, mState_OLD) then begin
      SetCurrentState(wpn, EHudStates__eIdle);
      PlayAnimIdle(wpn);
      SetCurrentState(wpn, EWeaponStates__eFire);
    end;
  end;

end;

procedure CWeaponMagazined__state_Fire_autoaim_patch; stdcall;
asm
  comiss xmm0, [esi+$390]
  jbe @finish

  pushad
    push esi
    call IsShotNeededNow
    cmp al, 0
  popad

  @finish:
end;


{procedure CWeaponRPG7__OnEvent_RemoveAmmoAfterRocketShot(); stdcall;
asm
  //��� ��������� ������� ������������� ����� ������ ������ - ��� ��� ��� ������������, ��� ������ �� ����� ��������
  //!!!� ���������, �������� ����������� �������� �������������� ������!!!
  push 0
  push esi
  call virtual_CWeaponMagazined__UnloadMagazine
end; }


function CWeaponMagazined__CheckForMisfire_validate_NoMisfire(wpn:pointer):boolean; stdcall;
var
  buf:WpnBuf;
  problems_lvl:single;
begin
  //������ ���� ���� �� ������. �� ��� ��� ����� ��������! ������� true, ���� �� ��������
  result:=false;

  if (GetOwner(wpn) = GetActor()) and (GetActor()<>nil) and not game_ini_r_bool_def(GetSection(wpn), 'actor_can_shoot', true) then begin
    result:=true;
  end;

  buf:=GetBuffer(wpn);
  problems_lvl:=buf.GetMisfireProblemsLevel();
  if (buf<>nil) and (problems_lvl>0) and (CurrentElectronicsProblemsCnt()>=problems_lvl) then begin
    SetWeaponMisfireStatus(wpn, true);
    virtual_CHudItem_SwitchState(wpn, EWeaponStates__eMisfire);
    result:= not OnWeaponJam(wpn);
  end;
end;

procedure CWeaponMagazined__CheckForMisfire_validate_NoMisfire_patch(); stdcall;
asm
  pushad
    push esi
    call CWeaponMagazined__CheckForMisfire_validate_NoMisfire
    cmp al, 0
  popad
  setnz al
  ret
end;

procedure Manager__upgrade_install_Patch(); stdcall;
asm
  test eax, eax
  jne @upgrade_found
  mov [esp+$30], 10
  mov esi, xrgame_addr
  add esi, $af60e
  jmp esi


  @upgrade_found:
  //original instructions
  mov ebx, [esp+$34]
  mov edi, [esp+$2c]
  mov esi, xrgame_addr
  add esi, $af4e9
  jmp esi
end;


function IsUpgradeBanned(item:pointer; upgrade_id:pshared_str; loading:boolean):boolean; stdcall;
var
  wpn:pointer;
  banned_ups, mask:string;
  sect:PAnsiChar;
const
  BANNED_UPGRADES:PAnsiChar='banned_upgrades';
begin
  result:=false;
  sect:=GetSection(item);
  if game_ini_line_exist(sect, BANNED_UPGRADES) then begin
    banned_ups:=game_ini_read_string(sect, BANNED_UPGRADES)+',';
    while GetNextSubStr(banned_ups, mask, ',') do begin
      if leftstr(get_string_value(upgrade_id), length(mask)) = mask then begin
        Log('Found banned upgrade "'+get_string_value(upgrade_id)+'" for item '+sect);
        result:=true;
        break;
      end;
    end;
  end;
end;

procedure Manager__upgrade_install_checkbanned_Patch(); stdcall;
asm

  mov eax, esp

  pushad
  movzx ebx, byte ptr [eax+$10]
  push ebx
  push [eax+$C] //pshared_str upgrade_id
  push [eax+$8] //CInventoryItem* item
  call IsUpgradeBanned
  test al, al
  popad
  je @orig


  pop eax //ret addr
  xor eax, eax
  ret $0c
@orig:
  pop eax //ret addr
  sub esp, $18 //original
  push ebx
  push ebp
  jmp eax
end;

procedure RegisterGrenadeShot(wpn:pointer); stdcall;
var
  buf:WpnBuf;
begin
  buf:=GetBuffer(wpn);
  if buf <> nil then begin
    buf.RegisterShot();
  end;
end;

procedure CWeaponMagazinedWGrenade__LaunchGrenade_RegisterShot_Patch(); stdcall;
asm
  pushad
  push esi
  call RegisterGrenadeShot
  popad

  //original
  mov eax, [esi+$318]
  ret
end;

procedure FixNullParent_Patch(); stdcall;
asm
  push ecx
  mov eax, xrgame_addr
  add eax, $512be0
  call [eax]    //CObject::H_Parent
  pop ecx

  cmp eax, 0
  jne @finish
  mov eax, ecx

  @finish:
  ret
end;

procedure CWeapon__AddShotEffector_replace_Patch(); stdcall;
asm
  mov eax, ecx
  mov ecx, [eax+$8c]
  test ecx, ecx
  je @finish;
  mov ecx, [ecx+$48]
  mov edx, [ecx]
  push eax
  mov eax, [edx+$d0]
  call eax
  @finish:
  ret
end;

function GetAmmoMaterial(section:PAnsiChar):PAnsiChar; stdcall;
const
  DEFAULT_MATERIAL:PAnsiChar = 'objects\bullet';
begin
  result:=game_ini_read_string_def(section, 'material', DEFAULT_MATERIAL);
end;

procedure CCartridge__Load_material_Patch(); stdcall;
asm
  push [esp] // ��������� ����� ��������
  lea eax, [esp+4] //�����, � ������� ����� �������� ��������, push'������ � ���������

  pushad
  push eax //save ptr to buf

  push edi //ammo section
  call GetAmmoMaterial

  pop ecx //restore ptr to buf
  mov [ecx], eax
  popad
end;

function GetCartridgeMaterial(c:pCCartridge):PAnsiChar; stdcall;
begin
  result:=GetAmmoMaterial(get_string_value(@c.m_ammo_sect));
end;

procedure CWeaponAmmo__Get_material_Patch; stdcall;
asm
  push [esp] // ��������� ����� ��������
  lea eax, [esp+4] //�����, � ������� ����� �������� ��������, push'������ � ���������

  pushad
  push eax //save ptr to buf

  push ebp //cartridge
  call GetCartridgeMaterial

  pop ecx //restore ptr to buf
  mov [ecx], eax
  popad
end;

function GetCartridgeHitType(c:pCCartridge):cardinal; stdcall;
var
  s:PAnsiChar;
begin
  result:=6; // ALife::eHitTypeFireWound
  if c = nil then exit;

  s:=get_string_value(@c.m_ammo_sect);
  if (s=nil) then exit;

  result:=game_ini_r_int_def(s, 'hit_type', result)
end;

procedure CShootingObject__FireBullet_hittype_Patch();stdcall;
asm
  fstp dword ptr [esp+4]
  push [esp] // ��������� ����� ��������, �������� �����
  lea ecx, [esp+4] //����� ������

  pushad
  push ecx //save buf
  push [ecx+8] //cartridge
  
  call GetCartridgeHitType
  pop ecx // restore buf
  mov [ecx], eax
  popad

  mov ecx, [esp+$4c] //��������������� ecx

end;

procedure ModifyObjectHitBeforeProcessing(h:pSHit); stdcall;
begin
  // ������������ ���� � ���� ����� ���, ��� ������ ��� �� ��������� ����������� �������
  if h.hit_type = EHitType__eHitTypeBurn then begin
    h.add_wound:=1;
  end;
end;

procedure CGameObject__OnEvent_addwoundonhit_Patch(); stdcall;
asm
  // original
  mov edx,[eax+$E8]
  lea ecx,[esp+$14]

  pushad
  push ecx
  call ModifyObjectHitBeforeProcessing
  popad

end;

procedure ScaleWoundByHitType(obj:pointer; hit_power:psingle; hit_type:cardinal); stdcall;
var
  factor1, factor2:single;
  sect:PAnsiChar;
begin
  sect:=get_string_value(GetCObjectSection(obj));
  sect:=game_ini_read_string_def(sect, 'condition_sect', sect);
  
  factor1:=game_ini_r_single_def('gunslinger_wound_factors', PAnsiChar('wound_factor_for_hit_type_'+inttostr(hit_type)), 1.0);
  factor2:=game_ini_r_single_def(sect, PAnsiChar('wound_factor_for_hit_type_'+inttostr(hit_type)), 1.0);

  // log('Section '+sect+', hit_type '+inttostr(hit_type)+', factor1 is '+floattostr(factor1)+', factor2 is '+floattostr(factor2));

  hit_power^:=hit_power^*factor1*factor2;
end;

procedure CEntityCondition__AddWound_scalewoundsize_Patch(); stdcall;
asm
  lea esi, [esp+$14] //hit_power
  mov eax, [esp+$18] //hit_type

  pushad
  push eax
  push esi
  push [ecx+$44] // this->m_object
  call ScaleWoundByHitType
  popad

  //original
  mov esi, ecx
  mov eax, [esi+$48]
end;

function GetMinFireParticleForDeadEntities():cardinal;
begin
  result:=game_ini_r_int_def('entity_fire_particles', 'min_burn_time_dead', 5000);
end;

procedure CEntityAlive__UpdateFireParticles_deadfire_Patch(); stdcall;
asm
  pushad
  mov ecx, edi
  mov eax, xrgame_addr
  add eax, $40aa0
  call eax // CEntity::g_Alive
  test eax, eax
  popad

  jne @alive
  
  lea eax, [esp+$8] // ����� ��������� � �������� �����
  pushad
  push eax
  call GetMinFireParticleForDeadEntities
  pop ecx
  mov [ecx], eax
  popad

  @alive:
  //original
  fldcw [esp+$1c]
  push [esp]
  mov [esp+4], esi
end;

procedure CEntityAlive__shedule_Update_updateparticles_Patch(); stdcall;
asm
  pushad
  lea ecx, [edi+$1b0] //cast to CParticlesPlayer
  mov eax, xrgame_addr
  add eax, $282b90
  call eax  //CParticlesPlayer::UpdateParticles
  popad

  //original
  mov eax,[edx+$254]
end;

function CorrectBleedingForHitType(obj:pointer; hit_type:cardinal; bleeding:single):single; stdcall;
var
  factor1, factor2:single;
  sect:PAnsiChar;
begin
  result:=bleeding;

  sect:=get_string_value(GetCObjectSection(obj));
  sect:=game_ini_read_string_def(sect, 'condition_sect', sect);

  factor1:=game_ini_r_single_def('gunslinger_wound_factors', PAnsiChar('bleeding_factor_for_hit_type_'+inttostr(hit_type)), 1.0);
  factor2:=game_ini_r_single_def(sect, PAnsiChar('bleeding_factor_for_hit_type_'+inttostr(hit_type)), 1.0);

  //log('Section '+sect+', hit_type '+inttostr(hit_type)+', val='+floattostr(bleeding)+', factor1 is '+floattostr(factor1)+', factor2 is '+floattostr(factor2));

  result:=result*factor1*factor2;
end;

function GetWoundComponentByHitType(wound:pointer; hit_type:cardinal):single; stdcall;
var
 a_m_Wounds:cardinal;
begin
  result:=0;
  if hit_type>=EHitType__eHitTypeMax then exit;

  a_m_Wounds:=cardinal(wound)+$10;
  result:=psingle(a_m_Wounds+hit_type*sizeof(single))^;
end;

function CalcWoundTotalSize(obj:pointer; wound:pointer):single; stdcall;
var
  i:integer;
  bleeding:single;
begin
  result:=0;
  for i:=0 to EHitType__eHitTypeMax do begin
    bleeding:=GetWoundComponentByHitType(wound, i);
    if bleeding > 0 then begin
      result:=result+CorrectBleedingForHitType(obj, i, bleeding);
    end;
  end;
end;

procedure CEntityCondition__BleedingSpeed_reimpl(obj:pointer;wounds:pxr_vector; res:psingle); stdcall;
var
  i:integer;
  pwound:pointer;
begin
  res^:=0;
  //if items_count_in_vector(wounds, sizeof(pointer)) > 0 then begin
  //  Log('Wounds count: '+inttostr(items_count_in_vector(wounds, sizeof(pointer))));
  //end;

  for i:=0 to items_count_in_vector(wounds, sizeof(pointer))-1 do begin
    pwound:=get_item_from_vector(wounds, i, sizeof(pointer));
    res^:=res^+CalcWoundTotalSize(obj, pointer(pcardinal(pwound)^));
  end;
end;

procedure CEntityCondition__BleedingSpeed_Patch(); stdcall;
asm
  push 0
  lea eax, [esp] 

  pushad
  mov edi, ecx //this

  push eax // ptr to result
  lea esi, [edi+$48] // m_WoundVector
  push esi       // this->m_WoundVector
  push [edi+$44] // this->m_object
  call CEntityCondition__BleedingSpeed_reimpl
  popad

  fld [esp]
  add esp, 4
  ret
end;

function Init:boolean;
var
  jmp_addr:cardinal;
begin
  result:=false;

  //������� ���������� ����� ( ������ CWeapon::CheckForMisfire)
  jmp_addr:= xrGame_addr+$2BD0AF;
  if not WriteJump(jmp_addr, cardinal(@WeaponJammed_Patch),16, true) then exit;

  //������� ������/������� ��������
  jmp_addr:=xrGame_addr+$2CCD75;
  if not WriteJump(jmp_addr, cardinal(@EmptyClick_Patch), 8, true) then exit;

  //-----------------------------------------------------------------------------------------------------
  //� CWeaponMagazined::Attach
  //����� �������
  InitAttachAddon(xrGame_addr+$2CEE33, $11);
  //                           register^|^addon type  
  //����� ���������(�������?)
  InitAttachAddon(xrGame_addr+$2CEEF5, $12);
  //������ ����� ���������, �����
  InitAttachAddon(xrGame_addr+$2D26F7, $02);

  //����� ���������
  InitAttachAddon(xrGame_addr+$2CEE5A, $14);

  //� CUIActorMenu::AttachAddon �������� ������������ ����� ������ �������

  //-----------------------------------------------------------------------------------------------------
  //CWeaponMagazined::Detach
  //����� ���������
  InitDetachAddon(xrGame_addr+$2CDB22, 4, 38);

  //����� ���������(�������?), �������� ����� �� ����� ������� ������, ������� ����� ������ ��� ���� ������
  InitDetachAddon(xrGame_addr+$2CDBAE, 2, 0, true);
  //������ ����� ���������, ������� ������������
  InitDetachAddon(xrGame_addr+$2D3BA1, 2, 82);

  //����� �������
  InitDetachAddon(xrGame_addr+$2CDA89, 1, 38);
  if not nop_code(xrGame_addr+$2CDA1E, 6) then exit;//����� ����� ���������, ������������ ���� �������
  //-----------------------------------------------------------------------------------------------------
  //�������� ��������
  jmp_addr:= xrGame_addr+$46E0C4;
  if not WriteJump(jmp_addr, cardinal(@UnloadMag_Patch), 5, true) then exit;
  //-----------------------------------------------------------------------------------------------------

  //����� � �������
  jmp_addr:=xrGame_addr+$2C120B;
  if not WriteJump(jmp_addr, cardinal(@CWeapon_NetSpawn_Patch_middle),6, true) then exit;

  jmp_addr:=xrGame_addr+$2C1328;
  if not WriteJump(jmp_addr, cardinal(@CWeapon_NetSpawn_Patch_end),6, true) then exit;

  jmp_addr:=xrGame_addr+$2BEFE9;
  if not WriteJump(jmp_addr, cardinal(@CWeapon_NetDestroy_Patch),6, true) then exit;

  upgrade_weapon_addr:=xrGame_addr+$2D09D6;
  if not WriteJump(upgrade_weapon_addr, cardinal(@Upgrade_Weapon_Patch), 5) then exit;
  //[bug]�������� ��� � ����������������� ������ �������� �� ����� ��������
  nop_code(xrGame_addr+$2d0abe, 6);


  //������� ����� ����� ������ ��������
  if not InitChangeFireMode(xrGame_addr+$2CE2E0,0) then exit;
  if not InitChangeFireMode(xrGame_addr+$2CE340,1) then exit;


  //���������������� ���������� ����������� ��������� � �����
  jmp_addr:=xrGame_addr+$2CFF6B;
  if not WriteJump(jmp_addr, cardinal(@OnJammedHintShow_Patch), 19, true) then exit;

  //���������� OnSwitchState
  jmp_addr:=xrGame_addr+$2BC4D7;
  if not WriteJump(jmp_addr, cardinal(@CHudItem__SwitchState_Patch), 10, false) then exit;


  //�������� �������� ����� + �������� ��� ��������� � ���� � �����
  jmp_addr:=xrGame_addr+$2d5491;
  if not WriteJump(jmp_addr, cardinal(@OnKnifeKick_Patch), 5, true) then exit;
  jmp_addr:=xrGame_addr+$2d54A6;
  if not WriteJump(jmp_addr, cardinal(@OnKnifeKick_Patch), 5, true) then exit;

  //��������� �������������� ������������ ��������
  jmp_addr:=xrGame_addr+$2BEC7B;
  if not WriteJump(jmp_addr, cardinal(@CWeapon__Action_Patch), 11, true) then exit;

  //[bug] ��� - ������ ��������� � CWeapon::Action �� cmd_start �����������/��������� ������� � ����� ���� �������� (��� �������� � ��� ��������)
  jmp_addr:=xrGame_addr+$2BEDAF;
  if not WriteJump(jmp_addr, cardinal(@CWeapon__Action_zoomincdec_Patch), 7, true) then exit;


  //���������� ���������� � ����������
  jmp_addr:=xrGame_addr+$2bc7e0;
  if not WriteJump(jmp_addr, cardinal(@CWeapon__OnAnimationEnd_Patch), 5, false) then exit;

  //[bug] ���� �������� ������ ��� ���������
  jmp_addr:=xrGame_addr+$2F96A0;
  if not WriteJump(jmp_addr, cardinal(@CHudItem__SendHiddenItem_Patch), 5, true) then exit;
  jmp_addr:=xrGame_addr+$2d4f30;
  if not WriteJump(jmp_addr, cardinal(@CWeaponKnife__OnAnimationEnd_Patch), 7, true) then exit;
  jmp_addr:=xrGame_addr+$2CCD86;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazined__OnAnimationEnd_Patch), 5, true) then exit;
  jmp_addr:=xrGame_addr+$2DE3DB;
  if not WriteJump(jmp_addr, cardinal(@CWeaponShotgun__OnAnimationEnd_OnClose_Patch), 6, true) then exit;

  jmp_addr:= xrgame_addr+$2BEE13;
  if not WriteJump(jmp_addr, cardinal(@CWeapon__OnZoomOut_Patch), 6, true) then exit;

  jmp_addr:= xrgame_addr+$2C07E5;
  if not WriteJump(jmp_addr, cardinal(@CWeapon__OnZoomIn_Patch), 6, true) then exit;

  //[bug] ���� ������ � ���� ������ ��� �������� ����� ��������
  jmp_addr:=xrGame_addr+$2AC678;
  if not WriteJump(jmp_addr, cardinal(@CEatableItemObject__OnH_A_Independent_Patch), 14, false) then exit;

  //[bug] ���� ��������������� ��������� ��� ������ ������� � ���������� ���������� � ������ ��� ������������� ������
  jmp_addr:=xrGame_addr+$2CDD6B;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazined__InitAddons_Patch), 6, true) then exit;
  //[bug] ���� ����������� �������� �������� ���������� � ����
  jmp_addr:=xrGame_addr+$2D5C87;
  if not WriteJump(jmp_addr, cardinal(@CWeaponKnife__OnStateSwitch_SetPending_Patch), 6, true) then exit;
  jmp_addr:=xrGame_addr+$2D5CA0;
  if not WriteJump(jmp_addr, cardinal(@CWeaponKnife__OnStateSwitch_SetPending_Patch), 6, true) then exit;

  jmp_addr:=xrGame_addr+$2F9640;
  if not WriteJump(jmp_addr, cardinal(@CHudItem__OnAnimationEnd_Patch), 5, true) then exit;

  jmp_addr:=xrGame_addr+$2D6B97;
  if not WriteJump(jmp_addr, cardinal(@CWeaponKnife__OnMotionMark_Patch), 6, true) then exit;


  //������ ����������� �������� ����� ��� ������������ �����������
  jmp_addr:=xrGame_addr+$2D314A;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazinedWGrenade__LaunchGrenade_controller_Patch), 6, true) then exit;

  //[bug] ��� �������� � ��������� � ������ ������������ - ���� ���� ������� ������, ����� ����� �� �� ������������ ���������, � ��� �������
  jmp_addr:=xrGame_addr+$2D30A2;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazinedWGrenade__LaunchGrenade_dir_Patch), 5, true) then exit;
  if not nop_code(xrgame_addr+$2D3038, 6) then exit;
  //���������� ��� ��-6
  jmp_addr:=xrGame_addr+$2DFA7A;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazinedWGrenade__LaunchGrenade_dir_Patch), 5, true) then exit;
  if not nop_code(xrgame_addr+$2DFA10, 6) then exit;  

  //[bug]��� ������ � ���������� - ��� �������� �� ����������� CCustomRocket'�
  //��� ����� ��������� ������������ ��� ������ CWeaponMagazinedWGrenade::Action, ������������� ��� ������� �������� � ���������
  //������ ������ ������: ������� ������ �� ��� �����������, � ��� ��������
  jmp_addr:=xrGame_addr+$2D3ABE;
  if not WriteJump(jmp_addr, cardinal(@TryShootGLFix_Patch), 47, true) then exit;
  nop_code(xrgame_addr+$2D206F, 13);
//  nop_code(xrgame_addr+$2D35B9, 13); //��������� � WeaponDataSaveLoad ��� ����� �������������� ��������� �� ������
  //jmp_addr:=xrGame_addr+$2D35ED;
  //� CWeaponMagazinedWGrenade::net_Spawn ������������ ������� CCartridge
  //if not WriteJump(jmp_addr, xrGame_addr+$2D35E1, 5, false) then exit;
  nop_code(xrgame_addr+$2D3519, 6);
  nop_code(xrgame_addr+$2D31C0, 12);  

  //���������� ������ ��� CWeaponRG6
  //�������� CWeaponRG6::AddCartridge �� ������
  jmp_addr:=xrGame_addr+$2DF5B0;
  if not WriteJump(jmp_addr, cardinal(@CWeaponRG6__AddCartridge_Replace_Patch), 6, false) then exit;
  nop_code(xrgame_addr+$2DF4A9, 2);
  jmp_addr:=xrGame_addr+$2DF6ED;
  if not WriteJump(jmp_addr, cardinal(@CWeaponRG6__FireStart_SpawnRocket_Patch), 5, true) then exit;
  //���������� ��� CWeaponRPG7
  jmp_addr:=xrGame_addr+$2D9440;
  if not WriteJump(jmp_addr, cardinal(@CWeaponRPG7__ReloadMagazine_Replace_Patch), 9, false) then exit;
  nop_code(xrgame_addr+$2D973E, 1, CHR($EB));
  jmp_addr:=xrGame_addr+$2D94C0;
  if not WriteJump(jmp_addr, cardinal(@CWeaponRPG7__FireStart_SpawnRocket_Replace_Patch), 5, false) then exit;

  //[bug] ��� - ��-�� dropCurrentRocket() � CWeaponRG6::FireStart ����� �������� ����� ����� �������� � �������
  //�� ���� ����� �� ������, � ��������� ����������� 2 CCustomRocket! ��-�� ������ FireStart 2 ����. �� ������ ���������� ���-7
  nop_code(xrgame_addr+$2DFBDD, 5);
  result:=true;

  //���������� ��������� �������� ����������/�������� ������ ��� ������������ ��/�� ����� ���������� � ������ ���������� �����
  jmp_addr:=xrGame_addr+$2FB5EA;
  if not WriteJump(jmp_addr, cardinal(@CalcMotionSpeed_QuickItems_Patch), 5, false) then exit;

  //����, ��������� �������� ���������(�������)
  jmp_addr:=xrGame_addr+$2D05E3;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazined__state_Fire_autoaim_patch), 7, true) then exit;

  // � CWeapon::CheckForMisfire - ����� ����, ��� ���������, ��� ������ ���� �� ������, �������� ��� ��� - � �����, ���-���� ���������?
  jmp_addr:=xrGame_addr+$2bd0c4;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazined__CheckForMisfire_validate_NoMisfire_patch), 5, false) then exit;

  //� Manager::upgrade_install ��������� �������� - ���� ������� �� ������� ����� upgrade_verify, �� � �� ��������� ��� ������
  jmp_addr:=xrGame_addr+$af4e1;
  if not WriteJump(jmp_addr, cardinal(@Manager__upgrade_install_Patch), 8, false) then exit;

  // � ����� ������ Manager::upgrade_install �������� ���������� ��������, ���������� �� ��������
  jmp_addr:=xrGame_addr+$af4d0;
  if not WriteJump(jmp_addr, cardinal(@Manager__upgrade_install_checkbanned_Patch), 5, true) then exit;

  // ������������ ������� �   CWeaponMagazinedWGrenade::LaunchGrenade
  jmp_addr:=xrGame_addr+$2d2cc7;
  if not WriteJump(jmp_addr, cardinal(@CWeaponMagazinedWGrenade__LaunchGrenade_RegisterShot_Patch), 6, true) then exit;

  // [bug] ��� � CWeaponMagazinedWGrenade::LaunchGrenade - ��� ��������� �� �������� ������� �� ����������� ���������� H_Parent(). ���� ������ ���� ��������� (��������, ��-�� ������) - ��� �������
  jmp_addr:=xrGame_addr+$2d317f;
  if not WriteJump(jmp_addr, cardinal(@FixNullParent_Patch), 6, true) then exit;
  //���������� � CWeaponRPG7::switch2_Fire
  jmp_addr:=xrGame_addr+$2d9d12;
  if not WriteJump(jmp_addr, cardinal(@FixNullParent_Patch), 6, true) then exit;
  // ���������� � CWeaponRG6::FireStart
  jmp_addr:=xrGame_addr+$2dfb57;
  if not WriteJump(jmp_addr, cardinal(@FixNullParent_Patch), 6, true) then exit;
  //todo: ���������� � CGrenade::Throw
  jmp_addr:=xrGame_addr+$2c6403;
  if not WriteJump(jmp_addr, cardinal(@FixNullParent_Patch), 6, true) then exit;

////////////////////////////////////////////////////////////////////////////////////
  //������ �� ����������� �������� �� ������, �� �������������� ������
  //� CWeapon::FireTrace � ������ FireBullet ���������� �������� �� ��, ��� H_Parent ����� ���� �������
  jmp_addr:=xrGame_addr+$2c3281;
  if not WriteJump(jmp_addr, cardinal(@FixNullParent_Patch), 6, true) then exit;

  //��������� ������ �� ������� H_Parent � CWeaponMagazined::FireStart
  if not nop_code(xrgame_addr+$2cfec6, 1, chr($eb)) then exit;

  //� CWeaponMagazined::state_Fire ��������� �������� ��� ���������� ��������� - ���������� je � xrgame.dll+2d0403 �� xrgame.dll+2d0588 (������� �� ���������� m_vStartPos � m_vStartDir) � ����� ��������
  if not nop_code(xrgame_addr+$2d0405, 1, chr($7f)) then exit;
  if not nop_code(xrgame_addr+$2d0406, 1, chr($01)) then exit;
  if not nop_code(xrgame_addr+$2d0407, 1, chr($00)) then exit;
  if not nop_code(xrgame_addr+$2d0408, 1, chr($00)) then exit;

  // CWeapon::AddShotEffector (xrGame.dll+2c2ae0) - ��������� �������� �� ��, ��� inventory_owner ����������, �������� �������
  jmp_addr:=xrGame_addr+$2c2ae0;
  if not WriteJump(jmp_addr, cardinal(@CWeapon__AddShotEffector_replace_Patch), 8, false) then exit;

  // CWeapon::SwitchState (xrGame.dll+2bc3e0) - ��������� ������ ��������� ��� m_pInventory = nil
  if not nop_code(xrgame_addr+$2bc432, 6) then exit;

  // CWeapon::ParentMayHaveAimBullet (xrGame.dll+2c1070) - ��������� ����������� parent'a ���� �������
  if not nop_code(xrgame_addr+$2c1080, 2, chr($c3)) then exit;

  // � CEntityCondition::ConditionHit ������ ��������� eHitTypeBurn ���, ����� bAddWound �� ������������ � false
  // ������ jmp, ����� ��������� � �����, �� ������������ bAddWound
  jmp_addr:=$9e;
  if not WriteBufAtAdr(xrgame_addr+$27e932,@jmp_addr,sizeof(jmp_addr)) then exit;

  // � CCartridge::Load ��������� ����������� ��������� ������������ bullet_material_idx ��� ����
  jmp_addr:=xrGame_addr+$2c43c7;
  if not WriteJump(jmp_addr, cardinal(@CCartridge__Load_material_Patch), 5, true) then exit;

  // � CWeaponAmmo::Get - ����������, ���� ���������������� bullet_material_idx
  jmp_addr:=xrGame_addr+$2c486c;
  if not WriteJump(jmp_addr, cardinal(@CWeaponAmmo__Get_material_Patch), 5, true) then exit;

  // � CShootingObject::FireBullet (xrgame.dll+2bb920) ���� ����������� ����������� ������ ���� ����� �����
  jmp_addr:=xrGame_addr+$2bba26;
  if not WriteJump(jmp_addr, cardinal(@CShootingObject__FireBullet_hittype_Patch), 5, true) then exit;

  // � CGameObject::OnEvent ��� ��������� ��������� � ���� ����� ������� Hit ������ add_wound=true
  jmp_addr:=xrGame_addr+$280935;
  if not WriteJump(jmp_addr, cardinal(@CGameObject__OnEvent_addwoundonhit_Patch), 10, true) then exit;

  // � CEntityCondition::AddWound ������� ����������� �������������� ������ ���� � ����������� �� ���� �����
  jmp_addr:=xrGame_addr+$27e683;
  if not WriteJump(jmp_addr, cardinal(@CEntityCondition__AddWound_scalewoundsize_Patch), 5, true) then exit;

  // � CEntityAlive::UpdateFireParticles ���� �������� ������ �� ��������� �������� ��������� ����, �� �������� ������� �������� (����� "��������")
  jmp_addr:=xrGame_addr+$27b6dc;
  if not WriteJump(jmp_addr, cardinal(@CEntityAlive__UpdateFireParticles_deadfire_Patch), 5, true) then exit;

  //���� �������� CParticlesPlayer::UpdateParticles �� CEntityAlive::shedule_Update, ����� �������� ��������� ��������� ����� ������
  jmp_addr:=xrGame_addr+$27a768;
  if not WriteJump(jmp_addr, cardinal(@CEntityAlive__shedule_Update_updateparticles_Patch), 6, true) then exit;

  // [bug] ��� � CEntityCondition::BleedingSpeed - ��-�� ����, ��� �������� ������������ ������� ��� ������� �� ���� ���, �� ��� ��������� ��������� ���� ������������ �����������
  // ��� ����������� �������� ������� �� ���� ����������, ������ ����������� � ������������ � ���������� �� ���� ����
  jmp_addr:=xrGame_addr+$27dd00;
  if not WriteJump(jmp_addr, cardinal(@CEntityCondition__BleedingSpeed_Patch), 6, false) then exit;

  //������������� �������� - ��� ����� ������ �� CInventory::Activate ���������� SendDeactivateItem, ������� ������� SendHiddenItem (xrGame.dll+2dc9f0), ������������ GE_WPN_STATE_CHANGE � eHiding
  //����� ��� ����� ������� � ���������� ���������� CWeaponMagazined::switch2_Hiding, � ������� �����-�� �������� PlaySound, � ����� ������� SetPending(true).
  //�� ������ pending ������ ���������� � CWeaponMagazined::switch2_Hidden, �� �� ��� ������ ���� �� �������, ��� ��� ������ ��������� � ��������� �� �������� (�������� ���������� �������)

  //��������� �������� ������ �� �������:
  //CWeaponMagazined::state_Fire - xrgame.dll+2d0350
  //CWeaponMagazined::OnStateSwitch - xrgame.dll+2d01b0 -> CWeaponMagazined::switch2_Fire (xrgame.dll+2d0720)
  //CWeaponMagazined::Action - xrgame.dll+2ce7a0; CWeapon::Action - xrGame.dll+2bec70
  //CWeaponMagazined::OnShot - xrgame.dll+2ccc40
  //CEntityAlive::Hit - xrgame.dll+27bdb0
  //CBaseMonster::Hit - xrgame.dll+c6440
  //CEntityAlive::StartFireParticles - xrgame.dll+27ba30
  //CEntityAlive::UpdateFireParticles - xrgame.dll+27b600
  //CEntityCondition::UpdateCondition - xrgame.dll+27def0
  //CEntityCondition::UpdateHealth - xrgame.dll+27dd70
  //CEntityCondition::BleedingSpeed - xrgame.dll+27dd00
  //CAI_Stalker::react_on_member_death - xrgame.dll+192430
  //CStalkerDangerPlanner::update - xrgame.dll+xrgame.dll+1785b0
////////////////////////////////////////////////////////////////////////////////////


  //�������������� ��������� ��������� �� ���
  //!!!������ ����������� ������������� ������������!!!
//  jmp_addr:=xrGame_addr+$2D980B;
//  if not WriteJump(jmp_addr, cardinal(@CWeaponRPG7__OnEvent_RemoveAmmoAfterRocketShot), 5, true) then exit;

  //[bug] ��� � ������������� ������ ��������� ������ ��� ������������ ������ - thanks to SkyLoader
  //[upd �������� ���-���� ���... ���������, ����� �� ���
  //jmp_addr:=xrGame_addr+$2FEC28;
  //if not WriteJump(jmp_addr, cardinal(@attachable_hud_item__anim_play_cameff_patch), 8, true) then exit;
end;


end.

