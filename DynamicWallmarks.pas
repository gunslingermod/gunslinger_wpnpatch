unit DynamicWallmarks;
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface
uses MatVectors;
function Init():boolean; stdcall;

type
SBullet_Hit = packed record
  power:single;
  impulse:single;
end;

SBullet = packed record
  init_frame_num:cardinal;
  flags:word;
  bullet_material_idx:word;
  bullet_pos:FVector3;
  dir:FVector3;
  speed:single;
  parent_id:word;
  weapon_id:word;
  fly_dist:single;
  tracer_start_position:FVector3;
  start_position:FVector3;
  start_velocity:FVector3;
  born_time:cardinal;
  life_time:single;
  change_rajectory_count:cardinal;
  hit_param:SBullet_Hit;
  air_resistance:single;
  max_speed:single;
  max_dist:single;
  armor_piercing:single;
  wallmark_size:single;
  //to be continued...
end;
pSBullet=^SBullet;

implementation
uses BaseGameData, RayPick, ActorUtils, Misc, SysUtils;

var
  RTTI_CKinematics:pointer;

function PKinematics(IRender_Visual:pointer):pointer; stdcall;
asm
  pushad
    mov eax, IRender_Visual
    push eax
    mov eax, [eax]
    mov eax, [eax+$0C]
    call eax
    mov @result, eax
  popad
end;

procedure add_SkeletonWallmark(xf:pointer; obj:pointer; wallmark_array:pointer; start:pFVector3; dir:pFVector3; size:single); stdcall;
asm
  pushad
    mov ecx, xrgame_addr
    mov ecx, [ecx+$5124a8]
    mov ecx, [ecx]
    mov edx, [ecx]
    mov edx, [edx+$70]

    push size
    push dir
    push start
    push wallmark_array
    push obj
    push xf
    call edx
  popad
end;

procedure AddDynamicShotmark (rqr:prq_result; m_pCollideMarks:pointer; particle_dir:pFVector3; bullet:pSBullet); stdcall;
var
  dir, pos:FVector3;
begin
  if rqr.O=nil then exit;
  if m_pCollideMarks=nil then exit;
  if (GetActor()<>nil) and (GetCObjectID(GetActor())=GetCObjectID(rqr.O)) then exit;

  dir:=FVector3_copyfromengine(particle_dir);
  v_mul(@dir, -1);

  pos:=bullet.bullet_pos;
  //log (floattostr(bullet.wallmark_size));
  log(inttohex(cardinal(bullet), 8));
  add_SkeletonWallmark(GetCObjectXForm(rqr.O), PKinematics(GetCObjectVisual(rqr.O)), m_pCollideMarks, @pos, @dir, bullet.wallmark_size);


end;

procedure CBulletManager__FireShotmark_Patch(); stdcall;
asm
  cmp eax, 0
  je @end
  
  lea esi, [esp+$64]
  pushad

  push [esi+$4] //bullet
  push [esi+$8] //vDir
  mov eax, [eax+$48]              //mtl_pair.m_pCollideMarks
  push eax
  push ebp
  call AddDynamicShotmark

  popad

  @end:
  cmp [ebp], 0
  mov esi, eax

end;

function Init():boolean; stdcall;
var
  jmp_addr:cardinal;
begin
  result:=false;

  //добавляем воллмарки от хита на динобъекты
  jmp_addr:=xrgame_addr+$250c29;
//  if not WriteJump(jmp_addr, cardinal(@CBulletManager__FireShotmark_Patch), 6, true) then exit;

  result:=true;
end;

end.
