unit Crows;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface
uses MatVectors;
function Init():boolean; stdcall;
function IsActorAttackedByBirds():boolean; stdcall;
procedure ResetBirdsAttackingState(); stdcall;

type
CAI_Crow = packed record
  _unknown:array[0..$30F] of Byte;
  vOldPosition:FVector3; //0x310
  st_current:cardinal; //0x31�
  st_target:cardinal;  //0x320
  vGoalDir:FVector3;   //0x324
  vCurrentDir:FVector3; //0x330
  vHPB:FVector3;        //0x33C
  fDHeading:single;     //0x348

  fGoalChangeDelta:single; //0x34C
  fSpeed:single;           //0x350
  fASpeed:single;          //0x354
  fMinHeight:single;       //0x358
  vVarGoal:FVector3;       //0x364
  fIdleSoundDelta:single;  //0x368

  fGoalChangeTime:single;  //0x36C
  fIdleSoundTime:single;   //0x370

  bPlayDeathIdle:byte;// bool, 0x374
  _unused_1:byte;
  _unused_2:word;
  o_workload_frame:cardinal; //0x378
  o_workload_rframe:cardinal; //0x37C
  //����������� �������...
end;

pCAI_Crow = ^CAI_Crow;
const
  ECrowStates__eUndef:integer = -1;
  ECrowStates__eDeathFall:integer = 0;
  ECrowStates__eDeathDead:integer = 1;
  ECrowStates__eFlyIdle:integer = 2;
  ECrowStates__eFlyUp:integer = 3;

var
  bird_attack_last_time:cardinal;

implementation
uses BaseGameData, Misc, sysutils, gunsl_config, ScriptFunctors, ActorUtils, math, RayPick, ConsoleUtils, LensDoubleRender;

function GetCrowHealthPtr(crow:pCAI_Crow):pSingle; stdcall;
asm
  mov @result, 0
  pushad
    mov eax, crow
    mov eax, [eax+$200]
    lea eax, [eax+$4]
    mov @result, eax
  popad
end;


procedure SetCrowStateInNetSpawn(crow:pCAI_Crow); stdcall;
begin
  if GetCrowHealthPtr(crow)^>0 then begin
    crow.st_current:=ECrowStates__eFlyIdle;
    crow.st_target:=ECrowStates__eFlyIdle;    
  end else begin
    crow.st_current:=ECrowStates__eDeathFall;
    crow.st_target:=ECrowStates__eDeathDead;
  end;

  //[bug] ��� - ���-�� ����� ������������������� � CAI_Crow::net_Spawn, ��-�� ���� ��� ��������� �������� ������������� ������ ��� ������� ������ �� ������... ��������.
  crow.o_workload_frame:=0;
  crow.o_workload_rframe:=0;
end;


procedure EnableCrowPhysics(crow:pCAI_Crow); stdcall;
asm
  pushad
    mov ecx, crow
    mov edi, xrgame_addr
    call [edi+$512D7C]   //processing_activate

    mov ecx, crow
    mov edi, xrgame_addr
    add edi, $1010C0
    call edi            //CAI_Crow::CreateSkeleton
  popad
end;


procedure CAICrow__net_Spawn_Patch(); stdcall;
asm
  pushad
    push esi
    call SetCrowStateInNetSpawn
  popad

  //������, ���� � ��� "�����" ����� (�� ���� ����� Die ���������, ��� Health>0) - ������������ ���������� ��������
  mov edi, [esi+CAI_Crow.st_target]
  cmp edi, ECrowStates__eDeathFall
  je @not_deactivate
  cmp edi, ECrowStates__eDeathDead
  je @not_deactivate
    mov ecx, esi
    mov edi, xrgame_addr
    call [edi+$512C44]   //processing_deactivate
    jmp @finish
  @not_deactivate:
    push esi
    call EnableCrowPhysics
  @finish:
end;

function CAI_Crow_Load(crow:pCAI_Crow; crow_section:PChar):PChar; stdcall; //������� ������ � ������� ������
begin
  result:=game_ini_read_string(crow_section, 'snd_idle');
end;

procedure CAI_Crow__Load_Patch(); stdcall;
asm
  push [esp]        //�������� ����� ��������
  lea ecx, [esp+4]  //����� ������ ��� ������
  pushad
    push ecx

    push edi //section
    push esi //crow
    call CAI_Crow_Load

    pop ecx
    mov [ecx], eax
  popad

  ret
end;

var
  cached_bomb_attack:cached_cfg_param_bool;
  cached_visibility_attack:cached_cfg_param_bool;

procedure CAI_Crow__CheckAttack(crow:pCAI_Crow; crow_sect:PChar; crow_pos:pFVector3; actor_pos:pFVector3); stdcall;
var
  dir, tmp:FVector3;
  dist_now:single;
begin
//  log('crow 0x'+inttohex(cardinal(crow), 8)+' alive! pos = '+floattostr(crow_pos.x)+', '+floattostr(crow_pos.y)+', '+floattostr(crow_pos.z));
//  log('goal = '+floattostr(crow_pos.x)+', '+floattostr(crow_pos.y)+', '+floattostr(crow_pos.z));
  if GetCachedCfgParamBoolDef(cached_bomb_attack, crow_sect, 'bomb_attack', false) then begin
    dir:=actor_pos^;
    v_sub(@dir, crow_pos);
    dist_now:=v_length(@dir);
    v_normalize(@dir);
    if (sqrt(dir.x*dir.x+dir.z*dir.z)<0.05) and (TraceAsView(crow_pos, @dir, nil)>=dist_now-0.4) and game_ini_line_exist(crow_sect, 'bomb_callback') then begin
      script_call(game_ini_read_string(crow_sect, 'bomb_callback'), crow_sect, 0); 
    end;
  end;

  if GetCachedCfgParamBoolDef(cached_visibility_attack, crow_sect, 'visibility_attack', false) and not IsDemoRecord() then begin
    dir:=FVector3_copyfromengine(CRenderDevice__GetCamPos());
    v_sub(@dir, crow_pos);
    dist_now:=v_length(@dir);
    v_normalize(@dir);

    tmp:=crow_pos^;
    tmp.y:=tmp.y-0.2;

    if (dist_now<game_ini_r_single_def(crow_sect, 'visibility_attack_max_dist', 0)) and (TraceAsView(crow_pos, @dir, nil)>=dist_now-0.4) and game_ini_line_exist(crow_sect, 'visibility_attack_callback') then begin
      bird_attack_last_time:=GetGameTickCount();
      script_call(game_ini_read_string(crow_sect, 'visibility_attack_callback'), crow_sect, 0);
    end;
  end;
end;

procedure CAI_Crow__shedule_Update_Attack_Patch();stdcall;
asm
  pushad
    call GetActor
    cmp eax, 0
    je @finish
    add eax, $80
    push eax

    mov eax, esi
    add eax, $3C
    push eax

    mov eax, esi
    mov eax, [eax+$68]
    add eax, $10
    push eax

    mov eax, esi
    sub eax, $44
    push eax

    call CAI_Crow__CheckAttack

    @finish:
  popad
  xorps xmm0, xmm0
  comiss xmm0, [esi+$328]
end;

procedure CEntity__Die_Patch(); stdcall;
asm
  cmp dword ptr [edx+$424], 01         //IsGameTypeSingle() == true?
  jne @finish
  cmp byte ptr[esi+$232], 01 //m_registered_member == true?
  jne @finish
  mov byte ptr[esi+$232], 00
  @finish:
end;

procedure CorrectRenderTimeDelta(crow:pCAI_Crow; delta:pSingle); stdcall;
var
  frames_was:cardinal;
begin
  frames_was := GetDevicedwFrame() - crow.o_workload_frame;
  if frames_was>3 then
    frames_was:=3 //������� ������ ����� ������ ������� �� ����� ���� � �.�. => ������ ������ ������
  else if
    frames_was<1 then frames_was:=1;
    
  delta^:=(delta^)*(frames_was);
end;

procedure CAI_Crow__renderable_Render_timedelta_Patch(); stdcall;
asm
  lea ecx, [esp+08]
  movss [ecx], xmm0; //original

  pushad
    push ecx //@delta
    lea eax, [esi-$4C]
    push eax //crow
    call CorrectRenderTimeDelta
  popad

  lea ecx, [esi-$4C] //original
  cmp [esi+$32c], eax //original
end;


function IsActorAttackedByBirds():boolean; stdcall;
begin
  result:=(GetTimeDeltaSafe(bird_attack_last_time)<2000);
end;

procedure ResetBirdsAttackingState(); stdcall;
begin
  bird_attack_last_time:=0;
end;


////////////////////////////////////////////////////////////////////////////////////////////////
function Init():boolean; stdcall;
var
  jmp_addr:cardinal;
begin
    result:=false;
    bird_attack_last_time:=0;


    //[bug] ������ ��� - ������� � CAICrow::net_Export � � CAICrow::net_Import/net_Spawn ���������� � �������� ��������� st_current � st_target
    //��� ����� ��� ������ ������ "����������" ��� ������������ ���� � �������� ����� ���� ����������� (�������� ������, ��� ��������� �� ������ �� �����)
    //UPDATE: ���� ������ ������� ������ net_Spawn, ��������� � ����� ��������, � ���� ��� >0 - ���������� ����� �����, ����� - �������.
    jmp_addr:=xrGame_addr+$100835;
    if not WriteJump(jmp_addr, cardinal(@CAICrow__net_Spawn_Patch), 8, true) then exit;

    //[bug] ������ ���, ����� ��� �� ����, �� ��������� � ���� ������������� ��� ��������
    //������ � void CEntity::Die(CObject* who): ���� ������ �� ��� ��������������� (m_registered_member	== false)
    //�� ���� ��� ��� ����� ����� �������� �����������������, ��� �������� � ������
    nop_code(xrGame_addr+$279650, 7);
    jmp_addr:=xrGame_addr+$27965F;
    if not WriteJump(jmp_addr, cardinal(@CEntity__Die_Patch), 7, true) then exit;

    //������ � ����� ����������� �������� ��� �����. �������� ���.
    // � CAI_Crow::shedule_Update ��������������� ����� UpdateWorkload, ��� �������� ���������� �� ���������� ����� ��� ���������� ������� � �����
    //��������� ���������� ��� ������, ����� ������ ����� ��� ������ ������ ����������� �� �����.
    // if (o_workload_rframe	== (Device.dwFrame-1)) ���� ��������� �� if (o_workload_rframe	>= (Device.dwFrame-2))
    nop_code(xrGame_addr+$1015D5, 1, CHR($FE));
    nop_code(xrGame_addr+$1015DC, 1, CHR($73));


    //CAI_Crow::renderable_Render ���������� ������ ��� ������� � ���� ����� ��������
    //��-�� ����� ������, ������� � ����, �� �� ������� � ����, ����������� - fDeltaTime ��� ������� ����� �� �����������
    //������ �����, ������ �������� ����������� �����, �� ������� ��� ������ ����� UpdateWorkload (o_workload_frame) � ���������� Device.fTimeDelta �� ����� ��������� � ����� ������� ������:
    //� ������ �� ������ ��������� ���: UpdateWorkload (Device.fTimeDelta*(Device.dwFrame-o_workload_frame))
    jmp_addr:=xrGame_addr+$100DD1;
    if not WriteJump(jmp_addr, cardinal(@CAI_Crow__renderable_Render_timedelta_Patch), 15, true) then exit;


    //����� ����
    jmp_addr:=xrGame_addr+$1013C8;
    if not WriteJump(jmp_addr, cardinal(@CAI_Crow__shedule_Update_Attack_Patch), 10, true) then exit;

    //��������� ����������� �������� ������ ������ ��� ������ ����
    jmp_addr:=xrGame_addr+$101A40;
    if not WriteJump(jmp_addr, cardinal(@CAI_Crow__Load_Patch), 5, true) then exit;


    result:=true;
end;

end.
