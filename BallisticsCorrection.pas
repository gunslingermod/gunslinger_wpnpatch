unit BallisticsCorrection;

interface
uses MatVectors;
function Init:boolean;

procedure CorrectShooting(wpn:pointer; CEntity:pointer; pos:pFVector3; dir:pFVector3); stdcall;

implementation
uses BaseGameData,  sysutils, messenger, HudItemUtils, ActorUtils, gunsl_config, WeaponAdditionalBuffer, RayPick, dynamic_caster, ControllerMonster;

procedure virtual_CEntity__g_fireParams(this:pointer; wpn:pointer; pos:pFVector3; dir:pFVector3); stdcall;
asm
  pushad
    mov ecx, this
    push dir
    push pos
    mov eax, wpn
    add eax, $2e0
    push eax

    mov eax, [ecx]
    mov eax, [eax+$20C]
    call eax
  popad
end; 

procedure CorrectLensOffset(wpn:pointer); stdcall;
var
  buf:WpnBuf;
  p:lens_offset_params;
begin
  buf:=GetBuffer(wpn);
  if buf<>nil then begin
    buf.GetLensOffsetParams(@p);
    if GetCurrentCondition(wpn)>p.start_condition then begin
      buf.SetOffsetDir(random);
    end;
  end;
end;

procedure CorrectShooting(wpn:pointer; CEntity:pointer; pos:pFVector3; dir:pFVector3); stdcall;
var
  oldpos:FVector3;
  olddir:FVector3;
  buf:WpnBuf;
  dist:single;
begin
  buf:=GetBuffer(wpn);
  if buf=nil then begin
    log('BallisticsCorrection.CorrectShooting: Shit happens!', true);
    exit;
  end;
  //сначала скорректируем точку стрельбы (чтобы не стреляло сквозь стены)
  olddir:=dir^;

  if (GetActorActiveItem()=wpn) and (CHudItem__HudItemData(wpn)<>nil) then begin
    v_mul(@olddir, buf.GetHUDBulletOffset());
  end else begin
    v_mul(@olddir, buf.GetWorldBulletOffset());
  end;
  v_add(pos, @olddir);

  //сохраним точку стрельбы оружия и посмотрим, откуда и куда захочет стрелять игра
  oldpos:=pos^;
  olddir:=dir^;
  virtual_CEntity__g_fireParams(CEntity, wpn, pos, dir);
  if v_equal(@oldpos, pos) and v_equal(@olddir, dir) then exit;

  //пересчитаем это в соответствии с нашими интересами
  if (GetOwner(wpn)=GetActor()) and (not (IsAimNow(wpn) or IsHolderInAimState(wpn)) and (buf.IsLaserInstalled() and buf.IsLaserEnabled()) or (GetCurrentDifficulty>=gd_veteran) or IsRealBallistics() or IsActorControlled()) then begin
    pos^:=oldpos;
    dir^:=olddir;
    //вид от 1-го лица, лазер/контроль... короче, стреляем туда, куда показывает оружие
    CorrectDirFromWorldToHud(dir, pos, game_ini_r_single_def(GetHUDSection(wpn), 'hud_recalc_koef', 1.0));
  end else begin
    //ищем предполагаемую точку попадания при стрельбе из новой точки
    dist:=TraceAsView(pos, dir, GetOwner(wpn));
    //log(floattostr(dist));
    v_mul(dir, dist);
    v_add(pos, dir); //в pos - точка попадания

    //если точка попадания лежит ближе, чем точка вылета - все плохо, пойдет стрельба сквозь стену

    //выставляем стартовую точку в FirePoint, а полет направим в вычисленную новую точку
    v_sub(pos, @oldpos);
    v_normalize(pos);
    dir^ := pos^;
    pos^:=oldpos;
  end;

end;

procedure CWeaponMagazined__state_Fire_Patch(); stdcall;
asm
  lea ecx, [esp+$10]
  lea edx, [esp+$1C]

  pushad
  push esi

  push ecx
  push edx
  push edi
  push esi
  call CorrectShooting

  call CorrectLensOffset
  popad
end;

procedure CWeaponRPG7__switch2_Fire_Patch(); stdcall;
asm
  test eax, eax
  je @finish
  lea edx, [esp+$34]
  lea ecx, [esp+$4C]
  pushad
    push esi//wpn

    push ecx//dir
    push edx//pos
    push eax //e
    push esi//wpn

    call CorrectShooting
    call CorrectLensOffset

  popad

{  pushad
    push 00
    push esi
    call virtual_CWeaponMagazined__UnloadMagazine
  popad }

  @finish:
  xor eax, eax
  test eax, eax
  ret 4
end;

function Init:boolean;
var
    addr:cardinal;
begin
  result:=false;
  addr:=xrGame_addr+$2d0554;
  if not WriteJump(addr, cardinal(@CWeaponMagazined__state_Fire_Patch), 29, true) then exit;
  addr:=xrGame_addr+$2D9A43;
  if not WriteJump(addr, cardinal(@CWeaponRPG7__switch2_Fire_Patch), 5, true) then exit;
  result:=true;
end;

end.
