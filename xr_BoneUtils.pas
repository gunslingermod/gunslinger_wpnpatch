unit xr_BoneUtils;

interface

procedure SetWorldModelBoneStatus(wpn: pointer; bone_name:PChar; status:boolean); stdcall;
procedure SetHudModelBoneStatus(wpn: pointer; bone_name:PChar; status:boolean); stdcall;
procedure SetWeaponModelBoneStatus(wpn: pointer; bone_name:PChar; status:boolean); stdcall;
procedure SetWeaponMultipleBonesStatus(wpn: pointer; bones:PChar; status:boolean); stdcall;
procedure SetWorldModelMultipleBonesStatus(wpn: pointer; bones:PChar; status:boolean); stdcall;
function IKinematics__LL_BoneID(IKinematics:pointer; name:PChar):word; stdcall;

implementation
uses BaseGameData, ActorUtils, HudItemUtils;

procedure SetWeaponMultipleBonesStatus(wpn: pointer; bones:PChar; status:boolean); stdcall;
var
  bones_string:string;
  bone:string;
begin
  bones_string:=bones;
  while (GetNextSubStr(bones_string, bone, ',')) do begin
    SetWeaponModelBoneStatus(wpn, PChar(bone), status);
  end;
end;

procedure SetWorldModelMultipleBonesStatus(wpn: pointer; bones:PChar; status:boolean); stdcall;
var
  bones_string:string;
  bone:string;
begin
  bones_string:=bones;
  while (GetNextSubStr(bones_string, bone, ',')) do begin
    SetWorldModelBoneStatus(wpn, PChar(bone), status);
  end;
end;


procedure SetWeaponModelBoneStatus(wpn: pointer; bone_name:PChar; status:boolean); stdcall;
begin
  if (ActorUtils.GetActor()<>nil) and (ActorUtils.GetActorActiveItem() = wpn) then begin
    SetHudModelBoneStatus(wpn, bone_name, status);
  end;
  SetWorldModelBoneStatus(wpn, bone_name, status);
end;

procedure SetHudModelBoneStatus(wpn: pointer; bone_name:PChar; status:boolean); stdcall;
asm
    pushad
    pushfd

    //Получим основной объект attachable_hud_item
    push wpn
    call CHudItem__HudItemData
    test eax, eax
    je @finish
    mov esi, eax
    //Поместим bone_name в str_container
    push bone_name
    call str_container_dock
    test eax, eax
    je @finish
    push eax
    push esp //сразу загнали в стек аргумент - указатель на указатель на объект-строку с именем кости

    //Далее найдем и вызовем функцию определения индекса кости
    mov eax, [esi+$0C] //mov eax, IKinematics* m_model
    mov ecx, [eax]
    mov edx, [ecx+$10]
    push eax
    call edx           //call m_model->LL_BoneID
    add esp, 4
    movzx edi, ax
    cmp di, $FFFF
    je @finish

    //Теперь вызовем функцию установки статуса для найденной кости
    push 00 //видимость дочерних костей не менять
    movzx eax, status
    push eax
    push edi
    mov ecx, [esi+$0C]  //mov ecx, IKinematics* m_model
    mov eax, [ecx]
    mov edx, [eax+$60]
    call edx            //call m_model->LL_SetBoneVisible

    @finish:
    popfd
    popad
end;

procedure SetWorldModelBoneStatus(wpn: pointer; bone_name:PChar; status:boolean); stdcall;
asm
    pushad
    pushfd
    //Получим индекс кости в скелете
    push bone_name
    call str_container_dock
    test eax, eax
    je @finish
    push eax
    push esp //сохранили указатель на указатель на объект-строку с именем кости

    mov edi, wpn
    test edi, edi
    je @before_finish
    mov esi, [edi+$178]   //Помещаем pVisual в esi
    test esi, esi
    je @before_finish
    push esi
    mov eax, xrgame_addr
    add eax, $3483C0
    call eax
    add esp, 4  //снимаем со стека аргумент функции
    mov esi, eax
    push esi
    mov edx, [esi]
    mov edx, [edx+$10]
    call edx  //получаем индекс интересующей нас кости (в ax)
    add esp, 4  //снимаем нашу сохраненную "строку"
    movzx ebx, ax
    cmp ebx, $FFFF //Проверяем, обнаружена ли такая кость вообще
    je @finish

    //получим адрес нашей функции, показывающей/скрывающей кость
    mov edx, [esi]
    mov edx, [edx+$60]
    //а теперь выполним операцию сокрытия\отображения
    movzx eax, status

    push 00 //видимость дочерних костей не менять
    push eax
    push ebx

    mov ecx, esi
    call edx

    jmp @finish

    @before_finish:
    add esp, 8

    @finish:
    popfd
    popad
end;

function IKinematics__LL_BoneID(IKinematics:pointer; name:PChar):word; stdcall;
asm
  mov @result, $FFFF
  pushad

  push name
  call str_container_dock
  test eax, eax
  je @finish

  push eax
  push esp

  mov eax, IKinematics
  mov ecx, [eax]
  mov edx, [ecx+$10]
  push eax
  call edx
  add esp, 4
  mov @result, ax

  @finish:
  popad
end;


end.
